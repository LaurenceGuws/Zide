const std = @import("std");
const parser_mod = @import("../../parser/parser.zig");
const app_logger = @import("../../../app_logger.zig");
const app_lifecycle_runtime = @import("../../../app/lifecycle_runtime.zig");
const terminal_transport = @import("terminal_transport.zig");
const terminal_publication = @import("../publication/terminal_publication.zig");
const publication_flow = @import("../publication/publication_flow.zig");

fn shouldPublishParseBatch(
    sync_updates_active: bool,
    pending_offset: ?usize,
    presentation_backlog: bool,
    drained_available: bool,
    parse_bytes_since_publish: usize,
    elapsed_since_publish: i64,
    backlog_publish_min_bytes: usize,
    backlog_publish_max_ms: i64,
) bool {
    if (sync_updates_active) return false;
    return pending_offset != null or
        !presentation_backlog or
        drained_available or
        parse_bytes_since_publish >= backlog_publish_min_bytes or
        elapsed_since_publish >= backlog_publish_max_ms;
}

fn publishedVisibleCellCount(session: anytype) usize {
    const cache = terminal_publication.renderCache(session).*;
    return @as(usize, cache.rows) * @as(usize, cache.cols);
}

pub fn readThreadMain(session: anytype) void {
    const max_read: usize = 64 * 1024;
    var buf: [max_read]u8 = undefined;
    var io_after_shutdown_logged = false;

    while (session.session.runtime.read_thread_running.load(.acquire)) {
        if (terminal_transport.Transport.fromSession(session)) |transport| {
            if (!transport.waitForData(10)) continue;
            var processed: usize = 0;
            const start_ms = std.time.milliTimestamp();
            while (session.session.runtime.read_thread_running.load(.acquire)) {
                const n = transport.read(&buf) catch break;
                if (n == null or n.? == 0) break;
                if (app_lifecycle_runtime.shutdownStarted() and !io_after_shutdown_logged) {
                    io_after_shutdown_logged = true;
                    app_logger.logger("terminal.lifecycle").logFields(.warning, "terminal_read_activity_after_shutdown_begin", &.{
                        .{ .key = "session_ptr", .value = .{ .unsigned = @intFromPtr(session) } },
                        .{ .key = "shell_deinitialized", .value = .{ .boolean = app_lifecycle_runtime.shellDeinitialized() } },
                        .{ .key = "bytes", .value = .{ .unsigned = n.? } },
                    });
                }
                processed += n.?;
                session.session.runtime.io_mutex.lock();
                session.session.runtime.io_buffer.appendSlice(session.allocator, buf[0..n.?]) catch |err| {
                    app_logger.logger("terminal.io").logf(.warning, "io buffer append failed bytes={d} err={s}", .{ n.?, @errorName(err) });
                };
                session.session.runtime.io_mutex.unlock();
                session.session.runtime.io_wait_cond.signal();
                if (session.session.runtime.parse_thread == null) {
                    publication_flow.markOutputPending(session);
                    _ = publication_flow.noteParsedOutputLocked(session);
                }
            }
            _ = start_ms;
            publication_flow.noteProcessedOutput(session, processed);
        } else {
            break;
        }
    }
}

pub fn parseThreadMain(session: anytype) void {
    var temp: [4096]u8 = undefined;

    while (session.session.runtime.parse_thread_running.load(.acquire)) {
        const input_pressure = session.session.control.input_pressure.load(.acquire);
        const presentation_backlog = publication_flow.outputPending(session);
        var max_bytes: usize = if (input_pressure) 64 * 1024 else 512 * 1024;
        var max_ms: i64 = if (input_pressure) 2 else 8;
        const pending_refresh = publication_flow.takePendingViewRefreshRequest(session);

        var queued_bytes: usize = 0;
        session.session.runtime.io_mutex.lock();
        if (session.session.runtime.io_buffer.items.len > session.session.runtime.io_read_offset) {
            queued_bytes = session.session.runtime.io_buffer.items.len - session.session.runtime.io_read_offset;
        } else {
            if (pending_refresh == null) {
                session.session.runtime.io_wait_cond.timedWait(&session.session.runtime.io_mutex, 10 * std.time.ns_per_ms) catch |err| {
                    if (err != error.Timeout) {
                        app_logger.logger("terminal.parse").logf(.warning, "parse wait timedWait failed err={s}", .{@errorName(err)});
                    }
                };
            }
            if (!session.session.runtime.parse_thread_running.load(.acquire)) {
                session.session.runtime.io_mutex.unlock();
                break;
            }
            if (session.session.runtime.io_buffer.items.len > session.session.runtime.io_read_offset) {
                queued_bytes = session.session.runtime.io_buffer.items.len - session.session.runtime.io_read_offset;
            }
        }
        session.session.runtime.io_mutex.unlock();

        if (queued_bytes == 0) {
            if (session.session.control.parse_bytes_since_publish > 0 and pending_refresh == null and !session.core.sync_updates_active) {
                const publish_lock_start_ns = std.time.nanoTimestamp();
                session.session.control.state_mutex.lock();
                publication_flow.publishPendingOutputLocked(session, session.core.history.scrollOffset(), "parse_thread_idle_publish");
                session.session.control.state_mutex.unlock();
                _ = std.time.nanoTimestamp() - publish_lock_start_ns;
                session.session.control.parse_publishes_since_log += 1;
                session.session.control.parse_bytes_since_log += session.session.control.parse_bytes_since_publish;
                session.session.control.parse_bytes_since_publish = 0;
                session.session.control.last_parse_publish_ms = std.time.milliTimestamp();
            }
            if (pending_refresh) |request| {
                session.session.control.state_mutex.lock();
                if (!session.core.sync_updates_active) {
                    publication_flow.publishViewRefreshRequestLocked(session, request, "parse_thread_pending_offset");
                }
                session.session.control.state_mutex.unlock();
            }
            continue;
        }

        if (queued_bytes >= 8 * 1024 * 1024) {
            max_bytes = if (input_pressure) 256 * 1024 else 2 * 1024 * 1024;
            max_ms = if (input_pressure) 4 else 16;
        } else if (queued_bytes >= 1024 * 1024) {
            max_bytes = if (input_pressure) 128 * 1024 else 512 * 1024;
            max_ms = if (input_pressure) 2 else 8;
        }
        // Keep live presentation cadence smoother under large flood even before
        // the draw side has observed the first published batch.
        if (queued_bytes >= 256 * 1024) {
            const cadence_max_bytes: usize = if (input_pressure) 64 * 1024 else 128 * 1024;
            const cadence_max_ms: i64 = if (input_pressure) 1 else 2;
            max_bytes = @min(max_bytes, cadence_max_bytes);
            max_ms = @min(max_ms, cadence_max_ms);
        }
        if (presentation_backlog) {
            const backlog_max_bytes: usize = if (input_pressure) 32 * 1024 else 64 * 1024;
            max_bytes = @min(max_bytes, backlog_max_bytes);
            max_ms = @min(max_ms, @as(i64, 1));
        }

        const start_ms = std.time.milliTimestamp();
        var processed: usize = 0;
        var had_data = false;
        var parse_lock_hold_ns: i128 = 0;
        var publish_lock_hold_ns: i128 = 0;
        const queued_before = queued_bytes;
        var queued_after: usize = queued_before;

        while (processed < max_bytes and std.time.milliTimestamp() - start_ms < max_ms) {
            var chunk_len: usize = 0;
            session.session.runtime.io_mutex.lock();
            const available = if (session.session.runtime.io_buffer.items.len > session.session.runtime.io_read_offset)
                session.session.runtime.io_buffer.items.len - session.session.runtime.io_read_offset
            else
                0;
            if (available > 0) {
                chunk_len = @min(temp.len, available);
                std.mem.copyForwards(u8, temp[0..chunk_len], session.session.runtime.io_buffer.items[session.session.runtime.io_read_offset .. session.session.runtime.io_read_offset + chunk_len]);
                session.session.runtime.io_read_offset += chunk_len;
                had_data = true;
                if (session.session.runtime.io_read_offset >= session.session.runtime.io_buffer.items.len) {
                    session.session.runtime.io_buffer.items.len = 0;
                    session.session.runtime.io_read_offset = 0;
                } else if (session.session.runtime.io_read_offset > 64 * 1024 and session.session.runtime.io_read_offset > session.session.runtime.io_buffer.items.len / 2) {
                    const remaining = session.session.runtime.io_buffer.items.len - session.session.runtime.io_read_offset;
                    std.mem.copyForwards(u8, session.session.runtime.io_buffer.items[0..remaining], session.session.runtime.io_buffer.items[session.session.runtime.io_read_offset..session.session.runtime.io_buffer.items.len]);
                    session.session.runtime.io_buffer.items.len = remaining;
                    session.session.runtime.io_read_offset = 0;
                }
            }
            session.session.runtime.io_mutex.unlock();

            if (chunk_len == 0) break;

            const parse_lock_start_ns = std.time.nanoTimestamp();
            session.session.control.state_mutex.lock();
            const result = session.core.feedOutputBytesLocked(session, temp[0..chunk_len]);
            publication_flow.consumeFeedResultLocked(session, result, "parse_thread_chunk");
            session.session.control.state_mutex.unlock();
            parse_lock_hold_ns += std.time.nanoTimestamp() - parse_lock_start_ns;
            processed += chunk_len;
        }

        session.session.runtime.io_mutex.lock();
        queued_after = if (session.session.runtime.io_buffer.items.len > session.session.runtime.io_read_offset)
            session.session.runtime.io_buffer.items.len - session.session.runtime.io_read_offset
        else
            0;
        session.session.runtime.io_mutex.unlock();

        if (processed > 0) {
            const end_ms = std.time.milliTimestamp();
            session.session.control.parse_bytes_since_publish += processed;
            if (had_data or pending_refresh != null) {
                var backlog_publish_max_ms: i64 = if (input_pressure) 2 else 8;
                var backlog_publish_min_bytes: usize = if (input_pressure) 32 * 1024 else 128 * 1024;
                if (presentation_backlog and publishedVisibleCellCount(session) >= 16_000) {
                    backlog_publish_max_ms = @min(backlog_publish_max_ms, @as(i64, 4));
                    backlog_publish_min_bytes = @min(backlog_publish_min_bytes, @as(usize, 16 * 1024));
                }
                const elapsed_since_publish = if (session.session.control.last_parse_publish_ms == 0)
                    backlog_publish_max_ms
                else
                    end_ms - session.session.control.last_parse_publish_ms;
                const drained_available = queued_bytes > 0 and processed >= queued_bytes;
                const should_publish = shouldPublishParseBatch(
                    session.core.sync_updates_active,
                    if (pending_refresh) |request| request.scroll_offset else null,
                    presentation_backlog,
                    drained_available,
                    session.session.control.parse_bytes_since_publish,
                    elapsed_since_publish,
                    backlog_publish_min_bytes,
                    backlog_publish_max_ms,
                );
                if (should_publish) {
                    const target_offset = if (pending_refresh) |request|
                        request.scroll_offset
                    else
                        session.core.history.scrollOffset();
                    const publish_lock_start_ns = std.time.nanoTimestamp();
                    session.session.control.state_mutex.lock();
                    publication_flow.publishPendingOutputLocked(session, target_offset, "parse_thread_publish");
                    session.session.control.state_mutex.unlock();
                    const publish_lock_ns = std.time.nanoTimestamp() - publish_lock_start_ns;
                    publish_lock_hold_ns += publish_lock_ns;
                    session.session.control.parse_publishes_since_log += 1;
                    session.session.control.parse_bytes_since_log += session.session.control.parse_bytes_since_publish;
                    session.session.control.parse_bytes_since_publish = 0;
                    session.session.control.last_parse_publish_ms = end_ms;
                    if (presentation_backlog) {
                        std.Thread.yield() catch {};
                    }
                }
            }

            const elapsed_ms = @as(f64, @floatFromInt(end_ms - start_ms));
            _ = elapsed_ms;
        }
    }
}

test "shouldPublishParseBatch suppresses intermediate publish during sync updates" {
    try std.testing.expect(!shouldPublishParseBatch(true, null, false, true, 1024, 99, 1, 1));
}

test "shouldPublishParseBatch publishes once sync updates are inactive" {
    try std.testing.expect(shouldPublishParseBatch(false, null, false, false, 0, 0, 128 * 1024, 8));
}

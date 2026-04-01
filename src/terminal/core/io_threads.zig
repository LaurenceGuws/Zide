const std = @import("std");
const parser_mod = @import("../parser/parser.zig");
const app_logger = @import("../../app_logger.zig");
const app_lifecycle_runtime = @import("../../app/lifecycle_runtime.zig");
const terminal_transport = @import("terminal_transport.zig");
const terminal_publication = @import("terminal_publication.zig");

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

    while (session.runtime.read_thread_running.load(.acquire)) {
        if (terminal_transport.Transport.fromSession(session)) |transport| {
            if (!transport.waitForData(10)) continue;
            var processed: usize = 0;
            const start_ms = std.time.milliTimestamp();
            while (session.runtime.read_thread_running.load(.acquire)) {
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
                session.runtime.io_mutex.lock();
                session.runtime.io_buffer.appendSlice(session.allocator, buf[0..n.?]) catch |err| {
                    app_logger.logger("terminal.io").logf(.warning, "io buffer append failed bytes={d} err={s}", .{ n.?, @errorName(err) });
                };
                session.runtime.io_mutex.unlock();
                session.runtime.io_wait_cond.signal();
                if (session.runtime.parse_thread == null) {
                    terminal_publication.markOutputPending(session);
                    _ = terminal_publication.bumpGeneration(session);
                }
            }
            _ = start_ms;
            if (processed > 0) _ = terminal_publication.takeAltExitPending(session);
        } else {
            break;
        }
    }
    app_logger.logger("terminal.lifecycle").logFields(.info, "terminal_read_thread_exit", &.{
        .{ .key = "session_ptr", .value = .{ .unsigned = @intFromPtr(session) } },
        .{ .key = "shutdown_started", .value = .{ .boolean = app_lifecycle_runtime.shutdownStarted() } },
        .{ .key = "shell_deinitialized", .value = .{ .boolean = app_lifecycle_runtime.shellDeinitialized() } },
    });
}

pub fn parseThreadMain(session: anytype) void {
    var temp: [4096]u8 = undefined;
    const publication_log = app_logger.logger("terminal.publication");

    while (session.runtime.parse_thread_running.load(.acquire)) {
        const input_pressure = session.control.input_pressure.load(.acquire);
        const presentation_backlog = terminal_publication.outputPending(session);
        var max_bytes: usize = if (input_pressure) 64 * 1024 else 512 * 1024;
        var max_ms: i64 = if (input_pressure) 2 else 8;
        const pending_offset = terminal_publication.takePendingViewRefresh(session);

        var queued_bytes: usize = 0;
        session.runtime.io_mutex.lock();
        if (session.runtime.io_buffer.items.len > session.runtime.io_read_offset) {
            queued_bytes = session.runtime.io_buffer.items.len - session.runtime.io_read_offset;
        } else {
            if (pending_offset == null) {
                session.runtime.io_wait_cond.timedWait(&session.runtime.io_mutex, 10 * std.time.ns_per_ms) catch |err| {
                    if (err != error.Timeout) {
                        app_logger.logger("terminal.parse").logf(.warning, "parse wait timedWait failed err={s}", .{@errorName(err)});
                    }
                };
            }
            if (!session.runtime.parse_thread_running.load(.acquire)) {
                session.runtime.io_mutex.unlock();
                break;
            }
            if (session.runtime.io_buffer.items.len > session.runtime.io_read_offset) {
                queued_bytes = session.runtime.io_buffer.items.len - session.runtime.io_read_offset;
            }
        }
        session.runtime.io_mutex.unlock();

        if (queued_bytes == 0) {
            if (session.control.parse_bytes_since_publish > 0 and pending_offset == null and !session.core.sync_updates_active) {
                const publish_lock_start_ns = std.time.nanoTimestamp();
                session.control.state_mutex.lock();
                const generation_before = terminal_publication.pendingGeneration(session);
                const published_before = session.publishedGeneration();
                const view = session.core.activeScreenConst().snapshotView();
                const rows = view.rows;
                const cols = view.cols;
                terminal_publication.publishGenerationLocked(session, generation_before, session.core.history.scrollOffset(), "parse_thread_idle_publish");
                const published_after = session.publishedGeneration();
                session.control.state_mutex.unlock();
                const publish_lock_ns = std.time.nanoTimestamp() - publish_lock_start_ns;
                session.control.parse_publishes_since_log += 1;
                session.control.parse_bytes_since_log += session.control.parse_bytes_since_publish;
                session.control.parse_bytes_since_publish = 0;
                session.control.last_parse_publish_ms = std.time.milliTimestamp();
                terminal_publication.markOutputPending(session);
                if (publication_log.enabled_file or publication_log.enabled_console) {
                    publication_log.logf(
                        .info,
                        "stage=parse_idle_publish attempted=1 published_before={d} current_before={d} published_after={d} bytes={d} rows={d} cols={d} publish_ms={d:.3}",
                        .{
                            published_before,
                            generation_before,
                            published_after,
                            session.control.parse_bytes_since_log,
                            rows,
                            cols,
                            @as(f64, @floatFromInt(publish_lock_ns)) / @as(f64, @floatFromInt(std.time.ns_per_ms)),
                        },
                    );
                }
            }
            if (pending_offset) |offset| {
                session.control.state_mutex.lock();
                if (!session.core.sync_updates_active) {
                    terminal_publication.publishGenerationLocked(session, terminal_publication.pendingGeneration(session), offset, "parse_thread_pending_offset");
                }
                session.control.state_mutex.unlock();
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
            session.runtime.io_mutex.lock();
            const available = if (session.runtime.io_buffer.items.len > session.runtime.io_read_offset)
                session.runtime.io_buffer.items.len - session.runtime.io_read_offset
            else
                0;
            if (available > 0) {
                chunk_len = @min(temp.len, available);
                std.mem.copyForwards(u8, temp[0..chunk_len], session.runtime.io_buffer.items[session.runtime.io_read_offset .. session.runtime.io_read_offset + chunk_len]);
                session.runtime.io_read_offset += chunk_len;
                had_data = true;
                if (session.runtime.io_read_offset >= session.runtime.io_buffer.items.len) {
                    session.runtime.io_buffer.items.len = 0;
                    session.runtime.io_read_offset = 0;
                } else if (session.runtime.io_read_offset > 64 * 1024 and session.runtime.io_read_offset > session.runtime.io_buffer.items.len / 2) {
                    const remaining = session.runtime.io_buffer.items.len - session.runtime.io_read_offset;
                    std.mem.copyForwards(u8, session.runtime.io_buffer.items[0..remaining], session.runtime.io_buffer.items[session.runtime.io_read_offset..session.runtime.io_buffer.items.len]);
                    session.runtime.io_buffer.items.len = remaining;
                    session.runtime.io_read_offset = 0;
                }
            }
            session.runtime.io_mutex.unlock();

            if (chunk_len == 0) break;

            const parse_lock_start_ns = std.time.nanoTimestamp();
            session.control.state_mutex.lock();
            session.core.parser.handleSlice(parser_mod.Parser.SessionFacade.from(session), temp[0..chunk_len]);
            session.control.state_mutex.unlock();
            parse_lock_hold_ns += std.time.nanoTimestamp() - parse_lock_start_ns;
            processed += chunk_len;
            _ = terminal_publication.bumpGeneration(session);
        }

        session.runtime.io_mutex.lock();
        queued_after = if (session.runtime.io_buffer.items.len > session.runtime.io_read_offset)
            session.runtime.io_buffer.items.len - session.runtime.io_read_offset
        else
            0;
        session.runtime.io_mutex.unlock();

        if (processed > 0) {
            const end_ms = std.time.milliTimestamp();
            session.control.parse_bytes_since_publish += processed;
            if (had_data or pending_offset != null) {
                var backlog_publish_max_ms: i64 = if (input_pressure) 2 else 8;
                var backlog_publish_min_bytes: usize = if (input_pressure) 32 * 1024 else 128 * 1024;
                if (presentation_backlog and publishedVisibleCellCount(session) >= 16_000) {
                    backlog_publish_max_ms = @min(backlog_publish_max_ms, @as(i64, 4));
                    backlog_publish_min_bytes = @min(backlog_publish_min_bytes, @as(usize, 16 * 1024));
                }
                const elapsed_since_publish = if (session.control.last_parse_publish_ms == 0)
                    backlog_publish_max_ms
                else
                    end_ms - session.control.last_parse_publish_ms;
                const drained_available = queued_bytes > 0 and processed >= queued_bytes;
                const pending_generation = terminal_publication.pendingGeneration(session);
                const published_generation = session.publishedGeneration();
                const should_publish = shouldPublishParseBatch(
                    session.core.sync_updates_active,
                    pending_offset,
                    presentation_backlog,
                    drained_available,
                    session.control.parse_bytes_since_publish,
                    elapsed_since_publish,
                    backlog_publish_min_bytes,
                    backlog_publish_max_ms,
                );
                if (should_publish) {
                    const target_offset = pending_offset orelse session.core.history.scrollOffset();
                    const publish_lock_start_ns = std.time.nanoTimestamp();
                    session.control.state_mutex.lock();
                    const generation_before = terminal_publication.pendingGeneration(session);
                    const published_before = session.publishedGeneration();
                    const view = session.core.activeScreenConst().snapshotView();
                    const rows = view.rows;
                    const cols = view.cols;
                    terminal_publication.publishGenerationLocked(session, generation_before, target_offset, "parse_thread_publish");
                    const published_after = session.publishedGeneration();
                    session.control.state_mutex.unlock();
                    const publish_lock_ns = std.time.nanoTimestamp() - publish_lock_start_ns;
                    publish_lock_hold_ns += publish_lock_ns;
                    session.control.parse_publishes_since_log += 1;
                    session.control.parse_bytes_since_log += session.control.parse_bytes_since_publish;
                    session.control.parse_bytes_since_publish = 0;
                    session.control.last_parse_publish_ms = end_ms;
                    terminal_publication.markOutputPending(session);
                    if (publication_log.enabled_file or publication_log.enabled_console) {
                        publication_log.logf(
                            .info,
                            "stage=parse_publish attempted=1 pending_offset={d} presentation_backlog={d} drained_available={d} bytes_since_publish={d} elapsed_since_publish_ms={d} min_bytes={d} max_ms={d} published_before={d} current_before={d} published_after={d} rows={d} cols={d} publish_ms={d:.3}",
                            .{
                                @as(u8, @intFromBool(pending_offset != null)),
                                @intFromBool(presentation_backlog),
                                @intFromBool(drained_available),
                                session.control.parse_bytes_since_log,
                                elapsed_since_publish,
                                backlog_publish_min_bytes,
                                backlog_publish_max_ms,
                                published_before,
                                generation_before,
                                published_after,
                                rows,
                                cols,
                                @as(f64, @floatFromInt(publish_lock_ns)) / @as(f64, @floatFromInt(std.time.ns_per_ms)),
                            },
                        );
                    }
                    if (presentation_backlog) {
                        std.Thread.yield() catch {};
                    }
                } else if ((publication_log.enabled_file or publication_log.enabled_console) and pending_generation > published_generation) {
                    publication_log.logf(
                        .info,
                        "stage=parse_publish_skipped attempted=0 reason_sync_updates={d} reason_pending_offset={d} reason_presentation_backlog={d} reason_drained_available={d} reason_bytes_threshold={d} reason_time_threshold={d} bytes_since_publish={d} elapsed_since_publish_ms={d} min_bytes={d} max_ms={d} current={d} published={d} queued_before={d} processed={d}",
                        .{
                            @intFromBool(session.core.sync_updates_active),
                            @intFromBool(pending_offset != null),
                            @intFromBool(!presentation_backlog),
                            @intFromBool(drained_available),
                            @intFromBool(session.control.parse_bytes_since_publish >= backlog_publish_min_bytes),
                            @intFromBool(elapsed_since_publish >= backlog_publish_max_ms),
                            session.control.parse_bytes_since_publish,
                            elapsed_since_publish,
                            backlog_publish_min_bytes,
                            backlog_publish_max_ms,
                            pending_generation,
                            published_generation,
                            queued_before,
                            processed,
                        },
                    );
                }
            }

            const elapsed_ms = @as(f64, @floatFromInt(end_ms - start_ms));
            _ = elapsed_ms;
        }
    }
    app_logger.logger("terminal.lifecycle").logFields(.info, "terminal_parse_thread_exit", &.{
        .{ .key = "session_ptr", .value = .{ .unsigned = @intFromPtr(session) } },
        .{ .key = "shutdown_started", .value = .{ .boolean = app_lifecycle_runtime.shutdownStarted() } },
        .{ .key = "shell_deinitialized", .value = .{ .boolean = app_lifecycle_runtime.shellDeinitialized() } },
    });
}

test "shouldPublishParseBatch suppresses intermediate publish during sync updates" {
    try std.testing.expect(!shouldPublishParseBatch(true, null, false, true, 1024, 99, 1, 1));
}

test "shouldPublishParseBatch publishes once sync updates are inactive" {
    try std.testing.expect(shouldPublishParseBatch(false, null, false, false, 0, 0, 128 * 1024, 8));
}

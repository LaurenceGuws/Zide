const std = @import("std");
const parser_mod = @import("../parser/parser.zig");
const app_logger = @import("../../app_logger.zig");
const terminal_transport = @import("terminal_transport.zig");

pub fn logCsiSequences(log: app_logger.Logger, buf: []const u8) void {
    var i: usize = 0;
    while (i + 1 < buf.len) : (i += 1) {
        if (buf[i] != 0x1b or buf[i + 1] != '[') continue;
        const start = i;
        i += 2;
        while (i < buf.len) : (i += 1) {
            const b = buf[i];
            if (b >= 0x40 and b <= 0x7E) {
                if (b == 'm') {
                    const seq = buf[start .. i + 1];
                    var hex_buf: [256]u8 = undefined;
                    var out: []u8 = hex_buf[0..0];
                    for (seq) |sb| {
                        if (out.len + 3 > hex_buf.len) break;
                        const pos = out.len;
                        _ = std.fmt.bufPrint(hex_buf[pos..], "{x:0>2} ", .{sb}) catch break;
                        out = hex_buf[0 .. pos + 3];
                    }
                    log.logf(.debug, "csi raw len={d} hex={s}", .{ seq.len, out });
                }
                break;
            }
        }
    }
}

pub fn readThreadMain(session: anytype) void {
    const max_read: usize = 64 * 1024;
    var buf: [max_read]u8 = undefined;

    while (session.read_thread_running.load(.acquire)) {
        if (terminal_transport.Transport.fromSession(session)) |transport| {
            if (!transport.waitForData(10)) continue;
            var processed: usize = 0;
            const start_ms = std.time.milliTimestamp();
            const io_log = app_logger.logger("terminal.io");
            while (session.read_thread_running.load(.acquire)) {
                const n = transport.read(&buf) catch break;
                if (n == null or n.? == 0) break;
                processed += n.?;
                logCsiSequences(io_log, buf[0..n.?]);
                session.io_mutex.lock();
                session.io_buffer.appendSlice(session.allocator, buf[0..n.?]) catch |err| {
                    io_log.logf(.warning, "io buffer append failed bytes={d} err={s}", .{ n.?, @errorName(err) });
                };
                session.io_mutex.unlock();
                session.io_wait_cond.signal();
                if (session.parse_thread == null) {
                    session.output_pending.store(true, .release);
                    _ = session.output_generation.fetchAdd(1, .acq_rel);
                }
            }
            if (processed > 0 and session.alt_exit_pending.swap(false, .acq_rel)) {
                const elapsed_ms = @as(f64, @floatFromInt(std.time.milliTimestamp() - start_ms));
                io_log.logf(.info, "alt_exit_io_ms={d:.2} bytes={d}", .{ elapsed_ms, processed });
            }
        } else {
            break;
        }
    }
}

pub fn parseThreadMain(session: anytype) void {
    var temp: [4096]u8 = undefined;

    while (session.parse_thread_running.load(.acquire)) {
        const input_pressure = session.input_pressure.load(.acquire);
        const presentation_backlog = session.output_pending.load(.acquire);
        var max_bytes: usize = if (input_pressure) 64 * 1024 else 512 * 1024;
        var max_ms: i64 = if (input_pressure) 2 else 8;
        var pending_offset: ?usize = null;
        if (session.view_cache_pending.swap(false, .acq_rel)) {
            pending_offset = @intCast(session.view_cache_request_offset.load(.acquire));
        }

        var queued_bytes: usize = 0;
        session.io_mutex.lock();
        if (session.io_buffer.items.len > session.io_read_offset) {
            queued_bytes = session.io_buffer.items.len - session.io_read_offset;
        } else {
            if (pending_offset == null) {
                session.io_wait_cond.timedWait(&session.io_mutex, 10 * std.time.ns_per_ms) catch |err| {
                    if (err != error.Timeout) {
                        app_logger.logger("terminal.parse").logf(.warning, "parse wait timedWait failed err={s}", .{@errorName(err)});
                    }
                };
            }
            if (!session.parse_thread_running.load(.acquire)) {
                session.io_mutex.unlock();
                break;
            }
            if (session.io_buffer.items.len > session.io_read_offset) {
                queued_bytes = session.io_buffer.items.len - session.io_read_offset;
            }
        }
        session.io_mutex.unlock();

        if (queued_bytes == 0) {
            if (pending_offset) |offset| {
                session.state_mutex.lock();
                @import("view_cache.zig").updateViewCacheNoLock(session, session.output_generation.load(.acquire), offset);
                session.state_mutex.unlock();
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

        const perf_log = app_logger.logger("terminal.parse");
        const start_ms = std.time.milliTimestamp();
        var processed: usize = 0;
        var had_data = false;
        var parse_lock_hold_ns: i128 = 0;
        var publish_lock_hold_ns: i128 = 0;

        while (processed < max_bytes and std.time.milliTimestamp() - start_ms < max_ms) {
            var chunk_len: usize = 0;
            session.io_mutex.lock();
            const available = if (session.io_buffer.items.len > session.io_read_offset)
                session.io_buffer.items.len - session.io_read_offset
            else
                0;
            if (available > 0) {
                chunk_len = @min(temp.len, available);
                std.mem.copyForwards(u8, temp[0..chunk_len], session.io_buffer.items[session.io_read_offset .. session.io_read_offset + chunk_len]);
                session.io_read_offset += chunk_len;
                had_data = true;
                if (session.io_read_offset >= session.io_buffer.items.len) {
                    session.io_buffer.items.len = 0;
                    session.io_read_offset = 0;
                } else if (session.io_read_offset > 64 * 1024 and session.io_read_offset > session.io_buffer.items.len / 2) {
                    const remaining = session.io_buffer.items.len - session.io_read_offset;
                    std.mem.copyForwards(u8, session.io_buffer.items[0..remaining], session.io_buffer.items[session.io_read_offset..session.io_buffer.items.len]);
                    session.io_buffer.items.len = remaining;
                    session.io_read_offset = 0;
                }
            }
            session.io_mutex.unlock();

            if (chunk_len == 0) break;

            const parse_lock_start_ns = std.time.nanoTimestamp();
            session.state_mutex.lock();
            session.core.parser.handleSlice(parser_mod.Parser.SessionFacade.from(session), temp[0..chunk_len]);
            session.state_mutex.unlock();
            parse_lock_hold_ns += std.time.nanoTimestamp() - parse_lock_start_ns;
            processed += chunk_len;
            _ = session.output_generation.fetchAdd(1, .acq_rel);
        }

        if (had_data or pending_offset != null) {
            const target_offset = pending_offset orelse session.core.history.scrollOffset();
            const publish_lock_start_ns = std.time.nanoTimestamp();
            session.state_mutex.lock();
            @import("view_cache.zig").updateViewCacheNoLock(session, session.output_generation.load(.acquire), target_offset);
            session.state_mutex.unlock();
            publish_lock_hold_ns += std.time.nanoTimestamp() - publish_lock_start_ns;
            session.output_pending.store(true, .release);
            if (presentation_backlog) {
                std.Thread.yield() catch {};
            }
        }

        if (processed > 0) {
            const end_ms = std.time.milliTimestamp();
            const elapsed_ms = @as(f64, @floatFromInt(end_ms - start_ms));
            const should_log = elapsed_ms >= 8.0 or queued_bytes >= 1024 * 1024 or processed >= 512 * 1024;
            if (should_log and (end_ms - session.last_parse_log_ms) >= 100) {
                session.last_parse_log_ms = end_ms;
                perf_log.logf(.info, "parse_ms={d:.2} parse_lock_ms={d:.2} publish_lock_ms={d:.2} bytes={d} queued_bytes={d} input_pressure={any} presentation_backlog={any}", .{
                    elapsed_ms,
                    @as(f64, @floatFromInt(parse_lock_hold_ns)) / @as(f64, @floatFromInt(std.time.ns_per_ms)),
                    @as(f64, @floatFromInt(publish_lock_hold_ns)) / @as(f64, @floatFromInt(std.time.ns_per_ms)),
                    processed,
                    queued_bytes,
                    input_pressure,
                    presentation_backlog,
                });
            }
        }
    }
}

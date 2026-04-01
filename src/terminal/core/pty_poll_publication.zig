const std = @import("std");
const terminal_publication = @import("terminal_publication.zig");

pub fn publishPtyPollResult(self: anytype, had_data: bool, processed: usize, input_pressure: bool, queued_bytes: usize, parse_lock_hold_ns: i128, publish_lock_hold_ns: *i128, start_ms: i64) void {
    if (had_data) {
        const publish_lock_start_ns = std.time.nanoTimestamp();
        self.control.state_mutex.lock();
        terminal_publication.publishCurrentViewLocked(self, "pty_poll_publish");
        self.control.state_mutex.unlock();
        publish_lock_hold_ns.* += std.time.nanoTimestamp() - publish_lock_start_ns;
    }

    if (processed > 0) {
        const end_ms = std.time.milliTimestamp();
        const elapsed_ms = @as(f64, @floatFromInt(end_ms - start_ms));
        const should_log = elapsed_ms >= 8.0 or queued_bytes >= 1024 * 1024 or processed >= 512 * 1024;
        if (should_log and (end_ms - self.control.last_parse_log_ms) >= 100) {
            self.control.last_parse_log_ms = end_ms;
            @import("../../app_logger.zig").logger("terminal.parse").logf(.info, "parse_ms={d:.2} parse_lock_ms={d:.2} publish_lock_ms={d:.2} bytes={d} queued_bytes={d} input_pressure={any}", .{
                elapsed_ms,
                @as(f64, @floatFromInt(parse_lock_hold_ns)) / @as(f64, @floatFromInt(std.time.ns_per_ms)),
                @as(f64, @floatFromInt(publish_lock_hold_ns.*)) / @as(f64, @floatFromInt(std.time.ns_per_ms)),
                processed,
                queued_bytes,
                input_pressure,
            });
        }
    }

    self.runtime.io_mutex.lock();
    if (self.runtime.io_buffer.items.len > self.runtime.io_read_offset) {
        self.publication.output_pending.store(true, .release);
    }
    self.runtime.io_mutex.unlock();
    if (self.publication.view_cache_pending.load(.acquire)) {
        self.control.state_mutex.lock();
        _ = terminal_publication.applyPendingViewRefreshLocked(self, "pty_pending_offset");
        self.control.state_mutex.unlock();
    }
}

pub fn publishTransportPollResult(self: anytype, had_data: bool, processed: usize, input_pressure: bool, parse_lock_hold_ns: i128, publish_lock_hold_ns: *i128, start_ms: i64) void {
    if (had_data) {
        const publish_lock_start_ns = std.time.nanoTimestamp();
        terminal_publication.publishCurrentViewLocked(self, "transport_poll_publish");
        publish_lock_hold_ns.* += std.time.nanoTimestamp() - publish_lock_start_ns;
    }
    if (processed > 0 and terminal_publication.takeAltExitPending(self)) {
        const elapsed_ms = @as(f64, @floatFromInt(std.time.milliTimestamp() - start_ms));
        @import("../../app_logger.zig").logger("terminal.io").logf(.info, "alt_exit_io_ms={d:.2} bytes={d}", .{ elapsed_ms, processed });
    }
    if (processed > 0) {
        const end_ms = std.time.milliTimestamp();
        const elapsed_ms = @as(f64, @floatFromInt(end_ms - start_ms));
        const should_log = elapsed_ms >= 8.0 or processed >= 512 * 1024;
        if (should_log and (end_ms - self.control.last_parse_log_ms) >= 100) {
            self.control.last_parse_log_ms = end_ms;
            @import("../../app_logger.zig").logger("terminal.parse").logf(.info, "parse_ms={d:.2} parse_lock_ms={d:.2} publish_lock_ms={d:.2} bytes={d} input_pressure={any}", .{
                elapsed_ms,
                @as(f64, @floatFromInt(parse_lock_hold_ns)) / @as(f64, @floatFromInt(std.time.ns_per_ms)),
                @as(f64, @floatFromInt(publish_lock_hold_ns.*)) / @as(f64, @floatFromInt(std.time.ns_per_ms)),
                processed,
                input_pressure,
            });
        }
    }
    if (self.publication.view_cache_pending.load(.acquire)) {
        const publish_lock_start_ns = std.time.nanoTimestamp();
        _ = terminal_publication.applyPendingViewRefreshLocked(self, "transport_pending_offset");
        publish_lock_hold_ns.* += std.time.nanoTimestamp() - publish_lock_start_ns;
    }
}

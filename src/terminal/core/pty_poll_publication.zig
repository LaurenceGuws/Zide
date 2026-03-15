const std = @import("std");

pub fn publishPtyPollResult(self: anytype, had_data: bool, processed: usize, input_pressure: bool, queued_bytes: usize, parse_lock_hold_ns: i128, publish_lock_hold_ns: *i128, start_ms: i64) void {
    if (had_data) {
        const publish_lock_start_ns = std.time.nanoTimestamp();
        self.state_mutex.lock();
        @import("view_cache.zig").updateViewCacheNoLockTagged(self, self.output_generation.load(.acquire), self.core.history.scrollOffset(), "pty_poll_publish");
        self.state_mutex.unlock();
        publish_lock_hold_ns.* += std.time.nanoTimestamp() - publish_lock_start_ns;
    }

    if (processed > 0) {
        const end_ms = std.time.milliTimestamp();
        const elapsed_ms = @as(f64, @floatFromInt(end_ms - start_ms));
        const should_log = elapsed_ms >= 8.0 or queued_bytes >= 1024 * 1024 or processed >= 512 * 1024;
        if (should_log and (end_ms - self.last_parse_log_ms) >= 100) {
            self.last_parse_log_ms = end_ms;
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

    self.io_mutex.lock();
    if (self.io_buffer.items.len > self.io_read_offset) {
        self.output_pending.store(true, .release);
    }
    self.io_mutex.unlock();
    if (self.view_cache_pending.swap(false, .acq_rel)) {
        self.state_mutex.lock();
        const offset: usize = @intCast(self.view_cache_request_offset.load(.acquire));
        @import("view_cache.zig").updateViewCacheNoLockTagged(self, self.output_generation.load(.acquire), offset, "pty_pending_offset");
        self.state_mutex.unlock();
    }
}

pub fn publishTransportPollResult(self: anytype, had_data: bool, processed: usize, input_pressure: bool, parse_lock_hold_ns: i128, publish_lock_hold_ns: *i128, start_ms: i64) void {
    if (had_data) {
        const publish_lock_start_ns = std.time.nanoTimestamp();
        @import("view_cache.zig").updateViewCacheNoLockTagged(self, self.output_generation.load(.acquire), self.core.history.scrollOffset(), "transport_poll_publish");
        publish_lock_hold_ns.* += std.time.nanoTimestamp() - publish_lock_start_ns;
    }
    if (processed > 0 and self.alt_exit_pending.swap(false, .acq_rel)) {
        const elapsed_ms = @as(f64, @floatFromInt(std.time.milliTimestamp() - start_ms));
        @import("../../app_logger.zig").logger("terminal.io").logf(.info, "alt_exit_io_ms={d:.2} bytes={d}", .{ elapsed_ms, processed });
    }
    if (processed > 0) {
        const end_ms = std.time.milliTimestamp();
        const elapsed_ms = @as(f64, @floatFromInt(end_ms - start_ms));
        const should_log = elapsed_ms >= 8.0 or processed >= 512 * 1024;
        if (should_log and (end_ms - self.last_parse_log_ms) >= 100) {
            self.last_parse_log_ms = end_ms;
            @import("../../app_logger.zig").logger("terminal.parse").logf(.info, "parse_ms={d:.2} parse_lock_ms={d:.2} publish_lock_ms={d:.2} bytes={d} input_pressure={any}", .{
                elapsed_ms,
                @as(f64, @floatFromInt(parse_lock_hold_ns)) / @as(f64, @floatFromInt(std.time.ns_per_ms)),
                @as(f64, @floatFromInt(publish_lock_hold_ns.*)) / @as(f64, @floatFromInt(std.time.ns_per_ms)),
                processed,
                input_pressure,
            });
        }
    }
    if (self.view_cache_pending.swap(false, .acq_rel)) {
        const offset: usize = @intCast(self.view_cache_request_offset.load(.acquire));
        const publish_lock_start_ns = std.time.nanoTimestamp();
        @import("view_cache.zig").updateViewCacheNoLockTagged(self, self.output_generation.load(.acquire), offset, "transport_pending_offset");
        publish_lock_hold_ns.* += std.time.nanoTimestamp() - publish_lock_start_ns;
    }
}

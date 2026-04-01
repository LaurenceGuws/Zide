const std = @import("std");
const terminal_publication = @import("../publication/terminal_publication.zig");

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
        _ = queued_bytes;
        _ = parse_lock_hold_ns;
        _ = input_pressure;
        self.control.last_parse_log_ms = end_ms;
        _ = elapsed_ms;
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
    _ = start_ms;
    if (had_data) {
        const publish_lock_start_ns = std.time.nanoTimestamp();
        terminal_publication.publishCurrentViewLocked(self, "transport_poll_publish");
        publish_lock_hold_ns.* += std.time.nanoTimestamp() - publish_lock_start_ns;
    }
    if (processed > 0) _ = terminal_publication.takeAltExitPending(self);
    if (processed > 0) {
        const end_ms = std.time.milliTimestamp();
        _ = parse_lock_hold_ns;
        _ = input_pressure;
        self.control.last_parse_log_ms = end_ms;
    }
    if (self.publication.view_cache_pending.load(.acquire)) {
        const publish_lock_start_ns = std.time.nanoTimestamp();
        _ = terminal_publication.applyPendingViewRefreshLocked(self, "transport_pending_offset");
        publish_lock_hold_ns.* += std.time.nanoTimestamp() - publish_lock_start_ns;
    }
}

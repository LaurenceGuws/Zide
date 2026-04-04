const std = @import("std");
const publication_flow = @import("../publication/publication_flow.zig");
const protocol_execution = @import("../session/protocol_execution.zig");

pub fn publishPtyPollResult(self: anytype, had_data: bool, processed: usize, input_pressure: bool, queued_bytes: usize, parse_lock_hold_ns: i128, publish_lock_hold_ns: *i128, start_ms: i64) void {
    var exec = protocol_execution.ProtocolExecution.init(self, &self.core);
    if (exec.shouldPublishPollUpdate(had_data)) {
        const publish_lock_start_ns = std.time.nanoTimestamp();
        self.session.control.state_mutex.lock();
        _ = exec.publishPollUpdate(had_data, "pty_poll_publish", "pty_pending_offset");
        self.session.control.state_mutex.unlock();
        publish_lock_hold_ns.* += std.time.nanoTimestamp() - publish_lock_start_ns;
    }

    if (processed > 0) {
        const end_ms = std.time.milliTimestamp();
        const elapsed_ms = @as(f64, @floatFromInt(end_ms - start_ms));
        _ = queued_bytes;
        _ = parse_lock_hold_ns;
        _ = input_pressure;
        self.session.control.last_parse_log_ms = end_ms;
        _ = elapsed_ms;
    }

    self.session.runtime.io_mutex.lock();
    if (self.session.runtime.io_buffer.items.len > self.session.runtime.io_read_offset) {
        exec.markOutputPending();
    }
    self.session.runtime.io_mutex.unlock();
}

pub fn publishTransportPollResult(self: anytype, had_data: bool, processed: usize, input_pressure: bool, parse_lock_hold_ns: i128, publish_lock_hold_ns: *i128, start_ms: i64) void {
    _ = start_ms;
    var exec = protocol_execution.ProtocolExecution.init(self, &self.core);
    if (exec.shouldPublishPollUpdate(had_data)) {
        const publish_lock_start_ns = std.time.nanoTimestamp();
        _ = exec.publishPollUpdate(had_data, "transport_poll_publish", "transport_pending_offset");
        publish_lock_hold_ns.* += std.time.nanoTimestamp() - publish_lock_start_ns;
    }
    publication_flow.noteProcessedOutput(self, processed);
    if (processed > 0) {
        const end_ms = std.time.milliTimestamp();
        _ = parse_lock_hold_ns;
        _ = input_pressure;
        self.session.control.last_parse_log_ms = end_ms;
    }
}

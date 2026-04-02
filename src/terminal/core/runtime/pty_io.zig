const std = @import("std");
const terminal_transport = @import("terminal_transport.zig");
const publication_flow = @import("../publication/publication_flow.zig");
const pty_poll_publication = @import("pty_poll_publication.zig");
const pty_poll_processing = @import("pty_poll_processing.zig");

pub fn poll(self: anytype) !void {
    const input_pressure = self.control.input_pressure.load(.acquire);
    if (self.runtime.read_thread != null) {
        if (self.runtime.parse_thread != null) {
            _ = publication_flow.clearPublishedOutputPending(self);
            return;
        }
        _ = publication_flow.clearPublishedOutputPending(self);
        var result = pty_poll_processing.processBufferedPtyOutput(self, input_pressure);
        pty_poll_publication.publishPtyPollResult(
            self,
            result.had_data,
            result.processed,
            input_pressure,
            result.queued_bytes,
            result.parse_lock_hold_ns,
            &result.publish_lock_hold_ns,
            result.start_ms,
        );
        return;
    }

    if (terminal_transport.Transport.fromSession(self)) |transport| {
        var result = try pty_poll_processing.processExternalTransportOutput(self, transport, input_pressure);
        pty_poll_publication.publishTransportPollResult(
            self,
            result.had_data,
            result.processed,
            input_pressure,
            result.parse_lock_hold_ns,
            &result.publish_lock_hold_ns,
            result.start_ms,
        );
    }
}

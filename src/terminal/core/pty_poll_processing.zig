const std = @import("std");
const parser_mod = @import("../parser/parser.zig");
const app_logger = @import("../../app_logger.zig");
const io_threads = @import("io_threads.zig");

pub const PtyPollResult = struct {
    queued_bytes: usize,
    had_data: bool,
    processed: usize,
    parse_lock_hold_ns: i128,
    publish_lock_hold_ns: i128,
    start_ms: i64,
};

pub const TransportPollResult = struct {
    had_data: bool,
    processed: usize,
    parse_lock_hold_ns: i128,
    publish_lock_hold_ns: i128,
    start_ms: i64,
};

pub fn processBufferedPtyOutput(self: anytype, input_pressure: bool) PtyPollResult {
    var queued_bytes: usize = 0;
    self.io_mutex.lock();
    if (self.io_buffer.items.len > self.io_read_offset) {
        queued_bytes = self.io_buffer.items.len - self.io_read_offset;
    }
    self.io_mutex.unlock();

    var max_bytes_per_poll: usize = if (input_pressure) 32 * 1024 else 64 * 1024;
    var max_ms: i64 = if (input_pressure) 1 else 2;
    if (queued_bytes >= 8 * 1024 * 1024) {
        max_bytes_per_poll = if (input_pressure) 256 * 1024 else 2 * 1024 * 1024;
        max_ms = if (input_pressure) 4 else 16;
    } else if (queued_bytes >= 1024 * 1024) {
        max_bytes_per_poll = if (input_pressure) 128 * 1024 else 512 * 1024;
        max_ms = if (input_pressure) 2 else 8;
    }

    const start_ms = std.time.milliTimestamp();
    var processed: usize = 0;
    var had_data = false;
    var temp: [4096]u8 = undefined;
    var parse_lock_hold_ns: i128 = 0;
    const publish_lock_hold_ns: i128 = 0;

    while (processed < max_bytes_per_poll and std.time.milliTimestamp() - start_ms < max_ms) {
        var chunk_len: usize = 0;
        self.io_mutex.lock();
        const available = if (self.io_buffer.items.len > self.io_read_offset)
            self.io_buffer.items.len - self.io_read_offset
        else
            0;
        if (available > 0) {
            chunk_len = @min(temp.len, available);
            std.mem.copyForwards(u8, temp[0..chunk_len], self.io_buffer.items[self.io_read_offset .. self.io_read_offset + chunk_len]);
            self.io_read_offset += chunk_len;
            had_data = true;
            if (self.io_read_offset >= self.io_buffer.items.len) {
                self.io_buffer.items.len = 0;
                self.io_read_offset = 0;
            } else if (self.io_read_offset > 64 * 1024 and self.io_read_offset > self.io_buffer.items.len / 2) {
                const remaining = self.io_buffer.items.len - self.io_read_offset;
                std.mem.copyForwards(u8, self.io_buffer.items[0..remaining], self.io_buffer.items[self.io_read_offset..self.io_buffer.items.len]);
                self.io_buffer.items.len = remaining;
                self.io_read_offset = 0;
            }
        }
        self.io_mutex.unlock();

        if (chunk_len == 0) break;

        const parse_lock_start_ns = std.time.nanoTimestamp();
        self.state_mutex.lock();
        self.core.parser.handleSlice(parser_mod.Parser.SessionFacade.from(self), temp[0..chunk_len]);
        self.state_mutex.unlock();
        parse_lock_hold_ns += std.time.nanoTimestamp() - parse_lock_start_ns;
        processed += chunk_len;
        _ = self.output_generation.fetchAdd(1, .acq_rel);
    }

    return .{
        .queued_bytes = queued_bytes,
        .had_data = had_data,
        .processed = processed,
        .parse_lock_hold_ns = parse_lock_hold_ns,
        .publish_lock_hold_ns = publish_lock_hold_ns,
        .start_ms = start_ms,
    };
}

pub fn processExternalTransportOutput(self: anytype, transport: anytype, input_pressure: bool) !TransportPollResult {
    var buf: [262144]u8 = undefined;
    var had_data = false;
    var processed: usize = 0;
    var parse_lock_hold_ns: i128 = 0;
    const publish_lock_hold_ns: i128 = 0;
    const max_bytes_per_poll: usize = 256 * 1024;
    const start_ms = std.time.milliTimestamp();
    const io_log = app_logger.logger("terminal.io");

    while (true) {
        const n = try transport.read(&buf);
        if (n == null or n.? == 0) break;
        had_data = true;
        processed += n.?;
        io_threads.logCsiSequences(io_log, buf[0..n.?]);
        const parse_lock_start_ns = std.time.nanoTimestamp();
        self.core.parser.handleSlice(parser_mod.Parser.SessionFacade.from(self), buf[0..n.?]);
        parse_lock_hold_ns += std.time.nanoTimestamp() - parse_lock_start_ns;
        _ = self.output_generation.fetchAdd(1, .acq_rel);
        if (processed >= max_bytes_per_poll) break;
    }

    _ = input_pressure;
    return .{
        .had_data = had_data,
        .processed = processed,
        .parse_lock_hold_ns = parse_lock_hold_ns,
        .publish_lock_hold_ns = publish_lock_hold_ns,
        .start_ms = start_ms,
    };
}

const std = @import("std");
const builtin = @import("builtin");
const pty_mod = @import("../io/pty.zig");
const app_logger = @import("../../app_logger.zig");
const io_threads = @import("io_threads.zig");

const Pty = pty_mod.Pty;
const PtySize = pty_mod.PtySize;

pub fn start(self: anytype, shell: ?[:0]const u8) !void {
    const size = PtySize{
        .rows = self.primary.grid.rows,
        .cols = self.primary.grid.cols,
        .cell_width = self.cell_width,
        .cell_height = self.cell_height,
    };
    const pty = try Pty.init(self.allocator, size, shell);
    self.pty = pty;
    if (builtin.os.tag == .linux or builtin.os.tag == .macos) {
        self.read_thread_running.store(true, .release);
        self.read_thread = try std.Thread.spawn(.{}, io_threads.readThreadMain, .{self});
        self.parse_thread_running.store(true, .release);
        self.parse_thread = try std.Thread.spawn(.{}, io_threads.parseThreadMain, .{self});
    }
}

pub fn startNoThreads(self: anytype, shell: ?[:0]const u8) !void {
    const size = PtySize{
        .rows = self.primary.grid.rows,
        .cols = self.primary.grid.cols,
        .cell_width = self.cell_width,
        .cell_height = self.cell_height,
    };
    const pty = try Pty.init(self.allocator, size, shell);
    self.pty = pty;
}

pub fn poll(self: anytype) !void {
    const input_pressure = self.input_pressure.load(.acquire);
    if (self.read_thread != null) {
        if (self.parse_thread != null) {
            _ = self.output_pending.swap(false, .acq_rel);
            return;
        }
        const perf_log = app_logger.logger("terminal.parse");
        _ = self.output_pending.swap(false, .acq_rel);
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

            self.state_mutex.lock();
            self.parser.handleSlice(self, temp[0..chunk_len]);
            self.state_mutex.unlock();
            processed += chunk_len;
            _ = self.output_generation.fetchAdd(1, .acq_rel);
        }

        if (had_data) {
            self.state_mutex.lock();
            self.force_full_damage.store(true, .release);
            @import("view_cache.zig").updateViewCacheNoLock(self, self.output_generation.load(.acquire), self.history.scrollOffset());
            self.state_mutex.unlock();
        }

        if (processed > 0 and (perf_log.enabled_file or perf_log.enabled_console)) {
            const end_ms = std.time.milliTimestamp();
            const elapsed_ms = @as(f64, @floatFromInt(end_ms - start_ms));
            const should_log = elapsed_ms >= 8.0 or queued_bytes >= 1024 * 1024 or processed >= 512 * 1024;
            if (should_log and (end_ms - self.last_parse_log_ms) >= 100) {
                self.last_parse_log_ms = end_ms;
                perf_log.logf("parse_ms={d:.2} bytes={d} queued_bytes={d} input_pressure={any}", .{
                    elapsed_ms,
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
            @import("view_cache.zig").updateViewCacheNoLock(self, self.output_generation.load(.acquire), offset);
            self.state_mutex.unlock();
        }
        return;
    }

    if (self.pty) |*pty| {
        const perf_log = app_logger.logger("terminal.parse");
        var buf: [262144]u8 = undefined;
        var had_data = false;
        var processed: usize = 0;
        const max_bytes_per_poll: usize = 256 * 1024;
        const start_ms = std.time.milliTimestamp();
        const io_log = app_logger.logger("terminal.io");
        while (true) {
            const n = try pty.read(&buf);
            if (n == null or n.? == 0) break;
            had_data = true;
            processed += n.?;
            io_threads.logCsiSequences(io_log, buf[0..n.?]);
            self.parser.handleSlice(self, buf[0..n.?]);
            _ = self.output_generation.fetchAdd(1, .acq_rel);
            if (processed >= max_bytes_per_poll) break;
        }
        if (had_data) {
            self.force_full_damage.store(true, .release);
            @import("view_cache.zig").updateViewCacheNoLock(self, self.output_generation.load(.acquire), self.history.scrollOffset());
        }
        if (processed > 0 and self.alt_exit_pending.swap(false, .acq_rel)) {
            const elapsed_ms = @as(f64, @floatFromInt(std.time.milliTimestamp() - start_ms));
            io_log.logf("alt_exit_io_ms={d:.2} bytes={d}", .{ elapsed_ms, processed });
        }
        if (processed > 0 and (perf_log.enabled_file or perf_log.enabled_console)) {
            const end_ms = std.time.milliTimestamp();
            const elapsed_ms = @as(f64, @floatFromInt(end_ms - start_ms));
            const should_log = elapsed_ms >= 8.0 or processed >= 512 * 1024;
            if (should_log and (end_ms - self.last_parse_log_ms) >= 100) {
                self.last_parse_log_ms = end_ms;
                perf_log.logf("parse_ms={d:.2} bytes={d} input_pressure={any}", .{
                    elapsed_ms,
                    processed,
                    input_pressure,
                });
            }
        }
        if (self.view_cache_pending.swap(false, .acq_rel)) {
            const offset: usize = @intCast(self.view_cache_request_offset.load(.acquire));
            @import("view_cache.zig").updateViewCacheNoLock(self, self.output_generation.load(.acquire), offset);
        }
    }
}

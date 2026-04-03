const std = @import("std");
const app_logger = @import("../../../app_logger.zig");
const session_host_types = @import("../session/host_types.zig");

const ProgressState = session_host_types.ProgressState;

pub fn setTitle(self: anytype, text: []const u8) void {
    const log = app_logger.logger("terminal.osc");
    self.core.clearTitleBuffer();
    const max_len: usize = 256;
    const slice = if (text.len > max_len) text[0..max_len] else text;
    self.core.appendTitleSlice(self.allocator, slice) catch |err| {
        log.logf(.warning, "osc title append failed: {s}", .{@errorName(err)});
        return;
    };
    self.core.publishTitleBuffer();
}

pub fn normalizeAndPublishCwd(self: anytype, raw_path: []const u8) void {
    const log = app_logger.logger("terminal.osc");
    self.core.clearCwdBuffer();
    self.core.appendCwdByte(self.allocator, '/') catch |err| {
        log.logf(.warning, "osc cwd normalize root append failed: {s}", .{@errorName(err)});
        return;
    };

    var stack = std.ArrayList(usize).empty;
    defer stack.deinit(self.allocator);

    var it = std.mem.splitScalar(u8, raw_path, '/');
    while (it.next()) |segment| {
        if (segment.len == 0 or std.mem.eql(u8, segment, ".")) continue;
        if (std.mem.eql(u8, segment, "..")) {
            if (stack.pop()) |new_len| {
                self.core.truncateCwdBuffer(new_len);
            } else if (self.core.cwdBufferLen() > 1) {
                self.core.truncateCwdBuffer(1);
            }
            continue;
        }
        if (self.core.cwdBufferLen() > 1 and self.core.cwdBufferLast() != '/') {
            self.core.appendCwdByte(self.allocator, '/') catch |err| {
                log.logf(.warning, "osc cwd normalize slash append failed: {s}", .{@errorName(err)});
                return;
            };
        }
        const segment_start = self.core.cwdBufferLen();
        self.core.appendCwdSlice(self.allocator, segment) catch |err| {
            log.logf(.warning, "osc cwd normalize segment append failed: {s}", .{@errorName(err)});
            return;
        };
        _ = stack.append(self.allocator, segment_start) catch |err| {
            log.logf(.warning, "osc cwd normalize stack append failed: {s}", .{@errorName(err)});
            return;
        };
    }

    if (self.core.cwdBufferLen() == 0) {
        self.core.appendCwdByte(self.allocator, '/') catch |err| {
            log.logf(.warning, "osc cwd normalize final root append failed: {s}", .{@errorName(err)});
            return;
        };
    }
    self.core.publishCwdBuffer();
}

pub fn applyProgress(self: anytype, text: []const u8) void {
    const log = app_logger.logger("terminal.osc");
    if (!std.mem.startsWith(u8, text, "4;")) return;
    if (text.len < 3) return;

    const state_char = text[2];
    const progress_value = if (text.len > 4 and text[3] == ';')
        parsePercent(text[4..])
    else
        null;

    switch (state_char) {
        '0' => self.core.setProgress(.none, null),
        '1' => self.core.setProgress(.set, progress_value orelse 0),
        '2' => self.core.setProgress(.@"error", progress_value),
        '3' => self.core.setProgress(.indeterminate, null),
        '4' => self.core.setProgress(.pause, progress_value),
        else => log.logf(.debug, "osc 9;4 unknown progress state={c}", .{state_char}),
    }
}

fn parsePercent(text: []const u8) ?u8 {
    const parsed = std.fmt.parseUnsigned(u8, text, 10) catch return null;
    return @min(parsed, 100);
}

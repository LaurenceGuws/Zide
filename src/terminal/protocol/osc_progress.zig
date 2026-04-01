const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const session_host_types = @import("../core/session/host_types.zig");

const ProgressState = session_host_types.ProgressState;

pub fn parseProgress(self: anytype, text: []const u8) void {
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

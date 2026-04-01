const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const session_host_types = @import("../core/session/session_host_types.zig");

const ProgressState = session_host_types.ProgressState;

pub const SessionFacade = struct {
    ctx: *anyopaque,
    set_progress_fn: *const fn (ctx: *anyopaque, state: ProgressState, value: ?u8) void,

    pub fn from(session: anytype) SessionFacade {
        const SessionPtr = @TypeOf(session);
        return .{
            .ctx = @ptrCast(session),
            .set_progress_fn = struct {
                fn call(ctx: *anyopaque, state: ProgressState, value: ?u8) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.core.setProgress(state, value);
                }
            }.call,
        };
    }

    pub fn setProgress(self: *const SessionFacade, state: ProgressState, value: ?u8) void {
        self.set_progress_fn(self.ctx, state, value);
    }
};

pub fn parseProgress(session: SessionFacade, text: []const u8) void {
    const log = app_logger.logger("terminal.osc");
    if (!std.mem.startsWith(u8, text, "4;")) return;
    if (text.len < 3) return;

    const state_char = text[2];
    const progress_value = if (text.len > 4 and text[3] == ';')
        parsePercent(text[4..])
    else
        null;

    switch (state_char) {
        '0' => session.setProgress(.none, null),
        '1' => session.setProgress(.set, progress_value orelse 0),
        '2' => session.setProgress(.@"error", progress_value),
        '3' => session.setProgress(.indeterminate, null),
        '4' => session.setProgress(.pause, progress_value),
        else => log.logf(.debug, "osc 9;4 unknown progress state={c}", .{state_char}),
    }
}

fn parsePercent(text: []const u8) ?u8 {
    const parsed = std.fmt.parseUnsigned(u8, text, 10) catch return null;
    return @min(parsed, 100);
}

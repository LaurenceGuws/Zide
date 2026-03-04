const std = @import("std");
const app_state_mod = @import("app_state.zig");

pub const AppMode = app_state_mod.AppMode;
const AppState = app_state_mod.AppState;

pub fn run(allocator: std.mem.Allocator, comptime app_mode: AppMode) !void {
    var app = try AppState.initFocused(allocator, app_mode);
    defer app.deinit();

    try app.run();
}


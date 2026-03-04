const std = @import("std");
const app_bootstrap = @import("bootstrap.zig");
const mode_build = @import("mode_build.zig");
const app_runner = @import("runner.zig");
const app_signals = @import("signals.zig");
const app_state_mod = @import("app_state.zig");

pub const AppMode = app_state_mod.AppMode;
const AppState = app_state_mod.AppState;

pub fn runWithMode(allocator: std.mem.Allocator, app_mode: AppMode) !void {
    const effective_mode = mode_build.effectiveMode(app_mode);
    var app = try AppState.init(allocator, effective_mode);
    defer app.deinit();

    try app.run();
}

pub fn runFromArgs(allocator: std.mem.Allocator) !void {
    const app_mode = app_bootstrap.parseAppMode(allocator);
    try runWithMode(allocator, app_mode);
}

pub fn runMain() !void {
    try app_runner.runWithGpa(struct {
        fn call(allocator: std.mem.Allocator) !void {
            app_signals.install();
            try runFromArgs(allocator);
        }
    }.call);
}

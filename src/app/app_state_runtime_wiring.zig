const std = @import("std");
const app_types = @import("app_state_types.zig");
const mode_build = @import("mode_build.zig");
const app_deinit_runtime = @import("deinit_runtime.zig");
const app_init_runtime = @import("init_runtime.zig");
const app_new_terminal_runtime = @import("new_terminal_runtime.zig");
const app_run_entry_hooks_runtime = @import("run_entry_hooks_runtime.zig");

pub const AppMode = app_types.AppMode;

pub fn init(comptime AppStateT: type, allocator: std.mem.Allocator, app_mode: AppMode) !*AppStateT {
    return try app_init_runtime.init(AppStateT, allocator, app_mode);
}

pub fn initFocused(comptime AppStateT: type, allocator: std.mem.Allocator, comptime app_mode: AppMode) !*AppStateT {
    return try app_init_runtime.initFocused(AppStateT, allocator, app_mode);
}

pub fn deinit(state: anytype) void {
    app_deinit_runtime.handle(state);
}

pub fn newEditor(state: anytype) !void {
    if (comptime mode_build.focused_mode == .terminal) return error.UnsupportedMode;
    const app_new_editor_runtime = @import("editor/new_editor_runtime.zig");
    try app_new_editor_runtime.handle(state);
}

pub fn openFile(state: anytype, path: []const u8) !void {
    if (comptime mode_build.focused_mode == .terminal) return error.UnsupportedMode;
    const app_open_file_runtime = @import("editor/open_file_runtime.zig");
    try app_open_file_runtime.open(state, path);
}

pub fn openFileAt(state: anytype, path: []const u8, line_1: usize, col_1: ?usize) !void {
    if (comptime mode_build.focused_mode == .terminal) return error.UnsupportedMode;
    const app_open_file_runtime = @import("editor/open_file_runtime.zig");
    try app_open_file_runtime.openAt(state, path, line_1, col_1);
}

pub fn newTerminal(state: anytype) !void {
    try app_new_terminal_runtime.handle(state);
}

pub fn run(state: anytype) !void {
    try app_run_entry_hooks_runtime.run(state);
}

pub fn runFocused(state: anytype, comptime app_mode: AppMode) !void {
    try app_run_entry_hooks_runtime.runFocused(state, app_mode);
}

const app_run_mode_init = @import("run_mode_init.zig");
const app_editor_seed = @import("editor_seed.zig");
const app_terminal_tab_bar_sync_runtime = @import("terminal_tab_bar_sync_runtime.zig");
const app_terminal_tabs_runtime = @import("terminal_tabs_runtime.zig");

pub fn handle(state: anytype) !void {
    try app_run_mode_init.initialize(
        state.app_mode,
        state.perf_mode,
        state.perf_file_path,
        @ptrCast(state),
        .{
            .terminal_tab_count = struct {
                fn call(raw: *anyopaque) usize {
                    const s = @as(@TypeOf(state), @ptrCast(@alignCast(raw)));
                    return app_terminal_tabs_runtime.count(s.app_mode, s.terminal_workspace, s.terminals.items.len);
                }
            }.call,
            .new_terminal = struct {
                fn call(raw: *anyopaque) !void {
                    const s = @as(@TypeOf(state), @ptrCast(@alignCast(raw)));
                    try s.newTerminal();
                }
            }.call,
            .sync_terminal_mode_tab_bar = struct {
                fn call(raw: *anyopaque) !void {
                    const s = @as(@TypeOf(state), @ptrCast(@alignCast(raw)));
                    try app_terminal_tab_bar_sync_runtime.syncIfWorkspace(s);
                }
            }.call,
            .open_file = struct {
                fn call(raw: *anyopaque, path: []const u8) !void {
                    const s = @as(@TypeOf(state), @ptrCast(@alignCast(raw)));
                    try s.openFile(path);
                }
            }.call,
            .new_editor = struct {
                fn call(raw: *anyopaque) !void {
                    const s = @as(@TypeOf(state), @ptrCast(@alignCast(raw)));
                    try s.newEditor();
                }
            }.call,
            .seed_default_welcome_buffer = struct {
                fn call(raw: *anyopaque) !void {
                    const s = @as(@TypeOf(state), @ptrCast(@alignCast(raw)));
                    if (s.editors.items.len > 0) {
                        const editor = s.editors.items[0];
                        try app_editor_seed.seedDefaultWelcomeBuffer(editor);
                    }
                }
            }.call,
        },
    );
}

pub fn handleFocused(state: anytype, comptime app_mode: @import("bootstrap.zig").AppMode) !void {
    try app_run_mode_init.initialize(
        app_mode,
        state.perf_mode,
        state.perf_file_path,
        @ptrCast(state),
        .{
            .terminal_tab_count = struct {
                fn call(raw: *anyopaque) usize {
                    const s = @as(@TypeOf(state), @ptrCast(@alignCast(raw)));
                    return app_terminal_tabs_runtime.count(app_mode, s.terminal_workspace, s.terminals.items.len);
                }
            }.call,
            .new_terminal = struct {
                fn call(raw: *anyopaque) !void {
                    const s = @as(@TypeOf(state), @ptrCast(@alignCast(raw)));
                    try s.newTerminal();
                }
            }.call,
            .sync_terminal_mode_tab_bar = struct {
                fn call(raw: *anyopaque) !void {
                    const s = @as(@TypeOf(state), @ptrCast(@alignCast(raw)));
                    try app_terminal_tab_bar_sync_runtime.syncIfWorkspace(s);
                }
            }.call,
            .open_file = struct {
                fn call(raw: *anyopaque, path: []const u8) !void {
                    const s = @as(@TypeOf(state), @ptrCast(@alignCast(raw)));
                    try s.openFile(path);
                }
            }.call,
            .new_editor = struct {
                fn call(raw: *anyopaque) !void {
                    const s = @as(@TypeOf(state), @ptrCast(@alignCast(raw)));
                    try s.newEditor();
                }
            }.call,
            .seed_default_welcome_buffer = struct {
                fn call(raw: *anyopaque) !void {
                    const s = @as(@TypeOf(state), @ptrCast(@alignCast(raw)));
                    if (s.editors.items.len > 0) {
                        const editor = s.editors.items[0];
                        try app_editor_seed.seedDefaultWelcomeBuffer(editor);
                    }
                }
            }.call,
        },
    );
}

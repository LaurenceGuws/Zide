const app_run_mode_init = @import("run_mode_init.zig");
const app_terminal_tab_bar_sync_runtime = @import("terminal/terminal_tab_bar_sync_runtime.zig");
const app_terminal_tabs_runtime = @import("terminal/terminal_tabs_runtime.zig");
const app_modes = @import("modes/mod.zig");

pub fn handle(state: anytype) !void {
    try handleWithMode(state, null);
}

pub fn handleFocused(state: anytype, comptime app_mode: @import("bootstrap.zig").AppMode) !void {
    try handleWithMode(state, app_mode);
}

fn handleWithMode(
    state: anytype,
    comptime forced_mode: ?@import("bootstrap.zig").AppMode,
) !void {
    const app_mode = if (comptime forced_mode) |mode| mode else state.app_mode;

    var runtime_state = struct {
        app_mode: @TypeOf(app_mode),
        state: @TypeOf(state),
    }{
        .app_mode = app_mode,
        .state = state,
    };

    try app_run_mode_init.initialize(
        app_mode,
        state.perf_mode,
        state.perf_file_path,
        @ptrCast(&runtime_state),
        .{
            .terminal_tab_count = struct {
                fn call(raw: *anyopaque) usize {
                    const rs = @as(*@TypeOf(runtime_state), @ptrCast(@alignCast(raw)));
                    const s = rs.state;
                    return app_terminal_tabs_runtime.count(rs.app_mode, s.terminal_workspace, s.terminals.items.len);
                }
            }.call,
            .new_terminal = struct {
                fn call(raw: *anyopaque) !void {
                    const rs = @as(*@TypeOf(runtime_state), @ptrCast(@alignCast(raw)));
                    const s = rs.state;
                    try s.newTerminal();
                }
            }.call,
            .sync_terminal_mode_tab_bar = struct {
                fn call(raw: *anyopaque) !void {
                    const rs = @as(*@TypeOf(runtime_state), @ptrCast(@alignCast(raw)));
                    const s = rs.state;
                    try app_terminal_tab_bar_sync_runtime.syncIfWorkspace(s);
                }
            }.call,
            .open_file = struct {
                fn call(raw: *anyopaque, path: []const u8) !void {
                    const rs = @as(*@TypeOf(runtime_state), @ptrCast(@alignCast(raw)));
                    const s = rs.state;
                    try s.openFile(path);
                }
            }.call,
            .new_editor = struct {
                fn call(raw: *anyopaque) !void {
                    const rs = @as(*@TypeOf(runtime_state), @ptrCast(@alignCast(raw)));
                    const s = rs.state;
                    try s.newEditor();
                }
            }.call,
            .seed_default_welcome_buffer = struct {
                fn call(raw: *anyopaque) !void {
                    if (comptime forced_mode != null and !app_modes.ide.supportsEditorSurface(forced_mode.?)) return;
                    const rs = @as(*@TypeOf(runtime_state), @ptrCast(@alignCast(raw)));
                    const s = rs.state;
                    if (s.editors.items.len > 0) {
                        const app_editor_seed = @import("editor_seed.zig");
                        const editor = s.editors.items[0];
                        try app_editor_seed.seedDefaultWelcomeBuffer(editor);
                    }
                }
            }.call,
        },
    );
}

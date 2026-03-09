const std = @import("std");
const app_active_view_runtime = @import("active_view_runtime.zig");
const app_editor_frame_hooks_runtime = @import("editor_frame_hooks_runtime.zig");
const app_bootstrap = @import("bootstrap.zig");
const app_modes = @import("modes/mod.zig");
const app_terminal_tab_bar_sync_runtime = @import("terminal_tab_bar_sync_runtime.zig");
const app_shell = @import("../app_shell.zig");
const shared_types = @import("../types/mod.zig");

const Shell = app_shell.Shell;
const layout_types = shared_types.layout;
const input_types = shared_types.input;
const ActiveMode = app_modes.ide.ActiveMode;

pub fn handle(
    allocator: std.mem.Allocator,
    search_panel_active: *bool,
    search_panel_query: *std.ArrayList(u8),
    editors: anytype,
    active_tab: usize,
    app_mode: app_bootstrap.AppMode,
    active_kind: ActiveMode,
    editor_cluster_cache: anytype,
    editor_wrap: bool,
    frame_shell: *Shell,
    layout: layout_types.WidgetLayout,
    mouse: input_types.MousePos,
    frame_input_batch: *input_types.InputBatch,
    perf_mode: bool,
    perf_frames_done: *u64,
    perf_frames_total: u64,
    perf_scroll_delta: i32,
    editor_render_cache: anytype,
    editor_highlight_budget: ?usize,
    editor_width_budget: ?usize,
    editor_input_state: app_editor_frame_hooks_runtime.InputState,
    show_terminal: bool,
    terminal_workspace: anytype,
    terminals: anytype,
    terminal_widgets: anytype,
    tab_bar_dragging: bool,
    frame_suppress_terminal_shortcuts: bool,
    frame_terminal_close_modal_active: bool,
    terminal_allocator: std.mem.Allocator,
    at: f64,
    needs_redraw: *bool,
    metrics: anytype,
    state: anytype,
) !void {
    const State = @TypeOf(state);
    try app_active_view_runtime.handle(
        allocator,
        search_panel_active,
        search_panel_query,
        editors,
        active_tab,
        app_mode,
        active_kind,
        editor_cluster_cache,
        editor_wrap,
        frame_shell,
        layout,
        mouse,
        frame_input_batch,
        perf_mode,
        perf_frames_done,
        perf_frames_total,
        perf_scroll_delta,
        editor_render_cache,
        editor_highlight_budget,
        editor_width_budget,
        editor_input_state,
        show_terminal,
        terminal_workspace,
        terminals,
        terminal_widgets,
        tab_bar_dragging,
        frame_suppress_terminal_shortcuts,
        frame_terminal_close_modal_active,
        terminal_allocator,
        at,
        needs_redraw,
        metrics,
        @ptrCast(state),
        .{
            .open_file = struct {
                fn call(raw: *anyopaque, path: []const u8) !void {
                    const s: State = @ptrCast(@alignCast(raw));
                    try s.openFile(path);
                }
            }.call,
            .open_file_at = struct {
                fn call(raw: *anyopaque, path: []const u8, line_1: usize, col_1: ?usize) !void {
                    const s: State = @ptrCast(@alignCast(raw));
                    try s.openFileAt(path, line_1, col_1);
                }
            }.call,
            .sync_terminal_tab_bar = struct {
                fn call(raw: *anyopaque) !void {
                    const s: State = @ptrCast(@alignCast(raw));
                    try app_terminal_tab_bar_sync_runtime.syncIfWorkspace(s);
                }
            }.call,
        },
    );
}

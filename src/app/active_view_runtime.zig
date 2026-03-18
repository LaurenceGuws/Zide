const std = @import("std");
const app_bootstrap = @import("bootstrap.zig");
const app_modes = @import("modes/mod.zig");
const app_path_prompt_frame_runtime = @import("editor/path_prompt_frame_runtime.zig");
const app_search_panel_frame_runtime = @import("search/search_panel_frame_runtime.zig");
const app_editor_frame_hooks_runtime = @import("editor/editor_frame_hooks_runtime.zig");
const app_visible_terminal_frame_hooks_runtime = @import("terminal/visible_terminal_frame_hooks_runtime.zig");
const app_shell = @import("../app_shell.zig");
const shared_types = @import("../types/mod.zig");
const widgets = @import("../ui/widgets.zig");

const layout_types = shared_types.layout;
const input_types = shared_types.input;
const ActiveMode = app_modes.ide.ActiveMode;
const Shell = app_shell.Shell;
const EditorClusterCache = widgets.EditorClusterCache;
const TerminalWidget = widgets.TerminalWidget;

pub const Hooks = struct {
    open_file: *const fn (*anyopaque, []const u8) anyerror!void,
    open_file_at: *const fn (*anyopaque, []const u8, usize, ?usize) anyerror!void,
    force_close_active_editor: *const fn (*anyopaque) anyerror!bool,
    sync_terminal_tab_bar: *const fn (*anyopaque) anyerror!void,
};

pub fn handle(
    allocator: std.mem.Allocator,
    path_prompt: anytype,
    search_panel_active: *bool,
    search_panel_select_all: *bool,
    search_panel_query: *std.ArrayList(u8),
    editors: anytype,
    active_tab: usize,
    tab_bar: anytype,
    app_mode: app_bootstrap.AppMode,
    active_kind: ActiveMode,
    editor_cluster_cache: *EditorClusterCache,
    editor_wrap: bool,
    shell: *Shell,
    layout: layout_types.WidgetLayout,
    mouse: input_types.MousePos,
    input_batch: *input_types.InputBatch,
    perf_mode: bool,
    perf_frames_done: *u64,
    perf_frames_total: u64,
    perf_scroll_delta: i32,
    editor_render_cache: anytype,
    editor_highlight_budget: ?usize,
    editor_width_budget: ?usize,
    editor_input_state: app_editor_frame_hooks_runtime.InputState,
    terminal_scrollbar_dragging: *bool,
    terminal_scrollbar_grab_offset: *f32,
    terminal_scrollbar_hovered: *bool,
    show_terminal: bool,
    terminal_workspace: anytype,
    terminals: anytype,
    terminal_widgets: []TerminalWidget,
    tab_bar_dragging: bool,
    suppress_terminal_shortcuts: bool,
    terminal_close_modal_active: bool,
    terminal_allocator: std.mem.Allocator,
    now: f64,
    needs_redraw: *bool,
    metrics: anytype,
    ctx: *anyopaque,
    hooks: Hooks,
) !void {
    const path_prompt_result = try app_path_prompt_frame_runtime.handle(
        allocator,
        shell,
        path_prompt,
        editors,
        active_tab,
        tab_bar,
        input_batch,
        ctx,
        .{
            .open_file = hooks.open_file,
            .force_close_active_editor = hooks.force_close_active_editor,
        },
    );
    if (path_prompt_result.clear_editor_cluster_cache) editor_cluster_cache.clear();
    if (path_prompt_result.needs_redraw) needs_redraw.* = true;
    if (path_prompt_result.note_input) metrics.noteInput(now);
    const path_prompt_consumed_input = path_prompt_result.consumed_input;

    var search_panel_consumed_input = false;
    if (!path_prompt_consumed_input) {
        const search_panel_result = try app_search_panel_frame_runtime.handle(
            allocator,
            shell,
            search_panel_active,
            search_panel_select_all,
            search_panel_query,
            editors,
            active_tab,
            tab_bar,
            input_batch,
        );
        if (search_panel_result.clear_editor_cluster_cache) editor_cluster_cache.clear();
        if (search_panel_result.needs_redraw) needs_redraw.* = true;
        if (search_panel_result.note_input) metrics.noteInput(now);
        search_panel_consumed_input = search_panel_result.consumed_input;
    }

    const editor_frame_result = try app_editor_frame_hooks_runtime.handle(
        app_mode,
        active_kind,
        editors,
        active_tab,
        tab_bar,
        editor_cluster_cache,
        editor_wrap,
        shell,
        layout,
        mouse,
        input_batch,
        path_prompt_consumed_input or search_panel_consumed_input,
        perf_mode,
        perf_frames_done.*,
        perf_frames_total,
        perf_scroll_delta,
        now,
        editor_render_cache,
        editor_highlight_budget,
        editor_width_budget,
        editor_input_state,
    );
    if (editor_frame_result.clear_editor_cluster_cache) editor_cluster_cache.clear();
    if (editor_frame_result.needs_redraw) needs_redraw.* = true;
    if (editor_frame_result.note_input) metrics.noteInput(now);
    if (editor_frame_result.perf_frames_done_inc) perf_frames_done.* +|= 1;

    var runtime_state = struct {
        needs_redraw: *bool,
        metrics: @TypeOf(metrics),
        user_ctx: *anyopaque,
        user_hooks: Hooks,
        terminal_scrollbar_dragging: *bool,
        terminal_scrollbar_grab_offset: *f32,
        terminal_scrollbar_hovered: *bool,
    }{
        .needs_redraw = needs_redraw,
        .metrics = metrics,
        .user_ctx = ctx,
        .user_hooks = hooks,
        .terminal_scrollbar_dragging = terminal_scrollbar_dragging,
        .terminal_scrollbar_grab_offset = terminal_scrollbar_grab_offset,
        .terminal_scrollbar_hovered = terminal_scrollbar_hovered,
    };

    try app_visible_terminal_frame_hooks_runtime.handle(
        app_mode,
        show_terminal,
        terminal_workspace,
        terminals,
        terminal_widgets,
        tab_bar_dragging,
        active_kind,
        shell,
        layout,
        input_batch,
        path_prompt_consumed_input or search_panel_consumed_input,
        suppress_terminal_shortcuts,
        terminal_close_modal_active,
        now,
        terminal_allocator,
        terminal_scrollbar_dragging,
        terminal_scrollbar_grab_offset,
        terminal_scrollbar_hovered,
        @ptrCast(&runtime_state),
        .{
            .open_file = struct {
                fn call(raw: *anyopaque, path: []const u8) !void {
                    const state = @as(*@TypeOf(runtime_state), @ptrCast(@alignCast(raw)));
                    try state.user_hooks.open_file(state.user_ctx, path);
                }
            }.call,
            .open_file_at = struct {
                fn call(raw: *anyopaque, path: []const u8, line_1: usize, col_1: ?usize) !void {
                    const state = @as(*@TypeOf(runtime_state), @ptrCast(@alignCast(raw)));
                    try state.user_hooks.open_file_at(state.user_ctx, path, line_1, col_1);
                }
            }.call,
            .mark_redraw = struct {
                fn call(raw: *anyopaque) void {
                    const state = @as(*@TypeOf(runtime_state), @ptrCast(@alignCast(raw)));
                    state.needs_redraw.* = true;
                }
            }.call,
            .note_input = struct {
                fn call(raw: *anyopaque, ts: f64) void {
                    const state = @as(*@TypeOf(runtime_state), @ptrCast(@alignCast(raw)));
                    state.metrics.noteInput(ts);
                }
            }.call,
            .sync_terminal_tab_bar = struct {
                fn call(raw: *anyopaque) !void {
                    const state = @as(*@TypeOf(runtime_state), @ptrCast(@alignCast(raw)));
                    try state.user_hooks.sync_terminal_tab_bar(state.user_ctx);
                }
            }.call,
        },
    );
}

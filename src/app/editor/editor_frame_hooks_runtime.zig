const app_active_editor_frame = @import("active_editor_frame.zig");
const app_active_editor_runtime = @import("active_editor_runtime.zig");
const app_bootstrap = @import("../bootstrap.zig");
const app_modes = @import("../modes/mod.zig");
const app_editor_input_runtime = @import("editor_input_runtime.zig");
const app_editor_visible_caches_runtime = @import("editor_visible_caches_runtime.zig");
const app_shell = @import("../../app_shell.zig");
const editor_mod = @import("../../editor/editor.zig");
const editor_types = @import("../../editor/types.zig");
const shared_types = @import("../../types/mod.zig");
const widgets = @import("../../ui/widgets.zig");

const layout_types = shared_types.layout;
const input_types = shared_types.input;
const ActiveMode = app_modes.ide.ActiveMode;
const Editor = editor_mod.Editor;
const EditorClusterCache = widgets.EditorClusterCache;
const CursorPos = editor_types.CursorPos;

pub const InputState = struct {
    editor_hscroll_dragging: *bool,
    editor_hscroll_grab_offset: *f32,
    editor_vscroll_dragging: *bool,
    editor_vscroll_grab_offset: *f32,
    editor_dragging: *bool,
    editor_drag_start: *CursorPos,
    editor_drag_rect: *bool,
};

pub fn handle(
    app_mode: app_bootstrap.AppMode,
    active_kind: ActiveMode,
    editors: []*Editor,
    active_tab: usize,
    tab_bar: anytype,
    editor_cluster_cache: *EditorClusterCache,
    editor_wrap: bool,
    shell: *app_shell.Shell,
    layout: layout_types.WidgetLayout,
    mouse: input_types.MousePos,
    input_batch: *input_types.InputBatch,
    search_panel_consumed_input: bool,
    perf_mode: bool,
    perf_frames_done: u64,
    perf_frames_total: u64,
    perf_scroll_delta: i32,
    frame_id: u64,
    now: f64,
    editor_render_cache: anytype,
    editor_highlight_budget: ?usize,
    editor_width_budget: ?usize,
    input_state: InputState,
) !app_active_editor_frame.Result {
    var runtime_state = struct {
        editor_render_cache: @TypeOf(editor_render_cache),
        editor_highlight_budget: ?usize,
        editor_width_budget: ?usize,
        input_state: InputState,
        needs_redraw: bool = false,
        note_input: bool = false,
    }{
        .editor_render_cache = editor_render_cache,
        .editor_highlight_budget = editor_highlight_budget,
        .editor_width_budget = editor_width_budget,
        .input_state = input_state,
    };

    var out = try app_active_editor_frame.handle(
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
        search_panel_consumed_input,
        perf_mode,
        perf_frames_done,
        perf_frames_total,
        perf_scroll_delta,
        now,
        @ptrCast(&runtime_state),
        .{
            .handle_editor_scrollbar_input = struct {
                fn call(
                    route_raw: *anyopaque,
                    widget: *widgets.EditorWidget,
                    editor_shell: *app_shell.Shell,
                    editor_layout: layout_types.WidgetLayout,
                    editor_mouse: input_types.MousePos,
                    editor_input_batch: *input_types.InputBatch,
                    editor_now: f64,
                ) bool {
                    const route = @as(*@TypeOf(runtime_state), @ptrCast(@alignCast(route_raw)));
                    const handled = app_editor_input_runtime.handleScrollbarInput(
                        widget,
                        editor_shell,
                        editor_layout,
                        editor_mouse,
                        editor_input_batch,
                        route.input_state.editor_hscroll_dragging,
                        route.input_state.editor_hscroll_grab_offset,
                        route.input_state.editor_vscroll_dragging,
                        route.input_state.editor_vscroll_grab_offset,
                    );
                    if (handled) {
                        route.needs_redraw = true;
                        route.note_input = true;
                        _ = editor_now;
                    }
                    return handled;
                }
            }.call,
            .handle_editor_mouse_selection_input = struct {
                fn call(
                    route_raw: *anyopaque,
                    widget: *widgets.EditorWidget,
                    editor_shell: *app_shell.Shell,
                    editor_layout: layout_types.WidgetLayout,
                    editor_mouse: input_types.MousePos,
                    editor_input_batch: *input_types.InputBatch,
                    scrollbar_blocking: bool,
                    editor_now: f64,
                ) void {
                    const route = @as(*@TypeOf(runtime_state), @ptrCast(@alignCast(route_raw)));
                    const result = app_editor_input_runtime.handleMouseSelectionInput(
                        widget,
                        editor_shell,
                        editor_layout,
                        editor_mouse,
                        editor_input_batch,
                        scrollbar_blocking,
                        .{
                            .dragging = route.input_state.editor_dragging,
                            .drag_start = route.input_state.editor_drag_start,
                            .drag_rect = route.input_state.editor_drag_rect,
                        },
                    );
                    if (result.needs_redraw) route.needs_redraw = true;
                    if (result.note_input) {
                        route.note_input = true;
                        _ = editor_now;
                    }
                }
            }.call,
        },
    );
    if (runtime_state.needs_redraw) out.needs_redraw = true;
    if (runtime_state.note_input) out.note_input = true;
    const editor = app_active_editor_runtime.fromVisualIndex(tab_bar, editors, active_tab) orelse return out;
    editor.setRuntimeWakeFn(app_shell.requestWake);
    if (editor.applyPendingSearchWork()) {
        out.needs_redraw = true;
    }
    var widget = widgets.EditorWidget.initWithCache(editor, editor_cluster_cache, editor_wrap);
    const view = widget.frameView();
    const visible_lines = if (layout.editor.height > 0 and shell.editorCharHeight() > 0)
        @as(usize, @intFromFloat(layout.editor.height / shell.editorCharHeight())) + 1
    else
        0;
    const start_line = view.scroll_line;
    const end_line = @min(start_line + visible_lines, view.lineCount());
    const published_visible_highlights = editor.applyPendingVisibleHighlightResult(editor_render_cache);
    if (published_visible_highlights) {
        out.needs_redraw = true;
    }
    const visible_highlight_compute_in_flight = editor.visibleHighlightComputeInFlight();
    const pending_visible_highlight_request = editor.hasPendingVisibleHighlightRequest();
    const pending_visible_highlight_result = editor.hasPendingVisibleHighlightResult();
    const visible_highlight_range_incomplete = editor.shouldThrottleVisibleHighlightRange(start_line, end_line, view.highlight_epoch);
    const can_schedule_visible_work =
        !visible_highlight_compute_in_flight and
        !pending_visible_highlight_request and
        !pending_visible_highlight_result;
    const should_schedule_visible_work =
        visible_lines > 0 and
        can_schedule_visible_work and
        visible_highlight_range_incomplete;
    const needs_layout_precompute = app_editor_visible_caches_runtime.needsLayoutPrecompute(
        &widget,
        shell,
        layout,
        editor_render_cache,
    );
    const should_run_visible_precompute =
        should_schedule_visible_work or
        needs_layout_precompute;
    if (should_run_visible_precompute) {
        const scheduled_visible_highlights = app_editor_visible_caches_runtime.precompute(
            &widget,
            shell,
            layout,
            editor_render_cache,
            editor_highlight_budget,
            editor_width_budget,
            frame_id,
            should_schedule_visible_work,
            .{
                .compute_in_flight = visible_highlight_compute_in_flight,
                .pending_request = pending_visible_highlight_request,
                .pending_result = pending_visible_highlight_result,
                .range_incomplete = visible_highlight_range_incomplete,
            },
        );
        if (scheduled_visible_highlights) {
            out.needs_redraw = true;
        }
    }
    return out;
}

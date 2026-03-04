const app_bootstrap = @import("bootstrap.zig");
const app_modes = @import("modes/mod.zig");
const app_shell = @import("../app_shell.zig");
const editor_mod = @import("../editor/editor.zig");
const shared_types = @import("../types/mod.zig");
const widgets = @import("../ui/widgets.zig");

const Editor = editor_mod.Editor;
const EditorWidget = widgets.EditorWidget;
const EditorClusterCache = widgets.EditorClusterCache;
const layout_types = shared_types.layout;
const input_types = shared_types.input;
const ActiveMode = app_modes.ide.ActiveMode;

pub const Result = struct {
    needs_redraw: bool = false,
    note_input: bool = false,
    perf_frames_done_inc: bool = false,
    clear_editor_cluster_cache: bool = false,
};

pub const Hooks = struct {
    handle_editor_scrollbar_input: *const fn (
        *anyopaque,
        *EditorWidget,
        *app_shell.Shell,
        layout_types.WidgetLayout,
        input_types.MousePos,
        *input_types.InputBatch,
        f64,
    ) bool,
    handle_editor_mouse_selection_input: *const fn (
        *anyopaque,
        *EditorWidget,
        *app_shell.Shell,
        layout_types.WidgetLayout,
        input_types.MousePos,
        *input_types.InputBatch,
        bool,
        f64,
    ) void,
    precompute_editor_visible_caches: *const fn (
        *anyopaque,
        *EditorWidget,
        *app_shell.Shell,
        layout_types.WidgetLayout,
    ) void,
};

pub fn handle(
    app_mode: app_bootstrap.AppMode,
    active_kind: ActiveMode,
    editors: []*Editor,
    active_tab: usize,
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
    now: f64,
    ctx: *anyopaque,
    hooks: Hooks,
) !Result {
    var out: Result = .{};
    if (!app_modes.ide.supportsEditorSurface(app_mode) or active_kind != .editor or editors.len == 0) return out;

    const editor_idx = @min(active_tab, editors.len - 1);
    var widget = EditorWidget.initWithCache(editors[editor_idx], editor_cluster_cache, editor_wrap);

    if (!search_panel_consumed_input and try widget.handleInput(shell, layout.editor.height, input_batch)) {
        out.needs_redraw = true;
        out.note_input = true;
        out.clear_editor_cluster_cache = true;
    }

    if (perf_mode and perf_frames_done < perf_frames_total) {
        widget.scrollVisual(shell, perf_scroll_delta);
        out.needs_redraw = true;
        out.note_input = true;
        out.perf_frames_done_inc = true;
    }

    const scrollbar_blocking = hooks.handle_editor_scrollbar_input(
        ctx,
        &widget,
        shell,
        layout,
        mouse,
        input_batch,
        now,
    );
    hooks.handle_editor_mouse_selection_input(
        ctx,
        &widget,
        shell,
        layout,
        mouse,
        input_batch,
        scrollbar_blocking,
        now,
    );
    hooks.precompute_editor_visible_caches(ctx, &widget, shell, layout);

    return out;
}

const app_editor_display_prepare = @import("editor_display_prepare.zig");
const app_logger = @import("../../app_logger.zig");
const runtime_policy = @import("../runtime_policy.zig");
const shared_types = @import("../../types/mod.zig");
const app_shell = @import("../../app_shell.zig");
const widgets = @import("../../ui/widgets.zig");
const editor_draw = @import("../../ui/widgets/editor_widget_draw.zig");
const std = @import("std");

const layout_types = shared_types.layout;
const Shell = app_shell.Shell;
const EditorWidget = widgets.EditorWidget;

pub const HighlightScheduleState = struct {
    compute_in_flight: bool,
    pending_request: bool,
    pending_result: bool,
    range_incomplete: bool,
};

fn visibleLineBudget(editor_shell: *Shell, editor_layout: layout_types.WidgetLayout) usize {
    const visible_lines = @as(usize, @intFromFloat(editor_layout.editor.height / editor_shell.editorCharHeight()));
    return if (visible_lines > 0) visible_lines + 1 else 0;
}

fn highlightBudget(widget: *EditorWidget, editor_shell: *Shell, editor_layout: layout_types.WidgetLayout, editor_highlight_budget: ?usize) usize {
    _ = widget;
    const base_budget = editor_highlight_budget orelse visibleLineBudget(editor_shell, editor_layout);
    return runtime_policy.editorVisibleWorkLineBudget(base_budget, runtime_policy.editorBackgroundIntent());
}

fn runHighlightPrecompute(
    widget: *EditorWidget,
    editor_shell: *Shell,
    editor_layout: layout_types.WidgetLayout,
    editor_render_cache: anytype,
    editor_highlight_budget: ?usize,
) bool {
    if (editor_layout.editor.width <= 0 or editor_layout.editor.height <= 0) return false;
    const budget = highlightBudget(widget, editor_shell, editor_layout, editor_highlight_budget);
    const highlight_scheduled = editor_draw.precomputeHighlightTokens(widget, editor_render_cache, editor_shell, editor_layout.editor.height, budget);
    if (highlight_scheduled and widget.editor.hasPendingVisibleHighlightRequest()) {
        widget.editor.ensureVisibleHighlightWorker();
        widget.editor.signalVisibleHighlightRuntime();
    }
    return highlight_scheduled;
}

fn runLayoutPrecompute(
    widget: *EditorWidget,
    editor_shell: *Shell,
    editor_layout: layout_types.WidgetLayout,
    editor_render_cache: anytype,
    editor_width_budget: ?usize,
) struct {
    visible_lines: usize,
    width_budget: usize,
    width_elapsed_us: i64,
    wrap_elapsed_us: i64,
} {
    if (editor_layout.editor.width <= 0 or editor_layout.editor.height <= 0) {
        return .{
            .visible_lines = 0,
            .width_budget = 0,
            .width_elapsed_us = 0,
            .wrap_elapsed_us = 0,
        };
    }
    const visible_lines = @as(usize, @intFromFloat(editor_layout.editor.height / editor_shell.editorCharHeight()));
    const default_budget = if (visible_lines > 0) visible_lines + 1 else 0;
    const base_budget = editor_width_budget orelse default_budget;
    const width_budget = runtime_policy.editorVisibleWorkLineBudget(base_budget, runtime_policy.editorBackgroundIntent());
    const t_width_start = std.time.nanoTimestamp();
    editor_draw.precomputeLineWidths(widget, editor_render_cache, editor_shell, editor_layout.editor.height, width_budget);
    const width_elapsed_us = @as(i64, @intCast(@divTrunc(std.time.nanoTimestamp() - t_width_start, 1000)));
    const t_wrap_start = std.time.nanoTimestamp();
    editor_draw.precomputeWrapCounts(widget, editor_render_cache, editor_shell, editor_layout.editor.height, width_budget);
    const wrap_elapsed_us = @as(i64, @intCast(@divTrunc(std.time.nanoTimestamp() - t_wrap_start, 1000)));
    return .{
        .visible_lines = visible_lines,
        .width_budget = width_budget,
        .width_elapsed_us = width_elapsed_us,
        .wrap_elapsed_us = wrap_elapsed_us,
    };
}

pub fn needsLayoutPrecompute(
    widget: *EditorWidget,
    editor_shell: *Shell,
    editor_layout: layout_types.WidgetLayout,
    editor_render_cache: anytype,
) bool {
    if (editor_layout.editor.width <= 0 or editor_layout.editor.height <= 0) return false;
    widget.viewport_width = editor_layout.editor.width;
    const view = widget.frameView();
    const visible_budget = visibleLineBudget(editor_shell, editor_layout);
    if (visible_budget == 0) return false;
    const total_lines = view.lineCount();
    if (total_lines == 0) return false;
    const start_line = view.scroll_line;
    const end_line = @min(start_line + visible_budget, total_lines);
    if (editor_render_cache.lineWidthWorkNeeded(start_line, end_line, view.change_tick)) return true;
    if (!view.wrap_enabled) return false;
    const cols = widget.viewportColumns(editor_shell);
    if (cols == 0) return false;
    return editor_render_cache.wrapWorkNeeded(start_line, end_line, cols, view.change_tick);
}

pub fn precompute(
    widget: *EditorWidget,
    editor_shell: *Shell,
    editor_layout: layout_types.WidgetLayout,
    editor_render_cache: anytype,
    editor_highlight_budget: ?usize,
    editor_width_budget: ?usize,
    frame_id: u64,
    run_highlight: bool,
    highlight_state: HighlightScheduleState,
) bool {
    const perf_log = app_logger.logger("editor.perf");
    const intent = runtime_policy.editorBackgroundIntent();
    if (editor_layout.editor.width <= 0 or editor_layout.editor.height <= 0) return false;
    widget.viewport_width = editor_layout.editor.width;
    widget.editor.advanceStartupDeferrals(frame_id);
    if (widget.editor.shouldDeferVisibleCachePrecompute()) {
        perf_log.logFields(.info, "visible_cache_precompute", &.{
            .{ .key = "runtime_kind", .value = .{ .string = runtime_policy.runtimeKindLabel(intent.runtime) } },
            .{ .key = "lifecycle", .value = .{ .string = runtime_policy.lifecycleLabel(intent.lifecycle) } },
            .{ .key = "work_class", .value = .{ .string = runtime_policy.workClassLabel(intent.work_class) } },
            .{ .key = "frame", .value = .{ .unsigned = frame_id } },
            .{ .key = "skipped", .value = .{ .boolean = true } },
            .{ .key = "defer_precompute", .value = .{ .unsigned = widget.editor.visible_cache_precompute_defer_frames } },
            .{ .key = "defer_clusters", .value = .{ .unsigned = widget.editor.cluster_offsets_defer_frames } },
        });
        return false;
    }
    const t_start = std.time.nanoTimestamp();
    app_editor_display_prepare.prepare(widget.editor, editor_render_cache, frame_id);
    const t_highlight_start = std.time.nanoTimestamp();
    const highlight_scheduled = if (run_highlight)
        runHighlightPrecompute(widget, editor_shell, editor_layout, editor_render_cache, editor_highlight_budget)
    else
        false;
    const highlight_elapsed_us = if (run_highlight)
        @as(i64, @intCast(@divTrunc(std.time.nanoTimestamp() - t_highlight_start, 1000)))
    else
        0;
    const layout_metrics = runLayoutPrecompute(widget, editor_shell, editor_layout, editor_render_cache, editor_width_budget);
    const elapsed_us = @as(i64, @intCast(@divTrunc(std.time.nanoTimestamp() - t_start, 1000)));
    perf_log.logFields(.info, "visible_cache_precompute", &.{
        .{ .key = "runtime_kind", .value = .{ .string = runtime_policy.runtimeKindLabel(intent.runtime) } },
        .{ .key = "lifecycle", .value = .{ .string = runtime_policy.lifecycleLabel(intent.lifecycle) } },
        .{ .key = "work_class", .value = .{ .string = runtime_policy.workClassLabel(intent.work_class) } },
        .{ .key = "frame", .value = .{ .unsigned = frame_id } },
        .{ .key = "skipped", .value = .{ .boolean = false } },
        .{ .key = "run_highlight", .value = .{ .boolean = run_highlight } },
        .{ .key = "highlight_compute_in_flight", .value = .{ .boolean = highlight_state.compute_in_flight } },
        .{ .key = "highlight_pending_request", .value = .{ .boolean = highlight_state.pending_request } },
        .{ .key = "highlight_pending_result", .value = .{ .boolean = highlight_state.pending_result } },
        .{ .key = "highlight_range_incomplete", .value = .{ .boolean = highlight_state.range_incomplete } },
        .{ .key = "visible_lines", .value = .{ .unsigned = layout_metrics.visible_lines } },
        .{ .key = "highlight_budget_base", .value = .{ .unsigned = if (run_highlight) editor_highlight_budget orelse visibleLineBudget(editor_shell, editor_layout) else 0 } },
        .{ .key = "highlight_budget", .value = .{ .unsigned = if (run_highlight) highlightBudget(widget, editor_shell, editor_layout, editor_highlight_budget) else 0 } },
        .{ .key = "width_budget_base", .value = .{ .unsigned = editor_width_budget orelse (if (layout_metrics.visible_lines > 0) layout_metrics.visible_lines + 1 else 0) } },
        .{ .key = "width_budget", .value = .{ .unsigned = layout_metrics.width_budget } },
        .{ .key = "highlight_us", .value = .{ .integer = highlight_elapsed_us } },
        .{ .key = "width_us", .value = .{ .integer = layout_metrics.width_elapsed_us } },
        .{ .key = "wrap_us", .value = .{ .integer = layout_metrics.wrap_elapsed_us } },
        .{ .key = "time_us", .value = .{ .integer = elapsed_us } },
    });
    return highlight_scheduled;
}

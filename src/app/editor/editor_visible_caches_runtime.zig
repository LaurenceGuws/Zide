const app_editor_display_prepare = @import("editor_display_prepare.zig");
const app_logger = @import("../../app_logger.zig");
const shared_types = @import("../../types/mod.zig");
const app_shell = @import("../../app_shell.zig");
const widgets = @import("../../ui/widgets.zig");
const editor_draw = @import("../../ui/widgets/editor_widget_draw.zig");
const std = @import("std");

const layout_types = shared_types.layout;
const Shell = app_shell.Shell;
const EditorWidget = widgets.EditorWidget;
const startup_highlight_lines_per_frame: usize = 4;

pub fn precompute(
    widget: *EditorWidget,
    editor_shell: *Shell,
    editor_layout: layout_types.WidgetLayout,
    editor_render_cache: anytype,
    editor_highlight_budget: ?usize,
    editor_width_budget: ?usize,
    frame_id: u64,
) bool {
    const perf_log = app_logger.logger("editor.perf");
    if (editor_layout.editor.width <= 0 or editor_layout.editor.height <= 0) return false;
    widget.editor.advanceStartupDeferrals(frame_id);
    if (widget.editor.shouldDeferVisibleCachePrecompute()) {
        perf_log.logf(
            .info,
            "visible_cache_precompute frame={d} skipped=true defer_precompute={d} defer_clusters={d}",
            .{ frame_id, widget.editor.visible_cache_precompute_defer_frames, widget.editor.cluster_offsets_defer_frames },
        );
        return false;
    }
    const t_start = std.time.nanoTimestamp();
    app_editor_display_prepare.prepare(widget.editor, editor_render_cache, frame_id);
    const visible_lines = @as(usize, @intFromFloat(editor_layout.editor.height / editor_shell.charHeight()));
    const default_budget = if (visible_lines > 0) visible_lines + 1 else 0;
    const configured_highlight_budget = editor_highlight_budget orelse default_budget;
    const highlight_budget = if (widget.editor.shouldThrottleStartupHighlightWarmup())
        @min(configured_highlight_budget, startup_highlight_lines_per_frame)
    else
        configured_highlight_budget;
    const t_highlight_start = std.time.nanoTimestamp();
    const highlight_scheduled = editor_draw.precomputeHighlightTokens(widget, editor_render_cache, editor_shell, editor_layout.editor.height, highlight_budget);
    if (highlight_scheduled and widget.editor.hasPendingVisibleHighlightRequest()) {
        widget.editor.ensureVisibleHighlightWorker();
        widget.editor.signalVisibleHighlightRuntime();
    }
    if (widget.editor.shouldThrottleStartupHighlightWarmup() and !widget.editor.visibleHighlightWorkInFlight()) {
        widget.editor.completeStartupVisibleWarmup();
    }
    const width_budget = editor_width_budget orelse highlight_budget;
    const highlight_elapsed_us = @as(i64, @intCast(@divTrunc(std.time.nanoTimestamp() - t_highlight_start, 1000)));
    const t_width_start = std.time.nanoTimestamp();
    editor_draw.precomputeLineWidths(widget, editor_render_cache, editor_shell, editor_layout.editor.height, width_budget);
    const width_elapsed_us = @as(i64, @intCast(@divTrunc(std.time.nanoTimestamp() - t_width_start, 1000)));
    const t_wrap_start = std.time.nanoTimestamp();
    editor_draw.precomputeWrapCounts(widget, editor_render_cache, editor_shell, editor_layout.editor.height, width_budget);
    const wrap_elapsed_us = @as(i64, @intCast(@divTrunc(std.time.nanoTimestamp() - t_wrap_start, 1000)));
    const elapsed_us = @as(i64, @intCast(@divTrunc(std.time.nanoTimestamp() - t_start, 1000)));
    perf_log.logf(
        .info,
        "visible_cache_precompute frame={d} skipped=false visible_lines={d} highlight_budget={d} width_budget={d} highlight_us={d} width_us={d} wrap_us={d} time_us={d}",
        .{ frame_id, visible_lines, highlight_budget, width_budget, highlight_elapsed_us, width_elapsed_us, wrap_elapsed_us, elapsed_us },
    );
    return highlight_scheduled;
}

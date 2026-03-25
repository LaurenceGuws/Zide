const editor_mod = @import("../../editor/editor.zig");
const editor_render_cache_mod = @import("../../editor/render/cache.zig");
const app_logger = @import("../../app_logger.zig");
const std = @import("std");

const Editor = editor_mod.Editor;
const EditorRenderCache = editor_render_cache_mod.EditorRenderCache;

pub fn prepare(
    editor: *Editor,
    editor_render_cache: *EditorRenderCache,
    frame_id: u64,
) void {
    const perf_log = app_logger.logger("editor.perf");
    const t_start = std.time.nanoTimestamp();
    editor.advanceStartupDeferrals(frame_id);
    const total_lines = editor.lineCount();
    var invalidated = false;
    if (editor.takeHighlightDirtyRange()) |range| {
        const end_line = @min(range.end_line, total_lines);
        editor_render_cache.invalidateHighlightRange(range.start_line, end_line);
        invalidated = true;
    }
    editor.ensureHighlighter();
    const elapsed_us = @as(i64, @intCast(@divTrunc(std.time.nanoTimestamp() - t_start, 1000)));
    const search_counters = editor.searchRuntimeCounters();
    const highlight_counters = editor.highlightRuntimeCounters();
    perf_log.logf(
        .info,
        "display_prepare frame={d} invalidated={any} highlight_pending={any} defer_highlight={d} defer_precompute={d} defer_clusters={d} time_us={d} search_epoch={d} search_async={d} search_sync_fallbacks={d} search_results={d} search_stale={d} search_worker_spawns={d}/{d} highlight_epoch={d} highlight_scheduled={d} highlight_skipped_large={d} highlight_disabled={d} highlight_init={d}/{d}/{d}",
        .{
            frame_id,
            invalidated,
            editor.documentCore().highlight_pending,
            editor.highlight_defer_frames,
            editor.visible_cache_precompute_defer_frames,
            editor.cluster_offsets_defer_frames,
            elapsed_us,
            search_counters.epoch,
            search_counters.scheduled_async,
            search_counters.sync_fallbacks,
            search_counters.results_applied,
            search_counters.stale_results_dropped,
            search_counters.worker_spawns,
            search_counters.worker_spawn_failures,
            highlight_counters.epoch,
            highlight_counters.scheduled,
            highlight_counters.skipped_large_file,
            highlight_counters.disabled_no_language,
            highlight_counters.init_attempts,
            highlight_counters.init_successes,
            highlight_counters.init_failures,
        },
    );
}

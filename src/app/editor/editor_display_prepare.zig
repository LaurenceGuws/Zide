const editor_mod = @import("../../editor/editor.zig");
const editor_render_cache_mod = @import("../../editor/render/cache.zig");
const app_logger = @import("../../app_logger.zig");
const runtime_policy = @import("../runtime_policy.zig");
const std = @import("std");

const Editor = editor_mod.Editor;
const EditorRenderCache = editor_render_cache_mod.EditorRenderCache;

pub fn prepare(
    editor: *Editor,
    editor_render_cache: *EditorRenderCache,
    frame_id: u64,
) void {
    const perf_log = app_logger.logger("editor.perf");
    const intent = runtime_policy.editorBackgroundIntent();
    const t_start = std.time.nanoTimestamp();
    editor.advanceStartupDeferrals(frame_id);
    const total_lines = editor.lineCount();
    var invalidated = false;
    var invalidated_ranges: usize = 0;
    var invalidated_full_document = false;
    if (editor.takeHighlightInvalidationBatch()) |batch| {
        defer editor.allocator.free(batch.ranges);
        if (batch.full_document) {
            editor_render_cache.clearHighlightEntries();
            invalidated = true;
            invalidated_full_document = true;
        } else {
            for (batch.ranges) |range| {
                const end_line = @min(range.end_line, total_lines);
                editor_render_cache.invalidateHighlightRange(range.start_line, end_line);
                invalidated = true;
                invalidated_ranges += 1;
            }
        }
    }
    editor.ensureHighlighter();
    const elapsed_us = @as(i64, @intCast(@divTrunc(std.time.nanoTimestamp() - t_start, 1000)));
    const search_counters = editor.searchRuntimeCounters();
    const highlight_counters = editor.highlightRuntimeCounters();
    perf_log.logFields(.info, "display_prepare", &.{
        .{ .key = "runtime_kind", .value = .{ .string = runtime_policy.runtimeKindLabel(intent.runtime) } },
        .{ .key = "lifecycle", .value = .{ .string = runtime_policy.lifecycleLabel(intent.lifecycle) } },
        .{ .key = "work_class", .value = .{ .string = runtime_policy.workClassLabel(intent.work_class) } },
        .{ .key = "frame", .value = .{ .unsigned = frame_id } },
        .{ .key = "invalidated", .value = .{ .boolean = invalidated } },
        .{ .key = "highlight_invalidated_full_document", .value = .{ .boolean = invalidated_full_document } },
        .{ .key = "highlight_invalidated_ranges", .value = .{ .unsigned = invalidated_ranges } },
        .{ .key = "highlight_pending", .value = .{ .boolean = editor.documentCore().highlight_pending } },
        .{ .key = "defer_highlight", .value = .{ .unsigned = editor.highlight_defer_frames } },
        .{ .key = "defer_precompute", .value = .{ .unsigned = editor.visible_cache_precompute_defer_frames } },
        .{ .key = "defer_clusters", .value = .{ .unsigned = editor.cluster_offsets_defer_frames } },
        .{ .key = "time_us", .value = .{ .integer = elapsed_us } },
        .{ .key = "search_epoch", .value = .{ .unsigned = search_counters.epoch } },
        .{ .key = "search_async", .value = .{ .unsigned = search_counters.scheduled_async } },
        .{ .key = "search_sync_fallbacks", .value = .{ .unsigned = search_counters.sync_fallbacks } },
        .{ .key = "search_results", .value = .{ .unsigned = search_counters.results_applied } },
        .{ .key = "search_stale", .value = .{ .unsigned = search_counters.stale_results_dropped } },
        .{ .key = "search_worker_spawns", .value = .{ .unsigned = search_counters.worker_spawns } },
        .{ .key = "search_worker_spawn_failures", .value = .{ .unsigned = search_counters.worker_spawn_failures } },
        .{ .key = "highlight_epoch", .value = .{ .unsigned = highlight_counters.epoch } },
        .{ .key = "highlight_scheduled", .value = .{ .unsigned = highlight_counters.scheduled } },
        .{ .key = "highlight_skipped_large", .value = .{ .unsigned = highlight_counters.skipped_large_file } },
        .{ .key = "highlight_disabled", .value = .{ .unsigned = highlight_counters.disabled_no_language } },
        .{ .key = "highlight_init_attempts", .value = .{ .unsigned = highlight_counters.init_attempts } },
        .{ .key = "highlight_init_successes", .value = .{ .unsigned = highlight_counters.init_successes } },
        .{ .key = "highlight_init_failures", .value = .{ .unsigned = highlight_counters.init_failures } },
    });
}

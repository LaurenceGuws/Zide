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
    perf_log.logf(
        .info,
        "display_prepare frame={d} invalidated={any} highlight_pending={any} defer_highlight={d} defer_precompute={d} defer_clusters={d} time_us={d}",
        .{
            frame_id,
            invalidated,
            editor.documentCore().highlight_pending,
            editor.highlight_defer_frames,
            editor.visible_cache_precompute_defer_frames,
            editor.cluster_offsets_defer_frames,
            elapsed_us,
        },
    );
}

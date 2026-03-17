const std = @import("std");
const syntax_mod = @import("../syntax.zig");
const selection_mod = @import("../view/selection.zig");
const chrome_geometry_mod = @import("../view/chrome_geometry.zig");
const metrics_mod = @import("../view/metrics.zig");
const runtime_mod = @import("../view/runtime.zig");
const cache_helpers = @import("../../ui/widgets/editor_widget_draw_cache.zig");
const cache_mod = @import("cache.zig");
const app_logger = @import("../../app_logger.zig");
const text_mod = @import("../../ui/widgets/editor_widget_draw_text.zig");

const HighlightToken = syntax_mod.HighlightToken;
const SelectionRange = selection_mod.SelectionRange;

pub const FramePrep = struct {
    gutter_width: f32,
    text_start_x: f32,
    visible_lines: usize,
    cols: usize,
    start_line: usize,
    start_seg: usize,
    total_lines: usize,
    end_line: usize,
};

pub const HighlightPrep = struct {
    tokens: []HighlightToken,
    allocated: bool,
};

pub const PreparedLine = struct {
    line_idx: usize,
    line_start: usize,
    line_end: usize,
    line_len: usize,
    line_text: []const u8,
    cluster_slice: ?[]const u32,
    owned_text: ?[]u8,
    owned_clusters: bool,
    line_width: usize,
    effective_tokens: []HighlightToken,
    selection_ranges: [8]SelectionRange,
    selection_count: usize,
};

pub fn prepareFrame(widget: anytype, shell: anytype, x: f32, height: f32) FramePrep {
    const r = shell.rendererPtr();
    const metrics = chrome_geometry_mod.frameMetrics(x, height, r.uiScaleFactor(), r.char_height);
    const view = widget.frameView();
    return .{
        .gutter_width = metrics.gutter_width,
        .text_start_x = metrics.text_start_x,
        .visible_lines = metrics.visible_lines,
        .cols = widget.viewportColumns(shell),
        .start_line = view.scroll_line,
        .start_seg = view.scroll_row_offset,
        .total_lines = view.lineCount(),
        .end_line = @min(view.scroll_line + metrics.visible_lines + 1, view.lineCount()),
    };
}

pub fn prepareLine(
    widget: anytype,
    shell: anytype,
    view: anytype,
    line_idx: usize,
    highlight_tokens: []const HighlightToken,
    token_idx: *usize,
    scratch: *runtime_mod.LineScratch,
    fallback_tokens_buf: []HighlightToken,
) PreparedLine {
    const line_data = widget.lineData(shell, line_idx, scratch);
    const line_start = view.lineStart(line_idx);
    const line_end = line_start + line_data.len;

    var tokens: []HighlightToken = &[_]HighlightToken{};
    if (highlight_tokens.len > 0) {
        while (token_idx.* < highlight_tokens.len and highlight_tokens[token_idx.*].end <= line_start) {
            token_idx.* += 1;
        }
        var line_token_end = token_idx.*;
        while (line_token_end < highlight_tokens.len and highlight_tokens[line_token_end].start < line_end) {
            line_token_end += 1;
        }
        tokens = @constCast(highlight_tokens[token_idx.*..line_token_end]);
    }

    var effective_tokens = tokens;
    if (tokens.len == 0 and cache_helpers.shouldUseLargeFileFallback(view)) {
        const fallback_count = cache_helpers.buildLargeFileFallbackTokens(line_data.text, line_start, fallback_tokens_buf);
        effective_tokens = fallback_tokens_buf[0..fallback_count];
    }

    var ranges: [8]SelectionRange = undefined;
    var range_count: usize = 0;
    selection_mod.collectSelectionRanges(widget.editor, line_idx, line_data.text, line_data.clusters, &ranges, &range_count);

    const width_cached = line_data.width;
    const line_width = metrics_mod.lineWidthForDisplay(line_data.len, width_cached, range_count > 0);

    const prepared = PreparedLine{
        .line_idx = line_idx,
        .line_start = line_start,
        .line_end = line_end,
        .line_len = line_data.len,
        .line_text = line_data.text,
        .cluster_slice = line_data.clusters,
        .owned_text = line_data.owned_text,
        .owned_clusters = line_data.owned_clusters,
        .line_width = line_width,
        .effective_tokens = effective_tokens,
        .selection_ranges = ranges,
        .selection_count = range_count,
    };
    return prepared;
}

pub fn prepareHighlightRange(view: anytype, allocator: anytype, start_line: usize, end_line: usize) HighlightPrep {
    if (view.highlighter) |highlighter| {
        if (view.lineCount() > 0 and start_line < view.lineCount()) {
            const range_start = view.lineStart(start_line);
            const range_end = if (end_line < view.lineCount()) view.lineStart(end_line) else view.totalLen();
            const tokens_opt: ?[]HighlightToken = highlighter.highlightRange(range_start, range_end, allocator) catch |err| blk: {
                const log = app_logger.logger("editor.draw");
                log.logf(.warning, "highlight range failed start={d} end={d} err={s}", .{ range_start, range_end, @errorName(err) });
                break :blk null;
            };
            if (tokens_opt) |tokens| {
                if (tokens.len > 1) {
                    std.sort.heap(HighlightToken, tokens, {}, text_mod.highlightTokenLessThan);
                }
                return .{ .tokens = tokens, .allocated = true };
            }
        }
    }
    return .{ .tokens = &[_]HighlightToken{}, .allocated = false };
}

pub fn prepareCachedLineTokens(
    cache: *cache_mod.EditorRenderCache,
    view: anytype,
    prepared: *PreparedLine,
    line_text_hash: u64,
    fallback_tokens_buf: []HighlightToken,
) void {
    const tokens = cache.highlightTokens(
        view.highlighter,
        prepared.line_idx,
        prepared.line_start,
        prepared.line_end,
        line_text_hash,
        view.highlight_epoch,
    );
    if (tokens.len > 0) {
        prepared.effective_tokens = tokens;
        return;
    }
    if (prepared.effective_tokens.len == 0 and cache_helpers.shouldUseLargeFileFallback(view)) {
        const fallback_count = cache_helpers.buildLargeFileFallbackTokens(prepared.line_text, prepared.line_start, fallback_tokens_buf);
        prepared.effective_tokens = fallback_tokens_buf[0..fallback_count];
    }
}

pub fn releasePreparedLine(widget: anytype, prepared: *PreparedLine) void {
    var line_data = runtime_mod.LineData{
        .text = prepared.line_text,
        .clusters = prepared.cluster_slice,
        .width = prepared.line_width,
        .len = prepared.line_len,
        .owned_text = prepared.owned_text,
        .owned_clusters = prepared.owned_clusters,
    };
    widget.releaseLineData(&line_data);
}

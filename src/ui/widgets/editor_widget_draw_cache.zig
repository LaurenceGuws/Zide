const std = @import("std");
const syntax_mod = @import("../../editor/syntax.zig");
const layout_mod = @import("../../editor/view/layout.zig");
const metrics_mod = @import("../../editor/view/metrics.zig");
const cache_mod = @import("../../editor/render/cache.zig");

const HighlightToken = syntax_mod.HighlightToken;
const TokenKind = syntax_mod.TokenKind;
const large_file_fallback_threshold_bytes: usize = 8 * 1024 * 1024;

pub fn hashLine(text: []const u8) u64 {
    var h: u64 = 1469598103934665603;
    for (text) |byte| {
        h ^= byte;
        h *%= 1099511628211;
    }
    return h;
}

pub fn shouldUseLargeFileFallback(editor: anytype) bool {
    if (editor.highlighter != null) return false;
    if (editor.totalLen() < large_file_fallback_threshold_bytes) return false;
    return true;
}

fn isIdentStart(ch: u8) bool {
    return (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z') or ch == '_';
}

fn isIdentContinue(ch: u8) bool {
    return isIdentStart(ch) or (ch >= '0' and ch <= '9');
}

fn isDigit(ch: u8) bool {
    return ch >= '0' and ch <= '9';
}

pub fn buildLargeFileFallbackTokens(line_text: []const u8, line_start: usize, out: []HighlightToken) usize {
    var count: usize = 0;
    var i: usize = 0;
    while (i < line_text.len and count < out.len) {
        const ch = line_text[i];
        if ((ch == '/' and i + 1 < line_text.len and line_text[i + 1] == '/') or ch == '#') {
            out[count] = .{
                .start = line_start + i,
                .end = line_start + line_text.len,
                .kind = .comment,
                .priority = 0,
                .conceal = null,
                .url = null,
                .conceal_lines = false,
            };
            count += 1;
            break;
        }
        if (ch == '"') {
            var j = i + 1;
            while (j < line_text.len) : (j += 1) {
                if (line_text[j] == '"' and line_text[j - 1] != '\\') {
                    j += 1;
                    break;
                }
            }
            out[count] = .{
                .start = line_start + i,
                .end = line_start + @min(j, line_text.len),
                .kind = .string,
                .priority = 0,
                .conceal = null,
                .url = null,
                .conceal_lines = false,
            };
            count += 1;
            i = @min(j, line_text.len);
            continue;
        }
        if (isDigit(ch)) {
            var j = i + 1;
            while (j < line_text.len and (isDigit(line_text[j]) or line_text[j] == '_')) : (j += 1) {}
            out[count] = .{
                .start = line_start + i,
                .end = line_start + j,
                .kind = .number,
                .priority = 0,
                .conceal = null,
                .url = null,
                .conceal_lines = false,
            };
            count += 1;
            i = j;
            continue;
        }
        if (isIdentStart(ch)) {
            var j = i + 1;
            while (j < line_text.len and isIdentContinue(line_text[j])) : (j += 1) {}
            i = j;
            continue;
        }
        i += 1;
    }
    return count;
}

pub fn precomputeHighlightTokens(widget: anytype, cache: *cache_mod.EditorRenderCache, shell: anytype, height: f32, budget_lines: usize) void {
    const r = shell.rendererPtr();
    if (budget_lines == 0) return;
    if (height <= 0) return;
    if (widget.editor.highlighter == null) return;
    const total_lines = widget.editor.lineCount();
    if (total_lines == 0) return;
    const visible_lines = @as(usize, @intFromFloat(height / r.char_height));
    if (visible_lines == 0) return;

    const start_line = widget.editor.scroll_line;
    const end_line = @min(start_line + visible_lines + 1, total_lines);
    cache.beginHighlightWork(start_line, end_line, widget.editor.highlight_epoch);

    var line_buf: [4096]u8 = undefined;
    var remaining = budget_lines;
    while (remaining > 0) : (remaining -= 1) {
        const next_line = cache.nextHighlightWorkLine() orelse break;
        const line_len = widget.editor.lineLen(next_line);
        var line_alloc: ?[]u8 = null;
        const line_text = if (line_len <= line_buf.len)
            line_buf[0..widget.editor.getLine(next_line, &line_buf)]
        else blk: {
            const owned = widget.editor.getLineAlloc(next_line) catch break :blk &[_]u8{};
            line_alloc = owned;
            break :blk owned;
        };
        defer if (line_alloc) |owned| widget.editor.allocator.free(owned);

        const line_start = widget.editor.lineStart(next_line);
        const line_end = line_start + line_len;
        const line_text_hash = hashLine(line_text);
        _ = cache.highlightTokens(
            widget.editor.highlighter,
            next_line,
            line_start,
            line_end,
            line_text_hash,
            widget.editor.highlight_epoch,
        );
    }
}

pub fn precomputeLineWidths(widget: anytype, cache: *cache_mod.EditorRenderCache, shell: anytype, height: f32, budget_lines: usize) void {
    const r = shell.rendererPtr();
    if (budget_lines == 0) return;
    if (height <= 0) return;
    const total_lines = widget.editor.lineCount();
    if (total_lines == 0) return;
    const visible_lines = @as(usize, @intFromFloat(height / r.char_height));
    if (visible_lines == 0) return;

    const start_line = widget.editor.scroll_line;
    const end_line = @min(start_line + visible_lines + 1, total_lines);
    cache.beginLineWidthWork(start_line, end_line, widget.editor.change_tick);

    var line_buf: [4096]u8 = undefined;
    var remaining = budget_lines;
    while (remaining > 0) : (remaining -= 1) {
        const next_line = cache.nextLineWidthWorkLine() orelse break;
        const line_len = widget.editor.lineLen(next_line);
        var line_alloc: ?[]u8 = null;
        const line_text = if (line_len <= line_buf.len)
            line_buf[0..widget.editor.getLine(next_line, &line_buf)]
        else blk: {
            const owned = widget.editor.getLineAlloc(next_line) catch break :blk &[_]u8{};
            line_alloc = owned;
            break :blk owned;
        };
        defer if (line_alloc) |owned| widget.editor.allocator.free(owned);

        var cluster_slice: ?[]const u32 = null;
        var cluster_owned = false;
        widget.clusterOffsets(shell, next_line, line_text, &cluster_slice, &cluster_owned);
        defer if (cluster_owned) {
            if (cluster_slice) |clusters| widget.editor.allocator.free(clusters);
        };

        _ = widget.editor.lineWidthCached(next_line, line_text, cluster_slice);
    }
}

pub fn precomputeWrapCounts(widget: anytype, cache: *cache_mod.EditorRenderCache, shell: anytype, height: f32, budget_lines: usize) void {
    const r = shell.rendererPtr();
    if (!widget.wrap_enabled) return;
    if (budget_lines == 0) return;
    if (height <= 0) return;
    const total_lines = widget.editor.lineCount();
    if (total_lines == 0) return;
    const visible_lines = @as(usize, @intFromFloat(height / r.char_height));
    if (visible_lines == 0) return;

    const cols = widget.viewportColumns(shell);
    if (cols == 0) return;
    const start_line = widget.editor.scroll_line;
    const end_line = @min(start_line + visible_lines + 1, total_lines);
    cache.beginWrapWork(start_line, end_line, cols, widget.editor.change_tick);

    var line_buf: [4096]u8 = undefined;
    var remaining = budget_lines;
    while (remaining > 0) : (remaining -= 1) {
        const next_line = cache.nextWrapWorkLine() orelse break;
        const line_len = widget.editor.lineLen(next_line);
        var line_alloc: ?[]u8 = null;
        const line_text = if (line_len <= line_buf.len)
            line_buf[0..widget.editor.getLine(next_line, &line_buf)]
        else blk: {
            const owned = widget.editor.getLineAlloc(next_line) catch break :blk &[_]u8{};
            line_alloc = owned;
            break :blk owned;
        };
        defer if (line_alloc) |owned| widget.editor.allocator.free(owned);

        var cluster_slice: ?[]const u32 = null;
        var cluster_owned = false;
        widget.clusterOffsets(shell, next_line, line_text, &cluster_slice, &cluster_owned);
        defer if (cluster_owned) {
            if (cluster_slice) |clusters| widget.editor.allocator.free(clusters);
        };

        const width_cached = widget.editor.lineWidthCached(next_line, line_text, cluster_slice);
        const line_width = metrics_mod.lineWidthForDisplay(line_len, width_cached, false);
        const count = layout_mod.visualLineCountForWidth(cols, line_width);
        cache.setWrapLineCount(next_line, cols, line_width, count);
    }
}

pub fn hashSegment(
    line_text: []const u8,
    seg_start_byte: usize,
    seg_end_byte: usize,
    ranges: anytype,
    seg_start_col: usize,
    seg_end_col: usize,
    tokens: []const HighlightToken,
    line_start: usize,
    is_current: bool,
    has_cursor: bool,
    cursor_col_vis: usize,
    cursor_seg_start: usize,
) u64 {
    var h: u64 = 1469598103934665603;
    for (line_text[seg_start_byte..seg_end_byte]) |byte| {
        h ^= byte;
        h *%= 1099511628211;
    }
    h ^= @as(u64, @intFromBool(is_current));
    h *%= 1099511628211;
    for (ranges) |range| {
        const sel_start = @max(range.start_col, seg_start_col);
        const sel_end = @min(range.end_col, seg_end_col);
        if (sel_end <= sel_start) continue;
        h ^= @as(u64, sel_start);
        h *%= 1099511628211;
        h ^= @as(u64, sel_end);
        h *%= 1099511628211;
    }
    for (tokens) |token| {
        if (token.end <= line_start) continue;
        const rel_start = if (token.start > line_start) token.start - line_start else 0;
        const t_start = @max(rel_start, seg_start_byte);
        const rel_end = if (token.end > line_start) token.end - line_start else 0;
        const t_end = @min(rel_end, seg_end_byte);
        if (t_end <= t_start) continue;
        h ^= @as(u64, t_start);
        h *%= 1099511628211;
        h ^= @as(u64, t_end);
        h *%= 1099511628211;
        h ^= @as(u64, @intFromEnum(token.kind));
        h *%= 1099511628211;
    }
    if (has_cursor) {
        h ^= 0x9e3779b97f4a7c15;
        h *%= 1099511628211;
        h ^= @as(u64, cursor_col_vis -| cursor_seg_start);
        h *%= 1099511628211;
    }
    return h;
}

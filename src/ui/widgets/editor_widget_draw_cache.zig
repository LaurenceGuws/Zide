const std = @import("std");
const editor_mod = @import("../../editor/editor.zig");
const syntax_mod = @import("../../editor/syntax.zig");
const layout_mod = @import("../../editor/view/layout.zig");
const metrics_mod = @import("../../editor/view/metrics.zig");
const cache_mod = @import("../../editor/render/cache.zig");
const app_logger = @import("../../app_logger.zig");

const Editor = editor_mod.Editor;
const HighlightToken = syntax_mod.HighlightToken;
const TokenKind = syntax_mod.TokenKind;
const large_file_fallback_threshold_bytes: usize = Editor.highlighter_large_file_threshold_bytes;

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
    const perf_log = app_logger.logger("editor.perf");
    const view = widget.frameView();
    const r = shell.rendererPtr();
    if (budget_lines == 0) return;
    if (height <= 0) return;
    if (view.highlighter == null) return;
    const total_lines = view.lineCount();
    if (total_lines == 0) return;
    const visible_lines = @as(usize, @intFromFloat(height / r.char_height));
    if (visible_lines == 0) return;

    const start_line = view.scroll_line;
    const end_line = @min(start_line + visible_lines + 1, total_lines);
    cache.beginHighlightWork(start_line, end_line, view.highlight_epoch);
    const batch = cache.takeHighlightWorkBatch(budget_lines) orelse {
        perf_log.logf(.info, "visible_precompute_highlight lines=0 budget={d} time_us=0", .{budget_lines});
        return;
    };

    const t_start = std.time.nanoTimestamp();
    var lines_done: usize = 0;
    var tokens: []HighlightToken = &[_]HighlightToken{};
    var allocated = false;
    if (view.highlighter) |highlighter| {
        const range_start = view.lineStart(batch.start_line);
        const range_end = if (batch.end_line < view.lineCount()) view.lineStart(batch.end_line) else view.totalLen();
        tokens = highlighter.highlightRange(range_start, range_end, widget.editor.allocator) catch |err| blk: {
            const log = app_logger.logger("editor.draw");
            log.logf(.warning, "visible precompute highlight range failed start={d} end={d} err={s}", .{ range_start, range_end, @errorName(err) });
            break :blk &[_]HighlightToken{};
        };
        allocated = true;
        if (tokens.len > 1) {
            std.sort.heap(HighlightToken, tokens, {}, struct {
                fn lessThan(_: void, a: HighlightToken, b: HighlightToken) bool {
                    return syntax_mod.highlightTokenLessThanStable(a, b);
                }
            }.lessThan);
        }
    }
    defer if (allocated) widget.editor.allocator.free(tokens);
    if (tokens.len > 0 or batch.start_line < batch.end_line) {
        var token_idx: usize = 0;
        var line_idx = batch.start_line;
        while (line_idx < batch.end_line) : (line_idx += 1) {
            var line_storage = loadLineText(widget, line_idx);
            defer line_storage.deinit(widget.editor.allocator);
            const line_start = view.lineStart(line_idx);
            const line_end = line_start + line_storage.text.len;
            while (token_idx < tokens.len and tokens[token_idx].end <= line_start) {
                token_idx += 1;
            }
            var line_token_end = token_idx;
            while (line_token_end < tokens.len and tokens[line_token_end].start < line_end) {
                line_token_end += 1;
            }
            const line_text_hash = hashLine(line_storage.text);
            cache.storeHighlightTokens(
                line_idx,
                line_start,
                line_text_hash,
                view.highlight_epoch,
                tokens[token_idx..line_token_end],
            );
            lines_done += 1;
        }
    }
    const elapsed_us = @as(i64, @intCast(@divTrunc(std.time.nanoTimestamp() - t_start, 1000)));
    perf_log.logf(.info, "visible_precompute_highlight lines={d} budget={d} time_us={d}", .{ lines_done, budget_lines, elapsed_us });
}

pub fn precomputeLineWidths(widget: anytype, cache: *cache_mod.EditorRenderCache, shell: anytype, height: f32, budget_lines: usize) void {
    const perf_log = app_logger.logger("editor.perf");
    const view = widget.frameView();
    const r = shell.rendererPtr();
    if (budget_lines == 0) return;
    if (height <= 0) return;
    const total_lines = view.lineCount();
    if (total_lines == 0) return;
    const visible_lines = @as(usize, @intFromFloat(height / r.char_height));
    if (visible_lines == 0) return;

    const start_line = view.scroll_line;
    const end_line = @min(start_line + visible_lines + 1, total_lines);
    cache.beginLineWidthWork(start_line, end_line, view.change_tick);

    const t_start = std.time.nanoTimestamp();
    var lines_done: usize = 0;
    var remaining = budget_lines;
    while (remaining > 0) : (remaining -= 1) {
        const next_line = cache.nextLineWidthWorkLine() orelse break;
        var line_storage = loadLineText(widget, next_line);
        defer line_storage.deinit(widget.editor.allocator);
        _ = widget.editor.lineWidthCached(next_line, line_storage.text, null);
        lines_done += 1;
    }
    const elapsed_us = @as(i64, @intCast(@divTrunc(std.time.nanoTimestamp() - t_start, 1000)));
    perf_log.logf(.info, "visible_precompute_width lines={d} budget={d} time_us={d}", .{ lines_done, budget_lines, elapsed_us });
}

pub fn precomputeWrapCounts(widget: anytype, cache: *cache_mod.EditorRenderCache, shell: anytype, height: f32, budget_lines: usize) void {
    const perf_log = app_logger.logger("editor.perf");
    const view = widget.frameView();
    const r = shell.rendererPtr();
    if (!view.wrap_enabled) return;
    if (budget_lines == 0) return;
    if (height <= 0) return;
    const total_lines = view.lineCount();
    if (total_lines == 0) return;
    const visible_lines = @as(usize, @intFromFloat(height / r.char_height));
    if (visible_lines == 0) return;

    const cols = widget.viewportColumns(shell);
    if (cols == 0) return;
    const start_line = view.scroll_line;
    const end_line = @min(start_line + visible_lines + 1, total_lines);
    cache.beginWrapWork(start_line, end_line, cols, view.change_tick);

    const t_start = std.time.nanoTimestamp();
    var lines_done: usize = 0;
    var remaining = budget_lines;
    while (remaining > 0) : (remaining -= 1) {
        const next_line = cache.nextWrapWorkLine() orelse break;
        var line_storage = loadLineText(widget, next_line);
        defer line_storage.deinit(widget.editor.allocator);
        const width_cached = widget.editor.lineWidthCached(next_line, line_storage.text, null);
        const line_width = metrics_mod.lineWidthForDisplay(line_storage.text.len, width_cached, false);
        const count = layout_mod.visualLineCountForWidth(cols, line_width);
        cache.setWrapLineCount(next_line, cols, line_width, count);
        lines_done += 1;
    }
    const elapsed_us = @as(i64, @intCast(@divTrunc(std.time.nanoTimestamp() - t_start, 1000)));
    perf_log.logf(.info, "visible_precompute_wrap lines={d} budget={d} cols={d} time_us={d}", .{ lines_done, budget_lines, cols, elapsed_us });
}

const LineStorage = struct {
    text: []const u8,
    owned: ?[]u8,

    fn deinit(self: *LineStorage, allocator: std.mem.Allocator) void {
        if (self.owned) |owned| allocator.free(owned);
    }
};

fn loadLineText(widget: anytype, line_idx: usize) LineStorage {
    var line_buf: [4096]u8 = undefined;
    const line_len = widget.editor.lineLen(line_idx);
    if (line_len <= line_buf.len) {
        const len = widget.editor.getLine(line_idx, line_buf[0..]);
        const owned = widget.editor.allocator.dupe(u8, line_buf[0..len]) catch return .{ .text = &[_]u8{}, .owned = null };
        return .{ .text = owned, .owned = owned };
    }
    const owned = widget.editor.getLineAlloc(line_idx) catch return .{ .text = &[_]u8{}, .owned = null };
    return .{ .text = owned, .owned = owned };
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

test "buildLargeFileFallbackTokens classifies comment string and number spans deterministically" {
    var tokens: [8]HighlightToken = undefined;

    const string_count = buildLargeFileFallbackTokens("const x = \"abc\"", 100, &tokens);
    try std.testing.expectEqual(@as(usize, 1), string_count);
    try std.testing.expectEqual(.string, tokens[0].kind);
    try std.testing.expectEqual(@as(usize, 110), tokens[0].start);
    try std.testing.expectEqual(@as(usize, 115), tokens[0].end);

    const number_count = buildLargeFileFallbackTokens("value = 123_45", 200, &tokens);
    try std.testing.expectEqual(@as(usize, 1), number_count);
    try std.testing.expectEqual(.number, tokens[0].kind);
    try std.testing.expectEqual(@as(usize, 208), tokens[0].start);
    try std.testing.expectEqual(@as(usize, 214), tokens[0].end);

    const comment_count = buildLargeFileFallbackTokens("name // trailing", 300, &tokens);
    try std.testing.expectEqual(@as(usize, 1), comment_count);
    try std.testing.expectEqual(.comment, tokens[0].kind);
    try std.testing.expectEqual(@as(usize, 305), tokens[0].start);
    try std.testing.expectEqual(@as(usize, 316), tokens[0].end);
}

test "hashSegment changes for cursor current-line and selection state" {
    const line_text = "abcdef";
    const tokens = [_]HighlightToken{
        .{
            .start = 0,
            .end = 6,
            .kind = .string,
            .priority = 0,
            .conceal = null,
            .url = null,
            .conceal_lines = false,
        },
    };
    const selections = [_]struct { start_col: usize, end_col: usize }{
        .{ .start_col = 1, .end_col = 3 },
    };

    const base = hashSegment(line_text, 0, 6, selections[0..0], 0, 6, &tokens, 0, false, false, 0, 0);
    const current_line = hashSegment(line_text, 0, 6, selections[0..0], 0, 6, &tokens, 0, true, false, 0, 0);
    const with_cursor = hashSegment(line_text, 0, 6, selections[0..0], 0, 6, &tokens, 0, true, true, 2, 0);
    const with_selection = hashSegment(line_text, 0, 6, selections[0..], 0, 6, &tokens, 0, false, false, 0, 0);

    try std.testing.expect(base != current_line);
    try std.testing.expect(current_line != with_cursor);
    try std.testing.expect(base != with_selection);
}

test "hashSegment ignores selection outside visible segment" {
    const line_text = "abcdef";
    const tokens = [_]HighlightToken{};
    const offscreen = [_]struct { start_col: usize, end_col: usize }{
        .{ .start_col = 8, .end_col = 10 },
    };

    const base = hashSegment(line_text, 0, 6, offscreen[0..0], 0, 6, &tokens, 0, false, false, 0, 0);
    const with_offscreen_selection = hashSegment(line_text, 0, 6, offscreen[0..], 0, 6, &tokens, 0, false, false, 0, 0);

    try std.testing.expectEqual(base, with_offscreen_selection);
}

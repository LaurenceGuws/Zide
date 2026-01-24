const std = @import("std");
const renderer_mod = @import("../renderer.zig");
const syntax_mod = @import("../../editor/syntax.zig");
const selection_mod = @import("../../editor/view/selection.zig");
const layout_mod = @import("../../editor/view/layout.zig");
const app_logger = @import("../../app_logger.zig");

const Renderer = renderer_mod.Renderer;
const Color = renderer_mod.Color;
const HighlightToken = syntax_mod.HighlightToken;
const TokenKind = syntax_mod.TokenKind;
const SelectionRange = selection_mod.SelectionRange;

pub fn draw(widget: anytype, r: *Renderer, x: f32, y: f32, width: f32, height: f32) void {
    widget.gutter_width = 50 * r.uiScaleFactor();
    const visible_lines = @as(usize, @intFromFloat(height / r.char_height));
    const start_line = widget.editor.scroll_line;
    const start_seg = widget.editor.scroll_row_offset;
    const total_lines = widget.editor.lineCount();
    const end_line = @min(start_line + visible_lines + 1, total_lines);
    var cursor_draw_x: ?f32 = null;
    var cursor_draw_y: ?f32 = null;
    var max_visible_width: usize = 0;
    const cols = widget.viewportColumns(r);
    const show_vscroll = !widget.wrap_enabled and total_lines > visible_lines;

    var highlight_tokens: []HighlightToken = &[_]HighlightToken{};
    var highlight_tokens_allocated = false;
    widget.editor.ensureHighlighter();
    if (widget.editor.highlighter) |highlighter| {
        if (total_lines > 0 and start_line < total_lines) {
            const range_start = widget.editor.lineStart(start_line);
            const range_end = if (end_line < total_lines) widget.editor.lineStart(end_line) else widget.editor.totalLen();
            const log = app_logger.logger("editor.highlight");
            log.logf(
                "highlight batch start lines={d}-{d} bytes={d}-{d}",
                .{ start_line, end_line, range_start, range_end },
            );
            const t_start = std.time.nanoTimestamp();
            const tokens_opt: ?[]HighlightToken = highlighter.highlightRange(range_start, range_end, widget.editor.allocator) catch null;
            const elapsed_ns = std.time.nanoTimestamp() - t_start;
            if (tokens_opt) |tokens| {
                highlight_tokens = tokens;
                highlight_tokens_allocated = true;
                if (highlight_tokens.len > 1) {
                    std.sort.heap(HighlightToken, highlight_tokens, {}, highlightTokenLessThan);
                }
            }
            log.logf(
                "highlight batch lines={d}-{d} bytes={d}-{d} tokens={d} time_us={d}",
                .{
                    start_line,
                    end_line,
                    range_start,
                    range_end,
                    highlight_tokens.len,
                    @as(i64, @intCast(@divTrunc(elapsed_ns, 1000))),
                },
            );
        }
    }
    defer if (highlight_tokens_allocated) widget.editor.allocator.free(highlight_tokens);

    // Draw gutter background
    r.drawRect(
        @intFromFloat(x),
        @intFromFloat(y),
        @intFromFloat(widget.gutter_width),
        @intFromFloat(height),
        r.theme.line_number_bg,
    );

    // Draw lines
    var line_buf: [4096]u8 = undefined;
    var line_idx = start_line;
    var visual_row: usize = 0;
    var token_idx: usize = 0;
    const text_start_x = x + widget.gutter_width + 8 * r.uiScaleFactor();
    while (line_idx < total_lines and visual_row < visible_lines) : (line_idx += 1) {
        const is_current = line_idx == widget.editor.cursor.line;

        const line_len = widget.editor.lineLen(line_idx);
        var line_alloc: ?[]u8 = null;
        const line_text = if (line_len <= line_buf.len)
            line_buf[0..widget.editor.getLine(line_idx, &line_buf)]
        else blk: {
            const owned = widget.editor.getLineAlloc(line_idx) catch break :blk &[_]u8{};
            line_alloc = owned;
            break :blk owned;
        };
        defer if (line_alloc) |owned| widget.editor.allocator.free(owned);
        const line_start = widget.editor.lineStart(line_idx);
        const line_end = line_start + line_len;

        var cluster_slice: ?[]const u32 = null;
        var cluster_owned = false;
        widget.clusterOffsets(r, line_idx, line_text, &cluster_slice, &cluster_owned);
        defer if (cluster_owned) {
            if (cluster_slice) |clusters| widget.editor.allocator.free(clusters);
        };

        var tokens: []HighlightToken = &[_]HighlightToken{};
        if (highlight_tokens_allocated) {
            while (token_idx < highlight_tokens.len and highlight_tokens[token_idx].end <= line_start) {
                token_idx += 1;
            }
            var line_token_end = token_idx;
            while (line_token_end < highlight_tokens.len and highlight_tokens[line_token_end].start < line_end) {
                line_token_end += 1;
            }
            tokens = highlight_tokens[token_idx..line_token_end];
        }

        var ranges: [8]SelectionRange = undefined;
        var range_count: usize = 0;
        selection_mod.collectSelectionRanges(widget.editor, line_idx, line_text, cluster_slice, &ranges, &range_count);

        const width_cached = widget.editor.lineWidthCached(line_idx, line_text, cluster_slice);
        const line_width = if (line_len == 0) 1 else if (width_cached == 0 and range_count > 0) 1 else width_cached;
        if (line_width > max_visible_width) {
            max_visible_width = line_width;
        }
        const total_visual_lines = if (widget.wrap_enabled) layout_mod.visualLineCountForWidth(cols, line_width) else 1;
        const seg_start_idx = if (widget.wrap_enabled and line_idx == start_line) @min(start_seg, total_visual_lines) else 0;

        var cursor_col_vis: usize = 0;
        var cursor_seg: usize = 0;
        if (is_current) {
            cursor_col_vis = selection_mod.visualColumnForByteIndex(line_text, widget.editor.cursor.col, cluster_slice);
            if (cols > 0 and widget.wrap_enabled) {
                cursor_seg = @min(cursor_col_vis / cols, if (total_visual_lines > 0) total_visual_lines - 1 else 0);
            }
        }

        var seg: usize = seg_start_idx;
        while (seg < total_visual_lines and visual_row < visible_lines) : (seg += 1) {
            const seg_start_col = if (widget.wrap_enabled) seg * cols else widget.editor.scroll_col;
            const seg_end_col = if (widget.wrap_enabled) @min(line_width, seg_start_col + cols) else @min(line_width, seg_start_col + cols);
            if (seg_start_col >= seg_end_col and range_count == 0) continue;
            const seg_y = y + @as(f32, @floatFromInt(visual_row)) * r.char_height;
            const seg_start_byte = selection_mod.byteIndexForVisualColumn(line_text, seg_start_col, cluster_slice);
            const seg_end_byte = selection_mod.byteIndexForVisualColumn(line_text, seg_end_col, cluster_slice);

            if (seg == seg_start_idx) {
                r.drawEditorLineBase(line_idx, seg_y, x, widget.gutter_width, width, is_current);
            } else if (is_current) {
                r.drawRect(
                    @intFromFloat(x),
                    @intFromFloat(seg_y),
                    @intFromFloat(widget.gutter_width),
                    @intFromFloat(r.char_height),
                    r.theme.current_line,
                );
                r.drawRect(
                    @intFromFloat(x + widget.gutter_width),
                    @intFromFloat(seg_y),
                    @intFromFloat(width - widget.gutter_width),
                    @intFromFloat(r.char_height),
                    r.theme.current_line,
                );
            }

            if (range_count > 0) {
                var r_i: usize = 0;
                while (r_i < range_count) : (r_i += 1) {
                    const range = ranges[r_i];
                    const sel_start = @max(range.start_col, seg_start_col);
                    const sel_end = @min(range.end_col, seg_end_col);
                    if (sel_end <= sel_start) continue;
                    const sel_x = text_start_x + @as(f32, @floatFromInt(sel_start - seg_start_col)) * r.char_width;
                    const sel_w = @as(f32, @floatFromInt(sel_end - sel_start)) * r.char_width;
                    r.drawRect(
                        @intFromFloat(sel_x),
                        @intFromFloat(seg_y),
                        @intFromFloat(sel_w),
                        @intFromFloat(r.char_height),
                        r.theme.selection,
                    );
                }
            }

            if (tokens.len == 0) {
                r.drawText(line_text[seg_start_byte..seg_end_byte], text_start_x, seg_y, r.theme.foreground);
            } else {
                drawHighlightedLineSegment(
                    r,
                    line_text,
                    seg_y,
                    text_start_x,
                    line_start,
                    seg_start_byte,
                    seg_end_byte,
                    tokens,
                );
            }

            if (is_current and seg == cursor_seg) {
                const local_col = cursor_col_vis - seg_start_col;
                cursor_draw_x = text_start_x + @as(f32, @floatFromInt(local_col)) * r.char_width;
                cursor_draw_y = seg_y;
            }
            visual_row += 1;
        }
    }

    // Draw cursor
    if (cursor_draw_x != null and cursor_draw_y != null) {
        r.drawCursor(cursor_draw_x.?, cursor_draw_y.?, .line);
    }

    if (!widget.wrap_enabled) {
        const vscroll_w: f32 = if (show_vscroll) 12 else 0;
        const scan = widget.editor.advanceMaxLineWidthCache(128);
        if (scan.max > cols) {
            drawHorizontalScrollbar(widget, r, x, y, width, height, scan.max, cols, vscroll_w);
        }
        if (show_vscroll) {
            drawVerticalScrollbar(widget, r, x, y, width, height, visible_lines, total_lines);
        }
    }
}

fn drawHorizontalScrollbar(
    widget: anytype,
    r: *Renderer,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    max_visible_width: usize,
    cols: usize,
    vscroll_w: f32,
) void {
    if (width <= 0 or height <= 0 or cols == 0) return;
    if (max_visible_width <= cols) return;
    const scale = r.uiScaleFactor();
    const track_h: f32 = 16 * scale;
    const track_y = y + height - track_h;
    const track_x = x + widget.gutter_width;
    const track_w = @max(@as(f32, 1), width - widget.gutter_width - vscroll_w);
    const max_scroll = max_visible_width - cols;
    if (widget.editor.scroll_col > max_scroll) {
        widget.editor.scroll_col = max_scroll;
    }

    const min_thumb_w: f32 = 32 * scale;
    const thumb_w = @max(min_thumb_w, track_w * (@as(f32, @floatFromInt(cols)) / @as(f32, @floatFromInt(max_visible_width))));
    const available = @max(@as(f32, 1), track_w - thumb_w);
    const ratio = if (max_scroll > 0)
        @as(f32, @floatFromInt(widget.editor.scroll_col)) / @as(f32, @floatFromInt(max_scroll))
    else
        0.0;
    const thumb_x = track_x + available * ratio;

    r.drawRect(
        @intFromFloat(track_x),
        @intFromFloat(track_y),
        @intFromFloat(track_w),
        @intFromFloat(track_h),
        r.theme.line_number_bg,
    );
    const inset: f32 = @max(1, 2 * scale);
    r.drawRect(
        @intFromFloat(thumb_x),
        @intFromFloat(track_y + inset),
        @intFromFloat(thumb_w),
        @intFromFloat(track_h - inset * 2),
        r.theme.selection,
    );
}

fn drawVerticalScrollbar(
    widget: anytype,
    r: *Renderer,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    visible_lines: usize,
    total_lines: usize,
) void {
    if (total_lines <= visible_lines or width <= 0 or height <= 0) return;
    const scale = r.uiScaleFactor();
    const scrollbar_w: f32 = 16 * scale;
    const scrollbar_x = x + width - scrollbar_w;
    const scrollbar_y = y;
    const scrollbar_h = height;
    const max_scroll = total_lines - visible_lines;
    if (widget.editor.scroll_line > max_scroll) {
        widget.editor.scroll_line = max_scroll;
    }

    const min_thumb_h: f32 = 32 * scale;
    const thumb_h = @max(min_thumb_h, scrollbar_h * (@as(f32, @floatFromInt(visible_lines)) / @as(f32, @floatFromInt(total_lines))));
    const available = @max(@as(f32, 1), scrollbar_h - thumb_h);
    const ratio = if (max_scroll > 0)
        @as(f32, @floatFromInt(widget.editor.scroll_line)) / @as(f32, @floatFromInt(max_scroll))
    else
        0.0;
    const thumb_y = scrollbar_y + available * ratio;

    r.drawRect(
        @intFromFloat(scrollbar_x),
        @intFromFloat(scrollbar_y),
        @intFromFloat(scrollbar_w),
        @intFromFloat(scrollbar_h),
        r.theme.line_number_bg,
    );
    const inset: f32 = @max(1, 2 * scale);
    r.drawRect(
        @intFromFloat(scrollbar_x + inset),
        @intFromFloat(thumb_y),
        @intFromFloat(scrollbar_w - inset * 2),
        @intFromFloat(thumb_h),
        r.theme.selection,
    );
}

fn drawHighlightedLineText(
    r: *Renderer,
    line_text: []const u8,
    y: f32,
    text_x: f32,
    line_start: usize,
    line_end: usize,
    tokens: []HighlightToken,
) void {
    if (line_text.len == 0) return;
    if (tokens.len == 0) return;

    var cursor = line_start;
    for (tokens) |token| {
        if (token.end <= line_start or token.start >= line_end) continue;
        const start = @max(token.start, line_start);
        const end = @min(token.end, line_end);
        if (start > cursor) {
            const slice_start = cursor - line_start;
            const slice_end = start - line_start;
            const x = text_x + @as(f32, @floatFromInt(slice_start)) * r.char_width;
            r.drawText(line_text[slice_start..slice_end], x, y, r.theme.foreground);
        }
        const slice_start = start - line_start;
        const slice_end = end - line_start;
        const x = text_x + @as(f32, @floatFromInt(slice_start)) * r.char_width;
        r.drawText(line_text[slice_start..slice_end], x, y, colorForToken(r, token.kind));
        cursor = end;
    }

    if (cursor < line_end) {
        const slice_start = cursor - line_start;
        const x = text_x + @as(f32, @floatFromInt(slice_start)) * r.char_width;
        r.drawText(line_text[slice_start..], x, y, r.theme.foreground);
    }
}

fn drawHighlightedLineSegment(
    r: *Renderer,
    line_text: []const u8,
    y: f32,
    text_x: f32,
    line_start: usize,
    seg_start: usize,
    seg_end: usize,
    tokens: []HighlightToken,
) void {
    if (seg_start >= seg_end or line_text.len == 0) return;

    var cursor = seg_start;
    for (tokens) |token| {
        if (token.end <= line_start + seg_start or token.start >= line_start + seg_end) continue;
        const start = @max(token.start - line_start, seg_start);
        const end = @min(token.end - line_start, seg_end);
        if (start > cursor) {
            const slice_start = cursor;
            const slice_end = start;
            const x = text_x + @as(f32, @floatFromInt(slice_start - seg_start)) * r.char_width;
            r.drawText(line_text[slice_start..slice_end], x, y, r.theme.foreground);
        }
        const slice_start = start;
        const slice_end = end;
        const x = text_x + @as(f32, @floatFromInt(slice_start - seg_start)) * r.char_width;
        r.drawText(line_text[slice_start..slice_end], x, y, colorForToken(r, token.kind));
        cursor = end;
    }

    if (cursor < seg_end) {
        const slice_start = cursor;
        const x = text_x + @as(f32, @floatFromInt(slice_start - seg_start)) * r.char_width;
        r.drawText(line_text[slice_start..seg_end], x, y, r.theme.foreground);
    }
}

fn highlightTokenLessThan(_: void, a: HighlightToken, b: HighlightToken) bool {
    if (a.start == b.start) return a.end < b.end;
    return a.start < b.start;
}

fn colorForToken(r: *Renderer, kind: TokenKind) Color {
    return switch (kind) {
        .comment => r.theme.comment_color,
        .string => r.theme.string,
        .keyword => r.theme.keyword,
        .number => r.theme.number,
        .function => r.theme.function,
        .variable => r.theme.variable,
        .type_name => r.theme.type_name,
        .operator => r.theme.operator,
        .builtin => r.theme.builtin_color,
        .punctuation => r.theme.punctuation,
        .constant => r.theme.constant,
        .attribute => r.theme.attribute,
        .namespace => r.theme.namespace,
        .label => r.theme.label,
        .error_token => r.theme.error_token,
        else => r.theme.foreground,
    };
}

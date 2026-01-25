const std = @import("std");
const syntax_mod = @import("../../editor/syntax.zig");
const selection_mod = @import("../../editor/view/selection.zig");
const layout_mod = @import("../../editor/view/layout.zig");
const metrics_mod = @import("../../editor/view/metrics.zig");
const cache_mod = @import("../../editor/render/cache.zig");
const draw_list_mod = @import("../../editor/render/draw_list.zig");
const app_logger = @import("../../app_logger.zig");

const HighlightToken = syntax_mod.HighlightToken;
const TokenKind = syntax_mod.TokenKind;
const SelectionRange = selection_mod.SelectionRange;
const EditorDrawList = draw_list_mod.EditorDrawList;
const TextOp = draw_list_mod.TextOp;
const RectOp = draw_list_mod.RectOp;
const CursorOp = draw_list_mod.CursorOp;

fn packColor(color: anytype) u32 {
    return @as(u32, color.r) | (@as(u32, color.g) << 8) | (@as(u32, color.b) << 16) | (@as(u32, color.a) << 24);
}

fn unpackColor(comptime ColorType: type, color: u32) ColorType {
    return .{
        .r = @intCast(color & 0xff),
        .g = @intCast((color >> 8) & 0xff),
        .b = @intCast((color >> 16) & 0xff),
        .a = @intCast((color >> 24) & 0xff),
    };
}

fn addRectOp(list: *EditorDrawList, x: f32, y: f32, w: f32, h: f32, color: anytype) bool {
    list.add(.{ .rect = RectOp{ .x = x, .y = y, .w = w, .h = h, .color = packColor(color) } }) catch return false;
    return true;
}

fn addTextOp(list: *EditorDrawList, x: f32, y: f32, text: []const u8, color: anytype) bool {
    list.add(.{ .text = TextOp{ .x = x, .y = y, .text = text, .color = packColor(color) } }) catch return false;
    return true;
}

fn addCursorOp(list: *EditorDrawList, x: f32, y: f32, h: f32, color: anytype) bool {
    list.add(.{ .cursor = CursorOp{ .x = x, .y = y, .h = h, .color = packColor(color) } }) catch return false;
    return true;
}

fn flushDrawList(list: *EditorDrawList, r: anytype) void {
    const ColorType = @TypeOf(r.theme.foreground);
    for (list.ops.items) |op| {
        switch (op) {
            .rect => |rect| {
                r.drawRect(
                    @intFromFloat(rect.x),
                    @intFromFloat(rect.y),
                    @intFromFloat(rect.w),
                    @intFromFloat(rect.h),
                    unpackColor(ColorType, rect.color),
                );
            },
            .text => |text| {
                r.drawText(text.text, text.x, text.y, unpackColor(ColorType, text.color));
            },
            .cursor => |cursor| {
                r.drawRect(
                    @intFromFloat(cursor.x),
                    @intFromFloat(cursor.y),
                    2,
                    @intFromFloat(cursor.h),
                    unpackColor(ColorType, cursor.color),
                );
            },
        }
    }
}

fn addEditorLineBaseOps(
    list: *EditorDrawList,
    r: anytype,
    line_num: usize,
    y: f32,
    x: f32,
    gutter_width: f32,
    content_width: f32,
    is_current: bool,
    num_buf: *[16]u8,
) bool {
    var ok = true;

    if (is_current) {
        ok = ok and addRectOp(
            list,
            x + gutter_width,
            y,
            content_width - gutter_width,
            r.char_height,
            r.theme.current_line,
        );
        ok = ok and addRectOp(
            list,
            x,
            y,
            gutter_width,
            r.char_height,
            r.theme.current_line,
        );
    }

    const num_str = std.fmt.bufPrint(num_buf, "{d: >4}", .{line_num + 1}) catch return false;
    const pad = 4 * r.uiScaleFactor();
    const line_color = if (is_current) r.theme.foreground else r.theme.line_number;
    ok = ok and addTextOp(list, x + pad, y, num_str, line_color);
    return ok;
}

fn appendHighlightedLineSegmentOps(
    list: *EditorDrawList,
    r: anytype,
    line_text: []const u8,
    y: f32,
    text_x: f32,
    line_start: usize,
    seg_start: usize,
    seg_end: usize,
    tokens: []HighlightToken,
) bool {
    if (seg_start >= seg_end or line_text.len == 0) return true;

    const log = app_logger.logger("editor.highlight");
    var ok = true;
    var cursor = seg_start;
    for (tokens) |token| {
        if (token.end <= line_start + seg_start or token.start >= line_start + seg_end) continue;
        const rel_start = if (token.start > line_start) token.start - line_start else 0;
        const start = @max(rel_start, seg_start);
        const end = @min(token.end - line_start, seg_end);
        if (start > cursor) {
            const slice_start = cursor;
            const slice_end = start;
            const x = text_x + @as(f32, @floatFromInt(slice_start - seg_start)) * r.char_width;
            ok = ok and addTextOp(list, x, y, line_text[slice_start..slice_end], r.theme.foreground);
        }
        const slice_start = start;
        const slice_end = end;
        const x = text_x + @as(f32, @floatFromInt(slice_start - seg_start)) * r.char_width;
        const color = colorForToken(r, token.kind);
        logHighlightSlice(log, token.kind, line_start + slice_start, line_start + slice_end, color);
        ok = ok and addTextOp(list, x, y, line_text[slice_start..slice_end], color);
        cursor = end;
    }

    if (cursor < seg_end) {
        const slice_start = cursor;
        const x = text_x + @as(f32, @floatFromInt(slice_start - seg_start)) * r.char_width;
        ok = ok and addTextOp(list, x, y, line_text[slice_start..seg_end], r.theme.foreground);
    }

    return ok;
}

pub fn draw(widget: anytype, r: anytype, x: f32, y: f32, width: f32, height: f32) void {
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
    var draw_list = EditorDrawList.init(widget.editor.allocator);
    defer draw_list.deinit();

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
        const line_width = metrics_mod.lineWidthForDisplay(line_len, width_cached, range_count > 0);
        if (line_width > max_visible_width) {
            max_visible_width = line_width;
        }
        const total_visual_lines = if (widget.wrap_enabled)
            layout_mod.visualLineCountForWidth(cols, line_width)
        else
            1;
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
            draw_list.clear();
            drawHorizontalScrollbar(widget, r, x, y, width, height, scan.max, cols, vscroll_w, &draw_list);
            flushDrawList(&draw_list, r);
        }
        if (show_vscroll) {
            draw_list.clear();
            drawVerticalScrollbar(widget, r, x, y, width, height, visible_lines, total_lines, &draw_list);
            flushDrawList(&draw_list, r);
        }
    }
}

pub fn drawCached(
    widget: anytype,
    r: anytype,
    cache: *cache_mod.EditorRenderCache,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    frame_id: u64,
) void {
    widget.gutter_width = 50 * r.uiScaleFactor();
    if (width <= 0 or height <= 0) return;
    const visible_lines = @as(usize, @intFromFloat(height / r.char_height));
    const start_line = widget.editor.scroll_line;
    const start_seg = widget.editor.scroll_row_offset;
    const total_lines = widget.editor.lineCount();
    const cols = widget.viewportColumns(r);
    if (cols == 0) return;
    const show_vscroll = !widget.wrap_enabled and total_lines > visible_lines;

    const draw_x = x;
    const draw_y = y;
    const origin_x: f32 = 0;
    const origin_y: f32 = 0;
    var draw_list = &cache.draw_list;

    const texture_changed = r.ensureEditorTexture(@intFromFloat(width), @intFromFloat(height));
    var force_redraw = cache.beginFrame(
        frame_id,
        cols,
        widget.wrap_enabled,
        @intFromFloat(width),
        @intFromFloat(height),
        widget.editor.change_tick,
        widget.editor.highlight_epoch,
        widget.editor.scroll_line,
        widget.editor.scroll_row_offset,
        widget.editor.scroll_col,
    );
    if (texture_changed) force_redraw = true;

    var any_dirty = force_redraw;

    if (force_redraw) {
        if (r.beginEditorTexture()) {
            r.drawRect(0, 0, @intFromFloat(width), @intFromFloat(height), r.theme.background);
            r.drawRect(0, 0, @intFromFloat(widget.gutter_width), @intFromFloat(height), r.theme.line_number_bg);
            r.endEditorTexture();
        }
    }

    var line_buf: [4096]u8 = undefined;
    var line_idx = start_line;
    var visual_row: usize = 0;
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
        const line_text_hash = hashLine(line_text);

        var cluster_slice: ?[]const u32 = null;
        var cluster_owned = false;
        widget.clusterOffsets(r, line_idx, line_text, &cluster_slice, &cluster_owned);
        defer if (cluster_owned) {
            if (cluster_slice) |clusters| widget.editor.allocator.free(clusters);
        };

        const tokens = cache.tryHighlightTokens(
            line_idx,
            line_text_hash,
            widget.editor.highlight_epoch,
        );

        var ranges: [8]SelectionRange = undefined;
        var range_count: usize = 0;
        selection_mod.collectSelectionRanges(widget.editor, line_idx, line_text, cluster_slice, &ranges, &range_count);

        const width_cached = widget.editor.lineWidthCached(line_idx, line_text, cluster_slice);
        const line_width = metrics_mod.lineWidthForDisplay(line_len, width_cached, range_count > 0);
        const total_visual_lines = if (widget.wrap_enabled)
            cache.wrapLineCount(line_idx, cols, line_width) orelse layout_mod.visualLineCountForWidth(cols, line_width)
        else
            1;
        
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
            const seg_y = origin_y + @as(f32, @floatFromInt(visual_row)) * r.char_height;
            const seg_start_byte = selection_mod.byteIndexForVisualColumn(line_text, seg_start_col, cluster_slice);
            const seg_end_byte = selection_mod.byteIndexForVisualColumn(line_text, seg_end_col, cluster_slice);

            const seg_hash = hashSegment(
                line_text,
                seg_start_byte,
                seg_end_byte,
                ranges[0..range_count],
                seg_start_col,
                seg_end_col,
                tokens,
                line_start,
                is_current,
                seg == cursor_seg,
                cursor_col_vis,
                seg_start_col,
            );
            const dirty = cache.segmentDirty(.{ .line_idx = line_idx, .seg_idx = seg }, seg_hash);
            if (force_redraw or dirty) {
                any_dirty = true;
                if (r.beginEditorTexture()) {
                    r.beginClip(
                        @intFromFloat(origin_x),
                        @intFromFloat(seg_y),
                        @intFromFloat(width),
                        @intFromFloat(r.char_height),
                    );
                    draw_list.clear();
                    var list_ok = true;
                    list_ok = list_ok and addRectOp(draw_list, origin_x, seg_y, width, r.char_height, r.theme.background);
                    list_ok = list_ok and addRectOp(draw_list, origin_x, seg_y, widget.gutter_width, r.char_height, r.theme.line_number_bg);

                    if (seg == seg_start_idx) {
                        var num_buf: [16]u8 = undefined;
                        list_ok = list_ok and addEditorLineBaseOps(
                            draw_list,
                            r,
                            line_idx,
                            seg_y,
                            origin_x,
                            widget.gutter_width,
                            width,
                            is_current,
                            &num_buf,
                        );
                    } else if (is_current) {
                        list_ok = list_ok and addRectOp(draw_list, origin_x, seg_y, widget.gutter_width, r.char_height, r.theme.current_line);
                        list_ok = list_ok and addRectOp(draw_list, origin_x + widget.gutter_width, seg_y, width - widget.gutter_width, r.char_height, r.theme.current_line);
                    }

                    if (range_count > 0) {
                        var r_i: usize = 0;
                        while (r_i < range_count) : (r_i += 1) {
                            const range = ranges[r_i];
                            const sel_start = @max(range.start_col, seg_start_col);
                            const sel_end = @min(range.end_col, seg_end_col);
                            if (sel_end <= sel_start) continue;
                            const sel_x = origin_x + widget.gutter_width + 8 * r.uiScaleFactor() + @as(f32, @floatFromInt(sel_start - seg_start_col)) * r.char_width;
                            const sel_w = @as(f32, @floatFromInt(sel_end - sel_start)) * r.char_width;
                            list_ok = list_ok and addRectOp(draw_list, sel_x, seg_y, sel_w, r.char_height, r.theme.selection);
                        }
                    }

                    const text_start_x = origin_x + widget.gutter_width + 8 * r.uiScaleFactor();
                    if (tokens.len == 0) {
                        list_ok = list_ok and addTextOp(draw_list, text_start_x, seg_y, line_text[seg_start_byte..seg_end_byte], r.theme.foreground);
                    } else {
                        list_ok = list_ok and appendHighlightedLineSegmentOps(
                            draw_list,
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
                        const cursor_draw_x = text_start_x + @as(f32, @floatFromInt(local_col)) * r.char_width;
                        list_ok = list_ok and addCursorOp(draw_list, cursor_draw_x, seg_y, r.char_height, r.theme.cursor);
                    }

                    if (list_ok) {
                        flushDrawList(draw_list, r);
                    } else {
                        r.drawRect(
                            @intFromFloat(origin_x),
                            @intFromFloat(seg_y),
                            @intFromFloat(width),
                            @intFromFloat(r.char_height),
                            r.theme.background,
                        );
                        r.drawRect(
                            @intFromFloat(origin_x),
                            @intFromFloat(seg_y),
                            @intFromFloat(widget.gutter_width),
                            @intFromFloat(r.char_height),
                            r.theme.line_number_bg,
                        );

                        if (seg == seg_start_idx) {
                            r.drawEditorLineBase(line_idx, seg_y, origin_x, widget.gutter_width, width, is_current);
                        } else if (is_current) {
                            r.drawRect(
                                @intFromFloat(origin_x),
                                @intFromFloat(seg_y),
                                @intFromFloat(widget.gutter_width),
                                @intFromFloat(r.char_height),
                                r.theme.current_line,
                            );
                            r.drawRect(
                                @intFromFloat(origin_x + widget.gutter_width),
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
                                const sel_x = origin_x + widget.gutter_width + 8 * r.uiScaleFactor() + @as(f32, @floatFromInt(sel_start - seg_start_col)) * r.char_width;
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
                            const cursor_draw_x = text_start_x + @as(f32, @floatFromInt(local_col)) * r.char_width;
                            r.drawCursor(cursor_draw_x, seg_y, .line);
                        }
                    }

                    r.endClip();
                    r.endEditorTexture();
                }
            }
            visual_row += 1;
        }
    }

    if (!widget.wrap_enabled) {
        const vscroll_w: f32 = if (show_vscroll) 12 else 0;
        const scan = widget.editor.advanceMaxLineWidthCache(128);
        const scroll_hash = hashScrollState(scan.max, cols, widget.editor.scroll_col, visible_lines, total_lines, widget.editor.scroll_line, show_vscroll);
        if (force_redraw or cache.scrollDirty(scroll_hash)) {
            any_dirty = true;
            if (r.beginEditorTexture()) {
                if (scan.max > cols) {
                    draw_list.clear();
                    drawHorizontalScrollbar(widget, r, origin_x, origin_y, width, height, scan.max, cols, vscroll_w, draw_list);
                    flushDrawList(draw_list, r);
                }
                if (show_vscroll) {
                    draw_list.clear();
                    drawVerticalScrollbar(widget, r, origin_x, origin_y, width, height, visible_lines, total_lines, draw_list);
                    flushDrawList(draw_list, r);
                }
                r.endEditorTexture();
            }
        }
    }

    if (any_dirty or force_redraw) {
        r.drawEditorTexture(draw_x, draw_y);
    } else {
        r.drawEditorTexture(draw_x, draw_y);
    }
}

pub fn hashLine(text: []const u8) u64 {
    var h: u64 = 1469598103934665603;
    for (text) |byte| {
        h ^= byte;
        h *%= 1099511628211;
    }
    return h;
}

pub fn precomputeHighlightTokens(
    widget: anytype,
    cache: *cache_mod.EditorRenderCache,
    r: anytype,
    height: f32,
    budget_lines: usize,
) void {
    if (budget_lines == 0) return;
    if (height <= 0) return;
    widget.editor.ensureHighlighter();
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

pub fn precomputeLineWidths(
    widget: anytype,
    cache: *cache_mod.EditorRenderCache,
    r: anytype,
    height: f32,
    budget_lines: usize,
) void {
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
        widget.clusterOffsets(r, next_line, line_text, &cluster_slice, &cluster_owned);
        defer if (cluster_owned) {
            if (cluster_slice) |clusters| widget.editor.allocator.free(clusters);
        };

        _ = widget.editor.lineWidthCached(next_line, line_text, cluster_slice);
    }
}

pub fn precomputeWrapCounts(
    widget: anytype,
    cache: *cache_mod.EditorRenderCache,
    r: anytype,
    height: f32,
    budget_lines: usize,
) void {
    if (!widget.wrap_enabled) return;
    if (budget_lines == 0) return;
    if (height <= 0) return;
    const total_lines = widget.editor.lineCount();
    if (total_lines == 0) return;
    const visible_lines = @as(usize, @intFromFloat(height / r.char_height));
    if (visible_lines == 0) return;

    const cols = widget.viewportColumns(r);
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
        widget.clusterOffsets(r, next_line, line_text, &cluster_slice, &cluster_owned);
        defer if (cluster_owned) {
            if (cluster_slice) |clusters| widget.editor.allocator.free(clusters);
        };

        const width_cached = widget.editor.lineWidthCached(next_line, line_text, cluster_slice);
        const line_width = metrics_mod.lineWidthForDisplay(line_len, width_cached, false);
        const count = layout_mod.visualLineCountForWidth(cols, line_width);
        cache.setWrapLineCount(next_line, cols, line_width, count);
    }
}

fn hashSegment(
    line_text: []const u8,
    seg_start_byte: usize,
    seg_end_byte: usize,
    ranges: []const SelectionRange,
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
        const rel_start = if (token.start > line_start) token.start - line_start else 0;
        const t_start = @max(rel_start, seg_start_byte);
        const t_end = @min(token.end - line_start, seg_end_byte);
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
        h ^= @as(u64, cursor_col_vis - cursor_seg_start);
        h *%= 1099511628211;
    }
    return h;
}

fn hashScrollState(
    max_visible_width: usize,
    cols: usize,
    scroll_col: usize,
    visible_lines: usize,
    total_lines: usize,
    scroll_line: usize,
    show_vscroll: bool,
) u64 {
    var h: u64 = 1469598103934665603;
    h ^= @as(u64, max_visible_width);
    h *%= 1099511628211;
    h ^= @as(u64, cols);
    h *%= 1099511628211;
    h ^= @as(u64, scroll_col);
    h *%= 1099511628211;
    h ^= @as(u64, visible_lines);
    h *%= 1099511628211;
    h ^= @as(u64, total_lines);
    h *%= 1099511628211;
    h ^= @as(u64, scroll_line);
    h *%= 1099511628211;
    h ^= @as(u64, @intFromBool(show_vscroll));
    h *%= 1099511628211;
    return h;
}

fn drawHorizontalScrollbar(
    widget: anytype,
    r: anytype,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    max_visible_width: usize,
    cols: usize,
    vscroll_w: f32,
    list: ?*EditorDrawList,
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

    if (list) |ops| {
        _ = addRectOp(ops, track_x, track_y, track_w, track_h, r.theme.line_number_bg);
    } else {
        r.drawRect(
            @intFromFloat(track_x),
            @intFromFloat(track_y),
            @intFromFloat(track_w),
            @intFromFloat(track_h),
            r.theme.line_number_bg,
        );
    }
    const inset: f32 = @max(1, 2 * scale);
    if (list) |ops| {
        _ = addRectOp(ops, thumb_x, track_y + inset, thumb_w, track_h - inset * 2, r.theme.selection);
    } else {
        r.drawRect(
            @intFromFloat(thumb_x),
            @intFromFloat(track_y + inset),
            @intFromFloat(thumb_w),
            @intFromFloat(track_h - inset * 2),
            r.theme.selection,
        );
    }
}

fn drawVerticalScrollbar(
    widget: anytype,
    r: anytype,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    visible_lines: usize,
    total_lines: usize,
    list: ?*EditorDrawList,
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

    if (list) |ops| {
        _ = addRectOp(ops, scrollbar_x, scrollbar_y, scrollbar_w, scrollbar_h, r.theme.line_number_bg);
    } else {
        r.drawRect(
            @intFromFloat(scrollbar_x),
            @intFromFloat(scrollbar_y),
            @intFromFloat(scrollbar_w),
            @intFromFloat(scrollbar_h),
            r.theme.line_number_bg,
        );
    }
    const inset: f32 = @max(1, 2 * scale);
    if (list) |ops| {
        _ = addRectOp(ops, scrollbar_x + inset, thumb_y, scrollbar_w - inset * 2, thumb_h, r.theme.selection);
    } else {
        r.drawRect(
            @intFromFloat(scrollbar_x + inset),
            @intFromFloat(thumb_y),
            @intFromFloat(scrollbar_w - inset * 2),
            @intFromFloat(thumb_h),
            r.theme.selection,
        );
    }
}

fn drawHighlightedLineText(
    r: anytype,
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
    r: anytype,
    line_text: []const u8,
    y: f32,
    text_x: f32,
    line_start: usize,
    seg_start: usize,
    seg_end: usize,
    tokens: []HighlightToken,
) void {
    if (seg_start >= seg_end or line_text.len == 0) return;

    const log = app_logger.logger("editor.highlight");
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
        const color = colorForToken(r, token.kind);
        logHighlightSlice(log, token.kind, line_start + slice_start, line_start + slice_end, color);
        r.drawText(line_text[slice_start..slice_end], x, y, color);
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

fn colorForToken(r: anytype, kind: TokenKind) @TypeOf(r.theme.foreground) {
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

fn logHighlightSlice(log: anytype, kind: TokenKind, start: usize, end: usize, color: anytype) void {
    log.logf(
        "highlight apply kind={s} bytes={d}-{d} color=rgba({d},{d},{d},{d})",
        .{ @tagName(kind), start, end, color.r, color.g, color.b, color.a },
    );
}

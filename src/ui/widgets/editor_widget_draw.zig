const std = @import("std");
const syntax_mod = @import("../../editor/syntax.zig");
const selection_mod = @import("../../editor/view/selection.zig");
const layout_mod = @import("../../editor/view/layout.zig");
const metrics_mod = @import("../../editor/view/metrics.zig");
const cache_mod = @import("../../editor/render/cache.zig");
const draw_list_mod = @import("../../editor/render/draw_list.zig");
const app_logger = @import("../../app_logger.zig");
const overlay_mod = @import("editor_widget_draw_overlay.zig");
const text_mod = @import("editor_widget_draw_text.zig");

const HighlightToken = syntax_mod.HighlightToken;
const TokenKind = syntax_mod.TokenKind;
const SelectionRange = selection_mod.SelectionRange;
const EditorDrawList = draw_list_mod.EditorDrawList;
const ByteRange = overlay_mod.ByteRange;
const large_file_fallback_threshold_bytes: usize = 8 * 1024 * 1024;

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
        ok = ok and overlay_mod.addRectOp(
            list,
            x + gutter_width,
            y,
            content_width - gutter_width,
            r.char_height,
            r.theme.current_line,
        );
        ok = ok and overlay_mod.addRectOp(
            list,
            x,
            y,
            gutter_width,
            r.char_height,
            r.theme.current_line,
        );
    }

    const num_str = std.fmt.bufPrint(num_buf, "{d: >4}", .{line_num + 1}) catch |err| {
        const log = app_logger.logger("editor.draw");
                    log.logf(.warning, "line number format failed line={d} err={s}", .{ line_num, @errorName(err) });
        return false;
    };
    const pad = 4 * r.uiScaleFactor();
    const line_color = if (is_current) r.theme.foreground else r.theme.line_number;
    const line_bg = if (is_current) r.theme.current_line else r.theme.line_number_bg;
    ok = ok and overlay_mod.addTextOpBg(list, x + pad, y, num_str, line_color, line_bg, false);
    return ok;
}


pub fn draw(
    widget: anytype,
    shell: anytype,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    input: anytype,
) void {
    const r = shell.rendererPtr();
    widget.gutter_width = 50 * r.uiScaleFactor();
    const visible_lines = @as(usize, @intFromFloat(height / r.char_height));
    const start_line = widget.editor.scroll_line;
    const start_seg = widget.editor.scroll_row_offset;
    const total_lines = widget.editor.lineCount();
    const end_line = @min(start_line + visible_lines + 1, total_lines);
    var cursor_draw_x: ?f32 = null;
    var cursor_draw_y: ?f32 = null;
    var max_visible_width: usize = 0;
    const cols = widget.viewportColumns(shell);
    var draw_list = EditorDrawList.init(widget.editor.allocator);
    defer draw_list.deinit();

    var highlight_tokens: []HighlightToken = &[_]HighlightToken{};
    var highlight_tokens_allocated = false;
    if (widget.editor.highlighter) |highlighter| {
        if (total_lines > 0 and start_line < total_lines) {
            const range_start = widget.editor.lineStart(start_line);
            const range_end = if (end_line < total_lines) widget.editor.lineStart(end_line) else widget.editor.totalLen();
            const tokens_opt: ?[]HighlightToken = highlighter.highlightRange(range_start, range_end, widget.editor.allocator) catch |err| blk: {
                const log = app_logger.logger("editor.draw");
                                    log.logf(.warning, "highlight range failed start={d} end={d} err={s}", .{ range_start, range_end, @errorName(err) });
                break :blk null;
            };
            if (tokens_opt) |tokens| {
                highlight_tokens = tokens;
                highlight_tokens_allocated = true;
                if (highlight_tokens.len > 1) {
                    std.sort.heap(HighlightToken, highlight_tokens, {}, text_mod.highlightTokenLessThan);
                }
            }
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
        widget.clusterOffsets(shell, line_idx, line_text, &cluster_slice, &cluster_owned);
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
        var fallback_tokens_buf: [32]HighlightToken = undefined;
        var effective_tokens = tokens;
        if (tokens.len == 0 and shouldUseLargeFileFallback(widget.editor)) {
            const fallback_count = buildLargeFileFallbackTokens(line_text, line_start, &fallback_tokens_buf);
            effective_tokens = fallback_tokens_buf[0..fallback_count];
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
            // Keep processing empty segments so cached selection overlays are
            // always cleared correctly after deselect/collapse.
            const seg_y = y + @as(f32, @floatFromInt(visual_row)) * r.char_height;
            const seg_band = overlay_mod.rowBandForRow(y, visual_row, r.char_height);
            const seg_start_byte = selection_mod.byteIndexForVisualColumn(line_text, seg_start_col, cluster_slice);
            const seg_end_byte = selection_mod.byteIndexForVisualColumn(line_text, seg_end_col, cluster_slice);
            const disable_programming_ligatures = switch (r.editor_disable_ligatures) {
                .never => false,
                .always => true,
                .cursor => is_current and seg == cursor_seg,
            };

            if (seg == seg_start_idx) {
                r.drawEditorLineBase(line_idx, seg_y, x, widget.gutter_width, width, is_current);
            } else if (is_current) {
                r.drawRect(
                    @intFromFloat(x),
                    seg_band.y_i,
                    @intFromFloat(widget.gutter_width),
                    seg_band.h_i,
                    r.theme.current_line,
                );
                r.drawRect(
                    @intFromFloat(x + widget.gutter_width),
                    seg_band.y_i,
                    @intFromFloat(width - widget.gutter_width),
                    seg_band.h_i,
                    r.theme.current_line,
                );
            }

            if (range_count > 0) {
                const sel_band = overlay_mod.selectionBandForRowBand(seg_band);
                const selection_color = overlay_mod.softSelectionColor(r.theme.selection);
                var r_i: usize = 0;
                while (r_i < range_count) : (r_i += 1) {
                    const range = ranges[r_i];
                    const sel_start = @max(range.start_col, seg_start_col);
                    const sel_end = @min(range.end_col, seg_end_col);
                    if (sel_end <= sel_start) continue;
                    const sel_x = text_start_x + @as(f32, @floatFromInt(sel_start - seg_start_col)) * r.char_width;
                    const sel_w = @as(f32, @floatFromInt(sel_end - sel_start)) * r.char_width;
                    const corner_mask = overlay_mod.selectionCornerMaskForSegment(widget.editor, line_idx, cols, line_width, seg, total_visual_lines, seg_start_col, seg_end_col, range);
                    overlay_mod.drawSoftSelectionRect(r, sel_x, sel_band.y_f, sel_w, sel_band.h_f, selection_color, corner_mask);
                }
            }

            var search_ranges: [16]ByteRange = undefined;
            const search_count = text_mod.collectSearchByteRanges(
                line_start + seg_start_byte,
                line_start + seg_end_byte,
                widget.editor.searchMatches(),
                &search_ranges,
            );
            if (search_count > 0) {
                const search_color = overlay_mod.searchHighlightColor(r.theme);
                const active_search = overlay_mod.searchActiveByteRange(widget.editor);
                const search_band = overlay_mod.selectionBandForRowBand(seg_band);
                for (search_ranges[0..search_count]) |match| {
                    const local_start = match.start - line_start;
                    const local_end = match.end - line_start;
                    const sx = text_mod.xForByteOffset(r, line_text, seg_start_byte, seg_start_col, local_start, text_start_x);
                    const ex = text_mod.xForByteOffset(r, line_text, seg_start_byte, seg_start_col, local_end, text_start_x);
                    if (ex <= sx) continue;
                    const draw_color = if (active_search) |active| if (overlay_mod.rangeContains(active, match)) overlay_mod.activeSearchHighlightColor(r.theme) else search_color else search_color;
                    r.drawRect(
                        @intFromFloat(sx),
                        search_band.y_i,
                        @intFromFloat(ex - sx),
                        search_band.h_i,
                        draw_color,
                    );
                }
            }

            const base_bg = if (is_current) r.theme.current_line else r.theme.background;
            const selection_bg = overlay_mod.softSelectionColor(r.theme.selection);
            var sel_bytes: [8]ByteRange = undefined;
            const sel_count = if (range_count > 0)
                text_mod.buildSelectionByteRanges(
                    line_text,
                    cluster_slice,
                    seg_start_col,
                    seg_end_col,
                    seg_start_byte,
                    seg_end_byte,
                    ranges[0..range_count],
                    &sel_bytes,
                )
            else
                0;

            if (effective_tokens.len == 0) {
                text_mod.drawTextSliceWithSelectionBg(
                    r,
                    text_start_x,
                    seg_y,
                    line_text,
                    seg_start_byte,
                    seg_start_col,
                    seg_start_byte,
                    seg_end_byte,
                    r.theme.foreground,
                    base_bg,
                    selection_bg,
                    sel_bytes[0..sel_count],
                    disable_programming_ligatures,
                );
            } else {
                text_mod.drawHighlightedLineSegment(
                    r,
                    line_text,
                    seg_y,
                    text_start_x,
                    line_start,
                    seg_start_byte,
                    seg_end_byte,
                    seg_start_col,
                    effective_tokens,
                    base_bg,
                    selection_bg,
                    sel_bytes[0..sel_count],
                    disable_programming_ligatures,
                );
            }

            if (is_current and seg == cursor_seg) {
                const local_col = cursor_col_vis - seg_start_col;
                cursor_draw_x = text_start_x + @as(f32, @floatFromInt(local_col)) * r.char_width;
                cursor_draw_y = seg_y;
            }
            overlay_mod.drawExtraCarets(widget, r, line_idx, line_text, cluster_slice, seg_start_col, seg_end_col, line_width, seg_y, text_start_x);
            visual_row += 1;
        }
    }

    // Draw cursor
    if (cursor_draw_x != null and cursor_draw_y != null) {
        r.drawCursor(cursor_draw_x.?, cursor_draw_y.?, .line);
        if (input.composing_active and input.composing_text.len > 0) {
            const comp_x = cursor_draw_x.?;
            const comp_y = cursor_draw_y.?;
            r.drawTextMonospaceOnBg(input.composing_text, comp_x, comp_y, r.theme.foreground, r.theme.current_line);
            r.drawRect(
                @intFromFloat(comp_x),
                @intFromFloat(comp_y + r.char_height - 2),
                @intFromFloat(@as(f32, @floatFromInt(input.composing_text.len)) * r.char_width),
                2,
                r.theme.selection,
            );
            shell.setTextInputRect(
                @intFromFloat(comp_x),
                @intFromFloat(comp_y),
                @intFromFloat(@as(f32, @floatFromInt(@max(@as(usize, 1), input.composing_text.len))) * r.char_width),
                @intFromFloat(r.char_height),
            );
        } else {
            shell.setTextInputRect(
                @intFromFloat(cursor_draw_x.?),
                @intFromFloat(cursor_draw_y.?),
                @intFromFloat(r.char_width),
                @intFromFloat(r.char_height),
            );
        }
    }

    if (!widget.wrap_enabled) {
        overlay_mod.drawEditorScrollbars(widget, r, x, y, width, height, visible_lines, total_lines, cols, input.mouse_pos, &draw_list);
    }
}

pub fn drawCached(
    widget: anytype,
    shell: anytype,
    cache: *cache_mod.EditorRenderCache,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    frame_id: u64,
    input: anytype,
) void {
    const r = shell.rendererPtr();
    widget.gutter_width = 50 * r.uiScaleFactor();
    if (width <= 0 or height <= 0) return;
    const visible_lines = @as(usize, @intFromFloat(height / r.char_height));
    const start_line = widget.editor.scroll_line;
    const start_seg = widget.editor.scroll_row_offset;
    const total_lines = widget.editor.lineCount();
    const cols = widget.viewportColumns(shell);
    if (cols == 0) return;

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
        overlay_mod.selectionStateHash(widget.editor),
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
        widget.clusterOffsets(shell, line_idx, line_text, &cluster_slice, &cluster_owned);
        defer if (cluster_owned) {
            if (cluster_slice) |clusters| widget.editor.allocator.free(clusters);
        };

        const line_end = line_start + line_len;
        const tokens = cache.highlightTokens(
            widget.editor.highlighter,
            line_idx,
            line_start,
            line_end,
            line_text_hash,
            widget.editor.highlight_epoch,
        );
        var fallback_tokens_buf: [32]HighlightToken = undefined;
        var effective_tokens = tokens;
        if (tokens.len == 0 and shouldUseLargeFileFallback(widget.editor)) {
            const fallback_count = buildLargeFileFallbackTokens(line_text, line_start, &fallback_tokens_buf);
            effective_tokens = fallback_tokens_buf[0..fallback_count];
        }

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
            // Keep processing empty segments so cached selection overlays are
            // always cleared correctly after deselect/collapse.
            const seg_y = origin_y + @as(f32, @floatFromInt(visual_row)) * r.char_height;
            const seg_band = overlay_mod.rowBandForRow(origin_y, visual_row, r.char_height);
            const seg_start_byte = selection_mod.byteIndexForVisualColumn(line_text, seg_start_col, cluster_slice);
            const seg_end_byte = selection_mod.byteIndexForVisualColumn(line_text, seg_end_col, cluster_slice);
            const disable_programming_ligatures = switch (r.editor_disable_ligatures) {
                .never => false,
                .always => true,
                .cursor => is_current and seg == cursor_seg,
            };

            const seg_hash = hashSegment(
                line_text,
                seg_start_byte,
                seg_end_byte,
                ranges[0..range_count],
                seg_start_col,
                seg_end_col,
                effective_tokens,
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
                    const clip_h = @min(seg_band.h_i + 1, @as(i32, @intFromFloat(height)) - seg_band.y_i);
                    r.beginClip(
                        @intFromFloat(origin_x),
                        seg_band.y_i,
                        @intFromFloat(width),
                        @max(1, clip_h),
                    );
                    draw_list.clear();
                    var list_ok = true;
                    list_ok = list_ok and overlay_mod.addRectOp(draw_list, origin_x, seg_band.y_f, width, seg_band.h_f, r.theme.background);
                    list_ok = list_ok and overlay_mod.addRectOp(draw_list, origin_x, seg_band.y_f, widget.gutter_width, seg_band.h_f, r.theme.line_number_bg);

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
                        list_ok = list_ok and overlay_mod.addRectOp(draw_list, origin_x, seg_band.y_f, widget.gutter_width, seg_band.h_f, r.theme.current_line);
                        list_ok = list_ok and overlay_mod.addRectOp(draw_list, origin_x + widget.gutter_width, seg_band.y_f, width - widget.gutter_width, seg_band.h_f, r.theme.current_line);
                    }

                    if (range_count > 0) {
                        const sel_band = overlay_mod.selectionBandForRowBand(seg_band);
                        const selection_color = overlay_mod.softSelectionColor(r.theme.selection);
                        var r_i: usize = 0;
                        while (r_i < range_count) : (r_i += 1) {
                            const range = ranges[r_i];
                            const sel_start = @max(range.start_col, seg_start_col);
                            const sel_end = @min(range.end_col, seg_end_col);
                            if (sel_end <= sel_start) continue;
                            const sel_x = origin_x + widget.gutter_width + 8 * r.uiScaleFactor() + @as(f32, @floatFromInt(sel_start - seg_start_col)) * r.char_width;
                            const sel_w = @as(f32, @floatFromInt(sel_end - sel_start)) * r.char_width;
                            const corner_mask = overlay_mod.selectionCornerMaskForSegment(widget.editor, line_idx, cols, line_width, seg, total_visual_lines, seg_start_col, seg_end_col, range);
                            list_ok = list_ok and overlay_mod.addSoftSelectionRectOp(draw_list, r, sel_x, sel_band.y_f, sel_w, sel_band.h_f, selection_color, corner_mask);
                        }
                    }

                    var search_ranges: [16]ByteRange = undefined;
                    const search_count = text_mod.collectSearchByteRanges(
                        line_start + seg_start_byte,
                        line_start + seg_end_byte,
                        widget.editor.searchMatches(),
                        &search_ranges,
                    );
                    if (search_count > 0) {
                        const search_color = overlay_mod.searchHighlightColor(r.theme);
                        const active_search = overlay_mod.searchActiveByteRange(widget.editor);
                        const search_band = overlay_mod.selectionBandForRowBand(seg_band);
                        for (search_ranges[0..search_count]) |match| {
                            const local_start = match.start - line_start;
                            const local_end = match.end - line_start;
                            const sx = text_mod.xForByteOffset(r, line_text, seg_start_byte, seg_start_col, local_start, origin_x + widget.gutter_width + 8 * r.uiScaleFactor());
                            const ex = text_mod.xForByteOffset(r, line_text, seg_start_byte, seg_start_col, local_end, origin_x + widget.gutter_width + 8 * r.uiScaleFactor());
                            if (ex <= sx) continue;
                            const draw_color = if (active_search) |active| if (overlay_mod.rangeContains(active, match)) overlay_mod.activeSearchHighlightColor(r.theme) else search_color else search_color;
                            list_ok = list_ok and overlay_mod.addRectOp(draw_list, sx, search_band.y_f, ex - sx, search_band.h_f, draw_color);
                        }
                    }

                    const base_bg = if (is_current) r.theme.current_line else r.theme.background;
                    const selection_bg = overlay_mod.softSelectionColor(r.theme.selection);
                    var sel_bytes: [8]ByteRange = undefined;
                    const sel_count = if (range_count > 0)
                        text_mod.buildSelectionByteRanges(
                            line_text,
                            cluster_slice,
                            seg_start_col,
                            seg_end_col,
                            seg_start_byte,
                            seg_end_byte,
                            ranges[0..range_count],
                            &sel_bytes,
                        )
                    else
                        0;

                    const text_start_x = origin_x + widget.gutter_width + 8 * r.uiScaleFactor();
                    if (effective_tokens.len == 0) {
                        list_ok = list_ok and text_mod.addTextSliceOpsWithSelectionBg(
                            draw_list,
                            r,
                            text_start_x,
                            seg_y,
                            line_text,
                            seg_start_byte,
                            seg_start_col,
                            seg_start_byte,
                            seg_end_byte,
                            r.theme.foreground,
                            base_bg,
                            selection_bg,
                            sel_bytes[0..sel_count],
                            disable_programming_ligatures,
                        );
                    } else {
                        list_ok = list_ok and text_mod.appendHighlightedLineSegmentOps(
                            draw_list,
                            r,
                            line_text,
                            seg_y,
                            text_start_x,
                            line_start,
                            seg_start_byte,
                            seg_end_byte,
                            seg_start_col,
                            effective_tokens,
                            base_bg,
                            selection_bg,
                            seg_start_byte,
                            sel_bytes[0..sel_count],
                            disable_programming_ligatures,
                        );
                    }

                    if (is_current and seg == cursor_seg) {
                        const local_col = cursor_col_vis - seg_start_col;
                        const cursor_draw_x = text_start_x + @as(f32, @floatFromInt(local_col)) * r.char_width;
                        list_ok = list_ok and overlay_mod.addCursorOp(draw_list, cursor_draw_x, seg_y, r.char_height, r.theme.cursor);
                    }
                    list_ok = list_ok and overlay_mod.addExtraCaretOps(
                        draw_list,
                        widget,
                        r,
                        line_idx,
                        line_text,
                        cluster_slice,
                        seg_start_col,
                        seg_end_col,
                        line_width,
                        seg_y,
                        text_start_x,
                    );

                    if (list_ok) {
                        overlay_mod.flushDrawList(draw_list, r);
                    } else {
                        r.drawRect(
                            @intFromFloat(origin_x),
                            seg_band.y_i,
                            @intFromFloat(width),
                            seg_band.h_i,
                            r.theme.background,
                        );
                        r.drawRect(
                            @intFromFloat(origin_x),
                            seg_band.y_i,
                            @intFromFloat(widget.gutter_width),
                            seg_band.h_i,
                            r.theme.line_number_bg,
                        );

                        if (seg == seg_start_idx) {
                            r.drawEditorLineBase(line_idx, seg_y, origin_x, widget.gutter_width, width, is_current);
                        } else if (is_current) {
                            r.drawRect(
                                @intFromFloat(origin_x),
                                seg_band.y_i,
                                @intFromFloat(widget.gutter_width),
                                seg_band.h_i,
                                r.theme.current_line,
                            );
                            r.drawRect(
                                @intFromFloat(origin_x + widget.gutter_width),
                                seg_band.y_i,
                                @intFromFloat(width - widget.gutter_width),
                                seg_band.h_i,
                                r.theme.current_line,
                            );
                        }

                        if (range_count > 0) {
                            const sel_band = overlay_mod.selectionBandForRowBand(seg_band);
                            const selection_color = overlay_mod.softSelectionColor(r.theme.selection);
                            var r_i: usize = 0;
                            while (r_i < range_count) : (r_i += 1) {
                                const range = ranges[r_i];
                                const sel_start = @max(range.start_col, seg_start_col);
                                const sel_end = @min(range.end_col, seg_end_col);
                                if (sel_end <= sel_start) continue;
                                const sel_x = origin_x + widget.gutter_width + 8 * r.uiScaleFactor() + @as(f32, @floatFromInt(sel_start - seg_start_col)) * r.char_width;
                                const sel_w = @as(f32, @floatFromInt(sel_end - sel_start)) * r.char_width;
                                const corner_mask = overlay_mod.selectionCornerMaskForSegment(widget.editor, line_idx, cols, line_width, seg, total_visual_lines, seg_start_col, seg_end_col, range);
                                overlay_mod.drawSoftSelectionRect(r, sel_x, sel_band.y_f, sel_w, sel_band.h_f, selection_color, corner_mask);
                            }
                        }

                        if (effective_tokens.len == 0) {
                            const seg_base_bg = base_bg;
                            const selection_bg_local = overlay_mod.softSelectionColor(r.theme.selection);
                            if (sel_count == 0) {
                                r.drawTextMonospaceOnBgPolicy(line_text[seg_start_byte..seg_end_byte], text_start_x, seg_y, r.theme.foreground, seg_base_bg, disable_programming_ligatures);
                            } else {
                                // Draw unselected/selected parts separately for correct correction.
                                var cursor_b: usize = seg_start_byte;
                                for (sel_bytes[0..sel_count]) |sr| {
                                    if (sr.start > cursor_b) {
                                        const x0 = text_mod.xForByteOffset(r, line_text, seg_start_byte, seg_start_col, cursor_b, text_start_x);
                                        r.drawTextMonospaceOnBgPolicy(line_text[cursor_b..sr.start], x0, seg_y, r.theme.foreground, seg_base_bg, disable_programming_ligatures);
                                    }
                                    const x1 = text_mod.xForByteOffset(r, line_text, seg_start_byte, seg_start_col, sr.start, text_start_x);
                                    r.drawTextMonospaceOnBgPolicy(line_text[sr.start..sr.end], x1, seg_y, r.theme.foreground, selection_bg_local, disable_programming_ligatures);
                                    cursor_b = sr.end;
                                }
                                if (cursor_b < seg_end_byte) {
                                    const x2 = text_mod.xForByteOffset(r, line_text, seg_start_byte, seg_start_col, cursor_b, text_start_x);
                                    r.drawTextMonospaceOnBgPolicy(line_text[cursor_b..seg_end_byte], x2, seg_y, r.theme.foreground, seg_base_bg, disable_programming_ligatures);
                                }
                            }
                        } else {
                            text_mod.drawHighlightedLineSegment(
                                r,
                                line_text,
                                seg_y,
                                text_start_x,
                                line_start,
                                seg_start_byte,
                                seg_end_byte,
                                seg_start_col,
                            effective_tokens,
                            base_bg,
                            selection_bg,
                            sel_bytes[0..sel_count],
                            disable_programming_ligatures,
                        );
                    }

                        if (is_current and seg == cursor_seg) {
                            const local_col = cursor_col_vis - seg_start_col;
                            const cursor_draw_x = text_start_x + @as(f32, @floatFromInt(local_col)) * r.char_width;
                            r.drawCursor(cursor_draw_x, seg_y, .line);
                        }
                        overlay_mod.drawExtraCarets(widget, r, line_idx, line_text, cluster_slice, seg_start_col, seg_end_col, line_width, seg_y, text_start_x);
                    }

                    r.endClip();
                    r.endEditorTexture();
                }
            }
            visual_row += 1;
        }
    }

    if (any_dirty or force_redraw) {
        r.drawEditorTexture(draw_x, draw_y);
    } else {
        r.drawEditorTexture(draw_x, draw_y);
    }

    // Draw scrollbars as final overlays (outside cached editor texture) to avoid
    // stale dirty-region artifacts when geometry changes frame-to-frame.
    if (!widget.wrap_enabled) {
        overlay_mod.drawEditorScrollbars(widget, r, draw_x, draw_y, width, height, visible_lines, total_lines, cols, input.mouse_pos, null);
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

fn shouldUseLargeFileFallback(editor: anytype) bool {
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

fn buildLargeFileFallbackTokens(line_text: []const u8, line_start: usize, out: []HighlightToken) usize {
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

pub fn precomputeHighlightTokens(
    widget: anytype,
    cache: *cache_mod.EditorRenderCache,
    shell: anytype,
    height: f32,
    budget_lines: usize,
) void {
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

pub fn precomputeLineWidths(
    widget: anytype,
    cache: *cache_mod.EditorRenderCache,
    shell: anytype,
    height: f32,
    budget_lines: usize,
) void {
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

pub fn precomputeWrapCounts(
    widget: anytype,
    cache: *cache_mod.EditorRenderCache,
    shell: anytype,
    height: f32,
    budget_lines: usize,
) void {
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


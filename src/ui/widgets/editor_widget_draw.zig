const std = @import("std");
const syntax_mod = @import("../../editor/syntax.zig");
const selection_mod = @import("../../editor/view/selection.zig");
const chrome_geometry_mod = @import("../../editor/view/chrome_geometry.zig");
const frame_view_mod = @import("../../editor/view/frame.zig");
const layout_mod = @import("../../editor/view/layout.zig");
const metrics_mod = @import("../../editor/view/metrics.zig");
const runtime_mod = @import("../../editor/view/runtime.zig");
const cache_mod = @import("../../editor/render/cache.zig");
const draw_list_mod = @import("../../editor/render/draw_list.zig");
const traversal_mod = @import("../../editor/render/traversal.zig");
const segment_paint_mod = @import("../../editor/render/segment_paint.zig");
const visible_prep_mod = @import("../../editor/render/visible_prep.zig");
const app_logger = @import("../../app_logger.zig");
const overlay_mod = @import("editor_widget_draw_overlay.zig");
const text_mod = @import("editor_widget_draw_text.zig");
const cache_helpers = @import("editor_widget_draw_cache.zig");

const HighlightToken = syntax_mod.HighlightToken;
const SelectionRange = selection_mod.SelectionRange;
const EditorDrawList = draw_list_mod.EditorDrawList;
const ByteRange = overlay_mod.ByteRange;
const Segment = traversal_mod.Segment;

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
    const view = frame_view_mod.EditorFrameView.init(widget.editor, widget.wrap_enabled);
    const frame_prep = visible_prep_mod.prepareFrame(widget, shell, x, height);
    widget.gutter_width = frame_prep.gutter_width;
    const visible_lines = frame_prep.visible_lines;
    const start_line = frame_prep.start_line;
    const start_seg = frame_prep.start_seg;
    const total_lines = frame_prep.total_lines;
    const end_line = frame_prep.end_line;
    var cursor_draw_x: ?f32 = null;
    var cursor_draw_y: ?f32 = null;
    var max_visible_width: usize = 0;
    const cols = frame_prep.cols;
    var draw_list = EditorDrawList.init(widget.editor.allocator);
    defer draw_list.deinit();

    const highlight_prep = visible_prep_mod.prepareHighlightRange(view, widget.editor.allocator, start_line, end_line);
    defer if (highlight_prep.allocated) widget.editor.allocator.free(highlight_prep.tokens);

    // Draw gutter background
    r.drawRect(
        @intFromFloat(x),
        @intFromFloat(y),
        @intFromFloat(widget.gutter_width),
        @intFromFloat(height),
        r.theme.line_number_bg,
    );

    // Draw lines
    var line_idx = start_line;
    var visual_row: usize = 0;
    var token_idx: usize = 0;
    const text_start_x = frame_prep.text_start_x;
    while (line_idx < total_lines and visual_row < visible_lines) : (line_idx += 1) {
        var line_buf: [4096]u8 = undefined;
        var scratch = runtime_mod.LineScratch{ .buf = line_buf[0..] };
        var fallback_tokens_buf: [32]HighlightToken = undefined;
        var prepared = visible_prep_mod.prepareLine(widget, shell, view, line_idx, highlight_prep.tokens, &token_idx, &scratch, &fallback_tokens_buf);
        defer visible_prep_mod.releasePreparedLine(widget, &prepared);
        const line_width = prepared.line_width;
        if (line_width > max_visible_width) {
            max_visible_width = line_width;
        }
        const Local = struct {
            fn renderSegment(ctx: anytype, seg_info: Segment) void {
                const widget_local = ctx.widget;
                const view_local = ctx.view;
                const r_local = ctx.r;
                const draw_list_local = ctx.draw_list;
                const ranges_local = ctx.ranges;
                const range_count_local = ctx.range_count;
                const effective_tokens_local = ctx.effective_tokens;
                const line_text_local = ctx.line_text;
                const cluster_slice_local = ctx.cluster_slice;
                const text_start_x_local = ctx.text_start_x;
                const x_local = ctx.x;
                const y_local = ctx.y;
                const width_local = ctx.width;
                const cols_local = ctx.cols;
                const cursor_draw_x_local = ctx.cursor_draw_x;
                const cursor_draw_y_local = ctx.cursor_draw_y;
                const seg_y = y_local + @as(f32, @floatFromInt(seg_info.visual_row)) * r_local.char_height;
                const seg_band = overlay_mod.rowBandForRow(y_local, seg_info.visual_row, r_local.char_height);
                const disable_programming_ligatures = switch (r_local.editor_disable_ligatures) {
                    .never => false,
                    .always => true,
                    .cursor => seg_info.is_current and seg_info.seg_idx == seg_info.cursor_seg,
                };

                if (seg_info.seg_idx == seg_info.seg_start_idx) {
                    var num_buf: [16]u8 = undefined;
                    _ = segment_paint_mod.addEditorLineBaseOps(draw_list_local, r_local, seg_info.line_idx, seg_y, x_local, widget_local.gutter_width, width_local, seg_info.is_current, &num_buf);
                    overlay_mod.flushDrawList(draw_list_local, r_local);
                    draw_list_local.clear();
                } else if (seg_info.is_current) {
                    r_local.drawRect(
                    @intFromFloat(x_local),
                    seg_band.y_i,
                    @intFromFloat(widget_local.gutter_width),
                    seg_band.h_i,
                    r_local.theme.current_line,
                );
                    r_local.drawRect(
                    @intFromFloat(x_local + widget_local.gutter_width),
                    seg_band.y_i,
                    @intFromFloat(width_local - widget_local.gutter_width),
                    seg_band.h_i,
                    r_local.theme.current_line,
                );
                }

                if (range_count_local > 0) {
                    segment_paint_mod.drawSelectionOverlays(
                        view_local,
                        r_local,
                        seg_info.line_idx,
                        cols_local,
                        seg_info.line_width,
                        seg_info.total_visual_lines,
                        seg_info.seg_idx,
                        seg_info.seg_start_col,
                        seg_info.seg_end_col,
                        seg_band,
                        text_start_x_local,
                        ranges_local[0..range_count_local],
                    );
                }

                segment_paint_mod.drawSearchOverlays(
                    view_local,
                    r_local,
                    seg_info.line_start,
                    seg_info.seg_start_byte,
                    seg_info.seg_end_byte,
                    seg_info.seg_start_col,
                    line_text_local,
                    seg_band,
                    text_start_x_local,
                );

                segment_paint_mod.drawSegmentText(
                    r_local,
                    line_text_local,
                    cluster_slice_local,
                    seg_y,
                    text_start_x_local,
                    seg_info.line_start,
                    seg_info.seg_start_byte,
                    seg_info.seg_end_byte,
                    seg_info.seg_start_col,
                    seg_info.seg_end_col,
                    effective_tokens_local,
                    ranges_local[0..range_count_local],
                    seg_info.is_current,
                    disable_programming_ligatures,
                );

                if (seg_info.is_current and seg_info.seg_idx == seg_info.cursor_seg) {
                    const local_col = seg_info.cursor_col_vis - seg_info.seg_start_col;
                    cursor_draw_x_local.* = text_start_x_local + @as(f32, @floatFromInt(local_col)) * r_local.char_width;
                    cursor_draw_y_local.* = seg_y;
                }
                overlay_mod.drawExtraCarets(view_local, r_local, seg_info.line_idx, line_text_local, cluster_slice_local, seg_info.seg_start_col, seg_info.seg_end_col, seg_info.line_width, seg_y, text_start_x_local);
            }
        };
        const ctx = .{
            .widget = widget,
            .view = &view,
            .r = r,
            .draw_list = &draw_list,
            .ranges = prepared.selection_ranges,
            .range_count = prepared.selection_count,
            .effective_tokens = prepared.effective_tokens,
            .line_text = prepared.line_text,
            .cluster_slice = prepared.cluster_slice,
            .text_start_x = text_start_x,
            .x = x,
            .y = y,
            .width = width,
            .cols = cols,
            .cursor_draw_x = &cursor_draw_x,
            .cursor_draw_y = &cursor_draw_y,
        };
        traversal_mod.walkVisibleSegments(view, prepared.line_text, prepared.cluster_slice, cols, widget.wrap_enabled, start_line, start_seg, line_idx, visible_lines, &visual_row, line_width, ctx, Local.renderSegment);
    }

    // Draw cursor
    if (cursor_draw_x != null and cursor_draw_y != null) {
        overlay_mod.drawLineCursor(r, cursor_draw_x.?, cursor_draw_y.?, r.char_height, r.theme.cursor);
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
        overlay_mod.drawEditorScrollbars(view, widget.gutter_width, r, x, y, width, height, visible_lines, total_lines, cols, input.mouse_pos, &draw_list);
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
    if (width <= 0 or height <= 0) return;
    var view = frame_view_mod.EditorFrameView.init(widget.editor, widget.wrap_enabled);
    const frame_prep = visible_prep_mod.prepareFrame(widget, shell, x, height);
    widget.gutter_width = frame_prep.gutter_width;
    const visible_lines = frame_prep.visible_lines;
    const start_line = frame_prep.start_line;
    const start_seg = frame_prep.start_seg;
    const total_lines = frame_prep.total_lines;
    const cols = frame_prep.cols;
    if (cols == 0) return;

    const draw_x = x;
    const draw_y = y;
    const origin_x: f32 = 0;
    const origin_y: f32 = 0;
    const draw_list = &cache.draw_list;

    const texture_changed = r.ensureEditorTexture(@intFromFloat(width), @intFromFloat(height));
    var force_redraw = cache.beginFrame(
        frame_id,
        cols,
        widget.wrap_enabled,
        @intFromFloat(width),
        @intFromFloat(height),
        view.change_tick,
        view.highlight_epoch,
        view.scroll_line,
        view.scroll_row_offset,
        view.scroll_col,
        view.selectionStateHash(),
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

    var line_idx = start_line;
    var visual_row: usize = 0;
    while (line_idx < total_lines and visual_row < visible_lines) : (line_idx += 1) {
        var line_buf: [4096]u8 = undefined;
        var scratch = runtime_mod.LineScratch{ .buf = line_buf[0..] };
        var fallback_tokens_buf: [32]HighlightToken = undefined;
        var no_token_idx: usize = 0;
        var prepared = visible_prep_mod.prepareLine(widget, shell, view, line_idx, &[_]HighlightToken{}, &no_token_idx, &scratch, &fallback_tokens_buf);
        defer visible_prep_mod.releasePreparedLine(widget, &prepared);
        const line_text_hash = cache_helpers.hashLine(prepared.line_text);
        visible_prep_mod.prepareCachedLineTokens(cache, view, &prepared, line_text_hash, &fallback_tokens_buf);
        const line_width = prepared.line_width;
        _ = if (widget.wrap_enabled)
            cache.wrapLineCount(line_idx, cols, line_width) orelse layout_mod.visualLineCountForWidth(cols, line_width)
        else
            1;

        const Local = struct {
            fn renderSegment(ctx: anytype, seg_info: Segment) void {
                const widget_local = ctx.widget;
                const view_local = ctx.view;
                const r_local = ctx.r;
                const cache_local = ctx.cache;
                const draw_list_local = ctx.draw_list;
                const ranges_local = ctx.ranges;
                const range_count_local = ctx.range_count;
                const effective_tokens_local = ctx.effective_tokens;
                const line_text_local = ctx.line_text;
                const cluster_slice_local = ctx.cluster_slice;
                const width_local = ctx.width;
                const height_local = ctx.height;
                const cols_local = ctx.cols;
                const origin_x_local = ctx.origin_x;
                const origin_y_local = ctx.origin_y;
                const line_width_local = ctx.line_width;
                const any_dirty_local = ctx.any_dirty;

                const seg_y = origin_y_local + @as(f32, @floatFromInt(seg_info.visual_row)) * r_local.char_height;
                const seg_band = overlay_mod.rowBandForRow(origin_y_local, seg_info.visual_row, r_local.char_height);
                const disable_programming_ligatures = switch (r_local.editor_disable_ligatures) {
                    .never => false,
                    .always => true,
                    .cursor => seg_info.is_current and seg_info.seg_idx == seg_info.cursor_seg,
                };
                const text_start_x = origin_x_local + widget_local.gutter_width + 8 * r_local.uiScaleFactor();

                const seg_hash = cache_helpers.hashSegment(
                    line_text_local,
                    seg_info.seg_start_byte,
                    seg_info.seg_end_byte,
                    ranges_local[0..range_count_local],
                    seg_info.seg_start_col,
                    seg_info.seg_end_col,
                    effective_tokens_local,
                    seg_info.line_start,
                    seg_info.is_current,
                    seg_info.seg_idx == seg_info.cursor_seg,
                    seg_info.cursor_col_vis,
                    seg_info.seg_start_col,
                );
                const dirty = cache_local.segmentDirty(.{ .line_idx = seg_info.line_idx, .seg_idx = seg_info.seg_idx }, seg_hash);
                if (!(ctx.force_redraw or dirty)) return;

                any_dirty_local.* = true;
                if (!r_local.beginEditorTexture()) return;
                defer r_local.endEditorTexture();

                const clip_h = @min(seg_band.h_i + 1, @as(i32, @intFromFloat(height_local)) - seg_band.y_i);
                r_local.beginClip(
                    @intFromFloat(origin_x_local),
                    seg_band.y_i,
                    @intFromFloat(width_local),
                    @max(1, clip_h),
                );
                defer r_local.endClip();

                draw_list_local.clear();
                var list_ok = true;
                list_ok = list_ok and overlay_mod.addRectOp(draw_list_local, origin_x_local, seg_band.y_f, width_local, seg_band.h_f, r_local.theme.background);
                list_ok = list_ok and overlay_mod.addRectOp(draw_list_local, origin_x_local, seg_band.y_f, widget_local.gutter_width, seg_band.h_f, r_local.theme.line_number_bg);

                if (seg_info.seg_idx == seg_info.seg_start_idx) {
                    var num_buf: [16]u8 = undefined;
                    list_ok = list_ok and segment_paint_mod.addEditorLineBaseOps(draw_list_local, r_local, seg_info.line_idx, seg_y, origin_x_local, widget_local.gutter_width, width_local, seg_info.is_current, &num_buf);
                } else if (seg_info.is_current) {
                    list_ok = list_ok and overlay_mod.addRectOp(draw_list_local, origin_x_local, seg_band.y_f, widget_local.gutter_width, seg_band.h_f, r_local.theme.current_line);
                    list_ok = list_ok and overlay_mod.addRectOp(draw_list_local, origin_x_local + widget_local.gutter_width, seg_band.y_f, width_local - widget_local.gutter_width, seg_band.h_f, r_local.theme.current_line);
                }

                if (range_count_local > 0) {
                    const sel_band = overlay_mod.selectionBandForRowBand(seg_band);
                    const selection_color = overlay_mod.softSelectionColor(r_local.theme.selection);
                    var r_i: usize = 0;
                    while (r_i < range_count_local) : (r_i += 1) {
                        const range = ranges_local[r_i];
                        const sel_start = @max(range.start_col, seg_info.seg_start_col);
                        const sel_end = @min(range.end_col, seg_info.seg_end_col);
                        if (sel_end <= sel_start) continue;
                        const sel_x = text_start_x + @as(f32, @floatFromInt(sel_start - seg_info.seg_start_col)) * r_local.char_width;
                        const sel_w = @as(f32, @floatFromInt(sel_end - sel_start)) * r_local.char_width;
                        const corner_mask = overlay_mod.selectionCornerMaskForSegment(view_local, seg_info.line_idx, cols_local, line_width_local, seg_info.seg_idx, seg_info.total_visual_lines, seg_info.seg_start_col, seg_info.seg_end_col, range);
                        list_ok = list_ok and overlay_mod.addSoftSelectionRectOp(draw_list_local, r_local, sel_x, sel_band.y_f, sel_w, sel_band.h_f, selection_color, corner_mask);
                    }
                }

                list_ok = list_ok and segment_paint_mod.addSearchOverlayOps(
                    draw_list_local,
                    view_local,
                    r_local,
                    seg_info.line_start,
                    seg_info.seg_start_byte,
                    seg_info.seg_end_byte,
                    seg_info.seg_start_col,
                    line_text_local,
                    seg_band,
                    text_start_x,
                );

                const base_bg = if (seg_info.is_current) r_local.theme.current_line else r_local.theme.background;
                const selection_bg = overlay_mod.softSelectionColor(r_local.theme.selection);
                var sel_bytes: [8]ByteRange = undefined;
                const sel_count = if (range_count_local > 0)
                    text_mod.buildSelectionByteRanges(
                        line_text_local,
                        cluster_slice_local,
                        seg_info.seg_start_col,
                        seg_info.seg_end_col,
                        seg_info.seg_start_byte,
                        seg_info.seg_end_byte,
                        ranges_local[0..range_count_local],
                        &sel_bytes,
                    )
                else
                    0;

                if (effective_tokens_local.len == 0) {
                    list_ok = list_ok and text_mod.addTextSliceOpsWithSelectionBg(
                        draw_list_local,
                        r_local,
                        text_start_x,
                        seg_y,
                        line_text_local,
                        seg_info.seg_start_byte,
                        seg_info.seg_start_col,
                        seg_info.seg_start_byte,
                        seg_info.seg_end_byte,
                        r_local.theme.foreground,
                        base_bg,
                        selection_bg,
                        sel_bytes[0..sel_count],
                        disable_programming_ligatures,
                    );
                } else {
                    list_ok = list_ok and text_mod.appendHighlightedLineSegmentOps(
                        draw_list_local,
                        r_local,
                        line_text_local,
                        seg_y,
                        text_start_x,
                        seg_info.line_start,
                        seg_info.seg_start_byte,
                        seg_info.seg_end_byte,
                        seg_info.seg_start_col,
                        effective_tokens_local,
                        base_bg,
                        selection_bg,
                        seg_info.seg_start_byte,
                        sel_bytes[0..sel_count],
                        disable_programming_ligatures,
                    );
                }

                if (seg_info.is_current and seg_info.seg_idx == seg_info.cursor_seg) {
                    const local_col = seg_info.cursor_col_vis - seg_info.seg_start_col;
                    const cursor_draw_x = text_start_x + @as(f32, @floatFromInt(local_col)) * r_local.char_width;
                    list_ok = list_ok and overlay_mod.addCursorOp(draw_list_local, cursor_draw_x, seg_y, r_local.char_height, r_local.theme.cursor);
                }
                list_ok = list_ok and overlay_mod.addExtraCaretOps(
                    draw_list_local,
                    view_local,
                    r_local,
                    seg_info.line_idx,
                    line_text_local,
                    cluster_slice_local,
                    seg_info.seg_start_col,
                    seg_info.seg_end_col,
                    line_width_local,
                    seg_y,
                    text_start_x,
                );

                if (list_ok) {
                    overlay_mod.flushDrawList(draw_list_local, r_local);
                    return;
                }

                r_local.drawRect(@intFromFloat(origin_x_local), seg_band.y_i, @intFromFloat(width_local), seg_band.h_i, r_local.theme.background);
                r_local.drawRect(@intFromFloat(origin_x_local), seg_band.y_i, @intFromFloat(widget_local.gutter_width), seg_band.h_i, r_local.theme.line_number_bg);

                if (seg_info.seg_idx == seg_info.seg_start_idx) {
                    var num_buf: [16]u8 = undefined;
                    _ = segment_paint_mod.addEditorLineBaseOps(draw_list_local, r_local, seg_info.line_idx, seg_y, origin_x_local, widget_local.gutter_width, width_local, seg_info.is_current, &num_buf);
                    overlay_mod.flushDrawList(draw_list_local, r_local);
                    draw_list_local.clear();
                } else if (seg_info.is_current) {
                    r_local.drawRect(@intFromFloat(origin_x_local), seg_band.y_i, @intFromFloat(widget_local.gutter_width), seg_band.h_i, r_local.theme.current_line);
                    r_local.drawRect(@intFromFloat(origin_x_local + widget_local.gutter_width), seg_band.y_i, @intFromFloat(width_local - widget_local.gutter_width), seg_band.h_i, r_local.theme.current_line);
                }

                segment_paint_mod.drawSelectionOverlays(view_local, r_local, seg_info.line_idx, cols_local, line_width_local, seg_info.total_visual_lines, seg_info.seg_idx, seg_info.seg_start_col, seg_info.seg_end_col, seg_band, text_start_x, ranges_local[0..range_count_local]);

                segment_paint_mod.drawSegmentText(
                    r_local,
                    line_text_local,
                    cluster_slice_local,
                    seg_y,
                    text_start_x,
                    seg_info.line_start,
                    seg_info.seg_start_byte,
                    seg_info.seg_end_byte,
                    seg_info.seg_start_col,
                    seg_info.seg_end_col,
                    effective_tokens_local,
                    ranges_local[0..range_count_local],
                    seg_info.is_current,
                    disable_programming_ligatures,
                );

                segment_paint_mod.drawSearchOverlays(
                    view_local,
                    r_local,
                    seg_info.line_start,
                    seg_info.seg_start_byte,
                    seg_info.seg_end_byte,
                    seg_info.seg_start_col,
                    line_text_local,
                    seg_band,
                    text_start_x,
                );

                if (seg_info.is_current and seg_info.seg_idx == seg_info.cursor_seg) {
                    const local_col = seg_info.cursor_col_vis - seg_info.seg_start_col;
                    const cursor_draw_x = text_start_x + @as(f32, @floatFromInt(local_col)) * r_local.char_width;
                    overlay_mod.drawLineCursor(r_local, cursor_draw_x, seg_y, r_local.char_height, r_local.theme.cursor);
                }
                overlay_mod.drawExtraCarets(view_local, r_local, seg_info.line_idx, line_text_local, cluster_slice_local, seg_info.seg_start_col, seg_info.seg_end_col, line_width_local, seg_y, text_start_x);
            }
        };
        const ctx = .{
            .widget = widget,
            .view = &view,
            .r = r,
            .cache = cache,
            .draw_list = draw_list,
            .ranges = prepared.selection_ranges,
            .range_count = prepared.selection_count,
            .effective_tokens = prepared.effective_tokens,
            .line_text = prepared.line_text,
            .cluster_slice = prepared.cluster_slice,
            .width = width,
            .height = height,
            .cols = cols,
            .origin_x = origin_x,
            .origin_y = origin_y,
            .line_width = line_width,
            .force_redraw = force_redraw,
            .any_dirty = &any_dirty,
        };
        traversal_mod.walkVisibleSegments(view, prepared.line_text, prepared.cluster_slice, cols, widget.wrap_enabled, start_line, start_seg, line_idx, visible_lines, &visual_row, line_width, ctx, Local.renderSegment);
    }

    if (any_dirty or force_redraw) {
        r.drawEditorTexture(draw_x, draw_y);
    } else {
        r.drawEditorTexture(draw_x, draw_y);
    }

    // Draw scrollbars as final overlays (outside cached editor texture) to avoid
    // stale dirty-region artifacts when geometry changes frame-to-frame.
    if (!widget.wrap_enabled) {
        view = frame_view_mod.EditorFrameView.init(widget.editor, widget.wrap_enabled);
        overlay_mod.drawEditorScrollbars(view, widget.gutter_width, r, draw_x, draw_y, width, height, visible_lines, total_lines, cols, input.mouse_pos, null);
    }
}

pub fn precomputeHighlightTokens(
    widget: anytype,
    cache: *cache_mod.EditorRenderCache,
    shell: anytype,
    height: f32,
    budget_lines: usize,
) void {
    cache_helpers.precomputeHighlightTokens(widget, cache, shell, height, budget_lines);
}

pub fn precomputeLineWidths(
    widget: anytype,
    cache: *cache_mod.EditorRenderCache,
    shell: anytype,
    height: f32,
    budget_lines: usize,
) void {
    cache_helpers.precomputeLineWidths(widget, cache, shell, height, budget_lines);
}

pub fn precomputeWrapCounts(
    widget: anytype,
    cache: *cache_mod.EditorRenderCache,
    shell: anytype,
    height: f32,
    budget_lines: usize,
) void {
    cache_helpers.precomputeWrapCounts(widget, cache, shell, height, budget_lines);
}

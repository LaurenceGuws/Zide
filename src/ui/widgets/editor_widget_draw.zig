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
const renderer_clip_host = @import("../renderer/renderer_clip_host.zig");
const renderer_text_host = @import("../renderer/renderer_text_host.zig");
const overlay_mod = @import("editor_widget_draw_overlay.zig");
const text_mod = @import("editor_widget_draw_text.zig");
const cache_helpers = @import("editor_widget_draw_cache.zig");

const HighlightToken = syntax_mod.HighlightToken;
const SelectionRange = selection_mod.SelectionRange;
const EditorDrawList = draw_list_mod.EditorDrawList;
const ByteRange = overlay_mod.ByteRange;
const Segment = traversal_mod.Segment;

fn clippedEditorRowHeight(seg_band_h: i32, remaining_height: i32) i32 {
    return @max(1, @min(seg_band_h, remaining_height));
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

    segment_paint_mod.drawEditorPaneBaseImmediate(r, x, y, width, height, widget.gutter_width);

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
                const seg_y = y_local + @as(f32, @floatFromInt(seg_info.visual_row)) * r_local.editor_char_height;
                const seg_band = overlay_mod.rowBandForRow(y_local, seg_info.visual_row, r_local.editor_char_height);
                const disable_programming_ligatures = switch (r_local.font_config.editor_disable_ligatures) {
                    .never => false,
                    .always => true,
                    .cursor => seg_info.is_current and seg_info.seg_idx == seg_info.cursor_seg,
                };
                var gutter_num_buf: [16]u8 = undefined;

                const row_band_ok = segment_paint_mod.addEditorRowBandOps(
                    draw_list_local,
                    view_local,
                    r_local,
                    seg_info.line_idx,
                    cols_local,
                    seg_info.line_width,
                    seg_info.total_visual_lines,
                    seg_info.seg_idx,
                    seg_info.seg_start_idx,
                    seg_info.seg_start_col,
                    seg_info.seg_end_col,
                    seg_y,
                    seg_band,
                    x_local,
                    text_start_x_local,
                    widget_local.gutter_width,
                    width_local,
                    line_text_local,
                    cluster_slice_local,
                    seg_info.line_start,
                    seg_info.seg_start_byte,
                    seg_info.seg_end_byte,
                    effective_tokens_local,
                    ranges_local[0..range_count_local],
                    seg_info.is_current,
                    seg_info.seg_idx == seg_info.cursor_seg,
                    seg_info.cursor_col_vis,
                    disable_programming_ligatures,
                    &gutter_num_buf,
                    cursor_draw_x_local,
                    cursor_draw_y_local,
                );
                if (row_band_ok) {
                    overlay_mod.flushDrawListEditorRowBand(draw_list_local, r_local);
                } else {
                    overlay_mod.runImmediateEditorRowBand(
                        r_local,
                        .{
                            .view = view_local,
                            .r = r_local,
                            .seg_info = seg_info,
                            .cols = cols_local,
                            .seg_band = seg_band,
                            .text_start_x = text_start_x_local,
                            .ranges = ranges_local[0..range_count_local],
                            .line_text = line_text_local,
                            .cluster_slice = cluster_slice_local,
                            .effective_tokens = effective_tokens_local,
                            .disable_programming_ligatures = disable_programming_ligatures,
                            .seg_y = seg_y,
                        },
                        struct {
                            fn draw(draw_ctx: anytype) void {
                                if (draw_ctx.ranges.len > 0) {
                                    segment_paint_mod.drawSelectionOverlays(
                                        draw_ctx.view,
                                        draw_ctx.r,
                                        draw_ctx.seg_info.line_idx,
                                        draw_ctx.cols,
                                        draw_ctx.seg_info.line_width,
                                        draw_ctx.seg_info.total_visual_lines,
                                        draw_ctx.seg_info.seg_idx,
                                        draw_ctx.seg_info.seg_start_col,
                                        draw_ctx.seg_info.seg_end_col,
                                        draw_ctx.seg_band,
                                        draw_ctx.text_start_x,
                                        draw_ctx.ranges,
                                    );
                                }

                                segment_paint_mod.drawSearchOverlays(
                                    draw_ctx.view,
                                    draw_ctx.r,
                                    draw_ctx.seg_info.line_start,
                                    draw_ctx.seg_info.seg_start_byte,
                                    draw_ctx.seg_info.seg_end_byte,
                                    draw_ctx.seg_info.seg_start_col,
                                    draw_ctx.line_text,
                                    draw_ctx.seg_band,
                                    draw_ctx.text_start_x,
                                );

                                segment_paint_mod.drawSegmentText(
                                    draw_ctx.r,
                                    draw_ctx.line_text,
                                    draw_ctx.cluster_slice,
                                    draw_ctx.seg_y,
                                    draw_ctx.text_start_x,
                                    draw_ctx.seg_info.line_start,
                                    draw_ctx.seg_info.seg_start_byte,
                                    draw_ctx.seg_info.seg_end_byte,
                                    draw_ctx.seg_info.seg_start_col,
                                    draw_ctx.seg_info.seg_end_col,
                                    draw_ctx.effective_tokens,
                                    draw_ctx.ranges,
                                    draw_ctx.seg_info.is_current,
                                    draw_ctx.disable_programming_ligatures,
                                );
                                overlay_mod.drawExtraCarets(
                                    draw_ctx.view,
                                    draw_ctx.r,
                                    draw_ctx.seg_info.line_idx,
                                    draw_ctx.line_text,
                                    draw_ctx.cluster_slice,
                                    draw_ctx.seg_info.seg_start_col,
                                    draw_ctx.seg_info.seg_end_col,
                                    draw_ctx.seg_info.line_width,
                                    draw_ctx.seg_y,
                                    draw_ctx.text_start_x,
                                );
                            }
                        }.draw,
                    );
                }
                draw_list_local.clear();
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
        overlay_mod.drawLineCursor(r, cursor_draw_x.?, cursor_draw_y.?, r.editor_char_height, r.theme.cursor);
        if (input.composing_active and input.composing_text.len > 0) {
            const comp_x = cursor_draw_x.?;
            const comp_y = cursor_draw_y.?;
            renderer_text_host.drawTextMonospaceOnBg(r, input.composing_text, comp_x, comp_y, r.theme.foreground, r.theme.current_line);
            overlay_mod.drawEditorSurfaceRect(
                r,
                .overlay,
                comp_x,
                comp_y + r.editor_char_height - 2,
                @as(f32, @floatFromInt(input.composing_text.len)) * r.editor_char_width,
                2.0,
                r.theme.selection,
            );
            shell.setTextInputRect(
                @intFromFloat(comp_x),
                @intFromFloat(comp_y),
                @intFromFloat(@as(f32, @floatFromInt(@max(@as(usize, 1), input.composing_text.len))) * r.editor_char_width),
                @intFromFloat(r.editor_char_height),
            );
        } else {
            shell.setTextInputRect(
                @intFromFloat(cursor_draw_x.?),
                @intFromFloat(cursor_draw_y.?),
                @intFromFloat(r.editor_char_width),
                @intFromFloat(r.editor_char_height),
            );
        }
    }

    if (!widget.wrap_enabled) {
        overlay_mod.drawEditorScrollbars(view, widget.gutter_width, r, x, y, width, height, visible_lines, total_lines, cols, input.mouse_pos, &draw_list);
        // Scrollbar rects were appended to the draw list; flush them (deferred GL solids).
        overlay_mod.flushDrawListEditorRowBand(&draw_list, r);
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
    const draw_list = &cache.draw_list;

    // The retained editor surface is still not trustworthy enough in live IDE
    // usage. Keep one honest direct editor path here until the retained seam is
    // either fixed as a separate lane or deleted.
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
    force_redraw = true;

    const origin_x: f32 = draw_x;
    const origin_y: f32 = draw_y;

    var any_dirty = force_redraw;

    if (force_redraw) {
        segment_paint_mod.drawEditorPaneBaseImmediate(r, draw_x, draw_y, width, height, widget.gutter_width);
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

                const seg_y = origin_y_local + @as(f32, @floatFromInt(seg_info.visual_row)) * r_local.editor_char_height;
                const seg_band = overlay_mod.rowBandForRow(origin_y_local, seg_info.visual_row, r_local.editor_char_height);
                const disable_programming_ligatures = switch (r_local.font_config.editor_disable_ligatures) {
                    .never => false,
                    .always => true,
                    .cursor => seg_info.is_current and seg_info.seg_idx == seg_info.cursor_seg,
                };
                var gutter_num_buf: [16]u8 = undefined;
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
                const clip_bottom = @as(i32, @intFromFloat(origin_y_local + height_local));
                const clip_h = clippedEditorRowHeight(seg_band.h_i, clip_bottom - seg_band.y_i);
                renderer_clip_host.beginClip(
                    r_local,
                    @intFromFloat(origin_x_local),
                    seg_band.y_i,
                    @intFromFloat(width_local),
                    @max(1, clip_h),
                );
                defer renderer_clip_host.endClip(r_local);

                draw_list_local.clear();
                var cached_cursor_draw_x: ?f32 = null;
                var cached_cursor_draw_y: ?f32 = null;
                var list_ok = segment_paint_mod.addEditorRowBandOps(
                    draw_list_local,
                    view_local,
                    r_local,
                    seg_info.line_idx,
                    cols_local,
                    line_width_local,
                    seg_info.total_visual_lines,
                    seg_info.seg_idx,
                    seg_info.seg_start_idx,
                    seg_info.seg_start_col,
                    seg_info.seg_end_col,
                    seg_y,
                    seg_band,
                    origin_x_local,
                    text_start_x,
                    widget_local.gutter_width,
                    width_local,
                    line_text_local,
                    cluster_slice_local,
                    seg_info.line_start,
                    seg_info.seg_start_byte,
                    seg_info.seg_end_byte,
                    effective_tokens_local,
                    ranges_local[0..range_count_local],
                    seg_info.is_current,
                    seg_info.seg_idx == seg_info.cursor_seg,
                    seg_info.cursor_col_vis,
                    disable_programming_ligatures,
                    &gutter_num_buf,
                    &cached_cursor_draw_x,
                    &cached_cursor_draw_y,
                );
                if (cached_cursor_draw_x) |cursor_x| {
                    list_ok = list_ok and overlay_mod.addCursorOp(draw_list_local, cursor_x, cached_cursor_draw_y.?, r_local.editor_char_height, r_local.theme.cursor);
                }

                if (list_ok) {
                    overlay_mod.flushDrawListEditorRowBand(draw_list_local, r_local);
                    return;
                }

                overlay_mod.runImmediateEditorRowBand(
                    r_local,
                    .{
                        .view = view_local,
                        .r = r_local,
                        .origin_x = origin_x_local,
                        .seg_y = seg_y,
                        .gutter_width = widget_local.gutter_width,
                        .width = width_local,
                        .seg_info = seg_info,
                        .cols = cols_local,
                        .line_width = line_width_local,
                        .seg_band = seg_band,
                        .text_start_x = text_start_x,
                        .line_text = line_text_local,
                        .cluster_slice = cluster_slice_local,
                        .effective_tokens = effective_tokens_local,
                        .ranges = ranges_local[0..range_count_local],
                        .disable_programming_ligatures = disable_programming_ligatures,
                    },
                    struct {
                        fn draw(draw_ctx: anytype) void {
                            segment_paint_mod.drawEditorSegmentBaseImmediate(
                                draw_ctx.r,
                                draw_ctx.origin_x,
                                draw_ctx.seg_y,
                                draw_ctx.gutter_width,
                                draw_ctx.width,
                                false,
                            );

                            segment_paint_mod.drawEditorRowBandImmediate(
                                draw_ctx.view,
                                draw_ctx.r,
                                draw_ctx.seg_info.line_idx,
                                draw_ctx.cols,
                                draw_ctx.line_width,
                                draw_ctx.seg_info.total_visual_lines,
                                draw_ctx.seg_info.seg_idx,
                                draw_ctx.seg_info.seg_start_col,
                                draw_ctx.seg_info.seg_end_col,
                                draw_ctx.seg_y,
                                draw_ctx.seg_band,
                                draw_ctx.origin_x,
                                draw_ctx.text_start_x,
                                draw_ctx.gutter_width,
                                draw_ctx.width,
                                draw_ctx.line_text,
                                draw_ctx.cluster_slice,
                                draw_ctx.seg_info.line_start,
                                draw_ctx.seg_info.seg_start_byte,
                                draw_ctx.seg_info.seg_end_byte,
                                draw_ctx.effective_tokens,
                                draw_ctx.ranges,
                                draw_ctx.seg_info.is_current,
                                draw_ctx.seg_info.seg_idx == draw_ctx.seg_info.cursor_seg,
                                draw_ctx.seg_info.cursor_col_vis,
                                draw_ctx.disable_programming_ligatures,
                            );
                        }
                    }.draw,
                );
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

    // Draw scrollbars as final overlays (outside cached editor texture) to avoid
    // stale dirty-region artifacts when geometry changes frame-to-frame.
    if (!widget.wrap_enabled) {
        view = frame_view_mod.EditorFrameView.init(widget.editor, widget.wrap_enabled);
        overlay_mod.runImmediateEditorSurfacePhase(
            r,
            .{
                .view = view,
                .gutter_width = widget.gutter_width,
                .r = r,
                .draw_x = draw_x,
                .draw_y = draw_y,
                .width = width,
                .height = height,
                .visible_lines = visible_lines,
                .total_lines = total_lines,
                .cols = cols,
                .mouse_pos = input.mouse_pos,
            },
            struct {
                fn draw(ctx: anytype) void {
                    overlay_mod.drawEditorScrollbars(
                        ctx.view,
                        ctx.gutter_width,
                        ctx.r,
                        ctx.draw_x,
                        ctx.draw_y,
                        ctx.width,
                        ctx.height,
                        ctx.visible_lines,
                        ctx.total_lines,
                        ctx.cols,
                        ctx.mouse_pos,
                        null,
                    );
                }
            }.draw,
        );
    }
}

pub fn precomputeHighlightTokens(
    widget: anytype,
    cache: *cache_mod.EditorRenderCache,
    shell: anytype,
    height: f32,
    budget_lines: usize,
) bool {
    return cache_helpers.precomputeHighlightTokens(widget, cache, shell, height, budget_lines);
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

test "editor dirty row clip does not spill into following row" {
    try std.testing.expectEqual(@as(i32, 16), clippedEditorRowHeight(16, 64));
    try std.testing.expectEqual(@as(i32, 16), clippedEditorRowHeight(16, 16));
    try std.testing.expectEqual(@as(i32, 8), clippedEditorRowHeight(16, 8));
}

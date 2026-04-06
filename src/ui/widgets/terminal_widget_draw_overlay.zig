const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const terminal_publication = @import("../../terminal/core/publication/terminal_publication.zig");
const render_cache_mod = @import("../../terminal/core/publication/render_cache.zig");
const shared_types = @import("../../types/mod.zig");
const common = @import("common.zig");
const hover_mod = @import("terminal_widget_hover.zig");
const debug_geometry_mod = @import("terminal_widget_debug_geometry.zig");
const metal_backend = @import("../renderer/metal_backend.zig");

const Shell = app_shell.Shell;
const Color = app_shell.Color;
const CursorPos = terminal_publication.CursorPos;
const Cell = terminal_publication.Cell;
const RenderCache = render_cache_mod.RenderCache;
const CursorOverlaySample = debug_geometry_mod.CursorOverlaySample;
const MetalTerminalFallbackSample = debug_geometry_mod.MetalTerminalFallbackSample;

const SelectionCornerMask = struct {
    top_left_outward: bool = false,
    top_right_outward: bool = false,
    bottom_left_outward: bool = false,
    bottom_right_outward: bool = false,
    top_left_inward: bool = false,
    top_right_inward: bool = false,
    bottom_left_inward: bool = false,
    bottom_right_inward: bool = false,
};

fn terminalOpaqueColor(color: Color) Color {
    return .{ .r = color.r, .g = color.g, .b = color.b, .a = 255 };
}

fn softSelectionColor(base: Color) Color {
    return .{
        .r = base.r,
        .g = base.g,
        .b = base.b,
        .a = @min(@as(u8, 156), base.a),
    };
}

fn overlayResolvedCursorColors(
    cell: Cell,
    screen_reverse: bool,
) struct { fg: Color, bg: Color } {
    const fg = terminalOpaqueColor(.{ .r = cell.attrs.fg.r, .g = cell.attrs.fg.g, .b = cell.attrs.fg.b, .a = cell.attrs.fg.a });
    const bg = terminalOpaqueColor(.{ .r = cell.attrs.bg.r, .g = cell.attrs.bg.g, .b = cell.attrs.bg.b, .a = cell.attrs.bg.a });
    const cell_reverse = cell.attrs.reverse != screen_reverse;
    const normal_fg = if (cell_reverse) bg else fg;
    const normal_bg = if (cell_reverse) fg else bg;
    return .{
        .fg = normal_bg,
        .bg = normal_fg,
    };
}

fn followedBySpace(row_cells: []const Cell, cols: usize, col: usize, width_units: usize) bool {
    const next_col = col + width_units;
    if (next_col >= cols or next_col >= row_cells.len) return true;
    const next = row_cells[next_col];
    return next.codepoint == 0 or next.codepoint == ' ';
}

fn drawSoftSelectionRect(r: anytype, x: i32, y: i32, w: i32, h: i32, color: Color, mask: SelectionCornerMask) void {
    if (w <= 0 or h <= 0) return;
    const style = r.terminalSelectionOverlayStyle();
    if (!style.smooth_enabled) {
        r.drawRect(x, y, w, h, color);
        return;
    }
    const corner_px = style.corner_px orelse @max(1.0, std.math.floor(r.uiScaleFactor() * 0.75));
    const inset_x = @max(1, @as(i32, @intFromFloat(std.math.round(corner_px))));
    const pad_px = style.pad_px orelse @max(1.0, std.math.round(r.uiScaleFactor() * 0.5));
    const pad_x = @max(0, @as(i32, @intFromFloat(std.math.round(pad_px))));
    const draw_x = x + inset_x - pad_x;
    const draw_y = y;
    const draw_w = @max(1, w - inset_x * 2 + pad_x * 2);
    const draw_h = h;
    const corner = @max(1, @min(inset_x, @divFloor(draw_h, 4)));
    const cornerDelta = struct {
        fn resolve(outward: bool, inward: bool, amount: i32) i32 {
            if (outward) return amount;
            if (inward) return -amount;
            return 0;
        }
    }.resolve;
    const top_left_inset = cornerDelta(mask.top_left_outward, mask.top_left_inward, corner);
    const top_right_inset = cornerDelta(mask.top_right_outward, mask.top_right_inward, corner);
    const bottom_left_inset = cornerDelta(mask.bottom_left_outward, mask.bottom_left_inward, corner);
    const bottom_right_inset = cornerDelta(mask.bottom_right_outward, mask.bottom_right_inward, corner);
    const top_left_edge = top_left_inset;
    const top_right_edge = top_right_inset;
    const bottom_left_edge = bottom_left_inset;
    const bottom_right_edge = bottom_right_inset;

    const drawTopRow = struct {
        fn draw(r_local: anytype, x_local: i32, y_local: i32, w_local: i32, color_local: Color, left_inset: i32, right_inset: i32) void {
            const line_x = x_local + left_inset;
            const line_w = w_local - left_inset - right_inset;
            if (line_w > 0) r_local.drawRect(line_x, y_local, line_w, 1, color_local);
        }
    }.draw;

    switch (draw_h) {
        1 => {
            drawTopRow(r, draw_x, draw_y, draw_w, color, if (top_left_edge != 0) top_left_edge else bottom_left_edge, if (top_right_edge != 0) top_right_edge else bottom_right_edge);
            return;
        },
        2 => {
            drawTopRow(r, draw_x, draw_y, draw_w, color, top_left_edge, top_right_edge);
            drawTopRow(r, draw_x, draw_y + 1, draw_w, color, bottom_left_edge, bottom_right_edge);
            return;
        },
        else => {},
    }

    if (top_left_edge == 0 and top_right_edge == 0 and bottom_left_edge == 0 and bottom_right_edge == 0) {
        r.drawRect(draw_x, draw_y, draw_w, draw_h, color);
        return;
    }

    drawTopRow(r, draw_x, draw_y, draw_w, color, top_left_edge, top_right_edge);
    r.drawRect(draw_x, draw_y + 1, draw_w, draw_h - 2, color);
    drawTopRow(r, draw_x, draw_y + draw_h - 1, draw_w, color, bottom_left_edge, bottom_right_edge);
}

fn rowSelectionNearColumn(cache: *const RenderCache, selection_rows: []const bool, row_idx: usize, col: usize, tolerance: usize) bool {
    if (row_idx >= selection_rows.len or !selection_rows[row_idx]) return false;
    const start = @as(usize, cache.selection_cols_start.items[row_idx]);
    const end = @as(usize, cache.selection_cols_end.items[row_idx]);
    const low = col -| tolerance;
    const high = col + tolerance;
    return !(end < low or start > high);
}

fn rowSelectionStart(cache: *const RenderCache, row_idx: usize) usize {
    return @as(usize, cache.selection_cols_start.items[row_idx]);
}

fn rowSelectionEnd(cache: *const RenderCache, row_idx: usize) usize {
    return @as(usize, cache.selection_cols_end.items[row_idx]);
}

fn rowSlice(cells: []const Cell, cols_count: usize, row: usize) []const Cell {
    const row_start = row * cols_count;
    if (row_start + cols_count > cells.len) return cells[0..0];
    return cells[row_start .. row_start + cols_count];
}

pub fn drawOverlays(
    self: anytype,
    shell: *Shell,
    view: shared_types.layout.TerminalViewGeometry,
    input: shared_types.input.InputSnapshot,
    cache: *const RenderCache,
    view_cells: []const Cell,
    screen_reverse: bool,
    hover_link_id: u32,
    draw_cursor: bool,
    cursor: CursorPos,
    cursor_style: @TypeOf(RenderCache.init().cursor_style),
    metal_fallback_sample: ?*MetalTerminalFallbackSample,
) void {
    const r = shell.rendererPtr();
    const composing_len: usize = if (input.composing_active and input.composing_text.len > 0) blk: {
        var count: usize = 0;
        var count_iter = std.unicode.Utf8Iterator{ .bytes = input.composing_text, .i = 0 };
        while (count_iter.nextCodepoint()) |_| count += 1;
        break :blk count;
    } else 0;

    if (view.rows > 0 and view.cols > 0 and cache.hasSelection()) {
        const selection_rows = cache.selection_rows.items;
        if (selection_rows.len == view.rows) {
            const selection_color = softSelectionColor(r.theme.selection);
            const cell_w = view.cell_width;
            const cell_h = view.cell_height;

            var row_idx: usize = 0;
            while (row_idx < view.rows) : (row_idx += 1) {
                if (!selection_rows[row_idx]) continue;
                const col_start = @as(usize, cache.selection_cols_start.items[row_idx]);
                const col_end = @as(usize, cache.selection_cols_end.items[row_idx]);
                if (col_end < col_start or col_end >= view.cols) continue;

                const rect_x = @as(i32, @intFromFloat(std.math.round(view.origin_x + @as(f32, @floatFromInt(@as(i32, @intCast(col_start)))) * cell_w)));
                const rect_y = @as(i32, @intFromFloat(std.math.round(view.origin_y + @as(f32, @floatFromInt(@as(i32, @intCast(row_idx)))) * cell_h)));
                const rect_w = @as(i32, @intFromFloat(std.math.round(cell_w * @as(f32, @floatFromInt(@as(i32, @intCast(col_end - col_start + 1)))))));
                const rect_h = @as(i32, @intFromFloat(std.math.round(cell_h)));
                const has_prev = row_idx > 0 and selection_rows[row_idx - 1];
                const has_next = row_idx + 1 < view.rows and selection_rows[row_idx + 1];
                const edge_tolerance: usize = 1;

                drawSoftSelectionRect(
                    r,
                    rect_x,
                    rect_y,
                    rect_w,
                    rect_h,
                    selection_color,
                    .{
                        .top_left_outward = !has_prev or !rowSelectionNearColumn(cache, selection_rows, row_idx - 1, col_start, edge_tolerance),
                        .top_right_outward = !has_prev or !rowSelectionNearColumn(cache, selection_rows, row_idx - 1, col_end, edge_tolerance),
                        .bottom_left_outward = !has_next or !rowSelectionNearColumn(cache, selection_rows, row_idx + 1, col_start, edge_tolerance),
                        .bottom_right_outward = !has_next or !rowSelectionNearColumn(cache, selection_rows, row_idx + 1, col_end, edge_tolerance),
                        .top_left_inward = has_prev and rowSelectionNearColumn(cache, selection_rows, row_idx - 1, col_start, edge_tolerance) and rowSelectionStart(cache, row_idx - 1) + edge_tolerance < col_start,
                        .top_right_inward = has_prev and rowSelectionNearColumn(cache, selection_rows, row_idx - 1, col_end, edge_tolerance) and rowSelectionEnd(cache, row_idx - 1) > col_end + edge_tolerance,
                        .bottom_left_inward = has_next and rowSelectionNearColumn(cache, selection_rows, row_idx + 1, col_start, edge_tolerance) and rowSelectionStart(cache, row_idx + 1) + edge_tolerance < col_start,
                        .bottom_right_inward = has_next and rowSelectionNearColumn(cache, selection_rows, row_idx + 1, col_end, edge_tolerance) and rowSelectionEnd(cache, row_idx + 1) > col_end + edge_tolerance,
                    },
                );
            }
        }
    }

    hover_mod.drawHoverUnderlineOverlay(r, view, hover_link_id, view_cells);

    if (draw_cursor and view.rows > 0 and view.cols > 0 and cursor.row < view.rows and cursor.col < view.cols and view_cells.len >= view.rows * view.cols) {
        const row_cells = rowSlice(view_cells, view.cols, cursor.row);
        if (row_cells.len != 0) {
            const cell = row_cells[cursor.col];
            const cell_width_units = @as(usize, @max(@as(u8, 1), cell.width));
            const cell_w_f = view.cell_width;
            const cell_h_f = view.cell_height;
            const pixel_step = r.devicePixelStep();
            const render_scale = 1.0 / pixel_step;
            const cell_x = view.origin_x + @as(f32, @floatFromInt(@as(i32, @intCast(cursor.col)))) * view.cell_width;
            const cell_y = view.origin_y + @as(f32, @floatFromInt(@as(i32, @intCast(cursor.row)))) * view.cell_height;
            const cursor_edge_inset: i32 = @max(0, @as(i32, @intFromFloat(std.math.floor(r.uiScaleFactor() * 0.5))));
            const cursor_stroke: i32 = @max(1, @as(i32, @intFromFloat(std.math.round(r.uiScaleFactor()))));
            const cursor_edge_inset_f = @as(f32, @floatFromInt(cursor_edge_inset));
            const cursor_stroke_f = @as(f32, @floatFromInt(cursor_stroke));

            var fg = Color{ .r = cell.attrs.fg.r, .g = cell.attrs.fg.g, .b = cell.attrs.fg.b, .a = cell.attrs.fg.a };
            const bg = Color{ .r = cell.attrs.bg.r, .g = cell.attrs.bg.g, .b = cell.attrs.bg.b, .a = cell.attrs.bg.a };
            const underline_color = Color{ .r = cell.attrs.underline_color.r, .g = cell.attrs.underline_color.g, .b = cell.attrs.underline_color.b, .a = cell.attrs.underline_color.a };
            if (cell.attrs.link_id != 0) fg = r.theme.link;
            var underline = cell.attrs.underline;
            if (cell.attrs.link_id != 0) underline = cell.attrs.link_id == hover_link_id;

            const cursor_w = cell_w_f * @as(f32, @floatFromInt(@as(i32, @intCast(cell_width_units))));
            const cursor_h = cell_h_f;
            var sample_cursor_x = cell_x;
            var sample_cursor_y = cell_y;
            var sample_cursor_w = cursor_w;
            var sample_cursor_h = cursor_h;
            const ui_focused = self.controller.focus.isUiFocused();
            if (!ui_focused) {
                const border_w = pixel_step;
                const box_x = cell_x + cursor_edge_inset_f;
                const box_y = cell_y + cursor_edge_inset_f;
                const box_w = @max(border_w * 2.0, cursor_w - cursor_edge_inset_f * 2.0);
                const box_h = @max(border_w * 2.0, cursor_h - cursor_edge_inset_f * 2.0);
                sample_cursor_x = box_x;
                sample_cursor_y = box_y;
                sample_cursor_w = box_w;
                sample_cursor_h = box_h;
                r.drawRectF(box_x, box_y, box_w, border_w, r.theme.cursor);
                r.drawRectF(box_x, box_y + box_h - border_w, box_w, border_w, r.theme.cursor);
                r.drawRectF(box_x, box_y, border_w, box_h, r.theme.cursor);
                r.drawRectF(box_x + box_w - border_w, box_y, border_w, box_h, r.theme.cursor);
            } else switch (cursor_style.shape) {
                .block => {
                    sample_cursor_x = cell_x;
                    sample_cursor_y = cell_y;
                    sample_cursor_w = cursor_w;
                    sample_cursor_h = cursor_h;
                    const colors = overlayResolvedCursorColors(cell, screen_reverse);
                    const followed_by_space = followedBySpace(row_cells, view.cols, cursor.col, cell_width_units);
                    if (cell.combining_len > 0) {
                        r.drawTerminalCellGraphemeBatched(
                            cell.codepoint,
                            cell.combining[0..@intCast(cell.combining_len)],
                            cell_x,
                            cell_y,
                            cursor_w,
                            cursor_h,
                            colors.fg,
                            colors.bg,
                            underline_color,
                            cell.attrs.bold,
                            underline,
                            false,
                            followed_by_space,
                            true,
                        );
                    } else {
                        r.drawTerminalCellBatched(
                            cell.codepoint,
                            cell_x,
                            cell_y,
                            cursor_w,
                            cursor_h,
                            colors.fg,
                            colors.bg,
                            underline_color,
                            cell.attrs.bold,
                            underline,
                            false,
                            followed_by_space,
                            true,
                        );
                    }
                },
                .underline => {
                    const draw_x = cell_x + cursor_edge_inset_f;
                    const draw_w = @max(pixel_step, cursor_w - cursor_edge_inset_f * 2.0);
                    const draw_y = cell_y + cursor_h - cursor_stroke_f - cursor_edge_inset_f;
                    sample_cursor_x = draw_x;
                    sample_cursor_y = draw_y;
                    sample_cursor_w = draw_w;
                    sample_cursor_h = cursor_stroke_f;
                    r.drawRectF(draw_x, draw_y, draw_w, cursor_stroke_f, r.theme.cursor);
                },
                .bar => {
                    const draw_x = cell_x + cursor_edge_inset_f;
                    const draw_y = cell_y + cursor_edge_inset_f;
                    const draw_h = @max(pixel_step, view.cell_height - cursor_edge_inset_f * 2.0);
                    sample_cursor_x = draw_x;
                    sample_cursor_y = draw_y;
                    sample_cursor_w = cursor_stroke_f;
                    sample_cursor_h = draw_h;
                    r.drawRectF(draw_x, draw_y, cursor_stroke_f, draw_h, r.theme.cursor);
                },
            }

            const composing_cells: usize = composing_len;
            const cursor_rect_w_f = if (composing_cells > 0) @as(f32, @floatFromInt(@as(i32, @intCast(@max(@as(usize, 1), composing_cells))))) * view.cell_width else view.cell_width;
            self.debug.last_cursor_overlay = CursorOverlaySample{
                .valid = true,
                .generation = cache.generation,
                .row = cursor.row,
                .col = cursor.col,
                .codepoint = cell.codepoint,
                .width_units = cell_width_units,
                .cell_x = cell_x,
                .cell_y = cell_y,
                .cell_w = cursor_w,
                .cell_h = cursor_h,
                .cursor_x = sample_cursor_x,
                .cursor_y = sample_cursor_y,
                .cursor_w = sample_cursor_w,
                .cursor_h = sample_cursor_h,
                .text_input_w = cursor_rect_w_f,
                .edge_inset = cursor_edge_inset_f,
                .stroke = cursor_stroke_f,
                .render_scale = render_scale,
            };
            shell.setTextInputRect(
                @as(i32, @intFromFloat(std.math.round(cell_x))),
                @as(i32, @intFromFloat(std.math.round(cell_y))),
                @as(i32, @intFromFloat(std.math.round(cursor_rect_w_f))),
                @as(i32, @intFromFloat(std.math.round(cursor_h))),
            );

            if (composing_cells > 0) {
                var use_metal_row_fallback = r.textRenderingMode() == .unavailable and r.plannedTextRenderingMode() == .metal_texture_atlas;
                if (use_metal_row_fallback) {
                    for (input.composing_text) |byte| {
                        if (byte >= 0x80) {
                            use_metal_row_fallback = false;
                            break;
                        }
                    }
                }

                var comp_col: usize = 0;
                if (use_metal_row_fallback) {
                    _ = metal_backend.drawTerminalCellRun(r, &r.terminal_font, .{
                        .text = input.composing_text,
                        .x = cell_x,
                        .y = cell_y,
                        .cell_width = view.cell_width,
                        .cell_height = view.cell_height,
                        .tint = r.theme.foreground.toRgba(),
                    });
                    comp_col = composing_cells;
                    if (metal_fallback_sample) |sample| {
                        sample.overlay_row_runs += 1;
                        sample.overlay_row_cells += comp_col;
                    }
                } else {
                    var iter = std.unicode.Utf8Iterator{ .bytes = input.composing_text, .i = 0 };
                    while (iter.nextCodepoint()) |cp| {
                        const comp_x = cell_x + @as(f32, @floatFromInt(@as(i32, @intCast(comp_col)))) * view.cell_width;
                        r.drawTerminalCellBatched(cp, comp_x, cell_y, view.cell_width, view.cell_height, r.theme.foreground, bg, underline_color, false, true, false, true, false);
                        comp_col += 1;
                    }
                }
                const underline_w = @as(f32, @floatFromInt(@as(i32, @intCast(@max(@as(usize, 1), comp_col))))) * view.cell_width;
                const underline_h = 2.0 * pixel_step;
                r.drawRectF(cell_x, cell_y + cursor_h - underline_h, underline_w, underline_h, r.theme.selection);
            }
        }
    }
}

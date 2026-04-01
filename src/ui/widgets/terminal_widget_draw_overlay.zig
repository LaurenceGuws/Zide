const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const app_logger = @import("../../app_logger.zig");
const terminal_publication = @import("../../terminal/core/terminal_publication.zig");
const render_cache_mod = @import("../../terminal/core/render_cache.zig");
const shared_types = @import("../../types/mod.zig");
const common = @import("common.zig");
const hover_mod = @import("terminal_widget_hover.zig");

const Shell = app_shell.Shell;
const Color = app_shell.Color;
const CursorPos = terminal_publication.CursorPos;
const Cell = terminal_publication.Cell;
const RenderCache = render_cache_mod.RenderCache;

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

fn softSelectionColor(base: Color) Color {
    return .{
        .r = base.r,
        .g = base.g,
        .b = base.b,
        .a = @min(@as(u8, 156), base.a),
    };
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
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    input: shared_types.input.InputSnapshot,
    cache: *const RenderCache,
    view_cells: []const Cell,
    rows: usize,
    cols: usize,
    screen_reverse: bool,
    hover_link_id: u32,
    draw_cursor: bool,
    cursor: CursorPos,
    cursor_style: @TypeOf(RenderCache.init().cursor_style),
) void {
    _ = width;
    _ = height;
    _ = screen_reverse;
    const r = shell.rendererPtr();
    const composing_len: usize = if (input.composing_active and input.composing_text.len > 0) blk: {
        var count: usize = 0;
        var count_iter = std.unicode.Utf8Iterator{ .bytes = input.composing_text, .i = 0 };
        while (count_iter.nextCodepoint()) |_| count += 1;
        break :blk count;
    } else 0;

    if (rows > 0 and cols > 0 and cache.hasSelection()) {
        const selection_rows = cache.selection_rows.items;
        if (selection_rows.len == rows) {
            const selection_color = softSelectionColor(r.theme.selection);
            const geom = r.terminalCellGeometry();
            const cell_w = geom.cell_width_logical_exact;
            const cell_h = geom.cell_height_logical_exact;

            var row_idx: usize = 0;
            while (row_idx < rows) : (row_idx += 1) {
                if (!selection_rows[row_idx]) continue;
                const col_start = @as(usize, cache.selection_cols_start.items[row_idx]);
                const col_end = @as(usize, cache.selection_cols_end.items[row_idx]);
                if (col_end < col_start or col_end >= cols) continue;

                const rect_x = @as(i32, @intFromFloat(std.math.round(x + @as(f32, @floatFromInt(@as(i32, @intCast(col_start)))) * cell_w)));
                const rect_y = @as(i32, @intFromFloat(std.math.round(y + @as(f32, @floatFromInt(@as(i32, @intCast(row_idx)))) * cell_h)));
                const rect_w = @as(i32, @intFromFloat(std.math.round(cell_w * @as(f32, @floatFromInt(@as(i32, @intCast(col_end - col_start + 1)))))));
                const rect_h = @as(i32, @intFromFloat(std.math.round(cell_h)));
                const has_prev = row_idx > 0 and selection_rows[row_idx - 1];
                const has_next = row_idx + 1 < rows and selection_rows[row_idx + 1];
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

    hover_mod.drawHoverUnderlineOverlay(r, x, y, rows, cols, hover_link_id, view_cells);

    if (draw_cursor and rows > 0 and cols > 0 and cursor.row < rows and cursor.col < cols and view_cells.len >= rows * cols) {
        const row_cells = rowSlice(view_cells, cols, cursor.row);
        if (row_cells.len != 0) {
            const cell = row_cells[cursor.col];
            const cell_width_units = @as(usize, @max(@as(u8, 1), cell.width));
            const geom = r.terminalCellGeometry();
            const cell_w_i: i32 = geom.cell_width_device_px;
            const cell_h_i: i32 = geom.cell_height_device_px;
            const cell_x = x + @as(f32, @floatFromInt(@as(i32, @intCast(cursor.col)))) * geom.cell_width_logical_exact;
            const cell_y = y + @as(f32, @floatFromInt(@as(i32, @intCast(cursor.row)))) * geom.cell_height_logical_exact;
            const cell_x_i = @as(i32, @intFromFloat(std.math.round(cell_x)));
            const cell_y_i = @as(i32, @intFromFloat(std.math.round(cell_y)));
            const cursor_edge_inset: i32 = @max(0, @as(i32, @intFromFloat(std.math.floor(r.uiScaleFactor() * 0.5))));
            const cursor_stroke: i32 = @max(1, @as(i32, @intFromFloat(std.math.round(r.uiScaleFactor()))));

            var fg = Color{ .r = cell.attrs.fg.r, .g = cell.attrs.fg.g, .b = cell.attrs.fg.b, .a = cell.attrs.fg.a };
            const bg = Color{ .r = cell.attrs.bg.r, .g = cell.attrs.bg.g, .b = cell.attrs.bg.b, .a = cell.attrs.bg.a };
            const underline_color = Color{ .r = cell.attrs.underline_color.r, .g = cell.attrs.underline_color.g, .b = cell.attrs.underline_color.b, .a = cell.attrs.underline_color.a };
            if (cell.attrs.link_id != 0) fg = r.theme.link;
            var underline = cell.attrs.underline;
            if (cell.attrs.link_id != 0) underline = cell.attrs.link_id == hover_link_id;

            const cursor_w_i: i32 = cell_w_i * @as(i32, @intCast(cell_width_units));
            if (!self.ui_focused) {
                const border_w: i32 = 1;
                const box_x = cell_x_i + cursor_edge_inset;
                const box_y = cell_y_i + cursor_edge_inset;
                const box_w = @max(border_w * 2, cursor_w_i - cursor_edge_inset * 2);
                const box_h = @max(border_w * 2, cell_h_i - cursor_edge_inset * 2);
                r.drawRect(box_x, box_y, box_w, border_w, r.theme.cursor);
                r.drawRect(box_x, box_y + box_h - border_w, box_w, border_w, r.theme.cursor);
                r.drawRect(box_x, box_y, border_w, box_h, r.theme.cursor);
                r.drawRect(box_x + box_w - border_w, box_y, border_w, box_h, r.theme.cursor);
            } else switch (cursor_style.shape) {
                .block => {},
                .underline => {
                    const draw_x = cell_x_i + cursor_edge_inset;
                    const draw_w = @max(1, cursor_w_i - cursor_edge_inset * 2);
                    const draw_y = cell_y_i + cell_h_i - cursor_stroke - cursor_edge_inset;
                    r.drawRect(draw_x, draw_y, draw_w, cursor_stroke, r.theme.cursor);
                },
                .bar => {
                    const inset_f = @as(f32, @floatFromInt(cursor_edge_inset));
                    const stroke_f = @as(f32, @floatFromInt(cursor_stroke));
                    const draw_x = cell_x + inset_f;
                    const draw_y = cell_y + inset_f;
                    const draw_h = @max(1.0, geom.cell_height_logical_exact - inset_f * 2.0);
                    r.drawRectF(draw_x, draw_y, stroke_f, draw_h, r.theme.cursor);
                },
            }

            const composing_cells: usize = composing_len;
            const cursor_rect_w = if (composing_cells > 0) @as(i32, @intFromFloat(std.math.round(@as(f32, @floatFromInt(@as(i32, @intCast(@max(@as(usize, 1), composing_cells))))) * geom.cell_width_logical_exact))) else @as(i32, @intFromFloat(std.math.round(geom.cell_width_logical_exact)));
            shell.setTextInputRect(cell_x_i, cell_y_i, cursor_rect_w, cell_h_i);

            if (composing_cells > 0) {
                var iter = std.unicode.Utf8Iterator{ .bytes = input.composing_text, .i = 0 };
                var comp_col: usize = 0;
                while (iter.nextCodepoint()) |cp| {
                    const comp_x = cell_x + @as(f32, @floatFromInt(@as(i32, @intCast(comp_col)))) * geom.cell_width_logical_exact;
                    r.drawTerminalCell(cp, comp_x, cell_y, geom.cell_width_logical_exact, geom.cell_height_logical_exact, r.theme.foreground, bg, underline_color, false, true, false, true, false);
                    comp_col += 1;
                }
                const underline_w = @as(i32, @intFromFloat(std.math.round(@as(f32, @floatFromInt(@as(i32, @intCast(@max(@as(usize, 1), comp_col))))) * geom.cell_width_logical_exact)));
                r.drawRect(cell_x_i, cell_y_i + cell_h_i - 2, underline_w, 2, r.theme.selection);
            }
        }
    }
}

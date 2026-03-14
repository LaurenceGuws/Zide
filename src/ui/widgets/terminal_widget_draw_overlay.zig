const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const terminal_mod = @import("../../terminal/core/terminal.zig");
const render_cache_mod = @import("../../terminal/core/render_cache.zig");
const shared_types = @import("../../types/mod.zig");
const common = @import("common.zig");
const hover_mod = @import("terminal_widget_hover.zig");

const Shell = app_shell.Shell;
const Color = app_shell.Color;
const CursorPos = terminal_mod.CursorPos;
const Cell = terminal_mod.Cell;
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
    scroll_offset: usize,
    total_lines: usize,
    max_scroll_offset: usize,
    screen_reverse: bool,
    hover_link_id: u32,
    draw_cursor: bool,
    cursor: CursorPos,
    cursor_style: @TypeOf(RenderCache.init().cursor_style),
) void {
    const r = shell.rendererPtr();
    const show_scrollbar = !cache.alt_active and !cache.mouse_reporting_active and total_lines > rows;
    const composing_len: usize = if (input.composing_active and input.composing_text.len > 0) blk: {
        var count: usize = 0;
        var count_iter = std.unicode.Utf8Iterator{ .bytes = input.composing_text, .i = 0 };
        while (count_iter.nextCodepoint()) |_| count += 1;
        break :blk count;
    } else 0;

    if (rows > 0 and cols > 0 and cache.selection_active) {
        const selection_rows = cache.selection_rows.items;
        if (selection_rows.len == rows) {
            const selection_color = softSelectionColor(r.theme.selection);
            const cell_w_i: i32 = @intFromFloat(std.math.round(r.terminal_cell_width));
            const cell_h_i: i32 = @intFromFloat(std.math.round(r.terminal_cell_height));
            const base_x_i: i32 = @intFromFloat(std.math.round(x));
            const base_y_i: i32 = @intFromFloat(std.math.round(y));

            var row_idx: usize = 0;
            while (row_idx < rows) : (row_idx += 1) {
                if (!selection_rows[row_idx]) continue;
                const col_start = @as(usize, cache.selection_cols_start.items[row_idx]);
                const col_end = @as(usize, cache.selection_cols_end.items[row_idx]);
                if (col_end < col_start or col_end >= cols) continue;

                const rect_x = base_x_i + @as(i32, @intCast(col_start)) * cell_w_i;
                const rect_y = base_y_i + @as(i32, @intCast(row_idx)) * cell_h_i;
                const rect_w = cell_w_i * @as(i32, @intCast(col_end - col_start + 1));
                const rect_h = cell_h_i;
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
            const cell_w_i: i32 = @intFromFloat(std.math.round(r.terminal_cell_width));
            const cell_h_i: i32 = @intFromFloat(std.math.round(r.terminal_cell_height));
            const base_x_i: i32 = @intFromFloat(std.math.round(x));
            const base_y_i: i32 = @intFromFloat(std.math.round(y));
            const cell_x_i = base_x_i + @as(i32, @intCast(cursor.col)) * cell_w_i;
            const cell_y_i = base_y_i + @as(i32, @intCast(cursor.row)) * cell_h_i;
            const cell_x = @as(f32, @floatFromInt(cell_x_i));
            const cell_y = @as(f32, @floatFromInt(cell_y_i));
            const cursor_edge_inset: i32 = @max(0, @as(i32, @intFromFloat(std.math.floor(r.uiScaleFactor() * 0.5))));
            const cursor_stroke: i32 = @max(1, @as(i32, @intFromFloat(std.math.round(r.uiScaleFactor()))));

            var fg = Color{ .r = cell.attrs.fg.r, .g = cell.attrs.fg.g, .b = cell.attrs.fg.b, .a = cell.attrs.fg.a };
            const bg = Color{ .r = cell.attrs.bg.r, .g = cell.attrs.bg.g, .b = cell.attrs.bg.b, .a = cell.attrs.bg.a };
            const underline_color = Color{ .r = cell.attrs.underline_color.r, .g = cell.attrs.underline_color.g, .b = cell.attrs.underline_color.b, .a = cell.attrs.underline_color.a };
            if (cell.attrs.link_id != 0) fg = r.theme.link;
            var underline = cell.attrs.underline;
            if (cell.attrs.link_id != 0) underline = cell.attrs.link_id == hover_link_id;

            const cell_reverse = cell.attrs.reverse != screen_reverse;
            const followed_by_space = blk: {
                const next_col = cursor.col + cell_width_units;
                if (next_col < cols) {
                    const next_cell = row_cells[next_col];
                    break :blk next_cell.codepoint == ' ' or next_cell.codepoint == 0;
                }
                break :blk true;
            };

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
                .block => {
                    if (cell.combining_len > 0) {
                        r.drawTerminalCellGrapheme(cell.codepoint, cell.combining[0..@intCast(cell.combining_len)], cell_x, cell_y, @as(f32, @floatFromInt(cursor_w_i)), @as(f32, @floatFromInt(cell_h_i)), if (cell_reverse) bg else fg, if (cell_reverse) fg else bg, underline_color, cell.attrs.bold, underline, true, followed_by_space, true);
                    } else {
                        r.drawTerminalCell(cell.codepoint, cell_x, cell_y, @as(f32, @floatFromInt(cursor_w_i)), @as(f32, @floatFromInt(cell_h_i)), if (cell_reverse) bg else fg, if (cell_reverse) fg else bg, underline_color, cell.attrs.bold, underline, true, followed_by_space, true);
                    }
                },
                .underline => {
                    const draw_x = cell_x_i + cursor_edge_inset;
                    const draw_w = @max(1, cursor_w_i - cursor_edge_inset * 2);
                    const draw_y = cell_y_i + cell_h_i - cursor_stroke - cursor_edge_inset;
                    r.drawRect(draw_x, draw_y, draw_w, cursor_stroke, r.theme.cursor);
                },
                .bar => {
                    const draw_x = cell_x_i + cursor_edge_inset;
                    const draw_h = @max(1, cell_h_i - cursor_edge_inset * 2);
                    const draw_y = cell_y_i + @divFloor(cell_h_i - draw_h, 2);
                    r.drawRect(draw_x, draw_y, cursor_stroke, draw_h, r.theme.cursor);
                },
            }

            const composing_cells: usize = composing_len;
            const cursor_rect_w = if (composing_cells > 0) @as(i32, @intCast(@max(@as(usize, 1), composing_cells))) * cell_w_i else cell_w_i;
            shell.setTextInputRect(cell_x_i, cell_y_i, cursor_rect_w, cell_h_i);

            if (composing_cells > 0) {
                var iter = std.unicode.Utf8Iterator{ .bytes = input.composing_text, .i = 0 };
                var comp_col: usize = 0;
                while (iter.nextCodepoint()) |cp| {
                    const comp_x = cell_x + @as(f32, @floatFromInt(@as(i32, @intCast(comp_col)) * cell_w_i));
                    r.drawTerminalCell(cp, comp_x, cell_y, @as(f32, @floatFromInt(cell_w_i)), @as(f32, @floatFromInt(cell_h_i)), r.theme.foreground, bg, underline_color, false, true, false, true, false);
                    comp_col += 1;
                }
                const underline_w = @as(i32, @intCast(@max(@as(usize, 1), comp_col))) * cell_w_i;
                r.drawRect(cell_x_i, cell_y_i + cell_h_i - 2, underline_w, 2, r.theme.selection);
            }
        }
    }

    if (show_scrollbar and height > 0 and width > 0) {
        const scrollbar_base_w: f32 = common.scrollbarWidth(r.uiScaleFactor());
        const scrollbar_hover_w: f32 = common.scrollbarHoverWidth(r.uiScaleFactor());
        const scrollbar_w: f32 = common.lerp(scrollbar_base_w, scrollbar_hover_w, self.scrollbar_hover_anim);
        const scrollbar_x = x + width - scrollbar_w;
        const scrollbar_y = y;
        const scrollbar_h = height;
        const min_thumb_h: f32 = 18;
        const ratio = common.scrollbarTrackRatio(max_scroll_offset, scroll_offset);
        const thumb = common.computeScrollbarThumb(scrollbar_y, scrollbar_h, rows, total_lines, min_thumb_h, ratio);
        const show_track = self.scrollbar_drag_active or self.scrollbar_hover_anim > 0.05;
        if (show_track) {
            r.drawRect(@intFromFloat(scrollbar_x), @intFromFloat(scrollbar_y), @intFromFloat(scrollbar_w), @intFromFloat(scrollbar_h), r.theme.line_number_bg);
        }
        const thumb_inset = if (show_track) @max(1.0, scrollbar_w * 0.25) else 0;
        const thumb_w = @max(1.0, scrollbar_w - thumb_inset * 2);
        r.drawRect(@intFromFloat(scrollbar_x + thumb_inset), @intFromFloat(thumb.thumb_y), @intFromFloat(thumb_w), @intFromFloat(thumb.thumb_h), r.theme.selection);
    }

    if (scroll_offset > 0 and width > 0 and height > 0) {
        const scrollbar_base_w: f32 = common.scrollbarWidth(r.uiScaleFactor());
        const scrollbar_hover_w: f32 = common.scrollbarHoverWidth(r.uiScaleFactor());
        const scrollbar_w: f32 = common.lerp(scrollbar_base_w, scrollbar_hover_w, self.scrollbar_hover_anim);
        var label_buf: [48]u8 = undefined;
        const label = std.fmt.bufPrint(&label_buf, "SCROLLBACK {d}", .{scroll_offset}) catch "SCROLLBACK";
        const padding_x: f32 = 6;
        const padding_y: f32 = 3;
        const text_w = @as(f32, @floatFromInt(label.len)) * r.char_width;
        const box_w = text_w + padding_x * 2;
        const box_h = r.char_height + padding_y * 2;
        const desired_x = x + width - scrollbar_w - box_w - 6;
        const box_x = @max(x + 4, desired_x);
        const box_y = y + 6;
        const bg = Color{ .r = r.theme.line_number_bg.r, .g = r.theme.line_number_bg.g, .b = r.theme.line_number_bg.b, .a = 220 };
        r.drawRect(@intFromFloat(box_x), @intFromFloat(box_y), @intFromFloat(box_w), @intFromFloat(box_h), bg);
        r.drawText(label, box_x + padding_x, box_y + padding_y, r.theme.foreground);
    }
}

const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const shared_types = @import("../../types/mod.zig");
const terminal_mod = @import("../../terminal/core/terminal.zig");
const common = @import("common.zig");

const Cell = terminal_mod.Cell;

pub const HoverState = struct {
    last_hover_link_id: u32 = 0,
    last_hover_row: isize = -1,
    last_hover_col: isize = -1,
    last_hover_ctrl: bool = false,
    dirty: bool = false,
};

pub fn hoverLinkId(state: *const HoverState) u32 {
    return if (state.last_hover_ctrl) state.last_hover_link_id else 0;
}

pub fn visibleLinkIdAtCell(view_cells: []const Cell, rows: usize, cols: usize, row: usize, col: usize) u32 {
    if (rows == 0 or cols == 0) return 0;
    if (row >= rows or col >= cols) return 0;
    if (view_cells.len < rows * cols) return 0;
    return view_cells[row * cols + col].attrs.link_id;
}

pub fn updateHoverStateVisible(
    state: *HoverState,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    ui_scale: f32,
    cell_width: f32,
    cell_height: f32,
    rows: usize,
    cols: usize,
    view_cells: []const Cell,
    input_batch: *shared_types.input.InputBatch,
) void {
    const mouse = input_batch.mouse_pos;
    const ctrl = input_batch.mods.ctrl;
    const scrollbar_w: f32 = common.scrollbarWidth(ui_scale);
    const scrollbar_x = x + width - scrollbar_w;
    var hover_row: isize = -1;
    var hover_col: isize = -1;
    var hover_link_id: u32 = 0;
    if (rows > 0 and cols > 0) {
        const in_terminal = common.pointInRect(mouse.x, mouse.y, x, y, width, height);
        const in_cells = in_terminal and mouse.x < scrollbar_x;
        if (in_cells and cell_width > 0 and cell_height > 0) {
            const base_x = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(x)))));
            const base_y = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(y)))));
            const col = @as(usize, @intFromFloat((mouse.x - base_x) / cell_width));
            const row = @as(usize, @intFromFloat((mouse.y - base_y) / cell_height));
            if (row < rows and col < cols) {
                hover_row = @intCast(row);
                hover_col = @intCast(col);
                if (ctrl) {
                    hover_link_id = visibleLinkIdAtCell(view_cells, rows, cols, row, col);
                }
            }
        }
    }
    const hover_changed = ctrl != state.last_hover_ctrl or
        hover_link_id != state.last_hover_link_id or
        hover_row != state.last_hover_row or
        hover_col != state.last_hover_col;
    if (hover_changed) {
        const log = app_logger.logger("terminal.ui.hover");
        log.logf(.info, "ctrl={any} row={d} col={d} link={d}", .{ ctrl, hover_row, hover_col, hover_link_id });
        state.dirty = true;
    }
    state.last_hover_ctrl = ctrl;
    state.last_hover_link_id = hover_link_id;
    state.last_hover_row = hover_row;
    state.last_hover_col = hover_col;
}

pub fn drawHoverUnderlineOverlay(
    r: anytype,
    base_x: f32,
    base_y: f32,
    rows: usize,
    cols: usize,
    hover_link_id: u32,
    view_cells: []const Cell,
) void {
    if (rows == 0 or cols == 0) return;
    if (hover_link_id == 0) return;
    if (view_cells.len < rows * cols) return;

    const cell_w_i: i32 = @intFromFloat(std.math.round(r.terminal_cell_width));
    const cell_h_i: i32 = @intFromFloat(std.math.round(r.terminal_cell_height));
    const base_x_i: i32 = @intFromFloat(std.math.round(base_x));
    const base_y_i: i32 = @intFromFloat(std.math.round(base_y));
    const underline_color = r.theme.link;

    var row_idx: usize = 0;
    while (row_idx < rows) : (row_idx += 1) {
        var col_idx: usize = 0;
        while (col_idx < cols) {
            const cell = view_cells[row_idx * cols + col_idx];
            if (cell.attrs.link_id != hover_link_id) {
                col_idx += 1;
                continue;
            }
            const start_col = col_idx;
            col_idx += 1;
            while (col_idx < cols and view_cells[row_idx * cols + col_idx].attrs.link_id == hover_link_id) {
                col_idx += 1;
            }
            const rect_x = base_x_i + @as(i32, @intCast(start_col)) * cell_w_i;
            const rect_y = base_y_i + @as(i32, @intCast(row_idx)) * cell_h_i + (cell_h_i - 2);
            const rect_w = cell_w_i * @as(i32, @intCast(col_idx - start_col));
            r.drawRect(rect_x, rect_y, rect_w, 2, underline_color);
        }
    }
}

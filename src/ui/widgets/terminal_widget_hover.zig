const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const shared_types = @import("../../types/mod.zig");
const terminal_publication = @import("../../terminal/core/publication/terminal_publication.zig");
const common = @import("common.zig");
const renderer_terminal_draw_host = @import("../renderer/renderer_terminal_draw_host.zig");

const Cell = terminal_publication.Cell;

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
    view: shared_types.layout.TerminalViewGeometry,
    ui_scale: f32,
    view_cells: []const Cell,
    input_batch: *shared_types.input.InputBatch,
    window_focused: bool,
) void {
    const mouse = input_batch.mouse_pos;
    const ctrl = window_focused and input_batch.mods.ctrl;
    const scrollbar_w: f32 = common.scrollbarWidth(ui_scale);
    const scrollbar_x = view.viewport.x + view.viewport.width - scrollbar_w;
    var hover_row: isize = -1;
    var hover_col: isize = -1;
    var hover_link_id: u32 = 0;
    if (view.rows > 0 and view.cols > 0) {
        const in_terminal = window_focused and common.pointInRect(
            mouse.x,
            mouse.y,
            view.viewport.x,
            view.viewport.y,
            view.viewport.width,
            view.viewport.height,
        );
        const in_cells = in_terminal and mouse.x < scrollbar_x;
        if (in_cells) {
            if (common.terminalVisibleCellHit(view, mouse.x, mouse.y)) |hit| {
                hover_row = @intCast(hit.row);
                hover_col = @intCast(hit.col);
                if (ctrl) {
                    hover_link_id = visibleLinkIdAtCell(view_cells, view.rows, view.cols, hit.row, hit.col);
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
    view: shared_types.layout.TerminalViewGeometry,
    hover_link_id: u32,
    view_cells: []const Cell,
) void {
    if (view.rows == 0 or view.cols == 0) return;
    if (hover_link_id == 0) return;
    if (view_cells.len < view.rows * view.cols) return;

    const cell_w = view.cell_width;
    const cell_h = view.cell_height;
    const underline_color = r.theme.link;
    const pixel_step = r.devicePixelStep();

    var row_idx: usize = 0;
    while (row_idx < view.rows) : (row_idx += 1) {
        var col_idx: usize = 0;
        while (col_idx < view.cols) {
            const cell = view_cells[row_idx * view.cols + col_idx];
            if (cell.attrs.link_id != hover_link_id) {
                col_idx += 1;
                continue;
            }
            const start_col = col_idx;
            col_idx += 1;
            while (col_idx < view.cols and view_cells[row_idx * view.cols + col_idx].attrs.link_id == hover_link_id) {
                col_idx += 1;
            }
            const rect_x = view.origin_x + @as(f32, @floatFromInt(@as(i32, @intCast(start_col)))) * cell_w;
            const rect_y = view.origin_y + @as(f32, @floatFromInt(@as(i32, @intCast(row_idx)))) * cell_h + (cell_h - (2.0 * pixel_step));
            const rect_w = cell_w * @as(f32, @floatFromInt(@as(i32, @intCast(col_idx - start_col))));
            renderer_terminal_draw_host.addTerminalRectLogical(r, rect_x, rect_y, rect_w, 2.0 * pixel_step, underline_color);
        }
    }
}

const std = @import("std");

const terminal_mod = @import("../../terminal/core/terminal.zig");
const app_logger = @import("../../app_logger.zig");
const shared_types = @import("../../types/mod.zig");
const paste_mod = @import("terminal_widget_paste.zig");

pub const PointerParams = struct {
    in_terminal: bool,
    mouse: shared_types.input.MousePos,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    hit_base_x: f32,
    hit_base_y: f32,
    hit_cell_w: f32,
    hit_cell_h: f32,
    rows: usize,
    cols: usize,
    total_lines: usize,
    history_len: usize,
    start_line: usize,
    scroll_offset: usize,
    has_visible_grid: bool,
    cache_selection_active: bool,
    mod: terminal_mod.Modifier,
};

pub const PointerResult = struct {
    handled: bool = false,
};

pub fn handlePointerInput(
    self: anytype,
    params: PointerParams,
    view_cells: anytype,
    input_batch: *shared_types.input.InputBatch,
    clip_opt: ?[]const u8,
    html: ?[]u8,
    uri_list: ?[]u8,
    png: ?[]u8,
    saw_non_modifier_key_press: bool,
    saw_text_input: bool,
    wheel_steps: *i32,
) !PointerResult {
    const scroll_log = app_logger.logger("terminal.scroll");
    var result = PointerResult{};
    if (!params.in_terminal and !saw_non_modifier_key_press and !saw_text_input) {
        return result;
    }

    var live_scroll_offset = params.scroll_offset;
    var selection_active = params.cache_selection_active;
    self.session.lock();
    defer self.session.unlock();

    if (live_scroll_offset > 0 and self.session.resetToLiveBottomForInputLocked(saw_non_modifier_key_press, saw_text_input)) {
        live_scroll_offset = 0;
    }

    if (params.in_terminal and input_batch.mousePressed(.left) and selection_active) {
        if (self.session.clearSelectionIfActiveLocked()) {
            selection_active = false;
            result.handled = true;
        }
    }

    if (params.has_visible_grid and params.in_terminal) {
        if (input_batch.mousePressed(.left)) {
            const press_mouse = input_batch.mousePressPos(.left) orelse params.mouse;
            const col = @as(usize, @intFromFloat((press_mouse.x - params.hit_base_x) / params.hit_cell_w));
            const row = @as(usize, @intFromFloat((press_mouse.y - params.hit_base_y) / params.hit_cell_h));
            const clamped_col = @min(col, params.cols - 1);
            const clamped_row = @min(row, params.rows - 1);
            const global_row = params.start_line + clamped_row;
            if (global_row < params.history_len + params.rows) {
                self.selection_press_origin = press_mouse;
                self.selection_drag_active = false;
                if (input_batch.mouseClicks(.left) >= 2) {
                    const row_cells = view_cells[clamped_row * params.cols .. (clamped_row + 1) * params.cols];
                    const click_result = self.session.beginClickSelectionLocked(
                        row_cells,
                        global_row,
                        clamped_col,
                        input_batch.mouseClicks(.left),
                    );
                    self.selection_gesture = click_result.gesture;
                    if (click_result.started) {
                        selection_active = true;
                        result.handled = true;
                    }
                } else {
                    self.selection_gesture = .{
                        .mode = .none,
                        .row = global_row,
                        .col_start = clamped_col,
                        .col_end = clamped_col,
                    };
                }
            }
        }

        const drag_select_active = selectionDragIsActive(self, input_batch, params.mouse, params.hit_cell_w);
        const drag_select_multi = drag_select_active and self.selection_gesture.mode != .none;
        const drag_select_normal = drag_select_active and self.selection_gesture.mode == .none;
        if (drag_select_multi) {
            const col = @as(usize, @intFromFloat((params.mouse.x - params.hit_base_x) / params.hit_cell_w));
            const row = @as(usize, @intFromFloat((params.mouse.y - params.hit_base_y) / params.hit_cell_h));
            const clamped_col = @min(col, params.cols - 1);
            const clamped_row = @min(row, params.rows - 1);
            const global_row = params.start_line + clamped_row;
            if (global_row < params.history_len + params.rows) {
                const row_cells = view_cells[clamped_row * params.cols .. (clamped_row + 1) * params.cols];
                if (self.session.extendGestureSelectionLocked(self.selection_gesture, row_cells, global_row, clamped_col)) {
                    selection_active = true;
                    result.handled = true;
                }
            }

            if (selection_active) {
                if (params.mouse.y < params.y) {
                    _ = self.session.scrollSelectionDragLocked(true);
                    result.handled = true;
                } else if (params.mouse.y > params.y + params.height) {
                    _ = self.session.scrollSelectionDragLocked(false);
                    result.handled = true;
                }
            }
        }
        if (drag_select_normal) {
            const col = @as(usize, @intFromFloat((params.mouse.x - params.hit_base_x) / params.hit_cell_w));
            const row = @as(usize, @intFromFloat((params.mouse.y - params.hit_base_y) / params.hit_cell_h));
            const clamped_col = @min(col, params.cols - 1);
            const clamped_row = @min(row, params.rows - 1);
            const global_row = params.start_line + clamped_row;
            if (global_row < params.history_len + params.rows) {
                if (!selection_active) {
                    const anchor = terminal_mod.SelectionPos{
                        .row = self.selection_gesture.row,
                        .col = self.selection_gesture.col_start,
                    };
                    const target = terminal_mod.SelectionPos{
                        .row = global_row,
                        .col = clamped_col,
                    };
                    if (anchor.row != target.row or anchor.col != target.col) {
                        self.session.selectRangeLocked(anchor, target, false);
                        selection_active = true;
                        result.handled = true;
                    }
                } else {
                    const row_cells = view_cells[clamped_row * params.cols .. (clamped_row + 1) * params.cols];
                    if (self.session.selectOrUpdateCellInRowLocked(row_cells, global_row, clamped_col)) {
                        selection_active = true;
                        result.handled = true;
                    }
                }
            }

            if (selection_active) {
                if (params.mouse.y < params.y) {
                    _ = self.session.scrollSelectionDragLocked(true);
                    result.handled = true;
                } else if (params.mouse.y > params.y + params.height) {
                    _ = self.session.scrollSelectionDragLocked(false);
                    result.handled = true;
                }
            }
        }

        if (input_batch.mouseReleased(.left)) {
            if (selection_active and self.session.finishSelectionIfActiveLocked()) {
                selection_active = true;
                result.handled = true;
            }
        }
    }

    if (params.in_terminal and input_batch.mousePressed(.middle)) {
        if (paste_mod.pasteSelectionClipboard(self, clip_opt, html, uri_list, png)) {
            result.handled = true;
        }
    }
    if (params.in_terminal and wheel_steps.* != 0) {
        if (try self.session.reportAlternateScrollWheel(wheel_steps.*, params.mod)) {
            scroll_log.logf(.info, "alt-scroll wheel steps={d}", .{wheel_steps.*});
            result.handled = true;
            wheel_steps.* = 0;
        }
    }
    if (params.in_terminal and wheel_steps.* != 0) {
        if (self.session.scrollWheelLocked(wheel_steps.*)) {
            scroll_log.logf(.info, "scroll wheel steps={d}", .{wheel_steps.*});
            result.handled = true;
        }
    }

    return result;
}

pub fn resetLeftDragState(self: anytype) void {
    self.selection_gesture = .{};
    self.selection_press_origin = null;
    self.selection_drag_active = false;
}

fn selectionDragIsActive(
    self: anytype,
    input_batch: *const shared_types.input.InputBatch,
    mouse: shared_types.input.MousePos,
    hit_cell_w: f32,
) bool {
    const drag_select_active = input_batch.mouseDown(.left) and !input_batch.mousePressed(.left);
    if (!drag_select_active) return false;
    if (self.selection_drag_active) return true;
    const origin = self.selection_press_origin orelse return false;
    const dx = mouse.x - origin.x;
    const dy = mouse.y - origin.y;
    const dist2 = dx * dx + dy * dy;
    const threshold2 = hit_cell_w * hit_cell_w;
    if (dist2 < threshold2) return false;
    self.selection_drag_active = true;
    return true;
}

const std = @import("std");

const terminal_types = @import("../../terminal/model/types.zig");
const app_logger = @import("../../app_logger.zig");
const shared_types = @import("../../types/mod.zig");
const input_adapter_mod = @import("terminal_widget_input_bridge.zig");
const paste_mod = @import("terminal_widget_paste.zig");
const common = @import("common.zig");

pub const PointerParams = struct {
    in_terminal: bool,
    mouse: shared_types.input.MousePos,
    view: shared_types.layout.TerminalViewGeometry,
    total_lines: usize,
    history_len: usize,
    start_line: usize,
    scroll_offset: usize,
    has_visible_grid: bool,
    cache_selection_active: bool,
    mod: terminal_types.Modifier,
};

pub const PointerResult = struct {
    handled: bool = false,
};

pub fn handlePointerInput(
    self: anytype,
    input_adapter: *const input_adapter_mod.TerminalInputAdapter,
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

    if (live_scroll_offset > 0 and input_adapter.resetToLiveBottomForInput(saw_non_modifier_key_press, saw_text_input)) {
        live_scroll_offset = 0;
    }

    if (params.in_terminal and input_batch.mousePressed(.left) and selection_active) {
        if (input_adapter.clearSelectionIfActive()) {
            selection_active = false;
            result.handled = true;
        }
    }

    if (params.has_visible_grid and params.in_terminal) {
        if (input_batch.mousePressed(.left)) {
            const press_mouse = input_batch.mousePressPos(.left) orelse params.mouse;
            if (common.terminalVisibleCellHit(params.view, press_mouse.x, press_mouse.y)) |hit| {
                const global_row = params.start_line + hit.row;
                if (global_row < params.history_len + params.view.rows) {
                    self.controller.selection.beginPress(press_mouse);
                    if (input_batch.mouseClicks(.left) >= 2) {
                        const row_cells = view_cells[hit.row * params.view.cols .. (hit.row + 1) * params.view.cols];
                        const click_result = input_adapter.beginClickSelection(row_cells, global_row, hit.col, input_batch.mouseClicks(.left));
                        self.controller.selection.setGesture(click_result.gesture);
                        if (click_result.started) {
                            selection_active = true;
                            result.handled = true;
                        }
                    } else {
                        self.controller.selection.setGesture(.{
                            .mode = .none,
                            .row = global_row,
                            .col_start = hit.col,
                            .col_end = hit.col,
                        });
                    }
                }
            }
        }

        const drag_select_active = selectionDragIsActive(self, input_batch, params.mouse, params.view.cell_width);
        const drag_select_multi = drag_select_active and self.controller.selection.gesture.mode != .none;
        const drag_select_normal = drag_select_active and self.controller.selection.gesture.mode == .none;
        if (drag_select_multi) {
            if (common.terminalVisibleCellHit(params.view, params.mouse.x, params.mouse.y)) |hit| {
                const global_row = params.start_line + hit.row;
                if (global_row < params.history_len + params.view.rows) {
                    const row_cells = view_cells[hit.row * params.view.cols .. (hit.row + 1) * params.view.cols];
                    if (input_adapter.extendGestureSelection(self.controller.selection.gesture, row_cells, global_row, hit.col)) {
                        selection_active = true;
                        result.handled = true;
                    }
                }
            }

            if (selection_active) {
                if (params.mouse.y < params.view.origin_y) {
                    _ = input_adapter.scrollSelectionDrag(true);
                    result.handled = true;
                } else if (params.mouse.y > params.view.origin_y + params.view.viewport_height) {
                    _ = input_adapter.scrollSelectionDrag(false);
                    result.handled = true;
                }
            }
        }
        if (drag_select_normal) {
            if (common.terminalVisibleCellHit(params.view, params.mouse.x, params.mouse.y)) |hit| {
                const global_row = params.start_line + hit.row;
                if (global_row < params.history_len + params.view.rows) {
                    if (!selection_active) {
                        const anchor = terminal_types.SelectionPos{
                            .row = self.controller.selection.gesture.row,
                            .col = self.controller.selection.gesture.col_start,
                        };
                        const target = terminal_types.SelectionPos{
                            .row = global_row,
                            .col = hit.col,
                        };
                        if (anchor.row != target.row or anchor.col != target.col) {
                            input_adapter.selectRange(anchor, target, false);
                            selection_active = true;
                            result.handled = true;
                        }
                    } else {
                        if (input_adapter.selectOrUpdateCell(.{
                            .row = global_row,
                            .col = hit.col,
                        })) {
                            selection_active = true;
                            result.handled = true;
                        }
                    }
                }
            }

            if (selection_active) {
                if (params.mouse.y < params.view.origin_y) {
                    _ = input_adapter.scrollSelectionDrag(true);
                    result.handled = true;
                } else if (params.mouse.y > params.view.origin_y + params.view.viewport_height) {
                    _ = input_adapter.scrollSelectionDrag(false);
                    result.handled = true;
                }
            }
        }

        if (input_batch.mouseReleased(.left)) {
            if (selection_active and input_adapter.finishSelectionIfActive()) {
                selection_active = true;
                result.handled = true;
            }
        }
    }

    if (params.in_terminal and input_batch.mousePressed(.middle)) {
        if (paste_mod.pasteSelectionClipboard(input_adapter, clip_opt, html, uri_list, png)) {
            result.handled = true;
        }
    }
    if (params.in_terminal and wheel_steps.* != 0) {
        if (try input_adapter.reportAlternateScrollWheel(wheel_steps.*, params.mod)) {
            scroll_log.logf(.info, "alt-scroll wheel steps={d}", .{wheel_steps.*});
            result.handled = true;
            wheel_steps.* = 0;
        }
    }
    if (params.in_terminal and wheel_steps.* != 0) {
        if (input_adapter.scrollWheel(wheel_steps.*)) {
            scroll_log.logf(.info, "scroll wheel steps={d}", .{wheel_steps.*});
            result.handled = true;
        }
    }

    return result;
}

pub fn resetLeftDragState(self: anytype) void {
    self.controller.selection.reset();
}

fn selectionDragIsActive(
    self: anytype,
    input_batch: *const shared_types.input.InputBatch,
    mouse: shared_types.input.MousePos,
    hit_cell_w: f32,
) bool {
    const drag_select_active = input_batch.mouseDown(.left) and !input_batch.mousePressed(.left);
    if (!drag_select_active) return false;
    if (self.controller.selection.dragIsActive()) return true;
    const origin = self.controller.selection.pressOrigin() orelse return false;
    const dx = mouse.x - origin.x;
    const dy = mouse.y - origin.y;
    const dist2 = dx * dx + dy * dy;
    const threshold2 = hit_cell_w * hit_cell_w;
    if (dist2 < threshold2) return false;
    self.controller.selection.activateDrag();
    return true;
}

const std = @import("std");

const app_shell = @import("../../app_shell.zig");
const terminal_types = @import("../../terminal/model/types.zig");
const shared_types = @import("../../types/mod.zig");

const input_adapter_mod = @import("terminal_widget_input_bridge.zig");
const open_mod = @import("terminal_widget_command/open.zig");
const hover_mod = @import("terminal_widget_hover.zig");
const keyboard_mod = @import("terminal_widget_keyboard.zig");
const mouse_reporting_mod = @import("terminal_widget_output_protocol_mouse.zig");
const pointer_mod = @import("terminal_widget_pointer.zig");
const view_state = @import("terminal_widget_view_state.zig");
const common = @import("common.zig");

const Shell = app_shell.Shell;

/// Handle input, returns true if any input was processed
pub fn handleInput(
    self: anytype,
    shell: *Shell,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    allow_input: bool,
    suppress_shortcuts: bool,
    input_batch: *shared_types.input.InputBatch,
) !bool {
    const mouse = input_batch.mouse_pos;
    const in_terminal = common.pointInRect(mouse.x, mouse.y, x, y, width, height);
    var handled = false;
    const cache = self.publication.cacheConst();
    const terminal_view = self.publication.model();
    const input_adapter = input_adapter_mod.TerminalInputAdapter.init(self.session);
    const view_cells = terminal_view.cells;
    const rows = terminal_view.rows;
    const cols = terminal_view.cols;
    const view_geometry = shell.terminalViewGeometry(.{
        .x = x,
        .y = y,
        .width = width,
        .height = height,
    }, rows, cols);
    const viewport = terminal_view.viewport;
    const history_len = viewport.history_len;
    const total_lines = viewport.total_lines;
    const scroll_offset = viewport.scroll_offset;
    const start_line = viewport.start_line;
    const has_visible_grid = rows > 0 and cols > 0 and view_cells.len >= rows * cols;
    const r = shell.rendererPtr();
    hover_mod.updateHoverStateVisible(
        &self.controller.hover,
        view_geometry,
        shell.uiGeometryContext().ui_scale,
        view_cells,
        input_batch,
        shell.windowFocused(),
    );

    const ctrl = input_batch.mods.ctrl;
    const shift = input_batch.mods.shift;
    const alt = input_batch.mods.alt;
    var mod: terminal_types.Modifier = terminal_types.VTERM_MOD_NONE;
    if (shift) mod |= terminal_types.VTERM_MOD_SHIFT;
    if (alt) mod |= terminal_types.VTERM_MOD_ALT;
    if (ctrl) mod |= terminal_types.VTERM_MOD_CTRL;

    const wheel_delta = if (in_terminal) input_batch.scroll.y else 0;
    var wheel_steps: i32 = 0;
    if (wheel_delta != 0) {
        const abs_delta = @abs(wheel_delta);
        const rounded: i32 = @intFromFloat(@round(abs_delta));
        wheel_steps = if (rounded > 0) rounded else 1;
        if (wheel_delta < 0) wheel_steps = -wheel_steps;
    }
    const mouse_reporting = allow_input and in_terminal and input_adapter.mouseReportingEnabled();
    var skip_mouse_click = false;
    if (allow_input and in_terminal and ctrl and input_batch.mousePressed(.left)) {
        if (has_visible_grid) {
            const did_open = open_mod.ctrlClickOpenVisibleMaybe(
                &input_adapter,
                self.controller.pending.pendingOpenPtr(),
                view_cells,
                view_geometry,
                mouse.x,
                mouse.y,
            );
            if (did_open) {
                handled = true;
                skip_mouse_click = true;
            }
        }
    }

    var osc_clipboard = std.ArrayList(u8).empty;
    defer osc_clipboard.deinit(self.session.allocator);
    osc_clipboard.clearRetainingCapacity();
    if ((input_adapter.takeOscClipboardCopy(self.session.allocator, &osc_clipboard) catch false)) {
        const cstr: [*:0]const u8 = @ptrCast(osc_clipboard.items.ptr);
        shell.setClipboardText(cstr);
        handled = true;
    }

    if (allow_input) {
        var skip_chars = false;
        const keyboard_result = try keyboard_mod.handleKeyboardInput(
            self,
            &input_adapter,
            shell,
            r,
            scroll_offset,
            allow_input,
            suppress_shortcuts,
            input_batch,
            mod,
        );
        handled = handled or keyboard_result.handled;
        skip_chars = keyboard_result.skip_chars;
        const saw_non_modifier_key_press = keyboard_result.saw_non_modifier_key_press;
        const saw_text_input = keyboard_result.saw_text_input;

        var clip_opt: ?[]const u8 = null;
        var html: ?[]u8 = null;
        var uri_list: ?[]u8 = null;
        var png: ?[]u8 = null;
        defer if (html) |buf| self.session.allocator.free(buf);
        defer if (uri_list) |buf| self.session.allocator.free(buf);
        defer if (png) |buf| self.session.allocator.free(buf);
        if (!mouse_reporting and in_terminal and input_batch.mousePressed(.middle)) {
            clip_opt = shell.getClipboardText();
            html = shell.getClipboardMimeData(self.session.allocator, "text/html");
            uri_list = shell.getClipboardMimeData(self.session.allocator, "text/uri-list");
            png = shell.getClipboardMimeData(self.session.allocator, "image/png");
        }

        if (!mouse_reporting) {
            const pointer_result = try pointer_mod.handlePointerInput(
                self,
                &input_adapter,
                .{
                    .in_terminal = in_terminal,
                    .mouse = mouse,
                    .view = view_geometry,
                    .total_lines = total_lines,
                    .history_len = history_len,
                    .start_line = start_line,
                    .scroll_offset = scroll_offset,
                    .has_visible_grid = has_visible_grid,
                    .cache_selection_active = cache.hasSelection(),
                    .mod = mod,
                },
                view_cells,
                input_batch,
                clip_opt,
                html,
                uri_list,
                png,
                saw_non_modifier_key_press,
                saw_text_input,
                &wheel_steps,
            );
            handled = handled or pointer_result.handled;
        }
        if (mouse_reporting and rows > 0 and cols > 0) {
            handled = handled or try mouse_reporting_mod.handleMouseReporting(
                self,
                &input_adapter,
                .{
                    .mouse = mouse,
                    .view = view_geometry,
                    .mod = mod,
                },
                input_batch,
                skip_mouse_click,
                wheel_steps,
            );
        }
    }

    if (input_batch.mouseReleased(.left)) pointer_mod.resetLeftDragState(self);
    if (handled) self.noteInput(app_shell.getTime());
    return handled;
}

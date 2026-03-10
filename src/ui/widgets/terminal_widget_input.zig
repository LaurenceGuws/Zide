const std = @import("std");

const app_shell = @import("../../app_shell.zig");
const terminal_mod = @import("../../terminal/core/terminal.zig");
const app_logger = @import("../../app_logger.zig");
const shared_types = @import("../../types/mod.zig");

const open_mod = @import("terminal_widget_open.zig");
const hover_mod = @import("terminal_widget_hover.zig");
const keyboard_mod = @import("terminal_widget_keyboard.zig");
const pointer_mod = @import("terminal_widget_pointer.zig");
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
    const scale = shell.uiScaleFactor();
    const scrollbar_base_w: f32 = common.scrollbarWidth(scale);
    const scrollbar_hover_w: f32 = common.scrollbarHoverWidth(scale);
    const scrollbar_hit_margin: f32 = common.scrollbarHitMargin(scale);
    const scrollbar_proximity: f32 = common.scrollbarProximityRange(scale);
    const in_scroll_y = mouse.y >= y and mouse.y <= y + height;
    const dist_from_right = (x + width) - mouse.x;
    const proximity_raw: f32 = if (in_scroll_y and dist_from_right <= scrollbar_proximity and dist_from_right >= -scrollbar_hit_margin)
        (1.0 - std.math.clamp(dist_from_right / scrollbar_proximity, 0.0, 1.0))
    else
        0.0;
    const proximity_t = common.smoothstep01(proximity_raw);
    const scrollbar_w: f32 = common.lerp(scrollbar_base_w, scrollbar_hover_w, if (self.scrollbar_drag_active) 1.0 else proximity_t);
    const scrollbar_x = x + width - scrollbar_w;
    const scrollbar_y = y;
    const scrollbar_h = height;

    const cache = &self.draw_cache;
    const view_cells = cache.cells.items;
    const history_len = cache.history_len;
    const rows = cache.rows;
    const cols = cache.cols;
    const total_lines = cache.total_lines;
    const scroll_offset = cache.scroll_offset;
    const end_line = total_lines - scroll_offset;
    const start_line = if (end_line > rows) end_line - rows else 0;
    const max_scroll_offset = if (total_lines > rows) total_lines - rows else 0;
    const has_visible_grid = rows > 0 and cols > 0 and view_cells.len >= rows * cols;
    const show_scrollbar = !cache.alt_active and !self.session.mouseReportingEnabled() and total_lines > rows;
    const mouse_on_scrollbar = show_scrollbar and common.pointInRect(
        mouse.x,
        mouse.y,
        scrollbar_x - scrollbar_hit_margin,
        scrollbar_y,
        scrollbar_w + scrollbar_hit_margin,
        scrollbar_h,
    );
    const r = shell.rendererPtr();
    const hit_cell_w = @as(f32, @floatFromInt(@max(1, @as(i32, @intFromFloat(std.math.round(r.terminal_cell_width))))));
    const hit_cell_h = @as(f32, @floatFromInt(@max(1, @as(i32, @intFromFloat(std.math.round(r.terminal_cell_height))))));
    const hit_base_x = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(x)))));
    const hit_base_y = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(y)))));
    hover_mod.updateHoverStateVisible(
        &self.hover,
        x,
        y,
        width,
        height,
        scale,
        hit_cell_w,
        hit_cell_h,
        rows,
        cols,
        view_cells,
        input_batch,
    );

    const ctrl = input_batch.mods.ctrl;
    const shift = input_batch.mods.shift;
    const alt = input_batch.mods.alt;
    var mod: terminal_mod.Modifier = terminal_mod.VTERM_MOD_NONE;
    if (shift) mod |= terminal_mod.VTERM_MOD_SHIFT;
    if (alt) mod |= terminal_mod.VTERM_MOD_ALT;
    if (ctrl) mod |= terminal_mod.VTERM_MOD_CTRL;

    const wheel_delta = if (in_terminal) input_batch.scroll.y else 0;
    var wheel_steps: i32 = 0;
    if (wheel_delta != 0) {
        const abs_delta = @abs(wheel_delta);
        const rounded: i32 = @intFromFloat(@round(abs_delta));
        wheel_steps = if (rounded > 0) rounded else 1;
        if (wheel_delta < 0) wheel_steps = -wheel_steps;
    }
    const mouse_reporting = allow_input and in_terminal and self.session.mouseReportingEnabled();
    var skip_mouse_click = false;
    if (allow_input and in_terminal and ctrl and input_batch.mousePressed(.left)) {
        if (has_visible_grid) {
            const did_open = open_mod.ctrlClickOpenVisibleMaybe(
                self.session.allocator,
                self.session,
                &self.pending_open,
                view_cells,
                rows,
                cols,
                hit_base_x,
                hit_base_y,
                mouse.x,
                mouse.y,
                hit_cell_w,
                hit_cell_h,
            );
            if (did_open) {
                handled = true;
                skip_mouse_click = true;
            }
        }
    }

    var osc_clipboard = std.ArrayList(u8).empty;
    defer osc_clipboard.deinit(self.session.allocator);
    if (self.session.tryTakeOscClipboardCopy(self.session.allocator, &osc_clipboard) catch false) {
        const cstr: [*:0]const u8 = @ptrCast(osc_clipboard.items.ptr);
        shell.setClipboardText(cstr);
        handled = true;
    }

    if (allow_input) {
        var skip_chars = false;
        const keyboard_result = try keyboard_mod.handleKeyboardInput(
            self,
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
                .{
                    .in_terminal = in_terminal,
                    .mouse_on_scrollbar = mouse_on_scrollbar,
                    .mouse = mouse,
                    .x = x,
                    .y = y,
                    .width = width,
                    .height = height,
                    .scrollbar_y = scrollbar_y,
                    .scrollbar_h = scrollbar_h,
                    .hit_base_x = hit_base_x,
                    .hit_base_y = hit_base_y,
                    .hit_cell_w = hit_cell_w,
                    .hit_cell_h = hit_cell_h,
                    .rows = rows,
                    .cols = cols,
                    .total_lines = total_lines,
                    .history_len = history_len,
                    .start_line = start_line,
                    .scroll_offset = scroll_offset,
                    .max_scroll_offset = max_scroll_offset,
                    .has_visible_grid = has_visible_grid,
                    .cache_selection_active = cache.selection_active,
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
            self.session.lock();
            defer self.session.unlock();
            // Mouse reporting uses terminal input-state bookkeeping and grid dimensions.
            var buttons_down: u8 = 0;
            if (input_batch.mouseDown(.left)) buttons_down |= 1;
            if (input_batch.mouseDown(.middle)) buttons_down |= 2;
            if (input_batch.mouseDown(.right)) buttons_down |= 4;

            var col: usize = 0;
            if (mouse.x > hit_base_x) col = @as(usize, @intFromFloat((mouse.x - hit_base_x) / hit_cell_w));
            var row: usize = 0;
            if (mouse.y > hit_base_y) row = @as(usize, @intFromFloat((mouse.y - hit_base_y) / hit_cell_h));
            row = @min(row, rows - 1);
            col = @min(col, cols - 1);
            const grid_px_w = @as(u32, @intCast(cols)) * @as(u32, @intFromFloat(hit_cell_w));
            const grid_px_h = @as(u32, @intCast(rows)) * @as(u32, @intFromFloat(hit_cell_h));
            const raw_px_x_f = @max(0.0, mouse.x - hit_base_x);
            const raw_px_y_f = @max(0.0, mouse.y - hit_base_y);
            var pixel_x: u32 = @intFromFloat(raw_px_x_f);
            var pixel_y: u32 = @intFromFloat(raw_px_y_f);
            if (grid_px_w > 0) pixel_x = @min(pixel_x, grid_px_w - 1);
            if (grid_px_h > 0) pixel_y = @min(pixel_y, grid_px_h - 1);

            if (wheel_steps != 0) {
                var remaining = wheel_steps;
                while (remaining != 0) {
                    const button: terminal_mod.MouseButton = if (remaining > 0) .wheel_up else .wheel_down;
                    if (try self.session.reportMouseEvent(.{ .kind = .wheel, .button = button, .row = row, .col = col, .pixel_x = pixel_x, .pixel_y = pixel_y, .mod = mod, .buttons_down = buttons_down })) {
                        handled = true;
                    }
                    remaining += if (remaining > 0) -1 else 1;
                }
            }
            if (input_batch.mousePressed(.left) and !skip_mouse_click) {
                if (try self.session.reportMouseEvent(.{ .kind = .press, .button = .left, .row = row, .col = col, .pixel_x = pixel_x, .pixel_y = pixel_y, .mod = mod, .buttons_down = buttons_down })) handled = true;
            }
            if (input_batch.mousePressed(.middle)) {
                if (try self.session.reportMouseEvent(.{ .kind = .press, .button = .middle, .row = row, .col = col, .pixel_x = pixel_x, .pixel_y = pixel_y, .mod = mod, .buttons_down = buttons_down })) handled = true;
            }
            if (input_batch.mousePressed(.right)) {
                if (try self.session.reportMouseEvent(.{ .kind = .press, .button = .right, .row = row, .col = col, .pixel_x = pixel_x, .pixel_y = pixel_y, .mod = mod, .buttons_down = buttons_down })) handled = true;
            }
            if (input_batch.mouseReleased(.left)) {
                if (try self.session.reportMouseEvent(.{ .kind = .release, .button = .left, .row = row, .col = col, .pixel_x = pixel_x, .pixel_y = pixel_y, .mod = mod, .buttons_down = buttons_down })) handled = true;
            }
            if (input_batch.mouseReleased(.middle)) {
                if (try self.session.reportMouseEvent(.{ .kind = .release, .button = .middle, .row = row, .col = col, .pixel_x = pixel_x, .pixel_y = pixel_y, .mod = mod, .buttons_down = buttons_down })) handled = true;
            }
            if (input_batch.mouseReleased(.right)) {
                if (try self.session.reportMouseEvent(.{ .kind = .release, .button = .right, .row = row, .col = col, .pixel_x = pixel_x, .pixel_y = pixel_y, .mod = mod, .buttons_down = buttons_down })) handled = true;
            }
            if (try self.session.reportMouseEvent(.{ .kind = .move, .button = .none, .row = row, .col = col, .pixel_x = pixel_x, .pixel_y = pixel_y, .mod = mod, .buttons_down = buttons_down })) handled = true;
        }
    }

    if (input_batch.mouseReleased(.left)) pointer_mod.resetLeftDragState(self);
    return handled;
}

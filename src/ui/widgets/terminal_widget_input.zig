const std = @import("std");
const builtin = @import("builtin");

const app_shell = @import("../../app_shell.zig");
const terminal_mod = @import("../../terminal/core/terminal.zig");
const terminal_types = @import("../../terminal/model/types.zig");
const key_encoder = @import("../../terminal/input/key_encoder.zig");
const app_logger = @import("../../app_logger.zig");
const shared_types = @import("../../types/mod.zig");

const open_mod = @import("terminal_widget_open.zig");
const hover_mod = @import("terminal_widget_hover.zig");
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
    scroll_dragging: *bool,
    scroll_grab_offset: *f32,
    suppress_shortcuts: bool,
    input_batch: *shared_types.input.InputBatch,
) !bool {
    var locked = self.session.tryLock();
    if (!locked) {
        const needs_input = allow_input and input_batch.events.items.len > 0;
        if (!needs_input) return false;
        self.session.lock();
        locked = true;
    }
    defer if (locked) self.session.unlock();
    var handled = false;
    const mouse = input_batch.mouse_pos;
    const in_terminal = common.pointInRect(mouse.x, mouse.y, x, y, width, height);
    const scrollbar_w: f32 = 10;
    const scrollbar_x = x + width - scrollbar_w;
    const scrollbar_y = y;
    const scrollbar_h = height;

    const history_len = self.session.scrollbackCount();
    const snapshot = self.session.snapshot();
    const rows = snapshot.rows;
    const cols = snapshot.cols;
    const total_lines = history_len + rows;
    const scroll_offset = self.session.scrollOffset();
    const end_line = total_lines - scroll_offset;
    const start_line = if (end_line > rows) end_line - rows else 0;
    const max_scroll_offset = if (total_lines > rows) total_lines - rows else 0;
    const cache = self.session.renderCache();
    const show_scrollbar = !cache.alt_active and !self.session.mouseReportingEnabled() and total_lines > rows;
    const mouse_on_scrollbar = show_scrollbar and common.pointInRect(mouse.x, mouse.y, scrollbar_x, scrollbar_y, scrollbar_w, scrollbar_h);
    const scroll_log = app_logger.logger("terminal.scroll");

    const r = shell.rendererPtr();
    hover_mod.updateHoverState(
        &self.hover,
        self.session,
        x,
        y,
        width,
        height,
        r.terminal_cell_width,
        r.terminal_cell_height,
        snapshot,
        history_len,
        start_line,
        input_batch,
    );

    const ctrl = input_batch.mods.ctrl;
    const shift = input_batch.mods.shift;
    const alt = input_batch.mods.alt;
    const super = input_batch.mods.super;
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
        if (rows > 0 and cols > 0 and snapshot.cells.len >= rows * cols) {
            const did_open = open_mod.ctrlClickOpenMaybe(
                self.session.allocator,
                self.session,
                &self.pending_open,
                snapshot,
                history_len,
                start_line,
                rows,
                cols,
                x,
                y,
                mouse.x,
                mouse.y,
                shell.terminalCellWidth(),
                shell.terminalCellHeight(),
            );
            if (did_open) {
                handled = true;
                skip_mouse_click = true;
            }
        }
    }

    if (self.session.takeOscClipboard()) |clip| {
        const cstr: [*:0]const u8 = @ptrCast(clip.ptr);
        shell.setClipboardText(cstr);
        handled = true;
    }

    if (mouse_reporting and rows > 0 and cols > 0) {
        const mouse_left_down = input_batch.mouseDown(.left);
        const mouse_middle_down = input_batch.mouseDown(.middle);
        const mouse_right_down = input_batch.mouseDown(.right);
        var buttons_down: u8 = 0;
        if (mouse_left_down) buttons_down |= 1;
        if (mouse_middle_down) buttons_down |= 2;
        if (mouse_right_down) buttons_down |= 4;

        var col: usize = 0;
        if (mouse.x > x) {
            col = @as(usize, @intFromFloat((mouse.x - x) / shell.terminalCellWidth()));
        }
        var row: usize = 0;
        if (mouse.y > y) {
            row = @as(usize, @intFromFloat((mouse.y - y) / shell.terminalCellHeight()));
        }
        row = @min(row, rows - 1);
        col = @min(col, cols - 1);

        if (wheel_steps != 0) {
            var remaining = wheel_steps;
            while (remaining != 0) {
                const button: terminal_mod.MouseButton = if (remaining > 0) .wheel_up else .wheel_down;
                if (try self.session.reportMouseEvent(.{ .kind = .wheel, .button = button, .row = row, .col = col, .mod = mod, .buttons_down = buttons_down })) {
                    handled = true;
                }
                remaining += if (remaining > 0) -1 else 1;
            }
        }

        if (input_batch.mousePressed(.left) and !skip_mouse_click) {
            if (try self.session.reportMouseEvent(.{ .kind = .press, .button = .left, .row = row, .col = col, .mod = mod, .buttons_down = buttons_down })) {
                handled = true;
            }
        }
        if (input_batch.mousePressed(.middle)) {
            if (try self.session.reportMouseEvent(.{ .kind = .press, .button = .middle, .row = row, .col = col, .mod = mod, .buttons_down = buttons_down })) {
                handled = true;
            }
        }
        if (input_batch.mousePressed(.right)) {
            if (try self.session.reportMouseEvent(.{ .kind = .press, .button = .right, .row = row, .col = col, .mod = mod, .buttons_down = buttons_down })) {
                handled = true;
            }
        }

        if (input_batch.mouseReleased(.left)) {
            if (try self.session.reportMouseEvent(.{ .kind = .release, .button = .left, .row = row, .col = col, .mod = mod, .buttons_down = buttons_down })) {
                handled = true;
            }
        }
        if (input_batch.mouseReleased(.middle)) {
            if (try self.session.reportMouseEvent(.{ .kind = .release, .button = .middle, .row = row, .col = col, .mod = mod, .buttons_down = buttons_down })) {
                handled = true;
            }
        }
        if (input_batch.mouseReleased(.right)) {
            if (try self.session.reportMouseEvent(.{ .kind = .release, .button = .right, .row = row, .col = col, .mod = mod, .buttons_down = buttons_down })) {
                handled = true;
            }
        }

        if (try self.session.reportMouseEvent(.{ .kind = .move, .button = .none, .row = row, .col = col, .mod = mod, .buttons_down = buttons_down })) {
            handled = true;
        }
    }

    if (allow_input) {
        var skip_chars = false;
        const allow_terminal_key = !(builtin.target.os.tag == .macos and super);
        const key_mode_flags = self.session.keyModeFlagsValue();
        const report_text_enabled = key_encoder.reportTextEnabled(key_mode_flags);
        const isModifierKey = struct {
            fn apply(key: shared_types.input.Key) bool {
                return switch (key) {
                    .left_shift,
                    .right_shift,
                    .left_ctrl,
                    .right_ctrl,
                    .left_alt,
                    .right_alt,
                    .left_super,
                    .right_super,
                    => true,
                    else => false,
                };
            }
        }.apply;
        const clearLiveState = struct {
            fn apply(widget: anytype) void {
                if (widget.session.scrollOffset() > 0) {
                    widget.session.setScrollOffset(0);
                }
            }
        }.apply;
        const applyTerminalKey = struct {
            fn apply(widget: anytype, key: shared_types.input.Key, key_mod: terminal_mod.Modifier, action: terminal_mod.KeyAction) !bool {
                return key_encoder.sendKeyAction(widget.session, key, key_mod, action);
            }
        }.apply;
        const translatedKeyCodepoint = struct {
            fn apply(renderer: anytype, key_event: shared_types.input.KeyEvent, shift_mod: bool) ?u32 {
                const sc = key_event.scancode orelse return null;
                return renderer.keycodeToCodepoint(renderer.keycodeFromScancode(sc, shift_mod));
            }
        }.apply;
        const keyAltMeta = struct {
            fn apply(
                renderer: anytype,
                key_event: shared_types.input.KeyEvent,
                base_char: ?u32,
            ) terminal_types.KeyboardAlternateMetadata {
                const translated_base = translatedKeyCodepoint(renderer, key_event, false);
                const translated_shifted = translatedKeyCodepoint(renderer, key_event, true);
                const event_sym = if (key_event.sym) |sym| renderer.keycodeToCodepoint(sym) else null;

                var meta = terminal_types.KeyboardAlternateMetadata{
                    .physical_key = if (key_event.scancode) |sc|
                        @as(terminal_types.PhysicalKey, @intCast(sc))
                    else
                        @as(terminal_types.PhysicalKey, @intCast(@intFromEnum(key_event.key))),
                    .base_codepoint = translated_base orelse base_char,
                    .shifted_codepoint = translated_shifted,
                };
                if (event_sym) |sym_cp| {
                    const base_cp = meta.base_codepoint;
                    const shifted_cp = meta.shifted_codepoint;
                    if (base_cp == null or sym_cp != base_cp.?) {
                        if (shifted_cp == null or sym_cp != shifted_cp.?) {
                            meta.alternate_layout_codepoint = sym_cp;
                        }
                    }
                }
                return meta;
            }
        }.apply;
        const textAltMeta = struct {
            fn apply(
                renderer: anytype,
                text_event: shared_types.input.TextEvent,
                key_event: ?shared_types.input.KeyEvent,
                fallback_char: u32,
            ) terminal_types.KeyboardAlternateMetadata {
                var utf8_buf: [4]u8 = undefined;
                const utf8_len = std.unicode.utf8Encode(@intCast(fallback_char), &utf8_buf) catch 0;
                var meta: terminal_types.KeyboardAlternateMetadata = .{
                    .produced_text_utf8 = if (text_event.utf8_len > 0)
                        text_event.utf8Slice()
                    else if (utf8_len > 0)
                        utf8_buf[0..utf8_len]
                    else
                        null,
                    .base_codepoint = fallback_char,
                    .text_is_composed = text_event.text_is_composed,
                };

                if (key_event) |ke| {
                    const key_meta = keyAltMeta(renderer, ke, fallback_char);
                    meta.physical_key = key_meta.physical_key;
                    meta.base_codepoint = key_meta.base_codepoint orelse fallback_char;
                    meta.shifted_codepoint = key_meta.shifted_codepoint;
                    meta.alternate_layout_codepoint = key_meta.alternate_layout_codepoint;
                }
                return meta;
            }
        }.apply;

        if (allow_terminal_key) {
            var handled_keys: [32]shared_types.input.Key = undefined;
            var handled_key_count: usize = 0;
            const markHandled = struct {
                fn apply(keys: *[32]shared_types.input.Key, count: *usize, key: shared_types.input.Key) void {
                    if (count.* >= keys.len) return;
                    keys[count.*] = key;
                    count.* += 1;
                }
            }.apply;
            const wasHandled = struct {
                fn apply(keys: *const [32]shared_types.input.Key, count: usize, key: shared_types.input.Key) bool {
                    var idx: usize = 0;
                    while (idx < count) : (idx += 1) {
                        if (keys[idx] == key) return true;
                    }
                    return false;
                }
            }.apply;
            const isRepeatKey = struct {
                fn apply(key: shared_types.input.Key) bool {
                    return key_encoder.isRepeatKey(key);
                }
            }.apply;

            for (input_batch.events.items) |event| {
                if (event != .key) continue;
                const key = event.key.key;
                if (suppress_shortcuts and ctrl and shift and (key == .c or key == .v)) {
                    continue;
                }
                if (!event.key.pressed) {
                    if (!report_text_enabled and isModifierKey(key)) {
                        continue;
                    }
                    if (report_text_enabled) {
                        if (key_encoder.baseCharForKey(key)) |base_char| {
                            clearLiveState(self);
                            try self.session.sendCharActionWithMetadata(base_char, mod, .release, keyAltMeta(r, event.key, base_char));
                            handled = true;
                            skip_chars = true;
                            continue;
                        }
                    }
                    const handled_release = try applyTerminalKey(self, key, mod, .release);
                    if (handled_release) {
                        clearLiveState(self);
                        handled = true;
                        skip_chars = true;
                    }
                    continue;
                }
                if (isRepeatKey(key) and event.key.pressed) {
                    continue;
                }
                const action: terminal_mod.KeyAction = if (event.key.repeated) .repeat else .press;
                if (!report_text_enabled and isModifierKey(key)) {
                    continue;
                }
                if (report_text_enabled) {
                    if (key_encoder.baseCharForKey(key)) |base_char| {
                        clearLiveState(self);
                        try self.session.sendCharActionWithMetadata(base_char, mod, action, keyAltMeta(r, event.key, base_char));
                        markHandled(&handled_keys, &handled_key_count, key);
                        handled = true;
                        skip_chars = true;
                        continue;
                    }
                }

                const handled_key = try applyTerminalKey(self, key, mod, action);

                if (handled_key) {
                    clearLiveState(self);
                    markHandled(&handled_keys, &handled_key_count, key);
                    handled = true;
                    skip_chars = true;
                    continue;
                }

                if (!report_text_enabled and (ctrl or alt)) {
                    if (try key_encoder.sendCharForKey(self.session, key, mod, action, ctrl, alt)) {
                        clearLiveState(self);
                        markHandled(&handled_keys, &handled_key_count, key);
                        handled = true;
                        skip_chars = true;
                    }
                }
            }

            for (key_encoder.repeat_keys) |key| {
                if (wasHandled(&handled_keys, handled_key_count, key)) continue;
                if (input_batch.keyReleased(key)) continue;
                if (input_batch.keyPressed(key) or input_batch.keyRepeated(key)) {
                    const action: terminal_mod.KeyAction = if (input_batch.keyRepeated(key)) .repeat else .press;
                    if (try applyTerminalKey(self, key, mod, action)) {
                        clearLiveState(self);
                        handled = true;
                        skip_chars = true;
                    }
                }
            }
        }

        if (!skip_chars and !report_text_enabled and !input_batch.mods.ctrl and !input_batch.mods.alt and !input_batch.mods.super) {
            var pending_text_key: ?shared_types.input.KeyEvent = null;
            for (input_batch.events.items) |event| {
                switch (event) {
                    .key => |key_event| {
                        if (key_event.pressed and !key_event.repeated) pending_text_key = key_event;
                    },
                    .text => |text_event| {
                        const char = text_event.codepoint;
                        if (char < 32) continue;
                        const alt_meta = textAltMeta(r, text_event, pending_text_key, char);
                        clearLiveState(self);
                        try self.session.sendCharActionWithMetadata(char, mod, .press, alt_meta);
                        handled = true;
                        pending_text_key = null;
                    },
                    else => {},
                }
            }
        }

        if (!mouse_reporting and in_terminal and mouse_on_scrollbar) {
            if (input_batch.mousePressed(.left)) {
                scroll_dragging.* = true;
                const track_h = scrollbar_h;
                const min_thumb_h: f32 = 18;
                const scroll_offset_local = self.session.scrollOffset();
                const ratio = if (max_scroll_offset > 0)
                    @as(f32, @floatFromInt(max_scroll_offset - scroll_offset_local)) / @as(f32, @floatFromInt(max_scroll_offset))
                else
                    1.0;
                const thumb = common.computeScrollbarThumb(scrollbar_y, track_h, rows, total_lines, min_thumb_h, ratio);
                scroll_grab_offset.* = mouse.y - thumb.thumb_y;
                if (scroll_log.enabled_file or scroll_log.enabled_console) {
                    scroll_log.logf("scrollbar press offset={d}", .{scroll_offset_local});
                }
                handled = true;
            }
        }

        if (!mouse_reporting and scroll_dragging.*) {
            if (input_batch.mouseDown(.left)) {
                const track_h = scrollbar_h;
                const min_thumb_h: f32 = 18;
                const thumb = common.computeScrollbarThumb(scrollbar_y, track_h, rows, total_lines, min_thumb_h, 0.0);
                const available = thumb.available;
                const clamped_mouse = @min(@max(mouse.y - scroll_grab_offset.*, scrollbar_y), scrollbar_y + available);
                const ratio = if (available > 0) (clamped_mouse - scrollbar_y) / available else 0;
                const target_offset = @as(usize, @intFromFloat(@round(@as(f32, @floatFromInt(max_scroll_offset)) * (1.0 - ratio))));
                self.session.setScrollOffset(target_offset);
                if (scroll_log.enabled_file or scroll_log.enabled_console) {
                    scroll_log.logf("scrollbar drag offset={d} ratio={d:.3}", .{ target_offset, ratio });
                }
                handled = true;
            } else {
                scroll_dragging.* = false;
            }
        }

        const suppress_selection_for_scrollbar = mouse_on_scrollbar or scroll_dragging.*;
        if (!mouse_reporting and in_terminal and !suppress_selection_for_scrollbar) {
            if (input_batch.mousePressed(.left)) {
                const local_x = mouse.x - x;
                const local_y = mouse.y - y;
                const col = @as(usize, @intFromFloat(local_x / shell.terminalCellWidth()));
                const row = @as(usize, @intFromFloat(local_y / shell.terminalCellHeight()));
                if (cols > 0 and rows > 0) {
                    const clamped_col = @min(col, cols - 1);
                    const clamped_row = @min(row, rows - 1);
                    const global_row = start_line + clamped_row;
                    if (global_row < history_len + rows) {
                        self.session.startSelection(global_row, clamped_col);
                        handled = true;
                    }
                }
            }

            if (input_batch.mouseDown(.left)) {
                if (self.session.selectionState()) |_| {
                    const local_x = mouse.x - x;
                    const local_y = mouse.y - y;
                    const col = @as(usize, @intFromFloat(local_x / shell.terminalCellWidth()));
                    const row = @as(usize, @intFromFloat(local_y / shell.terminalCellHeight()));
                    if (cols > 0 and rows > 0) {
                        const clamped_col = @min(col, cols - 1);
                        const clamped_row = @min(row, rows - 1);
                        const global_row = start_line + clamped_row;
                        if (global_row < history_len + rows) {
                            self.session.updateSelection(global_row, clamped_col);
                            handled = true;
                        }
                    }

                    // Autoscroll when dragging outside terminal area
                    if (mouse.y < y) {
                        self.session.scrollBy(1);
                        handled = true;
                    } else if (mouse.y > y + height) {
                        self.session.scrollBy(-1);
                        handled = true;
                    }
                }
            }

            if (input_batch.mouseReleased(.left)) {
                if (self.session.selectionState() != null) {
                    self.session.finishSelection();
                    handled = true;
                }
            }
        }

        if (!mouse_reporting and in_terminal) {
            if (input_batch.mousePressed(.middle)) {
                if (shell.getClipboardText()) |clip| {
                    if (self.session.bracketedPasteEnabled()) {
                        try self.session.sendText("\x1b[200~");
                        try self.session.sendText(clip);
                        try self.session.sendText("\x1b[201~");
                    } else {
                        try self.session.sendText(clip);
                    }
                    handled = true;
                }
            }
            if (wheel_steps != 0) {
                const delta: isize = @intCast(wheel_steps * 3);
                self.session.scrollBy(delta);
                if (scroll_log.enabled_file or scroll_log.enabled_console) {
                    scroll_log.logf("scroll wheel delta={d}", .{delta});
                }
                handled = true;
            }
        }

    }

    return handled;
}

const std = @import("std");
const builtin = @import("builtin");

const app_shell = @import("../../app_shell.zig");
const terminal_mod = @import("../../terminal/core/terminal.zig");
const terminal_types = @import("../../terminal/model/types.zig");
const key_encoder = @import("../../terminal/input/key_encoder.zig");
const alt_probe = @import("../../terminal/input/alternate_probe.zig");
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
    const mouse = input_batch.mouse_pos;
    const in_terminal = common.pointInRect(mouse.x, mouse.y, x, y, width, height);
    var handled = false;
    self.scrollbar_drag_active = scroll_dragging.*;
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
    const scrollbar_w: f32 = common.lerp(scrollbar_base_w, scrollbar_hover_w, if (scroll_dragging.*) 1.0 else proximity_t);
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
    const scroll_log = app_logger.logger("terminal.scroll");
    const altmeta_log = app_logger.logger("terminal.input.altmeta");
    const key_log = app_logger.logger("terminal.input.keys");

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

    if (self.session.tryLock()) {
        defer self.session.unlock();
        if (self.session.takeOscClipboard()) |clip| {
            const cstr: [*:0]const u8 = @ptrCast(clip.ptr);
            shell.setClipboardText(cstr);
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
                widget.session.lock();
                defer widget.session.unlock();
                if (widget.session.scrollOffset() > 0) {
                    widget.session.setScrollOffset(0);
                }
            }
        }.apply;
        const rowLastContentCol = struct {
            fn apply(cells: []const terminal_types.Cell, cols_count: usize, row_idx: usize) ?usize {
                if (cols_count == 0) return null;
                const row_start = row_idx * cols_count;
                if (row_start + cols_count > cells.len) return null;
                const row_cells = cells[row_start .. row_start + cols_count];
                var last: ?usize = null;
                var col_idx: usize = 0;
                while (col_idx < cols_count) : (col_idx += 1) {
                    const cell = row_cells[col_idx];
                    if (cell.x != 0 or cell.y != 0) continue;
                    if (cell.codepoint == 0 and cell.combining_len == 0) continue;
                    const width_units = @as(usize, @max(@as(u8, 1), cell.width));
                    const cell_end = @min(cols_count - 1, col_idx + width_units - 1);
                    last = cell_end;
                }
                return last;
            }
        }.apply;
        const applyTerminalKey = struct {
            fn apply(widget: anytype, key: shared_types.input.Key, key_mod: terminal_mod.Modifier, action: terminal_mod.KeyAction) !bool {
                return key_encoder.sendKeyAction(widget.session, key, key_mod, action);
            }
        }.apply;
        const keyModFromEvent = struct {
            fn apply(key_event: shared_types.input.KeyEvent) terminal_mod.Modifier {
                var m: terminal_mod.Modifier = terminal_mod.VTERM_MOD_NONE;
                if (key_event.mods.shift) m |= terminal_mod.VTERM_MOD_SHIFT;
                if (key_event.mods.alt) m |= terminal_mod.VTERM_MOD_ALT;
                if (key_event.mods.ctrl) m |= terminal_mod.VTERM_MOD_CTRL;
                return m;
            }
        }.apply;
        const translatedKeyCodepoint = struct {
            fn apply(renderer: anytype, key_event: shared_types.input.KeyEvent, shift_mod: bool) ?u32 {
                const sc = key_event.scancode orelse return null;
                return renderer.keycodeToCodepoint(renderer.keycodeFromScancode(sc, shift_mod));
            }
        }.apply;
        const translatedKeyCodepointMods = struct {
            fn apply(
                renderer: anytype,
                key_event: shared_types.input.KeyEvent,
                shift_mod: bool,
                alt_mod: bool,
                ctrl_mod: bool,
                super_mod: bool,
            ) ?u32 {
                const sc = key_event.scancode orelse return null;
                return renderer.keycodeToCodepoint(
                    renderer.keycodeFromScancodeMods(sc, shift_mod, alt_mod, ctrl_mod, super_mod),
                );
            }
        }.apply;
        const keyAltMeta = struct {
            fn apply(
                renderer: anytype,
                log: app_logger.Logger,
                key_event: shared_types.input.KeyEvent,
                base_char: ?u32,
            ) terminal_types.KeyboardAlternateMetadata {
                const explicit_altgr = key_event.mods.altgr;
                const explicit_non_altgr_alt = key_event.mods.alt and !key_event.mods.altgr;
                const translated_base = translatedKeyCodepoint(renderer, key_event, false);
                const translated_shifted = translatedKeyCodepoint(renderer, key_event, true);
                const translated_altgr = translatedKeyCodepointMods(renderer, key_event, false, true, true, false);
                const translated_shift_altgr = translatedKeyCodepointMods(renderer, key_event, true, true, true, false);
                const event_sym = if (key_event.sym) |sym| renderer.keycodeToCodepoint(sym) else null;

                var meta = terminal_types.KeyboardAlternateMetadata{
                    .physical_key = if (key_event.scancode) |sc|
                        @as(terminal_types.PhysicalKey, @intCast(sc))
                    else
                        @as(terminal_types.PhysicalKey, @intCast(@intFromEnum(key_event.key))),
                    .base_codepoint = translated_base orelse base_char,
                    .shifted_codepoint = translated_shifted,
                };
                meta.alternate_layout_codepoint = alt_probe.selectThirdAlternate(.{
                    .base = meta.base_codepoint,
                    .shifted = meta.shifted_codepoint,
                    .event_sym = event_sym,
                    .altgr = translated_altgr,
                    .altgr_shift = translated_shift_altgr,
                    .explicit_altgr = explicit_altgr,
                    .explicit_non_altgr_alt = explicit_non_altgr_alt,
                });
                log.logf(
                    .info,
                    "key={d} sc={d} sym={d} sdl_mods={d} flags(exp_altgr={d} exp_non_alt={d}) mods(s={d} a={d} c={d} g={d}) trans(base={d} shift={d} altgr={d} altgr_shift={d}) meta(base={d} shift={d} alt={d})",
                    .{
                        @intFromEnum(key_event.key),
                        key_event.scancode orelse -1,
                        key_event.sym orelse 0,
                        key_event.sdl_mod_bits orelse 0,
                        @intFromBool(explicit_altgr),
                        @intFromBool(explicit_non_altgr_alt),
                        @intFromBool(key_event.mods.shift),
                        @intFromBool(key_event.mods.alt),
                        @intFromBool(key_event.mods.ctrl),
                        @intFromBool(key_event.mods.super),
                        translated_base orelse 0,
                        translated_shifted orelse 0,
                        translated_altgr orelse 0,
                        translated_shift_altgr orelse 0,
                        meta.base_codepoint orelse 0,
                        meta.shifted_codepoint orelse 0,
                        meta.alternate_layout_codepoint orelse 0,
                    },
                );
                return meta;
            }
        }.apply;
        const textAltMeta = struct {
            fn apply(
                renderer: anytype,
                log: app_logger.Logger,
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
                    const key_meta = keyAltMeta(renderer, log, ke, fallback_char);
                    meta.physical_key = key_meta.physical_key;
                    meta.base_codepoint = key_meta.base_codepoint orelse fallback_char;
                    meta.shifted_codepoint = key_meta.shifted_codepoint;
                    meta.alternate_layout_codepoint = key_meta.alternate_layout_codepoint;
                }
                return meta;
            }
        }.apply;

        var reset_scrollback = false;
        if (scroll_offset > 0) {
            for (input_batch.events.items) |event| {
                switch (event) {
                    .key => |key_event| {
                        if (key_event.pressed and !isModifierKey(key_event.key)) {
                            reset_scrollback = true;
                            break;
                        }
                    },
                    .text => {
                        reset_scrollback = true;
                        break;
                    },
                    else => {},
                }
            }
        }

        if (allow_terminal_key) {
            if (input_batch.events.items.len > 0) {
                key_log.logf(
                    .info,
                    "frame key_mode_flags={d} report_text={d} auto_repeat={d} events={d}",
                    .{
                        key_mode_flags,
                        @intFromBool(report_text_enabled),
                        @intFromBool(self.session.autoRepeatEnabled()),
                        input_batch.events.items.len,
                    },
                );
            }
            for (input_batch.events.items) |event| {
                if (event != .focus) continue;
                if (try self.reportFocusChangedFrom(.window, event.focus)) {
                    handled = true;
                }
            }

            for (input_batch.events.items) |event| {
                if (event != .key) continue;
                const key = event.key.key;
                const event_mod = keyModFromEvent(event.key);
                key_log.logf(
                    .info,
                    "event key={d} pressed={d} repeated={d} mods(s={d} a={d} c={d} g={d} super={d})",
                    .{
                        @intFromEnum(key),
                        @intFromBool(event.key.pressed),
                        @intFromBool(event.key.repeated),
                        @intFromBool(event.key.mods.shift),
                        @intFromBool(event.key.mods.alt),
                        @intFromBool(event.key.mods.ctrl),
                        @intFromBool(event.key.mods.altgr),
                        @intFromBool(event.key.mods.super),
                    },
                );
                if (suppress_shortcuts and ctrl and shift and (key == .c or key == .v)) {
                    key_log.logf(.info, "skip key={d} reason=suppress_shortcuts", .{@intFromEnum(key)});
                    continue;
                }
                if (!event.key.pressed) {
                    if (!report_text_enabled and isModifierKey(key)) {
                        key_log.logf(.info, "skip key={d} reason=modifier_release_without_report_text", .{@intFromEnum(key)});
                        continue;
                    }
                    if (report_text_enabled) {
                        if (key_encoder.baseCharForKey(key)) |base_char| {
                            clearLiveState(self);
                            try self.session.sendCharActionWithMetadata(base_char, event_mod, .release, keyAltMeta(r, altmeta_log, event.key, base_char));
                            key_log.logf(.info, "send char key={d} action=release base_char={d}", .{ @intFromEnum(key), base_char });
                            handled = true;
                            skip_chars = true;
                            continue;
                        }
                    }
                    const handled_release = try applyTerminalKey(self, key, event_mod, .release);
                    key_log.logf(.info, "send key={d} action=release handled={d}", .{ @intFromEnum(key), @intFromBool(handled_release) });
                    if (handled_release) {
                        clearLiveState(self);
                        handled = true;
                        skip_chars = true;
                    }
                    continue;
                }
                const action: terminal_mod.KeyAction = if (event.key.repeated) .repeat else .press;
                if (action == .repeat and !self.session.autoRepeatEnabled()) {
                    key_log.logf(.info, "skip key={d} action=repeat reason=auto_repeat_disabled", .{@intFromEnum(key)});
                    continue;
                }
                if (!report_text_enabled and isModifierKey(key)) {
                    key_log.logf(.info, "skip key={d} action={s} reason=modifier_without_report_text", .{ @intFromEnum(key), @tagName(action) });
                    continue;
                }
                if (report_text_enabled) {
                    if (key_encoder.baseCharForKey(key)) |base_char| {
                        clearLiveState(self);
                        try self.session.sendCharActionWithMetadata(base_char, event_mod, action, keyAltMeta(r, altmeta_log, event.key, base_char));
                        key_log.logf(.info, "send char key={d} action={s} base_char={d}", .{ @intFromEnum(key), @tagName(action), base_char });
                        handled = true;
                        skip_chars = true;
                        continue;
                    }
                }

                const handled_key = try applyTerminalKey(self, key, event_mod, action);
                key_log.logf(.info, "send key={d} action={s} handled={d}", .{ @intFromEnum(key), @tagName(action), @intFromBool(handled_key) });

                if (handled_key) {
                    clearLiveState(self);
                    handled = true;
                    skip_chars = true;
                    continue;
                }

                if (!report_text_enabled and (event.key.mods.ctrl or event.key.mods.alt)) {
                    if (try key_encoder.sendCharForKey(self.session, key, event_mod, action, event.key.mods.ctrl, event.key.mods.alt)) {
                        key_log.logf(.info, "send ctrl_alt_char key={d} action={s}", .{ @intFromEnum(key), @tagName(action) });
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
                        const alt_meta = textAltMeta(r, altmeta_log, text_event, pending_text_key, char);
                        clearLiveState(self);
                        try self.session.sendCharActionWithMetadata(char, mod, .press, alt_meta);
                        handled = true;
                        pending_text_key = null;
                    },
                    else => {},
                }
            }
        }

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

        const suppress_selection_for_scrollbar = mouse_on_scrollbar or scroll_dragging.*;
        if (!mouse_reporting and (reset_scrollback or in_terminal or scroll_dragging.*)) {
            self.session.lock();
            defer self.session.unlock();

            if (reset_scrollback and self.session.scrollOffset() > 0) {
                self.session.setScrollOffset(0);
            }

            if (in_terminal and mouse_on_scrollbar and input_batch.mousePressed(.left)) {
                scroll_dragging.* = true;
                self.scrollbar_drag_active = true;
                const track_h = scrollbar_h;
                const min_thumb_h: f32 = 18;
                const scroll_offset_local = self.session.scrollOffset();
                const ratio = if (max_scroll_offset > 0)
                    @as(f32, @floatFromInt(max_scroll_offset - scroll_offset_local)) / @as(f32, @floatFromInt(max_scroll_offset))
                else
                    1.0;
                const thumb = common.computeScrollbarThumb(scrollbar_y, track_h, rows, total_lines, min_thumb_h, ratio);
                scroll_grab_offset.* = mouse.y - thumb.thumb_y;
                scroll_log.logf(.info, "scrollbar press offset={d}", .{scroll_offset_local});
                handled = true;
            }

            if (scroll_dragging.*) {
                if (input_batch.mouseDown(.left)) {
                    const track_h = scrollbar_h;
                    const min_thumb_h: f32 = 18;
                    const thumb = common.computeScrollbarThumb(scrollbar_y, track_h, rows, total_lines, min_thumb_h, 0.0);
                    const available = thumb.available;
                    const clamped_mouse = @min(@max(mouse.y - scroll_grab_offset.*, scrollbar_y), scrollbar_y + available);
                    const ratio = if (available > 0) (clamped_mouse - scrollbar_y) / available else 0;
                    const target_offset = @as(usize, @intFromFloat(@round(@as(f32, @floatFromInt(max_scroll_offset)) * (1.0 - ratio))));
                    self.session.setScrollOffset(target_offset);
                    scroll_log.logf(.info, "scrollbar drag offset={d} ratio={d:.3}", .{ target_offset, ratio });
                    handled = true;
                } else {
                    scroll_dragging.* = false;
                    self.scrollbar_drag_active = false;
                }
            }

            if (in_terminal and input_batch.mousePressed(.left) and self.session.selectionState() != null) {
                self.session.clearSelection();
                handled = true;
            }
            if (has_visible_grid and in_terminal and !suppress_selection_for_scrollbar) {
                if (input_batch.mousePressed(.left)) {
                    const press_mouse = input_batch.mousePressPos(.left) orelse mouse;
                    const col = @as(usize, @intFromFloat((press_mouse.x - hit_base_x) / hit_cell_w));
                    const row = @as(usize, @intFromFloat((press_mouse.y - hit_base_y) / hit_cell_h));
                    const clamped_col = @min(col, cols - 1);
                    const clamped_row = @min(row, rows - 1);
                    const global_row = start_line + clamped_row;
                    if (global_row < history_len + rows) {
                        const row_cells = view_cells[clamped_row * cols .. (clamped_row + 1) * cols];
                        if (rowLastContentCol(view_cells, cols, clamped_row)) |last_col| {
                            const click_count = input_batch.mouseClicks(.left);
                            self.selection_press_origin = press_mouse;
                            self.selection_drag_active = false;
                            if (click_count >= 3) {
                                self.multi_click_selection_mode = .line;
                                self.multi_click_anchor_row = global_row;
                                self.multi_click_anchor_col_start = 0;
                                self.multi_click_anchor_col_end = last_col;
                                self.session.startSelection(global_row, 0);
                                self.session.updateSelection(global_row, last_col);
                                self.session.finishSelection();
                                handled = true;
                            } else if (click_count == 2) {
                                if (selectWordSpan(row_cells, cols, clamped_col, last_col)) |span| {
                                    self.multi_click_selection_mode = .word;
                                    self.multi_click_anchor_row = global_row;
                                    self.multi_click_anchor_col_start = span.start;
                                    self.multi_click_anchor_col_end = span.end;
                                    self.session.startSelection(global_row, span.start);
                                    self.session.updateSelection(global_row, span.end);
                                    self.session.finishSelection();
                                    handled = true;
                                } else {
                                    self.multi_click_selection_mode = .none;
                                    const sel_col = @min(clamped_col, last_col);
                                    self.session.startSelection(global_row, sel_col);
                                    handled = true;
                                }
                            } else {
                                self.multi_click_selection_mode = .none;
                                // Single-click only sets drag origin; selection begins once drag threshold is crossed.
                            }
                        }
                    }
                }

                var drag_select_active = input_batch.mouseDown(.left) and !input_batch.mousePressed(.left);
                if (drag_select_active and !self.selection_drag_active) {
                    if (self.selection_press_origin) |origin| {
                        const dx = mouse.x - origin.x;
                        const dy = mouse.y - origin.y;
                        const dist2 = dx * dx + dy * dy;
                        const threshold = hit_cell_w;
                        const threshold2 = threshold * threshold;
                        if (dist2 >= threshold2) {
                            self.selection_drag_active = true;
                        } else {
                            drag_select_active = false;
                        }
                    } else {
                        drag_select_active = false;
                    }
                }
                const drag_select_multi = drag_select_active and self.multi_click_selection_mode != .none;
                const drag_select_normal = drag_select_active and self.multi_click_selection_mode == .none;
                if (drag_select_multi) {
                    const col = @as(usize, @intFromFloat((mouse.x - hit_base_x) / hit_cell_w));
                    const row = @as(usize, @intFromFloat((mouse.y - hit_base_y) / hit_cell_h));
                    const clamped_col = @min(col, cols - 1);
                    const clamped_row = @min(row, rows - 1);
                    const global_row = start_line + clamped_row;
                    if (global_row < history_len + rows) {
                        const row_cells = view_cells[clamped_row * cols .. (clamped_row + 1) * cols];
                        const last_col_opt = rowLastContentCol(view_cells, cols, clamped_row);
                        switch (self.multi_click_selection_mode) {
                            .word => {
                                var target_start: usize = clamped_col;
                                var target_end: usize = clamped_col;
                                if (last_col_opt) |last_col| {
                                    if (selectWordSpan(row_cells, cols, clamped_col, last_col)) |span| {
                                        target_start = span.start;
                                        target_end = span.end;
                                    } else {
                                        const sel_col = @min(clamped_col, last_col);
                                        target_start = sel_col;
                                        target_end = sel_col;
                                    }
                                } else {
                                    target_start = 0;
                                    target_end = 0;
                                }
                                const anchor_start = SelPoint{
                                    .row = self.multi_click_anchor_row,
                                    .col = self.multi_click_anchor_col_start,
                                };
                                const anchor_end = SelPoint{
                                    .row = self.multi_click_anchor_row,
                                    .col = self.multi_click_anchor_col_end,
                                };
                                const target_start_pos = SelPoint{ .row = global_row, .col = target_start };
                                const target_end_pos = SelPoint{ .row = global_row, .col = target_end };
                                var sel_start: SelPoint = undefined;
                                var sel_end: SelPoint = undefined;
                                if (selPointBefore(target_start_pos, anchor_start)) {
                                    sel_start = target_start_pos;
                                    sel_end = anchor_end;
                                } else {
                                    sel_start = anchor_start;
                                    sel_end = target_end_pos;
                                }
                                self.session.startSelection(sel_start.row, sel_start.col);
                                self.session.updateSelection(sel_end.row, sel_end.col);
                                handled = true;
                            },
                            .line => {
                                const target_last = last_col_opt orelse 0;
                                const anchor_start = SelPoint{ .row = self.multi_click_anchor_row, .col = 0 };
                                const anchor_end = SelPoint{
                                    .row = self.multi_click_anchor_row,
                                    .col = self.multi_click_anchor_col_end,
                                };
                                const target_start_pos = SelPoint{ .row = global_row, .col = 0 };
                                const target_end_pos = SelPoint{ .row = global_row, .col = target_last };
                                var sel_start: SelPoint = undefined;
                                var sel_end: SelPoint = undefined;
                                if (selPointBefore(target_start_pos, anchor_start)) {
                                    sel_start = target_start_pos;
                                    sel_end = anchor_end;
                                } else {
                                    sel_start = anchor_start;
                                    sel_end = target_end_pos;
                                }
                                self.session.startSelection(sel_start.row, sel_start.col);
                                self.session.updateSelection(sel_end.row, sel_end.col);
                                handled = true;
                            },
                            .none => {},
                        }
                    }

                    if (self.session.selectionState() != null) {
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
                if (drag_select_normal) {
                    const col = @as(usize, @intFromFloat((mouse.x - hit_base_x) / hit_cell_w));
                    const row = @as(usize, @intFromFloat((mouse.y - hit_base_y) / hit_cell_h));
                    const clamped_col = @min(col, cols - 1);
                    const clamped_row = @min(row, rows - 1);
                    const global_row = start_line + clamped_row;
                    if (global_row < history_len + rows) {
                        if (rowLastContentCol(view_cells, cols, clamped_row)) |last_col| {
                            const sel_col = @min(clamped_col, last_col);
                            if (self.session.selectionState() == null) {
                                // Late-start selection when drag begins on blank space and enters content.
                                self.session.startSelection(global_row, sel_col);
                                handled = true;
                            } else {
                                self.session.updateSelection(global_row, sel_col);
                                handled = true;
                            }
                        }
                    }

                    if (self.session.selectionState() != null) {
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
                    self.multi_click_selection_mode = .none;
                    self.selection_press_origin = null;
                    self.selection_drag_active = false;
                    if (self.session.selectionState() != null) {
                        self.session.finishSelection();
                        handled = true;
                    }
                }
            }

            if (in_terminal and input_batch.mousePressed(.middle)) {
                const has_supported_clipboard_data = clip_opt != null or html != null or uri_list != null or png != null;
                if (has_supported_clipboard_data) {
                    const clip = clip_opt orelse "";
                    if (try self.session.sendKittyPasteEvent5522WithMimeRich(clip, html, uri_list, png)) {
                        handled = true;
                    } else if (clip_opt) |clip_text| {
                        if (self.session.bracketedPasteEnabled()) {
                            try self.session.sendText("\x1b[200~");
                            try self.session.sendText(clip_text);
                            try self.session.sendText("\x1b[201~");
                        } else {
                            try self.session.sendText(clip_text);
                        }
                        handled = true;
                    }
                }
            }
            if (in_terminal and wheel_steps != 0) {
                if (try self.session.reportAlternateScrollWheel(wheel_steps, mod)) {
                    scroll_log.logf(.info, "alt-scroll wheel steps={d}", .{wheel_steps});
                    handled = true;
                    wheel_steps = 0;
                }
            }
            if (in_terminal and wheel_steps != 0) {
                const delta: isize = @intCast(wheel_steps * 3);
                self.session.scrollBy(delta);
                scroll_log.logf(.info, "scroll wheel delta={d}", .{delta});
                handled = true;
            }
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

    if (input_batch.mouseReleased(.left)) {
        self.multi_click_selection_mode = .none;
        self.selection_press_origin = null;
        self.selection_drag_active = false;
    }
    self.scrollbar_drag_active = scroll_dragging.*;
    return handled;
}

const WordSpan = struct {
    start: usize,
    end: usize,
};

fn selectWordSpan(row_cells: []const terminal_types.Cell, cols_count: usize, col: usize, last_col: usize) ?WordSpan {
    if (cols_count == 0 or row_cells.len < cols_count) return null;
    const clamped_last = @min(last_col, cols_count - 1);
    var anchor = @min(col, clamped_last);
    anchor = cellRootCol(row_cells, anchor);
    const anchor_class = classifySelectionCell(row_cells[anchor]);
    if (anchor_class == .empty) return null;

    var start = anchor;
    while (start > 0) {
        const prev = start - 1;
        const prev_root = cellRootCol(row_cells, prev);
        if (prev_root >= start) break;
        if (prev_root > clamped_last) break;
        if (classifySelectionCell(row_cells[prev_root]) != anchor_class) break;
        start = prev_root;
    }

    var end = anchor;
    while (end < clamped_last) {
        const next = end + 1;
        const next_root = cellRootCol(row_cells, next);
        if (next_root <= end) break;
        if (next_root > clamped_last) break;
        if (classifySelectionCell(row_cells[next_root]) != anchor_class) break;
        end = next_root;
    }

    return .{ .start = start, .end = end };
}

const SelectionCellClass = enum {
    empty,
    word,
    space,
    other,
};

const SelPoint = struct {
    row: usize,
    col: usize,
};

fn selPointBefore(a: SelPoint, b: SelPoint) bool {
    if (a.row < b.row) return true;
    if (a.row > b.row) return false;
    return a.col < b.col;
}

fn classifySelectionCell(cell: terminal_types.Cell) SelectionCellClass {
    if (cell.x != 0 or cell.y != 0) return .empty;
    if (cell.codepoint == 0 and cell.combining_len == 0) return .space;
    const cp = cell.codepoint;
    if (cp <= 0x7F) {
        const b: u8 = @intCast(cp);
        if (std.ascii.isAlphanumeric(b) or b == '_') return .word;
        if (std.ascii.isWhitespace(b)) return .space;
    } else {
        // Treat non-ASCII graphemes as word characters by default.
        return .word;
    }
    return .other;
}

fn cellRootCol(row_cells: []const terminal_types.Cell, col: usize) usize {
    if (row_cells.len == 0) return 0;
    const idx = @min(col, row_cells.len - 1);
    const cell = row_cells[idx];
    if (cell.x == 0 or cell.y != 0) return idx;
    const delta = @as(usize, cell.x);
    if (delta > idx) return 0;
    return idx - delta;
}

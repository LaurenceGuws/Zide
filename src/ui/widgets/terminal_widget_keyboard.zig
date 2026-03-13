const std = @import("std");
const builtin = @import("builtin");

const terminal_mod = @import("../../terminal/core/terminal.zig");
const terminal_types = @import("../../terminal/model/types.zig");
const key_encoder = @import("../../terminal/input/key_encoder.zig");
const alt_probe = @import("../../terminal/input/alternate_probe.zig");
const app_logger = @import("../../app_logger.zig");
const shared_types = @import("../../types/mod.zig");

pub const InputResult = struct {
    handled: bool = false,
    skip_chars: bool = false,
    saw_non_modifier_key_press: bool = false,
    saw_text_input: bool = false,
};

pub fn handleKeyboardInput(
    self: anytype,
    renderer: anytype,
    scroll_offset: usize,
    allow_input: bool,
    suppress_shortcuts: bool,
    input_batch: *shared_types.input.InputBatch,
    mod: terminal_mod.Modifier,
) !InputResult {
    _ = allow_input;
    var result = InputResult{};

    const altmeta_log = app_logger.logger("terminal.input.altmeta");
    const key_log = app_logger.logger("terminal.input.keys");
    const dump_log = app_logger.logger("terminal.ui.dump");

    const key_mode_flags = self.session.keyModeFlagsValue();
    const report_text_enabled = key_encoder.reportTextEnabled(key_mode_flags);
    const allow_terminal_key = !(builtin.target.os.tag == .macos and input_batch.mods.super);

    if (scroll_offset > 0) {
        for (input_batch.events.items) |event| {
            switch (event) {
                .key => |key_event| {
                    if (key_event.pressed and !isModifierKey(key_event.key)) {
                        result.saw_non_modifier_key_press = true;
                        break;
                    }
                },
                .text => {
                    result.saw_text_input = true;
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
                result.handled = true;
            }
        }

        for (input_batch.events.items) |event| {
            if (event != .key) continue;
            const key = event.key.key;
            const event_mod = keyModFromEvent(event.key);
            if (event.key.pressed and !event.key.repeated and event.key.mods.ctrl and event.key.mods.shift and !event.key.mods.alt and !event.key.mods.altgr and !event.key.mods.super and key == .f12) {
                self.dumpVisibleAsciiView() catch |err| {
                    dump_log.logf(.warning, "visible_ascii_dump failed err={s}", .{@errorName(err)});
                    result.handled = true;
                    result.skip_chars = true;
                    continue;
                };
                dump_log.logf(.info, "visible_ascii_dump path={s} rows={d} cols={d} alt_active={d} generation={d}", .{
                    "zide_terminal_view_dump.txt",
                    self.draw_cache.rows,
                    self.draw_cache.cols,
                    @intFromBool(self.draw_cache.alt_active),
                    self.draw_cache.generation,
                });
                result.handled = true;
                result.skip_chars = true;
                continue;
            }
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
            if (suppress_shortcuts and input_batch.mods.ctrl and input_batch.mods.shift and (key == .c or key == .v)) {
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
                        try self.session.sendCharActionWithMetadata(base_char, event_mod, .release, keyAltMeta(renderer, altmeta_log, event.key, base_char));
                        key_log.logf(.info, "send char key={d} action=release base_char={d}", .{ @intFromEnum(key), base_char });
                        result.handled = true;
                        result.skip_chars = true;
                        continue;
                    }
                }
                const handled_release = try key_encoder.sendKeyAction(self.session, key, event_mod, .release);
                key_log.logf(.info, "send key={d} action=release handled={d}", .{ @intFromEnum(key), @intFromBool(handled_release) });
                if (handled_release) {
                    clearLiveState(self);
                    result.handled = true;
                    result.skip_chars = true;
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
                    try self.session.sendCharActionWithMetadata(base_char, event_mod, action, keyAltMeta(renderer, altmeta_log, event.key, base_char));
                    key_log.logf(.info, "send char key={d} action={s} base_char={d}", .{ @intFromEnum(key), @tagName(action), base_char });
                    result.handled = true;
                    result.skip_chars = true;
                    continue;
                }
            }

            const handled_key = try key_encoder.sendKeyAction(self.session, key, event_mod, action);
            key_log.logf(.info, "send key={d} action={s} handled={d}", .{ @intFromEnum(key), @tagName(action), @intFromBool(handled_key) });

            if (handled_key) {
                clearLiveState(self);
                result.handled = true;
                result.skip_chars = true;
                continue;
            }

            if (!report_text_enabled and (event.key.mods.ctrl or event.key.mods.alt)) {
                if (try key_encoder.sendCharForKey(self.session, key, event_mod, action, event.key.mods.ctrl, event.key.mods.alt)) {
                    key_log.logf(.info, "send ctrl_alt_char key={d} action={s}", .{ @intFromEnum(key), @tagName(action) });
                    clearLiveState(self);
                    result.handled = true;
                    result.skip_chars = true;
                }
            }
        }
    }

    if (!result.skip_chars and !report_text_enabled and !input_batch.mods.ctrl and !input_batch.mods.alt and !input_batch.mods.super) {
        var pending_text_key: ?shared_types.input.KeyEvent = null;
        for (input_batch.events.items) |event| {
            switch (event) {
                .key => |key_event| {
                    if (key_event.pressed and !key_event.repeated) pending_text_key = key_event;
                },
                .text => |text_event| {
                    const char = text_event.codepoint;
                    if (char < 32) continue;
                    const alt_meta = textAltMeta(renderer, altmeta_log, text_event, pending_text_key, char);
                    clearLiveState(self);
                    try self.session.sendCharActionWithMetadata(char, mod, .press, alt_meta);
                    result.handled = true;
                    pending_text_key = null;
                },
                else => {},
            }
        }
    }

    return result;
}

fn isModifierKey(key: shared_types.input.Key) bool {
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

fn clearLiveState(widget: anytype) void {
    widget.session.lock();
    defer widget.session.unlock();
    _ = widget.session.resetToLiveBottomLocked();
}

fn keyModFromEvent(key_event: shared_types.input.KeyEvent) terminal_mod.Modifier {
    var m: terminal_mod.Modifier = terminal_mod.VTERM_MOD_NONE;
    if (key_event.mods.shift) m |= terminal_mod.VTERM_MOD_SHIFT;
    if (key_event.mods.alt) m |= terminal_mod.VTERM_MOD_ALT;
    if (key_event.mods.ctrl) m |= terminal_mod.VTERM_MOD_CTRL;
    return m;
}

fn translatedKeyCodepoint(renderer: anytype, key_event: shared_types.input.KeyEvent, shift_mod: bool) ?u32 {
    const sc = key_event.scancode orelse return null;
    return renderer.keycodeToCodepoint(renderer.keycodeFromScancode(sc, shift_mod));
}

fn translatedKeyCodepointMods(
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

fn keyAltMeta(
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

fn textAltMeta(
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

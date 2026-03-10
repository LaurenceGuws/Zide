const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const input_modes = @import("input_modes.zig");
const input_mod = @import("../input/input.zig");
const types = @import("../model/types.zig");

const Key = types.Key;
const Modifier = types.Modifier;
const MouseEvent = types.MouseEvent;
const VTERM_KEY_UP = types.VTERM_KEY_UP;
const VTERM_KEY_DOWN = types.VTERM_KEY_DOWN;
const VTERM_KEY_RIGHT = types.VTERM_KEY_RIGHT;
const VTERM_KEY_LEFT = types.VTERM_KEY_LEFT;
const VTERM_KEY_HOME = types.VTERM_KEY_HOME;
const VTERM_KEY_END = types.VTERM_KEY_END;
const VTERM_MOD_NONE = types.VTERM_MOD_NONE;

fn isNavigationKey(key: Key) bool {
    return switch (key) {
        VTERM_KEY_UP, VTERM_KEY_DOWN, VTERM_KEY_LEFT, VTERM_KEY_RIGHT, VTERM_KEY_HOME, VTERM_KEY_END => true,
        else => false,
    };
}

fn keyName(key: Key) []const u8 {
    return switch (key) {
        VTERM_KEY_UP => "up",
        VTERM_KEY_DOWN => "down",
        VTERM_KEY_LEFT => "left",
        VTERM_KEY_RIGHT => "right",
        VTERM_KEY_HOME => "home",
        VTERM_KEY_END => "end",
        else => "other",
    };
}

fn keypadKeyName(key: input_mod.KeypadKey) []const u8 {
    return switch (key) {
        .kp0 => "kp0",
        .kp1 => "kp1",
        .kp2 => "kp2",
        .kp3 => "kp3",
        .kp4 => "kp4",
        .kp5 => "kp5",
        .kp6 => "kp6",
        .kp7 => "kp7",
        .kp8 => "kp8",
        .kp9 => "kp9",
        .kp_decimal => "kp_decimal",
        .kp_divide => "kp_divide",
        .kp_multiply => "kp_multiply",
        .kp_subtract => "kp_subtract",
        .kp_add => "kp_add",
        .kp_enter => "kp_enter",
        .kp_equal => "kp_equal",
    };
}

fn echoCharLocallyIfEnabled(self: anytype, char: u32, mod: Modifier, action: input_mod.KeyAction) void {
    if (action == .release) return;
    if (mod != VTERM_MOD_NONE) return;
    if (char < 0x20 or char == 0x7F) return;
    if (char > 0x10FFFF or (char >= 0xD800 and char <= 0xDFFF)) return;
    const screen = self.activeScreen();
    if (!screen.local_echo_mode_12) return;
    self.handleCodepoint(char);
}

pub fn sendKey(self: anytype, key: Key, mod: Modifier) !void {
    try sendKeyAction(self, key, mod, input_mod.KeyAction.press);
}

pub fn sendKeyAction(self: anytype, key: Key, mod: Modifier, action: input_mod.KeyAction) !void {
    if (action == .repeat and !self.input_snapshot.auto_repeat.load(.acquire)) return;
    const log = app_logger.logger("terminal.input");
    const input_snapshot = self.input_snapshot;
    const key_mode_flags = input_snapshot.key_mode_flags.load(.acquire);
    const app_cursor = input_snapshot.app_cursor_keys.load(.acquire);
    if (isNavigationKey(key)) {
        log.logf(.debug, "sendKey key={s} code={d} mod=0x{x} action={s} app_cursor={any} key_mode=0x{x}", .{
            keyName(key),
            key,
            mod,
            @tagName(action),
            app_cursor,
            key_mode_flags,
        });
    }
    if (self.lockPtyWriter()) |writer_guard| {
        var writer = writer_guard;
        defer writer.unlock();
        if (key_mode_flags == 0 and app_cursor and mod == VTERM_MOD_NONE and action == .press) {
            const seq = switch (key) {
                VTERM_KEY_UP => "\x1bOA",
                VTERM_KEY_DOWN => "\x1bOB",
                VTERM_KEY_RIGHT => "\x1bOC",
                VTERM_KEY_LEFT => "\x1bOD",
                VTERM_KEY_HOME => "\x1bOH",
                VTERM_KEY_END => "\x1bOF",
                else => "",
            };
            if (seq.len > 0) {
                if (isNavigationKey(key)) {
                    log.logf(.debug, "sendKey path=app_cursor seq_len={d}", .{seq.len});
                }
                _ = try writer.write(seq);
                return;
            }
        }
        if (isNavigationKey(key)) {
            log.logf(.debug, "sendKey path=encoded", .{});
        }
        _ = try writer.sendKeyAction(key, mod, key_mode_flags, action);
    }
}

pub fn sendKeyActionWithMetadata(
    self: anytype,
    key: Key,
    mod: Modifier,
    action: input_mod.KeyAction,
    alternate_meta: ?types.KeyboardAlternateMetadata,
) !void {
    if (action == .repeat and !self.input_snapshot.auto_repeat.load(.acquire)) return;
    const log = app_logger.logger("terminal.input");
    const input_snapshot = self.input_snapshot;
    const key_mode_flags = input_snapshot.key_mode_flags.load(.acquire);
    const app_cursor = input_snapshot.app_cursor_keys.load(.acquire);
    if (isNavigationKey(key)) {
        log.logf(.debug, "sendKey(meta) key={s} code={d} mod=0x{x} action={s} app_cursor={any} key_mode=0x{x} alt_meta={any}", .{
            keyName(key),
            key,
            mod,
            @tagName(action),
            app_cursor,
            key_mode_flags,
            alternate_meta != null,
        });
    }
    if (self.lockPtyWriter()) |writer_guard| {
        var writer = writer_guard;
        defer writer.unlock();
        if (key_mode_flags == 0 and app_cursor and mod == VTERM_MOD_NONE and action == .press) {
            const seq = switch (key) {
                VTERM_KEY_UP => "\x1bOA",
                VTERM_KEY_DOWN => "\x1bOB",
                VTERM_KEY_RIGHT => "\x1bOC",
                VTERM_KEY_LEFT => "\x1bOD",
                VTERM_KEY_HOME => "\x1bOH",
                VTERM_KEY_END => "\x1bOF",
                else => "",
            };
            if (seq.len > 0) {
                if (isNavigationKey(key)) {
                    log.logf(.debug, "sendKey(meta) path=app_cursor seq_len={d}", .{seq.len});
                }
                _ = try writer.write(seq);
                return;
            }
        }
        if (isNavigationKey(key)) {
            log.logf(.debug, "sendKey(meta) path=encoded", .{});
        }
        _ = try writer.sendKeyActionEvent(.{
            .key = key,
            .mod = mod,
            .key_mode_flags = key_mode_flags,
            .action = action,
            .protocol = .{ .alternate = alternate_meta },
        });
    }
}

pub fn sendKeypad(self: anytype, key: input_mod.KeypadKey, mod: Modifier) !void {
    try sendKeypadAction(self, key, mod, input_mod.KeyAction.press);
}

pub fn sendKeypadAction(self: anytype, key: input_mod.KeypadKey, mod: Modifier, action: input_mod.KeyAction) !void {
    if (action == .repeat and !self.input_snapshot.auto_repeat.load(.acquire)) return;
    const log = app_logger.logger("terminal.input");
    const input_snapshot = self.input_snapshot;
    const key_mode_flags = input_snapshot.key_mode_flags.load(.acquire);
    const app_keypad = input_snapshot.app_keypad.load(.acquire);
    log.logf(.debug, "sendKeypad key={s} mod=0x{x} action={s} app_keypad={any} key_mode=0x{x}", .{
        keypadKeyName(key),
        mod,
        @tagName(action),
        app_keypad,
        key_mode_flags,
    });
    if (self.lockPtyWriter()) |writer_guard| {
        var writer = writer_guard;
        defer writer.unlock();
        if (action == .press) {
            _ = try writer.sendKeypad(key, mod, app_keypad, key_mode_flags);
        }
    }
}

pub fn appKeypadEnabled(self: anytype) bool {
    return input_modes.appKeypadEnabled(self);
}

pub fn appCursorKeysEnabled(self: anytype) bool {
    return self.input_snapshot.app_cursor_keys.load(.acquire);
}

pub fn sendChar(self: anytype, char: u32, mod: Modifier) !void {
    try sendCharAction(self, char, mod, input_mod.KeyAction.press);
}

pub fn sendCharAction(self: anytype, char: u32, mod: Modifier, action: input_mod.KeyAction) !void {
    if (action == .repeat and !self.input_snapshot.auto_repeat.load(.acquire)) return;
    const log = app_logger.logger("terminal.input");
    const input_snapshot = self.input_snapshot;
    const key_mode_flags = input_snapshot.key_mode_flags.load(.acquire);
    log.logf(.debug, "sendChar cp={d} mod=0x{x} action={s} key_mode=0x{x}", .{
        char,
        mod,
        @tagName(action),
        key_mode_flags,
    });
    if (self.lockPtyWriter()) |writer_guard| {
        var writer = writer_guard;
        defer writer.unlock();
        _ = try writer.sendCharAction(char, mod, key_mode_flags, action);
    } else {
        echoCharLocallyIfEnabled(self, char, mod, action);
    }
}

pub fn sendCharActionWithMetadata(
    self: anytype,
    char: u32,
    mod: Modifier,
    action: input_mod.KeyAction,
    alternate_meta: ?types.KeyboardAlternateMetadata,
) !void {
    if (action == .repeat and !self.input_snapshot.auto_repeat.load(.acquire)) return;
    const log = app_logger.logger("terminal.input");
    const input_snapshot = self.input_snapshot;
    const key_mode_flags = input_snapshot.key_mode_flags.load(.acquire);
    log.logf(.debug, "sendChar(meta) cp={d} mod=0x{x} action={s} key_mode=0x{x} alt_meta={any}", .{
        char,
        mod,
        @tagName(action),
        key_mode_flags,
        alternate_meta != null,
    });
    if (self.lockPtyWriter()) |writer_guard| {
        var writer = writer_guard;
        defer writer.unlock();
        _ = try writer.sendCharActionEvent(.{
            .codepoint = char,
            .mod = mod,
            .key_mode_flags = key_mode_flags,
            .action = action,
            .protocol = .{ .alternate = alternate_meta },
        });
    } else {
        echoCharLocallyIfEnabled(self, char, mod, action);
    }
}

pub fn reportMouseEvent(self: anytype, event: MouseEvent) !bool {
    if (self.pty == null) return false;
    const screen = self.activeScreen();
    if (self.lockPtyWriter()) |writer_guard| {
        var writer = writer_guard;
        defer writer.unlock();
        return writer.reportMouseEvent(&self.input, event, screen.grid.rows, screen.grid.cols);
    }
    return false;
}

pub fn reportAlternateScrollWheel(self: anytype, wheel_steps: i32, mod: Modifier) !bool {
    if (wheel_steps == 0) return false;
    if (!self.input_snapshot.mouse_alternate_scroll.load(.acquire)) return false;
    if (!self.input_snapshot.alt_active.load(.acquire)) return false;
    var remaining = wheel_steps;
    while (remaining != 0) {
        const key: Key = if (remaining > 0) VTERM_KEY_UP else VTERM_KEY_DOWN;
        try sendKeyAction(self, key, mod, input_mod.KeyAction.press);
        remaining += if (remaining > 0) -1 else 1;
    }
    return true;
}

pub fn sendText(self: anytype, text: []const u8) !void {
    if (text.len == 0) return;
    const log = app_logger.logger("terminal.input");
    log.logf(.debug, "sendText len={d}", .{text.len});
    if (self.lockPtyWriter()) |writer_guard| {
        var writer = writer_guard;
        defer writer.unlock();
        try writer.sendText(text);
    }
}

pub fn sendBytes(self: anytype, bytes: []const u8) !void {
    if (bytes.len == 0) return;
    if (self.lockPtyWriter()) |writer_guard| {
        var writer = writer_guard;
        defer writer.unlock();
        _ = try writer.write(bytes);
    }
}

pub fn reportFocusChanged(self: anytype, focused: bool) !bool {
    const log = app_logger.logger("terminal.input");
    if (!self.focusReportingEnabled()) {
        log.logf(.debug, "focus report skipped focused={d} reason=disabled", .{@intFromBool(focused)});
        return false;
    }
    if (self.lockPtyWriter()) |writer_guard| {
        var writer = writer_guard;
        defer writer.unlock();
        _ = try writer.write(if (focused) "\x1b[I" else "\x1b[O");
        return true;
    }
    log.logf(.warning, "focus report dropped focused={d} reason=missing-pty", .{@intFromBool(focused)});
    return false;
}

pub fn reportColorSchemeChanged(self: anytype, dark: bool) !bool {
    const log = app_logger.logger("terminal.input");
    self.color_scheme_dark = dark;
    if (!self.report_color_scheme_2031) {
        log.logf(.debug, "color-scheme report skipped dark={d} reason=disabled", .{@intFromBool(dark)});
        return false;
    }
    if (self.lockPtyWriter()) |writer_guard| {
        var writer = writer_guard;
        var buf: [16]u8 = undefined;
        const seq = try std.fmt.bufPrint(&buf, "\x1b[?997;{d}n", .{if (dark) @as(u8, 1) else @as(u8, 2)});
        defer writer.unlock();
        _ = try writer.write(seq);
        return true;
    }
    log.logf(.warning, "color-scheme report dropped dark={d} reason=missing-pty", .{@intFromBool(dark)});
    return false;
}

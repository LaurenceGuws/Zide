const std = @import("std");
const input_modes = @import("input_modes.zig");
const terminal_transport = @import("terminal_transport.zig");
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
    if (action == .repeat and !self.interaction.input_snapshot.auto_repeat.load(.acquire)) return;
    const input_snapshot = self.interaction.input_snapshot;
    const key_mode_flags = input_snapshot.key_mode_flags.load(.acquire);
    const app_cursor = input_snapshot.app_cursor_keys.load(.acquire);
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
                _ = try writer.write(seq);
                return;
            }
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
    if (action == .repeat and !self.interaction.input_snapshot.auto_repeat.load(.acquire)) return;
    const input_snapshot = self.interaction.input_snapshot;
    const key_mode_flags = input_snapshot.key_mode_flags.load(.acquire);
    const app_cursor = input_snapshot.app_cursor_keys.load(.acquire);
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
                _ = try writer.write(seq);
                return;
            }
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
    if (action == .repeat and !self.interaction.input_snapshot.auto_repeat.load(.acquire)) return;
    const input_snapshot = self.interaction.input_snapshot;
    const key_mode_flags = input_snapshot.key_mode_flags.load(.acquire);
    const app_keypad = input_snapshot.app_keypad.load(.acquire);
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
    return self.interaction.input_snapshot.app_cursor_keys.load(.acquire);
}

pub fn sendChar(self: anytype, char: u32, mod: Modifier) !void {
    try sendCharAction(self, char, mod, input_mod.KeyAction.press);
}

pub fn sendCharAction(self: anytype, char: u32, mod: Modifier, action: input_mod.KeyAction) !void {
    if (action == .repeat and !self.interaction.input_snapshot.auto_repeat.load(.acquire)) return;
    const input_snapshot = self.interaction.input_snapshot;
    const key_mode_flags = input_snapshot.key_mode_flags.load(.acquire);
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
    if (action == .repeat and !self.interaction.input_snapshot.auto_repeat.load(.acquire)) return;
    const input_snapshot = self.interaction.input_snapshot;
    const key_mode_flags = input_snapshot.key_mode_flags.load(.acquire);
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
    if (!terminal_transport.Writer.exists(self)) return false;
    const screen = self.activeScreen();
    if (self.lockPtyWriter()) |writer_guard| {
        var writer = writer_guard;
        defer writer.unlock();
        return writer.reportMouseEvent(&self.interaction.input, event, screen.grid.rows, screen.grid.cols);
    }
    return false;
}

pub fn reportAlternateScrollWheel(self: anytype, wheel_steps: i32, mod: Modifier) !bool {
    if (wheel_steps == 0) return false;
    if (!self.interaction.input_snapshot.mouse_alternate_scroll.load(.acquire)) return false;
    if (!self.interaction.input_snapshot.alt_active.load(.acquire)) return false;
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
    if (!self.focusReportingEnabled()) {
        return false;
    }
    if (self.lockPtyWriter()) |writer_guard| {
        var writer = writer_guard;
        defer writer.unlock();
        _ = try writer.write(if (focused) "\x1b[I" else "\x1b[O");
        return true;
    }
    std.log.warn("focus report dropped focused={} reason=missing-pty", .{@intFromBool(focused)});
    return false;
}

pub fn reportColorSchemeChanged(self: anytype, dark: bool) !bool {
    self.interaction.color_scheme_dark = dark;
    if (!self.interaction.report_color_scheme_2031) {
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
    std.log.warn("color-scheme report dropped dark={} reason=missing-pty", .{@intFromBool(dark)});
    return false;
}

const std = @import("std");
const input_modes = @import("../input_modes.zig");
const terminal_core_text = @import("../protocol/terminal_core_text.zig");
const terminal_transport = @import("../runtime/terminal_transport.zig");
const session_interaction = @import("interaction.zig");
const input_mod = @import("../../input/input.zig");
const types = @import("../../model/types.zig");

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

const KeyActionContext = struct {
    key_mode_flags: u32,
    dispatch: @import("../terminal_core.zig").TerminalCore.KeyActionDispatch,
};

fn echoCharLocallyIfEnabled(self: anytype, char: u32, mod: Modifier, action: input_mod.KeyAction) void {
    if (action == .release) return;
    if (mod != VTERM_MOD_NONE) return;
    if (char < 0x20 or char == 0x7F) return;
    if (char > 0x10FFFF or (char >= 0xD800 and char <= 0xDFFF)) return;
    const screen = self.core.activeScreen();
    if (!screen.local_echo_mode_12) return;
    terminal_core_text.handleCodepoint(self, char);
}

pub fn sendKey(self: anytype, key: Key, mod: Modifier) !void {
    try sendKeyAction(self, key, mod, input_mod.KeyAction.press);
}

fn keyActionContext(self: anytype, key: Key, mod: Modifier, action: input_mod.KeyAction) KeyActionContext {
    const input_snapshot = self.session.interaction.input_snapshot;
    const key_mode_flags = input_snapshot.key_mode_flags.load(.acquire);
    return .{
        .key_mode_flags = key_mode_flags,
        .dispatch = self.core.decideKeyAction(
            key,
            mod,
            action,
            input_snapshot.auto_repeat.load(.acquire),
            input_snapshot.app_cursor_keys.load(.acquire),
            key_mode_flags,
        ),
    };
}

pub fn sendKeyAction(self: anytype, key: Key, mod: Modifier, action: input_mod.KeyAction) !void {
    const context = keyActionContext(self, key, mod, action);
    if (context.dispatch == .suppress) return;
    if (self.lockPtyWriter()) |writer_guard| {
        var writer = writer_guard;
        defer writer.unlock();
        if (context.dispatch == .app_cursor) {
            if (self.core.appCursorSequence(key)) |seq| {
                _ = try writer.write(seq);
                return;
            }
        }
        _ = try writer.sendKeyAction(key, mod, context.key_mode_flags, action);
    }
}

pub fn sendKeyActionWithMetadata(
    self: anytype,
    key: Key,
    mod: Modifier,
    action: input_mod.KeyAction,
    alternate_meta: ?types.KeyboardAlternateMetadata,
) !void {
    const context = keyActionContext(self, key, mod, action);
    if (context.dispatch == .suppress) return;
    if (self.lockPtyWriter()) |writer_guard| {
        var writer = writer_guard;
        defer writer.unlock();
        if (context.dispatch == .app_cursor) {
            if (self.core.appCursorSequence(key)) |seq| {
                _ = try writer.write(seq);
                return;
            }
        }
        _ = try writer.sendKeyActionEvent(.{
            .key = key,
            .mod = mod,
            .key_mode_flags = context.key_mode_flags,
            .action = action,
            .protocol = .{ .alternate = alternate_meta },
        });
    }
}

pub fn sendKeypad(self: anytype, key: input_mod.KeypadKey, mod: Modifier) !void {
    try sendKeypadAction(self, key, mod, input_mod.KeyAction.press);
}

pub fn sendKeypadAction(self: anytype, key: input_mod.KeypadKey, mod: Modifier, action: input_mod.KeyAction) !void {
    if (action == .repeat and !self.session.interaction.input_snapshot.auto_repeat.load(.acquire)) return;
    const input_snapshot = self.session.interaction.input_snapshot;
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
    return self.session.interaction.input_snapshot.app_cursor_keys.load(.acquire);
}

pub fn sendChar(self: anytype, char: u32, mod: Modifier) !void {
    try sendCharAction(self, char, mod, input_mod.KeyAction.press);
}

pub fn sendCharAction(self: anytype, char: u32, mod: Modifier, action: input_mod.KeyAction) !void {
    if (action == .repeat and !self.session.interaction.input_snapshot.auto_repeat.load(.acquire)) return;
    const input_snapshot = self.session.interaction.input_snapshot;
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
    if (action == .repeat and !self.session.interaction.input_snapshot.auto_repeat.load(.acquire)) return;
    const input_snapshot = self.session.interaction.input_snapshot;
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
    const screen = self.core.activeScreen();
    if (self.lockPtyWriter()) |writer_guard| {
        var writer = writer_guard;
        defer writer.unlock();
        return writer.reportMouseEvent(&self.session.interaction.input, event, screen.grid.rows, screen.grid.cols);
    }
    return false;
}

pub fn reportAlternateScrollWheel(self: anytype, wheel_steps: i32, mod: Modifier) !bool {
    if (wheel_steps == 0) return false;
    if (!self.session.interaction.input_snapshot.mouse_alternate_scroll.load(.acquire)) return false;
    if (!self.session.interaction.input_snapshot.alt_active.load(.acquire)) return false;
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
    if (!session_interaction.focusReportingEnabled(self)) {
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
    self.session.interaction.color_scheme_dark = dark;
    if (!self.session.interaction.report_color_scheme_2031) {
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

test "key action uses app cursor fallback sequence from core dispatch" {
    const session_runtime = @import("runtime.zig");

    const allocator = std.testing.allocator;
    var session = try @import("terminal_runtime_shell.zig").TerminalRuntimeShell.init(allocator, 2, 2);
    defer session.deinit();

    session_runtime.attachExternalTransport(session);
    @import("../input_modes.zig").setAppCursorKeys(session, true);

    try sendKeyAction(session, VTERM_KEY_UP, VTERM_MOD_NONE, .press);

    const bytes = (try session_runtime.takeExternalOutgoingBytes(session, allocator)).?;
    defer allocator.free(bytes);
    try std.testing.expectEqualStrings("\x1bOA", bytes);
}

test "key action repeat suppression comes from core dispatch" {
    const session_runtime = @import("runtime.zig");

    const allocator = std.testing.allocator;
    var session = try @import("terminal_runtime_shell.zig").TerminalRuntimeShell.init(allocator, 2, 2);
    defer session.deinit();

    session_runtime.attachExternalTransport(session);
    @import("../input_modes.zig").setAutoRepeat(session, false);

    try sendKeyAction(session, VTERM_KEY_UP, VTERM_MOD_NONE, .repeat);

    const bytes = (try session_runtime.takeExternalOutgoingBytes(session, allocator)).?;
    defer allocator.free(bytes);
    try std.testing.expectEqual(@as(usize, 0), bytes.len);
}

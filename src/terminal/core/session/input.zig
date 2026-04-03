const std = @import("std");
const input_modes = @import("../input_modes.zig");
const terminal_core_text = @import("../protocol/terminal_core_text.zig");
const terminal_transport = @import("../runtime/terminal_transport.zig");
const host_reporting = @import("host_reporting.zig");
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

const KeypadActionContext = struct {
    key_mode_flags: u32,
    dispatch: @import("../terminal_core.zig").TerminalCore.KeypadActionDispatch,
};

const CharActionContext = struct {
    key_mode_flags: u32,
    dispatch: @import("../terminal_core.zig").TerminalCore.CharActionDispatch,
};

fn echoCharLocallyIfEligible(self: anytype, char: u32, eligible: bool) void {
    if (!eligible) return;
    terminal_core_text.handleCodepoint(self, char);
}

pub fn sendKey(self: anytype, key: Key, mod: Modifier) !void {
    try sendKeyAction(self, key, mod, input_mod.KeyAction.press);
}

fn keyActionContext(self: anytype, key: Key, mod: Modifier, action: input_mod.KeyAction) KeyActionContext {
    const input_snapshot = self.session.interaction.derived_snapshot.input;
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

fn keypadActionContext(self: anytype, action: input_mod.KeyAction) KeypadActionContext {
    const input_snapshot = self.session.interaction.derived_snapshot.input;
    const key_mode_flags = input_snapshot.key_mode_flags.load(.acquire);
    return .{
        .key_mode_flags = key_mode_flags,
        .dispatch = self.core.decideKeypadAction(
            action,
            input_snapshot.auto_repeat.load(.acquire),
            input_snapshot.app_keypad.load(.acquire),
        ),
    };
}

pub fn sendKeypadAction(self: anytype, key: input_mod.KeypadKey, mod: Modifier, action: input_mod.KeyAction) !void {
    const context = keypadActionContext(self, action);
    if (context.dispatch.suppress) return;
    if (self.lockPtyWriter()) |writer_guard| {
        var writer = writer_guard;
        defer writer.unlock();
        if (context.dispatch.emit) {
            _ = try writer.sendKeypad(key, mod, context.dispatch.app_keypad, context.key_mode_flags);
        }
    }
}

pub fn appKeypadEnabled(self: anytype) bool {
    return input_modes.appKeypadEnabled(self);
}

pub fn appCursorKeysEnabled(self: anytype) bool {
    return self.session.interaction.derived_snapshot.input.app_cursor_keys.load(.acquire);
}

pub fn sendChar(self: anytype, char: u32, mod: Modifier) !void {
    try sendCharAction(self, char, mod, input_mod.KeyAction.press);
}

fn charActionContext(self: anytype, char: u32, mod: Modifier, action: input_mod.KeyAction) CharActionContext {
    const input_snapshot = self.session.interaction.derived_snapshot.input;
    const key_mode_flags = input_snapshot.key_mode_flags.load(.acquire);
    return .{
        .key_mode_flags = key_mode_flags,
        .dispatch = self.core.decideCharAction(
            char,
            mod,
            action,
            input_snapshot.auto_repeat.load(.acquire),
            self.core.activeScreen().local_echo_mode_12,
        ),
    };
}

pub fn sendCharAction(self: anytype, char: u32, mod: Modifier, action: input_mod.KeyAction) !void {
    const context = charActionContext(self, char, mod, action);
    if (context.dispatch.suppress) return;
    if (self.lockPtyWriter()) |writer_guard| {
        var writer = writer_guard;
        defer writer.unlock();
        _ = try writer.sendCharAction(char, mod, context.key_mode_flags, action);
    } else {
        echoCharLocallyIfEligible(self, char, context.dispatch.local_echo_eligible);
    }
}

pub fn sendCharActionWithMetadata(
    self: anytype,
    char: u32,
    mod: Modifier,
    action: input_mod.KeyAction,
    alternate_meta: ?types.KeyboardAlternateMetadata,
) !void {
    const context = charActionContext(self, char, mod, action);
    if (context.dispatch.suppress) return;
    if (self.lockPtyWriter()) |writer_guard| {
        var writer = writer_guard;
        defer writer.unlock();
        _ = try writer.sendCharActionEvent(.{
            .codepoint = char,
            .mod = mod,
            .key_mode_flags = context.key_mode_flags,
            .action = action,
            .protocol = .{ .alternate = alternate_meta },
        });
    } else {
        echoCharLocallyIfEligible(self, char, context.dispatch.local_echo_eligible);
    }
}

pub fn reportMouseEvent(self: anytype, event: MouseEvent) !bool {
    if (!terminal_transport.Writer.exists(self)) return false;
    const screen = self.core.activeScreen();
    if (self.lockPtyWriter()) |writer_guard| {
        var writer = writer_guard;
        defer writer.unlock();
        return writer.reportMouseEvent(&self.session.interaction.protocol_modes.input, event, screen.grid.rows, screen.grid.cols);
    }
    return false;
}

pub fn reportAlternateScrollWheel(self: anytype, wheel_steps: i32, mod: Modifier) !bool {
    const input_snapshot = self.session.interaction.derived_snapshot.input;
    var remaining = wheel_steps;
    while (remaining != 0) {
        const dispatch = self.core.decideAlternateScrollStep(
            remaining,
            input_snapshot.mouse_alternate_scroll.load(.acquire),
            input_snapshot.alt_active.load(.acquire),
        );
        if (!dispatch.active) return false;
        try sendKeyAction(self, dispatch.key.?, mod, input_mod.KeyAction.press);
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
    return try host_reporting.reportColorSchemeChanged(self, dark);
}

test "key action uses app cursor fallback sequence from core dispatch" {
    const session_runtime = @import("runtime.zig");

    const allocator = std.testing.allocator;
    var session = try @import("../terminal_runtime.zig").init(allocator, 2, 2);
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
    var session = try @import("../terminal_runtime.zig").init(allocator, 2, 2);
    defer session.deinit();

    session_runtime.attachExternalTransport(session);
    @import("../input_modes.zig").setAutoRepeat(session, false);

    try sendKeyAction(session, VTERM_KEY_UP, VTERM_MOD_NONE, .repeat);

    const bytes = (try session_runtime.takeExternalOutgoingBytes(session, allocator)).?;
    defer allocator.free(bytes);
    try std.testing.expectEqual(@as(usize, 0), bytes.len);
}

test "keypad action uses app keypad mode from core dispatch" {
    const session_runtime = @import("runtime.zig");

    const allocator = std.testing.allocator;
    var session = try @import("../terminal_runtime.zig").init(allocator, 2, 2);
    defer session.deinit();

    session_runtime.attachExternalTransport(session);
    @import("../input_modes.zig").setKeypadMode(session, true);

    try sendKeypadAction(session, input_mod.KeypadKey.kp1, VTERM_MOD_NONE, .press);

    const bytes = (try session_runtime.takeExternalOutgoingBytes(session, allocator)).?;
    defer allocator.free(bytes);
    try std.testing.expectEqualStrings("\x1bOq", bytes);
}

test "keypad repeat suppression comes from core dispatch" {
    const session_runtime = @import("runtime.zig");

    const allocator = std.testing.allocator;
    var session = try @import("../terminal_runtime.zig").init(allocator, 2, 2);
    defer session.deinit();

    session_runtime.attachExternalTransport(session);
    @import("../input_modes.zig").setAutoRepeat(session, false);

    try sendKeypadAction(session, input_mod.KeypadKey.kp1, VTERM_MOD_NONE, .repeat);

    const bytes = (try session_runtime.takeExternalOutgoingBytes(session, allocator)).?;
    defer allocator.free(bytes);
    try std.testing.expectEqual(@as(usize, 0), bytes.len);
}

test "alternate scroll mapping comes from core dispatch" {
    const session_runtime = @import("runtime.zig");

    const allocator = std.testing.allocator;
    var session = try @import("../terminal_runtime.zig").init(allocator, 2, 2);
    defer session.deinit();

    session_runtime.attachExternalTransport(session);
    @import("../input_modes.zig").setAppCursorKeys(session, true);
    terminal_core_text.handleCodepoint(session, 'x');
    session.core.active = .alt;
    @import("../input_modes.zig").publishSnapshot(session);

    try std.testing.expect(try reportAlternateScrollWheel(session, 1, VTERM_MOD_NONE));

    const bytes = (try session_runtime.takeExternalOutgoingBytes(session, allocator)).?;
    defer allocator.free(bytes);
    try std.testing.expectEqualStrings("\x1bOA", bytes);
}

test "char local echo eligibility comes from core dispatch" {
    const allocator = std.testing.allocator;
    var session = try @import("../terminal_runtime.zig").init(allocator, 2, 2);
    defer session.deinit();

    session.core.activeScreen().setLocalEchoMode12(true);

    try sendCharAction(session, 'x', VTERM_MOD_NONE, .press);

    try std.testing.expectEqual(@as(u32, 'x'), session.core.activeScreenConst().grid.cells.items[0].codepoint);
}

test "char repeat suppression comes from core dispatch" {
    const allocator = std.testing.allocator;
    var session = try @import("../terminal_runtime.zig").init(allocator, 2, 2);
    defer session.deinit();

    session.core.activeScreen().setLocalEchoMode12(true);
    @import("../input_modes.zig").setAutoRepeat(session, false);

    try sendCharAction(session, 'x', VTERM_MOD_NONE, .repeat);

    try std.testing.expectEqual(@as(u32, 0), session.core.activeScreenConst().grid.cells.items[0].codepoint);
}

const input_mod = @import("../../input/input.zig");
const types = @import("../../model/types.zig");
const session_input = @import("input.zig");

pub fn sendKey(self: anytype, key: types.Key, mod: types.Modifier) !void {
    try session_input.sendKey(self, key, mod);
}

pub fn sendKeyAction(
    self: anytype,
    key: types.Key,
    mod: types.Modifier,
    action: input_mod.KeyAction,
) !void {
    try session_input.sendKeyAction(self, key, mod, action);
}

pub fn sendKeyActionWithMetadata(
    self: anytype,
    key: types.Key,
    mod: types.Modifier,
    action: input_mod.KeyAction,
    alternate_meta: ?types.KeyboardAlternateMetadata,
) !void {
    try session_input.sendKeyActionWithMetadata(self, key, mod, action, alternate_meta);
}

pub fn sendKeypad(
    self: anytype,
    key: input_mod.KeypadKey,
    mod: types.Modifier,
) !void {
    try session_input.sendKeypad(self, key, mod);
}

pub fn sendKeypadAction(
    self: anytype,
    key: input_mod.KeypadKey,
    mod: types.Modifier,
    action: input_mod.KeyAction,
) !void {
    try session_input.sendKeypadAction(self, key, mod, action);
}

pub fn appKeypadEnabled(self: anytype) bool {
    return session_input.appKeypadEnabled(self);
}

pub fn appCursorKeysEnabled(self: anytype) bool {
    return session_input.appCursorKeysEnabled(self);
}

pub fn sendChar(self: anytype, char: u32, mod: types.Modifier) !void {
    try session_input.sendChar(self, char, mod);
}

pub fn sendCharAction(
    self: anytype,
    char: u32,
    mod: types.Modifier,
    action: input_mod.KeyAction,
) !void {
    try session_input.sendCharAction(self, char, mod, action);
}

pub fn sendCharActionWithMetadata(
    self: anytype,
    char: u32,
    mod: types.Modifier,
    action: input_mod.KeyAction,
    alternate_meta: ?types.KeyboardAlternateMetadata,
) !void {
    try session_input.sendCharActionWithMetadata(self, char, mod, action, alternate_meta);
}

pub fn reportMouseEvent(self: anytype, event: types.MouseEvent) !bool {
    return session_input.reportMouseEvent(self, event);
}

pub fn reportAlternateScrollWheel(self: anytype, wheel_steps: i32, mod: types.Modifier) !bool {
    return session_input.reportAlternateScrollWheel(self, wheel_steps, mod);
}

pub fn sendText(self: anytype, text: []const u8) !void {
    try session_input.sendText(self, text);
}

pub fn sendBytes(self: anytype, bytes: []const u8) !void {
    try session_input.sendBytes(self, bytes);
}

pub fn reportFocusChanged(self: anytype, focused: bool) !bool {
    return session_input.reportFocusChanged(self, focused);
}

pub fn reportColorSchemeChanged(self: anytype, dark: bool) !bool {
    return session_input.reportColorSchemeChanged(self, dark);
}

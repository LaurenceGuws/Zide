const mode_effects = @import("../session/mode_effects.zig");
const terminal_core_modes = @import("../terminal_core_modes.zig");

pub fn applyAnsiTerminalMode(self: anytype, mode: i32, enabled: bool) bool {
    switch (mode) {
        4 => self.core.activeScreen().*.setInsertMode(enabled),
        12 => self.core.activeScreen().*.setLocalEchoMode12(enabled),
        20 => self.core.activeScreen().*.setNewlineMode(enabled),
        else => return false,
    }
    return true;
}

pub fn applyPrivateTerminalMode(self: anytype, mode: i32, enabled: bool) bool {
    switch (mode) {
        5 => self.core.activeScreen().*.setScreenReverse(enabled),
        6 => self.core.activeScreen().*.setOriginMode(enabled),
        7 => self.core.activeScreen().*.setAutowrap(enabled),
        12 => self.core.activeScreen().*.setCursorBlink(enabled),
        25 => self.core.activeScreen().setCursorVisible(enabled),
        45 => self.core.activeScreen().*.setReverseWrap(enabled),
        47 => if (enabled) mode_effects.enterAltScreen(self, false, false) else mode_effects.exitAltScreen(self, false),
        69 => self.core.activeScreen().*.setLeftRightMarginMode69(enabled),
        1047 => if (enabled) mode_effects.enterAltScreen(self, true, false) else mode_effects.exitAltScreen(self, false),
        1048 => {
            if (enabled) {
                terminal_core_modes.saveCursor(self);
            } else {
                terminal_core_modes.restoreCursor(self);
            }
            self.core.activeScreen().*.setSaveCursorMode1048(enabled);
        },
        1049 => if (enabled) mode_effects.enterAltScreen(self, true, true) else mode_effects.exitAltScreen(self, true),
        else => return false,
    }
    return true;
}

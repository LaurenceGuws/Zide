const input_modes = @import("../input_modes.zig");
const terminal_core_modes = @import("../terminal_core_modes.zig");
const terminal_core_protocol = @import("terminal_core_protocol.zig");
const mode_effects = @import("../session/mode_effects.zig");

pub fn handleEscSemanticEffect(self: anytype, byte: u8) bool {
    switch (byte) {
        'c' => {
            mode_effects.resetStateLocked(self);
            return true;
        },
        '7' => {
            terminal_core_modes.saveCursor(self);
            return true;
        },
        '8' => {
            terminal_core_modes.restoreCursor(self);
            return true;
        },
        'H' => {
            terminal_core_protocol.setTabAtCursor(self);
            return true;
        },
        'M' => { // RI
            terminal_core_protocol.reverseIndex(self);
            return true;
        },
        '=' => {
            input_modes.setKeypadModeLocked(self, true);
            return true;
        },
        '>' => {
            input_modes.setKeypadModeLocked(self, false);
            return true;
        },
        else => return false,
    }
}

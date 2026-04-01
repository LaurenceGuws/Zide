pub fn handleControl(self: anytype, byte: u8) void {
    const screen = self.activeScreen();
    switch (byte) {
        0x08 => { // BS
            screen.backspace();
        },
        0x09 => { // TAB (every 8 columns)
            screen.tab();
        },
        0x0A => { // LF
            @import("terminal_core_protocol.zig").newline(self);
        },
        0x0D => { // CR
            screen.carriageReturn();
        },
        0x0E => { // SO (Shift Out) -> G1
            self.core.shiftOutCharset();
        },
        0x0F => { // SI (Shift In) -> G0
            self.core.shiftInCharset();
        },
        0x1B => { // ESC
            self.core.enterEscapeState();
        },
        else => {},
    }
}

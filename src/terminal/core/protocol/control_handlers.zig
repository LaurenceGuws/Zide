pub fn handleControl(self: anytype, byte: u8) void {
    switch (byte) {
        0x08 => { // BS
            self.core.backspaceLocked();
        },
        0x09 => { // TAB (every 8 columns)
            self.core.tabLocked();
        },
        0x0A => { // LF
            @import("terminal_core_protocol.zig").newline(self);
        },
        0x0D => { // CR
            self.core.carriageReturnLocked();
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

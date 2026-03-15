const scrolling_mod = @import("scrolling.zig");
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
            newline(self);
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

pub fn newline(self: anytype) void {
    const screen = self.activeScreen();
    switch (screen.newlineAction()) {
        .moved => {},
        .scroll_region => self.scrollRegionUpWithOrigin(1, "control.lf.scroll_region"),
        .scroll_full => scrolling_mod.scrollUp(self),
    }
}

pub fn wrapNewline(self: anytype) void {
    const screen = self.activeScreen();
    switch (screen.wrapNewlineAction()) {
        .moved => {},
        .scroll_region => self.scrollRegionUpWithOrigin(1, "control.wrap_newline.scroll_region"),
        .scroll_full => scrolling_mod.scrollUp(self),
    }
}

pub fn reverseIndex(self: anytype) void {
    const screen = self.activeScreen();
    if (screen.cursor.row > screen.scroll_top) {
        screen.cursorUp(1);
        return;
    }
    if (screen.cursor.row == screen.scroll_top) {
        self.scrollRegionDown(1);
    }
}

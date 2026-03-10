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
            self.core.parser.gl_charset = self.core.parser.g1_charset;
        },
        0x0F => { // SI (Shift In) -> G0
            self.core.parser.gl_charset = self.core.parser.g0_charset;
        },
        0x1B => { // ESC
            self.core.parser.esc_state = .esc;
            self.core.parser.stream.reset();
            self.core.parser.csi.reset();
            self.core.parser.osc_state = .idle;
            self.core.parser.apc_state = .idle;
            self.core.parser.dcs_state = .idle;
        },
        else => {},
    }
}

pub fn newline(self: anytype) void {
    const screen = self.activeScreen();
    switch (screen.newlineAction()) {
        .moved => {},
        .scroll_region => self.scrollRegionUp(1),
        .scroll_full => scrolling_mod.scrollUp(self),
    }
}

pub fn wrapNewline(self: anytype) void {
    const screen = self.activeScreen();
    switch (screen.wrapNewlineAction()) {
        .moved => {},
        .scroll_region => self.scrollRegionUp(1),
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

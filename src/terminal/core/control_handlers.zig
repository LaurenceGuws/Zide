const app_logger = @import("../../app_logger.zig");
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
            const log = app_logger.logger("terminal.trace.control");
            if (log.enabled_file or log.enabled_console) {
                log.logf("control=LF row={d} col={d}", .{ screen.cursor.row, screen.cursor.col });
            }
        },
        0x0D => { // CR
            screen.carriageReturn();
            const log = app_logger.logger("terminal.trace.control");
            if (log.enabled_file or log.enabled_console) {
                log.logf("control=CR row={d} col={d}", .{ screen.cursor.row, screen.cursor.col });
            }
        },
        0x0E => { // SO (Shift Out) -> G1
            self.parser.gl_charset = self.parser.g1_charset;
        },
        0x0F => { // SI (Shift In) -> G0
            self.parser.gl_charset = self.parser.g0_charset;
        },
        0x1B => { // ESC
            self.parser.esc_state = .esc;
            self.parser.stream.reset();
            self.parser.csi.reset();
            self.parser.osc_state = .idle;
            self.parser.apc_state = .idle;
            self.parser.dcs_state = .idle;
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

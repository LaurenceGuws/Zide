const app_logger = @import("../../app_logger.zig");
const screen_mod = @import("../model/screen.zig");
const csi_mod = @import("../parser/csi.zig");
const protocol_csi = @import("../protocol/csi.zig");
const protocol_dcs_apc = @import("../protocol/dcs_apc.zig");
const protocol_osc = @import("../protocol/osc.zig");
const kitty_mod = @import("../kitty/graphics.zig");
const parser_mod = @import("../parser/parser.zig");

const OscTerminator = parser_mod.OscTerminator;

pub fn parseDcs(self: anytype, payload: []const u8) void {
    protocol_dcs_apc.parseDcs(self, payload);
}

pub fn parseApc(self: anytype, payload: []const u8) void {
    protocol_dcs_apc.parseApc(self, payload);
}

pub fn parseOsc(self: anytype, payload: []const u8, terminator: OscTerminator) void {
    protocol_osc.parseOsc(self, payload, terminator);
}

pub fn parseKittyGraphics(self: anytype, payload: []const u8) void {
    kitty_mod.parseKittyGraphics(self, payload);
}

pub fn handleCsi(self: anytype, action: csi_mod.CsiAction) void {
    protocol_csi.handleCsi(self, action);
}

pub fn handleCodepoint(self: anytype, codepoint: u32) void {
    if (codepoint == 0) return;
    if (codepoint > 0x10FFFF or (codepoint >= 0xD800 and codepoint <= 0xDFFF)) return;

    var cp = codepoint;
    if (self.parser.gl_charset == .dec_special) {
        cp = screen_mod.mapDecSpecial(codepoint);
    }

    const screen = self.activeScreen();
    const rows = @as(usize, screen.grid.rows);
    const cols = @as(usize, screen.grid.cols);
    if (rows == 0 or cols == 0) return;
    if (screen.cursor.row >= rows) return;
    while (true) {
        switch (screen.prepareWrite()) {
            .done => return,
            .need_wrap => self.wrapNewline(),
            .proceed => break,
        }
    }

    // A width-2 glyph at the last column should wrap before writing instead of being
    // forced into a single cell.
    if (screen.auto_wrap and cols > 1) {
        const cp_width = screen_mod.Screen.codepointCellWidth(cp);
        const right = screen.writeRightBoundary();
        const cpw: usize = cp_width;
        if (cp_width > 1 and screen.cursor.col + cpw > right + 1) {
            self.wrapNewline();
            while (true) {
                switch (screen.prepareWrite()) {
                    .done => return,
                    .need_wrap => self.wrapNewline(),
                    .proceed => break,
                }
            }
        }
    }

    var attrs = screen.current_attrs;
    if (self.osc_hyperlink_active and self.current_hyperlink_id > 0) {
        attrs.link_id = self.current_hyperlink_id;
        attrs.underline = true;
    } else {
        attrs.link_id = 0;
    }
    if (cp == 0x2502) {
        const log = app_logger.logger("terminal.trace.scope");
        if (log.enabled_file or log.enabled_console) {
            log.logf(.info, 
                "scope_glyph row={d} col={d} origin={any} scroll_top={d} scroll_bottom={d}",
                .{ screen.cursor.row, screen.cursor.col, screen.origin_mode, screen.scroll_top, screen.scroll_bottom },
            );
        }
    }
    const cp_width = screen_mod.Screen.codepointCellWidth(cp);
    if (screen.insert_mode and cp_width > 0) {
        self.insertChars(@intCast(cp_width));
    }
    screen.writeCodepoint(cp, attrs);
}

pub fn handleAsciiSlice(self: anytype, bytes: []const u8) void {
    if (bytes.len == 0) return;
    const screen = self.activeScreen();
    const rows = @as(usize, screen.grid.rows);
    const cols = @as(usize, screen.grid.cols);
    if (rows == 0 or cols == 0) return;
    if (screen.cursor.row >= rows) return;

    var attrs = screen.current_attrs;
    if (self.osc_hyperlink_active and self.current_hyperlink_id > 0) {
        attrs.link_id = self.current_hyperlink_id;
        attrs.underline = true;
    } else {
        attrs.link_id = 0;
    }
    const use_dec_special = self.parser.gl_charset == .dec_special;

    if (screen.insert_mode) {
        for (bytes) |b| {
            while (true) {
                switch (screen.prepareWrite()) {
                    .done => return,
                    .need_wrap => {
                        self.wrapNewline();
                        continue;
                    },
                    .proceed => break,
                }
            }
            self.insertChars(1);
            screen.writeCodepoint(@intCast(b), attrs);
        }
        return;
    }

    var i: usize = 0;
    while (i < bytes.len) {
        switch (screen.prepareWrite()) {
            .done => break,
            .need_wrap => {
                self.wrapNewline();
                continue;
            },
            .proceed => {},
        }

        const run_len = screen.writeAsciiRun(bytes[i..], attrs, use_dec_special);
        if (run_len == 0) break;
        i += run_len;
    }
}

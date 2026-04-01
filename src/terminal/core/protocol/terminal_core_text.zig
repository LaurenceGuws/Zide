const screen_mod = @import("../../model/screen.zig");
const terminal_core_mod = @import("../terminal_core.zig");
const terminal_core_protocol = @import("terminal_core_protocol.zig");
const parser_mod = @import("../../parser/parser.zig");
const types = @import("../../model/types.zig");

pub fn handleCodepoint(self: anytype, codepoint: u32) void {
    if (codepoint == 0) return;
    if (codepoint > 0x10FFFF or (codepoint >= 0xD800 and codepoint <= 0xDFFF)) return;

    var cp = codepoint;
    if (self.core.glCharset() == .dec_special) {
        cp = screen_mod.mapDecSpecial(codepoint);
    }

    const screen = self.core.activeScreen();
    const rows = @as(usize, screen.grid.rows);
    const cols = @as(usize, screen.grid.cols);
    if (rows == 0 or cols == 0) return;
    if (screen.cursor.row >= rows) return;
    while (true) {
        switch (screen.prepareWrite()) {
            .done => return,
            .need_wrap => terminal_core_protocol.wrapNewline(self),
            .proceed => break,
        }
    }

    if (screen.auto_wrap and cols > 1) {
        const cp_width = screen_mod.Screen.codepointCellWidth(cp);
        const right = screen.writeRightBoundary();
        const cpw: usize = cp_width;
        if (cp_width > 1 and screen.cursor.col + cpw > right + 1) {
            terminal_core_protocol.wrapNewline(self);
            while (true) {
                switch (screen.prepareWrite()) {
                    .done => return,
                    .need_wrap => terminal_core_protocol.wrapNewline(self),
                    .proceed => break,
                }
            }
        }
    }

    var attrs = screen.current_attrs;
    self.core.applyHyperlinkAttrs(&attrs);
    const cp_width = screen_mod.Screen.codepointCellWidth(cp);
    if (screen.insert_mode and cp_width > 0) {
        terminal_core_protocol.insertChars(self, @intCast(cp_width));
    }
    screen.writeCodepoint(cp, attrs);
}

pub fn handleAsciiSlice(self: anytype, bytes: []const u8) void {
    if (bytes.len == 0) return;
    const screen = self.core.activeScreen();
    const rows = @as(usize, screen.grid.rows);
    const cols = @as(usize, screen.grid.cols);
    if (rows == 0 or cols == 0) return;
    if (screen.cursor.row >= rows) return;

    var attrs = screen.current_attrs;
    self.core.applyHyperlinkAttrs(&attrs);
    const use_dec_special = self.core.glCharset() == .dec_special;

    if (screen.insert_mode) {
        for (bytes) |b| {
            while (true) {
                switch (screen.prepareWrite()) {
                    .done => return,
                    .need_wrap => {
                        terminal_core_protocol.wrapNewline(self);
                        continue;
                    },
                    .proceed => break,
                }
            }
            terminal_core_protocol.insertChars(self, 1);
            screen.writeCodepoint(@intCast(b), attrs);
        }
        return;
    }

    var i: usize = 0;
    while (i < bytes.len) {
        switch (screen.prepareWrite()) {
            .done => break,
            .need_wrap => {
                terminal_core_protocol.wrapNewline(self);
                continue;
            },
            .proceed => {},
        }

        const ascii_origin = if (use_dec_special)
            "core.ascii_run.dec_special"
        else
            "core.ascii_run";
        const run_len = screen.writeAsciiRun(bytes[i..], attrs, use_dec_special, ascii_origin);
        if (run_len == 0) break;
        i += run_len;
    }
}

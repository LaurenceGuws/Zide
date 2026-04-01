const screen_mod = @import("../../model/screen.zig");
const terminal_core_mod = @import("../terminal_core.zig");
const terminal_core_protocol = @import("terminal_core_protocol.zig");
const parser_mod = @import("../../parser/parser.zig");
const types = @import("../../model/types.zig");

pub const TextContext = struct {
    core: *terminal_core_mod.TerminalCore,
    effects: terminal_core_protocol.TextEffects,

    pub fn from(session: anytype) TextContext {
        return .{
            .core = &session.core,
            .effects = terminal_core_protocol.TextEffects.from(session),
        };
    }

    pub fn activeScreen(self: *const TextContext) *screen_mod.Screen {
        return self.core.activeScreen();
    }

    pub fn applyHyperlinkAttrs(self: *const TextContext, attrs: *types.CellAttrs) void {
        self.core.applyHyperlinkAttrs(attrs);
    }

    pub fn glCharset(self: *const TextContext) parser_mod.Charset {
        return self.core.glCharset();
    }

    pub fn wrapNewline(self: *const TextContext) void {
        self.effects.wrapNewline();
    }

    pub fn insertChars(self: *const TextContext, count: usize) void {
        self.effects.insertChars(count);
    }
};

pub fn handleCodepoint(context: TextContext, codepoint: u32) void {
    if (codepoint == 0) return;
    if (codepoint > 0x10FFFF or (codepoint >= 0xD800 and codepoint <= 0xDFFF)) return;

    var cp = codepoint;
    if (context.glCharset() == .dec_special) {
        cp = screen_mod.mapDecSpecial(codepoint);
    }

    const screen = context.activeScreen();
    const rows = @as(usize, screen.grid.rows);
    const cols = @as(usize, screen.grid.cols);
    if (rows == 0 or cols == 0) return;
    if (screen.cursor.row >= rows) return;
    while (true) {
        switch (screen.prepareWrite()) {
            .done => return,
            .need_wrap => context.wrapNewline(),
            .proceed => break,
        }
    }

    if (screen.auto_wrap and cols > 1) {
        const cp_width = screen_mod.Screen.codepointCellWidth(cp);
        const right = screen.writeRightBoundary();
        const cpw: usize = cp_width;
        if (cp_width > 1 and screen.cursor.col + cpw > right + 1) {
            context.wrapNewline();
            while (true) {
                switch (screen.prepareWrite()) {
                    .done => return,
                    .need_wrap => context.wrapNewline(),
                    .proceed => break,
                }
            }
        }
    }

    var attrs = screen.current_attrs;
    context.applyHyperlinkAttrs(&attrs);
    const cp_width = screen_mod.Screen.codepointCellWidth(cp);
    if (screen.insert_mode and cp_width > 0) {
        context.insertChars(@intCast(cp_width));
    }
    screen.writeCodepoint(cp, attrs);
}

pub fn handleAsciiSlice(context: TextContext, bytes: []const u8) void {
    if (bytes.len == 0) return;
    const screen = context.activeScreen();
    const rows = @as(usize, screen.grid.rows);
    const cols = @as(usize, screen.grid.cols);
    if (rows == 0 or cols == 0) return;
    if (screen.cursor.row >= rows) return;

    var attrs = screen.current_attrs;
    context.applyHyperlinkAttrs(&attrs);
    const use_dec_special = context.glCharset() == .dec_special;

    if (screen.insert_mode) {
        for (bytes) |b| {
            while (true) {
                switch (screen.prepareWrite()) {
                    .done => return,
                    .need_wrap => {
                        context.wrapNewline();
                        continue;
                    },
                    .proceed => break,
                }
            }
            context.insertChars(1);
            screen.writeCodepoint(@intCast(b), attrs);
        }
        return;
    }

    var i: usize = 0;
    while (i < bytes.len) {
        switch (screen.prepareWrite()) {
            .done => break,
            .need_wrap => {
                context.wrapNewline();
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

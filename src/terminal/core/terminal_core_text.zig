const screen_mod = @import("../model/screen.zig");
const types = @import("../model/types.zig");
const parser_mod = @import("../parser/parser.zig");

pub const TextContext = struct {
    ctx: *anyopaque,
    active_screen_fn: *const fn (ctx: *anyopaque) *screen_mod.Screen,
    gl_charset_fn: *const fn (ctx: *anyopaque) parser_mod.Charset,
    hyperlink_attrs_fn: *const fn (ctx: *anyopaque, attrs: *types.CellAttrs) void,
    wrap_newline_fn: *const fn (ctx: *anyopaque) void,
    insert_chars_fn: *const fn (ctx: *anyopaque, count: usize) void,

    pub fn from(session: anytype) TextContext {
        const SessionPtr = @TypeOf(session);
        return .{
            .ctx = @ptrCast(session),
            .active_screen_fn = struct {
                fn call(ctx: *anyopaque) *screen_mod.Screen {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return s.activeScreen();
                }
            }.call,
            .gl_charset_fn = struct {
                fn call(ctx: *anyopaque) parser_mod.Charset {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return s.core.parser.gl_charset;
                }
            }.call,
            .hyperlink_attrs_fn = struct {
                fn call(ctx: *anyopaque, attrs: *types.CellAttrs) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    if (s.core.osc_hyperlink_active and s.core.current_hyperlink_id > 0) {
                        attrs.link_id = s.core.current_hyperlink_id;
                        attrs.underline = true;
                    } else {
                        attrs.link_id = 0;
                    }
                }
            }.call,
            .wrap_newline_fn = struct {
                fn call(ctx: *anyopaque) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.wrapNewline();
                }
            }.call,
            .insert_chars_fn = struct {
                fn call(ctx: *anyopaque, count: usize) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.insertChars(count);
                }
            }.call,
        };
    }

    pub fn activeScreen(self: *const TextContext) *screen_mod.Screen {
        return self.active_screen_fn(self.ctx);
    }

    pub fn glCharset(self: *const TextContext) parser_mod.Charset {
        return self.gl_charset_fn(self.ctx);
    }

    pub fn applyHyperlinkAttrs(self: *const TextContext, attrs: *types.CellAttrs) void {
        self.hyperlink_attrs_fn(self.ctx, attrs);
    }

    pub fn wrapNewline(self: *const TextContext) void {
        self.wrap_newline_fn(self.ctx);
    }

    pub fn insertChars(self: *const TextContext, count: usize) void {
        self.insert_chars_fn(self.ctx, count);
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

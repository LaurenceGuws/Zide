const screen_mod = @import("../model/screen.zig");
const types = @import("../model/types.zig");
const csi_mod = @import("../parser/csi.zig");
const protocol_csi = @import("../protocol/csi.zig");
const protocol_dcs_apc = @import("../protocol/dcs_apc.zig");
const protocol_osc = @import("../protocol/osc.zig");
const kitty_mod = @import("../kitty/graphics.zig");
const parser_mod = @import("../parser/parser.zig");

const OscTerminator = parser_mod.OscTerminator;

pub const SessionFacade = struct {
    ctx: *anyopaque,
    parse_dcs_fn: *const fn (ctx: *anyopaque, payload: []const u8) void,
    parse_apc_fn: *const fn (ctx: *anyopaque, payload: []const u8) void,
    parse_osc_fn: *const fn (ctx: *anyopaque, payload: []const u8, terminator: OscTerminator) void,
    parse_kitty_graphics_fn: *const fn (ctx: *anyopaque, payload: []const u8) void,
    handle_csi_fn: *const fn (ctx: *anyopaque, action: csi_mod.CsiAction) void,
    handle_codepoint_fn: *const fn (ctx: *anyopaque, codepoint: u32) void,
    handle_ascii_slice_fn: *const fn (ctx: *anyopaque, bytes: []const u8) void,

    pub fn from(session: anytype) SessionFacade {
        const SessionPtr = @TypeOf(session);
        return .{
            .ctx = @ptrCast(session),
            .parse_dcs_fn = struct {
                fn call(ctx: *anyopaque, payload: []const u8) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    protocol_dcs_apc.parseDcs(protocol_dcs_apc.SessionFacade.from(s), payload);
                }
            }.call,
            .parse_apc_fn = struct {
                fn call(ctx: *anyopaque, payload: []const u8) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    protocol_dcs_apc.parseApc(protocol_dcs_apc.SessionFacade.from(s), payload);
                }
            }.call,
            .parse_osc_fn = struct {
                fn call(ctx: *anyopaque, payload: []const u8, terminator: OscTerminator) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    protocol_osc.parseOsc(protocol_osc.SessionFacade.from(s), payload, terminator);
                }
            }.call,
            .parse_kitty_graphics_fn = struct {
                fn call(ctx: *anyopaque, payload: []const u8) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    kitty_mod.parseKittyGraphics(s, payload);
                }
            }.call,
            .handle_csi_fn = struct {
                fn call(ctx: *anyopaque, action: csi_mod.CsiAction) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    protocol_csi.handleCsi(protocol_csi.SessionFacade.from(s), action);
                }
            }.call,
            .handle_codepoint_fn = struct {
                fn call(ctx: *anyopaque, codepoint: u32) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    handleCodepointOnSession(s, codepoint);
                }
            }.call,
            .handle_ascii_slice_fn = struct {
                fn call(ctx: *anyopaque, bytes: []const u8) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    handleAsciiSliceOnSession(s, bytes);
                }
            }.call,
        };
    }

    pub fn parseDcs(self: *const SessionFacade, payload: []const u8) void {
        self.parse_dcs_fn(self.ctx, payload);
    }

    pub fn parseApc(self: *const SessionFacade, payload: []const u8) void {
        self.parse_apc_fn(self.ctx, payload);
    }

    pub fn parseOsc(self: *const SessionFacade, payload: []const u8, terminator: OscTerminator) void {
        self.parse_osc_fn(self.ctx, payload, terminator);
    }

    pub fn parseKittyGraphics(self: *const SessionFacade, payload: []const u8) void {
        self.parse_kitty_graphics_fn(self.ctx, payload);
    }

    pub fn handleCsi(self: *const SessionFacade, action: csi_mod.CsiAction) void {
        self.handle_csi_fn(self.ctx, action);
    }

    pub fn handleCodepoint(self: *const SessionFacade, codepoint: u32) void {
        self.handle_codepoint_fn(self.ctx, codepoint);
    }

    pub fn handleAsciiSlice(self: *const SessionFacade, bytes: []const u8) void {
        self.handle_ascii_slice_fn(self.ctx, bytes);
    }
};

const TextWriteContext = struct {
    ctx: *anyopaque,
    active_screen_fn: *const fn (ctx: *anyopaque) *screen_mod.Screen,
    gl_charset_fn: *const fn (ctx: *anyopaque) parser_mod.Charset,
    hyperlink_attrs_fn: *const fn (ctx: *anyopaque, attrs: *types.CellAttrs) void,
    wrap_newline_fn: *const fn (ctx: *anyopaque) void,
    insert_chars_fn: *const fn (ctx: *anyopaque, count: usize) void,

    pub fn from(session: anytype) TextWriteContext {
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

    pub fn activeScreen(self: *const TextWriteContext) *screen_mod.Screen {
        return self.active_screen_fn(self.ctx);
    }

    pub fn glCharset(self: *const TextWriteContext) parser_mod.Charset {
        return self.gl_charset_fn(self.ctx);
    }

    pub fn applyHyperlinkAttrs(self: *const TextWriteContext, attrs: *types.CellAttrs) void {
        self.hyperlink_attrs_fn(self.ctx, attrs);
    }

    pub fn wrapNewline(self: *const TextWriteContext) void {
        self.wrap_newline_fn(self.ctx);
    }

    pub fn insertChars(self: *const TextWriteContext, count: usize) void {
        self.insert_chars_fn(self.ctx, count);
    }
};

pub fn parseDcs(session: SessionFacade, payload: []const u8) void {
    session.parseDcs(payload);
}

pub fn parseApc(session: SessionFacade, payload: []const u8) void {
    session.parseApc(payload);
}

pub fn parseOsc(session: SessionFacade, payload: []const u8, terminator: OscTerminator) void {
    session.parseOsc(payload, terminator);
}

pub fn parseKittyGraphics(session: SessionFacade, payload: []const u8) void {
    session.parseKittyGraphics(payload);
}

pub fn handleCsi(session: SessionFacade, action: csi_mod.CsiAction) void {
    session.handleCsi(action);
}

pub fn handleCodepoint(session: SessionFacade, codepoint: u32) void {
    session.handleCodepoint(codepoint);
}

fn handleCodepointOnSession(session: anytype, codepoint: u32) void {
    handleCodepointWithContext(TextWriteContext.from(session), codepoint);
}

fn handleCodepointWithContext(context: TextWriteContext, codepoint: u32) void {
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

    // A width-2 glyph at the last column should wrap before writing instead of being
    // forced into a single cell.
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

pub fn handleAsciiSlice(session: SessionFacade, bytes: []const u8) void {
    session.handleAsciiSlice(bytes);
}

fn handleAsciiSliceOnSession(session: anytype, bytes: []const u8) void {
    handleAsciiSliceWithContext(TextWriteContext.from(session), bytes);
}

fn handleAsciiSliceWithContext(context: TextWriteContext, bytes: []const u8) void {
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

        const run_len = screen.writeAsciiRun(bytes[i..], attrs, use_dec_special);
        if (run_len == 0) break;
        i += run_len;
    }
}

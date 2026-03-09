const screen_mod = @import("../model/screen.zig");
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

fn handleCodepointOnSession(self: anytype, codepoint: u32) void {
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
    const cp_width = screen_mod.Screen.codepointCellWidth(cp);
    if (screen.insert_mode and cp_width > 0) {
        self.insertChars(@intCast(cp_width));
    }
    screen.writeCodepoint(cp, attrs);
}

pub fn handleAsciiSlice(session: SessionFacade, bytes: []const u8) void {
    session.handleAsciiSlice(bytes);
}

fn handleAsciiSliceOnSession(self: anytype, bytes: []const u8) void {
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

const std = @import("std");
const palette_mod = @import("palette.zig");
const osc_semantic = @import("osc_semantic.zig");
const osc_clipboard = @import("osc_clipboard.zig");
const osc_kitty_clipboard = @import("osc_kitty_clipboard.zig");
const osc_cwd = @import("osc_cwd.zig");
const osc_hyperlink = @import("osc_hyperlink.zig");
const osc_title = @import("osc_title.zig");
const parser_mod = @import("../parser/parser.zig");
const app_logger = @import("../../app_logger.zig");

const OscTerminator = parser_mod.OscTerminator;

pub const SessionFacade = struct {
    ctx: *anyopaque,
    set_title_fn: *const fn (ctx: *anyopaque, text: []const u8) void,
    handle_palette_fn: *const fn (ctx: *anyopaque, text: []const u8, terminator: OscTerminator) void,
    handle_dynamic_color_fn: *const fn (ctx: *anyopaque, code: u8, text: []const u8, terminator: OscTerminator) void,
    handle_palette_reset_fn: *const fn (ctx: *anyopaque, text: []const u8) void,
    handle_dynamic_reset_fn: *const fn (ctx: *anyopaque, code: u8) void,
    parse_hyperlink_fn: *const fn (ctx: *anyopaque, text: []const u8) void,
    parse_cwd_fn: *const fn (ctx: *anyopaque, text: []const u8) void,
    parse_clipboard_fn: *const fn (ctx: *anyopaque, text: []const u8, terminator: OscTerminator) void,
    parse_kitty_clipboard_fn: *const fn (ctx: *anyopaque, text: []const u8, terminator: OscTerminator) void,
    parse_semantic_prompt_fn: *const fn (ctx: *anyopaque, text: []const u8) void,
    parse_user_var_fn: *const fn (ctx: *anyopaque, text: []const u8) void,

    pub fn from(session: anytype) SessionFacade {
        const SessionPtr = @TypeOf(session);
        return .{
            .ctx = @ptrCast(session),
            .set_title_fn = struct {
                fn call(ctx: *anyopaque, text: []const u8) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    osc_title.setTitle(osc_title.SessionFacade.from(s), text);
                }
            }.call,
            .handle_palette_fn = struct {
                fn call(ctx: *anyopaque, text: []const u8, terminator: OscTerminator) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    palette_mod.handleOscPalette(s, text, terminator);
                }
            }.call,
            .handle_dynamic_color_fn = struct {
                fn call(ctx: *anyopaque, code: u8, text: []const u8, terminator: OscTerminator) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    palette_mod.handleOscDynamicColor(s, code, text, terminator);
                }
            }.call,
            .handle_palette_reset_fn = struct {
                fn call(ctx: *anyopaque, text: []const u8) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    palette_mod.handleOscPaletteReset(s, text);
                }
            }.call,
            .handle_dynamic_reset_fn = struct {
                fn call(ctx: *anyopaque, code: u8) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    palette_mod.handleOscDynamicReset(s, code);
                }
            }.call,
            .parse_hyperlink_fn = struct {
                fn call(ctx: *anyopaque, text: []const u8) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    osc_hyperlink.parseHyperlink(osc_hyperlink.SessionFacade.from(s), text);
                }
            }.call,
            .parse_cwd_fn = struct {
                fn call(ctx: *anyopaque, text: []const u8) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    osc_cwd.parseCwd(osc_cwd.SessionFacade.from(s), text);
                }
            }.call,
            .parse_clipboard_fn = struct {
                fn call(ctx: *anyopaque, text: []const u8, terminator: OscTerminator) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    osc_clipboard.parseClipboard(osc_clipboard.SessionFacade.from(s), text, terminator);
                }
            }.call,
            .parse_kitty_clipboard_fn = struct {
                fn call(ctx: *anyopaque, text: []const u8, terminator: OscTerminator) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    osc_kitty_clipboard.parseOsc5522(s, text, terminator);
                }
            }.call,
            .parse_semantic_prompt_fn = struct {
                fn call(ctx: *anyopaque, text: []const u8) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    osc_semantic.parseSemanticPrompt(osc_semantic.SessionFacade.from(s), text);
                }
            }.call,
            .parse_user_var_fn = struct {
                fn call(ctx: *anyopaque, text: []const u8) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    osc_semantic.parseUserVar(osc_semantic.SessionFacade.from(s), text);
                }
            }.call,
        };
    }

    pub fn setTitle(self: *const SessionFacade, text: []const u8) void {
        self.set_title_fn(self.ctx, text);
    }

    pub fn handleOscPalette(self: *const SessionFacade, text: []const u8, terminator: OscTerminator) void {
        self.handle_palette_fn(self.ctx, text, terminator);
    }

    pub fn handleOscDynamicColor(self: *const SessionFacade, code: u8, text: []const u8, terminator: OscTerminator) void {
        self.handle_dynamic_color_fn(self.ctx, code, text, terminator);
    }

    pub fn handleOscPaletteReset(self: *const SessionFacade, text: []const u8) void {
        self.handle_palette_reset_fn(self.ctx, text);
    }

    pub fn handleOscDynamicReset(self: *const SessionFacade, code: u8) void {
        self.handle_dynamic_reset_fn(self.ctx, code);
    }

    pub fn parseHyperlink(self: *const SessionFacade, text: []const u8) void {
        self.parse_hyperlink_fn(self.ctx, text);
    }

    pub fn parseCwd(self: *const SessionFacade, text: []const u8) void {
        self.parse_cwd_fn(self.ctx, text);
    }

    pub fn parseClipboard(self: *const SessionFacade, text: []const u8, terminator: OscTerminator) void {
        self.parse_clipboard_fn(self.ctx, text, terminator);
    }

    pub fn parseOsc5522(self: *const SessionFacade, text: []const u8, terminator: OscTerminator) void {
        self.parse_kitty_clipboard_fn(self.ctx, text, terminator);
    }

    pub fn parseSemanticPrompt(self: *const SessionFacade, text: []const u8) void {
        self.parse_semantic_prompt_fn(self.ctx, text);
    }

    pub fn parseUserVar(self: *const SessionFacade, text: []const u8) void {
        self.parse_user_var_fn(self.ctx, text);
    }
};

pub fn parseOsc(session: SessionFacade, payload: []const u8, terminator: OscTerminator) void {
    const log = app_logger.logger("terminal.osc");
    const max_len: usize = 160;
    const slice = if (payload.len > max_len) payload[0..max_len] else payload;
    log.logf(.debug, "osc payload=\"{s}\"", .{slice});
    var i: usize = 0;
    var code: usize = 0;
    var has_code = false;
    while (i < payload.len) : (i += 1) {
        const b = payload[i];
        if (b == ';') {
            has_code = true;
            i += 1;
            break;
        }
        if (b < '0' or b > '9') {
            return;
        }
        code = code * 10 + @as(usize, b - '0');
        has_code = true;
    }
    if (!has_code or i > payload.len) return;
    const text = payload[i..];
    switch (code) {
        0, 2 => {
            session.setTitle(text);
        },
        4 => session.handleOscPalette(text, terminator),
        10...19 => session.handleOscDynamicColor(@intCast(code), text, terminator),
        104 => session.handleOscPaletteReset(text),
        110...119 => session.handleOscDynamicReset(@intCast(code)),
        8 => {
            session.parseHyperlink(text);
        },
        7 => {
            session.parseCwd(text);
        },
        52 => {
            session.parseClipboard(text, terminator);
        },
        5522 => {
            session.parseOsc5522(text, terminator);
        },
        133 => {
            session.parseSemanticPrompt(text);
        },
        1337 => {
            session.parseUserVar(text);
        },
        else => {},
    }
}

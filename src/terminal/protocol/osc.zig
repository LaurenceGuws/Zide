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
    title: osc_title.SessionFacade,
    palette: palette_mod.SessionFacade,
    hyperlink: osc_hyperlink.SessionFacade,
    cwd: osc_cwd.SessionFacade,
    clipboard: osc_clipboard.SessionFacade,
    kitty_clipboard: osc_kitty_clipboard.SessionFacade,
    semantic: osc_semantic.SessionFacade,

    pub fn from(session: anytype) SessionFacade {
        return .{
            .title = osc_title.SessionFacade.from(session),
            .palette = palette_mod.SessionFacade.from(session),
            .hyperlink = osc_hyperlink.SessionFacade.from(session),
            .cwd = osc_cwd.SessionFacade.from(session),
            .clipboard = osc_clipboard.SessionFacade.from(session),
            .kitty_clipboard = osc_kitty_clipboard.SessionFacade.from(session),
            .semantic = osc_semantic.SessionFacade.from(session),
        };
    }

    pub fn setTitle(self: *const SessionFacade, text: []const u8) void {
        osc_title.setTitle(self.title, text);
    }

    pub fn handleOscPalette(self: *const SessionFacade, text: []const u8, terminator: OscTerminator) void {
        palette_mod.handleOscPalette(self.palette, text, terminator);
    }

    pub fn handleOscDynamicColor(self: *const SessionFacade, code: u8, text: []const u8, terminator: OscTerminator) void {
        palette_mod.handleOscDynamicColor(self.palette, code, text, terminator);
    }

    pub fn handleOscPaletteReset(self: *const SessionFacade, text: []const u8) void {
        palette_mod.handleOscPaletteReset(self.palette, text);
    }

    pub fn handleOscDynamicReset(self: *const SessionFacade, code: u8) void {
        palette_mod.handleOscDynamicReset(self.palette, code);
    }

    pub fn parseHyperlink(self: *const SessionFacade, text: []const u8) void {
        osc_hyperlink.parseHyperlink(self.hyperlink, text);
    }

    pub fn parseCwd(self: *const SessionFacade, text: []const u8) void {
        osc_cwd.parseCwd(self.cwd, text);
    }

    pub fn parseClipboard(self: *const SessionFacade, text: []const u8, terminator: OscTerminator) void {
        osc_clipboard.parseClipboard(self.clipboard, text, terminator);
    }

    pub fn parseOsc5522(self: *const SessionFacade, text: []const u8, terminator: OscTerminator) void {
        osc_kitty_clipboard.parseOsc5522(self.kitty_clipboard, text, terminator);
    }

    pub fn parseSemanticPrompt(self: *const SessionFacade, text: []const u8) void {
        osc_semantic.parseSemanticPrompt(self.semantic, text);
    }

    pub fn parseUserVar(self: *const SessionFacade, text: []const u8) void {
        osc_semantic.parseUserVar(self.semantic, text);
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

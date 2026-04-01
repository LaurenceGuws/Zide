const std = @import("std");
const palette_mod = @import("palette.zig");
const osc_semantic = @import("osc_semantic.zig");
const osc_clipboard = @import("osc_clipboard.zig");
const osc_kitty_clipboard = @import("osc_kitty_clipboard.zig");
const osc_cwd = @import("osc_cwd.zig");
const osc_hyperlink = @import("osc_hyperlink.zig");
const osc_progress = @import("osc_progress.zig");
const osc_title = @import("osc_title.zig");
const parser_mod = @import("../parser/parser.zig");
const app_logger = @import("../../app_logger.zig");

const OscTerminator = parser_mod.OscTerminator;

pub fn parseOsc(self: anytype, payload: []const u8, terminator: OscTerminator) void {
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
            osc_title.setTitle(osc_title.SessionFacade.from(self), text);
        },
        4 => palette_mod.handleOscPalette(palette_mod.SessionFacade.from(self), text, terminator),
        10...19 => palette_mod.handleOscDynamicColor(palette_mod.SessionFacade.from(self), @intCast(code), text, terminator),
        104 => palette_mod.handleOscPaletteReset(palette_mod.SessionFacade.from(self), text),
        110...119 => palette_mod.handleOscDynamicReset(palette_mod.SessionFacade.from(self), @intCast(code)),
        8 => {
            osc_hyperlink.parseHyperlink(osc_hyperlink.SessionFacade.from(self), text);
        },
        7 => {
            osc_cwd.parseCwd(osc_cwd.SessionFacade.from(self), text);
        },
        9 => {
            osc_progress.parseProgress(osc_progress.SessionFacade.from(self), text);
        },
        52 => {
            osc_clipboard.parseClipboard(osc_clipboard.SessionFacade.from(self), text, terminator);
        },
        5522 => {
            osc_kitty_clipboard.parseOsc5522(osc_kitty_clipboard.SessionFacade.from(self), text, terminator);
        },
        133 => {
            osc_semantic.parseSemanticPrompt(osc_semantic.SessionFacade.from(self), text);
        },
        1337 => {
            osc_semantic.parseUserVar(osc_semantic.SessionFacade.from(self), text);
        },
        else => {},
    }
}

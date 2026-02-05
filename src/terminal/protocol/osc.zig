const std = @import("std");
const palette_mod = @import("../core/palette.zig");
const osc_semantic = @import("../core/osc_semantic.zig");
const osc_clipboard = @import("../core/osc_clipboard.zig");
const osc_cwd = @import("../core/osc_cwd.zig");
const osc_hyperlink = @import("../core/osc_hyperlink.zig");
const parser_mod = @import("../parser/parser.zig");
const app_logger = @import("../../app_logger.zig");

const OscTerminator = parser_mod.OscTerminator;

pub fn parseOsc(self: anytype, payload: []const u8, terminator: OscTerminator) void {
    const log = app_logger.logger("terminal.osc");
    if (log.enabled_file or log.enabled_console) {
        const max_len: usize = 160;
        const slice = if (payload.len > max_len) payload[0..max_len] else payload;
        log.logf("osc payload=\"{s}\"", .{slice});
    }
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
            setTitle(self, text);
        },
        4 => palette_mod.handleOscPalette(self, text, terminator),
        10...19 => palette_mod.handleOscDynamicColor(self, @intCast(code), text, terminator),
        104 => palette_mod.handleOscPaletteReset(self, text),
        110...119 => palette_mod.handleOscDynamicReset(self, @intCast(code)),
        8 => {
            osc_hyperlink.parseHyperlink(self, text);
        },
        7 => {
            osc_cwd.parseCwd(self, text);
        },
        52 => {
            osc_clipboard.parseClipboard(self, text, terminator);
        },
        133 => {
            osc_semantic.parseSemanticPrompt(self, text);
        },
        1337 => {
            osc_semantic.parseUserVar(self, text);
        },
        else => {},
    }
}

fn setTitle(self: anytype, text: []const u8) void {
    self.title_buffer.clearRetainingCapacity();
    const max_len: usize = 256;
    const slice = if (text.len > max_len) text[0..max_len] else text;
    _ = self.title_buffer.appendSlice(self.allocator, slice) catch return;
    self.title = self.title_buffer.items;
}

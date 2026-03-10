const csi_mod = @import("../parser/csi.zig");
const parser_mod = @import("../parser/parser.zig");
const parser_hooks = @import("parser_hooks.zig");
const control_handlers = @import("control_handlers.zig");

pub fn handleControl(self: anytype, byte: u8) void {
    control_handlers.handleControl(self, byte);
}

pub fn parseDcs(self: anytype, payload: []const u8) void {
    parser_hooks.parseDcs(parser_hooks.SessionFacade.from(self), payload);
}

pub fn parseApc(self: anytype, payload: []const u8) void {
    parser_hooks.parseApc(parser_hooks.SessionFacade.from(self), payload);
}

pub fn parseOsc(self: anytype, payload: []const u8, terminator: parser_mod.OscTerminator) void {
    parser_hooks.parseOsc(parser_hooks.SessionFacade.from(self), payload, terminator);
}

pub fn handleCsi(self: anytype, action: csi_mod.CsiAction) void {
    parser_hooks.handleCsi(parser_hooks.SessionFacade.from(self), action);
}

pub fn handleCodepoint(self: anytype, codepoint: u32) void {
    parser_hooks.handleCodepoint(parser_hooks.SessionFacade.from(self), codepoint);
}

pub fn handleAsciiSlice(self: anytype, bytes: []const u8) void {
    parser_hooks.handleAsciiSlice(parser_hooks.SessionFacade.from(self), bytes);
}

pub fn newline(self: anytype) void {
    control_handlers.newline(self);
}

pub fn wrapNewline(self: anytype) void {
    control_handlers.wrapNewline(self);
}

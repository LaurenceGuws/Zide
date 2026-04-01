const csi_mod = @import("../../parser/csi.zig");
const protocol_csi = @import("../../protocol/csi.zig");
const protocol_dcs_apc = @import("../../protocol/dcs_apc.zig");
const protocol_osc = @import("../../protocol/osc.zig");
const kitty_mod = @import("../../kitty/graphics.zig");
const parser_mod = @import("../../parser/parser.zig");

const OscTerminator = parser_mod.OscTerminator;

pub const SessionFacade = struct {
    ctx: *anyopaque,
    parse_dcs_fn: *const fn (ctx: *anyopaque, payload: []const u8) void,
    parse_apc_fn: *const fn (ctx: *anyopaque, payload: []const u8) void,
    parse_osc_fn: *const fn (ctx: *anyopaque, payload: []const u8, terminator: OscTerminator) void,
    parse_kitty_graphics_fn: *const fn (ctx: *anyopaque, payload: []const u8) void,
    handle_csi_fn: *const fn (ctx: *anyopaque, action: csi_mod.CsiAction) void,

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

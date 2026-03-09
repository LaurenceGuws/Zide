const std = @import("std");
const stream_mod = @import("stream.zig");
const csi_mod = @import("csi.zig");
const app_logger = @import("../../app_logger.zig");

pub const Parser = struct {
    allocator: std.mem.Allocator,
    stream: stream_mod.Stream,
    esc_state: EscState,
    csi: csi_mod.CsiParser,
    osc_state: OscState,
    osc_terminator: OscTerminator,
    osc_buffer: std.ArrayList(u8),
    apc_state: ApcState,
    apc_buffer: std.ArrayList(u8),
    dcs_state: DcsState,
    dcs_buffer: std.ArrayList(u8),
    g0_charset: Charset,
    g1_charset: Charset,
    gl_charset: Charset,
    charset_target: CharsetTarget,

    pub fn init(allocator: std.mem.Allocator) Parser {
        return .{
            .allocator = allocator,
            .stream = .{},
            .esc_state = .ground,
            .csi = .{},
            .osc_state = .idle,
            .osc_terminator = .st,
            .osc_buffer = .empty,
            .apc_state = .idle,
            .apc_buffer = .empty,
            .dcs_state = .idle,
            .dcs_buffer = .empty,
            .g0_charset = .ascii,
            .g1_charset = .ascii,
            .gl_charset = .ascii,
            .charset_target = .g0,
        };
    }

    pub fn deinit(self: *Parser) void {
        self.osc_buffer.deinit(self.allocator);
        self.apc_buffer.deinit(self.allocator);
        self.dcs_buffer.deinit(self.allocator);
    }

    pub fn reset(self: *Parser) void {
        self.stream.reset();
        self.csi.reset();
        self.esc_state = .ground;
        self.osc_state = .idle;
        self.osc_terminator = .st;
        self.apc_state = .idle;
        self.dcs_state = .idle;
        self.g0_charset = .ascii;
        self.g1_charset = .ascii;
        self.gl_charset = .ascii;
        self.charset_target = .g0;
        self.osc_buffer.clearRetainingCapacity();
        self.apc_buffer.clearRetainingCapacity();
        self.dcs_buffer.clearRetainingCapacity();
    }

    pub const SessionFacade = struct {
        ctx: *anyopaque,
        handle_codepoint_fn: *const fn (ctx: *anyopaque, codepoint: u32) void,
        handle_control_fn: *const fn (ctx: *anyopaque, byte: u8) void,
        reset_state_locked_fn: *const fn (ctx: *anyopaque) void,
        save_cursor_fn: *const fn (ctx: *anyopaque) void,
        restore_cursor_fn: *const fn (ctx: *anyopaque) void,
        set_tab_at_cursor_fn: *const fn (ctx: *anyopaque) void,
        reverse_index_fn: *const fn (ctx: *anyopaque) void,
        set_keypad_mode_locked_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
        handle_csi_fn: *const fn (ctx: *anyopaque, action: csi_mod.CsiAction) void,
        handle_ascii_slice_fn: *const fn (ctx: *anyopaque, bytes: []const u8) void,
        parse_osc_fn: *const fn (ctx: *anyopaque, payload: []const u8, terminator: OscTerminator) void,
        parse_apc_fn: *const fn (ctx: *anyopaque, payload: []const u8) void,
        parse_dcs_fn: *const fn (ctx: *anyopaque, payload: []const u8) void,

        pub fn from(session: anytype) SessionFacade {
            const SessionPtr = @TypeOf(session);
            return .{
                .ctx = @ptrCast(session),
                .handle_codepoint_fn = struct {
                    fn call(ctx: *anyopaque, codepoint: u32) void {
                        const s: SessionPtr = @ptrCast(@alignCast(ctx));
                        s.handleCodepoint(codepoint);
                    }
                }.call,
                .handle_control_fn = struct {
                    fn call(ctx: *anyopaque, byte: u8) void {
                        const s: SessionPtr = @ptrCast(@alignCast(ctx));
                        s.handleControl(byte);
                    }
                }.call,
                .reset_state_locked_fn = struct {
                    fn call(ctx: *anyopaque) void {
                        const s: SessionPtr = @ptrCast(@alignCast(ctx));
                        s.resetStateLocked();
                    }
                }.call,
                .save_cursor_fn = struct {
                    fn call(ctx: *anyopaque) void {
                        const s: SessionPtr = @ptrCast(@alignCast(ctx));
                        s.saveCursor();
                    }
                }.call,
                .restore_cursor_fn = struct {
                    fn call(ctx: *anyopaque) void {
                        const s: SessionPtr = @ptrCast(@alignCast(ctx));
                        s.restoreCursor();
                    }
                }.call,
                .set_tab_at_cursor_fn = struct {
                    fn call(ctx: *anyopaque) void {
                        const s: SessionPtr = @ptrCast(@alignCast(ctx));
                        s.setTabAtCursor();
                    }
                }.call,
                .reverse_index_fn = struct {
                    fn call(ctx: *anyopaque) void {
                        const s: SessionPtr = @ptrCast(@alignCast(ctx));
                        s.reverseIndex();
                    }
                }.call,
                .set_keypad_mode_locked_fn = struct {
                    fn call(ctx: *anyopaque, enabled: bool) void {
                        const s: SessionPtr = @ptrCast(@alignCast(ctx));
                        s.setKeypadModeLocked(enabled);
                    }
                }.call,
                .handle_csi_fn = struct {
                    fn call(ctx: *anyopaque, action: csi_mod.CsiAction) void {
                        const s: SessionPtr = @ptrCast(@alignCast(ctx));
                        s.handleCsi(action);
                    }
                }.call,
                .handle_ascii_slice_fn = struct {
                    fn call(ctx: *anyopaque, bytes: []const u8) void {
                        const s: SessionPtr = @ptrCast(@alignCast(ctx));
                        s.handleAsciiSlice(bytes);
                    }
                }.call,
                .parse_osc_fn = struct {
                    fn call(ctx: *anyopaque, payload: []const u8, terminator: OscTerminator) void {
                        const s: SessionPtr = @ptrCast(@alignCast(ctx));
                        s.parseOsc(payload, terminator);
                    }
                }.call,
                .parse_apc_fn = struct {
                    fn call(ctx: *anyopaque, payload: []const u8) void {
                        const s: SessionPtr = @ptrCast(@alignCast(ctx));
                        s.parseApc(payload);
                    }
                }.call,
                .parse_dcs_fn = struct {
                    fn call(ctx: *anyopaque, payload: []const u8) void {
                        const s: SessionPtr = @ptrCast(@alignCast(ctx));
                        s.parseDcs(payload);
                    }
                }.call,
            };
        }

        pub fn handleCodepoint(self: *const SessionFacade, codepoint: u32) void {
            self.handle_codepoint_fn(self.ctx, codepoint);
        }

        pub fn handleControl(self: *const SessionFacade, byte: u8) void {
            self.handle_control_fn(self.ctx, byte);
        }

        pub fn resetStateLocked(self: *const SessionFacade) void {
            self.reset_state_locked_fn(self.ctx);
        }

        pub fn saveCursor(self: *const SessionFacade) void {
            self.save_cursor_fn(self.ctx);
        }

        pub fn restoreCursor(self: *const SessionFacade) void {
            self.restore_cursor_fn(self.ctx);
        }

        pub fn setTabAtCursor(self: *const SessionFacade) void {
            self.set_tab_at_cursor_fn(self.ctx);
        }

        pub fn reverseIndex(self: *const SessionFacade) void {
            self.reverse_index_fn(self.ctx);
        }

        pub fn setKeypadModeLocked(self: *const SessionFacade, enabled: bool) void {
            self.set_keypad_mode_locked_fn(self.ctx, enabled);
        }

        pub fn handleCsi(self: *const SessionFacade, action: csi_mod.CsiAction) void {
            self.handle_csi_fn(self.ctx, action);
        }

        pub fn handleAsciiSlice(self: *const SessionFacade, bytes: []const u8) void {
            self.handle_ascii_slice_fn(self.ctx, bytes);
        }

        pub fn parseOsc(self: *const SessionFacade, payload: []const u8, terminator: OscTerminator) void {
            self.parse_osc_fn(self.ctx, payload, terminator);
        }

        pub fn parseApc(self: *const SessionFacade, payload: []const u8) void {
            self.parse_apc_fn(self.ctx, payload);
        }

        pub fn parseDcs(self: *const SessionFacade, payload: []const u8) void {
            self.parse_dcs_fn(self.ctx, payload);
        }
    };

    pub fn handleByte(self: *Parser, session: SessionFacade, byte: u8) void {
        if (self.osc_state != .idle) {
            self.handleOscByte(session, byte);
            return;
        }
        if (self.apc_state != .idle) {
            self.handleApcByte(session, byte);
            return;
        }
        if (self.dcs_state != .idle) {
            self.handleDcsByte(session, byte);
            return;
        }
        switch (self.esc_state) {
            .ground => {
                if (byte == 0x1B) {
                    self.esc_state = .esc;
                    self.stream.reset();
                    self.csi.reset();
                    self.osc_state = .idle;
                    return;
                }
                if (self.stream.feed(byte)) |event| {
                    switch (event) {
                        .codepoint => |cp| session.handleCodepoint(@intCast(cp)),
                        .control => |c| session.handleControl(c),
                        .invalid => session.handleCodepoint(0xFFFD),
                    }
                }
            },
            .esc => {
                if (byte == '[') {
                    self.esc_state = .csi;
                    self.csi.reset();
                } else if (byte == ']') {
                    self.esc_state = .ground;
                    self.osc_state = .osc;
                    self.osc_buffer.clearRetainingCapacity();
                    return;
                } else if (byte == 'P') {
                    self.esc_state = .ground;
                    self.dcs_state = .dcs;
                    self.dcs_buffer.clearRetainingCapacity();
                    return;
                } else if (byte == '_') { // APC
                    self.esc_state = .ground;
                    self.apc_state = .apc;
                    self.apc_buffer.clearRetainingCapacity();
                    return;
                } else if (byte == '(') {
                    self.charset_target = .g0;
                    self.esc_state = .charset;
                } else if (byte == ')') {
                    self.charset_target = .g1;
                    self.esc_state = .charset;
                } else if (byte == 'c') {
                    session.resetStateLocked();
                    self.esc_state = .ground;
                } else if (byte == '7') {
                    session.saveCursor();
                    self.esc_state = .ground;
                } else if (byte == '8') {
                    session.restoreCursor();
                    self.esc_state = .ground;
                } else if (byte == 'H') {
                    session.setTabAtCursor();
                    self.esc_state = .ground;
                } else if (byte == 'M') { // RI
                    session.reverseIndex();
                    self.esc_state = .ground;
                } else if (byte == '=') {
                    session.setKeypadModeLocked(true);
                    self.esc_state = .ground;
                } else if (byte == '>') {
                    session.setKeypadModeLocked(false);
                    self.esc_state = .ground;
                } else {
                    self.esc_state = .ground;
                }
            },
            .charset => {
                const charset: Charset = switch (byte) {
                    '0' => .dec_special,
                    'B' => .ascii,
                    else => .ascii,
                };
                switch (self.charset_target) {
                    .g0 => self.g0_charset = charset,
                    .g1 => self.g1_charset = charset,
                }
                if (self.charset_target == .g0) {
                    self.gl_charset = self.g0_charset;
                }
                self.esc_state = .ground;
            },
            .csi => {
                if (self.csi.feed(byte)) |action| {
                    session.handleCsi(action);
                    self.esc_state = .ground;
                }
            },
        }
    }

    pub fn handleSlice(self: *Parser, session: SessionFacade, bytes: []const u8) void {
        var i: usize = 0;
        while (i < bytes.len) {
            if (self.osc_state != .idle) {
                self.handleOscByte(session, bytes[i]);
                i += 1;
                continue;
            }
            if (self.apc_state != .idle) {
                self.handleApcByte(session, bytes[i]);
                i += 1;
                continue;
            }
            if (self.dcs_state != .idle) {
                self.handleDcsByte(session, bytes[i]);
                i += 1;
                continue;
            }

            if (self.esc_state == .ground and self.stream.decoder.needed == 0) {
                const start = i;
                while (i < bytes.len) {
                    const b = bytes[i];
                    if (b < 0x20 or b == 0x7f or b == 0x1b or b >= 0x80) break;
                    i += 1;
                }
                if (i > start) {
                    session.handleAsciiSlice(bytes[start..i]);
                    continue;
                }
            }

            self.handleByte(session, bytes[i]);
            i += 1;
        }
    }

    fn handleOscByte(self: *Parser, session: SessionFacade, byte: u8) void {
        switch (self.osc_state) {
            .idle => return,
            .osc => {
                if (byte == 0x07) { // BEL
                    self.osc_terminator = .bel;
                    self.finishOsc(session);
                    return;
                }
                if (byte == 0x1B) { // ESC
                    self.osc_state = .osc_esc;
                    return;
                }
                if (self.osc_buffer.items.len < 4096) {
                    self.osc_buffer.append(self.allocator, byte) catch |err| {
                        app_logger.logger("terminal.parse").logf(.warning, "osc buffer append failed len={d} err={s}", .{ self.osc_buffer.items.len, @errorName(err) });
                    };
                }
            },
            .osc_esc => {
                if (byte == '\\') { // ST
                    self.osc_terminator = .st;
                    self.finishOsc(session);
                    return;
                }
                // Treat stray ESC as ignored and continue.
                self.osc_state = .osc;
                if (self.osc_buffer.items.len < 4096) {
                    self.osc_buffer.append(self.allocator, byte) catch |err| {
                        app_logger.logger("terminal.parse").logf(.warning, "osc buffer append failed len={d} err={s}", .{ self.osc_buffer.items.len, @errorName(err) });
                    };
                }
            },
        }
    }

    fn finishOsc(self: *Parser, session: SessionFacade) void {
        session.parseOsc(self.osc_buffer.items, self.osc_terminator);
        self.osc_buffer.clearRetainingCapacity();
        self.osc_state = .idle;
    }

    fn handleApcByte(self: *Parser, session: SessionFacade, byte: u8) void {
        const apc_max_len: usize = 1024 * 1024;
        switch (self.apc_state) {
            .idle => return,
            .apc => {
                if (byte == 0x07) { // BEL
                    self.finishApc(session);
                    return;
                }
                if (byte == 0x1B) { // ESC
                    self.apc_state = .apc_esc;
                    return;
                }
                if (self.apc_buffer.items.len < apc_max_len) {
                    self.apc_buffer.append(self.allocator, byte) catch |err| {
                        app_logger.logger("terminal.parse").logf(.warning, "apc buffer append failed len={d} err={s}", .{ self.apc_buffer.items.len, @errorName(err) });
                    };
                }
            },
            .apc_esc => {
                if (byte == '\\') { // ST
                    self.finishApc(session);
                    return;
                }
                self.apc_state = .apc;
                if (self.apc_buffer.items.len < apc_max_len) {
                    self.apc_buffer.append(self.allocator, byte) catch |err| {
                        app_logger.logger("terminal.parse").logf(.warning, "apc buffer append failed len={d} err={s}", .{ self.apc_buffer.items.len, @errorName(err) });
                    };
                }
            },
        }
    }

    fn finishApc(self: *Parser, session: SessionFacade) void {
        session.parseApc(self.apc_buffer.items);
        self.apc_buffer.clearRetainingCapacity();
        self.apc_state = .idle;
    }

    fn handleDcsByte(self: *Parser, session: SessionFacade, byte: u8) void {
        switch (self.dcs_state) {
            .idle => return,
            .dcs => {
                if (byte == 0x1B) { // ESC
                    self.dcs_state = .dcs_esc;
                    return;
                }
                if (self.dcs_buffer.items.len < 4096) {
                    self.dcs_buffer.append(self.allocator, byte) catch |err| {
                        app_logger.logger("terminal.parse").logf(.warning, "dcs buffer append failed len={d} err={s}", .{ self.dcs_buffer.items.len, @errorName(err) });
                    };
                }
            },
            .dcs_esc => {
                if (byte == '\\') { // ST
                    self.finishDcs(session);
                    return;
                }
                self.dcs_state = .dcs;
                if (self.dcs_buffer.items.len < 4096) {
                    self.dcs_buffer.append(self.allocator, byte) catch |err| {
                        app_logger.logger("terminal.parse").logf(.warning, "dcs buffer append failed len={d} err={s}", .{ self.dcs_buffer.items.len, @errorName(err) });
                    };
                }
            },
        }
    }

    fn finishDcs(self: *Parser, session: SessionFacade) void {
        session.parseDcs(self.dcs_buffer.items);
        self.dcs_buffer.clearRetainingCapacity();
        self.dcs_state = .idle;
    }
};

pub const EscState = enum {
    ground,
    esc,
    csi,
    charset,
};

pub const OscState = enum {
    idle,
    osc,
    osc_esc,
};

pub const ApcState = enum {
    idle,
    apc,
    apc_esc,
};

pub const OscTerminator = enum {
    bel,
    st,
};

pub const DcsState = enum {
    idle,
    dcs,
    dcs_esc,
};

pub const Charset = enum {
    ascii,
    dec_special,
};

pub const CharsetTarget = enum {
    g0,
    g1,
};

const std = @import("std");
const types = @import("../model/types.zig");
const screen_mod = @import("../model/screen.zig");
const parser_csi = @import("../parser/csi.zig");
const app_logger = @import("../../app_logger.zig");
const csi_reply = @import("csi_reply.zig");
const csi_mode_query = @import("csi_mode_query.zig");
const csi_mode_mutation = @import("csi_mode_mutation.zig");
const csi_style_reset = @import("csi_style_reset.zig");
const csi_exec = @import("csi_exec.zig");

const Color = types.Color;

pub const DecrpmState = enum(u8) {
    not_recognized = 0,
    set = 1,
    reset = 2,
    permanently_set = 3,
    permanently_reset = 4,
};

const ModeSnapshot = csi_mode_query.ModeSnapshot;
const ModeCaptureContext = csi_mode_query.ModeCaptureContext;
const ModeQueryContext = csi_mode_query.ModeQueryContext;
const ModeMutationContext = csi_mode_mutation.ModeMutationContext;

fn modeSnapshotFromContext(ctx: ModeCaptureContext) ModeSnapshot {
    return csi_mode_query.modeSnapshotFromContext(ctx);
}

const SgrContext = csi_style_reset.SgrContext;
const DecstrContext = csi_style_reset.DecstrContext;

pub const SimpleCsiContext = struct {
    ctx: *anyopaque,
    active_screen_fn: *const fn (ctx: *anyopaque) *screen_mod.Screen,
    erase_display_fn: *const fn (ctx: *anyopaque, mode: i32) void,
    erase_line_fn: *const fn (ctx: *anyopaque, mode: i32) void,
    insert_chars_fn: *const fn (ctx: *anyopaque, count: usize) void,
    delete_chars_fn: *const fn (ctx: *anyopaque, count: usize) void,
    erase_chars_fn: *const fn (ctx: *anyopaque, count: usize) void,
    insert_lines_fn: *const fn (ctx: *anyopaque, count: usize) void,
    delete_lines_fn: *const fn (ctx: *anyopaque, count: usize) void,
    scroll_region_up_fn: *const fn (ctx: *anyopaque, count: usize) void,
    scroll_region_up_with_origin_fn: *const fn (ctx: *anyopaque, count: usize, origin: ?[]const u8) void,
    scroll_region_down_fn: *const fn (ctx: *anyopaque, count: usize) void,
    save_cursor_fn: *const fn (ctx: *anyopaque) void,
    restore_cursor_fn: *const fn (ctx: *anyopaque) void,
    set_cursor_style_fn: *const fn (ctx: *anyopaque, mode: i32) void,

    pub fn from(session: anytype) SimpleCsiContext {
        const SessionPtr = @TypeOf(session);
        return .{
            .ctx = @ptrCast(session),
            .active_screen_fn = struct {
                fn call(ctx: *anyopaque) *screen_mod.Screen {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return s.activeScreen();
                }
            }.call,
            .erase_display_fn = struct {
                fn call(ctx: *anyopaque, mode: i32) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.eraseDisplay(mode);
                }
            }.call,
            .erase_line_fn = struct {
                fn call(ctx: *anyopaque, mode: i32) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.eraseLine(mode);
                }
            }.call,
            .insert_chars_fn = struct {
                fn call(ctx: *anyopaque, count: usize) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.insertChars(count);
                }
            }.call,
            .delete_chars_fn = struct {
                fn call(ctx: *anyopaque, count: usize) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.deleteChars(count);
                }
            }.call,
            .erase_chars_fn = struct {
                fn call(ctx: *anyopaque, count: usize) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.eraseChars(count);
                }
            }.call,
            .insert_lines_fn = struct {
                fn call(ctx: *anyopaque, count: usize) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.insertLines(count);
                }
            }.call,
            .delete_lines_fn = struct {
                fn call(ctx: *anyopaque, count: usize) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.deleteLines(count);
                }
            }.call,
            .scroll_region_up_fn = struct {
                fn call(ctx: *anyopaque, count: usize) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.scrollRegionUp(count);
                }
            }.call,
            .scroll_region_up_with_origin_fn = struct {
                fn call(ctx: *anyopaque, count: usize, origin: ?[]const u8) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.scrollRegionUpWithOrigin(count, origin);
                }
            }.call,
            .scroll_region_down_fn = struct {
                fn call(ctx: *anyopaque, count: usize) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.scrollRegionDown(count);
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
            .set_cursor_style_fn = struct {
                fn call(ctx: *anyopaque, mode: i32) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.setCursorStyle(mode);
                }
            }.call,
        };
    }

    pub fn activeScreen(self: *const SimpleCsiContext) *screen_mod.Screen {
        return self.active_screen_fn(self.ctx);
    }
    pub fn eraseDisplay(self: *const SimpleCsiContext, mode: i32) void {
        self.erase_display_fn(self.ctx, mode);
    }
    pub fn eraseLine(self: *const SimpleCsiContext, mode: i32) void {
        self.erase_line_fn(self.ctx, mode);
    }
    pub fn insertChars(self: *const SimpleCsiContext, count: usize) void {
        self.insert_chars_fn(self.ctx, count);
    }
    pub fn deleteChars(self: *const SimpleCsiContext, count: usize) void {
        self.delete_chars_fn(self.ctx, count);
    }
    pub fn eraseChars(self: *const SimpleCsiContext, count: usize) void {
        self.erase_chars_fn(self.ctx, count);
    }
    pub fn insertLines(self: *const SimpleCsiContext, count: usize) void {
        self.insert_lines_fn(self.ctx, count);
    }
    pub fn deleteLines(self: *const SimpleCsiContext, count: usize) void {
        self.delete_lines_fn(self.ctx, count);
    }
    pub fn scrollRegionUp(self: *const SimpleCsiContext, count: usize) void {
        self.scroll_region_up_fn(self.ctx, count);
    }
    pub fn scrollRegionUpWithOrigin(self: *const SimpleCsiContext, count: usize, origin: ?[]const u8) void {
        self.scroll_region_up_with_origin_fn(self.ctx, count, origin);
    }
    pub fn scrollRegionDown(self: *const SimpleCsiContext, count: usize) void {
        self.scroll_region_down_fn(self.ctx, count);
    }
    pub fn saveCursor(self: *const SimpleCsiContext) void {
        self.save_cursor_fn(self.ctx);
    }
    pub fn restoreCursor(self: *const SimpleCsiContext) void {
        self.restore_cursor_fn(self.ctx);
    }
    pub fn setCursorStyle(self: *const SimpleCsiContext, mode: i32) void {
        self.set_cursor_style_fn(self.ctx, mode);
    }
};

pub const SpecialCsiContext = struct {
    ctx: *anyopaque,
    active_screen_fn: *const fn (ctx: *anyopaque) *screen_mod.Screen,
    save_cursor_fn: *const fn (ctx: *anyopaque) void,
    restore_cursor_fn: *const fn (ctx: *anyopaque) void,
    set_cursor_style_fn: *const fn (ctx: *anyopaque, mode: i32) void,
    key_mode_push_locked_fn: *const fn (ctx: *anyopaque, flags: u32) void,
    key_mode_pop_locked_fn: *const fn (ctx: *anyopaque, count: usize) void,
    key_mode_modify_locked_fn: *const fn (ctx: *anyopaque, flags: u32, mode: u32) void,
    key_mode_query_locked_fn: *const fn (ctx: *anyopaque) void,

    pub fn from(session: anytype) SpecialCsiContext {
        const SessionPtr = @TypeOf(session);
        return .{
            .ctx = @ptrCast(session),
            .active_screen_fn = struct {
                fn call(ctx: *anyopaque) *screen_mod.Screen {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return s.activeScreen();
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
            .set_cursor_style_fn = struct {
                fn call(ctx: *anyopaque, mode: i32) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.setCursorStyle(mode);
                }
            }.call,
            .key_mode_push_locked_fn = struct {
                fn call(ctx: *anyopaque, flags: u32) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.keyModePushLocked(flags);
                }
            }.call,
            .key_mode_pop_locked_fn = struct {
                fn call(ctx: *anyopaque, count: usize) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.keyModePopLocked(count);
                }
            }.call,
            .key_mode_modify_locked_fn = struct {
                fn call(ctx: *anyopaque, flags: u32, mode: u32) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.keyModeModifyLocked(flags, mode);
                }
            }.call,
            .key_mode_query_locked_fn = struct {
                fn call(ctx: *anyopaque) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    s.keyModeQueryLocked();
                }
            }.call,
        };
    }

    pub fn activeScreen(self: *const SpecialCsiContext) *screen_mod.Screen {
        return self.active_screen_fn(self.ctx);
    }
    pub fn saveCursor(self: *const SpecialCsiContext) void {
        self.save_cursor_fn(self.ctx);
    }
    pub fn restoreCursor(self: *const SpecialCsiContext) void {
        self.restore_cursor_fn(self.ctx);
    }
    pub fn setCursorStyle(self: *const SpecialCsiContext, mode: i32) void {
        self.set_cursor_style_fn(self.ctx, mode);
    }
    pub fn keyModePushLocked(self: *const SpecialCsiContext, flags: u32) void {
        self.key_mode_push_locked_fn(self.ctx, flags);
    }
    pub fn keyModePopLocked(self: *const SpecialCsiContext, count: usize) void {
        self.key_mode_pop_locked_fn(self.ctx, count);
    }
    pub fn keyModeModifyLocked(self: *const SpecialCsiContext, flags: u32, mode: u32) void {
        self.key_mode_modify_locked_fn(self.ctx, flags, mode);
    }
    pub fn keyModeQueryLocked(self: *const SpecialCsiContext) void {
        self.key_mode_query_locked_fn(self.ctx);
    }
};

const ReplyCsiContext = struct {
    ctx: *anyopaque,
    active_screen_fn: *const fn (ctx: *anyopaque) *screen_mod.Screen,
    handle_dsr_fn: *const fn (ctx: *anyopaque, action: parser_csi.CsiAction, param_len: usize, params: [parser_csi.max_params]i32) void,
    handle_da_fn: *const fn (ctx: *anyopaque, action: parser_csi.CsiAction) void,
    handle_window_op_fn: *const fn (ctx: *anyopaque, action: parser_csi.CsiAction, param_len: usize, params: [parser_csi.max_params]i32) void,
    handle_decrqm_fn: *const fn (ctx: *anyopaque, action: parser_csi.CsiAction, param_len: usize, params: [parser_csi.max_params]i32) void,
    apply_decstr_fn: *const fn (ctx: *anyopaque) void,

    pub fn from(session: anytype) ReplyCsiContext {
        const SessionPtr = @TypeOf(session);
        return .{
            .ctx = @ptrCast(session),
            .active_screen_fn = struct {
                fn call(ctx: *anyopaque) *screen_mod.Screen {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return s.activeScreen();
                }
            }.call,
            .handle_dsr_fn = struct {
                fn call(ctx: *anyopaque, action: parser_csi.CsiAction, param_len: usize, params: [parser_csi.max_params]i32) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    if (s.lockPtyWriter()) |writer_guard| {
                        var writer = writer_guard;
                        defer writer.unlock();
                        handleDsrQuery(QueryContext.from(s), CsiWriter.from(&writer), ScreenQueryContext.from(s.activeScreen()), action, param_len, params);
                    }
                }
            }.call,
            .handle_da_fn = struct {
                fn call(ctx: *anyopaque, action: parser_csi.CsiAction) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    if (!(action.leader == 0 or action.leader == '?')) return;
                    if (s.lockPtyWriter()) |writer_guard| {
                        var writer = writer_guard;
                        defer writer.unlock();
                        handleDaQuery(CsiWriter.from(&writer));
                    }
                }
            }.call,
            .handle_window_op_fn = struct {
                fn call(ctx: *anyopaque, action: parser_csi.CsiAction, param_len: usize, params: [parser_csi.max_params]i32) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    if (action.leader != 0 or action.private) return;
                    if (s.lockPtyWriter()) |writer_guard| {
                        var writer = writer_guard;
                        defer writer.unlock();
                        handleWindowOpQuery(QueryContext.from(s), CsiWriter.from(&writer), ScreenQueryContext.from(s.activeScreen()), param_len, params);
                    }
                }
            }.call,
            .handle_decrqm_fn = struct {
                fn call(ctx: *anyopaque, action: parser_csi.CsiAction, param_len: usize, params: [parser_csi.max_params]i32) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    if (!csiIntermediatesEq(action, "$")) return;
                    if (param_len != 1) return;
                    if (s.lockPtyWriter()) |writer_guard| {
                        var writer = writer_guard;
                        defer writer.unlock();
                        handleDecrqmQuery(CsiWriter.from(&writer), action, params[0], ModeQueryContext.from(s).snapshot());
                    }
                }
            }.call,
            .apply_decstr_fn = struct {
                fn call(ctx: *anyopaque) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    csi_style_reset.applyDecstrReset(DecstrContext.from(s));
                }
            }.call,
        };
    }

    pub fn activeScreen(self: *const ReplyCsiContext) *screen_mod.Screen {
        return self.active_screen_fn(self.ctx);
    }
    pub fn handleDsr(self: *const ReplyCsiContext, action: parser_csi.CsiAction, param_len: usize, params: [parser_csi.max_params]i32) void {
        self.handle_dsr_fn(self.ctx, action, param_len, params);
    }
    pub fn handleDa(self: *const ReplyCsiContext, action: parser_csi.CsiAction) void {
        self.handle_da_fn(self.ctx, action);
    }
    pub fn handleWindowOp(self: *const ReplyCsiContext, action: parser_csi.CsiAction, param_len: usize, params: [parser_csi.max_params]i32) void {
        self.handle_window_op_fn(self.ctx, action, param_len, params);
    }
    pub fn handleDecrqm(self: *const ReplyCsiContext, action: parser_csi.CsiAction, param_len: usize, params: [parser_csi.max_params]i32) void {
        self.handle_decrqm_fn(self.ctx, action, param_len, params);
    }
    pub fn applyDecstr(self: *const ReplyCsiContext) void {
        self.apply_decstr_fn(self.ctx);
    }
};

fn csiIntermediatesEq(action: parser_csi.CsiAction, bytes: []const u8) bool {
    if (action.intermediates_len != bytes.len) return false;
    return std.mem.eql(u8, action.intermediates[0..action.intermediates_len], bytes);
}

fn effectiveCsiParamCount(action: parser_csi.CsiAction) usize {
    const raw_count = @min(@as(usize, action.count) + 1, parser_csi.max_params);
    if (action.count == 0 and action.params[0] == 0) return 0;
    return raw_count;
}

fn effectiveSgrParamCount(action: parser_csi.CsiAction) usize {
    const raw_count = @min(@as(usize, action.count) + 1, parser_csi.max_params);
    if (action.count == 0 and action.params[0] == 0) return 1;
    return raw_count;
}

pub const CsiWriter = csi_reply.CsiWriter;
const QueryContext = csi_reply.QueryContext;
const CursorReport = csi_reply.CursorReport;
const ScreenQueryContext = csi_reply.ScreenQueryContext;

pub const SessionFacade = struct {
    ctx: *anyopaque,
    handle_csi_fn: *const fn (ctx: *anyopaque, action: parser_csi.CsiAction) void,

    pub fn from(session: anytype) SessionFacade {
        const SessionPtr = @TypeOf(session);
        return .{
            .ctx = @ptrCast(session),
            .handle_csi_fn = struct {
                fn call(ctx: *anyopaque, action: parser_csi.CsiAction) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    handleCsiOnSession(s, action);
                }
            }.call,
        };
    }

    pub fn handleCsi(self: *const SessionFacade, action: parser_csi.CsiAction) void {
        self.handle_csi_fn(self.ctx, action);
    }
};

pub fn handleCsi(session: SessionFacade, action: parser_csi.CsiAction) void {
    session.handleCsi(action);
}

fn handleCsiOnSession(self: anytype, action: parser_csi.CsiAction) void {
    const log = app_logger.logger("terminal.csi");
    const csi_param_count = effectiveCsiParamCount(action);
    log.logf(
        .debug,
        "csi final={c} leader={c} private={d} interm={s} count={d} params={d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}",
        .{
            action.final,
            if (action.leader == 0) '.' else action.leader,
            @as(u8, @intFromBool(action.private)),
            action.intermediates[0..action.intermediates_len],
            csi_param_count,
            action.params[0],
            action.params[1],
            action.params[2],
            action.params[3],
            action.params[4],
            action.params[5],
            action.params[6],
            action.params[7],
            action.params[8],
            action.params[9],
            action.params[10],
            action.params[11],
            action.params[12],
            action.params[13],
            action.params[14],
            action.params[15],
        },
    );
    const p = action.params;
    const param_len = csi_param_count;
    const mode_context = ModeMutationContext.from(self);
    const simple = SimpleCsiContext.from(self);
    const special = SpecialCsiContext.from(self);
    const reply = ReplyCsiContext.from(self);

    switch (action.final) {
        'A', 'B', 'C', 'D', 'E', 'F', 'G', 'I', 'H', 'f', 'd', 'J', 'K', '@', 'P', 'X', 'L', 'M', 'S', 'T', 'Z', 'r' => {
            handleSimpleCsi(simple, action, param_len, p);
        },
        's' => { // SCP / DECSLRM (when ?69 enabled)
            handleSpecialCsi(special, action, param_len, p);
        },
        'u' => { // RCP
            handleSpecialCsi(special, action, param_len, p);
        },
        'm' => { // SGR
            applySgr(SgrContext.from(self), action);
        },
        'q' => { // DECSCUSR
            handleSpecialCsi(special, action, param_len, p);
        },
        'g' => { // TBC
            handleSpecialCsi(special, action, param_len, p);
        },
        'n' => { // DSR
            reply.handleDsr(action, param_len, p);
        },
        'c' => { // DA
            reply.handleDa(action);
        },
        't' => { // Window ops (bounded subset)
            reply.handleWindowOp(action, param_len, p);
        },
        'p' => { // DECRQM (requires '$' intermediate)
            if (csiIntermediatesEq(action, "!")) { // DECSTR (soft terminal reset)
                if (action.leader == 0 and !action.private) {
                    reply.applyDecstr();
                }
                return;
            }
            reply.handleDecrqm(action, param_len, p);
        },
        'h' => { // SM
            csi_mode_mutation.applyModeMutation(mode_context, action, param_len, p, true);
            return;
        },
        'l' => { // RM
            csi_mode_mutation.applyModeMutation(mode_context, action, param_len, p, false);
            return;
        },
        else => {},
    }
}

fn handleSimpleCsi(
    context: SimpleCsiContext,
    action: parser_csi.CsiAction,
    param_len: usize,
    params: [parser_csi.max_params]i32,
) void {
    csi_exec.handleSimpleCsi(context, action, param_len, params);
}

fn handleSpecialCsi(
    context: SpecialCsiContext,
    action: parser_csi.CsiAction,
    param_len: usize,
    params: [parser_csi.max_params]i32,
) void {
    csi_exec.handleSpecialCsi(context, action, param_len, params);
}

pub fn writeDaPrimaryReply(pty: anytype) bool {
    return csi_reply.writeDaPrimaryReply(pty);
}

fn writeDaPrimaryReplyWithWriter(writer: CsiWriter) bool {
    return csi_reply.writeDaPrimaryReplyWithWriter(writer);
}

pub fn writeDsrReply(pty: anytype, leader: u8, mode: i32, row_1: usize, col_1: usize) bool {
    return csi_reply.writeDsrReply(pty, leader, mode, row_1, col_1);
}

fn writeDsrReplyWithWriter(writer: CsiWriter, leader: u8, mode: i32, row_1: usize, col_1: usize) bool {
    return csi_reply.writeDsrReplyWithWriter(writer, leader, mode, row_1, col_1);
}

pub fn writeDecrqmReply(pty: anytype, private: bool, mode: i32, state: DecrpmState) bool {
    return writeDecrqmReplyWithWriter(CsiWriter.from(pty), private, mode, state);
}

pub fn writeDecrqmReplyWithWriter(writer: CsiWriter, private: bool, mode: i32, state: DecrpmState) bool {
    const log = app_logger.logger("terminal.csi");
    var buf: [32]u8 = undefined;
    const seq = if (private)
        std.fmt.bufPrint(&buf, "\x1b[?{d};{d}$y", .{ mode, @intFromEnum(state) })
    else
        std.fmt.bufPrint(&buf, "\x1b[{d};{d}$y", .{ mode, @intFromEnum(state) });
    const bytes = seq catch |err| {
        log.logf(.warning, "DECRQM reply format failed mode={d} private={d}: {s}", .{ mode, @as(u8, @intFromBool(private)), @errorName(err) });
        return false;
    };
    _ = writer.write(bytes) catch |err| {
        log.logf(.warning, "DECRQM reply write failed mode={d} private={d}: {s}", .{ mode, @as(u8, @intFromBool(private)), @errorName(err) });
        return false;
    };
    return true;
}

fn handleDsrQuery(query: QueryContext, writer: CsiWriter, screen: ScreenQueryContext, action: parser_csi.CsiAction, param_len: usize, params: [parser_csi.max_params]i32) void {
    csi_reply.handleDsrQuery(query, writer, screen, action, param_len, params);
}

fn handleDaQuery(writer: CsiWriter) void {
    csi_reply.handleDaQuery(writer);
}

fn handleWindowOpQuery(query: QueryContext, writer: CsiWriter, screen: ScreenQueryContext, param_len: usize, params: [parser_csi.max_params]i32) void {
    csi_reply.handleWindowOpQuery(query, writer, screen, param_len, params);
}

fn handleDecrqmQuery(writer: CsiWriter, action: parser_csi.CsiAction, mode: i32, snapshot: ModeSnapshot) void {
    csi_mode_query.handleDecrqmQuery(writer, action, mode, snapshot);
}

fn writeConst(writer: CsiWriter, seq: []const u8) bool {
    return csi_reply.writeConst(writer, seq);
}

pub fn writeColorSchemePreferenceReply(pty: anytype, dark: bool) bool {
    return csi_reply.writeColorSchemePreferenceReply(pty, dark);
}

fn writeColorSchemePreferenceReplyWithWriter(writer: CsiWriter, dark: bool) bool {
    return csi_reply.writeColorSchemePreferenceReplyWithWriter(writer, dark);
}

pub fn writeWindowOpCharsReply(pty: anytype, rows: u16, cols: u16) bool {
    return csi_reply.writeWindowOpCharsReply(pty, rows, cols);
}

fn writeWindowOpCharsReplyWithWriter(writer: CsiWriter, rows: u16, cols: u16) bool {
    return csi_reply.writeWindowOpCharsReplyWithWriter(writer, rows, cols);
}

pub fn writeWindowOpScreenCharsReply(pty: anytype, rows: u16, cols: u16) bool {
    return csi_reply.writeWindowOpScreenCharsReply(pty, rows, cols);
}

fn writeWindowOpScreenCharsReplyWithWriter(writer: CsiWriter, rows: u16, cols: u16) bool {
    return csi_reply.writeWindowOpScreenCharsReplyWithWriter(writer, rows, cols);
}

pub fn writeWindowOpPixelsReply(pty: anytype, height_px: u32, width_px: u32) bool {
    return csi_reply.writeWindowOpPixelsReply(pty, height_px, width_px);
}

fn writeWindowOpPixelsReplyWithWriter(writer: CsiWriter, height_px: u32, width_px: u32) bool {
    return csi_reply.writeWindowOpPixelsReplyWithWriter(writer, height_px, width_px);
}

pub fn writeWindowOpCellPixelsReply(pty: anytype, cell_h: u16, cell_w: u16) bool {
    return csi_reply.writeWindowOpCellPixelsReply(pty, cell_h, cell_w);
}

fn writeWindowOpCellPixelsReplyWithWriter(writer: CsiWriter, cell_h: u16, cell_w: u16) bool {
    return csi_reply.writeWindowOpCellPixelsReplyWithWriter(writer, cell_h, cell_w);
}

pub fn applySgr(context: SgrContext, action: parser_csi.CsiAction) void {
    csi_style_reset.applySgr(context, action, effectiveSgrParamCount);
}

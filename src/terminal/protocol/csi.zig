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
const ModeMutationContext = csi_mode_mutation.ModeMutationContext;

fn modeSnapshotFromContext(ctx: ModeCaptureContext) ModeSnapshot {
    return csi_mode_query.modeSnapshotFromContext(ctx);
}

const SgrContext = csi_style_reset.SgrContext;
const DecstrContext = csi_style_reset.DecstrContext;

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
const CursorReport = csi_reply.CursorReport;
const QueryState = csi_reply.QueryState;
const ScreenState = csi_reply.ScreenState;

pub fn handleCsi(self: anytype, action: parser_csi.CsiAction) void {
    handleCsiOnSession(self, action);
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
    switch (action.final) {
        'A', 'B', 'C', 'D', 'E', 'F', 'G', 'I', 'H', 'f', 'd', 'J', 'K', '@', 'P', 'X', 'L', 'M', 'S', 'T', 'Z', 'r' => {
            csi_exec.handleSimpleCsi(self, action, param_len, p);
        },
        's' => { // SCP / DECSLRM (when ?69 enabled)
            csi_exec.handleSpecialCsi(self, action, param_len, p);
        },
        'u' => { // RCP
            csi_exec.handleSpecialCsi(self, action, param_len, p);
        },
        'm' => { // SGR
            applySgr(SgrContext.from(self), action);
        },
        'q' => { // DECSCUSR
            csi_exec.handleSpecialCsi(self, action, param_len, p);
        },
        'g' => { // TBC
            csi_exec.handleSpecialCsi(self, action, param_len, p);
        },
        'n' => { // DSR
            if (self.lockPtyWriter()) |writer_guard| {
                var writer = writer_guard;
                defer writer.unlock();
                const screen = self.activeScreen();
                handleDsrQuery(.{
                    .color_scheme_dark = self.interaction.color_scheme_dark,
                    .cell_height = self.interaction.cell_height,
                    .cell_width = self.interaction.cell_width,
                }, CsiWriter.from(&writer), .{
                    .cursor_report = blk: {
                        const pos = screen.cursorReport();
                        break :blk .{ .row_1 = pos.row_1, .col_1 = pos.col_1 };
                    },
                    .rows = screen.grid.rows,
                    .cols = screen.grid.cols,
                }, action, param_len, p);
            }
        },
        'c' => { // DA
            if (action.leader == 0 or action.leader == '?') {
                if (self.lockPtyWriter()) |writer_guard| {
                    var writer = writer_guard;
                    defer writer.unlock();
                    handleDaQuery(CsiWriter.from(&writer));
                }
            }
        },
        't' => { // Window ops (bounded subset)
            if (action.leader == 0 and !action.private) {
                if (self.lockPtyWriter()) |writer_guard| {
                    var writer = writer_guard;
                    defer writer.unlock();
                    const screen = self.activeScreen();
                    handleWindowOpQuery(.{
                        .color_scheme_dark = self.interaction.color_scheme_dark,
                        .cell_height = self.interaction.cell_height,
                        .cell_width = self.interaction.cell_width,
                    }, CsiWriter.from(&writer), .{
                        .cursor_report = blk: {
                            const pos = screen.cursorReport();
                            break :blk .{ .row_1 = pos.row_1, .col_1 = pos.col_1 };
                        },
                        .rows = screen.grid.rows,
                        .cols = screen.grid.cols,
                    }, param_len, p);
                }
            }
        },
        'p' => { // DECRQM (requires '$' intermediate)
            if (csiIntermediatesEq(action, "!")) { // DECSTR (soft terminal reset)
                if (action.leader == 0 and !action.private) {
                    csi_style_reset.applyDecstrReset(DecstrContext.from(self));
                }
                return;
            }
            if (csiIntermediatesEq(action, "$") and param_len == 1) {
                if (self.lockPtyWriter()) |writer_guard| {
                    var writer = writer_guard;
                    defer writer.unlock();
                    handleDecrqmQuery(CsiWriter.from(&writer), action, p[0], csi_mode_query.modeSnapshot(self));
                }
            }
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

fn handleDsrQuery(query: QueryState, writer: CsiWriter, screen: ScreenState, action: parser_csi.CsiAction, param_len: usize, params: [parser_csi.max_params]i32) void {
    csi_reply.handleDsrQuery(query, writer, screen, action, param_len, params);
}

fn handleDaQuery(writer: CsiWriter) void {
    csi_reply.handleDaQuery(writer);
}

fn handleWindowOpQuery(query: QueryState, writer: CsiWriter, screen: ScreenState, param_len: usize, params: [parser_csi.max_params]i32) void {
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

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
const palette_mod = @import("palette.zig");
const protocol_runtime = @import("../core/session/protocol_runtime.zig");

const Color = types.Color;

pub const DecrpmState = enum(u8) {
    not_recognized = 0,
    set = 1,
    reset = 2,
    permanently_set = 3,
    permanently_reset = 4,
};

const ModeSnapshot = csi_mode_query.ModeSnapshot;

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

pub fn handleCsi(self: anytype, action: parser_csi.CsiAction) void {
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
    if (!action.private and action.leader == 0 and csiIntermediatesEq(action, "#")) {
        switch (action.final) {
            'P' => {
                palette_mod.handleColorStackPush(self);
                return;
            },
            'Q' => {
                palette_mod.handleColorStackPop(self);
                return;
            },
            else => {},
        }
    }
    switch (action.final) {
        'A', 'B', 'C', 'D', 'E', 'F', 'G', 'I', 'H', 'f', 'd', 'J', 'K', '@', 'P', 'X', 'L', 'M', 'S', 'T', 'b', 'Z', 'r' => {
            csi_exec.handleSimpleCsi(self, action, param_len, p);
        },
        's' => { // SCP / DECSLRM (when ?69 enabled)
            csi_exec.handleSpecialCsi(self, action, param_len, p);
        },
        'u' => { // RCP
            csi_exec.handleSpecialCsi(self, action, param_len, p);
        },
        'm' => { // SGR
            applySgr(self, action);
        },
        'q' => { // DECSCUSR
            csi_exec.handleSpecialCsi(self, action, param_len, p);
        },
        'g' => { // TBC
            csi_exec.handleSpecialCsi(self, action, param_len, p);
        },
        'n' => { // DSR
            const reply_snapshot = csi_reply.snapshot(self);
            const mode = if (param_len > 0) p[0] else 0;
            var buf: [40]u8 = undefined;
            if (action.leader == '?') {
                switch (mode) {
                    6, 15, 25, 26, 55, 56, 75, 85 => {
                        if (csi_reply.dsrReplyInto(&buf, action.leader, mode, reply_snapshot.cursor_row_1, reply_snapshot.cursor_col_1)) |seq| {
                            _ = protocol_runtime.emitReplyBytes(self, "terminal.csi", seq);
                        }
                    },
                    996 => {
                        if (csi_reply.colorSchemePreferenceReplyInto(&buf, reply_snapshot.color_scheme_dark)) |seq| {
                            _ = protocol_runtime.emitReplyBytes(self, "terminal.csi", seq);
                        }
                    },
                    else => {},
                }
            } else if (action.leader == 0) {
                switch (mode) {
                    5, 6 => {
                        if (csi_reply.dsrReplyInto(&buf, action.leader, mode, reply_snapshot.cursor_row_1, reply_snapshot.cursor_col_1)) |seq| {
                            _ = protocol_runtime.emitReplyBytes(self, "terminal.csi", seq);
                        }
                    },
                    else => {},
                }
            }
        },
        'c' => { // DA
            if (action.leader == 0 or action.leader == '?') {
                _ = protocol_runtime.emitReplyBytes(self, "terminal.csi", csi_reply.daPrimaryReplyBytes());
            }
        },
        't' => { // Window ops (bounded subset)
            if (action.leader == 0 and !action.private) {
                const reply_snapshot = csi_reply.snapshot(self);
                const mode = if (param_len > 0) p[0] else 0;
                var buf: [40]u8 = undefined;
                switch (mode) {
                    14 => {
                        if (csi_reply.windowOpPixelsReplyInto(
                            &buf,
                            @as(u32, reply_snapshot.cell_height) * reply_snapshot.rows,
                            @as(u32, reply_snapshot.cell_width) * reply_snapshot.cols,
                        )) |seq| {
                            _ = protocol_runtime.emitReplyBytes(self, "terminal.csi", seq);
                        }
                    },
                    16 => {
                        if (csi_reply.windowOpCellPixelsReplyInto(&buf, reply_snapshot.cell_height, reply_snapshot.cell_width)) |seq| {
                            _ = protocol_runtime.emitReplyBytes(self, "terminal.csi", seq);
                        }
                    },
                    18 => {
                        if (csi_reply.windowOpCharsReplyInto(&buf, reply_snapshot.rows, reply_snapshot.cols)) |seq| {
                            _ = protocol_runtime.emitReplyBytes(self, "terminal.csi", seq);
                        }
                    },
                    19 => {
                        if (csi_reply.windowOpScreenCharsReplyInto(&buf, reply_snapshot.rows, reply_snapshot.cols)) |seq| {
                            _ = protocol_runtime.emitReplyBytes(self, "terminal.csi", seq);
                        }
                    },
                    else => {},
                }
            }
        },
        'p' => { // DECRQM (requires '$' intermediate)
            if (csiIntermediatesEq(action, "!")) { // DECSTR (soft terminal reset)
                if (action.leader == 0 and !action.private) {
                    csi_style_reset.applyDecstrReset(self);
                }
                return;
            }
            if (csiIntermediatesEq(action, "$") and param_len == 1) {
                const mode = p[0];
                const snapshot = csi_mode_query.modeSnapshot(self);
                var buf: [32]u8 = undefined;
                if (action.leader == '?' and action.private) {
                    const state = csi_mode_query.decrqmPrivateModeState(snapshot, mode);
                    if (csi_mode_query.decrqmReplyInto(&buf, true, mode, state)) |seq| {
                        _ = protocol_runtime.emitReplyBytes(self, "terminal.csi", seq);
                    }
                } else if (action.leader == 0 and !action.private) {
                    const state = csi_mode_query.decrqmAnsiModeState(snapshot, mode);
                    if (csi_mode_query.decrqmReplyInto(&buf, false, mode, state)) |seq| {
                        _ = protocol_runtime.emitReplyBytes(self, "terminal.csi", seq);
                    }
                }
            }
        },
        'h' => { // SM
            csi_mode_mutation.applyModeMutation(self, action, param_len, p, true);
            return;
        },
        'l' => { // RM
            csi_mode_mutation.applyModeMutation(self, action, param_len, p, false);
            return;
        },
        else => {},
    }
}

pub fn applySgr(self: anytype, action: parser_csi.CsiAction) void {
    self.core.applySgrLocked(action.params[0..effectiveSgrParamCount(action)]);
}

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
            applySgr(self, action);
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
                const screen = self.core.activeScreen();
                const pos = screen.cursorReport();
                const mode = if (param_len > 0) p[0] else 0;
                if (action.leader == '?') {
                    switch (mode) {
                        6 => _ = csi_reply.writeDsrReplyWithWriter(&writer, action.leader, mode, pos.row_1, pos.col_1),
                        15, 25, 26, 55, 56, 75, 85 => _ = csi_reply.writeDsrReplyWithWriter(&writer, action.leader, mode, 0, 0),
                        996 => _ = csi_reply.writeColorSchemePreferenceReplyWithWriter(&writer, self.session.interaction.host_contract.color_scheme_dark),
                        else => {},
                    }
                } else if (action.leader == 0) {
                    switch (mode) {
                        5 => _ = csi_reply.writeDsrReplyWithWriter(&writer, action.leader, mode, 0, 0),
                        6 => _ = csi_reply.writeDsrReplyWithWriter(&writer, action.leader, mode, pos.row_1, pos.col_1),
                        else => {},
                    }
                }
            }
        },
        'c' => { // DA
            if (action.leader == 0 or action.leader == '?') {
                if (self.lockPtyWriter()) |writer_guard| {
                    var writer = writer_guard;
                    defer writer.unlock();
                    _ = csi_reply.writeDaPrimaryReplyWithWriter(&writer);
                }
            }
        },
        't' => { // Window ops (bounded subset)
            if (action.leader == 0 and !action.private) {
                if (self.lockPtyWriter()) |writer_guard| {
                    var writer = writer_guard;
                    defer writer.unlock();
                    const screen = self.core.activeScreen();
                    const mode = if (param_len > 0) p[0] else 0;
                    switch (mode) {
                        14 => _ = csi_reply.writeWindowOpPixelsReplyWithWriter(
                            &writer,
                            @as(u32, self.session.interaction.host_contract.cell_height) * screen.grid.rows,
                            @as(u32, self.session.interaction.host_contract.cell_width) * screen.grid.cols,
                        ),
                        16 => _ = csi_reply.writeWindowOpCellPixelsReplyWithWriter(&writer, self.session.interaction.host_contract.cell_height, self.session.interaction.host_contract.cell_width),
                        18 => _ = csi_reply.writeWindowOpCharsReplyWithWriter(&writer, screen.grid.rows, screen.grid.cols),
                        19 => _ = csi_reply.writeWindowOpScreenCharsReplyWithWriter(&writer, screen.grid.rows, screen.grid.cols),
                        else => {},
                    }
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
                if (self.lockPtyWriter()) |writer_guard| {
                    var writer = writer_guard;
                    defer writer.unlock();
                    const mode = p[0];
                    const snapshot = csi_mode_query.modeSnapshot(self);
                    if (action.leader == '?' and action.private) {
                        const state = csi_mode_query.decrqmPrivateModeState(snapshot, mode);
                        _ = csi_mode_query.writeDecrqmReplyWithWriter(&writer, true, mode, state);
                    } else if (action.leader == 0 and !action.private) {
                        const state = csi_mode_query.decrqmAnsiModeState(snapshot, mode);
                        _ = csi_mode_query.writeDecrqmReplyWithWriter(&writer, false, mode, state);
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
    csi_style_reset.applySgr(self, action, effectiveSgrParamCount);
}

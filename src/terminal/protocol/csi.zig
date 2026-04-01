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
                csi_reply.handleDsrQuery(.{
                    .color_scheme_dark = self.interaction.color_scheme_dark,
                    .cell_height = self.interaction.cell_height,
                    .cell_width = self.interaction.cell_width,
                }, &writer, .{
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
                    csi_reply.handleDaQuery(&writer);
                }
            }
        },
        't' => { // Window ops (bounded subset)
            if (action.leader == 0 and !action.private) {
                if (self.lockPtyWriter()) |writer_guard| {
                    var writer = writer_guard;
                    defer writer.unlock();
                    const screen = self.core.activeScreen();
                    csi_reply.handleWindowOpQuery(.{
                        .color_scheme_dark = self.interaction.color_scheme_dark,
                        .cell_height = self.interaction.cell_height,
                        .cell_width = self.interaction.cell_width,
                    }, &writer, .{
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
                    csi_style_reset.applyDecstrReset(self);
                }
                return;
            }
            if (csiIntermediatesEq(action, "$") and param_len == 1) {
                if (self.lockPtyWriter()) |writer_guard| {
                    var writer = writer_guard;
                    defer writer.unlock();
                    csi_mode_query.handleDecrqmQuery(&writer, action, p[0], csi_mode_query.modeSnapshot(self));
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

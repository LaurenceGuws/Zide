const std = @import("std");
const parser_csi = @import("../parser/csi.zig");
const app_logger = @import("../../app_logger.zig");
const protocol_runtime = @import("../core/session/protocol_runtime.zig");

pub const Snapshot = struct {
    cursor_row_1: usize,
    cursor_col_1: usize,
    rows: u16,
    cols: u16,
    cell_height: u16,
    cell_width: u16,
    color_scheme_dark: bool,
};

pub fn snapshot(self: anytype) Snapshot {
    const core_snapshot = self.core.csiReplySnapshot();
    const runtime_snapshot = protocol_runtime.csiReplyRuntimeSnapshot(self);
    return .{
        .cursor_row_1 = core_snapshot.cursor_row_1,
        .cursor_col_1 = core_snapshot.cursor_col_1,
        .rows = core_snapshot.rows,
        .cols = core_snapshot.cols,
        .cell_height = core_snapshot.cell_height,
        .cell_width = core_snapshot.cell_width,
        .color_scheme_dark = runtime_snapshot.color_scheme_dark,
    };
}

pub fn dsrReplyInto(buf: []u8, leader: u8, mode: i32, row_1: usize, col_1: usize) ?[]const u8 {
    if (leader == '?') {
        return switch (mode) {
            6 => std.fmt.bufPrint(buf, "\x1b[?{d};{d}R", .{ row_1, col_1 }) catch null,
            15 => "\x1b[?10n",
            25 => "\x1b[?20n",
            26 => "\x1b[?27;1;0;0n",
            55 => "\x1b[?50n",
            56 => "\x1b[?57;0n",
            75 => "\x1b[?70n",
            85 => "\x1b[?83n",
            else => null,
        };
    }
    if (leader == 0) {
        return switch (mode) {
            5 => "\x1b[0n",
            6 => std.fmt.bufPrint(buf, "\x1b[{d};{d}R", .{ row_1, col_1 }) catch null,
            else => null,
        };
    }
    return null;
}

pub fn daPrimaryReplyBytes() []const u8 {
    return "\x1b[?62;1;2;4;6;7;8;9;15;18;21;22;28;29c";
}

pub fn colorSchemePreferenceReplyInto(buf: []u8, dark: bool) ?[]const u8 {
    return std.fmt.bufPrint(buf, "\x1b[?997;{d}n", .{if (dark) @as(u8, 1) else @as(u8, 2)}) catch null;
}

pub fn windowOpCharsReplyInto(buf: []u8, rows: u16, cols: u16) ?[]const u8 {
    return std.fmt.bufPrint(buf, "\x1b[8;{d};{d}t", .{ rows, cols }) catch null;
}

pub fn windowOpScreenCharsReplyInto(buf: []u8, rows: u16, cols: u16) ?[]const u8 {
    return std.fmt.bufPrint(buf, "\x1b[9;{d};{d}t", .{ rows, cols }) catch null;
}

pub fn windowOpPixelsReplyInto(buf: []u8, height_px: u32, width_px: u32) ?[]const u8 {
    return std.fmt.bufPrint(buf, "\x1b[4;{d};{d}t", .{ height_px, width_px }) catch null;
}

pub fn windowOpCellPixelsReplyInto(buf: []u8, cell_h: u16, cell_w: u16) ?[]const u8 {
    return std.fmt.bufPrint(buf, "\x1b[6;{d};{d}t", .{ cell_h, cell_w }) catch null;
}

pub fn writeDaPrimaryReplyWithWriter(writer: anytype) bool {
    return writeConst(writer, daPrimaryReplyBytes());
}

pub fn writeDsrReplyWithWriter(writer: anytype, leader: u8, mode: i32, row_1: usize, col_1: usize) bool {
    const log = app_logger.logger("terminal.csi");
    var buf: [32]u8 = undefined;
    const seq = dsrReplyInto(&buf, leader, mode, row_1, col_1) orelse {
        log.logf(.warning, "DSR reply format failed leader={c} mode={d}", .{ if (leader == 0) '.' else leader, mode });
        return false;
    };
    return writeConst(writer, seq);
}

fn writeConst(writer: anytype, seq: []const u8) bool {
    const log = app_logger.logger("terminal.csi");
    _ = writer.write(seq) catch |err| {
        log.logf(.warning, "CSI const reply write failed: {s}", .{@errorName(err)});
        return false;
    };
    return true;
}

pub fn writeColorSchemePreferenceReplyWithWriter(writer: anytype, dark: bool) bool {
    const log = app_logger.logger("terminal.csi");
    var buf: [16]u8 = undefined;
    const seq = colorSchemePreferenceReplyInto(&buf, dark) orelse {
        log.logf(.warning, "color scheme preference reply format failed", .{});
        return false;
    };
    _ = writer.write(seq) catch |err| {
        log.logf(.warning, "color scheme preference reply write failed: {s}", .{@errorName(err)});
        return false;
    };
    return true;
}

pub fn writeWindowOpCharsReplyWithWriter(writer: anytype, rows: u16, cols: u16) bool {
    const log = app_logger.logger("terminal.csi");
    var buf: [32]u8 = undefined;
    const seq = windowOpCharsReplyInto(&buf, rows, cols) orelse {
        log.logf(.warning, "window chars reply format failed", .{});
        return false;
    };
    _ = writer.write(seq) catch |err| {
        log.logf(.warning, "window chars reply write failed: {s}", .{@errorName(err)});
        return false;
    };
    return true;
}

pub fn writeWindowOpScreenCharsReplyWithWriter(writer: anytype, rows: u16, cols: u16) bool {
    const log = app_logger.logger("terminal.csi");
    var buf: [32]u8 = undefined;
    const seq = windowOpScreenCharsReplyInto(&buf, rows, cols) orelse {
        log.logf(.warning, "window screen chars reply format failed", .{});
        return false;
    };
    _ = writer.write(seq) catch |err| {
        log.logf(.warning, "window screen chars reply write failed: {s}", .{@errorName(err)});
        return false;
    };
    return true;
}

pub fn writeWindowOpPixelsReplyWithWriter(writer: anytype, height_px: u32, width_px: u32) bool {
    const log = app_logger.logger("terminal.csi");
    var buf: [40]u8 = undefined;
    const seq = windowOpPixelsReplyInto(&buf, height_px, width_px) orelse {
        log.logf(.warning, "window pixels reply format failed", .{});
        return false;
    };
    _ = writer.write(seq) catch |err| {
        log.logf(.warning, "window pixels reply write failed: {s}", .{@errorName(err)});
        return false;
    };
    return true;
}

pub fn writeWindowOpCellPixelsReplyWithWriter(writer: anytype, cell_h: u16, cell_w: u16) bool {
    const log = app_logger.logger("terminal.csi");
    var buf: [32]u8 = undefined;
    const seq = windowOpCellPixelsReplyInto(&buf, cell_h, cell_w) orelse {
        log.logf(.warning, "window cell pixels reply format failed", .{});
        return false;
    };
    _ = writer.write(seq) catch |err| {
        log.logf(.warning, "window cell pixels reply write failed: {s}", .{@errorName(err)});
        return false;
    };
    return true;
}

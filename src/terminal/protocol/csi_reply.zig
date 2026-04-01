const std = @import("std");
const parser_csi = @import("../parser/csi.zig");
const app_logger = @import("../../app_logger.zig");

pub fn writeDaPrimaryReplyWithWriter(writer: anytype) bool {
    const log = app_logger.logger("terminal.csi");
    _ = writer.write("\x1b[?62;1;2;4;6;7;8;9;15;18;21;22;28;29c") catch |err| {
        log.logf(.warning, "DA primary reply write failed: {s}", .{@errorName(err)});
        return false;
    };
    return true;
}

pub fn writeDsrReplyWithWriter(writer: anytype, leader: u8, mode: i32, row_1: usize, col_1: usize) bool {
    const log = app_logger.logger("terminal.csi");
    if (leader == '?') {
        switch (mode) {
            6 => {
                var buf: [32]u8 = undefined;
                const seq = std.fmt.bufPrint(&buf, "\x1b[?{d};{d}R", .{ row_1, col_1 }) catch |err| {
                    log.logf(.warning, "DSR private cursor reply format failed: {s}", .{@errorName(err)});
                    return false;
                };
                _ = writer.write(seq) catch |err| {
                    log.logf(.warning, "DSR private cursor reply write failed: {s}", .{@errorName(err)});
                    return false;
                };
                return true;
            },
            15 => return writeConst(writer, "\x1b[?10n"),
            25 => return writeConst(writer, "\x1b[?20n"),
            26 => return writeConst(writer, "\x1b[?27;1;0;0n"),
            55 => return writeConst(writer, "\x1b[?50n"),
            56 => return writeConst(writer, "\x1b[?57;0n"),
            75 => return writeConst(writer, "\x1b[?70n"),
            85 => return writeConst(writer, "\x1b[?83n"),
            else => return false,
        }
    }
    if (leader == 0) {
        switch (mode) {
            5 => return writeConst(writer, "\x1b[0n"),
            6 => {
                var buf: [32]u8 = undefined;
                const seq = std.fmt.bufPrint(&buf, "\x1b[{d};{d}R", .{ row_1, col_1 }) catch |err| {
                    log.logf(.warning, "DSR cursor reply format failed: {s}", .{@errorName(err)});
                    return false;
                };
                _ = writer.write(seq) catch |err| {
                    log.logf(.warning, "DSR cursor reply write failed: {s}", .{@errorName(err)});
                    return false;
                };
                return true;
            },
            else => return false,
        }
    }
    return false;
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
    const seq = std.fmt.bufPrint(&buf, "\x1b[?997;{d}n", .{if (dark) @as(u8, 1) else @as(u8, 2)}) catch |err| {
        log.logf(.warning, "color scheme preference reply format failed: {s}", .{@errorName(err)});
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
    const seq = std.fmt.bufPrint(&buf, "\x1b[8;{d};{d}t", .{ rows, cols }) catch |err| {
        log.logf(.warning, "window chars reply format failed: {s}", .{@errorName(err)});
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
    const seq = std.fmt.bufPrint(&buf, "\x1b[9;{d};{d}t", .{ rows, cols }) catch |err| {
        log.logf(.warning, "window screen chars reply format failed: {s}", .{@errorName(err)});
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
    const seq = std.fmt.bufPrint(&buf, "\x1b[4;{d};{d}t", .{ height_px, width_px }) catch |err| {
        log.logf(.warning, "window pixels reply format failed: {s}", .{@errorName(err)});
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
    const seq = std.fmt.bufPrint(&buf, "\x1b[6;{d};{d}t", .{ cell_h, cell_w }) catch |err| {
        log.logf(.warning, "window cell pixels reply format failed: {s}", .{@errorName(err)});
        return false;
    };
    _ = writer.write(seq) catch |err| {
        log.logf(.warning, "window cell pixels reply write failed: {s}", .{@errorName(err)});
        return false;
    };
    return true;
}

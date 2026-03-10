const std = @import("std");
const parser_csi = @import("../parser/csi.zig");
const app_logger = @import("../../app_logger.zig");

pub const CsiWriter = struct {
    ctx: *anyopaque,
    write_fn: *const fn (ctx: *anyopaque, bytes: []const u8) anyerror!usize,

    pub fn from(writer: anytype) CsiWriter {
        const WriterPtr = @TypeOf(writer);
        return .{
            .ctx = @ptrCast(writer),
            .write_fn = struct {
                fn call(ctx: *anyopaque, bytes: []const u8) anyerror!usize {
                    const typed: WriterPtr = @ptrCast(@alignCast(ctx));
                    return try typed.write(bytes);
                }
            }.call,
        };
    }

    pub fn write(self: CsiWriter, bytes: []const u8) anyerror!usize {
        return try self.write_fn(self.ctx, bytes);
    }
};

pub const QueryContext = struct {
    ctx: *anyopaque,
    color_scheme_dark_fn: *const fn (ctx: *anyopaque) bool,
    cell_height_fn: *const fn (ctx: *anyopaque) u16,
    cell_width_fn: *const fn (ctx: *anyopaque) u16,

    pub fn from(session: anytype) QueryContext {
        const SessionPtr = @TypeOf(session);
        return .{
            .ctx = @ptrCast(session),
            .color_scheme_dark_fn = struct {
                fn call(ctx: *anyopaque) bool {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return s.color_scheme_dark;
                }
            }.call,
            .cell_height_fn = struct {
                fn call(ctx: *anyopaque) u16 {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return s.cell_height;
                }
            }.call,
            .cell_width_fn = struct {
                fn call(ctx: *anyopaque) u16 {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return s.cell_width;
                }
            }.call,
        };
    }

    pub fn colorSchemeDark(self: *const QueryContext) bool {
        return self.color_scheme_dark_fn(self.ctx);
    }

    pub fn cellHeight(self: *const QueryContext) u16 {
        return self.cell_height_fn(self.ctx);
    }

    pub fn cellWidth(self: *const QueryContext) u16 {
        return self.cell_width_fn(self.ctx);
    }
};

pub const CursorReport = struct {
    row_1: usize,
    col_1: usize,
};

pub const ScreenQueryContext = struct {
    ctx: *anyopaque,
    cursor_report_fn: *const fn (ctx: *anyopaque) CursorReport,
    rows_fn: *const fn (ctx: *anyopaque) u16,
    cols_fn: *const fn (ctx: *anyopaque) u16,

    pub fn from(screen: anytype) ScreenQueryContext {
        const ScreenPtr = @TypeOf(screen);
        return .{
            .ctx = @ptrCast(screen),
            .cursor_report_fn = struct {
                fn call(ctx: *anyopaque) CursorReport {
                    const typed: ScreenPtr = @ptrCast(@alignCast(ctx));
                    const pos = typed.cursorReport();
                    return .{ .row_1 = pos.row_1, .col_1 = pos.col_1 };
                }
            }.call,
            .rows_fn = struct {
                fn call(ctx: *anyopaque) u16 {
                    const typed: ScreenPtr = @ptrCast(@alignCast(ctx));
                    return typed.grid.rows;
                }
            }.call,
            .cols_fn = struct {
                fn call(ctx: *anyopaque) u16 {
                    const typed: ScreenPtr = @ptrCast(@alignCast(ctx));
                    return typed.grid.cols;
                }
            }.call,
        };
    }

    pub fn cursorReport(self: *const ScreenQueryContext) CursorReport {
        return self.cursor_report_fn(self.ctx);
    }

    pub fn rows(self: *const ScreenQueryContext) u16 {
        return self.rows_fn(self.ctx);
    }

    pub fn cols(self: *const ScreenQueryContext) u16 {
        return self.cols_fn(self.ctx);
    }
};

pub fn writeDaPrimaryReply(pty: anytype) bool {
    return writeDaPrimaryReplyWithWriter(CsiWriter.from(pty));
}

pub fn writeDaPrimaryReplyWithWriter(writer: CsiWriter) bool {
    const log = app_logger.logger("terminal.csi");
    _ = writer.write("\x1b[?62;1;2;4;6;7;8;9;15;18;21;22;28;29c") catch |err| {
        log.logf(.warning, "DA primary reply write failed: {s}", .{@errorName(err)});
        return false;
    };
    return true;
}

pub fn writeDsrReply(pty: anytype, leader: u8, mode: i32, row_1: usize, col_1: usize) bool {
    return writeDsrReplyWithWriter(CsiWriter.from(pty), leader, mode, row_1, col_1);
}

pub fn writeDsrReplyWithWriter(writer: CsiWriter, leader: u8, mode: i32, row_1: usize, col_1: usize) bool {
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

pub fn handleDsrQuery(query: QueryContext, writer: CsiWriter, screen: ScreenQueryContext, action: parser_csi.CsiAction, param_len: usize, params: [parser_csi.max_params]i32) void {
    const mode = if (param_len > 0) params[0] else 0;
    if (action.leader == '?') {
        switch (mode) {
            6 => {
                const pos = screen.cursorReport();
                _ = writeDsrReplyWithWriter(writer, action.leader, mode, pos.row_1, pos.col_1);
            },
            15, 25, 26, 55, 56, 75, 85 => _ = writeDsrReplyWithWriter(writer, action.leader, mode, 0, 0),
            996 => _ = writeColorSchemePreferenceReplyWithWriter(writer, query.colorSchemeDark()),
            else => {},
        }
    } else if (action.leader == 0) {
        switch (mode) {
            5 => _ = writeDsrReplyWithWriter(writer, action.leader, mode, 0, 0),
            6 => {
                const pos = screen.cursorReport();
                _ = writeDsrReplyWithWriter(writer, action.leader, mode, pos.row_1, pos.col_1);
            },
            else => {},
        }
    }
}

pub fn handleDaQuery(writer: CsiWriter) void {
    _ = writeDaPrimaryReplyWithWriter(writer);
}

pub fn handleWindowOpQuery(query: QueryContext, writer: CsiWriter, screen: ScreenQueryContext, param_len: usize, params: [parser_csi.max_params]i32) void {
    const mode = if (param_len > 0) params[0] else 0;
    switch (mode) {
        14 => _ = writeWindowOpPixelsReplyWithWriter(writer, @as(u32, query.cellHeight()) * screen.rows(), @as(u32, query.cellWidth()) * screen.cols()),
        16 => _ = writeWindowOpCellPixelsReplyWithWriter(writer, query.cellHeight(), query.cellWidth()),
        18 => _ = writeWindowOpCharsReplyWithWriter(writer, screen.rows(), screen.cols()),
        19 => _ = writeWindowOpScreenCharsReplyWithWriter(writer, screen.rows(), screen.cols()),
        else => {},
    }
}

pub fn writeConst(writer: CsiWriter, seq: []const u8) bool {
    const log = app_logger.logger("terminal.csi");
    _ = writer.write(seq) catch |err| {
        log.logf(.warning, "CSI const reply write failed: {s}", .{@errorName(err)});
        return false;
    };
    return true;
}

pub fn writeColorSchemePreferenceReply(pty: anytype, dark: bool) bool {
    return writeColorSchemePreferenceReplyWithWriter(CsiWriter.from(pty), dark);
}

pub fn writeColorSchemePreferenceReplyWithWriter(writer: CsiWriter, dark: bool) bool {
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

pub fn writeWindowOpCharsReply(pty: anytype, rows: u16, cols: u16) bool {
    return writeWindowOpCharsReplyWithWriter(CsiWriter.from(pty), rows, cols);
}

pub fn writeWindowOpCharsReplyWithWriter(writer: CsiWriter, rows: u16, cols: u16) bool {
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

pub fn writeWindowOpScreenCharsReply(pty: anytype, rows: u16, cols: u16) bool {
    return writeWindowOpScreenCharsReplyWithWriter(CsiWriter.from(pty), rows, cols);
}

pub fn writeWindowOpScreenCharsReplyWithWriter(writer: CsiWriter, rows: u16, cols: u16) bool {
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

pub fn writeWindowOpPixelsReply(pty: anytype, height_px: u32, width_px: u32) bool {
    return writeWindowOpPixelsReplyWithWriter(CsiWriter.from(pty), height_px, width_px);
}

pub fn writeWindowOpPixelsReplyWithWriter(writer: CsiWriter, height_px: u32, width_px: u32) bool {
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

pub fn writeWindowOpCellPixelsReply(pty: anytype, cell_h: u16, cell_w: u16) bool {
    return writeWindowOpCellPixelsReplyWithWriter(CsiWriter.from(pty), cell_h, cell_w);
}

pub fn writeWindowOpCellPixelsReplyWithWriter(writer: CsiWriter, cell_h: u16, cell_w: u16) bool {
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

const std = @import("std");
const types = @import("../model/types.zig");
const parser_csi = @import("../parser/csi.zig");
const app_logger = @import("../../app_logger.zig");

const Color = types.Color;

pub const DecrpmState = enum(u8) {
    not_recognized = 0,
    set = 1,
    reset = 2,
    permanently_set = 3,
    permanently_reset = 4,
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
    const get = struct {
        fn at(params: [parser_csi.max_params]i32, idx: u8, default: i32) i32 {
            return if (idx < parser_csi.max_params) params[idx] else default;
        }
    }.at;
    const screen = self.activeScreen();

    switch (action.final) {
        'A' => { // CUU
            const n = @max(1, get(p, 0, 1));
            const delta: usize = @intCast(n);
            screen.cursorUp(delta);
        },
        'B' => { // CUD
            const n = @max(1, get(p, 0, 1));
            const delta: usize = @intCast(n);
            screen.cursorDown(delta);
        },
        'C' => { // CUF
            const n = @max(1, get(p, 0, 1));
            const delta: usize = @intCast(n);
            screen.cursorForward(delta);
        },
        'D' => { // CUB
            const n = @max(1, get(p, 0, 1));
            const delta: usize = @intCast(n);
            screen.cursorBack(delta);
        },
        'E' => { // CNL
            const n = @max(1, get(p, 0, 1));
            const delta: usize = @intCast(n);
            screen.cursorNextLine(delta);
        },
        'F' => { // CPL
            const n = @max(1, get(p, 0, 1));
            const delta: usize = @intCast(n);
            screen.cursorPrevLine(delta);
        },
        'G' => { // CHA
            const col_1 = @max(1, get(p, 0, 1));
            screen.cursorColAbsolute(col_1);
        },
        'I' => { // CHT
            const n = @max(1, get(p, 0, 1));
            var i: i32 = 0;
            while (i < n) : (i += 1) {
                screen.tab();
            }
        },
        'H', 'f' => { // CUP
            const row_1 = @max(1, get(p, 0, 1));
            const col_1 = @max(1, get(p, 1, 1));
            screen.cursorPosAbsolute(row_1, col_1);
        },
        'd' => { // VPA
            const row_1 = @max(1, get(p, 0, 1));
            screen.cursorRowAbsolute(row_1);
        },
        'J' => { // ED
            const mode = if (param_len > 0) p[0] else 0;
            self.eraseDisplay(mode);
        },
        'K' => { // EL
            const mode = if (param_len > 0) p[0] else 0;
            self.eraseLine(mode);
        },
        '@' => { // ICH
            const n = @max(1, get(p, 0, 1));
            self.insertChars(@intCast(n));
        },
        'P' => { // DCH
            const n = @max(1, get(p, 0, 1));
            self.deleteChars(@intCast(n));
        },
        'X' => { // ECH
            const n = @max(1, get(p, 0, 1));
            self.eraseChars(@intCast(n));
        },
        'L' => { // IL
            const n = @max(1, get(p, 0, 1));
            self.insertLines(@intCast(n));
        },
        'M' => { // DL
            const n = @max(1, get(p, 0, 1));
            self.deleteLines(@intCast(n));
        },
        'S' => { // SU
            const n = @max(1, get(p, 0, 1));
            self.scrollRegionUp(@intCast(n));
        },
        'T' => { // SD
            const n = @max(1, get(p, 0, 1));
            self.scrollRegionDown(@intCast(n));
        },
        'Z' => { // CBT
            const n = @max(1, get(p, 0, 1));
            var i: i32 = 0;
            while (i < n) : (i += 1) {
                screen.backTab();
            }
        },
        'r' => { // DECSTBM
            const top_1 = if (param_len > 0 and p[0] > 0) p[0] else 1;
            const bot_1 = if (param_len > 1 and p[1] > 0) p[1] else @as(i32, @intCast(screen.grid.rows));
            const top = @min(@as(usize, screen.grid.rows - 1), @as(usize, @intCast(@max(1, top_1) - 1)));
            const bot = @min(@as(usize, screen.grid.rows - 1), @as(usize, @intCast(@max(1, bot_1) - 1)));
            if (top < bot) {
                screen.setScrollRegion(top, bot);
            }
        },
        's' => { // SCP / DECSLRM (when ?69 enabled)
            if (!action.private) {
                if (screen.left_right_margin_mode_69) {
                    const cols = @as(usize, screen.grid.cols);
                    if (cols == 0) return;
                    const left_1 = if (param_len > 0 and p[0] > 0) p[0] else 1;
                    const right_1 = if (param_len > 1 and p[1] > 0) p[1] else @as(i32, @intCast(cols));
                    const left = @min(cols - 1, @as(usize, @intCast(@max(1, left_1) - 1)));
                    const right = @min(cols - 1, @as(usize, @intCast(@max(1, right_1) - 1)));
                    if (left < right) {
                        screen.setLeftRightMargins(left, right);
                    }
                    return;
                }
                self.saveCursor();
            }
        },
        'u' => { // RCP
            if (action.leader == 0 and !action.private) {
                self.restoreCursor();
                return;
            }
            const flags: u32 = if (param_len > 0) @intCast(@max(0, p[0])) else 0;
            const mode: u32 = if (param_len > 1) @intCast(@max(0, p[1])) else 1;
            switch (action.leader) {
                '>' => self.keyModePushLocked(flags),
                '<' => self.keyModePopLocked(if (param_len > 0) @intCast(@max(1, p[0])) else 1),
                '=' => self.keyModeModifyLocked(flags, mode),
                '?' => self.keyModeQueryLocked(),
                else => {},
            }
        },
        'm' => { // SGR
            applySgr(self, action);
        },
        'q' => { // DECSCUSR
            if (action.leader == 0 and !action.private) {
                const mode = if (param_len > 0) p[0] else 0;
                self.setCursorStyle(mode);
            }
        },
        'g' => { // TBC
            const mode = if (param_len > 0) p[0] else 0;
            switch (mode) {
                0 => screen.clearTabAtCursor(),
                3 => screen.clearAllTabs(),
                else => {},
            }
        },
        'n' => { // DSR
            const mode = if (param_len > 0) p[0] else 0;
            if (self.lockPtyWriter()) |writer_guard| {
                var writer = writer_guard;
                defer writer.unlock();
                if (action.leader == '?') {
                    switch (mode) {
                        6 => { // DECXCPR
                            const pos = screen.cursorReport();
                            _ = writeDsrReply(&writer, action.leader, mode, pos.row_1, pos.col_1);
                        },
                        15, 25, 26, 55, 56, 75, 85 => _ = writeDsrReply(&writer, action.leader, mode, 0, 0),
                        996 => _ = writeColorSchemePreferenceReply(&writer, self.color_scheme_dark),
                        else => {},
                    }
                } else if (action.leader == 0) {
                    switch (mode) {
                        5 => _ = writeDsrReply(&writer, action.leader, mode, 0, 0),
                        6 => { // Cursor position report
                            const pos = screen.cursorReport();
                            _ = writeDsrReply(&writer, action.leader, mode, pos.row_1, pos.col_1);
                        },
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
                    _ = writeDaPrimaryReply(&writer);
                }
            }
        },
        't' => { // Window ops (bounded subset)
            if (action.leader != 0 or action.private) return;
            const mode = if (param_len > 0) p[0] else 0;
            if (self.lockPtyWriter()) |writer_guard| {
                var writer = writer_guard;
                defer writer.unlock();
                switch (mode) {
                    14 => _ = writeWindowOpPixelsReply(&writer, @as(u32, self.cell_height) * screen.grid.rows, @as(u32, self.cell_width) * screen.grid.cols),
                    16 => _ = writeWindowOpCellPixelsReply(&writer, self.cell_height, self.cell_width),
                    18 => _ = writeWindowOpCharsReply(&writer, screen.grid.rows, screen.grid.cols),
                    19 => _ = writeWindowOpScreenCharsReply(&writer, screen.grid.rows, screen.grid.cols),
                    else => {},
                }
            }
        },
        'p' => { // DECRQM (requires '$' intermediate)
            if (csiIntermediatesEq(action, "!")) { // DECSTR (soft terminal reset)
                if (action.leader == 0 and !action.private) {
                    applyDecstr(self);
                }
                return;
            }
            if (!csiIntermediatesEq(action, "$")) return;
            // DECRQM is valid only with exactly one parameter; invalid cardinality is ignored.
            if (param_len != 1) return;
            if (action.leader == '?' and action.private) {
                const mode = p[0];
                if (self.lockPtyWriter()) |writer_guard| {
                    var writer = writer_guard;
                    defer writer.unlock();
                    const state = decrqmPrivateModeState(self, screen, mode);
                    _ = writeDecrqmReply(&writer, true, mode, state);
                }
                return;
            }
            if (action.leader == 0 and !action.private) {
                const mode = p[0];
                if (self.lockPtyWriter()) |writer_guard| {
                    var writer = writer_guard;
                    defer writer.unlock();
                    const state = decrqmAnsiModeState(screen, mode);
                    _ = writeDecrqmReply(&writer, false, mode, state);
                }
            }
        },
        'h' => { // SM
            if (!action.private) {
                var idx: u8 = 0;
                while (idx < param_len and idx < p.len) : (idx += 1) {
                    const mode = p[idx];
                    switch (mode) {
                        4 => self.activeScreen().*.setInsertMode(true),
                        12 => self.activeScreen().*.setLocalEchoMode12(true),
                        20 => self.activeScreen().*.setNewlineMode(true),
                        else => {},
                    }
                }
                return;
            }
            if (action.leader == '?') {
                var idx: u8 = 0;
                while (idx < param_len and idx < p.len) : (idx += 1) {
                    const mode = p[idx];
                    switch (mode) {
                        1 => {
                            self.setAppCursorKeysLocked(true);
                        },
                        3 => self.setColumnMode132Locked(true),
                        5 => self.activeScreen().*.setScreenReverse(true),
                        6 => self.activeScreen().*.setOriginMode(true),
                        7 => self.activeScreen().*.setAutowrap(true),
                        8 => {
                            self.setAutoRepeatLocked(true);
                        },
                        9 => {
                            self.setMouseModeX10Locked(true);
                        },
                        12 => self.activeScreen().*.setCursorBlink(true),
                        45 => self.activeScreen().*.setReverseWrap(true),
                        69 => self.activeScreen().*.setLeftRightMarginMode69(true),
                        25 => self.activeScreen().setCursorVisible(true),
                        47 => self.enterAltScreen(false, false),
                        1047 => self.enterAltScreen(true, false),
                        1048 => {
                            self.saveCursor();
                            self.activeScreen().*.setSaveCursorMode1048(true);
                        },
                        1049 => self.enterAltScreen(true, true),
                        2004 => {
                            self.setBracketedPasteLocked(true);
                        },
                        2026 => self.setSyncUpdatesLocked(true),
                        2027 => {
                            self.grapheme_cluster_shaping_2027 = true;
                            self.primary.setGraphemeClusterShaping2027(true);
                            self.alt.setGraphemeClusterShaping2027(true);
                        },
                        2031 => self.report_color_scheme_2031 = true,
                        2048 => self.inband_resize_notifications_2048 = true,
                        1004 => {
                            self.setFocusReportingLocked(true);
                        },
                        1000 => {
                            self.setMouseModeX10Locked(true);
                        },
                        1002 => {
                            self.setMouseModeButtonLocked(true);
                        },
                        1003 => {
                            self.setMouseModeAnyLocked(true);
                        },
                        1006 => {
                            self.setMouseModeSgrLocked(true);
                        },
                        1007 => {
                            self.setMouseAlternateScrollLocked(true);
                        },
                        1016 => {
                            self.setMouseModeSgrPixelsLocked(true);
                        },
                        5522 => self.kitty_paste_events_5522 = true,
                        else => {},
                    }
                }
                return;
            }
        },
        'l' => { // RM
            if (!action.private) {
                var idx: u8 = 0;
                while (idx < param_len and idx < p.len) : (idx += 1) {
                    const mode = p[idx];
                    switch (mode) {
                        4 => self.activeScreen().*.setInsertMode(false),
                        12 => self.activeScreen().*.setLocalEchoMode12(false),
                        20 => self.activeScreen().*.setNewlineMode(false),
                        else => {},
                    }
                }
                return;
            }
            if (action.leader == '?') {
                var idx: u8 = 0;
                while (idx < param_len and idx < p.len) : (idx += 1) {
                    const mode = p[idx];
                    switch (mode) {
                        1 => {
                            self.setAppCursorKeysLocked(false);
                        },
                        3 => self.setColumnMode132Locked(false),
                        5 => self.activeScreen().*.setScreenReverse(false),
                        6 => self.activeScreen().*.setOriginMode(false),
                        7 => self.activeScreen().*.setAutowrap(false),
                        8 => {
                            self.setAutoRepeatLocked(false);
                        },
                        9 => {
                            self.setMouseModeX10Locked(false);
                        },
                        12 => self.activeScreen().*.setCursorBlink(false),
                        45 => self.activeScreen().*.setReverseWrap(false),
                        69 => self.activeScreen().*.setLeftRightMarginMode69(false),
                        25 => self.activeScreen().setCursorVisible(false),
                        47 => self.exitAltScreen(false),
                        1047 => self.exitAltScreen(false),
                        1048 => {
                            self.restoreCursor();
                            self.activeScreen().*.setSaveCursorMode1048(false);
                        },
                        1049 => self.exitAltScreen(true),
                        2004 => {
                            self.setBracketedPasteLocked(false);
                        },
                        2026 => self.setSyncUpdatesLocked(false),
                        2027 => {
                            self.grapheme_cluster_shaping_2027 = false;
                            self.primary.setGraphemeClusterShaping2027(false);
                            self.alt.setGraphemeClusterShaping2027(false);
                        },
                        2031 => self.report_color_scheme_2031 = false,
                        2048 => self.inband_resize_notifications_2048 = false,
                        1004 => {
                            self.setFocusReportingLocked(false);
                        },
                        1000 => {
                            self.setMouseModeX10Locked(false);
                        },
                        1002 => {
                            self.setMouseModeButtonLocked(false);
                        },
                        1003 => {
                            self.setMouseModeAnyLocked(false);
                        },
                        1006 => {
                            self.setMouseModeSgrLocked(false);
                        },
                        1007 => {
                            self.setMouseAlternateScrollLocked(false);
                        },
                        1016 => {
                            self.setMouseModeSgrPixelsLocked(false);
                        },
                        5522 => self.kitty_paste_events_5522 = false,
                        else => {},
                    }
                }
                return;
            }
        },
        else => {},
    }
}

pub fn writeDaPrimaryReply(pty: anytype) bool {
    const log = app_logger.logger("terminal.csi");
    _ = pty.write("\x1b[?62;1;2;4;6;7;8;9;15;18;21;22;28;29c") catch |err| {
        log.logf(.warning, "DA primary reply write failed: {s}", .{@errorName(err)});
        return false;
    };
    return true;
}

pub fn writeDsrReply(pty: anytype, leader: u8, mode: i32, row_1: usize, col_1: usize) bool {
    const log = app_logger.logger("terminal.csi");
    if (leader == '?') {
        switch (mode) {
            6 => {
                var buf: [32]u8 = undefined;
                const seq = std.fmt.bufPrint(&buf, "\x1b[?{d};{d}R", .{ row_1, col_1 }) catch |err| {
                    log.logf(.warning, "DSR private cursor reply format failed: {s}", .{@errorName(err)});
                    return false;
                };
                _ = pty.write(seq) catch |err| {
                    log.logf(.warning, "DSR private cursor reply write failed: {s}", .{@errorName(err)});
                    return false;
                };
                return true;
            },
            15 => return writeConst(pty, "\x1b[?10n"),
            25 => return writeConst(pty, "\x1b[?20n"),
            26 => return writeConst(pty, "\x1b[?27;1;0;0n"),
            55 => return writeConst(pty, "\x1b[?50n"),
            56 => return writeConst(pty, "\x1b[?57;0n"),
            75 => return writeConst(pty, "\x1b[?70n"),
            85 => return writeConst(pty, "\x1b[?83n"),
            else => return false,
        }
    }
    if (leader == 0) {
        switch (mode) {
            5 => return writeConst(pty, "\x1b[0n"),
            6 => {
                var buf: [32]u8 = undefined;
                const seq = std.fmt.bufPrint(&buf, "\x1b[{d};{d}R", .{ row_1, col_1 }) catch |err| {
                    log.logf(.warning, "DSR cursor reply format failed: {s}", .{@errorName(err)});
                    return false;
                };
                _ = pty.write(seq) catch |err| {
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

pub fn writeDecrqmReply(pty: anytype, private: bool, mode: i32, state: DecrpmState) bool {
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
    _ = pty.write(bytes) catch |err| {
        log.logf(.warning, "DECRQM reply write failed mode={d} private={d}: {s}", .{ mode, @as(u8, @intFromBool(private)), @errorName(err) });
        return false;
    };
    return true;
}

fn applyDecstr(self: anytype) void {
    // DECSTR is a soft reset: reset parser/mode state but preserve screen contents,
    // scrollback, and kitty graphics. Do not call the hard reset path.
    self.parser.reset();
    self.saved_charset = .{};
    self.title_buffer.clearRetainingCapacity();
    self.title = "Terminal";

    self.report_color_scheme_2031 = false;
    self.grapheme_cluster_shaping_2027 = false;
    self.primary.setGraphemeClusterShaping2027(false);
    self.alt.setGraphemeClusterShaping2027(false);
    self.inband_resize_notifications_2048 = false;
    self.kitty_paste_events_5522 = false;
    self.resetInputModesLocked();
    self.column_mode_132 = false;
    self.setSyncUpdatesLocked(false);

    // Reset kitty graphics state across both screens as part of DECSTR.
    // This follows foot-style soft reset behavior and avoids hidden-screen leaks.
    self.clearAllKittyImages();

    const screen = self.activeScreen();
    screen.resetState();
    screen.markDirtyAllWithReason(.decstr_soft_reset, @src());
}

fn decrqmPrivateModeState(self: anytype, screen: anytype, mode: i32) DecrpmState {
    return switch (mode) {
        1 => boolModeState(self.appCursorKeysEnabled()),
        3 => boolModeState(self.column_mode_132),
        5 => boolModeState(screen.screen_reverse),
        6 => boolModeState(screen.origin_mode),
        7 => boolModeState(screen.auto_wrap),
        8 => boolModeState(self.autoRepeatEnabled()),
        9 => boolModeState(self.mouseModeX10Enabled()),
        12 => boolModeState(screen.cursor_style.blink),
        25 => boolModeState(screen.cursor_visible),
        45 => boolModeState(screen.reverse_wrap),
        69 => boolModeState(screen.left_right_margin_mode_69),
        47, 1047, 1049 => boolModeState(self.active == .alt),
        1048 => boolModeState(screen.save_cursor_mode_1048),
        66 => boolModeState(self.appKeypadEnabled()),
        67 => .permanently_reset, // DECBKM (backarrow key mode) not supported
        1000 => boolModeState(self.mouseModeX10Enabled()),
        1001 => .permanently_reset, // Mouse highlight tracking not supported
        1002 => boolModeState(self.mouseModeButtonEnabled()),
        1003 => boolModeState(self.mouseModeAnyEnabled()),
        1004 => boolModeState(self.focusReportingEnabled()),
        1005 => .permanently_reset, // UTF-8 mouse encoding not supported
        1006 => boolModeState(self.mouseModeSgrEnabled()),
        1007 => boolModeState(self.mouseAlternateScrollEnabled()),
        1015 => .permanently_reset, // urxvt mouse encoding not supported
        1016 => boolModeState(self.mouseModeSgrPixelsEnabled()),
        1034 => .permanently_reset, // 8-bit meta mode not supported
        1035 => .permanently_reset, // num lock modifier mode not supported
        1036 => .permanently_reset, // ESC-prefixed meta mode toggle not supported
        1042 => .permanently_reset, // bell action toggle not supported
        1070 => .permanently_reset, // sixel private palette mode not supported
        2004 => boolModeState(self.bracketedPasteEnabled()),
        2026 => boolModeState(self.sync_updates_active),
        2027 => boolModeState(self.grapheme_cluster_shaping_2027),
        2031 => boolModeState(self.report_color_scheme_2031),
        2048 => boolModeState(self.inband_resize_notifications_2048),
        5522 => boolModeState(self.kitty_paste_events_5522),
        else => .not_recognized,
    };
}

fn decrqmAnsiModeState(screen: anytype, mode: i32) DecrpmState {
    return switch (mode) {
        4 => boolModeState(screen.insert_mode),
        12 => boolModeState(screen.local_echo_mode_12),
        20 => boolModeState(screen.newline_mode),
        else => .not_recognized,
    };
}

fn boolModeState(enabled: bool) DecrpmState {
    return if (enabled) .set else .reset;
}

fn writeConst(pty: anytype, seq: []const u8) bool {
    const log = app_logger.logger("terminal.csi");
    _ = pty.write(seq) catch |err| {
        log.logf(.warning, "CSI const reply write failed: {s}", .{@errorName(err)});
        return false;
    };
    return true;
}

pub fn writeColorSchemePreferenceReply(pty: anytype, dark: bool) bool {
    const log = app_logger.logger("terminal.csi");
    var buf: [16]u8 = undefined;
    const seq = std.fmt.bufPrint(&buf, "\x1b[?997;{d}n", .{if (dark) @as(u8, 1) else @as(u8, 2)}) catch |err| {
        log.logf(.warning, "color scheme preference reply format failed: {s}", .{@errorName(err)});
        return false;
    };
    _ = pty.write(seq) catch |err| {
        log.logf(.warning, "color scheme preference reply write failed: {s}", .{@errorName(err)});
        return false;
    };
    return true;
}

pub fn writeWindowOpCharsReply(pty: anytype, rows: u16, cols: u16) bool {
    const log = app_logger.logger("terminal.csi");
    var buf: [32]u8 = undefined;
    const seq = std.fmt.bufPrint(&buf, "\x1b[8;{d};{d}t", .{ rows, cols }) catch |err| {
        log.logf(.warning, "window chars reply format failed: {s}", .{@errorName(err)});
        return false;
    };
    _ = pty.write(seq) catch |err| {
        log.logf(.warning, "window chars reply write failed: {s}", .{@errorName(err)});
        return false;
    };
    return true;
}

pub fn writeWindowOpScreenCharsReply(pty: anytype, rows: u16, cols: u16) bool {
    const log = app_logger.logger("terminal.csi");
    var buf: [32]u8 = undefined;
    const seq = std.fmt.bufPrint(&buf, "\x1b[9;{d};{d}t", .{ rows, cols }) catch |err| {
        log.logf(.warning, "window screen chars reply format failed: {s}", .{@errorName(err)});
        return false;
    };
    _ = pty.write(seq) catch |err| {
        log.logf(.warning, "window screen chars reply write failed: {s}", .{@errorName(err)});
        return false;
    };
    return true;
}

pub fn writeWindowOpPixelsReply(pty: anytype, height_px: u32, width_px: u32) bool {
    const log = app_logger.logger("terminal.csi");
    var buf: [40]u8 = undefined;
    const seq = std.fmt.bufPrint(&buf, "\x1b[4;{d};{d}t", .{ height_px, width_px }) catch |err| {
        log.logf(.warning, "window pixels reply format failed: {s}", .{@errorName(err)});
        return false;
    };
    _ = pty.write(seq) catch |err| {
        log.logf(.warning, "window pixels reply write failed: {s}", .{@errorName(err)});
        return false;
    };
    return true;
}

pub fn writeWindowOpCellPixelsReply(pty: anytype, cell_h: u16, cell_w: u16) bool {
    const log = app_logger.logger("terminal.csi");
    var buf: [32]u8 = undefined;
    const seq = std.fmt.bufPrint(&buf, "\x1b[6;{d};{d}t", .{ cell_h, cell_w }) catch |err| {
        log.logf(.warning, "window cell pixels reply format failed: {s}", .{@errorName(err)});
        return false;
    };
    _ = pty.write(seq) catch |err| {
        log.logf(.warning, "window cell pixels reply write failed: {s}", .{@errorName(err)});
        return false;
    };
    return true;
}

pub fn applySgr(self: anytype, action: parser_csi.CsiAction) void {
    const screen = self.activeScreen();
    const params = action.params;
    const n_params = effectiveSgrParamCount(action);
    const log = app_logger.logger("terminal.sgr");
    log.logf(
        .debug,
        "sgr count={d} params={d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}",
        .{
            n_params,
            params[0],
            params[1],
            params[2],
            params[3],
            params[4],
            params[5],
            params[6],
            params[7],
            params[8],
            params[9],
            params[10],
            params[11],
            params[12],
            params[13],
            params[14],
            params[15],
        },
    );
    var i: usize = 0;
    while (i < n_params) {
        const p = params[i];
        if (p == 38 or p == 48 or p == 58) {
            if (i + 1 < n_params) {
                const mode = params[i + 1];
                if (mode == 5 and i + 2 < n_params) {
                    const idx = types.clampColorIndex(params[i + 2]);
                    const color = self.paletteColor(idx);
                    switch (p) {
                        38 => screen.current_attrs.fg = color,
                        48 => screen.current_attrs.bg = color,
                        58 => screen.current_attrs.underline_color = color,
                        else => {},
                    }
                    i += 3;
                    continue;
                }
                if (mode == 2) {
                    // Parse 38/48/58;2;R;G;B (truecolor).
                    const base: usize = i + 2;
                    if (base + 2 < n_params) {
                        const r = types.clampColorIndex(params[base]);
                        const g = types.clampColorIndex(params[base + 1]);
                        const b = types.clampColorIndex(params[base + 2]);
                        const color = Color{ .r = r, .g = g, .b = b, .a = 255 };
                        switch (p) {
                            38 => screen.current_attrs.fg = color,
                            48 => screen.current_attrs.bg = color,
                            58 => screen.current_attrs.underline_color = color,
                            else => {},
                        }
                        i = base + 3;
                        continue;
                    }
                }
                if (mode == 6) {
                    // WezTerm extension: RGBA (38;6;R;G;B;A).
                    const base: usize = i + 2;
                    if (base + 3 < n_params) {
                        const r = types.clampColorIndex(params[base]);
                        const g = types.clampColorIndex(params[base + 1]);
                        const b = types.clampColorIndex(params[base + 2]);
                        const a = types.clampColorIndex(params[base + 3]);
                        const color = Color{ .r = r, .g = g, .b = b, .a = a };
                        switch (p) {
                            38 => screen.current_attrs.fg = color,
                            48 => screen.current_attrs.bg = color,
                            58 => screen.current_attrs.underline_color = color,
                            else => {},
                        }
                        i = base + 4;
                        continue;
                    }
                }
            }
            i += 1;
            continue;
        }
        switch (p) {
            0 => { // reset
                screen.current_attrs = screen.default_attrs;
            },
            1 => { // bold
                screen.current_attrs.bold = true;
            },
            5 => { // blink (slow)
                screen.current_attrs.blink = true;
                screen.current_attrs.blink_fast = false;
            },
            6 => { // blink (fast)
                screen.current_attrs.blink = true;
                screen.current_attrs.blink_fast = true;
            },
            22 => { // normal intensity
                screen.current_attrs.bold = false;
            },
            25 => { // blink off
                screen.current_attrs.blink = false;
                screen.current_attrs.blink_fast = false;
            },
            4 => { // underline
                screen.current_attrs.underline = true;
            },
            24 => { // underline off
                screen.current_attrs.underline = false;
            },
            7 => { // reverse
                screen.current_attrs.reverse = true;
            },
            27 => { // reverse off
                screen.current_attrs.reverse = false;
            },
            39 => { // default fg
                screen.current_attrs.fg = screen.default_attrs.fg;
            },
            49 => { // default bg
                screen.current_attrs.bg = screen.default_attrs.bg;
            },
            59 => {
                screen.current_attrs.underline_color = screen.default_attrs.underline_color;
            },
            30...37 => {
                const idx: u8 = @intCast(p - 30);
                screen.current_attrs.fg = self.paletteColor(idx);
            },
            40...47 => {
                const idx: u8 = @intCast(p - 40);
                screen.current_attrs.bg = self.paletteColor(idx);
            },
            90...97 => {
                const idx: u8 = @intCast(8 + (p - 90));
                screen.current_attrs.fg = self.paletteColor(idx);
            },
            100...107 => {
                const idx: u8 = @intCast(8 + (p - 100));
                screen.current_attrs.bg = self.paletteColor(idx);
            },
            else => {},
        }
        i += 1;
    }
}

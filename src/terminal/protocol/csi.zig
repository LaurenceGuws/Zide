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

pub fn handleCsi(self: anytype, action: parser_csi.CsiAction) void {
    const log = app_logger.logger("terminal.csi");
    if (log.enabled_file or log.enabled_console) {
        log.logf(
            "csi final={c} leader={c} private={d} interm={s} count={d} params={d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}",
            .{
                action.final,
                if (action.leader == 0) '.' else action.leader,
                @as(u8, @intFromBool(action.private)),
                action.intermediates[0..action.intermediates_len],
                action.count,
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
    }
    const p = action.params;
    const count = action.count;
    const param_len: u8 = if (count == 0 and p[0] == 0) 0 else count + 1;
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
            if (top <= bot) {
                screen.setScrollRegion(top, bot);
            }
        },
        's' => { // SCP
            if (!action.private) {
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
                '>' => self.keyModePush(flags),
                '<' => self.keyModePop(if (param_len > 0) @intCast(@max(1, p[0])) else 1),
                '=' => self.keyModeModify(flags, mode),
                '?' => self.keyModeQuery(),
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
            if (self.pty) |*pty| {
                if (action.leader == '?') {
                    switch (mode) {
                        6 => { // DECXCPR
                            const pos = screen.cursorReport();
                            _ = writeDsrReply(pty, action.leader, mode, pos.row_1, pos.col_1);
                        },
                        15, 25, 26, 55, 56, 75, 85 => _ = writeDsrReply(pty, action.leader, mode, 0, 0),
                        else => {},
                    }
                } else if (action.leader == 0) {
                    switch (mode) {
                        5 => _ = writeDsrReply(pty, action.leader, mode, 0, 0),
                        6 => { // Cursor position report
                            const pos = screen.cursorReport();
                            _ = writeDsrReply(pty, action.leader, mode, pos.row_1, pos.col_1);
                        },
                        else => {},
                    }
                }
            }
        },
        'c' => { // DA
            if (action.leader == 0 or action.leader == '?') {
                if (self.pty) |*pty| {
                    _ = writeDaPrimaryReply(pty);
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
            if (action.leader == '?' and action.private) {
                const mode = if (param_len > 0) p[0] else 0;
                if (self.pty) |*pty| {
                    const state = decrqmPrivateModeState(self, screen, mode);
                    _ = writeDecrqmReply(pty, true, mode, state);
                }
                return;
            }
            if (action.leader == 0 and !action.private) {
                const mode = if (param_len > 0) p[0] else 0;
                if (self.pty) |*pty| {
                    const state = decrqmAnsiModeState(screen, mode);
                    _ = writeDecrqmReply(pty, false, mode, state);
                }
            }
        },
        'h' => { // SM
            if (!action.private) {
                var idx: u8 = 0;
                while (idx < param_len and idx < p.len) : (idx += 1) {
                    const mode = p[idx];
                    if (mode == 20) {
                        self.activeScreen().*.setNewlineMode(true);
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
                            self.app_cursor_keys = true;
                            self.updateInputSnapshot();
                        },
                        3 => self.setColumnMode132(true),
                        5 => self.activeScreen().*.setScreenReverse(true),
                        6 => self.activeScreen().*.setOriginMode(true),
                        25 => self.activeScreen().setCursorVisible(true),
                        7 => self.activeScreen().*.setAutowrap(true),
                        47 => self.enterAltScreen(false, false),
                        1047 => self.enterAltScreen(true, false),
                        1048 => self.saveCursor(),
                        1049 => self.enterAltScreen(true, true),
                        2004 => self.bracketed_paste = true,
                        2026 => self.setSyncUpdates(true),
                        1004 => {
                            self.focus_reporting = true;
                            self.updateInputSnapshot();
                        },
                        1000 => {
                            self.input.mouse_mode_x10 = true;
                            self.updateInputSnapshot();
                        },
                        1002 => {
                            self.input.mouse_mode_button = true;
                            self.updateInputSnapshot();
                        },
                        1003 => {
                            self.input.mouse_mode_any = true;
                            self.updateInputSnapshot();
                        },
                        1006 => {
                            self.input.mouse_mode_sgr = true;
                            self.updateInputSnapshot();
                        },
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
                    if (mode == 20) {
                        self.activeScreen().*.setNewlineMode(false);
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
                            self.app_cursor_keys = false;
                            self.updateInputSnapshot();
                        },
                        3 => self.setColumnMode132(false),
                        5 => self.activeScreen().*.setScreenReverse(false),
                        6 => self.activeScreen().*.setOriginMode(false),
                        25 => self.activeScreen().setCursorVisible(false),
                        7 => self.activeScreen().*.setAutowrap(false),
                        47 => self.exitAltScreen(false),
                        1047 => self.exitAltScreen(false),
                        1048 => self.restoreCursor(),
                        1049 => self.exitAltScreen(true),
                        2004 => self.bracketed_paste = false,
                        2026 => self.setSyncUpdates(false),
                        1004 => {
                            self.focus_reporting = false;
                            self.updateInputSnapshot();
                        },
                        1000 => {
                            self.input.mouse_mode_x10 = false;
                            self.updateInputSnapshot();
                        },
                        1002 => {
                            self.input.mouse_mode_button = false;
                            self.updateInputSnapshot();
                        },
                        1003 => {
                            self.input.mouse_mode_any = false;
                            self.updateInputSnapshot();
                        },
                        1006 => {
                            self.input.mouse_mode_sgr = false;
                            self.updateInputSnapshot();
                        },
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
    _ = pty.write("\x1b[?62;1;2;4;6;7;8;9;15;18;21;22;28;29c") catch return false;
    return true;
}

pub fn writeDsrReply(pty: anytype, leader: u8, mode: i32, row_1: usize, col_1: usize) bool {
    if (leader == '?') {
        switch (mode) {
            6 => {
                var buf: [32]u8 = undefined;
                const seq = std.fmt.bufPrint(&buf, "\x1b[?{d};{d}R", .{ row_1, col_1 }) catch return false;
                _ = pty.write(seq) catch return false;
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
                const seq = std.fmt.bufPrint(&buf, "\x1b[{d};{d}R", .{ row_1, col_1 }) catch return false;
                _ = pty.write(seq) catch return false;
                return true;
            },
            else => return false,
        }
    }
    return false;
}

pub fn writeDecrqmReply(pty: anytype, private: bool, mode: i32, state: DecrpmState) bool {
    var buf: [32]u8 = undefined;
    const seq = if (private)
        std.fmt.bufPrint(&buf, "\x1b[?{d};{d}$y", .{ mode, @intFromEnum(state) })
    else
        std.fmt.bufPrint(&buf, "\x1b[{d};{d}$y", .{ mode, @intFromEnum(state) });
    const bytes = seq catch return false;
    _ = pty.write(bytes) catch return false;
    return true;
}

fn applyDecstr(self: anytype) void {
    // DECSTR is a soft reset: reset parser/mode state but preserve screen contents,
    // scrollback, and kitty graphics. Do not call the hard reset path.
    self.parser.reset();
    self.saved_charset = .{};

    self.app_cursor_keys = false;
    self.app_keypad = false;
    self.input.resetMouse();
    self.bracketed_paste = false;
    self.focus_reporting = false;
    self.column_mode_132 = false;
    self.setSyncUpdates(false);

    const screen = self.activeScreen();
    screen.resetState();
    screen.markDirtyAll();

    self.updateInputSnapshot();
}

fn decrqmPrivateModeState(self: anytype, screen: anytype, mode: i32) DecrpmState {
    return switch (mode) {
        1 => boolModeState(self.app_cursor_keys),
        3 => boolModeState(self.column_mode_132),
        5 => boolModeState(screen.screen_reverse),
        6 => boolModeState(screen.origin_mode),
        7 => boolModeState(screen.auto_wrap),
        9 => .not_recognized, // Legacy X10 mouse mode (?9) not yet supported in DECSET/DECRQM scope
        25 => boolModeState(screen.cursor_visible),
        45 => .not_recognized, // Reverse-wrap mode not yet implemented
        47, 1047, 1049 => boolModeState(self.active == .alt),
        66 => boolModeState(self.app_keypad),
        67 => .permanently_reset, // DECBKM (backarrow key mode) not supported
        1000 => boolModeState(self.input.mouse_mode_x10),
        1001 => .permanently_reset, // Mouse highlight tracking not supported
        1002 => boolModeState(self.input.mouse_mode_button),
        1003 => boolModeState(self.input.mouse_mode_any),
        1004 => boolModeState(self.focus_reporting),
        1005 => .permanently_reset, // UTF-8 mouse encoding not supported
        1006 => boolModeState(self.input.mouse_mode_sgr),
        1015 => .permanently_reset, // urxvt mouse encoding not supported
        1016 => .not_recognized, // SGR pixel mouse encoding not yet supported
        1034 => .permanently_reset, // 8-bit meta mode not supported
        1035 => .permanently_reset, // num lock modifier mode not supported
        1036 => .permanently_reset, // ESC-prefixed meta mode toggle not supported
        1042 => .permanently_reset, // bell action toggle not supported
        1070 => .permanently_reset, // sixel private palette mode not supported
        2004 => boolModeState(self.bracketed_paste),
        2026 => boolModeState(self.sync_updates_active),
        2031 => .not_recognized, // theme change reporting not yet supported
        2048 => .not_recognized, // size notifications not yet supported
        5522 => .not_recognized, // kitty clipboard protocol mode not yet supported
        else => .not_recognized,
    };
}

fn decrqmAnsiModeState(screen: anytype, mode: i32) DecrpmState {
    return switch (mode) {
        20 => boolModeState(screen.newline_mode),
        else => .not_recognized,
    };
}

fn boolModeState(enabled: bool) DecrpmState {
    return if (enabled) .set else .reset;
}

fn writeConst(pty: anytype, seq: []const u8) bool {
    _ = pty.write(seq) catch return false;
    return true;
}

pub fn applySgr(self: anytype, action: parser_csi.CsiAction) void {
    const screen = self.activeScreen();
    const params = action.params;
    const total = params.len;
    const n_params: usize = if (action.count == 0 and params[0] == 0) 1 else @min(@as(usize, action.count + 1), total);
    const log = app_logger.logger("terminal.sgr");
    if (log.enabled_file or log.enabled_console) {
        log.logf(
            "sgr count={d} params={d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}",
            .{
                action.count,
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
    }
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

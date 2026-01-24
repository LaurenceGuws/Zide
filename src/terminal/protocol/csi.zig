const std = @import("std");
const types = @import("../model/types.zig");
const parser_csi = @import("../parser/csi.zig");
const app_logger = @import("../../app_logger.zig");

const Color = types.Color;

pub fn handleCsi(self: anytype, action: parser_csi.CsiAction) void {
    const log = app_logger.logger("terminal.csi");
    if (log.enabled_file or log.enabled_console) {
        log.logf(
            "csi final={c} leader={c} private={d} count={d} params={d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}",
            .{
                action.final,
                if (action.leader == 0) '.' else action.leader,
                @as(u8, @intFromBool(action.private)),
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
            const mode = if (count > 0) p[0] else 0;
            self.eraseDisplay(mode);
        },
        'K' => { // EL
            const mode = if (count > 0) p[0] else 0;
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
        'r' => { // DECSTBM
            const top_1 = if (count > 0 and p[0] > 0) p[0] else 1;
            const bot_1 = if (count > 1 and p[1] > 0) p[1] else @as(i32, @intCast(screen.grid.rows));
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
            const param_len: u8 = if (count == 0 and p[0] == 0) 0 else count + 1;
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
                const param_len: u8 = if (count == 0 and p[0] == 0) 0 else count + 1;
                const mode = if (param_len > 0) p[0] else 0;
                self.setCursorStyle(mode);
            }
        },
        'n' => { // DSR
            const param_len: u8 = if (count == 0 and p[0] == 0) 0 else count + 1;
            const mode = if (param_len > 0) p[0] else 0;
            if (self.pty) |*pty| {
                var buf: [32]u8 = undefined;
                if (action.leader == '?') {
                    switch (mode) {
                        6 => { // DECXCPR
                            const row_1 = screen.cursor.row + 1;
                            const col_1 = screen.cursor.col + 1;
                            const seq = std.fmt.bufPrint(&buf, "\x1b[?{d};{d}R", .{ row_1, col_1 }) catch return;
                            _ = pty.write(seq) catch {};
                        },
                        15 => { // Printer status
                            _ = pty.write("\x1b[?10n") catch {};
                        },
                        25 => { // UDK status
                            _ = pty.write("\x1b[?20n") catch {};
                        },
                        26 => { // Keyboard status
                            _ = pty.write("\x1b[?27;1;0;0n") catch {};
                        },
                        55 => { // Locator status
                            _ = pty.write("\x1b[?50n") catch {};
                        },
                        56 => { // Locator type
                            _ = pty.write("\x1b[?57;0n") catch {};
                        },
                        75 => { // Data integrity
                            _ = pty.write("\x1b[?70n") catch {};
                        },
                        85 => { // Multi-session config
                            _ = pty.write("\x1b[?83n") catch {};
                        },
                        else => {},
                    }
                } else if (action.leader == 0) {
                    switch (mode) {
                        5 => { // Device status report
                            _ = pty.write("\x1b[0n") catch {};
                        },
                        6 => { // Cursor position report
                            const row_1 = screen.cursor.row + 1;
                            const col_1 = screen.cursor.col + 1;
                            const seq = std.fmt.bufPrint(&buf, "\x1b[{d};{d}R", .{ row_1, col_1 }) catch return;
                            _ = pty.write(seq) catch {};
                        },
                        else => {},
                    }
                }
            }
        },
        'c' => { // DA
            if (action.leader == 0 or action.leader == '?') {
                if (self.pty) |*pty| {
                    _ = pty.write("\x1b[?62;1;2;4;6;7;8;9;15;18;21;22;28;29c") catch {};
                }
            }
        },
        'h' => { // SM
            if (action.leader == '?') {
                const param_len: u8 = if (count == 0 and p[0] == 0) 0 else count + 1;
                var idx: u8 = 0;
                while (idx < param_len and idx < p.len) : (idx += 1) {
                    const mode = p[idx];
                    switch (mode) {
                        1 => self.app_cursor_keys = true,
                        25 => self.activeScreen().cursor_visible = true,
                        47 => self.enterAltScreen(false, false),
                        1047 => self.enterAltScreen(true, false),
                        1048 => self.saveCursor(),
                        1049 => self.enterAltScreen(true, true),
                        2004 => self.bracketed_paste = true,
                        1000 => self.input.mouse_mode_x10 = true,
                        1002 => self.input.mouse_mode_button = true,
                        1003 => self.input.mouse_mode_any = true,
                        1006 => self.input.mouse_mode_sgr = true,
                        else => {},
                    }
                }
                return;
            }
        },
        'l' => { // RM
            if (action.leader == '?') {
                const param_len: u8 = if (count == 0 and p[0] == 0) 0 else count + 1;
                var idx: u8 = 0;
                while (idx < param_len and idx < p.len) : (idx += 1) {
                    const mode = p[idx];
                    switch (mode) {
                        1 => self.app_cursor_keys = false,
                        25 => self.activeScreen().cursor_visible = false,
                        47 => self.exitAltScreen(false),
                        1047 => self.exitAltScreen(false),
                        1048 => self.restoreCursor(),
                        1049 => self.exitAltScreen(true),
                        2004 => self.bracketed_paste = false,
                        1000 => self.input.mouse_mode_x10 = false,
                        1002 => self.input.mouse_mode_button = false,
                        1003 => self.input.mouse_mode_any = false,
                        1006 => self.input.mouse_mode_sgr = false,
                        else => {},
                    }
                }
                return;
            }
        },
        else => {},
    }
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
            22 => { // normal intensity
                screen.current_attrs.bold = false;
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
            58 => {
                screen.current_attrs.underline_color = screen.default_attrs.underline_color;
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

const std = @import("std");
const parser_csi = @import("../parser/csi.zig");
const input_modes = @import("../core/input_modes.zig");
const terminal_core_modes = @import("../core/terminal_core_modes.zig");
const terminal_core_protocol = @import("../core/protocol/terminal_core_protocol.zig");

pub fn handleSimpleCsi(
    self: anytype,
    action: parser_csi.CsiAction,
    param_len: usize,
    params: [parser_csi.max_params]i32,
) void {
    const get = struct {
        fn at(local_params: [parser_csi.max_params]i32, idx: u8, default: i32) i32 {
            return if (idx < parser_csi.max_params) local_params[idx] else default;
        }
    }.at;
    const screen = self.core.activeScreen();

    switch (action.final) {
        'A' => screen.cursorUp(@intCast(@max(1, get(params, 0, 1)))),
        'B' => screen.cursorDown(@intCast(@max(1, get(params, 0, 1)))),
        'C' => screen.cursorForward(@intCast(@max(1, get(params, 0, 1)))),
        'D' => screen.cursorBack(@intCast(@max(1, get(params, 0, 1)))),
        'E' => screen.cursorNextLine(@intCast(@max(1, get(params, 0, 1)))),
        'F' => screen.cursorPrevLine(@intCast(@max(1, get(params, 0, 1)))),
        'G' => screen.cursorColAbsolute(@max(1, get(params, 0, 1))),
        'I' => {
            var i: i32 = 0;
            const n = @max(1, get(params, 0, 1));
            while (i < n) : (i += 1) screen.tab();
        },
        'H', 'f' => screen.cursorPosAbsolute(@max(1, get(params, 0, 1)), @max(1, get(params, 1, 1))),
        'd' => screen.cursorRowAbsolute(@max(1, get(params, 0, 1))),
        'J' => terminal_core_protocol.eraseDisplay(self, if (param_len > 0) params[0] else 0),
        'K' => terminal_core_protocol.eraseLine(self, if (param_len > 0) params[0] else 0),
        '@' => terminal_core_protocol.insertChars(self, @intCast(@max(1, get(params, 0, 1)))),
        'P' => terminal_core_protocol.deleteChars(self, @intCast(@max(1, get(params, 0, 1)))),
        'X' => terminal_core_protocol.eraseChars(self, @intCast(@max(1, get(params, 0, 1)))),
        'L' => terminal_core_protocol.insertLines(self, @intCast(@max(1, get(params, 0, 1)))),
        'M' => terminal_core_protocol.deleteLines(self, @intCast(@max(1, get(params, 0, 1)))),
        'S' => {
            const count = @as(usize, @intCast(@max(1, get(params, 0, 1))));
            terminal_core_protocol.scrollRegionUpWithOrigin(self, count, "csi.S.scroll_region_up");
        },
        'T' => terminal_core_protocol.scrollRegionDown(self, @intCast(@max(1, get(params, 0, 1)))),
        'Z' => {
            var i: i32 = 0;
            const n = @max(1, get(params, 0, 1));
            while (i < n) : (i += 1) screen.backTab();
        },
        'r' => {
            const top_1 = if (param_len > 0 and params[0] > 0) params[0] else 1;
            const bot_1 = if (param_len > 1 and params[1] > 0) params[1] else @as(i32, @intCast(screen.grid.rows));
            const top = @min(@as(usize, screen.grid.rows - 1), @as(usize, @intCast(@max(1, top_1) - 1)));
            const bot = @min(@as(usize, screen.grid.rows - 1), @as(usize, @intCast(@max(1, bot_1) - 1)));
            if (top < bot) {
                screen.setScrollRegion(top, bot);
            }
        },
        else => {},
    }
}

pub fn handleSpecialCsi(
    self: anytype,
    action: parser_csi.CsiAction,
    param_len: usize,
    params: [parser_csi.max_params]i32,
) void {
    const screen = self.core.activeScreen();
    switch (action.final) {
        's' => {
            if (!action.private) {
                if (screen.left_right_margin_mode_69) {
                    const cols = @as(usize, screen.grid.cols);
                    if (cols == 0) return;
                    const left_1 = if (param_len > 0 and params[0] > 0) params[0] else 1;
                    const right_1 = if (param_len > 1 and params[1] > 0) params[1] else @as(i32, @intCast(cols));
                    const left = @min(cols - 1, @as(usize, @intCast(@max(1, left_1) - 1)));
                    const right = @min(cols - 1, @as(usize, @intCast(@max(1, right_1) - 1)));
                    if (left < right) {
                        screen.setLeftRightMargins(left, right);
                    }
                    return;
                }
                terminal_core_modes.saveCursor(self);
            }
        },
        'u' => {
            if (action.leader == 0 and !action.private) {
                terminal_core_modes.restoreCursor(self);
                return;
            }
            const flags: u32 = if (param_len > 0) @intCast(@max(0, params[0])) else 0;
            const mode: u32 = if (param_len > 1) @intCast(@max(0, params[1])) else 1;
            switch (action.leader) {
                '>' => input_modes.keyModePushLocked(self, flags),
                '<' => input_modes.keyModePopLocked(self, if (param_len > 0) @intCast(@max(1, params[0])) else 1),
                '=' => input_modes.keyModeModifyLocked(self, flags, mode),
                '?' => input_modes.keyModeQueryLocked(self),
                else => {},
            }
        },
        'q' => {
            if (action.leader == 0 and !action.private) {
                terminal_core_protocol.setCursorStyle(self, if (param_len > 0) params[0] else 0);
            }
        },
        'g' => {
            switch (if (param_len > 0) params[0] else 0) {
                0 => screen.clearTabAtCursor(),
                3 => screen.clearAllTabs(),
                else => {},
            }
        },
        else => {},
    }
}

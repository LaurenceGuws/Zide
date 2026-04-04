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

    switch (action.final) {
        'A' => self.core.cursorUpLocked(@intCast(@max(1, get(params, 0, 1)))),
        'B' => self.core.cursorDownLocked(@intCast(@max(1, get(params, 0, 1)))),
        'C' => self.core.cursorForwardLocked(@intCast(@max(1, get(params, 0, 1)))),
        'D' => self.core.cursorBackLocked(@intCast(@max(1, get(params, 0, 1)))),
        'E' => self.core.cursorNextLineLocked(@intCast(@max(1, get(params, 0, 1)))),
        'F' => self.core.cursorPrevLineLocked(@intCast(@max(1, get(params, 0, 1)))),
        'G' => self.core.cursorColAbsoluteLocked(@max(1, get(params, 0, 1))),
        'I' => {
            var i: i32 = 0;
            const n = @max(1, get(params, 0, 1));
            while (i < n) : (i += 1) self.core.tabLocked();
        },
        'H', 'f' => self.core.cursorPosAbsoluteLocked(@max(1, get(params, 0, 1)), @max(1, get(params, 1, 1))),
        'd' => self.core.cursorRowAbsoluteLocked(@max(1, get(params, 0, 1))),
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
            while (i < n) : (i += 1) self.core.backTabLocked();
        },
        'r' => {
            const screen = self.core.activeScreen();
            const top_1 = if (param_len > 0 and params[0] > 0) params[0] else 1;
            const bot_1 = if (param_len > 1 and params[1] > 0) params[1] else @as(i32, @intCast(screen.grid.rows));
            const top = @min(@as(usize, screen.grid.rows - 1), @as(usize, @intCast(@max(1, top_1) - 1)));
            const bot = @min(@as(usize, screen.grid.rows - 1), @as(usize, @intCast(@max(1, bot_1) - 1)));
            if (top < bot) {
                self.core.setScrollRegionLocked(top, bot);
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
    switch (action.final) {
        's' => {
            if (!action.private) {
                const screen = self.core.activeScreen();
                if (screen.left_right_margin_mode_69) {
                    const cols = @as(usize, screen.grid.cols);
                    if (cols == 0) return;
                    const left_1 = if (param_len > 0 and params[0] > 0) params[0] else 1;
                    const right_1 = if (param_len > 1 and params[1] > 0) params[1] else @as(i32, @intCast(cols));
                    const left = @min(cols - 1, @as(usize, @intCast(@max(1, left_1) - 1)));
                    const right = @min(cols - 1, @as(usize, @intCast(@max(1, right_1) - 1)));
                    if (left < right) {
                        self.core.setLeftRightMarginsLocked(left, right);
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
                self.core.setCursorStyleLocked(if (param_len > 0) params[0] else 0);
            }
        },
        'g' => {
            switch (if (param_len > 0) params[0] else 0) {
                0 => self.core.clearTabAtCursorLocked(),
                3 => self.core.clearAllTabsLocked(),
                else => {},
            }
        },
        else => {},
    }
}

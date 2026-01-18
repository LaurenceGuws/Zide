const std = @import("std");
const pty_mod = @import("../io/pty.zig");
const types = @import("../model/types.zig");

pub const InputState = struct {
    mouse_mode_x10: bool,
    mouse_mode_button: bool,
    mouse_mode_any: bool,
    mouse_mode_sgr: bool,
    mouse_last_row: usize,
    mouse_last_col: usize,
    mouse_last_buttons: u8,

    pub fn init() InputState {
        return .{
            .mouse_mode_x10 = false,
            .mouse_mode_button = false,
            .mouse_mode_any = false,
            .mouse_mode_sgr = false,
            .mouse_last_row = 0,
            .mouse_last_col = 0,
            .mouse_last_buttons = 0,
        };
    }

    pub fn resetMouse(self: *InputState) void {
        self.mouse_mode_x10 = false;
        self.mouse_mode_button = false;
        self.mouse_mode_any = false;
        self.mouse_mode_sgr = false;
        self.mouse_last_row = 0;
        self.mouse_last_col = 0;
        self.mouse_last_buttons = 0;
    }

    pub fn mouseTrackingActive(self: *const InputState) bool {
        return self.mouse_mode_x10 or self.mouse_mode_button or self.mouse_mode_any;
    }

    pub fn mouseMotionActive(self: *const InputState, buttons_down: bool) bool {
        return self.mouse_mode_any or (self.mouse_mode_button and buttons_down);
    }

    pub fn reportMouseEvent(self: *InputState, pty: *pty_mod.Pty, event: types.MouseEvent, rows: u16, cols: u16) !bool {
        if (!self.mouseTrackingActive()) return false;
        if (rows == 0 or cols == 0) return false;

        const row = @min(event.row, @as(usize, rows - 1));
        const col = @min(event.col, @as(usize, cols - 1));
        const buttons_down = event.buttons_down;
        const buttons_active = buttons_down != 0;
        const mod_bits = mouseModBits(event.mod);

        if (event.kind == .move) {
            if (!self.mouseMotionActive(buttons_active)) return false;
            if (row == self.mouse_last_row and col == self.mouse_last_col and buttons_down == self.mouse_last_buttons) {
                return false;
            }
        }

        var button = event.button;
        if (event.kind == .move) {
            button = mouseButtonFromMask(buttons_down);
        }
        if (event.kind == .release and !self.mouse_mode_sgr) {
            button = .none;
        }

        const base_code = mouseButtonCode(button);
        const motion_code: u8 = if (event.kind == .move) 32 else 0;
        const code = base_code + motion_code + mod_bits;

        if (self.mouse_mode_sgr) {
            var buf: [64]u8 = undefined;
            const terminator: u8 = if (event.kind == .release) 'm' else 'M';
            const seq = std.fmt.bufPrint(
                &buf,
                "\x1b[<{d};{d};{d}{c}",
                .{ code, col + 1, row + 1, terminator },
            ) catch return false;
            _ = try pty.write(seq);
        } else {
            var buf: [6]u8 = undefined;
            buf[0] = 0x1b;
            buf[1] = '[';
            buf[2] = 'M';
            buf[3] = @intCast(32 + code);
            buf[4] = mouseEncodeCoordX10(col);
            buf[5] = mouseEncodeCoordX10(row);
            _ = try pty.write(buf[0..6]);
        }

        self.mouse_last_row = row;
        self.mouse_last_col = col;
        self.mouse_last_buttons = buttons_down;
        return true;
    }
};

pub fn sendKey(pty: *pty_mod.Pty, key: types.Key, mod: types.Modifier, key_mode_flags: u32) !bool {
    if (sendKeyWithProtocol(pty, key, mod, key_mode_flags)) return true;
    const seq = switch (key) {
        types.VTERM_KEY_ENTER => "\r",
        types.VTERM_KEY_TAB => "\t",
        types.VTERM_KEY_BACKSPACE => "\x7f",
        types.VTERM_KEY_ESCAPE => "\x1b",
        types.VTERM_KEY_UP => "\x1b[A",
        types.VTERM_KEY_DOWN => "\x1b[B",
        types.VTERM_KEY_RIGHT => "\x1b[C",
        types.VTERM_KEY_LEFT => "\x1b[D",
        types.VTERM_KEY_HOME => "\x1b[H",
        types.VTERM_KEY_END => "\x1b[F",
        types.VTERM_KEY_PAGEUP => "\x1b[5~",
        types.VTERM_KEY_PAGEDOWN => "\x1b[6~",
        types.VTERM_KEY_INS => "\x1b[2~",
        types.VTERM_KEY_DEL => "\x1b[3~",
        else => "",
    };
    if (seq.len > 0) {
        _ = try pty.write(seq);
    }
    return seq.len > 0;
}

pub fn sendChar(pty: *pty_mod.Pty, char: u32, mod: types.Modifier, key_mode_flags: u32) !bool {
    if (char > 0x10FFFF or (char >= 0xD800 and char <= 0xDFFF)) return false;
    if (key_mode_flags == 0 and (mod & types.VTERM_MOD_CTRL) != 0) {
        if (ctrlChar(char)) |mapped| {
            if ((mod & types.VTERM_MOD_ALT) != 0) {
                _ = try pty.write(&[_]u8{0x1b});
            }
            _ = try pty.write(&[_]u8{mapped});
            return true;
        }
    }
    if (key_mode_flags == 0 and (mod & types.VTERM_MOD_ALT) != 0) {
        _ = try pty.write(&[_]u8{0x1b});
    }
    if (sendCharWithProtocol(pty, char, mod, key_mode_flags)) return true;
    var buf: [4]u8 = undefined;
    const len = std.unicode.utf8Encode(@intCast(char), &buf) catch return false;
    _ = try pty.write(buf[0..len]);
    return true;
}

pub fn sendText(pty: *pty_mod.Pty, text: []const u8) !void {
    if (text.len == 0) return;
    _ = try pty.write(text);
}

fn ctrlChar(char: u32) ?u8 {
    return switch (char) {
        'a'...'z' => @intCast(char - 'a' + 1),
        'A'...'Z' => @intCast(char - 'A' + 1),
        '@', ' ' => 0,
        '[' => 27,
        '\\' => 28,
        ']' => 29,
        '^' => 30,
        '_' => 31,
        '?' => 127,
        else => null,
    };
}

fn encodeModifier(mod: types.Modifier) u8 {
    var value: u8 = 1;
    if ((mod & types.VTERM_MOD_SHIFT) != 0) value += 1;
    if ((mod & types.VTERM_MOD_ALT) != 0) value += 2;
    if ((mod & types.VTERM_MOD_CTRL) != 0) value += 4;
    return value;
}

fn sendCsiWithMod(pty: *pty_mod.Pty, prefix: []const u8, mod_code: u8, suffix: []const u8) bool {
    var buf: [32]u8 = undefined;
    const seq = if (mod_code > 1)
        std.fmt.bufPrint(&buf, "\x1b[{s};{d}{s}", .{ prefix, mod_code, suffix }) catch return false
    else
        std.fmt.bufPrint(&buf, "\x1b[{s}{s}", .{ prefix, suffix }) catch return false;
    _ = pty.write(seq) catch return false;
    return true;
}

fn sendKeyWithProtocol(pty: *pty_mod.Pty, key: types.Key, mod: types.Modifier, flags: u32) bool {
    if (flags == 0) return false;

    const mod_code = encodeModifier(mod);
    if ((flags & key_mode_report_all_keys) == 0) {
        if (key == types.VTERM_KEY_ENTER or key == types.VTERM_KEY_TAB or key == types.VTERM_KEY_BACKSPACE) {
            return false;
        }
    }

    switch (key) {
        types.VTERM_KEY_UP => return sendCsiWithMod(pty, "1", mod_code, "A"),
        types.VTERM_KEY_DOWN => return sendCsiWithMod(pty, "1", mod_code, "B"),
        types.VTERM_KEY_RIGHT => return sendCsiWithMod(pty, "1", mod_code, "C"),
        types.VTERM_KEY_LEFT => return sendCsiWithMod(pty, "1", mod_code, "D"),
        types.VTERM_KEY_HOME => return sendCsiWithMod(pty, "1", mod_code, "H"),
        types.VTERM_KEY_END => return sendCsiWithMod(pty, "1", mod_code, "F"),
        types.VTERM_KEY_PAGEUP => return sendCsiWithMod(pty, "5", mod_code, "~"),
        types.VTERM_KEY_PAGEDOWN => return sendCsiWithMod(pty, "6", mod_code, "~"),
        types.VTERM_KEY_INS => return sendCsiWithMod(pty, "2", mod_code, "~"),
        types.VTERM_KEY_DEL => return sendCsiWithMod(pty, "3", mod_code, "~"),
        types.VTERM_KEY_ESCAPE => {
            var buf: [32]u8 = undefined;
            const seq = std.fmt.bufPrint(&buf, "\x1b[{d};{d}u", .{ 27, mod_code }) catch return false;
            _ = pty.write(seq) catch return false;
            return true;
        },
        else => return false,
    }
}

fn sendCharWithProtocol(pty: *pty_mod.Pty, char: u32, mod: types.Modifier, flags: u32) bool {
    if (flags == 0) return false;
    if (mod == types.VTERM_MOD_NONE and (flags & key_mode_report_all_keys) == 0) return false;
    const mod_code = encodeModifier(mod);
    var buf: [48]u8 = undefined;
    const seq = std.fmt.bufPrint(&buf, "\x1b[{d};{d}u", .{ char, mod_code }) catch return false;
    _ = pty.write(seq) catch return false;
    return true;
}

fn mouseModBits(mod: types.Modifier) u8 {
    var value: u8 = 0;
    if ((mod & types.VTERM_MOD_SHIFT) != 0) value += 4;
    if ((mod & types.VTERM_MOD_ALT) != 0) value += 8;
    if ((mod & types.VTERM_MOD_CTRL) != 0) value += 16;
    return value;
}

fn mouseButtonFromMask(mask: u8) types.MouseButton {
    if ((mask & mouse_button_left_mask) != 0) return .left;
    if ((mask & mouse_button_middle_mask) != 0) return .middle;
    if ((mask & mouse_button_right_mask) != 0) return .right;
    return .none;
}

fn mouseButtonCode(button: types.MouseButton) u8 {
    return switch (button) {
        .left => 0,
        .middle => 1,
        .right => 2,
        .wheel_up => 64,
        .wheel_down => 65,
        .none => 3,
    };
}

fn mouseEncodeCoordX10(value: usize) u8 {
    const v = value + 1 + 32;
    if (v > 255) return 0;
    return @intCast(v);
}

const key_mode_report_all_keys: u32 = 8;
const mouse_button_left_mask: u8 = 1;
const mouse_button_middle_mask: u8 = 2;
const mouse_button_right_mask: u8 = 4;

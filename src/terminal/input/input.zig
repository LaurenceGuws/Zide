const std = @import("std");
const builtin = @import("builtin");
const pty_mod = @import("../io/pty.zig");
const types = @import("../model/types.zig");
const mouse_report = @import("mouse_report.zig");
const key_encoding = @import("key_encoding.zig");
const keypad = @import("keypad.zig");

pub const KeyAction = key_encoding.KeyAction;

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
        const mod_bits = mouse_report.mouseModBits(event.mod);

        if (event.kind == .move) {
            if (!self.mouseMotionActive(buttons_active)) return false;
            if (row == self.mouse_last_row and col == self.mouse_last_col and buttons_down == self.mouse_last_buttons) {
                return false;
            }
        }

        var button = event.button;
        if (event.kind == .move) {
            button = mouse_report.mouseButtonFromMask(buttons_down);
        }
        if (event.kind == .release and !self.mouse_mode_sgr) {
            button = .none;
        }

        const base_code = mouse_report.mouseButtonCode(button);
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
            buf[4] = mouse_report.mouseEncodeCoordX10(col);
            buf[5] = mouse_report.mouseEncodeCoordX10(row);
            _ = try pty.write(buf[0..6]);
        }

        self.mouse_last_row = row;
        self.mouse_last_col = col;
        self.mouse_last_buttons = buttons_down;
        return true;
    }
};

pub const KeypadKey = enum {
    kp0,
    kp1,
    kp2,
    kp3,
    kp4,
    kp5,
    kp6,
    kp7,
    kp8,
    kp9,
    kp_decimal,
    kp_divide,
    kp_multiply,
    kp_subtract,
    kp_add,
    kp_enter,
    kp_equal,
};

pub fn sendKey(pty: *pty_mod.Pty, key: types.Key, mod: types.Modifier, key_mode_flags: u32) !bool {
    if (sendKeyWithProtocol(pty, key, mod, key_mode_flags, .press)) return true;
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

pub fn sendKeyAction(pty: *pty_mod.Pty, key: types.Key, mod: types.Modifier, key_mode_flags: u32, action: KeyAction) !bool {
    if (sendKeyWithProtocol(pty, key, mod, key_mode_flags, action)) return true;
    if (action == .release) return false;
    return sendKey(pty, key, mod, key_mode_flags);
}

pub fn sendKeypad(pty: *pty_mod.Pty, key: KeypadKey, mod: types.Modifier, app_keypad: bool, key_mode_flags: u32) !bool {
    if (app_keypad and mod == types.VTERM_MOD_NONE) {
        if (keypad.keypadAppCode(key)) |code| {
            var buf: [3]u8 = undefined;
            buf[0] = 0x1b;
            buf[1] = 'O';
            buf[2] = code;
            _ = try pty.write(buf[0..3]);
            return true;
        }
    }
    if (keypad.keypadChar(key)) |ch| {
        return sendChar(pty, ch, mod, key_mode_flags);
    }
    return false;
}

pub fn sendChar(pty: *pty_mod.Pty, char: u32, mod: types.Modifier, key_mode_flags: u32) !bool {
    return sendCharAction(pty, char, mod, key_mode_flags, .press);
}

pub fn sendCharAction(pty: *pty_mod.Pty, char: u32, mod: types.Modifier, key_mode_flags: u32, action: KeyAction) !bool {
    if (char > 0x10FFFF or (char >= 0xD800 and char <= 0xDFFF)) return false;
    const report_text = (key_mode_flags & key_encoding.key_mode_report_text) != 0;
    if (!report_text and (mod & types.VTERM_MOD_CTRL) != 0) {
        if (ctrlChar(char)) |mapped| {
            if ((mod & types.VTERM_MOD_ALT) != 0) {
                _ = try pty.write(&[_]u8{0x1b});
            }
            _ = try pty.write(&[_]u8{mapped});
            return true;
        }
    }
    if (!report_text and (mod & types.VTERM_MOD_ALT) != 0) {
        _ = try pty.write(&[_]u8{0x1b});
    }
    if (sendCharWithProtocol(pty, char, mod, key_mode_flags, action)) return true;
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
    return key_encoding.encodeModifier(mod);
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

fn sendKeyWithProtocol(pty: *pty_mod.Pty, key: types.Key, mod: types.Modifier, flags: u32, action: KeyAction) bool {
    if (flags == 0) return false;
    if (!key_encoding.supportsKeyEncoding(flags)) return false;

    const report_all = (flags & key_encoding.key_mode_report_all_event_types) != 0;
    const disambiguate = (flags & key_encoding.key_mode_disambiguate) != 0;
    const report_text = (flags & key_encoding.key_mode_report_text) != 0;
    if (!report_all and !disambiguate and !report_text) {
        return false;
    }

    if (!report_all and action == .release) return false;

    const mapping = key_encoding.kittyFunctionKeyMapping(key) orelse return false;
    return key_encoding.sendKittyFunctionKey(pty, mapping.number, mapping.trailer, mod, action, flags);
}

fn sendCharWithProtocol(pty: *pty_mod.Pty, char: u32, mod: types.Modifier, flags: u32, action: KeyAction) bool {
    if (flags == 0) return false;
    if (!key_encoding.supportsKeyEncoding(flags)) return false;
    if ((flags & key_encoding.key_mode_report_text) == 0) return false;
    if ((flags & key_encoding.key_mode_report_all_event_types) == 0 and action == .release) return false;

    var buf: [64]u8 = undefined;
    const mod_value = key_encoding.kittyModValue(mod);
    const has_mods = mod_value != 1;
    const add_actions = (flags & key_encoding.key_mode_report_all_event_types) != 0 and action != .press;
    const second_field = has_mods or add_actions;

    var pos: usize = 0;
    buf[pos] = 0x1b;
    pos += 1;
    buf[pos] = '[';
    pos += 1;
    const written_key = std.fmt.bufPrint(buf[pos..], "{d}", .{char}) catch return false;
    pos += written_key.len;
    if (second_field or (flags & key_encoding.key_mode_embed_text) != 0) {
        buf[pos] = ';';
        pos += 1;
        if (has_mods) {
            const written_mod = std.fmt.bufPrint(buf[pos..], "{d}", .{mod_value}) catch return false;
            pos += written_mod.len;
        }
        if (add_actions) {
            buf[pos] = ':';
            pos += 1;
            const written_action = std.fmt.bufPrint(buf[pos..], "{d}", .{@intFromEnum(action) + 1}) catch return false;
            pos += written_action.len;
        }
    }
    if ((flags & key_encoding.key_mode_embed_text) != 0) {
        buf[pos] = ';';
        pos += 1;
        const written_text = std.fmt.bufPrint(buf[pos..], "{d}", .{char}) catch return false;
        pos += written_text.len;
    }
    buf[pos] = 'u';
    pos += 1;
    _ = pty.write(buf[0..pos]) catch return false;
    return true;
}

pub fn encodeKeyBytesForTest(
    allocator: std.mem.Allocator,
    key: types.Key,
    mod: types.Modifier,
    flags: u32,
) ![]u8 {
    if (!debugAccessAllowed()) @panic("encodeKeyBytesForTest is test-only");
    if (flags == 0) return allocator.alloc(u8, 0);
    const mod_code = encodeModifier(mod);
    if ((flags & key_encoding.key_mode_report_all_event_types) == 0) {
        if (key == types.VTERM_KEY_ENTER or key == types.VTERM_KEY_TAB or key == types.VTERM_KEY_BACKSPACE) {
            return allocator.alloc(u8, 0);
        }
    }
    return switch (key) {
        types.VTERM_KEY_UP => encodeCsiWithModBytes(allocator, "1", mod_code, "A"),
        types.VTERM_KEY_DOWN => encodeCsiWithModBytes(allocator, "1", mod_code, "B"),
        types.VTERM_KEY_RIGHT => encodeCsiWithModBytes(allocator, "1", mod_code, "C"),
        types.VTERM_KEY_LEFT => encodeCsiWithModBytes(allocator, "1", mod_code, "D"),
        types.VTERM_KEY_HOME => encodeCsiWithModBytes(allocator, "1", mod_code, "H"),
        types.VTERM_KEY_END => encodeCsiWithModBytes(allocator, "1", mod_code, "F"),
        types.VTERM_KEY_PAGEUP => encodeCsiWithModBytes(allocator, "5", mod_code, "~"),
        types.VTERM_KEY_PAGEDOWN => encodeCsiWithModBytes(allocator, "6", mod_code, "~"),
        types.VTERM_KEY_INS => encodeCsiWithModBytes(allocator, "2", mod_code, "~"),
        types.VTERM_KEY_DEL => encodeCsiWithModBytes(allocator, "3", mod_code, "~"),
        types.VTERM_KEY_ESCAPE => std.fmt.allocPrint(allocator, "\x1b[{d};{d}u", .{ 27, mod_code }),
        else => allocator.alloc(u8, 0),
    };
}

pub fn encodeCharBytesForTest(
    allocator: std.mem.Allocator,
    char: u32,
    mod: types.Modifier,
    flags: u32,
) ![]u8 {
    if (!debugAccessAllowed()) @panic("encodeCharBytesForTest is test-only");
    if (flags == 0) return allocator.alloc(u8, 0);
    if (mod == types.VTERM_MOD_NONE and (flags & key_encoding.key_mode_report_all_event_types) == 0) {
        return allocator.alloc(u8, 0);
    }
    const mod_code = encodeModifier(mod);
    return std.fmt.allocPrint(allocator, "\x1b[{d};{d}u", .{ char, mod_code });
}

fn encodeCsiWithModBytes(
    allocator: std.mem.Allocator,
    prefix: []const u8,
    mod_code: u8,
    suffix: []const u8,
) ![]u8 {
    if (!debugAccessAllowed()) @panic("encodeCsiWithModBytes is test-only");
    if (mod_code > 1) {
        return std.fmt.allocPrint(allocator, "\x1b[{s};{d}{s}", .{ prefix, mod_code, suffix });
    }
    return std.fmt.allocPrint(allocator, "\x1b[{s}{s}", .{ prefix, suffix });
}

fn debugAccessAllowed() bool {
    if (builtin.is_test) return true;
    const root = @import("root");
    return @hasDecl(root, "terminal_replay_enabled") and root.terminal_replay_enabled;
}

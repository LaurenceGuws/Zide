const std = @import("std");
const builtin = @import("builtin");
const pty_mod = @import("../io/pty.zig");
const types = @import("../model/types.zig");
const mouse_report = @import("mouse_report.zig");
const key_encoding = @import("key_encoding.zig");
const keypad = @import("keypad.zig");

pub const KeyAction = key_encoding.KeyAction;

pub const KeyProtocolMetadata = struct {
    alternate: ?types.KeyboardAlternateMetadata = null,
};

pub const KeyInputEvent = struct {
    key: types.Key,
    mod: types.Modifier,
    key_mode_flags: u32,
    action: KeyAction = .press,
    protocol: KeyProtocolMetadata = .{},
};

pub const CharInputEvent = struct {
    codepoint: u32,
    mod: types.Modifier,
    key_mode_flags: u32,
    action: KeyAction = .press,
    protocol: KeyProtocolMetadata = .{},
};

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

pub fn sendKeyActionEvent(pty: *pty_mod.Pty, event: KeyInputEvent) !bool {
    // Metadata is threaded through the input boundary for future kitty alternate-key parity work.
    _ = event.protocol;
    return sendKeyAction(pty, event.key, event.mod, event.key_mode_flags, event.action);
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
    if (sendCharWithProtocol(pty, char, mod, key_mode_flags, action)) return true;
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
    var buf: [4]u8 = undefined;
    const len = std.unicode.utf8Encode(@intCast(char), &buf) catch return false;
    _ = try pty.write(buf[0..len]);
    return true;
}

pub fn sendCharActionEvent(pty: *pty_mod.Pty, event: CharInputEvent) !bool {
    if (event.codepoint > 0x10FFFF or (event.codepoint >= 0xD800 and event.codepoint <= 0xDFFF)) return false;
    if (sendCharWithProtocolMeta(
        pty,
        event.codepoint,
        event.mod,
        event.key_mode_flags,
        event.action,
        event.protocol.alternate,
    )) return true;
    return sendCharAction(pty, event.codepoint, event.mod, event.key_mode_flags, event.action);
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
    return sendCharWithProtocolMeta(pty, char, mod, flags, action, null);
}

fn sendCharWithProtocolMeta(
    pty: *pty_mod.Pty,
    char: u32,
    mod: types.Modifier,
    flags: u32,
    action: KeyAction,
    alternate_meta: ?types.KeyboardAlternateMetadata,
) bool {
    if (flags == 0) return false;
    if (!key_encoding.supportsKeyEncoding(flags)) return false;
    const report_text = (flags & key_encoding.key_mode_report_text) != 0;
    const disambiguate = (flags & key_encoding.key_mode_disambiguate) != 0;
    if (!report_text and !disambiguate) return false;
    if (!report_text and !charNeedsProtocolDisambiguation(char, mod)) return false;
    if ((flags & key_encoding.key_mode_report_all_event_types) == 0 and action == .release) return false;

    var buf: [64]u8 = undefined;
    const key_fields = protocolCharKeyFields(char, mod, flags, alternate_meta);
    const mod_value = key_encoding.kittyModValue(mod);
    const has_mods = mod_value != 1;
    const add_actions = (flags & key_encoding.key_mode_report_all_event_types) != 0 and action != .press;
    const second_field = has_mods or add_actions;

    var pos: usize = 0;
    buf[pos] = 0x1b;
    pos += 1;
    buf[pos] = '[';
    pos += 1;
    const written_key = std.fmt.bufPrint(buf[pos..], "{d}", .{key_fields.key}) catch return false;
    pos += written_key.len;
    if (key_fields.shifted) |shifted_key| {
        buf[pos] = ':';
        pos += 1;
        const written_shifted = std.fmt.bufPrint(buf[pos..], "{d}", .{shifted_key}) catch return false;
        pos += written_shifted.len;
        if (key_fields.alternate) |alternate_key| {
            buf[pos] = ':';
            pos += 1;
            const written_alt = std.fmt.bufPrint(buf[pos..], "{d}", .{alternate_key}) catch return false;
            pos += written_alt.len;
        }
    }
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

const ProtocolCharKeyFields = struct {
    key: u32,
    shifted: ?u32 = null,
    alternate: ?u32 = null,
};

fn protocolCharKeyFields(
    char: u32,
    mod: types.Modifier,
    flags: u32,
    alternate_meta: ?types.KeyboardAlternateMetadata,
) ProtocolCharKeyFields {
    const report_alternate = (flags & key_encoding.key_mode_report_alternate_key) != 0;
    if (!report_alternate) return .{ .key = char };
    if ((mod & types.VTERM_MOD_SHIFT) == 0) return .{ .key = char };

    if (alternate_meta) |meta| {
        if (meta.text_is_composed) return .{ .key = char };
        if (meta.base_codepoint) |base_cp| {
            const shifted_cp = meta.shifted_codepoint orelse char;
            if (shifted_cp == char and base_cp != char) {
                var alt_cp: ?u32 = null;
                if (meta.alternate_layout_codepoint) |candidate| {
                    if (candidate != base_cp and candidate != shifted_cp) alt_cp = candidate;
                }
                return .{
                    .key = base_cp,
                    .shifted = char,
                    .alternate = alt_cp,
                };
            }
        }
    }

    if (asciiShiftBase(char)) |base| {
        return .{
            .key = base,
            .shifted = char,
        };
    }
    return .{ .key = char };
}

fn asciiShiftBase(char: u32) ?u32 {
    if (char >= 'A' and char <= 'Z') return char + 32;
    return switch (char) {
        '!' => '1',
        '@' => '2',
        '#' => '3',
        '$' => '4',
        '%' => '5',
        '^' => '6',
        '&' => '7',
        '*' => '8',
        '(' => '9',
        ')' => '0',
        '_' => '-',
        '+' => '=',
        '{' => '[',
        '}' => ']',
        '|' => '\\',
        ':' => ';',
        '"' => '\'',
        '<' => ',',
        '>' => '.',
        '?' => '/',
        '~' => '`',
        else => null,
    };
}

fn charNeedsProtocolDisambiguation(char: u32, mod: types.Modifier) bool {
    if (mod != types.VTERM_MOD_NONE) return true;
    return switch (char) {
        0x08, // BS
        0x09, // TAB
        0x0D, // CR
        0x1B, // ESC
        0x7F, // DEL/Backspace legacy
        => true,
        else => false,
    };
}

pub fn encodeKeyActionBytesForTest(
    allocator: std.mem.Allocator,
    key: types.Key,
    mod: types.Modifier,
    flags: u32,
    action: KeyAction,
) ![]u8 {
    if (!debugAccessAllowed()) @panic("encodeKeyActionBytesForTest is test-only");
    if (flags == 0) return allocator.alloc(u8, 0);
    const report_all = (flags & key_encoding.key_mode_report_all_event_types) != 0;
    const disambiguate = (flags & key_encoding.key_mode_disambiguate) != 0;
    const report_text = (flags & key_encoding.key_mode_report_text) != 0;
    if (!report_all and !disambiguate and !report_text) {
        return allocator.alloc(u8, 0);
    }
    if (!report_all and action == .release) return allocator.alloc(u8, 0);

    const mod_code = encodeModifier(mod);
    const has_mods = mod_code != 1;
    const add_actions = report_all and action != .press;
    const second_field = has_mods or add_actions;
    const TestFunctionKey = struct {
        number: u32,
        trailer: u8,
    };

    const function_key: ?TestFunctionKey = switch (key) {
        types.VTERM_KEY_ENTER => .{ .number = 13, .trailer = 'u' },
        types.VTERM_KEY_TAB => .{ .number = 9, .trailer = 'u' },
        types.VTERM_KEY_BACKSPACE => .{ .number = 127, .trailer = 'u' },
        types.VTERM_KEY_ESCAPE => .{ .number = 27, .trailer = 'u' },
        types.VTERM_KEY_UP => .{ .number = 1, .trailer = 'A' },
        types.VTERM_KEY_DOWN => .{ .number = 1, .trailer = 'B' },
        types.VTERM_KEY_RIGHT => .{ .number = 1, .trailer = 'C' },
        types.VTERM_KEY_LEFT => .{ .number = 1, .trailer = 'D' },
        types.VTERM_KEY_HOME => .{ .number = 1, .trailer = 'H' },
        types.VTERM_KEY_END => .{ .number = 1, .trailer = 'F' },
        types.VTERM_KEY_PAGEUP => .{ .number = 5, .trailer = '~' },
        types.VTERM_KEY_PAGEDOWN => .{ .number = 6, .trailer = '~' },
        types.VTERM_KEY_INS => .{ .number = 2, .trailer = '~' },
        types.VTERM_KEY_DEL => .{ .number = 3, .trailer = '~' },
        else => null,
    };
    if (function_key == null) return allocator.alloc(u8, 0);
    const fk = function_key.?;

    if (!report_all) {
        if (key == types.VTERM_KEY_ENTER or key == types.VTERM_KEY_TAB or key == types.VTERM_KEY_BACKSPACE) {
            if (!disambiguate and !report_text) return allocator.alloc(u8, 0);
        }
    }

    var buf: [64]u8 = undefined;
    var pos: usize = 0;
    buf[pos] = 0x1b;
    pos += 1;
    buf[pos] = '[';
    pos += 1;
    const omit_leading_one = !second_field and fk.number == 1 and switch (fk.trailer) {
        'A', 'B', 'C', 'D', 'H', 'F' => true,
        else => false,
    };
    if (!omit_leading_one) {
        const written_key = std.fmt.bufPrint(buf[pos..], "{d}", .{fk.number}) catch return allocator.alloc(u8, 0);
        pos += written_key.len;
    }
    if (second_field) {
        buf[pos] = ';';
        pos += 1;
        if (has_mods) {
            const written_mod = std.fmt.bufPrint(buf[pos..], "{d}", .{mod_code}) catch return allocator.alloc(u8, 0);
            pos += written_mod.len;
        }
        if (add_actions) {
            buf[pos] = ':';
            pos += 1;
            const written_action = std.fmt.bufPrint(buf[pos..], "{d}", .{@intFromEnum(action) + 1}) catch return allocator.alloc(u8, 0);
            pos += written_action.len;
        }
    }
    buf[pos] = fk.trailer;
    pos += 1;
    return allocator.dupe(u8, buf[0..pos]);
}

pub fn encodeKeyBytesForTest(
    allocator: std.mem.Allocator,
    key: types.Key,
    mod: types.Modifier,
    flags: u32,
) ![]u8 {
    return encodeKeyActionBytesForTest(allocator, key, mod, flags, .press);
}

pub fn encodeCharBytesForTest(
    allocator: std.mem.Allocator,
    char: u32,
    mod: types.Modifier,
    flags: u32,
) ![]u8 {
    if (!debugAccessAllowed()) @panic("encodeCharBytesForTest is test-only");
    if (flags == 0) return allocator.alloc(u8, 0);
    const report_text = (flags & key_encoding.key_mode_report_text) != 0;
    const disambiguate = (flags & key_encoding.key_mode_disambiguate) != 0;
    if (!report_text and !disambiguate) return allocator.alloc(u8, 0);
    if (!report_text and !charNeedsProtocolDisambiguation(char, mod)) return allocator.alloc(u8, 0);
    const mod_code = encodeModifier(mod);
    const key_fields = protocolCharKeyFields(char, mod, flags, null);
    const embed_text = (flags & key_encoding.key_mode_embed_text) != 0;
    const has_mods = mod_code != 1;
    if (key_fields.shifted) |shifted_key| {
        if (embed_text) {
            if (has_mods) {
                return std.fmt.allocPrint(allocator, "\x1b[{d}:{d};{d};{d}u", .{ key_fields.key, shifted_key, mod_code, char });
            }
            return std.fmt.allocPrint(allocator, "\x1b[{d}:{d};;{d}u", .{ key_fields.key, shifted_key, char });
        }
        return std.fmt.allocPrint(allocator, "\x1b[{d}:{d};{d}u", .{ key_fields.key, shifted_key, mod_code });
    }
    if (embed_text) {
        if (has_mods) {
            return std.fmt.allocPrint(allocator, "\x1b[{d};{d};{d}u", .{ key_fields.key, mod_code, char });
        }
        return std.fmt.allocPrint(allocator, "\x1b[{d};;{d}u", .{ key_fields.key, char });
    }
    return std.fmt.allocPrint(allocator, "\x1b[{d};{d}u", .{ key_fields.key, mod_code });
}

pub fn encodeCharEventBytesForTest(
    allocator: std.mem.Allocator,
    event: CharInputEvent,
) ![]u8 {
    if (!debugAccessAllowed()) @panic("encodeCharEventBytesForTest is test-only");
    if (event.key_mode_flags == 0) return allocator.alloc(u8, 0);
    const report_text = (event.key_mode_flags & key_encoding.key_mode_report_text) != 0;
    const disambiguate = (event.key_mode_flags & key_encoding.key_mode_disambiguate) != 0;
    if (!report_text and !disambiguate) return allocator.alloc(u8, 0);
    if (!report_text and !charNeedsProtocolDisambiguation(event.codepoint, event.mod)) return allocator.alloc(u8, 0);
    const mod_code = encodeModifier(event.mod);
    const key_fields = protocolCharKeyFields(event.codepoint, event.mod, event.key_mode_flags, event.protocol.alternate);
    const embed_text = (event.key_mode_flags & key_encoding.key_mode_embed_text) != 0;
    const has_mods = mod_code != 1;
    if (key_fields.shifted) |shifted_key| {
        if (embed_text) {
            if (has_mods) {
                if (key_fields.alternate) |alternate_key| {
                    return std.fmt.allocPrint(allocator, "\x1b[{d}:{d}:{d};{d};{d}u", .{ key_fields.key, shifted_key, alternate_key, mod_code, event.codepoint });
                }
                return std.fmt.allocPrint(allocator, "\x1b[{d}:{d};{d};{d}u", .{ key_fields.key, shifted_key, mod_code, event.codepoint });
            }
            if (key_fields.alternate) |alternate_key| {
                return std.fmt.allocPrint(allocator, "\x1b[{d}:{d}:{d};;{d}u", .{ key_fields.key, shifted_key, alternate_key, event.codepoint });
            }
            return std.fmt.allocPrint(allocator, "\x1b[{d}:{d};;{d}u", .{ key_fields.key, shifted_key, event.codepoint });
        }
        if (key_fields.alternate) |alternate_key| {
            return std.fmt.allocPrint(allocator, "\x1b[{d}:{d}:{d};{d}u", .{ key_fields.key, shifted_key, alternate_key, mod_code });
        }
        return std.fmt.allocPrint(allocator, "\x1b[{d}:{d};{d}u", .{ key_fields.key, shifted_key, mod_code });
    }
    if (embed_text) {
        if (has_mods) {
            return std.fmt.allocPrint(allocator, "\x1b[{d};{d};{d}u", .{ key_fields.key, mod_code, event.codepoint });
        }
        return std.fmt.allocPrint(allocator, "\x1b[{d};;{d}u", .{ key_fields.key, event.codepoint });
    }
    return std.fmt.allocPrint(allocator, "\x1b[{d};{d}u", .{ key_fields.key, mod_code });
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

const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const types = @import("../model/types.zig");

pub const KeyAction = enum(u8) {
    press = 0,
    repeat = 1,
    release = 2,
};

pub const key_mode_disambiguate: u32 = 1;
pub const key_mode_report_all_event_types: u32 = 2;
pub const key_mode_report_alternate_key: u32 = 4;
pub const key_mode_report_text: u32 = 8;
pub const key_mode_embed_text: u32 = 16;

pub fn supportsKeyEncoding(flags: u32) bool {
    if (flags == 0) return false;
    return true;
}

pub fn encodeModifier(mod: types.Modifier) u8 {
    var value: u8 = 1;
    if ((mod & types.VTERM_MOD_SHIFT) != 0) value += 1;
    if ((mod & types.VTERM_MOD_ALT) != 0) value += 2;
    if ((mod & types.VTERM_MOD_CTRL) != 0) value += 4;
    return value;
}

pub fn kittyModValue(mod: types.Modifier) u8 {
    var value: u8 = 1;
    if ((mod & types.VTERM_MOD_SHIFT) != 0) value += 1;
    if ((mod & types.VTERM_MOD_ALT) != 0) value += 2;
    if ((mod & types.VTERM_MOD_CTRL) != 0) value += 4;
    return value;
}

const KittyKeyMapping = struct {
    number: u32,
    trailer: u8,
};

pub fn kittyFunctionKeyMapping(key: types.Key) ?KittyKeyMapping {
    return switch (key) {
        types.VTERM_KEY_ESCAPE => .{ .number = 27, .trailer = 'u' },
        types.VTERM_KEY_ENTER => .{ .number = 13, .trailer = 'u' },
        types.VTERM_KEY_TAB => .{ .number = 9, .trailer = 'u' },
        types.VTERM_KEY_BACKSPACE => .{ .number = 127, .trailer = 'u' },
        types.VTERM_KEY_INS => .{ .number = 2, .trailer = '~' },
        types.VTERM_KEY_DEL => .{ .number = 3, .trailer = '~' },
        types.VTERM_KEY_LEFT => .{ .number = 1, .trailer = 'D' },
        types.VTERM_KEY_RIGHT => .{ .number = 1, .trailer = 'C' },
        types.VTERM_KEY_UP => .{ .number = 1, .trailer = 'A' },
        types.VTERM_KEY_DOWN => .{ .number = 1, .trailer = 'B' },
        types.VTERM_KEY_PAGEUP => .{ .number = 5, .trailer = '~' },
        types.VTERM_KEY_PAGEDOWN => .{ .number = 6, .trailer = '~' },
        types.VTERM_KEY_HOME => .{ .number = 1, .trailer = 'H' },
        types.VTERM_KEY_END => .{ .number = 1, .trailer = 'F' },
        types.VTERM_KEY_LEFT_SHIFT => .{ .number = 57441, .trailer = 'u' },
        types.VTERM_KEY_LEFT_CTRL => .{ .number = 57442, .trailer = 'u' },
        types.VTERM_KEY_LEFT_ALT => .{ .number = 57443, .trailer = 'u' },
        types.VTERM_KEY_LEFT_SUPER => .{ .number = 57444, .trailer = 'u' },
        types.VTERM_KEY_RIGHT_SHIFT => .{ .number = 57447, .trailer = 'u' },
        types.VTERM_KEY_RIGHT_CTRL => .{ .number = 57448, .trailer = 'u' },
        types.VTERM_KEY_RIGHT_ALT => .{ .number = 57449, .trailer = 'u' },
        types.VTERM_KEY_RIGHT_SUPER => .{ .number = 57450, .trailer = 'u' },
        else => null,
    };
}

pub fn sendKittyFunctionKey(
    writer: anytype,
    key_number: u32,
    trailer: u8,
    mod: types.Modifier,
    action: KeyAction,
    flags: u32,
) bool {
    const log = app_logger.logger("terminal.input");
    const report_all = (flags & key_mode_report_all_event_types) != 0;
    const disambiguate = (flags & key_mode_disambiguate) != 0;
    const report_text = (flags & key_mode_report_text) != 0;
    if (!report_all and !disambiguate and !report_text) return false;
    if (!report_all and action == .release) return false;

    const mod_value = kittyModValue(mod);
    const has_mods = mod_value != 1;
    const add_actions = report_all and action != .press;
    const second_field = has_mods or add_actions;
    const omit_leading_one = !second_field and key_number == 1 and isLegacyCsiCursorTrailer(trailer);

    var buf: [64]u8 = undefined;
    var pos: usize = 0;
    buf[pos] = 0x1b;
    pos += 1;
    buf[pos] = '[';
    pos += 1;
    if (!omit_leading_one) {
        const written_key = std.fmt.bufPrint(buf[pos..], "{d}", .{key_number}) catch |err| {
            log.logf(.warning, "kitty function key number format failed: {s}", .{@errorName(err)});
            return false;
        };
        pos += written_key.len;
    }
    if (second_field) {
        buf[pos] = ';';
        pos += 1;
        if (has_mods or add_actions) {
            const written_mod = std.fmt.bufPrint(buf[pos..], "{d}", .{mod_value}) catch |err| {
                log.logf(.warning, "kitty function key modifier format failed: {s}", .{@errorName(err)});
                return false;
            };
            pos += written_mod.len;
        }
        if (add_actions) {
            buf[pos] = ':';
            pos += 1;
            const written_action = std.fmt.bufPrint(buf[pos..], "{d}", .{@intFromEnum(action) + 1}) catch |err| {
                log.logf(.warning, "kitty function key action format failed: {s}", .{@errorName(err)});
                return false;
            };
            pos += written_action.len;
        }
    }
    buf[pos] = trailer;
    pos += 1;
    _ = writer.write(buf[0..pos]) catch |err| {
        log.logf(.warning, "kitty function key write failed: {s}", .{@errorName(err)});
        return false;
    };
    return true;
}

fn isLegacyCsiCursorTrailer(trailer: u8) bool {
    return switch (trailer) {
        'A', 'B', 'C', 'D', 'H', 'F' => true,
        else => false,
    };
}

const std = @import("std");
const input_mod = @import("terminal/input/input.zig");
const types = @import("terminal/model/types.zig");

test "terminal input encodes arrow keys with modifiers" {
    const allocator = std.testing.allocator;
    const flags: u32 = 2; // key_mode_report_all_event_types
    const none = types.VTERM_MOD_NONE;
    const shift = types.VTERM_MOD_SHIFT;

    const up = try input_mod.encodeKeyBytesForTest(allocator, types.VTERM_KEY_UP, none, flags);
    defer allocator.free(up);
    try std.testing.expectEqualStrings("\x1b[1A", up);

    const up_shift = try input_mod.encodeKeyBytesForTest(allocator, types.VTERM_KEY_UP, shift, flags);
    defer allocator.free(up_shift);
    try std.testing.expectEqualStrings("\x1b[1;2A", up_shift);
}

test "terminal input encodes char with modifiers when report_text enabled" {
    const allocator = std.testing.allocator;
    const flags: u32 = 8; // key_mode_report_text
    const ctrl = types.VTERM_MOD_CTRL;

    const seq = try input_mod.encodeCharBytesForTest(allocator, 'a', ctrl, flags);
    defer allocator.free(seq);
    try std.testing.expectEqualStrings("\x1b[97;5u", seq);
}

test "terminal input skips char encoding without report_all" {
    const allocator = std.testing.allocator;
    const flags: u32 = 0;
    const seq = try input_mod.encodeCharBytesForTest(allocator, 'a', types.VTERM_MOD_NONE, flags);
    defer allocator.free(seq);
    try std.testing.expectEqual(@as(usize, 0), seq.len);
}

test "terminal input disambiguate mode encodes modified char without report_text" {
    const allocator = std.testing.allocator;
    const flags: u32 = 1; // key_mode_disambiguate
    const ctrl = types.VTERM_MOD_CTRL;

    const seq = try input_mod.encodeCharBytesForTest(allocator, 'a', ctrl, flags);
    defer allocator.free(seq);
    try std.testing.expectEqualStrings("\x1b[97;5u", seq);
}

test "terminal input disambiguate mode encodes escape without modifiers" {
    const allocator = std.testing.allocator;
    const flags: u32 = 1; // key_mode_disambiguate

    const seq = try input_mod.encodeCharBytesForTest(allocator, 27, types.VTERM_MOD_NONE, flags);
    defer allocator.free(seq);
    try std.testing.expectEqualStrings("\x1b[27;1u", seq);
}

test "terminal input disambiguate mode encodes enter key" {
    const allocator = std.testing.allocator;
    const flags: u32 = 1; // key_mode_disambiguate

    const seq = try input_mod.encodeKeyBytesForTest(allocator, types.VTERM_KEY_ENTER, types.VTERM_MOD_NONE, flags);
    defer allocator.free(seq);
    try std.testing.expectEqualStrings("\x1b[13;1u", seq);
}

test "terminal input skips key protocol encoding for alternate-key flag alone" {
    const allocator = std.testing.allocator;
    const flags: u32 = 4; // key_mode_report_alternate_key (unsupported / no-op in encoder)

    const seq = try input_mod.encodeKeyBytesForTest(allocator, types.VTERM_KEY_UP, types.VTERM_MOD_NONE, flags);
    defer allocator.free(seq);
    try std.testing.expectEqual(@as(usize, 0), seq.len);
}

test "terminal input reports shifted alternate for uppercase char" {
    const allocator = std.testing.allocator;
    const flags: u32 = 1 | 4; // disambiguate + report_alternate_key
    const shift = types.VTERM_MOD_SHIFT;

    const seq = try input_mod.encodeCharBytesForTest(allocator, 'A', shift, flags);
    defer allocator.free(seq);
    try std.testing.expectEqualStrings("\x1b[97:65;2u", seq);
}

test "terminal input reports shifted alternate for shifted punctuation" {
    const allocator = std.testing.allocator;
    const flags: u32 = 1 | 4; // disambiguate + report_alternate_key
    const shift = types.VTERM_MOD_SHIFT;

    const seq = try input_mod.encodeCharBytesForTest(allocator, ':', shift, flags);
    defer allocator.free(seq);
    try std.testing.expectEqualStrings("\x1b[59:58;2u", seq);
}

test "terminal input reports shifted alternate with embedded text" {
    const allocator = std.testing.allocator;
    const flags: u32 = 4 | 8 | 16; // alternate + report_text + embed_text
    const shift = types.VTERM_MOD_SHIFT;

    const seq = try input_mod.encodeCharBytesForTest(allocator, 'A', shift, flags);
    defer allocator.free(seq);
    try std.testing.expectEqualStrings("\x1b[97:65;2;65u", seq);
}

const std = @import("std");
const input_mod = @import("terminal/input/input.zig");
const alt_probe = @import("terminal/input/alternate_probe.zig");
const types = @import("terminal/model/types.zig");
const shared_types = @import("types/mod.zig");

test "terminal input encodes arrow keys with modifiers" {
    const allocator = std.testing.allocator;
    const flags: u32 = 2; // key_mode_report_all_event_types
    const none = types.VTERM_MOD_NONE;
    const shift = types.VTERM_MOD_SHIFT;

    const up = try input_mod.encodeKeyBytesForTest(allocator, types.VTERM_KEY_UP, none, flags);
    defer allocator.free(up);
    try std.testing.expectEqualStrings("\x1b[A", up);

    const up_shift = try input_mod.encodeKeyBytesForTest(allocator, types.VTERM_KEY_UP, shift, flags);
    defer allocator.free(up_shift);
    try std.testing.expectEqualStrings("\x1b[1;2A", up_shift);
}

test "terminal input disambiguate mode uses legacy compact cursor/home/end forms when unmodified" {
    const allocator = std.testing.allocator;
    const flags: u32 = 1; // key_mode_disambiguate
    const none = types.VTERM_MOD_NONE;

    const up = try input_mod.encodeKeyBytesForTest(allocator, types.VTERM_KEY_UP, none, flags);
    defer allocator.free(up);
    try std.testing.expectEqualStrings("\x1b[A", up);

    const down = try input_mod.encodeKeyBytesForTest(allocator, types.VTERM_KEY_DOWN, none, flags);
    defer allocator.free(down);
    try std.testing.expectEqualStrings("\x1b[B", down);

    const right = try input_mod.encodeKeyBytesForTest(allocator, types.VTERM_KEY_RIGHT, none, flags);
    defer allocator.free(right);
    try std.testing.expectEqualStrings("\x1b[C", right);

    const left = try input_mod.encodeKeyBytesForTest(allocator, types.VTERM_KEY_LEFT, none, flags);
    defer allocator.free(left);
    try std.testing.expectEqualStrings("\x1b[D", left);

    const home = try input_mod.encodeKeyBytesForTest(allocator, types.VTERM_KEY_HOME, none, flags);
    defer allocator.free(home);
    try std.testing.expectEqualStrings("\x1b[H", home);

    const end = try input_mod.encodeKeyBytesForTest(allocator, types.VTERM_KEY_END, none, flags);
    defer allocator.free(end);
    try std.testing.expectEqualStrings("\x1b[F", end);
}

test "terminal input disambiguate mode encodes modified cursor/home/end with 1;{m} forms" {
    const allocator = std.testing.allocator;
    const flags: u32 = 1; // key_mode_disambiguate

    const cases = [_]struct {
        key: types.Key,
        mod: types.Modifier,
        expected: []const u8,
    }{
        .{ .key = types.VTERM_KEY_UP, .mod = types.VTERM_MOD_SHIFT, .expected = "\x1b[1;2A" },
        .{ .key = types.VTERM_KEY_DOWN, .mod = types.VTERM_MOD_SHIFT, .expected = "\x1b[1;2B" },
        .{ .key = types.VTERM_KEY_LEFT, .mod = types.VTERM_MOD_SHIFT, .expected = "\x1b[1;2D" },
        .{ .key = types.VTERM_KEY_RIGHT, .mod = types.VTERM_MOD_SHIFT, .expected = "\x1b[1;2C" },
        .{ .key = types.VTERM_KEY_HOME, .mod = types.VTERM_MOD_SHIFT, .expected = "\x1b[1;2H" },
        .{ .key = types.VTERM_KEY_END, .mod = types.VTERM_MOD_SHIFT, .expected = "\x1b[1;2F" },
        .{ .key = types.VTERM_KEY_UP, .mod = types.VTERM_MOD_ALT, .expected = "\x1b[1;3A" },
        .{ .key = types.VTERM_KEY_HOME, .mod = types.VTERM_MOD_ALT, .expected = "\x1b[1;3H" },
        .{ .key = types.VTERM_KEY_END, .mod = types.VTERM_MOD_ALT, .expected = "\x1b[1;3F" },
        .{ .key = types.VTERM_KEY_UP, .mod = types.VTERM_MOD_CTRL, .expected = "\x1b[1;5A" },
        .{ .key = types.VTERM_KEY_HOME, .mod = types.VTERM_MOD_CTRL, .expected = "\x1b[1;5H" },
        .{ .key = types.VTERM_KEY_END, .mod = types.VTERM_MOD_CTRL, .expected = "\x1b[1;5F" },
    };

    inline for (cases) |case_| {
        const seq = try input_mod.encodeKeyBytesForTest(allocator, case_.key, case_.mod, flags);
        defer allocator.free(seq);
        try std.testing.expectEqualStrings(case_.expected, seq);
    }
}

test "terminal input report-all disambiguate encodes cursor/home/end releases with :3 action field" {
    const allocator = std.testing.allocator;
    const flags: u32 = 1 | 2; // disambiguate + report_all_event_types

    const cases = [_]struct {
        key: types.Key,
        mod: types.Modifier,
        expected: []const u8,
    }{
        .{ .key = types.VTERM_KEY_UP, .mod = types.VTERM_MOD_NONE, .expected = "\x1b[1;:3A" },
        .{ .key = types.VTERM_KEY_DOWN, .mod = types.VTERM_MOD_NONE, .expected = "\x1b[1;:3B" },
        .{ .key = types.VTERM_KEY_LEFT, .mod = types.VTERM_MOD_NONE, .expected = "\x1b[1;:3D" },
        .{ .key = types.VTERM_KEY_RIGHT, .mod = types.VTERM_MOD_NONE, .expected = "\x1b[1;:3C" },
        .{ .key = types.VTERM_KEY_HOME, .mod = types.VTERM_MOD_NONE, .expected = "\x1b[1;:3H" },
        .{ .key = types.VTERM_KEY_END, .mod = types.VTERM_MOD_NONE, .expected = "\x1b[1;:3F" },
        .{ .key = types.VTERM_KEY_UP, .mod = types.VTERM_MOD_SHIFT, .expected = "\x1b[1;2:3A" },
        .{ .key = types.VTERM_KEY_HOME, .mod = types.VTERM_MOD_ALT, .expected = "\x1b[1;3:3H" },
        .{ .key = types.VTERM_KEY_END, .mod = types.VTERM_MOD_CTRL, .expected = "\x1b[1;5:3F" },
    };

    inline for (cases) |case_| {
        const seq = try input_mod.encodeKeyActionBytesForTest(allocator, case_.key, case_.mod, flags, .release);
        defer allocator.free(seq);
        try std.testing.expectEqualStrings(case_.expected, seq);
    }
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
    try std.testing.expectEqualStrings("\x1b[13u", seq);
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

test "terminal input char event metadata path preserves encoding bytes" {
    const allocator = std.testing.allocator;
    const flags: u32 = 1 | 4; // disambiguate + alternate
    const shift = types.VTERM_MOD_SHIFT;

    const seq = try input_mod.encodeCharEventBytesForTest(allocator, .{
        .codepoint = 'A',
        .mod = shift,
        .key_mode_flags = flags,
        .action = .press,
        .protocol = .{
            .alternate = .{
                .physical_key = 30,
                .produced_text_utf8 = "A",
                .base_codepoint = 'a',
                .shifted_codepoint = 'A',
            },
        },
    });
    defer allocator.free(seq);
    try std.testing.expectEqualStrings("\x1b[97:65;2u", seq);
}

test "terminal input char event metadata enables non-us shifted alternate" {
    const allocator = std.testing.allocator;
    const flags: u32 = 4 | 8; // alternate + report_text
    const shift = types.VTERM_MOD_SHIFT;

    const seq = try input_mod.encodeCharEventBytesForTest(allocator, .{
        .codepoint = 0x00C9, // É
        .mod = shift,
        .key_mode_flags = flags,
        .protocol = .{
            .alternate = .{
                .physical_key = 30,
                .produced_text_utf8 = "É",
                .base_codepoint = 0x00E9, // é
                .shifted_codepoint = 0x00C9, // É
            },
        },
    });
    defer allocator.free(seq);
    try std.testing.expectEqualStrings("\x1b[233:201;2u", seq);
}

test "terminal input char event composed metadata suppresses alternate reporting" {
    const allocator = std.testing.allocator;
    const flags: u32 = 1 | 4; // disambiguate + alternate
    const shift = types.VTERM_MOD_SHIFT;

    const seq = try input_mod.encodeCharEventBytesForTest(allocator, .{
        .codepoint = 'A',
        .mod = shift,
        .key_mode_flags = flags,
        .protocol = .{
            .alternate = .{
                .physical_key = 30,
                .produced_text_utf8 = "A",
                .base_codepoint = 'a',
                .shifted_codepoint = 'A',
                .text_is_composed = true,
            },
        },
    });
    defer allocator.free(seq);
    try std.testing.expectEqualStrings("\x1b[65;2u", seq);
}

test "terminal input char event metadata emits third alternate field" {
    const allocator = std.testing.allocator;
    const flags: u32 = 4 | 8; // alternate + report_text
    const shift = types.VTERM_MOD_SHIFT;

    const seq = try input_mod.encodeCharEventBytesForTest(allocator, .{
        .codepoint = 0x00C9, // É
        .mod = shift,
        .key_mode_flags = flags,
        .protocol = .{
            .alternate = .{
                .physical_key = 30,
                .produced_text_utf8 = "É",
                .base_codepoint = 0x00E9, // é
                .shifted_codepoint = 0x00C9, // É
                .alternate_layout_codepoint = 0x20AC, // €
            },
        },
    });
    defer allocator.free(seq);
    try std.testing.expectEqualStrings("\x1b[233:201:8364;2u", seq);
}

test "terminal input bridge seam derives altgr metadata into CSI-u bytes" {
    const allocator = std.testing.allocator;
    const flags: u32 = 4 | 8; // alternate + report_text
    const shift = types.VTERM_MOD_SHIFT;

    const key_event: shared_types.input.KeyEvent = .{
        .key = .e,
        .mods = .{ .shift = true, .alt = true, .ctrl = true, .altgr = true },
        .repeated = false,
        .pressed = true,
        .scancode = 18,
        .sym = 0x20AC, // Euro
        .sdl_mod_bits = 0x4200, // MODE | RALT (representative)
    };
    const text_event: shared_types.input.TextEvent = .{
        .codepoint = 0x00C9, // É
        .utf8_len = 2,
        .utf8 = .{ 0xC3, 0x89, 0, 0 },
        .text_is_composed = false,
    };
    const meta = alt_probe.buildTextEventAlternateMetadata(key_event, text_event, text_event.codepoint, .{
        .base = 0x00E9, // é
        .shifted = 0x00C9, // É
        .event_sym = 0x20AC, // €
        .altgr = 0x20AC, // €
        .explicit_altgr = true,
    });

    const seq = try input_mod.encodeCharEventBytesForTest(allocator, .{
        .codepoint = text_event.codepoint,
        .mod = shift,
        .key_mode_flags = flags,
        .protocol = .{ .alternate = meta },
    });
    defer allocator.free(seq);
    try std.testing.expectEqualStrings("\x1b[233:201:8364;2u", seq);
}

test "terminal input bridge seam suppresses generic altgr probes for explicit non-altgr alt" {
    const allocator = std.testing.allocator;
    const flags: u32 = 4 | 8; // alternate + report_text
    const shift = types.VTERM_MOD_SHIFT;

    const key_event: shared_types.input.KeyEvent = .{
        .key = .e,
        .mods = .{ .shift = true, .alt = true, .ctrl = true, .altgr = false },
        .repeated = false,
        .pressed = true,
        .scancode = 18,
        .sym = '@',
        .sdl_mod_bits = 0x0100, // representative left-alt
    };
    const text_event: shared_types.input.TextEvent = .{
        .codepoint = 0x00C9, // É
        .utf8_len = 2,
        .utf8 = .{ 0xC3, 0x89, 0, 0 },
        .text_is_composed = false,
    };
    const meta = alt_probe.buildTextEventAlternateMetadata(key_event, text_event, text_event.codepoint, .{
        .base = 0x00E9, // é
        .shifted = 0x00C9, // É
        .event_sym = '@',
        .altgr = 0x20AC, // €
        .explicit_non_altgr_alt = true,
    });

    const seq = try input_mod.encodeCharEventBytesForTest(allocator, .{
        .codepoint = text_event.codepoint,
        .mod = shift,
        .key_mode_flags = flags,
        .protocol = .{ .alternate = meta },
    });
    defer allocator.free(seq);
    try std.testing.expectEqualStrings("\x1b[233:201:64;2u", seq);
}

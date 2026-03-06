const std = @import("std");
const shared_types = @import("../../types/mod.zig");
const term_types = @import("../model/types.zig");

pub const ProbeInputs = struct {
    base: ?u32 = null,
    shifted: ?u32 = null,
    event_sym: ?u32 = null,
    altgr: ?u32 = null,
    altgr_shift: ?u32 = null,
    // True when the SDL key event explicitly indicates AltGr / right-alt state.
    explicit_altgr: bool = false,
    // True when SDL keymod bits are present and indicate non-AltGr alt usage.
    explicit_non_altgr_alt: bool = false,
};

fn distinctFromKnown(candidate: u32, base: ?u32, shifted: ?u32) bool {
    if (base) |v| if (candidate == v) return false;
    if (shifted) |v| if (candidate == v) return false;
    return true;
}

pub fn selectThirdAlternate(inputs: ProbeInputs) ?u32 {
    // Only trust AltGr-derived probes when SDL explicitly reports AltGr.
    // This avoids layout guesswork from generic ctrl+alt translations.
    if (inputs.explicit_altgr) {
        if (inputs.altgr) |cp| {
            if (distinctFromKnown(cp, inputs.base, inputs.shifted)) return cp;
        }
        if (inputs.altgr_shift) |cp| {
            if (distinctFromKnown(cp, inputs.base, inputs.shifted)) return cp;
        }
    }

    if (inputs.event_sym) |cp| {
        if (distinctFromKnown(cp, inputs.base, inputs.shifted)) return cp;
    }
    return null;
}

// Test/integration seam: builds the same metadata shape used by the terminal
// encoder from synthetic shared key/text events plus precomputed probe outputs.
pub fn buildTextEventAlternateMetadata(
    key_event: ?shared_types.input.KeyEvent,
    text_event: shared_types.input.TextEvent,
    fallback_char: u32,
    probe_inputs: ProbeInputs,
) term_types.KeyboardAlternateMetadata {
    var utf8_buf: [4]u8 = undefined;
    const utf8_len = std.unicode.utf8Encode(@intCast(fallback_char), &utf8_buf) catch 0;
    var meta: term_types.KeyboardAlternateMetadata = .{
        .produced_text_utf8 = if (text_event.utf8_len > 0)
            text_event.utf8Slice()
        else if (utf8_len > 0)
            utf8_buf[0..utf8_len]
        else
            null,
        .base_codepoint = fallback_char,
        .text_is_composed = text_event.text_is_composed,
    };

    if (key_event) |ke| {
        meta.physical_key = if (ke.scancode) |sc|
            @as(term_types.PhysicalKey, @intCast(sc))
        else
            @as(term_types.PhysicalKey, @intCast(@intFromEnum(ke.key)));
        meta.base_codepoint = probe_inputs.base orelse fallback_char;
        meta.shifted_codepoint = probe_inputs.shifted;
        meta.alternate_layout_codepoint = selectThirdAlternate(.{
            .base = meta.base_codepoint,
            .shifted = meta.shifted_codepoint,
            .event_sym = probe_inputs.event_sym,
            .altgr = probe_inputs.altgr,
            .altgr_shift = probe_inputs.altgr_shift,
            .explicit_altgr = probe_inputs.explicit_altgr or ke.mods.altgr,
            .explicit_non_altgr_alt = probe_inputs.explicit_non_altgr_alt or (ke.mods.alt and !ke.mods.altgr),
        });
    }

    return meta;
}

test "selectThirdAlternate prefers explicit altgr probe over sym" {
    const got = selectThirdAlternate(.{
        .base = 'q',
        .shifted = 'Q',
        .event_sym = '@',
        .altgr = '@',
        .altgr_shift = 0x20AC, // Euro
        .explicit_altgr = true,
    });
    try std.testing.expectEqual(@as(?u32, '@'), got);
}

test "selectThirdAlternate skips generic altgr probes for explicit non-altgr alt" {
    const got = selectThirdAlternate(.{
        .base = 'q',
        .shifted = 'Q',
        .event_sym = 0x00e9, // e acute from event keycode translation
        .altgr = '@',
        .altgr_shift = 0x20AC,
        .explicit_non_altgr_alt = true,
    });
    try std.testing.expectEqual(@as(?u32, 0x00e9), got);
}

test "selectThirdAlternate does not infer altgr probe without explicit altgr" {
    const got = selectThirdAlternate(.{
        .base = 'e',
        .shifted = 'E',
        .event_sym = null,
        .altgr = 0x20AC,
    });
    try std.testing.expectEqual(@as(?u32, null), got);
}

test "selectThirdAlternate uses event_sym when distinct and explicit altgr is missing" {
    const got = selectThirdAlternate(.{
        .base = 'e',
        .shifted = 'E',
        .event_sym = '@',
        .altgr = 0x20AC,
    });
    try std.testing.expectEqual(@as(?u32, '@'), got);
}

test "selectThirdAlternate ignores duplicates and returns null" {
    const got = selectThirdAlternate(.{
        .base = 'a',
        .shifted = 'A',
        .event_sym = 'A',
        .altgr = 'a',
        .altgr_shift = 'A',
        .explicit_altgr = true,
    });
    try std.testing.expectEqual(@as(?u32, null), got);
}

const std = @import("std");

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
    // If SDL explicitly indicates a non-AltGr alt key is active, avoid inferring
    // an AltGr-style third field from ctrl+alt probes.
    if (inputs.explicit_altgr) {
        if (inputs.altgr) |cp| {
            if (distinctFromKnown(cp, inputs.base, inputs.shifted)) return cp;
        }
        if (inputs.altgr_shift) |cp| {
            if (distinctFromKnown(cp, inputs.base, inputs.shifted)) return cp;
        }
    } else if (!inputs.explicit_non_altgr_alt) {
        // No explicit SDL distinction available: keep generic ctrl+alt probing as
        // a best-effort fallback for layouts that expose AltGr this way.
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

test "selectThirdAlternate falls back to generic altgr probes when explicit state missing" {
    const got = selectThirdAlternate(.{
        .base = 'e',
        .shifted = 'E',
        .event_sym = null,
        .altgr = 0x20AC,
    });
    try std.testing.expectEqual(@as(?u32, 0x20AC), got);
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

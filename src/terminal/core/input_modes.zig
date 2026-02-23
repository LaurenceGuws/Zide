const std = @import("std");
const key_encoding = @import("../input/key_encoding.zig");

const supported_key_mode_flags: u32 =
    key_encoding.key_mode_disambiguate |
    key_encoding.key_mode_report_all_event_types |
    key_encoding.key_mode_report_text |
    key_encoding.key_mode_embed_text;

pub fn sanitizeKeyModeFlags(flags: u32) u32 {
    return flags & supported_key_mode_flags;
}

pub fn keyModeFlags(self: anytype) u32 {
    return sanitizeKeyModeFlags(self.activeScreen().keyModeFlags());
}

pub fn keyModePush(self: anytype, flags: u32) void {
    self.activeScreen().keyModePush(sanitizeKeyModeFlags(flags));
    self.updateInputSnapshot();
}

pub fn keyModePop(self: anytype, count: usize) void {
    self.activeScreen().keyModePop(count);
    self.updateInputSnapshot();
}

pub fn keyModeModify(self: anytype, flags: u32, mode: u32) void {
    self.activeScreen().keyModeModify(sanitizeKeyModeFlags(flags), mode);
    self.updateInputSnapshot();
}

pub fn keyModeQuery(self: anytype) void {
    const flags = keyModeFlags(self);
    if (self.pty) |*pty| {
        var buf: [32]u8 = undefined;
        const seq = std.fmt.bufPrint(&buf, "\x1b[?{d}u", .{flags}) catch return;
        _ = pty.write(seq) catch {};
    }
}

pub fn setKeypadMode(self: anytype, enabled: bool) void {
    self.app_keypad = enabled;
    self.updateInputSnapshot();
}

pub fn appKeypadEnabled(self: anytype) bool {
    return self.input_snapshot.app_keypad.load(.acquire);
}

test "sanitize key mode flags masks unsupported alternate-key bit" {
    const flags = key_encoding.key_mode_report_alternate_key |
        key_encoding.key_mode_report_text |
        key_encoding.key_mode_report_all_event_types;
    const sanitized = sanitizeKeyModeFlags(flags);
    try std.testing.expect((sanitized & key_encoding.key_mode_report_alternate_key) == 0);
    try std.testing.expect((sanitized & key_encoding.key_mode_report_text) != 0);
    try std.testing.expect((sanitized & key_encoding.key_mode_report_all_event_types) != 0);
}

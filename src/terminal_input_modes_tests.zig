const std = @import("std");
const input_modes = @import("terminal/core/input_modes.zig");
const key_encoding = @import("terminal/input/key_encoding.zig");

test "sanitize key mode flags preserves alternate-key bit" {
    const flags = key_encoding.key_mode_report_alternate_key |
        key_encoding.key_mode_report_text |
        key_encoding.key_mode_report_all_event_types;
    const sanitized = input_modes.sanitizeKeyModeFlags(flags);
    try std.testing.expect((sanitized & key_encoding.key_mode_report_alternate_key) != 0);
    try std.testing.expect((sanitized & key_encoding.key_mode_report_text) != 0);
    try std.testing.expect((sanitized & key_encoding.key_mode_report_all_event_types) != 0);
}

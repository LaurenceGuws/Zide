const std = @import("std");
const key_encoder = @import("terminal/input/key_encoder.zig");
const input_types = @import("types/input.zig");

test "terminal key encoder base char mapping" {
    try std.testing.expectEqual(@as(?u32, 'a'), key_encoder.baseCharForKey(.a));
    try std.testing.expectEqual(@as(?u32, '0'), key_encoder.baseCharForKey(.zero));
    try std.testing.expectEqual(@as(?u32, '['), key_encoder.baseCharForKey(.left_bracket));
    try std.testing.expectEqual(@as(?u32, null), key_encoder.baseCharForKey(.up));
}

test "terminal key encoder ctrl eligibility" {
    try std.testing.expect(key_encoder.ctrlAllowsChar('a'));
    try std.testing.expect(key_encoder.ctrlAllowsChar('Z'));
    try std.testing.expect(key_encoder.ctrlAllowsChar('@'));
    try std.testing.expect(!key_encoder.ctrlAllowsChar('='));
}

test "terminal key encoder repeat keys" {
    try std.testing.expect(key_encoder.isRepeatKey(.enter));
    try std.testing.expect(key_encoder.isRepeatKey(.kp_0));
    try std.testing.expect(!key_encoder.isRepeatKey(.a));
    try std.testing.expect(!key_encoder.isRepeatKey(.space));
}

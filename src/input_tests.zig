const std = @import("std");
const shared_types = @import("types/mod.zig");

test "input batch append/clear" {
    const allocator = std.testing.allocator;

    var batch = shared_types.input.InputBatch.init(allocator);
    defer batch.deinit();

    try batch.append(.{ .focus = true });
    try std.testing.expectEqual(@as(usize, 1), batch.events.items.len);

    batch.clear();
    try std.testing.expectEqual(@as(usize, 0), batch.events.items.len);
}

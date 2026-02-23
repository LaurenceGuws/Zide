const std = @import("std");
const kitty = @import("terminal/kitty/graphics.zig");

const FakePty = struct {
    writes: std.ArrayList(u8),

    fn init() FakePty {
        return .{ .writes = .empty };
    }

    fn deinit(self: *FakePty) void {
        self.writes.deinit(std.testing.allocator);
    }

    pub fn write(self: *FakePty, bytes: []const u8) !usize {
        try self.writes.appendSlice(std.testing.allocator, bytes);
        return bytes.len;
    }
};

const TestSelf = struct {
    allocator: std.mem.Allocator,
    pty: ?FakePty,
};

test "kitty reply formats ids and placement ids" {
    var self = TestSelf{
        .allocator = std.testing.allocator,
        .pty = FakePty.init(),
    };
    defer if (self.pty) |*pty| pty.deinit();

    var control = kitty.KittyControl{};
    control.image_number = 77;
    control.placement_id = 3;
    kitty.writeKittyResponse(&self, control, 42, true, "OK");

    try std.testing.expectEqualStrings("\x1b_Gi=42,I=77,p=3;OK\x1b\\", self.pty.?.writes.items);
}

test "kitty reply quiet=1 suppresses success but not error" {
    var self = TestSelf{
        .allocator = std.testing.allocator,
        .pty = FakePty.init(),
    };
    defer if (self.pty) |*pty| pty.deinit();

    var control = kitty.KittyControl{};
    control.quiet = 1;

    kitty.writeKittyResponse(&self, control, 7, true, "OK");
    try std.testing.expectEqual(@as(usize, 0), self.pty.?.writes.items.len);

    kitty.writeKittyResponse(&self, control, 7, false, "EINVAL");
    try std.testing.expectEqualStrings("\x1b_Gi=7;EINVAL\x1b\\", self.pty.?.writes.items);
}

test "kitty reply quiet=2 suppresses all replies" {
    var self = TestSelf{
        .allocator = std.testing.allocator,
        .pty = FakePty.init(),
    };
    defer if (self.pty) |*pty| pty.deinit();

    var control = kitty.KittyControl{};
    control.quiet = 2;

    kitty.writeKittyResponse(&self, control, 9, true, "OK");
    kitty.writeKittyResponse(&self, control, 9, false, "EINVAL");
    try std.testing.expectEqual(@as(usize, 0), self.pty.?.writes.items.len);
}

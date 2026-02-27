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

test "kitty query early reply emits no reply on missing image id" {
    var self = TestSelf{
        .allocator = std.testing.allocator,
        .pty = FakePty.init(),
    };
    defer if (self.pty) |*pty| pty.deinit();

    const handled = kitty.handleKittyQueryEarlyReply(&self, .{ .action = 'q' }, 0);
    try std.testing.expect(handled);
    try std.testing.expectEqual(@as(usize, 0), self.pty.?.writes.items.len);
}

test "kitty query early reply returns metadata-only OK" {
    var self = TestSelf{
        .allocator = std.testing.allocator,
        .pty = FakePty.init(),
    };
    defer if (self.pty) |*pty| pty.deinit();

    const handled = kitty.handleKittyQueryEarlyReply(&self, .{ .action = 'q', .image_id = 7 }, 0);
    try std.testing.expect(handled);
    try std.testing.expectEqualStrings("\x1b_Gi=7;OK\x1b\\", self.pty.?.writes.items);
}

test "kitty query early reply falls through when payload or dimensions present" {
    var self = TestSelf{
        .allocator = std.testing.allocator,
        .pty = FakePty.init(),
    };
    defer if (self.pty) |*pty| pty.deinit();

    const handled = kitty.handleKittyQueryEarlyReply(&self, .{ .action = 'q', .image_id = 7, .width = 1 }, 0);
    try std.testing.expect(!handled);
    try std.testing.expectEqual(@as(usize, 0), self.pty.?.writes.items.len);
}

test "kitty query payload preflight rejects chunked query" {
    var self = TestSelf{
        .allocator = std.testing.allocator,
        .pty = FakePty.init(),
    };
    defer if (self.pty) |*pty| pty.deinit();

    const handled = kitty.handleKittyQueryPayloadPreflightReply(&self, .{
        .action = 'q',
        .image_id = 9,
        .more = true,
    }, 9);
    try std.testing.expect(handled);
    try std.testing.expectEqualStrings("\x1b_Gi=9;EINVAL\x1b\\", self.pty.?.writes.items);
}

test "kitty query payload load failure replies EINVAL" {
    var self = TestSelf{
        .allocator = std.testing.allocator,
        .pty = FakePty.init(),
    };
    defer if (self.pty) |*pty| pty.deinit();

    kitty.handleKittyQueryPayloadLoadFailureReply(&self, .{ .action = 'q', .image_id = 5 }, 5);
    try std.testing.expectEqualStrings("\x1b_Gi=5;EINVAL\x1b\\", self.pty.?.writes.items);
}

test "kitty query payload size reply emits ENODATA message" {
    var self = TestSelf{
        .allocator = std.testing.allocator,
        .pty = FakePty.init(),
    };
    defer if (self.pty) |*pty| pty.deinit();

    const handled = kitty.handleKittyQueryPayloadSizeReply(&self, .{
        .action = 'q',
        .image_id = 3,
        .format = 32,
        .width = 2,
        .height = 2,
    }, 3, 15);
    try std.testing.expect(handled);
    try std.testing.expectEqualStrings(
        "\x1b_Gi=3;ENODATA:Insufficient image data: 15 < 16\x1b\\",
        self.pty.?.writes.items,
    );
}

test "kitty query build error reply message maps bad png" {
    try std.testing.expectEqualStrings("EBADPNG", kitty.kittyQueryBuildErrorReplyMessage(error.BadPng));
}

test "kitty query build error reply message maps invalid data" {
    try std.testing.expectEqualStrings("EINVAL", kitty.kittyQueryBuildErrorReplyMessage(error.InvalidData));
}

test "kitty query chunk build reply emits OK on builder success" {
    var self = TestSelf{
        .allocator = std.testing.allocator,
        .pty = FakePty.init(),
    };
    defer if (self.pty) |*pty| pty.deinit();

    const Ctx = struct {};
    const Builder = struct {
        fn run(_: Ctx, _: anytype, _: u32, _: kitty.KittyControl) kitty.KittyBuildError!void {}
    };

    const handled = kitty.handleKittyQueryChunkBuildReply(
        &self,
        .{ .action = 'q', .image_id = 12, .format = 32, .width = 1, .height = 1 },
        12,
        16,
        Ctx{},
        Builder.run,
    );
    try std.testing.expect(handled);
    try std.testing.expectEqualStrings("\x1b_Gi=12;OK\x1b\\", self.pty.?.writes.items);
}

test "kitty query chunk build reply emits EBADPNG on builder error" {
    var self = TestSelf{
        .allocator = std.testing.allocator,
        .pty = FakePty.init(),
    };
    defer if (self.pty) |*pty| pty.deinit();

    const Ctx = struct {};
    const Builder = struct {
        fn run(_: Ctx, _: anytype, _: u32, _: kitty.KittyControl) kitty.KittyBuildError!void {
            return error.BadPng;
        }
    };

    const handled = kitty.handleKittyQueryChunkBuildReply(
        &self,
        .{ .action = 'q', .image_id = 12, .format = 100 },
        12,
        67,
        Ctx{},
        Builder.run,
    );
    try std.testing.expect(handled);
    try std.testing.expectEqualStrings("\x1b_Gi=12;EBADPNG\x1b\\", self.pty.?.writes.items);
}

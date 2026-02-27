const std = @import("std");
const dcs_apc = @import("terminal/protocol/dcs_apc.zig");
const osc_clipboard = @import("terminal/protocol/osc_clipboard.zig");
const palette = @import("terminal/protocol/palette.zig");
const types = @import("terminal/model/types.zig");

const FakePty = struct {
    writes: std.ArrayList(u8),

    fn init() FakePty {
        return .{ .writes = .empty };
    }

    fn deinit(self: *FakePty, allocator: std.mem.Allocator) void {
        self.writes.deinit(allocator);
    }

    pub fn write(self: *FakePty, bytes: []const u8) !usize {
        try self.writes.appendSlice(std.testing.allocator, bytes);
        return bytes.len;
    }
};

test "DCS XTGETTCAP writes TN reply" {
    const allocator = std.testing.allocator;

    const Self = struct {
        allocator: std.mem.Allocator,
        pty: ?FakePty,

        pub fn setSyncUpdates(_: *@This(), _: bool) void {}
    };

    var self = Self{ .allocator = allocator, .pty = FakePty.init() };
    defer if (self.pty) |*pty| pty.deinit(allocator);
    dcs_apc.parseDcs(&self, "+q544E"); // hex("TN")

    try std.testing.expectEqualStrings("\x1bP1+r544E=7A696465\x1b\\", self.pty.?.writes.items);
}

test "DCS XTGETTCAP writes failure reply for unknown cap" {
    const allocator = std.testing.allocator;

    const Self = struct {
        allocator: std.mem.Allocator,
        pty: ?FakePty,

        pub fn setSyncUpdates(_: *@This(), _: bool) void {}
    };

    var self = Self{ .allocator = allocator, .pty = FakePty.init() };
    defer if (self.pty) |*pty| pty.deinit(allocator);
    dcs_apc.parseDcs(&self, "+q5A5A"); // hex("ZZ")

    try std.testing.expectEqualStrings("\x1bP0+r5A5A\x1b\\", self.pty.?.writes.items);
}

test "DCS XTGETTCAP writes ordered replies for multi-cap request" {
    const allocator = std.testing.allocator;

    const Self = struct {
        allocator: std.mem.Allocator,
        pty: ?FakePty,

        pub fn setSyncUpdates(_: *@This(), _: bool) void {}
    };

    var self = Self{ .allocator = allocator, .pty = FakePty.init() };
    defer if (self.pty) |*pty| pty.deinit(allocator);
    // TN ; Co ; RGB ; ZZ (unknown)
    dcs_apc.parseDcs(&self, "+q544E;436F;524742;5A5A");

    try std.testing.expectEqualStrings(
        "\x1bP1+r544E=7A696465\x1b\\" ++
            "\x1bP1+r436F=323536\x1b\\" ++
            "\x1bP1+r524742=38\x1b\\" ++
            "\x1bP0+r5A5A\x1b\\",
        self.pty.?.writes.items,
    );
}

test "DCS DECRQSS writes DECSCUSR reply" {
    const allocator = std.testing.allocator;

    const Self = struct {
        allocator: std.mem.Allocator,
        pty: ?FakePty,

        pub fn setSyncUpdates(_: *@This(), _: bool) void {}
        pub fn decrqssReply(_: *@This(), text: []const u8) ?[]const u8 {
            if (std.mem.eql(u8, text, " q")) return "3 q";
            return null;
        }
    };

    var self = Self{ .allocator = allocator, .pty = FakePty.init() };
    defer if (self.pty) |*pty| pty.deinit(allocator);
    dcs_apc.parseDcs(&self, "$q q");

    try std.testing.expectEqualStrings("\x1bP1$r3 q\x1b\\", self.pty.?.writes.items);
}

test "DCS DECRQSS writes failure reply for unsupported request string" {
    const allocator = std.testing.allocator;

    const Self = struct {
        allocator: std.mem.Allocator,
        pty: ?FakePty,

        pub fn setSyncUpdates(_: *@This(), _: bool) void {}
        pub fn decrqssReply(_: *@This(), _: []const u8) ?[]const u8 {
            return null;
        }
    };

    var self = Self{ .allocator = allocator, .pty = FakePty.init() };
    defer if (self.pty) |*pty| pty.deinit(allocator);
    dcs_apc.parseDcs(&self, "$qm");

    try std.testing.expectEqualStrings("\x1bP0$r\x1b\\", self.pty.?.writes.items);
}

test "DCS DECRQSS writes SGR reply for bounded attribute state" {
    const allocator = std.testing.allocator;

    const Self = struct {
        allocator: std.mem.Allocator,
        pty: ?FakePty,

        pub fn setSyncUpdates(_: *@This(), _: bool) void {}
        pub fn decrqssReplyInto(_: *@This(), text: []const u8, _: []u8) ?[]const u8 {
            if (std.mem.eql(u8, text, "m")) return "1;5;7;31;42";
            return null;
        }
    };

    var self = Self{ .allocator = allocator, .pty = FakePty.init() };
    defer if (self.pty) |*pty| pty.deinit(allocator);
    dcs_apc.parseDcs(&self, "$qm");

    try std.testing.expectEqualStrings("\x1bP1$r1;5;7;31;42m\x1b\\", self.pty.?.writes.items);
}

test "DCS DECRQSS writes DECSTBM reply" {
    const allocator = std.testing.allocator;

    const Self = struct {
        allocator: std.mem.Allocator,
        pty: ?FakePty,

        pub fn setSyncUpdates(_: *@This(), _: bool) void {}
        pub fn decrqssReply(_: *@This(), text: []const u8) ?[]const u8 {
            if (std.mem.eql(u8, text, "r")) return "2;5r";
            return null;
        }
    };

    var self = Self{ .allocator = allocator, .pty = FakePty.init() };
    defer if (self.pty) |*pty| pty.deinit(allocator);
    dcs_apc.parseDcs(&self, "$qr");

    try std.testing.expectEqualStrings("\x1bP1$r2;5r\x1b\\", self.pty.?.writes.items);
}

test "DCS DECRQSS writes DECSLRM reply" {
    const allocator = std.testing.allocator;

    const Self = struct {
        allocator: std.mem.Allocator,
        pty: ?FakePty,

        pub fn setSyncUpdates(_: *@This(), _: bool) void {}
        pub fn decrqssReply(_: *@This(), text: []const u8) ?[]const u8 {
            if (std.mem.eql(u8, text, "s")) return "3;8s";
            return null;
        }
    };

    var self = Self{ .allocator = allocator, .pty = FakePty.init() };
    defer if (self.pty) |*pty| pty.deinit(allocator);
    dcs_apc.parseDcs(&self, "$qs");

    try std.testing.expectEqualStrings("\x1bP1$r3;8s\x1b\\", self.pty.?.writes.items);
}

test "OSC 52 clipboard query preserves BEL terminator" {
    const allocator = std.testing.allocator;

    const Self = struct {
        allocator: std.mem.Allocator,
        pty: ?FakePty,
        osc_clipboard: std.ArrayList(u8),
        osc_clipboard_pending: bool,
    };

    var clipboard = std.ArrayList(u8).empty;
    defer clipboard.deinit(allocator);
    try clipboard.appendSlice(allocator, "hi");
    try clipboard.append(allocator, 0);

    var self = Self{
        .allocator = allocator,
        .pty = FakePty.init(),
        .osc_clipboard = clipboard,
        .osc_clipboard_pending = false,
    };
    defer if (self.pty) |*pty| pty.deinit(allocator);

    osc_clipboard.parseClipboard(&self, "c;?", .bel);
    try std.testing.expectEqualStrings("\x1b]52;c;aGk=\x07", self.pty.?.writes.items);
}

test "OSC 52 clipboard query preserves ST terminator" {
    const allocator = std.testing.allocator;

    const Self = struct {
        allocator: std.mem.Allocator,
        pty: ?FakePty,
        osc_clipboard: std.ArrayList(u8),
        osc_clipboard_pending: bool,
    };

    var clipboard = std.ArrayList(u8).empty;
    defer clipboard.deinit(allocator);
    try clipboard.appendSlice(allocator, "ok");
    try clipboard.append(allocator, 0);

    var self = Self{
        .allocator = allocator,
        .pty = FakePty.init(),
        .osc_clipboard = clipboard,
        .osc_clipboard_pending = false,
    };
    defer if (self.pty) |*pty| pty.deinit(allocator);

    osc_clipboard.parseClipboard(&self, "c;?", .st);
    try std.testing.expectEqualStrings("\x1b]52;c;b2s=\x1b\\", self.pty.?.writes.items);
}

test "OSC 4 palette query preserves ST terminator" {
    const Self = struct {
        pty: ?FakePty,
        palette_current: [256]types.Color,
    };

    var pal = palette.buildDefaultPalette();
    pal[1] = .{ .r = 1, .g = 2, .b = 3, .a = 255 };

    var self = Self{
        .pty = FakePty.init(),
        .palette_current = pal,
    };
    defer if (self.pty) |*pty| pty.deinit(std.testing.allocator);

    palette.handleOscPalette(&self, "1;?", .st);
    try std.testing.expectEqualStrings("\x1b]4;1;rgb:0101/0202/0303\x1b\\", self.pty.?.writes.items);
}

test "OSC 10 dynamic color query replies with default fg and BEL terminator" {
    const Attrs = types.CellAttrs;
    const ScreenLike = struct {
        default_attrs: Attrs,
    };

    const Self = struct {
        pty: ?FakePty,
        primary: ScreenLike,
        base_default_attrs: Attrs,
        dynamic_colors: [10]?types.Color,

        pub fn setDefaultColors(_: *@This(), _: types.Color, _: types.Color) void {}
    };

    const default_attrs = types.defaultCell().attrs;
    var self = Self{
        .pty = FakePty.init(),
        .primary = .{ .default_attrs = default_attrs },
        .base_default_attrs = default_attrs,
        .dynamic_colors = [_]?types.Color{null} ** 10,
    };
    defer if (self.pty) |*pty| pty.deinit(std.testing.allocator);

    palette.handleOscDynamicColor(&self, 10, "?", .bel);
    try std.testing.expectEqualStrings("\x1b]10;rgb:dcdc/dcdc/dcdc\x07", self.pty.?.writes.items);
}

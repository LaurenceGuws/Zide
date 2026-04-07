const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const present_trace_runtime = @import("present_trace_runtime.zig");
const renderer_text_host = @import("renderer_text_host.zig");
const Color = app_shell.Color;

pub const TextKind = enum {
    text,
    icon,
};

pub const ReplayOp = struct {
    kind: TextKind,
    text: []const u8,
    x: f32,
    y: f32,
    color: Color,
    bg: Color,
};

pub fn beginBandCommandGroup(renderer: anytype) void {
    present_trace_runtime.noteBandCommandGroupBegin(renderer);
}

pub fn endBandCommandGroup(renderer: anytype) void {
    present_trace_runtime.noteBandCommandGroupEnd(renderer);
}

pub fn replayBandTextOnBg(renderer: anytype, text: []const u8, x: f32, y: f32, color: anytype, bg: anytype) void {
    renderer_text_host.drawTextOnBg(renderer, text, x, y, color, bg);
}

pub fn replayBandIconTextOnBg(renderer: anytype, text: []const u8, x: f32, y: f32, color: anytype, bg: anytype) void {
    renderer_text_host.drawIconTextOnBg(renderer, text, x, y, color, bg);
}

pub fn replayBandOpsWith(replayer: anytype, ops: []const ReplayOp) void {
    replayer.beginBandCommandGroup();
    defer replayer.endBandCommandGroup();
    for (ops) |op| {
        switch (op.kind) {
            .text => replayer.replayBandTextOnBg(op.text, op.x, op.y, op.color, op.bg),
            .icon => replayer.replayBandIconTextOnBg(op.text, op.x, op.y, op.color, op.bg),
        }
    }
}

pub fn replayBandOps(renderer: anytype, ops: []const ReplayOp) void {
    beginBandCommandGroup(renderer);
    defer endBandCommandGroup(renderer);
    for (ops) |op| {
        switch (op.kind) {
            .text => replayBandTextOnBg(renderer, op.text, op.x, op.y, op.color, op.bg),
            .icon => replayBandIconTextOnBg(renderer, op.text, op.x, op.y, op.color, op.bg),
        }
    }
}

test "replayBandOpsWith preserves order and wraps with group boundaries" {
    const EventKind = enum {
        begin,
        text,
        icon,
        end,
    };
    const Event = struct {
        kind: EventKind,
        text: []const u8 = "",
        bg_id: u8 = 0,
    };

    const FakeReplayer = struct {
        events: *std.ArrayList(Event),

        fn beginBandCommandGroup(self: @This()) void {
            self.events.append(std.testing.allocator, .{ .kind = .begin }) catch unreachable;
        }

        fn endBandCommandGroup(self: @This()) void {
            self.events.append(std.testing.allocator, .{ .kind = .end }) catch unreachable;
        }

        fn replayBandTextOnBg(self: @This(), text: []const u8, x: f32, y: f32, color: Color, bg: Color) void {
            _ = x;
            _ = y;
            _ = color;
            self.events.append(std.testing.allocator, .{ .kind = .text, .text = text, .bg_id = bg.r }) catch unreachable;
        }

        fn replayBandIconTextOnBg(self: @This(), text: []const u8, x: f32, y: f32, color: Color, bg: Color) void {
            _ = x;
            _ = y;
            _ = color;
            self.events.append(std.testing.allocator, .{ .kind = .icon, .text = text, .bg_id = bg.r }) catch unreachable;
        }
    };

    var events = std.ArrayList(Event).empty;
    defer events.deinit(std.testing.allocator);
    const ops = [_]ReplayOp{
        .{ .kind = .text, .text = "A", .x = 1, .y = 2, .color = .{ .r = 1, .g = 0, .b = 0, .a = 255 }, .bg = .{ .r = 9, .g = 0, .b = 0, .a = 255 } },
        .{ .kind = .icon, .text = "I", .x = 3, .y = 4, .color = .{ .r = 2, .g = 0, .b = 0, .a = 255 }, .bg = .{ .r = 8, .g = 0, .b = 0, .a = 255 } },
    };
    replayBandOpsWith(FakeReplayer{ .events = &events }, &ops);

    try std.testing.expectEqual(@as(usize, 4), events.items.len);
    try std.testing.expectEqual(EventKind.begin, events.items[0].kind);
    try std.testing.expectEqual(EventKind.text, events.items[1].kind);
    try std.testing.expectEqualStrings("A", events.items[1].text);
    try std.testing.expectEqual(@as(u8, 9), events.items[1].bg_id);
    try std.testing.expectEqual(EventKind.icon, events.items[2].kind);
    try std.testing.expectEqualStrings("I", events.items[2].text);
    try std.testing.expectEqual(@as(u8, 8), events.items[2].bg_id);
    try std.testing.expectEqual(EventKind.end, events.items[3].kind);
}

test "replayBandOpsWith wraps empty op lists" {
    const EventKind = enum { begin, end };
    const Event = struct { kind: EventKind };
    const FakeReplayer = struct {
        events: *std.ArrayList(Event),
        fn beginBandCommandGroup(self: @This()) void {
            self.events.append(std.testing.allocator, .{ .kind = .begin }) catch unreachable;
        }
        fn endBandCommandGroup(self: @This()) void {
            self.events.append(std.testing.allocator, .{ .kind = .end }) catch unreachable;
        }
        fn replayBandTextOnBg(self: @This(), text: []const u8, x: f32, y: f32, color: Color, bg: Color) void {
            _ = self;
            _ = text;
            _ = x;
            _ = y;
            _ = color;
            _ = bg;
            unreachable;
        }
        fn replayBandIconTextOnBg(self: @This(), text: []const u8, x: f32, y: f32, color: Color, bg: Color) void {
            _ = self;
            _ = text;
            _ = x;
            _ = y;
            _ = color;
            _ = bg;
            unreachable;
        }
    };

    var events = std.ArrayList(Event).empty;
    defer events.deinit(std.testing.allocator);
    replayBandOpsWith(FakeReplayer{ .events = &events }, &[_]ReplayOp{});
    try std.testing.expectEqual(@as(usize, 2), events.items.len);
    try std.testing.expectEqual(EventKind.begin, events.items[0].kind);
    try std.testing.expectEqual(EventKind.end, events.items[1].kind);
}

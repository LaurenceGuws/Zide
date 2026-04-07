const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const present_trace_runtime = @import("present_trace_runtime.zig");
const renderer_text_host = @import("renderer_text_host.zig");

const Color = app_shell.Color;

pub const TextOp = struct {
    text: []const u8,
    x: f32,
    y: f32,
    color: Color,
    bg: Color,
};

pub fn beginSampleSectionCommandGroup(renderer: anytype) void {
    present_trace_runtime.noteSampleSectionCommandGroupBegin(renderer);
}

pub fn endSampleSectionCommandGroup(renderer: anytype) void {
    present_trace_runtime.noteSampleSectionCommandGroupEnd(renderer);
}

pub fn replaySampleSectionTextOnBg(renderer: anytype, op: TextOp) void {
    renderer_text_host.drawTextOnBg(renderer, op.text, op.x, op.y, op.color, op.bg);
}

pub fn replaySampleSectionTextOps(renderer: anytype, ops: []const TextOp) void {
    beginSampleSectionCommandGroup(renderer);
    defer endSampleSectionCommandGroup(renderer);
    for (ops) |op| replaySampleSectionTextOnBg(renderer, op);
}

pub fn replaySampleSectionTextOpsWith(replayer: anytype, ops: []const TextOp) void {
    replayer.beginSampleSectionCommandGroup();
    defer replayer.endSampleSectionCommandGroup();
    for (ops) |op| replayer.replaySampleSectionTextOnBg(op);
}

test "replaySampleSectionTextOpsWith preserves order and wraps group boundaries" {
    const EventKind = enum { begin, text, end };
    const Event = struct {
        kind: EventKind,
        text: []const u8 = "",
        bg_r: u8 = 0,
    };

    const FakeReplayer = struct {
        events: *std.ArrayList(Event),
        fn beginSampleSectionCommandGroup(self: @This()) void {
            self.events.append(std.testing.allocator, .{ .kind = .begin }) catch unreachable;
        }
        fn endSampleSectionCommandGroup(self: @This()) void {
            self.events.append(std.testing.allocator, .{ .kind = .end }) catch unreachable;
        }
        fn replaySampleSectionTextOnBg(self: @This(), op: TextOp) void {
            self.events.append(std.testing.allocator, .{ .kind = .text, .text = op.text, .bg_r = op.bg.r }) catch unreachable;
        }
    };

    var events = std.ArrayList(Event).empty;
    defer events.deinit(std.testing.allocator);
    const ops = [_]TextOp{
        .{ .text = "header", .x = 1, .y = 2, .color = .{ .r = 1, .g = 2, .b = 3, .a = 255 }, .bg = .{ .r = 10, .g = 0, .b = 0, .a = 255 } },
        .{ .text = "stress", .x = 3, .y = 4, .color = .{ .r = 4, .g = 5, .b = 6, .a = 255 }, .bg = .{ .r = 11, .g = 0, .b = 0, .a = 255 } },
    };
    replaySampleSectionTextOpsWith(FakeReplayer{ .events = &events }, &ops);
    try std.testing.expectEqual(@as(usize, 4), events.items.len);
    try std.testing.expectEqual(EventKind.begin, events.items[0].kind);
    try std.testing.expectEqual(EventKind.text, events.items[1].kind);
    try std.testing.expectEqualStrings("header", events.items[1].text);
    try std.testing.expectEqual(@as(u8, 10), events.items[1].bg_r);
    try std.testing.expectEqual(EventKind.text, events.items[2].kind);
    try std.testing.expectEqualStrings("stress", events.items[2].text);
    try std.testing.expectEqual(@as(u8, 11), events.items[2].bg_r);
    try std.testing.expectEqual(EventKind.end, events.items[3].kind);
}

test "replaySampleSectionTextOpsWith wraps empty section ops" {
    const EventKind = enum { begin, end };
    const Event = struct { kind: EventKind };

    const FakeReplayer = struct {
        events: *std.ArrayList(Event),
        fn beginSampleSectionCommandGroup(self: @This()) void {
            self.events.append(std.testing.allocator, .{ .kind = .begin }) catch unreachable;
        }
        fn endSampleSectionCommandGroup(self: @This()) void {
            self.events.append(std.testing.allocator, .{ .kind = .end }) catch unreachable;
        }
        fn replaySampleSectionTextOnBg(self: @This(), op: TextOp) void {
            _ = self;
            _ = op;
            unreachable;
        }
    };

    var events = std.ArrayList(Event).empty;
    defer events.deinit(std.testing.allocator);
    replaySampleSectionTextOpsWith(FakeReplayer{ .events = &events }, &[_]TextOp{});
    try std.testing.expectEqual(@as(usize, 2), events.items.len);
    try std.testing.expectEqual(EventKind.begin, events.items[0].kind);
    try std.testing.expectEqual(EventKind.end, events.items[1].kind);
}

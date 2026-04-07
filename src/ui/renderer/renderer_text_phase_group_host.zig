const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const present_trace_runtime = @import("present_trace_runtime.zig");
const renderer_text_host = @import("renderer_text_host.zig");

const Color = app_shell.Color;

pub const GroupKind = enum {
    chrome_band,
    sample_section,
};

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

pub fn beginGroup(renderer: anytype, kind: GroupKind) void {
    switch (kind) {
        .chrome_band => present_trace_runtime.noteBandCommandGroupBegin(renderer),
        .sample_section => present_trace_runtime.noteSampleSectionCommandGroupBegin(renderer),
    }
}

pub fn endGroup(renderer: anytype, kind: GroupKind) void {
    switch (kind) {
        .chrome_band => present_trace_runtime.noteBandCommandGroupEnd(renderer),
        .sample_section => present_trace_runtime.noteSampleSectionCommandGroupEnd(renderer),
    }
}

pub fn replayOpOnBg(renderer: anytype, op: ReplayOp) void {
    switch (op.kind) {
        .text => renderer_text_host.drawTextOnBg(renderer, op.text, op.x, op.y, op.color, op.bg),
        .icon => renderer_text_host.drawIconTextOnBg(renderer, op.text, op.x, op.y, op.color, op.bg),
    }
}

pub fn replayOps(renderer: anytype, group: GroupKind, ops: []const ReplayOp) void {
    beginGroup(renderer, group);
    defer endGroup(renderer, group);
    for (ops) |op| replayOpOnBg(renderer, op);
}

pub fn replayOpsWith(replayer: anytype, group: GroupKind, ops: []const ReplayOp) void {
    replayer.beginGroup(group);
    defer replayer.endGroup(group);
    for (ops) |op| replayer.replayOpOnBg(op);
}

test "replayOpsWith keeps order and wraps group" {
    const EventKind = enum { begin, op, end };
    const Event = struct {
        kind: EventKind,
        group: GroupKind,
        text: []const u8 = "",
    };
    const FakeReplayer = struct {
        events: *std.ArrayList(Event),
        fn beginGroup(self: @This(), group: GroupKind) void {
            self.events.append(std.testing.allocator, .{ .kind = .begin, .group = group }) catch unreachable;
        }
        fn endGroup(self: @This(), group: GroupKind) void {
            self.events.append(std.testing.allocator, .{ .kind = .end, .group = group }) catch unreachable;
        }
        fn replayOpOnBg(self: @This(), op: ReplayOp) void {
            self.events.append(std.testing.allocator, .{ .kind = .op, .group = .chrome_band, .text = op.text }) catch unreachable;
        }
    };
    var events = std.ArrayList(Event).empty;
    defer events.deinit(std.testing.allocator);
    const ops = [_]ReplayOp{
        .{ .kind = .text, .text = "A", .x = 0, .y = 0, .color = .{ .r = 1, .g = 1, .b = 1, .a = 255 }, .bg = .{ .r = 2, .g = 2, .b = 2, .a = 255 } },
        .{ .kind = .icon, .text = "I", .x = 1, .y = 1, .color = .{ .r = 3, .g = 3, .b = 3, .a = 255 }, .bg = .{ .r = 4, .g = 4, .b = 4, .a = 255 } },
    };
    replayOpsWith(FakeReplayer{ .events = &events }, .sample_section, &ops);
    try std.testing.expectEqual(@as(usize, 4), events.items.len);
    try std.testing.expectEqual(EventKind.begin, events.items[0].kind);
    try std.testing.expectEqual(GroupKind.sample_section, events.items[0].group);
    try std.testing.expectEqual(EventKind.op, events.items[1].kind);
    try std.testing.expectEqualStrings("A", events.items[1].text);
    try std.testing.expectEqual(EventKind.op, events.items[2].kind);
    try std.testing.expectEqualStrings("I", events.items[2].text);
    try std.testing.expectEqual(EventKind.end, events.items[3].kind);
    try std.testing.expectEqual(GroupKind.sample_section, events.items[3].group);
}

test "replayOpsWith wraps empty group" {
    const EventKind = enum { begin, end };
    const Event = struct { kind: EventKind, group: GroupKind };
    const FakeReplayer = struct {
        events: *std.ArrayList(Event),
        fn beginGroup(self: @This(), group: GroupKind) void {
            self.events.append(std.testing.allocator, .{ .kind = .begin, .group = group }) catch unreachable;
        }
        fn endGroup(self: @This(), group: GroupKind) void {
            self.events.append(std.testing.allocator, .{ .kind = .end, .group = group }) catch unreachable;
        }
        fn replayOpOnBg(self: @This(), op: ReplayOp) void {
            _ = self;
            _ = op;
            unreachable;
        }
    };
    var events = std.ArrayList(Event).empty;
    defer events.deinit(std.testing.allocator);
    replayOpsWith(FakeReplayer{ .events = &events }, .chrome_band, &[_]ReplayOp{});
    try std.testing.expectEqual(@as(usize, 2), events.items.len);
    try std.testing.expectEqual(EventKind.begin, events.items[0].kind);
    try std.testing.expectEqual(GroupKind.chrome_band, events.items[0].group);
    try std.testing.expectEqual(EventKind.end, events.items[1].kind);
    try std.testing.expectEqual(GroupKind.chrome_band, events.items[1].group);
}

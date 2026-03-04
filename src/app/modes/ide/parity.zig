const runtime_bridge = @import("../runtime_bridge.zig");
const shared = @import("../shared/mod.zig");
const ide = @import("host.zig");

pub const Mismatch = struct {
    index: usize,
    expected_id: ?u64,
    actual_id: ?u64,
    expected_title: []const u8,
    actual_title: []const u8,
};

pub const KindParity = struct {
    expected_count: usize,
    actual_count: usize,
    expected_active: ?u64,
    actual_active: ?u64,
    mismatch: ?Mismatch,
};

pub fn evaluateKind(
    projections: []const runtime_bridge.AppTabProjection,
    kind: shared.types.ViewKind,
    active: runtime_bridge.ActiveProjection,
    mode_tabs: []const shared.contracts.ModeTab,
    mode_active: ?u64,
) KindParity {
    var expected_count: usize = 0;
    for (projections) |p| {
        if (p.kind == kind) expected_count += 1;
    }

    const expected_active: ?u64 = switch (active.kind) {
        .editor => if (kind == .editor) active.id else null,
        .terminal => if (kind == .terminal) active.id else null,
    };

    return .{
        .expected_count = expected_count,
        .actual_count = mode_tabs.len,
        .expected_active = expected_active,
        .actual_active = mode_active,
        .mismatch = firstMismatch(projections, kind, mode_tabs),
    };
}

fn firstMismatch(
    projections: []const runtime_bridge.AppTabProjection,
    kind: shared.types.ViewKind,
    mode_tabs: []const shared.contracts.ModeTab,
) ?Mismatch {
    var expected_idx: usize = 0;
    for (projections) |p| {
        if (p.kind != kind) continue;
        if (expected_idx >= mode_tabs.len) {
            return .{
                .index = expected_idx,
                .expected_id = p.id,
                .actual_id = null,
                .expected_title = p.title,
                .actual_title = "<missing>",
            };
        }
        const actual = mode_tabs[expected_idx];
        if (actual.id != p.id or actual.alive != p.alive or !std.mem.eql(u8, actual.title, p.title)) {
            return .{
                .index = expected_idx,
                .expected_id = p.id,
                .actual_id = actual.id,
                .expected_title = p.title,
                .actual_title = actual.title,
            };
        }
        expected_idx += 1;
    }
    if (expected_idx < mode_tabs.len) {
        const extra = mode_tabs[expected_idx];
        return .{
            .index = expected_idx,
            .expected_id = null,
            .actual_id = extra.id,
            .expected_title = "<missing>",
            .actual_title = extra.title,
        };
    }
    return null;
}

const std = @import("std");

test "evaluateKind reports counts, active, and first mismatch" {
    const projections = [_]runtime_bridge.AppTabProjection{
        .{ .kind = .editor, .id = 1, .title = "e1", .alive = true },
        .{ .kind = .terminal, .id = 2, .title = "t1", .alive = true },
        .{ .kind = .editor, .id = 3, .title = "e2", .alive = true },
    };
    const tabs = [_]shared.contracts.ModeTab{
        .{ .id = 1, .title = "e1", .alive = true },
        .{ .id = 3, .title = "DIFF", .alive = true },
    };
    const parity = evaluateKind(
        projections[0..],
        .editor,
        .{ .kind = ide.ActiveMode.editor, .id = 3 },
        tabs[0..],
        1,
    );

    try std.testing.expectEqual(@as(usize, 2), parity.expected_count);
    try std.testing.expectEqual(@as(usize, 2), parity.actual_count);
    try std.testing.expectEqual(@as(?u64, 3), parity.expected_active);
    try std.testing.expectEqual(@as(?u64, 1), parity.actual_active);
    try std.testing.expect(parity.mismatch != null);
    try std.testing.expectEqual(@as(usize, 1), parity.mismatch.?.index);
    try std.testing.expectEqual(@as(?u64, 3), parity.mismatch.?.expected_id);
    try std.testing.expectEqual(@as(?u64, 3), parity.mismatch.?.actual_id);
}

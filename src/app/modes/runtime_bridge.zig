const std = @import("std");
const modes = @import("mod.zig");

pub const AppTabProjection = struct {
    kind: modes.shared.types.ViewKind,
    id: modes.shared.types.TabId,
    title: []const u8,
    alive: bool = true,
};

pub const ActiveProjection = struct {
    kind: modes.ide.ActiveMode,
    id: ?modes.shared.types.TabId = null,
};

pub fn syncModesFromProjections(
    allocator: std.mem.Allocator,
    editor_mode: *modes.backend.EditorMode,
    terminal_mode: *modes.backend.TerminalMode,
    projections: []const AppTabProjection,
    active: ActiveProjection,
) !void {
    var editor_tabs = std.ArrayList(modes.bridge.TabView).empty;
    defer editor_tabs.deinit(allocator);
    var terminal_tabs = std.ArrayList(modes.bridge.TabView).empty;
    defer terminal_tabs.deinit(allocator);

    for (projections) |p| {
        const view: modes.bridge.TabView = .{
            .id = p.id,
            .title = p.title,
            .alive = p.alive,
        };
        switch (p.kind) {
            .editor => try editor_tabs.append(allocator, view),
            .terminal => try terminal_tabs.append(allocator, view),
        }
    }

    const active_editor = if (active.kind == .editor) active.id else null;
    const active_terminal = if (active.kind == .terminal) active.id else null;

    try modes.bridge.syncEditorModeFromViews(editor_mode, allocator, editor_tabs.items, active_editor);
    try modes.bridge.syncTerminalModeFromViews(terminal_mode, allocator, terminal_tabs.items, active_terminal);
}

test "runtime bridge syncs editor and terminal buckets" {
    const allocator = std.testing.allocator;
    var editor = modes.backend.EditorMode.init(allocator);
    defer editor.deinit(allocator);
    var terminal = modes.backend.TerminalMode.init(allocator);
    defer terminal.deinit(allocator);

    const projections = [_]AppTabProjection{
        .{ .kind = .editor, .id = 1, .title = "e1", .alive = true },
        .{ .kind = .terminal, .id = 2, .title = "t1", .alive = true },
        .{ .kind = .editor, .id = 3, .title = "e2", .alive = false },
    };
    try syncModesFromProjections(
        allocator,
        &editor,
        &terminal,
        projections[0..],
        .{ .kind = .editor, .id = 3 },
    );

    const editor_snap = try editor.asContract().snapshot(allocator);
    const terminal_snap = try terminal.asContract().snapshot(allocator);
    try std.testing.expectEqual(@as(usize, 2), editor_snap.tabs.len);
    try std.testing.expectEqual(@as(usize, 1), terminal_snap.tabs.len);
    try std.testing.expectEqual(@as(?modes.shared.types.TabId, 3), editor_snap.active_tab);
    try std.testing.expectEqual(@as(?modes.shared.types.TabId, 2), terminal_snap.active_tab);
}

test "runtime bridge tracks projection transitions across sync passes" {
    const allocator = std.testing.allocator;
    var editor = modes.backend.EditorMode.init(allocator);
    defer editor.deinit(allocator);
    var terminal = modes.backend.TerminalMode.init(allocator);
    defer terminal.deinit(allocator);

    const initial = [_]AppTabProjection{
        .{ .kind = .editor, .id = 10, .title = "e1", .alive = true },
        .{ .kind = .editor, .id = 11, .title = "e2", .alive = true },
        .{ .kind = .terminal, .id = 21, .title = "t1", .alive = true },
    };
    try syncModesFromProjections(
        allocator,
        &editor,
        &terminal,
        initial[0..],
        .{ .kind = .editor, .id = 11 },
    );

    var editor_snap = try editor.asContract().snapshot(allocator);
    var terminal_snap = try terminal.asContract().snapshot(allocator);
    try std.testing.expectEqual(@as(usize, 2), editor_snap.tabs.len);
    try std.testing.expectEqual(@as(usize, 1), terminal_snap.tabs.len);
    try std.testing.expectEqual(@as(?modes.shared.types.TabId, 11), editor_snap.active_tab);
    try std.testing.expectEqual(@as(?modes.shared.types.TabId, 21), terminal_snap.active_tab);

    const reordered = [_]AppTabProjection{
        .{ .kind = .terminal, .id = 21, .title = "t1", .alive = true },
        .{ .kind = .editor, .id = 11, .title = "e2", .alive = true },
        .{ .kind = .editor, .id = 10, .title = "e1", .alive = true },
        .{ .kind = .terminal, .id = 22, .title = "t2", .alive = true },
    };
    try syncModesFromProjections(
        allocator,
        &editor,
        &terminal,
        reordered[0..],
        .{ .kind = .terminal, .id = 22 },
    );

    editor_snap = try editor.asContract().snapshot(allocator);
    terminal_snap = try terminal.asContract().snapshot(allocator);
    try std.testing.expectEqual(@as(usize, 2), editor_snap.tabs.len);
    try std.testing.expectEqual(@as(usize, 2), terminal_snap.tabs.len);
    try std.testing.expectEqual(@as(?modes.shared.types.TabId, 11), editor_snap.active_tab);
    try std.testing.expectEqual(@as(?modes.shared.types.TabId, 22), terminal_snap.active_tab);
    try std.testing.expectEqual(@as(modes.shared.types.TabId, 21), terminal_snap.tabs[0].id);
    try std.testing.expectEqual(@as(modes.shared.types.TabId, 22), terminal_snap.tabs[1].id);

    const after_close = [_]AppTabProjection{
        .{ .kind = .editor, .id = 11, .title = "e2", .alive = true },
        .{ .kind = .terminal, .id = 21, .title = "t1", .alive = true },
    };
    try syncModesFromProjections(
        allocator,
        &editor,
        &terminal,
        after_close[0..],
        .{ .kind = .terminal, .id = 21 },
    );

    editor_snap = try editor.asContract().snapshot(allocator);
    terminal_snap = try terminal.asContract().snapshot(allocator);
    try std.testing.expectEqual(@as(usize, 1), editor_snap.tabs.len);
    try std.testing.expectEqual(@as(usize, 1), terminal_snap.tabs.len);
    try std.testing.expectEqual(@as(?modes.shared.types.TabId, 11), editor_snap.active_tab);
    try std.testing.expectEqual(@as(?modes.shared.types.TabId, 21), terminal_snap.active_tab);
}

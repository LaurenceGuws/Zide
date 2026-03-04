const terminal_mod = @import("../terminal/core/terminal.zig");
const std = @import("std");

pub fn routeActiveTabId(
    terminal_workspace: *?terminal_mod.TerminalWorkspace,
    ctx: *anyopaque,
    route_fn: *const fn (*anyopaque, ?u64) anyerror!bool,
) !bool {
    if (terminal_workspace.*) |*workspace| {
        return try route_fn(ctx, workspace.activeTabId());
    }
    return false;
}

test "routeActiveTabId handles missing workspace and forwards active id when present" {
    var no_workspace: ?terminal_mod.TerminalWorkspace = null;
    var calls: usize = 0;
    var saw_id: ?u64 = 123;

    try std.testing.expect(!try routeActiveTabId(
        &no_workspace,
        @ptrCast(&calls),
        struct {
            fn call(raw: *anyopaque, id: ?u64) !bool {
                const count: *usize = @ptrCast(@alignCast(raw));
                count.* += 1;
                _ = id;
                return true;
            }
        }.call,
    ));
    try std.testing.expectEqual(@as(usize, 0), calls);

    var workspace = terminal_mod.TerminalWorkspace.init(std.testing.allocator, .{});
    defer workspace.deinit();
    var with_workspace: ?terminal_mod.TerminalWorkspace = workspace;

    const invoked = try routeActiveTabId(
        &with_workspace,
        @ptrCast(&saw_id),
        struct {
            fn call(raw: *anyopaque, id: ?u64) !bool {
                const seen: *?u64 = @ptrCast(@alignCast(raw));
                seen.* = id;
                return true;
            }
        }.call,
    );
    try std.testing.expect(invoked);
    try std.testing.expectEqual(@as(?u64, null), saw_id);
}

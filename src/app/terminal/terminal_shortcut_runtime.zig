const app_modes = @import("../modes/mod.zig");
const std = @import("std");

pub const RuntimeHooks = struct {
    request_create: *const fn (ctx: *anyopaque, now: f64) anyerror!bool,
    request_close: *const fn (ctx: *anyopaque, now: f64) anyerror!bool,
    request_cycle: *const fn (ctx: *anyopaque, dir: app_modes.ide.TerminalShortcutCycleDirection, now: f64) anyerror!bool,
    request_focus: *const fn (ctx: *anyopaque, route: app_modes.ide.TerminalFocusRoute, now: f64) anyerror!bool,
};

pub fn handleIntent(
    intent: app_modes.ide.TerminalShortcutIntent,
    now: f64,
    ctx: *anyopaque,
    hooks: RuntimeHooks,
) !bool {
    return switch (intent) {
        .create => hooks.request_create(ctx, now),
        .close => hooks.request_close(ctx, now),
        .cycle => |dir| hooks.request_cycle(ctx, dir, now),
        .focus => |route| hooks.request_focus(ctx, route, now),
    };
}

test "handleIntent dispatches to matching runtime hook" {
    const Ctx = struct {
        create_calls: usize = 0,
        close_calls: usize = 0,
        cycle_calls: usize = 0,
        focus_calls: usize = 0,
        last_cycle: ?app_modes.ide.TerminalShortcutCycleDirection = null,
        last_focus: ?usize = null,
    };

    var ctx = Ctx{};
    const hooks: RuntimeHooks = .{
        .request_create = struct {
            fn call(raw: *anyopaque, _: f64) !bool {
                const payload: *Ctx = @ptrCast(@alignCast(raw));
                payload.create_calls += 1;
                return true;
            }
        }.call,
        .request_close = struct {
            fn call(raw: *anyopaque, _: f64) !bool {
                const payload: *Ctx = @ptrCast(@alignCast(raw));
                payload.close_calls += 1;
                return true;
            }
        }.call,
        .request_cycle = struct {
            fn call(raw: *anyopaque, dir: app_modes.ide.TerminalShortcutCycleDirection, _: f64) !bool {
                const payload: *Ctx = @ptrCast(@alignCast(raw));
                payload.cycle_calls += 1;
                payload.last_cycle = dir;
                return true;
            }
        }.call,
        .request_focus = struct {
            fn call(raw: *anyopaque, route: app_modes.ide.TerminalFocusRoute, _: f64) !bool {
                const payload: *Ctx = @ptrCast(@alignCast(raw));
                payload.focus_calls += 1;
                payload.last_focus = route.index;
                return true;
            }
        }.call,
    };

    try std.testing.expect(try handleIntent(.create, 1.0, @ptrCast(&ctx), hooks));
    try std.testing.expect(try handleIntent(.close, 2.0, @ptrCast(&ctx), hooks));
    try std.testing.expect(try handleIntent(.{ .cycle = .prev }, 3.0, @ptrCast(&ctx), hooks));
    try std.testing.expect(try handleIntent(.{ .focus = .{
        .index = 4,
        .intent = .{ .activate_by_index = 4 },
    } }, 4.0, @ptrCast(&ctx), hooks));

    try std.testing.expectEqual(@as(usize, 1), ctx.create_calls);
    try std.testing.expectEqual(@as(usize, 1), ctx.close_calls);
    try std.testing.expectEqual(@as(usize, 1), ctx.cycle_calls);
    try std.testing.expectEqual(@as(usize, 1), ctx.focus_calls);
    try std.testing.expectEqual(@as(?app_modes.ide.TerminalShortcutCycleDirection, .prev), ctx.last_cycle);
    try std.testing.expectEqual(@as(?usize, 4), ctx.last_focus);
}

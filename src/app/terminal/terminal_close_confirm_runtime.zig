const app_modes = @import("../modes/mod.zig");
const std = @import("std");

pub const RuntimeHooks = struct {
    confirm: *const fn (ctx: *anyopaque, now: f64) anyerror!bool,
    cancel: *const fn (ctx: *anyopaque, now: f64) anyerror!bool,
};

pub fn applyDecision(
    decision: app_modes.ide.TerminalCloseConfirmDecision,
    now: f64,
    ctx: *anyopaque,
    hooks: RuntimeHooks,
) !bool {
    return switch (decision) {
        .confirm => hooks.confirm(ctx, now),
        .cancel => hooks.cancel(ctx, now),
        .consume => true,
        .none => false,
    };
}

test "applyDecision dispatches confirm/cancel hooks and handles consume/none" {
    const Ctx = struct {
        confirm_calls: usize = 0,
        cancel_calls: usize = 0,
    };

    var ctx = Ctx{};
    const hooks: RuntimeHooks = .{
        .confirm = struct {
            fn call(raw: *anyopaque, _: f64) !bool {
                const payload: *Ctx = @ptrCast(@alignCast(raw));
                payload.confirm_calls += 1;
                return true;
            }
        }.call,
        .cancel = struct {
            fn call(raw: *anyopaque, _: f64) !bool {
                const payload: *Ctx = @ptrCast(@alignCast(raw));
                payload.cancel_calls += 1;
                return true;
            }
        }.call,
    };

    try std.testing.expect(try applyDecision(.confirm, 1.0, @ptrCast(&ctx), hooks));
    try std.testing.expect(try applyDecision(.cancel, 2.0, @ptrCast(&ctx), hooks));
    try std.testing.expect(try applyDecision(.consume, 3.0, @ptrCast(&ctx), hooks));
    try std.testing.expect(!try applyDecision(.none, 4.0, @ptrCast(&ctx), hooks));

    try std.testing.expectEqual(@as(usize, 1), ctx.confirm_calls);
    try std.testing.expectEqual(@as(usize, 1), ctx.cancel_calls);
}

//! Renderer present execution wrapper: dispatches to refresh or direct flow based on backend mode.
//! **Result ownership:** this module mediates between backend dispatch and widget presentation
//! runtime. `TerminalPresentResult` from `presentable_contract` is the
//! single result type used by all flows; runtime populates it via canonical outcome-folding helpers
//! in `terminal_widget_presentation_runtime.zig`. This module does not derive or compute present
//! state or result values — it routes to the appropriate flow via `Hooks`.
const present_feedback_host = @import("present_feedback_host.zig");
const capability_contract = @import("capability_contract.zig");
const presentable_contract = @import("presentable_contract.zig");

pub const TerminalPresentableRefresh = @import("backend_dispatch.zig").TerminalPresentableRefreshResult;
const PresentableDraw = presentable_contract.PresentableDraw;
pub const TerminalPresentPlan = presentable_contract.TerminalPresentPlan;
pub const TerminalPresentResult = presentable_contract.TerminalPresentResult;
pub const TerminalPresentTiming = presentable_contract.TerminalPresentTiming;
const TerminalPresentationMode = capability_contract.TerminalPresentationMode;

pub const TerminalPresentableRefreshExecutionResult = struct {
    completed: bool = false,
    refresh: TerminalPresentableRefresh = .unsupported,
    timing: TerminalPresentTiming = .{},
};

pub const DirectTerminalPresentExecutionResult = struct {
    completed: bool = false,
    updated: bool = false,
    timing: TerminalPresentTiming = .{},
};

pub fn terminalPresentationMode(renderer: anytype) TerminalPresentationMode {
    return renderer.capabilities().terminal_presentation_mode;
}

pub fn terminalUsesRetainedPresentSurface(renderer: anytype) bool {
    return terminalPresentationMode(renderer) == .retained_surface;
}

pub fn terminalSupportsPresentableRefresh(renderer: anytype) bool {
    return terminalPresentationMode(renderer) != .direct_main_target;
}

pub fn runTerminalPresentExecution(
    renderer: anytype,
    plan: TerminalPresentPlan,
    ctx: anytype,
    comptime Hooks: type,
) TerminalPresentResult {
    if (terminalSupportsPresentableRefresh(renderer)) {
        return Hooks.executePresentableRefreshFlow(plan, ctx, renderer);
    }
    return Hooks.executeDirectPresentFlow(plan, ctx, renderer);
}

pub fn terminalUsesRefreshDrivenRecentInputPolicy(renderer: anytype) bool {
    return terminalUsesRetainedPresentSurface(renderer);
}

pub fn terminalSupportsReuseWithoutSyncUpdates(renderer: anytype) bool {
    return !terminalUsesRetainedPresentSurface(renderer);
}

pub fn terminalSupportsIncrementalPresentableUpdate(renderer: anytype) bool {
    return terminalPresentationMode(renderer) == .direct_snapshot_cache;
}

pub fn ensureTerminalPresentable(renderer: anytype, width: i32, height: i32) bool {
    return renderer.backend.ensurePresentable(renderer, width, height);
}

pub fn refreshTerminalPresentable(renderer: anytype, plan: TerminalPresentPlan, ctx: anytype, comptime body: fn (@TypeOf(ctx), @TypeOf(renderer)) void) TerminalPresentableRefresh {
    const Local = struct {
        fn erasedBody(raw_ctx: ?*const anyopaque, renderer_local: @TypeOf(renderer)) void {
            const typed_ctx: *@TypeOf(ctx) = @ptrCast(@alignCast(@constCast(raw_ctx.?)));
            body(typed_ctx.*, renderer_local);
        }
    };
    return renderer.backend.refreshTerminalPresentable(
        renderer,
        plan,
        @ptrCast(&ctx),
        Local.erasedBody,
    );
}

pub fn runTerminalPresentableRefreshExecution(
    renderer: anytype,
    plan: TerminalPresentPlan,
    ctx: anytype,
    comptime Hooks: type,
) TerminalPresentableRefreshExecutionResult {
    var result = TerminalPresentableRefreshExecutionResult{};
    if (plan.update_intent == .none) return result;

    const ExecCtx = struct {
        inner: @TypeOf(ctx),
        plan: TerminalPresentPlan,
        out: *TerminalPresentableRefreshExecutionResult,
    };
    const Local = struct {
        fn run(raw_ctx: ?*const anyopaque, renderer_local: @TypeOf(renderer)) void {
            const typed_ctx: *ExecCtx = @ptrCast(@alignCast(@constCast(raw_ctx.?)));
            typed_ctx.out.timing = Hooks.executeUpdate(typed_ctx.inner, renderer_local, typed_ctx.plan);
            typed_ctx.out.completed = true;
        }
    };
    const call_ctx = ExecCtx{
        .inner = ctx,
        .plan = plan,
        .out = &result,
    };
    result.refresh = renderer.backend.refreshTerminalPresentable(
        renderer,
        plan,
        @ptrCast(&call_ctx),
        Local.run,
    );
    return result;
}

pub fn runDirectTerminalPresentExecution(
    renderer: anytype,
    plan: TerminalPresentPlan,
    ctx: anytype,
    comptime Hooks: type,
) DirectTerminalPresentExecutionResult {
    var result = DirectTerminalPresentExecutionResult{};
    if (terminalSupportsPresentableRefresh(renderer)) return result;

    if (plan.update_intent == .partial) {
        result = Hooks.tryPartialUpdate(ctx, renderer, plan);
        if (result.completed) return result;
    }

    result = Hooks.executePresent(ctx, renderer, plan);
    result.completed = true;
    return result;
}

pub fn drawTerminalPresentableBackdrop(renderer: anytype, x: f32, y: f32, w: f32, h: f32, color: @import("types.zig").Rgba) void {
    renderer.backend.drawPresentableBackdrop(renderer, x, y, w, h, color);
}

pub fn drawTerminalPresentable(renderer: anytype, draw: PresentableDraw) void {
    present_feedback_host.noteTerminalPresentation(renderer, draw.generation);
    renderer.backend.drawPresentable(renderer, draw);
}

pub fn presentExistingTerminalPresentable(
    renderer: anytype,
    sample_generation: u64,
    surface_generation: u64,
    view_geometry: anytype,
    viewport_w: f32,
    viewport_h: f32,
    note_present_ctx: anytype,
    comptime Hooks: type,
) void {
    if (terminalUsesRetainedPresentSurface(renderer)) {
        Hooks.noteRetainedReuse(
            note_present_ctx,
            renderer,
            sample_generation,
            view_geometry,
            viewport_w,
            viewport_h,
        );
    } else {
        Hooks.noteDirectReuse(
            note_present_ctx,
            renderer,
            sample_generation,
            view_geometry,
            viewport_w,
            viewport_h,
        );
    }
    drawTerminalPresentable(renderer, .{
        .x = view_geometry.origin_x,
        .y = view_geometry.origin_y,
        .width = viewport_w,
        .height = viewport_h,
        .source_width = viewport_w,
        .source_height = viewport_h,
        .generation = surface_generation,
    });
}

pub fn scrollTerminalPresentable(renderer: anytype, dx: i32, dy: i32) bool {
    return renderer.backend.scrollPresentable(renderer, dx, dy);
}

pub fn terminalPresentableInfo(renderer: anytype) @TypeOf(renderer.backend.presentableInfo(renderer)) {
    return renderer.backend.presentableInfo(renderer);
}

test "refresh execution does not require ctx.result field" {
    const std = @import("std");

    const FakeBackend = struct {
        pub fn refreshTerminalPresentable(
            _: @This(),
            renderer: anytype,
            _: TerminalPresentPlan,
            raw_ctx: ?*const anyopaque,
            body: fn (?*const anyopaque, @TypeOf(renderer)) void,
        ) TerminalPresentableRefresh {
            body(raw_ctx, renderer);
            return .refreshed;
        }
    };

    const FakeRenderer = struct {
        backend: FakeBackend = .{},
    };

    const Hooks = struct {
        pub fn executeUpdate(_: anytype, _: FakeRenderer, _: TerminalPresentPlan) TerminalPresentTiming {
            return .{ .background_ms = 1.0, .glyph_ms = 2.0, .kitty_ms = 3.0 };
        }
    };

    const ctx = struct { x: u8 }{ .x = 7 };
    const renderer = FakeRenderer{};

    const plan = TerminalPresentPlan{
        .update_intent = .full,
        .surface_geometry = .{
            .logical_width = 1,
            .logical_height = 1,
            .visible_width = 1,
            .visible_height = 1,
            .dest_x = 0,
            .dest_y = 0,
            .dest_width = 1,
            .dest_height = 1,
        },
    };

    const result = runTerminalPresentableRefreshExecution(renderer, plan, ctx, Hooks);
    try std.testing.expect(result.completed);
    try std.testing.expectEqual(@as(f64, 1.0), result.timing.background_ms);
    try std.testing.expectEqual(@as(f64, 2.0), result.timing.glyph_ms);
    try std.testing.expectEqual(@as(f64, 3.0), result.timing.kitty_ms);
    try std.testing.expectEqual(TerminalPresentableRefresh.refreshed, result.refresh);
}

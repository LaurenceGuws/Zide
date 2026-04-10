const present_trace_runtime = @import("present_trace_runtime.zig");
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

pub fn runTerminalPresentExecution(
    renderer: anytype,
    plan: TerminalPresentPlan,
    ctx: anytype,
    comptime Hooks: type,
) TerminalPresentResult {
    if (terminalUsesRetainedPresentSurface(renderer)) {
        return Hooks.executePresentableRefreshFlow(plan, ctx, renderer);
    }
    return Hooks.executeDirectPresentFlow(plan, ctx, renderer);
}

pub fn terminalAllowsRecentInputForceFullPresentation(renderer: anytype) bool {
    return terminalUsesRetainedPresentSurface(renderer);
}

pub fn terminalAllowsFastPresentReuse(renderer: anytype, sync_updates_active: bool) bool {
    return sync_updates_active or !terminalUsesRetainedPresentSurface(renderer);
}

pub fn terminalSupportsDirectPartialUpdate(renderer: anytype) bool {
    return terminalPresentationMode(renderer) == .direct_snapshot_cache;
}

pub fn ensureTerminalPresentable(renderer: anytype, width: i32, height: i32) bool {
    return renderer.backend.ensurePresentable(renderer, width, height);
}

pub fn refreshTerminalPresentable(renderer: anytype, ctx: anytype, comptime body: fn (@TypeOf(ctx), @TypeOf(renderer)) void) TerminalPresentableRefresh {
    const Local = struct {
        fn erasedBody(raw_ctx: ?*const anyopaque, renderer_local: @TypeOf(renderer)) void {
            const typed_ctx: *@TypeOf(ctx) = @constCast(@alignCast(@ptrCast(raw_ctx.?)));
            body(typed_ctx.*, renderer_local);
        }
    };
    return renderer.backend.refreshTerminalPresentable(
        renderer,
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
    };
    const Local = struct {
        fn run(raw_ctx: ?*const anyopaque, renderer_local: @TypeOf(renderer)) void {
            const typed_ctx: *ExecCtx = @constCast(@alignCast(@ptrCast(raw_ctx.?)));
            typed_ctx.inner.result.timing = Hooks.executeUpdate(typed_ctx.inner, renderer_local, typed_ctx.plan);
            typed_ctx.inner.result.completed = true;
        }
    };
    var exec_ctx = ctx;
    exec_ctx.result = &result;
    var call_ctx = ExecCtx{ .inner = exec_ctx, .plan = plan };
    result.refresh = renderer.backend.refreshTerminalPresentable(
        renderer,
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
    if (terminalUsesRetainedPresentSurface(renderer)) return result;

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
    present_trace_runtime.noteTerminalPresentation(renderer, draw.generation);
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

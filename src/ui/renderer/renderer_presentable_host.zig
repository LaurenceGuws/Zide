const present_trace_runtime = @import("present_trace_runtime.zig");
const presentable_contract = @import("presentable_contract.zig");

pub const RetainedTerminalPresentableUpdate = @import("backend_dispatch.zig").RetainedPresentableUpdateResult;
const PresentableDraw = presentable_contract.PresentableDraw;
const TerminalPresentPath = presentable_contract.TerminalPresentPath;
pub const TerminalPresentPlan = presentable_contract.TerminalPresentPlan;
pub const TerminalPresentResult = presentable_contract.TerminalPresentResult;
pub const TerminalPresentTiming = presentable_contract.TerminalPresentTiming;

pub const RetainedTerminalPresentExecutionResult = struct {
    completed: bool = false,
    update: RetainedTerminalPresentableUpdate = .unsupported,
    timing: TerminalPresentTiming = .{},
};

pub const DirectTerminalPresentExecutionResult = struct {
    completed: bool = false,
    updated: bool = false,
    timing: TerminalPresentTiming = .{},
};

pub fn runTerminalPresentPath(renderer: anytype, plan: TerminalPresentPlan, ctx: anytype, comptime Hooks: type) TerminalPresentResult {
    return switch (renderer.backend.terminalPresentPath(renderer)) {
        .direct_surface => Hooks.runDirect(plan, ctx, renderer),
        .retained_surface => Hooks.runRetained(plan, ctx, renderer),
    };
}

pub fn usesDirectTerminalPresentation(renderer: anytype) bool {
    return renderer.backend.terminalPresentPath(renderer) == .direct_surface;
}

pub fn ensureTerminalPresentable(renderer: anytype, width: i32, height: i32) bool {
    return renderer.backend.ensurePresentable(renderer, width, height);
}

pub fn updateTerminalPresentable(renderer: anytype, ctx: anytype, comptime body: fn (@TypeOf(ctx), @TypeOf(renderer)) void) RetainedTerminalPresentableUpdate {
    const Local = struct {
        fn erasedBody(raw_ctx: ?*const anyopaque, renderer_local: @TypeOf(renderer)) void {
            const typed_ctx: *@TypeOf(ctx) = @constCast(@alignCast(@ptrCast(raw_ctx.?)));
            body(typed_ctx.*, renderer_local);
        }
    };
    return renderer.backend.updateRetainedPresentable(
        renderer,
        @ptrCast(&ctx),
        Local.erasedBody,
    );
}

pub fn runRetainedTerminalPresentExecution(
    renderer: anytype,
    plan: TerminalPresentPlan,
    ctx: anytype,
    comptime Hooks: type,
) RetainedTerminalPresentExecutionResult {
    var result = RetainedTerminalPresentExecutionResult{};
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
    result.update = renderer.backend.updateRetainedPresentable(
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
    if (renderer.backend.terminalPresentPath(renderer) != .direct_surface) return result;

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
    switch (renderer.backend.terminalPresentPath(renderer)) {
        .direct_surface => Hooks.noteDirectReuse(
            note_present_ctx,
            renderer,
            sample_generation,
            view_geometry,
            viewport_w,
            viewport_h,
        ),
        .retained_surface => Hooks.noteRetainedReuse(
            note_present_ctx,
            renderer,
            sample_generation,
            view_geometry,
            viewport_w,
            viewport_h,
        ),
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

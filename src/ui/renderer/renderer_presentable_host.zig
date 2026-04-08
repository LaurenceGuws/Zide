const present_trace_runtime = @import("present_trace_runtime.zig");
const presentable_contract = @import("presentable_contract.zig");

pub const RetainedTerminalPresentableUpdate = @import("backend_dispatch.zig").RetainedPresentableUpdateResult;
const PresentableDraw = presentable_contract.PresentableDraw;
const TerminalPresentPath = presentable_contract.TerminalPresentPath;
pub const TerminalPresentPlan = presentable_contract.TerminalPresentPlan;
pub const TerminalPresentResult = presentable_contract.TerminalPresentResult;

pub fn runTerminalPresentPath(renderer: anytype, plan: TerminalPresentPlan, ctx: anytype, comptime Hooks: type) TerminalPresentResult {
    return switch (renderer.backend.ops.presentable.terminalPresentPath(renderer)) {
        .direct_surface => Hooks.runDirect(plan, ctx, renderer),
        .retained_surface => Hooks.runRetained(plan, ctx, renderer),
    };
}

pub fn usesDirectTerminalPresentation(renderer: anytype) bool {
    return renderer.backend.ops.presentable.terminalPresentPath(renderer) == .direct_surface;
}

pub fn ensureTerminalPresentable(renderer: anytype, width: i32, height: i32) bool {
    return renderer.backend.ops.presentable.ensurePresentable(renderer, width, height);
}

pub fn updateTerminalPresentable(renderer: anytype, ctx: anytype, comptime body: fn (@TypeOf(ctx), @TypeOf(renderer)) void) RetainedTerminalPresentableUpdate {
    const Local = struct {
        fn erasedBody(raw_ctx: ?*const anyopaque, renderer_local: @TypeOf(renderer)) void {
            const typed_ctx: *@TypeOf(ctx) = @constCast(@alignCast(@ptrCast(raw_ctx.?)));
            body(typed_ctx.*, renderer_local);
        }
    };
    return renderer.backend.ops.presentable.updateRetainedPresentable(
        renderer,
        @ptrCast(&ctx),
        Local.erasedBody,
    );
}

pub fn drawTerminalPresentableBackdrop(renderer: anytype, x: f32, y: f32, w: f32, h: f32, color: @import("types.zig").Rgba) void {
    renderer.backend.ops.presentable.drawPresentableBackdrop(renderer, x, y, w, h, color);
}

pub fn drawTerminalPresentable(renderer: anytype, draw: PresentableDraw) void {
    present_trace_runtime.noteTerminalPresentation(renderer, draw.generation);
    renderer.backend.ops.presentable.drawPresentable(renderer, draw);
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
    switch (renderer.backend.ops.presentable.terminalPresentPath(renderer)) {
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
    return renderer.backend.ops.presentable.scrollPresentable(renderer, dx, dy);
}

pub fn terminalPresentableInfo(renderer: anytype) @TypeOf(renderer.backend.ops.presentable.presentableInfo(renderer)) {
    return renderer.backend.ops.presentable.presentableInfo(renderer);
}

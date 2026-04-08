const present_trace_runtime = @import("present_trace_runtime.zig");
const presentable_contract = @import("presentable_contract.zig");
const capability_contract = @import("capability_contract.zig");

pub const RetainedTerminalPresentableUpdate = @import("backend_dispatch.zig").RetainedPresentableUpdateResult;
const PresentableDraw = presentable_contract.PresentableDraw;
const TerminalPresentPath = presentable_contract.TerminalPresentPath;
pub const TerminalPresentationMode = capability_contract.TerminalPresentationMode;

pub fn terminalPresentationMode(renderer: anytype) TerminalPresentationMode {
    return renderer.capabilities().terminal_presentation_mode;
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

pub fn scrollTerminalPresentable(renderer: anytype, dx: i32, dy: i32) bool {
    return renderer.backend.ops.presentable.scrollPresentable(renderer, dx, dy);
}

pub fn terminalPresentableInfo(renderer: anytype) @TypeOf(renderer.backend.ops.presentable.presentableInfo(renderer)) {
    return renderer.backend.ops.presentable.presentableInfo(renderer);
}

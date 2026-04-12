const metal_backend = @import("metal_backend.zig");
const metal_text_sample_runtime = @import("metal_text_sample_runtime.zig");
const presentable_contract = @import("presentable_contract.zig");
const types = @import("types.zig");

const TerminalPresentableRefreshResult = @import("backend_dispatch.zig").TerminalPresentableRefreshResult;
const PresentableDraw = presentable_contract.PresentableDraw;
const PresentableInfo = presentable_contract.PresentableInfo;

pub fn ensurePresentable(renderer: anytype, width: i32, height: i32) bool {
    const drawable_width = renderer.render_width;
    const drawable_height = renderer.render_height;
    if (drawable_width <= 0 or drawable_height <= 0) return false;
    const context = metal_backend.backendContext(renderer) orelse return false;
    metal_backend.setTerminalSnapshotLogicalSize(context, width, height);
    return metal_backend.ensureTerminalSnapshotPresentable(context, drawable_width, drawable_height).recreated;
}

pub fn refreshTerminalPresentable(
    renderer: anytype,
    plan: presentable_contract.TerminalPresentPlan,
    ctx: ?*const anyopaque,
    body: *const fn (?*const anyopaque, @TypeOf(renderer)) void,
) TerminalPresentableRefreshResult {
    const drawable_width = renderer.render_width;
    const drawable_height = renderer.render_height;
    if (drawable_width <= 0 or drawable_height <= 0) return .target_unavailable;
    const context = metal_backend.backendContext(renderer) orelse return .target_unavailable;
    metal_backend.setTerminalSnapshotLogicalSize(context, plan.surface_geometry.logical_width, plan.surface_geometry.logical_height);
    if (!metal_backend.ensureTerminalSnapshotPresentable(context, drawable_width, drawable_height).available) {
        return .target_unavailable;
    }
    body(ctx, renderer);
    if (!metal_backend.refreshTerminalSnapshotPresentable(renderer)) return .target_unavailable;
    return .refreshed;
}

pub fn drawPresentableBackdrop(renderer: anytype, x: f32, y: f32, w: f32, h: f32, color: types.Rgba) void {
    if (w <= 0 or h <= 0) return;
    _ = metal_backend.recordPresentableDrawForComposition(renderer, .{ .solid = .{
        .dest_rect = .{
            .x = renderer.logicalLengthToRaster(x),
            .y = renderer.logicalLengthToRaster(y),
            .width = renderer.logicalLengthToRaster(w),
            .height = renderer.logicalLengthToRaster(h),
        },
        .color = color,
        .clip_rect = if (renderer.currentClipRect()) |clip_logical|
            metal_text_sample_runtime.pixelClipRect(renderer, clip_logical)
        else
            null,
    } });
}

pub fn presentableInfo(renderer: anytype) ?PresentableInfo {
    const context = metal_backend.backendContextConst(renderer) orelse return null;
    const snap = context.terminal_snapshot orelse return null;
    if (context.terminal_snapshot_logical_width <= 0 or context.terminal_snapshot_logical_height <= 0) return null;
    return .{
        .width_px = snap.width,
        .height_px = snap.height,
        .logical_width = context.terminal_snapshot_logical_width,
        .logical_height = context.terminal_snapshot_logical_height,
    };
}

pub fn drawPresentable(renderer: anytype, draw: PresentableDraw) void {
    const resolved = presentable_contract.resolveDraw(draw, null, null) orelse return;
    const context = metal_backend.backendContext(renderer) orelse return;
    const snapshot = context.terminal_snapshot orelse return;
    _ = metal_backend.recordPresentableDrawForComposition(renderer, .{ .raw_image = .{
        .texture = metal_backend.cloneGpuImageRef(snapshot),
        .source_rect = .{
            .x = 0,
            .y = 0,
            .width = renderer.logicalLengthToRaster(resolved.source_width),
            .height = renderer.logicalLengthToRaster(resolved.source_height),
        },
        .dest_rect = .{
            .x = renderer.logicalLengthToRaster(resolved.x),
            .y = renderer.logicalLengthToRaster(resolved.y),
            .width = renderer.logicalLengthToRaster(resolved.width),
            .height = renderer.logicalLengthToRaster(resolved.height),
        },
    } });
}

pub fn scrollPresentable(renderer: anytype, dx: i32, dy: i32) bool {
    const context = metal_backend.backendContext(renderer) orelse return false;
    return metal_backend.scrollTerminalSnapshotPresentable(context, dx, dy);
}

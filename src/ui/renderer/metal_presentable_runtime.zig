const metal_backend = @import("metal_backend.zig");
const metal_text_sample_runtime = @import("metal_text_sample_runtime.zig");
const presentable_contract = @import("presentable_contract.zig");
const types = @import("types.zig");

const PresentableDraw = presentable_contract.PresentableDraw;
const PresentableInfo = presentable_contract.PresentableInfo;
const PresentableSurface = presentable_contract.PresentableSurface;

pub fn ensurePresentable(renderer: anytype, surface: PresentableSurface, width: i32, height: i32) bool {
    return switch (surface) {
        .terminal => blk: {
            const drawable_width = renderer.render_width;
            const drawable_height = renderer.render_height;
            if (drawable_width <= 0 or drawable_height <= 0) break :blk false;
            const context = metal_backend.backendContext(renderer) orelse break :blk false;
            metal_backend.setTerminalSnapshotLogicalSize(context, width, height);
            break :blk metal_backend.ensureTerminalSnapshotPresentable(context, drawable_width, drawable_height).recreated;
        },
    };
}

pub fn beginPresentable(_: anytype, _: PresentableSurface) bool {
    return false;
}

pub fn endPresentable(_: anytype, _: PresentableSurface) void {}

pub fn drawPresentableBackdrop(renderer: anytype, surface: PresentableSurface, x: f32, y: f32, w: f32, h: f32, color: types.Rgba) void {
    if (surface != .terminal or w <= 0 or h <= 0) return;
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

pub fn presentableInfo(renderer: anytype, surface: PresentableSurface) ?PresentableInfo {
    if (surface != .terminal) return null;
    const context = metal_backend.backendContextConst(renderer) orelse return null;
    const snap = context.terminal_snapshot orelse return null;
    const logical_width = if (context.terminal_snapshot_logical_width > 0) context.terminal_snapshot_logical_width else renderer.width;
    const logical_height = if (context.terminal_snapshot_logical_height > 0) context.terminal_snapshot_logical_height else renderer.height;
    return .{
        .width_px = snap.width,
        .height_px = snap.height,
        .logical_width = logical_width,
        .logical_height = logical_height,
    };
}

pub fn drawPresentable(renderer: anytype, surface: PresentableSurface, draw: PresentableDraw) void {
    switch (surface) {
        .terminal => {
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
        },
    }
}

pub fn scrollPresentable(renderer: anytype, surface: PresentableSurface, dx: i32, dy: i32) bool {
    return switch (surface) {
        .terminal => blk: {
            const context = metal_backend.backendContext(renderer) orelse break :blk false;
            break :blk metal_backend.scrollTerminalSnapshotPresentable(context, dx, dy);
        },
    };
}

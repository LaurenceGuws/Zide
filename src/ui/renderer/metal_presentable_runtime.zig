const metal_backend = @import("metal_backend.zig");
const presentable_contract = @import("presentable_contract.zig");
const surface_draw = @import("surface_draw.zig");

const PresentableDraw = presentable_contract.PresentableDraw;
const PresentableInfo = presentable_contract.PresentableInfo;
const PresentableSurface = presentable_contract.PresentableSurface;

pub fn ensurePresentable(renderer: anytype, surface: PresentableSurface, width: i32, height: i32) bool {
    return switch (surface) {
        .terminal => blk: {
            _ = width;
            _ = height;
            const drawable_width = renderer.render_width;
            const drawable_height = renderer.render_height;
            if (drawable_width <= 0 or drawable_height <= 0) break :blk false;
            const context = metal_backend.backendContext(renderer) orelse break :blk false;
            break :blk metal_backend.ensureTerminalSnapshotPresentable(context, drawable_width, drawable_height).recreated;
        },
        .editor => false,
    };
}

pub fn beginPresentable(_: anytype, _: PresentableSurface) bool {
    return false;
}

pub fn presentableAvailable(renderer: anytype, surface: PresentableSurface) bool {
    return switch (surface) {
        .terminal => blk: {
            const context = metal_backend.backendContextConst(renderer) orelse break :blk false;
            break :blk metal_backend.terminalSnapshotMatchesDrawable(context);
        },
        .editor => false,
    };
}

pub fn endPresentable(_: anytype, _: PresentableSurface) void {}

pub fn presentableInfo(renderer: anytype, surface: PresentableSurface) ?PresentableInfo {
    if (surface != .terminal) return null;
    const context = metal_backend.backendContextConst(renderer) orelse return null;
    const snap = context.terminal_snapshot orelse return null;
    return .{
        .width_px = snap.width,
        .height_px = snap.height,
        .logical_width = renderer.width,
        .logical_height = renderer.height,
    };
}

pub fn drawPresentable(renderer: anytype, surface: PresentableSurface, draw: PresentableDraw) void {
    switch (surface) {
        .terminal => {
            const resolved = presentable_contract.resolveDraw(draw, null, null) orelse return;
            const context = metal_backend.backendContext(renderer) orelse return;
            const snapshot = context.terminal_snapshot orelse return;
            _ = metal_backend.recordSurfaceDrawToMetalQueue(renderer, .{ .raw_image = .{
                .texture = metal_backend.cloneGpuImageRef(snapshot),
                .source_rect = .{
                    .x = renderer.logicalLengthToRaster(draw.x),
                    .y = renderer.logicalLengthToRaster(draw.y),
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
        .editor => {},
    }
}

pub fn scrollPresentable(renderer: anytype, surface: PresentableSurface, dx: i32, dy: i32) bool {
    return switch (surface) {
        .terminal => blk: {
            const context = metal_backend.backendContext(renderer) orelse break :blk false;
            break :blk metal_backend.scrollTerminalSnapshotPresentable(context, dx, dy);
        },
        .editor => false,
    };
}

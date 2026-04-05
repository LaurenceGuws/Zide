const retained_targets_runtime = @import("../renderer/retained_targets_runtime.zig");
const scene_frame_runtime = @import("../renderer/scene_frame_runtime.zig");

pub const PresentableDraw = retained_targets_runtime.SurfaceDraw;

pub fn presentableAvailable(renderer: anytype) bool {
    if (renderer.backend == .metal) return renderer.metalTerminalSnapshotAvailable();
    return retained_targets_runtime.surfaceAvailable(renderer, .terminal);
}

pub fn ensurePresentable(renderer: anytype, width: i32, height: i32) bool {
    if (renderer.backend == .metal) {
        const drawable_width = renderer.render_width;
        const drawable_height = renderer.render_height;
        if (drawable_width <= 0 or drawable_height <= 0) return false;
        return renderer.ensureMetalTerminalSnapshotPresentable(drawable_width, drawable_height);
    }
    return retained_targets_runtime.ensureSurface(renderer, .terminal, width, height);
}

pub fn beginPresentable(renderer: anytype) bool {
    if (renderer.backend == .metal) return false;
    return retained_targets_runtime.beginSurface(renderer, .terminal);
}

pub fn endPresentable(renderer: anytype) void {
    scene_frame_runtime.restoreMainCompositionTarget(renderer);
}

pub fn drawPresentable(renderer: anytype, draw: PresentableDraw) void {
    if (renderer.backend == .metal) {
        const dest_width = draw.width orelse return;
        const dest_height = draw.height orelse return;
        const source_width = draw.source_width orelse dest_width;
        const source_height = draw.source_height orelse dest_height;
        scene_frame_runtime.noteTerminalPresentation(renderer, draw.generation);
        _ = renderer.drawMetalTerminalSnapshotPresentable(.{
            .texture = undefined,
            .source_rect = .{
                .x = renderer.logicalLengthToRaster(draw.x),
                .y = renderer.logicalLengthToRaster(draw.y),
                .width = renderer.logicalLengthToRaster(source_width),
                .height = renderer.logicalLengthToRaster(source_height),
            },
            .dest_rect = .{
                .x = renderer.logicalLengthToRaster(draw.x),
                .y = renderer.logicalLengthToRaster(draw.y),
                .width = renderer.logicalLengthToRaster(dest_width),
                .height = renderer.logicalLengthToRaster(dest_height),
            },
        });
        return;
    }
    retained_targets_runtime.drawSurface(renderer, .terminal, draw);
}

pub fn scrollPresentable(renderer: anytype, dx: i32, dy: i32) bool {
    if (renderer.backend == .metal) return renderer.scrollMetalTerminalSnapshotPresentable(dx, dy);
    return retained_targets_runtime.scrollSurface(renderer, .terminal, dx, dy);
}

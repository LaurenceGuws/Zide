const retained_targets_runtime = @import("../renderer/retained_targets_runtime.zig");
const scene_frame_runtime = @import("../renderer/scene_frame_runtime.zig");

pub const PresentableDraw = retained_targets_runtime.SurfaceDraw;

pub fn presentableAvailable(renderer: anytype) bool {
    if (renderer.backend == .metal) return renderer.metalTerminalSnapshotAvailable();
    return retained_targets_runtime.surfaceAvailable(renderer, .terminal);
}

pub fn ensurePresentable(renderer: anytype, width: i32, height: i32) bool {
    if (renderer.backend == .metal) return renderer.ensureMetalTerminalSnapshotPresentable(width, height);
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
        scene_frame_runtime.noteTerminalPresentation(renderer, draw.generation);
        _ = renderer.drawMetalTerminalSnapshotPresentable(.{
            .texture = undefined,
            .dest_rect = .{
                .x = draw.x,
                .y = draw.y,
                .width = draw.width orelse return,
                .height = draw.height orelse return,
            },
        });
        return;
    }
    retained_targets_runtime.drawSurface(renderer, .terminal, draw);
}

pub fn scrollPresentable(renderer: anytype, dx: i32, dy: i32) bool {
    if (renderer.backend == .metal) return false;
    return retained_targets_runtime.scrollSurface(renderer, .terminal, dx, dy);
}

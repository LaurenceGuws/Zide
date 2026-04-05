const gl = @import("gl.zig");
const scene_frame_runtime = @import("scene_frame_runtime.zig");

pub fn beginFrame(renderer: anytype) void {
    scene_frame_runtime.refreshSceneTargetContract(renderer, renderer.display_metrics);
    if (renderer.capabilities().scene_composition_mode == .offscreen_scene_target) {
        scene_frame_runtime.prepareSceneTarget(renderer, gl.c.GL_NEAREST);
    }
    renderer.present.main_composition_target = switch (renderer.sceneCompositionMode()) {
        .offscreen_scene_target => if (scene_frame_runtime.beginSceneFrame(renderer))
            .offscreen_scene_target
        else
            .default_target,
        .direct_main_target => .default_target,
    };
    if (renderer.present.main_composition_target == .default_target) renderer.bindDefaultTarget();
    gl.Disable(gl.c.GL_SCISSOR_TEST);

    const bg = renderer.theme.background.toRgba();
    gl.ClearColor(
        @as(f32, @floatFromInt(bg.r)) / 255.0,
        @as(f32, @floatFromInt(bg.g)) / 255.0,
        @as(f32, @floatFromInt(bg.b)) / 255.0,
        @as(f32, @floatFromInt(bg.a)) / 255.0,
    );
    gl.Clear(gl.c.GL_COLOR_BUFFER_BIT);
}

pub fn submitFrame(renderer: anytype) scene_frame_runtime.FrameSubmission {
    return scene_frame_runtime.submitOpenGlFrame(renderer);
}

//! Neutral presentable surface identity and draw payloads. OpenGL retained
//! `PresentableTarget` / `PresentableTargetState` live in `gl_presentable_target.zig`.

pub const PresentableSurface = enum {
    terminal,
};

pub const PresentableDraw = struct {
    x: f32,
    y: f32,
    width: ?f32 = null,
    height: ?f32 = null,
    source_width: ?f32 = null,
    source_height: ?f32 = null,
    generation: ?u64 = null,
};

pub const ResolvedPresentableDraw = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    source_width: f32,
    source_height: f32,
    generation: ?u64 = null,
};

pub fn resolveDraw(
    draw: PresentableDraw,
    fallback_width: ?f32,
    fallback_height: ?f32,
) ?ResolvedPresentableDraw {
    const width = draw.width orelse fallback_width orelse return null;
    const height = draw.height orelse fallback_height orelse return null;
    return .{
        .x = draw.x,
        .y = draw.y,
        .width = width,
        .height = height,
        .source_width = draw.source_width orelse width,
        .source_height = draw.source_height orelse height,
        .generation = draw.generation,
    };
}

pub const PresentableInfo = struct {
    width_px: i32,
    height_px: i32,
    logical_width: i32,
    logical_height: i32,
};

pub const PresentableSurface = enum {
    terminal,
    editor,
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

pub const PresentableInfo = struct {
    width_px: i32,
    height_px: i32,
    logical_width: i32,
    logical_height: i32,
};

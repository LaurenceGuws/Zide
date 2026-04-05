const terminal_font_mod = @import("../terminal_font.zig");

pub const TextPaintSource = enum {
    direct,
    shaped,
    special,
    fallback,
};

pub const ViewGeometrySample = struct {
    valid: bool = false,
    generation: u64 = 0,
    base_x: f32 = 0,
    base_y: f32 = 0,
    viewport_w: f32 = 0,
    viewport_h: f32 = 0,
    rows: usize = 0,
    cols: usize = 0,
    ui_scale: f32 = 1.0,
    render_scale: f32 = 1.0,
    cell_width_logical: f32 = 0,
    cell_height_logical: f32 = 0,
    cell_width_device: i32 = 0,
    cell_height_device: i32 = 0,
    baseline_logical: f32 = 0,
};

pub const CursorOverlaySample = struct {
    valid: bool = false,
    generation: u64 = 0,
    row: usize = 0,
    col: usize = 0,
    codepoint: u32 = 0,
    width_units: usize = 0,
    cell_x: f32 = 0,
    cell_y: f32 = 0,
    cell_w: f32 = 0,
    cell_h: f32 = 0,
    cursor_x: f32 = 0,
    cursor_y: f32 = 0,
    cursor_w: f32 = 0,
    cursor_h: f32 = 0,
    text_input_w: f32 = 0,
    edge_inset: f32 = 0,
    stroke: f32 = 0,
    render_scale: f32 = 1.0,
};

pub const TerminalPresentationSampleMode = enum {
    direct_main_target,
    direct_snapshot_update,
    direct_snapshot_presentable,
    retained_surface,
};

pub const TerminalPresentationSample = struct {
    valid: bool = false,
    mode: TerminalPresentationSampleMode = .retained_surface,
    generation: u64 = 0,
    presentable_w_px: i32 = 0,
    presentable_h_px: i32 = 0,
    target_logical_w: f32 = 0,
    target_logical_h: f32 = 0,
    source_logical_w: f32 = 0,
    source_logical_h: f32 = 0,
    dest_x: f32 = 0,
    dest_y: f32 = 0,
    dest_w: f32 = 0,
    dest_h: f32 = 0,
    scale_x: f32 = 1.0,
    scale_y: f32 = 1.0,
};

pub const TextPaintSample = struct {
    valid: bool = false,
    generation: u64 = 0,
    row: usize = 0,
    col: usize = 0,
    covers_cursor: bool = false,
    cursor_distance_cols: usize = 0,
    codepoint: u32 = 0,
    width_units: usize = 0,
    cell_x: f32 = 0,
    cell_y: f32 = 0,
    cell_w: f32 = 0,
    cell_h: f32 = 0,
    baseline: f32 = 0,
    render_scale: f32 = 1.0,
    glyph: terminal_font_mod.Rect = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
    source: TextPaintSource = .direct,
};

pub const MetalTerminalFallbackSample = struct {
    valid: bool = false,
    generation: u64 = 0,
    grid_row_runs: usize = 0,
    grid_row_cells: usize = 0,
    overlay_row_runs: usize = 0,
    overlay_row_cells: usize = 0,
};

pub const DebugCaptureState = struct {
    last_view_geometry: ViewGeometrySample = .{},
    last_cursor_overlay: CursorOverlaySample = .{},
    last_terminal_presentation: TerminalPresentationSample = .{},
    last_text_paint: TextPaintSample = .{},
    last_metal_terminal_fallback: MetalTerminalFallbackSample = .{},
};

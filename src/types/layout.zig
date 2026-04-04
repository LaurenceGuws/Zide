pub const Rect = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
};

pub const UiGeometryContext = struct {
    window: Rect,
    ui_scale: f32,
};

pub const TerminalViewGeometry = struct {
    viewport: Rect,
    origin_x: f32,
    origin_y: f32,
    viewport_width: f32,
    viewport_height: f32,
    rows: usize,
    cols: usize,
    cell_width: f32,
    cell_height: f32,
    baseline_from_top: f32,
};

pub const WidgetLayout = struct {
    window: Rect,
    top_bar: Rect,
    tab_bar: Rect,
    side_nav: Rect,
    editor: Rect,
    terminal: Rect,
    status_bar: Rect,
};

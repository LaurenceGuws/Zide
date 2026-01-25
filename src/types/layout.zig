pub const Rect = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
};

pub const WidgetLayout = struct {
    window: Rect,
    options_bar: Rect,
    tab_bar: Rect,
    side_nav: Rect,
    editor: Rect,
    terminal: Rect,
    status_bar: Rect,
};

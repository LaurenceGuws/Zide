const std = @import("std");

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

pub const TerminalGridFit = struct {
    cols: usize,
    rows: usize,
    width: f32,
    height: f32,
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

pub fn fitTerminalGrid(
    terminal_width: f32,
    terminal_height: f32,
    cell_geometry: anytype,
    min_cols: usize,
    min_rows: usize,
    max_cols: ?usize,
    max_rows: ?usize,
) TerminalGridFit {
    const cell_w = if (cell_geometry.cell_width_logical_exact > 0.0)
        cell_geometry.cell_width_logical_exact
    else
        1.0;
    const cell_h = if (cell_geometry.cell_height_logical_exact > 0.0)
        cell_geometry.cell_height_logical_exact
    else
        1.0;
    const available_cols = @as(usize, @intFromFloat(std.math.floor(@max(0.0, terminal_width) / cell_w)));
    const available_rows = @as(usize, @intFromFloat(std.math.floor(@max(0.0, terminal_height) / cell_h)));
    var cols = @max(min_cols, available_cols);
    var rows = @max(min_rows, available_rows);
    if (max_cols) |limit| cols = @min(cols, limit);
    if (max_rows) |limit| rows = @min(rows, limit);
    return .{
        .cols = cols,
        .rows = rows,
        .width = @as(f32, @floatFromInt(@as(i32, @intCast(cols)))) * cell_w,
        .height = @as(f32, @floatFromInt(@as(i32, @intCast(rows)))) * cell_h,
    };
}

test "fitTerminalGrid derives rows and cols from snapped logical cell geometry" {
    const fit = fitTerminalGrid(
        1000.0,
        500.0,
        .{
            .cell_width_logical_exact = 8.125,
            .cell_height_logical_exact = 20.625,
        },
        1,
        1,
        null,
        null,
    );

    try std.testing.expectEqual(@as(usize, 123), fit.cols);
    try std.testing.expectEqual(@as(usize, 24), fit.rows);
    try std.testing.expectApproxEqAbs(@as(f32, 999.375), fit.width, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 495.0), fit.height, 0.0001);
}

test "fitTerminalGrid clamps visible geometry to current terminal rows and cols" {
    const fit = fitTerminalGrid(
        1000.0,
        500.0,
        .{
            .cell_width_logical_exact = 8.125,
            .cell_height_logical_exact = 20.625,
        },
        0,
        0,
        80,
        20,
    );

    try std.testing.expectEqual(@as(usize, 80), fit.cols);
    try std.testing.expectEqual(@as(usize, 20), fit.rows);
    try std.testing.expectApproxEqAbs(@as(f32, 650.0), fit.width, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 412.5), fit.height, 0.0001);
}

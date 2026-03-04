const std = @import("std");

pub fn compute(
    terminal_width: f32,
    terminal_height: f32,
    terminal_cell_width: f32,
    terminal_cell_height: f32,
    min_cols: u16,
    min_rows: u16,
) struct { cols: u16, rows: u16 } {
    const cell_w = @as(f32, @floatFromInt(@max(1, @as(i32, @intFromFloat(std.math.round(terminal_cell_width))))));
    const cell_h = @as(f32, @floatFromInt(@max(1, @as(i32, @intFromFloat(std.math.round(terminal_cell_height))))));
    const cols_f = std.math.floor(@max(0.0, terminal_width) / cell_w);
    const rows_f = std.math.floor(@max(0.0, terminal_height) / cell_h);
    const cols_u: u16 = @intFromFloat(@max(@as(f32, @floatFromInt(min_cols)), cols_f));
    const rows_u: u16 = @intFromFloat(@max(@as(f32, @floatFromInt(min_rows)), rows_f));
    return .{ .cols = cols_u, .rows = rows_u };
}

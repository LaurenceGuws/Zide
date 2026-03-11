const std = @import("std");

pub const Override = struct {
    cols: u16,
    rows: u16,
};

pub const Grid = struct {
    cols: u16,
    rows: u16,
};

pub fn compute(
    terminal_width: f32,
    terminal_height: f32,
    terminal_cell_width: f32,
    terminal_cell_height: f32,
    min_cols: u16,
    min_rows: u16,
) Grid {
    const cell_w = @as(f32, @floatFromInt(@max(1, @as(i32, @intFromFloat(std.math.round(terminal_cell_width))))));
    const cell_h = @as(f32, @floatFromInt(@max(1, @as(i32, @intFromFloat(std.math.round(terminal_cell_height))))));
    const cols_f = std.math.floor(@max(0.0, terminal_width) / cell_w);
    const rows_f = std.math.floor(@max(0.0, terminal_height) / cell_h);
    const cols_u: u16 = @intFromFloat(@max(@as(f32, @floatFromInt(min_cols)), cols_f));
    const rows_u: u16 = @intFromFloat(@max(@as(f32, @floatFromInt(min_rows)), rows_f));
    return .{ .cols = cols_u, .rows = rows_u };
}

pub fn overrideFromEnv() ?Override {
    const rows = parseEnvDimension("ZIDE_TERMINAL_ROWS") orelse return null;
    const cols = parseEnvDimension("ZIDE_TERMINAL_COLS") orelse return null;
    return .{ .cols = cols, .rows = rows };
}

pub fn computeWithEnvOverride(
    terminal_width: f32,
    terminal_height: f32,
    terminal_cell_width: f32,
    terminal_cell_height: f32,
    min_cols: u16,
    min_rows: u16,
) Grid {
    if (overrideFromEnv()) |override| return .{ .cols = override.cols, .rows = override.rows };
    return compute(terminal_width, terminal_height, terminal_cell_width, terminal_cell_height, min_cols, min_rows);
}

fn parseEnvDimension(name: [:0]const u8) ?u16 {
    const value = std.c.getenv(name) orelse return null;
    const slice = std.mem.sliceTo(value, 0);
    return std.fmt.parseUnsigned(u16, slice, 10) catch null;
}

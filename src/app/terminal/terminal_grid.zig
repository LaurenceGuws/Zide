const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const shared_types = @import("../../types/mod.zig");

const TerminalCellGeometry = app_shell.TerminalCellGeometry;
const terminal_layout = shared_types.layout;

pub const Override = struct {
    cols: u16,
    rows: u16,
};

pub const Grid = struct {
    cols: u16,
    rows: u16,
    cell_width: u16,
    cell_height: u16,
};

pub fn compute(
    terminal_width: f32,
    terminal_height: f32,
    cell_geometry: TerminalCellGeometry,
    min_cols: u16,
    min_rows: u16,
) Grid {
    const fit = terminal_layout.fitTerminalGrid(
        terminal_width,
        terminal_height,
        cell_geometry,
        min_cols,
        min_rows,
        null,
        null,
    );
    return .{
        .cols = @intCast(@min(fit.cols, @as(usize, std.math.maxInt(u16)))),
        .rows = @intCast(@min(fit.rows, @as(usize, std.math.maxInt(u16)))),
        .cell_width = clampDeviceCellDimension(cell_geometry.cell_width_device_px),
        .cell_height = clampDeviceCellDimension(cell_geometry.cell_height_device_px),
    };
}

pub fn overrideFromEnv() ?Override {
    const rows = parseEnvDimension("ZIDE_TERMINAL_ROWS") orelse return null;
    const cols = parseEnvDimension("ZIDE_TERMINAL_COLS") orelse return null;
    return .{ .cols = cols, .rows = rows };
}

pub fn computeWithEnvOverride(
    terminal_width: f32,
    terminal_height: f32,
    cell_geometry: TerminalCellGeometry,
    min_cols: u16,
    min_rows: u16,
) Grid {
    if (overrideFromEnv()) |override| {
        return .{
            .cols = override.cols,
            .rows = override.rows,
            .cell_width = clampDeviceCellDimension(cell_geometry.cell_width_device_px),
            .cell_height = clampDeviceCellDimension(cell_geometry.cell_height_device_px),
        };
    }
    return compute(terminal_width, terminal_height, cell_geometry, min_cols, min_rows);
}

fn clampDeviceCellDimension(value: i32) u16 {
    const positive = @max(1, value);
    const clamped = @min(positive, @as(i32, std.math.maxInt(u16)));
    return @intCast(clamped);
}

test "compute uses exact snapped logical cell geometry instead of rounded logical metrics" {
    const grid = compute(
        1000.0,
        500.0,
        .{
            .cell_width_logical_exact = 8.125,
            .cell_height_logical_exact = 20.625,
            .baseline_logical_exact = 16.25,
            .cell_width_device_px = 13,
            .cell_height_device_px = 33,
            .baseline_device_px = 26,
        },
        1,
        1,
    );

    try std.testing.expectEqual(@as(u16, 123), grid.cols);
    try std.testing.expectEqual(@as(u16, 24), grid.rows);
    try std.testing.expectEqual(@as(u16, 13), grid.cell_width);
    try std.testing.expectEqual(@as(u16, 33), grid.cell_height);
}

fn parseEnvDimension(name: [:0]const u8) ?u16 {
    const value = std.c.getenv(name) orelse return null;
    const slice = std.mem.sliceTo(value, 0);
    return std.fmt.parseUnsigned(u16, slice, 10) catch null;
}

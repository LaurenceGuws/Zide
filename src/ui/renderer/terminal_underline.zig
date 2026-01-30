const iface = @import("interface.zig");

const Color = iface.Color;

pub fn underlineY(base_y: i32, cell_h: i32) i32 {
    return base_y + cell_h - 2;
}

pub fn drawUnderline(
    drawRect: *const fn (ctx: *anyopaque, x: i32, y: i32, w: i32, h: i32, color: Color) void,
    ctx: *anyopaque,
    x: i32,
    base_y: i32,
    cell_w: i32,
    cell_h: i32,
    color: Color,
) void {
    const y = underlineY(base_y, cell_h);
    drawRect(ctx, x, y, cell_w, 2, color);
}

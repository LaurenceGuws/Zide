const iface = @import("interface.zig");

const Color = iface.Color;

pub fn drawRectOutline(
    drawRect: *const fn (ctx: *anyopaque, x: i32, y: i32, w: i32, h: i32, color: Color) void,
    ctx: *anyopaque,
    x: i32,
    y: i32,
    w: i32,
    h: i32,
    color: Color,
) void {
    const thick: i32 = 1;
    drawRect(ctx, x, y, w, thick, color);
    drawRect(ctx, x, y + h - thick, w, thick, color);
    drawRect(ctx, x, y, thick, h, color);
    drawRect(ctx, x + w - thick, y, thick, h, color);
}

pub fn drawLine(
    drawRect: *const fn (ctx: *anyopaque, x: i32, y: i32, w: i32, h: i32, color: Color) void,
    ctx: *anyopaque,
    x1: i32,
    y1: i32,
    x2: i32,
    y2: i32,
    color: Color,
) void {
    if (x1 == x2) {
        const top = @min(y1, y2);
        const h = @abs(y2 - y1) + 1;
        drawRect(ctx, x1, top, 1, h, color);
        return;
    }
    if (y1 == y2) {
        const left = @min(x1, x2);
        const w = @abs(x2 - x1) + 1;
        drawRect(ctx, left, y1, w, 1, color);
        return;
    }
    // Fallback: draw bounding rect for diagonal lines.
    const left = @min(x1, x2);
    const top = @min(y1, y2);
    const w = @abs(x2 - x1) + 1;
    const h = @abs(y2 - y1) + 1;
    drawRect(ctx, left, top, w, h, color);
}

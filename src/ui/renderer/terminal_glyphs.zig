const iface = @import("interface.zig");

const Color = iface.Color;

pub fn drawBoxGlyph(
    drawRect: *const fn (ctx: *anyopaque, x: i32, y: i32, w: i32, h: i32, color: Color) void,
    ctx: *anyopaque,
    codepoint: u32,
    x: f32,
    y: f32,
    w: f32,
    h: f32,
    color: Color,
) bool {
    const ix = @as(i32, @intFromFloat(x));
    const iy = @as(i32, @intFromFloat(y));
    const iw = @as(i32, @intFromFloat(w));
    const ih = @as(i32, @intFromFloat(h));
    const mid_x = ix + @divTrunc(iw, 2);
    const mid_y = iy + @divTrunc(ih, 2);
    const thin: i32 = 1;
    const thick: i32 = @max(2, @divTrunc(ih, 6));
    const extend: i32 = 0;

    switch (codepoint) {
        0x2500 => { // ─
            drawRect(ctx, ix, mid_y, iw, thin, color);
            return true;
        },
        0x2501 => { // ━
            drawRect(ctx, ix, mid_y - @divTrunc(thick, 2), iw, thick, color);
            return true;
        },
        0x2502 => { // │
            drawRect(ctx, mid_x, iy - extend, thin, ih + extend * 2, color);
            return true;
        },
        0x2503 => { // ┃
            drawRect(ctx, mid_x - @divTrunc(thick, 2), iy - extend, thick, ih + extend * 2, color);
            return true;
        },
        0x256d => { // ╭
            drawRect(ctx, mid_x, mid_y, iw - (mid_x - ix), thin, color);
            drawRect(ctx, mid_x, mid_y, thin, ih - (mid_y - iy) + extend, color);
            return true;
        },
        0x256e => { // ╮
            drawRect(ctx, ix, mid_y, mid_x - ix + thin, thin, color);
            drawRect(ctx, mid_x, mid_y, thin, ih - (mid_y - iy) + extend, color);
            return true;
        },
        0x256f => { // ╯
            drawRect(ctx, ix, mid_y, mid_x - ix + thin, thin, color);
            drawRect(ctx, mid_x, iy - extend, thin, mid_y - iy + thin + extend, color);
            return true;
        },
        0x2570 => { // ╰
            drawRect(ctx, mid_x, mid_y, iw - (mid_x - ix), thin, color);
            drawRect(ctx, mid_x, iy - extend, thin, mid_y - iy + thin + extend, color);
            return true;
        },
        0x250c => { // ┌
            drawRect(ctx, mid_x, mid_y, iw - (mid_x - ix), thin, color);
            drawRect(ctx, mid_x, mid_y, thin, ih - (mid_y - iy) + extend, color);
            return true;
        },
        0x2510 => { // ┐
            drawRect(ctx, ix, mid_y, mid_x - ix + thin, thin, color);
            drawRect(ctx, mid_x, mid_y, thin, ih - (mid_y - iy) + extend, color);
            return true;
        },
        0x2514 => { // └
            drawRect(ctx, mid_x, mid_y, iw - (mid_x - ix), thin, color);
            drawRect(ctx, mid_x, iy - extend, thin, mid_y - iy + thin + extend, color);
            return true;
        },
        0x2518 => { // ┘
            drawRect(ctx, ix, mid_y, mid_x - ix + thin, thin, color);
            drawRect(ctx, mid_x, iy - extend, thin, mid_y - iy + thin + extend, color);
            return true;
        },
        0x2574 => { // ╴
            drawRect(ctx, ix, mid_y, mid_x - ix + thin, thin, color);
            return true;
        },
        0x2575 => { // ╵
            drawRect(ctx, mid_x, iy - extend, thin, mid_y - iy + thin + extend, color);
            return true;
        },
        0x2576 => { // ╶
            drawRect(ctx, mid_x, mid_y, iw - (mid_x - ix), thin, color);
            return true;
        },
        0x2577 => { // ╷
            drawRect(ctx, mid_x, mid_y, thin, ih - (mid_y - iy) + extend, color);
            return true;
        },
        0x251c => { // ├
            drawRect(ctx, mid_x, iy - extend, thin, ih + extend * 2, color);
            drawRect(ctx, mid_x, mid_y, iw - (mid_x - ix), thin, color);
            return true;
        },
        0x2524 => { // ┤
            drawRect(ctx, mid_x, iy - extend, thin, ih + extend * 2, color);
            drawRect(ctx, ix, mid_y, mid_x - ix + thin, thin, color);
            return true;
        },
        0x252c => { // ┬
            drawRect(ctx, ix, mid_y, iw, thin, color);
            drawRect(ctx, mid_x, mid_y, thin, ih - (mid_y - iy) + extend, color);
            return true;
        },
        0x2534 => { // ┴
            drawRect(ctx, ix, mid_y, iw, thin, color);
            drawRect(ctx, mid_x, iy - extend, thin, mid_y - iy + thin + extend, color);
            return true;
        },
        0x253c => { // ┼
            drawRect(ctx, ix, mid_y, iw, thin, color);
            drawRect(ctx, mid_x, iy - extend, thin, ih + extend * 2, color);
            return true;
        },
        0x2580 => { // ▀
            drawRect(ctx, ix, iy, iw, @divTrunc(ih, 2), color);
            return true;
        },
        0x2584 => { // ▄
            const half = @divTrunc(ih, 2);
            drawRect(ctx, ix, iy + half, iw, ih - half, color);
            return true;
        },
        0x2588 => { // █
            drawRect(ctx, ix, iy, iw, ih, color);
            return true;
        },
        else => return false,
    }
}

pub fn drawBoxGlyphBatched(
    addRect: *const fn (ctx: *anyopaque, x: i32, y: i32, w: i32, h: i32, color: Color) void,
    ctx: *anyopaque,
    codepoint: u32,
    x: f32,
    y: f32,
    w: f32,
    h: f32,
    color: Color,
) bool {
    return drawBoxGlyph(addRect, ctx, codepoint, x, y, w, h, color);
}

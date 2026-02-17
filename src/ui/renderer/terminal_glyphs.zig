const iface = @import("interface.zig");

const Color = iface.Color;

const PowerlineMode = enum {
    filled_right, // 
    thin_right, // 
    filled_left, // 
    thin_left, // 
};

fn edge(ax: f32, ay: f32, bx: f32, by: f32, px: f32, py: f32) f32 {
    return (px - ax) * (by - ay) - (py - ay) * (bx - ax);
}

fn insideTriangle(
    px: f32,
    py: f32,
    ax: f32,
    ay: f32,
    bx: f32,
    by: f32,
    cx: f32,
    cy: f32,
) bool {
    const e0 = edge(ax, ay, bx, by, px, py);
    const e1 = edge(bx, by, cx, cy, px, py);
    const e2 = edge(cx, cy, ax, ay, px, py);
    return (e0 >= 0.0 and e1 >= 0.0 and e2 >= 0.0) or
        (e0 <= 0.0 and e1 <= 0.0 and e2 <= 0.0);
}

fn distToSegmentSquared(px: f32, py: f32, ax: f32, ay: f32, bx: f32, by: f32) f32 {
    const vx = bx - ax;
    const vy = by - ay;
    const wx = px - ax;
    const wy = py - ay;
    const vv = vx * vx + vy * vy;
    if (vv <= 0.0001) {
        const dx = px - ax;
        const dy = py - ay;
        return dx * dx + dy * dy;
    }
    var t = (wx * vx + wy * vy) / vv;
    if (t < 0.0) t = 0.0;
    if (t > 1.0) t = 1.0;
    const qx = ax + t * vx;
    const qy = ay + t * vy;
    const dx = px - qx;
    const dy = py - qy;
    return dx * dx + dy * dy;
}

fn powerlineInside(mode: PowerlineMode, iw: f32, ih: f32, x: f32, y: f32) bool {
    const mid_y = ih * 0.5;
    return switch (mode) {
        .filled_right => insideTriangle(x, y, 0.0, 0.0, iw, mid_y, 0.0, ih),
        .filled_left => insideTriangle(x, y, iw, 0.0, 0.0, mid_y, iw, ih),
        .thin_right => blk: {
            const stroke = @max(1.0, ih * 0.08);
            const r2 = (stroke * 0.5) * (stroke * 0.5);
            const d0 = distToSegmentSquared(x, y, 0.0, 0.0, iw, mid_y);
            const d1 = distToSegmentSquared(x, y, 0.0, ih, iw, mid_y);
            break :blk d0 <= r2 or d1 <= r2;
        },
        .thin_left => blk: {
            const stroke = @max(1.0, ih * 0.08);
            const r2 = (stroke * 0.5) * (stroke * 0.5);
            const d0 = distToSegmentSquared(x, y, iw, 0.0, 0.0, mid_y);
            const d1 = distToSegmentSquared(x, y, iw, ih, 0.0, mid_y);
            break :blk d0 <= r2 or d1 <= r2;
        },
    };
}

fn drawPowerlineGlyphAA(
    drawRect: *const fn (ctx: *anyopaque, x: i32, y: i32, w: i32, h: i32, color: Color) void,
    ctx: *anyopaque,
    mode: PowerlineMode,
    ix: i32,
    iy: i32,
    iw: i32,
    ih: i32,
    color: Color,
) void {
    const ss: i32 = 6;
    const samples = ss * ss;
    const fw = @as(f32, @floatFromInt(iw));
    const fh = @as(f32, @floatFromInt(ih));
    var py: i32 = 0;
    while (py < ih) : (py += 1) {
        var px: i32 = 0;
        while (px < iw) : (px += 1) {
            var hit: i32 = 0;
            var sy: i32 = 0;
            while (sy < ss) : (sy += 1) {
                var sx: i32 = 0;
                while (sx < ss) : (sx += 1) {
                    const sample_x = @as(f32, @floatFromInt(px)) + (@as(f32, @floatFromInt(sx)) + 0.5) / @as(f32, @floatFromInt(ss));
                    const sample_y = @as(f32, @floatFromInt(py)) + (@as(f32, @floatFromInt(sy)) + 0.5) / @as(f32, @floatFromInt(ss));
                    if (powerlineInside(mode, fw, fh, sample_x, sample_y)) hit += 1;
                }
            }
            if (hit == 0) continue;
            var c = color;
            c.a = @intCast(@divTrunc(@as(i32, color.a) * hit + @divTrunc(samples, 2), samples));
            drawRect(ctx, ix + px, iy + py, 1, 1, c);
        }
    }
}

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
    // Use edge-based quantization so adjacent fractional cells share boundaries
    // without seam gaps (common under fractional DPI/zoom).
    const left = @as(i32, @intFromFloat(@floor(x)));
    const top = @as(i32, @intFromFloat(@floor(y)));
    const right = @as(i32, @intFromFloat(@ceil(x + w)));
    const bottom = @as(i32, @intFromFloat(@ceil(y + h)));
    const ix = left;
    const iy = top;
    const iw = @max(1, right - left);
    const ih = @max(1, bottom - top);
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
        0xE0B0 => { // 
            drawPowerlineGlyphAA(drawRect, ctx, .filled_right, ix, iy, iw, ih, color);
            return true;
        },
        0xE0B1 => { // 
            drawPowerlineGlyphAA(drawRect, ctx, .thin_right, ix, iy, iw, ih, color);
            return true;
        },
        0xE0B2 => { // 
            drawPowerlineGlyphAA(drawRect, ctx, .filled_left, ix, iy, iw, ih, color);
            return true;
        },
        0xE0B3 => { // 
            drawPowerlineGlyphAA(drawRect, ctx, .thin_left, ix, iy, iw, ih, color);
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

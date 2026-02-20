const std = @import("std");
const iface = @import("interface.zig");
const types = @import("types.zig");

const Color = iface.Color;

const PowerlineMode = enum {
    filled_right, // 
    thin_right, // 
    filled_left, // 
    thin_left, // 
};

fn powerlineModeForCodepoint(codepoint: u32) ?PowerlineMode {
    return switch (codepoint) {
        0xE0B0 => .filled_right,
        0xE0B1 => .thin_right,
        0xE0B2 => .filled_left,
        0xE0B3 => .thin_left,
        else => null,
    };
}

pub fn specialVariantForCodepoint(codepoint: u32) ?types.SpecialGlyphVariant {
    if (codepoint == 0xE0B0 or codepoint == 0xE0B1 or codepoint == 0xE0B2 or codepoint == 0xE0B3) {
        return .powerline;
    }
    if (codepoint == 0x2591 or codepoint == 0x2592 or codepoint == 0x2593) {
        return .shade;
    }
    if (codepoint >= 0x2500 and codepoint <= 0x259F) {
        return .box;
    }
    if (codepoint >= 0x2800 and codepoint <= 0x28FF) {
        return .braille;
    }
    if (codepoint >= 0xF5D0 and codepoint <= 0xF60D) {
        return .branch;
    }
    if ((codepoint >= 0x1CD00 and codepoint <= 0x1CDE5) or
        (codepoint >= 0x1FB00 and codepoint <= 0x1FBAF) or
        codepoint == 0x1FBE6 or
        codepoint == 0x1FBE7)
    {
        return .legacy;
    }
    return null;
}

pub fn rasterizeSpecialGlyphCoverage(
    codepoint: u32,
    width: i32,
    height: i32,
    out_alpha: []u8,
) bool {
    if (powerlineModeForCodepoint(codepoint)) |mode| {
        return rasterizePowerlineMask(mode, width, height, out_alpha);
    }
    if (width <= 0 or height <= 0) return false;
    const expected_len: usize = @intCast(width * height);
    if (out_alpha.len < expected_len) return false;
    @memset(out_alpha[0..expected_len], 0);

    const Ctx = struct {
        width: i32,
        height: i32,
        alpha: []u8,
    };
    var ctx = Ctx{
        .width = width,
        .height = height,
        .alpha = out_alpha[0..expected_len],
    };

    const drawToCoverage = struct {
        fn call(raw_ctx: *anyopaque, x: i32, y: i32, w: i32, h: i32, color: Color) void {
            const cctx: *Ctx = @ptrCast(@alignCast(raw_ctx));
            if (w <= 0 or h <= 0) return;
            const x0 = @max(0, x);
            const y0 = @max(0, y);
            const x1 = @min(cctx.width, x + w);
            const y1 = @min(cctx.height, y + h);
            if (x1 <= x0 or y1 <= y0) return;
            var py = y0;
            while (py < y1) : (py += 1) {
                var px = x0;
                while (px < x1) : (px += 1) {
                    const idx: usize = @intCast(py * cctx.width + px);
                    if (color.a > cctx.alpha[idx]) cctx.alpha[idx] = color.a;
                }
            }
        }
    }.call;

    return drawBoxGlyph(
        drawToCoverage,
        &ctx,
        codepoint,
        0.0,
        0.0,
        @floatFromInt(width),
        @floatFromInt(height),
        Color{ .r = 255, .g = 255, .b = 255, .a = 255 },
    );
}

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

fn distToStrokeExtended(
    x: f32,
    y: f32,
    ax: f32,
    ay: f32,
    bx: f32,
    by: f32,
    extend: f32,
) f32 {
    const vx = bx - ax;
    const vy = by - ay;
    const v2 = vx * vx + vy * vy;
    if (v2 <= 0.0001) return 1_000_000.0;

    const vlen = std.math.sqrt(v2);
    const ux = vx / vlen;
    const uy = vy / vlen;

    // Square-cap style stroke extension.
    const sx = ax - ux * extend;
    const sy = ay - uy * extend;
    const ex = bx + ux * extend;
    const ey = by + uy * extend;

    return std.math.sqrt(distToSegmentSquared(x, y, sx, sy, ex, ey));
}

fn clamp01(v: f32) f32 {
    if (v <= 0.0) return 0.0;
    if (v >= 1.0) return 1.0;
    return v;
}

fn triangleCoverage(
    px: f32,
    py: f32,
    ax: f32,
    ay: f32,
    bx: f32,
    by: f32,
    cx: f32,
    cy: f32,
) f32 {
    const inside = insideTriangle(px, py, ax, ay, bx, by, cx, cy);
    const d0 = std.math.sqrt(distToSegmentSquared(px, py, ax, ay, bx, by));
    const d1 = std.math.sqrt(distToSegmentSquared(px, py, bx, by, cx, cy));
    const d2 = std.math.sqrt(distToSegmentSquared(px, py, cx, cy, ax, ay));
    const d = @min(d0, @min(d1, d2));
    return if (inside) clamp01(0.5 + d) else clamp01(0.5 - d);
}

fn powerlineCoverage(mode: PowerlineMode, iw: f32, ih: f32, x: f32, y: f32) f32 {
    const mid_y = ih * 0.5;
    return switch (mode) {
        .filled_right => triangleCoverage(x, y, 0.0, 0.0, iw, mid_y, 0.0, ih),
        .filled_left => triangleCoverage(x, y, iw, 0.0, 0.0, mid_y, iw, ih),
        .thin_right => blk: {
            const stroke = @max(1.0, @round(ih / 16.0));
            const half_w = stroke * 0.5;
            const d0 = distToStrokeExtended(x, y, 0.0, 0.0, iw, mid_y, half_w);
            const d1 = distToStrokeExtended(x, y, 0.0, ih, iw, mid_y, half_w);
            const c0 = clamp01(half_w + 0.5 - d0);
            const c1 = clamp01(half_w + 0.5 - d1);
            break :blk @max(c0, c1);
        },
        .thin_left => blk: {
            const stroke = @max(1.0, @round(ih / 16.0));
            const half_w = stroke * 0.5;
            const d0 = distToStrokeExtended(x, y, iw, 0.0, 0.0, mid_y, half_w);
            const d1 = distToStrokeExtended(x, y, iw, ih, 0.0, mid_y, half_w);
            const c0 = clamp01(half_w + 0.5 - d0);
            const c1 = clamp01(half_w + 0.5 - d1);
            break :blk @max(c0, c1);
        },
    };
}

fn powerlineCoverageHard(mode: PowerlineMode, iw: f32, ih: f32, x: f32, y: f32) u8 {
    const mid_y = ih * 0.5;
    return switch (mode) {
        .filled_right => blk: {
            const ext = 0.25;
            break :blk if (insideTriangle(x, y, -ext, 0.0, iw + ext, mid_y, -ext, ih)) 255 else 0;
        },
        .filled_left => blk: {
            const ext = 0.25;
            break :blk if (insideTriangle(x, y, iw + ext, 0.0, -ext, mid_y, iw + ext, ih)) 255 else 0;
        },
        .thin_right => blk: {
            const stroke = @max(1.0, @round(ih / 16.0));
            const half_w = stroke * 0.5;
            const d0 = distToStrokeExtended(x, y, 0.0, 0.0, iw, mid_y, half_w);
            const d1 = distToStrokeExtended(x, y, 0.0, ih, iw, mid_y, half_w);
            break :blk if (d0 <= half_w or d1 <= half_w) 255 else 0;
        },
        .thin_left => blk: {
            const stroke = @max(1.0, @round(ih / 16.0));
            const half_w = stroke * 0.5;
            const d0 = distToStrokeExtended(x, y, iw, 0.0, 0.0, mid_y, half_w);
            const d1 = distToStrokeExtended(x, y, iw, ih, 0.0, mid_y, half_w);
            break :blk if (d0 <= half_w or d1 <= half_w) 255 else 0;
        },
    };
}

fn rasterizePowerlineMask(mode: PowerlineMode, width: i32, height: i32, out_alpha: []u8) bool {
    if (width <= 0 or height <= 0) return false;
    const out_len: usize = @intCast(width * height);
    if (out_alpha.len < out_len) return false;

    const ss: i32 = 8;
    const hi_w = width * ss;
    const hi_h = height * ss;
    const hi_len: usize = @intCast(hi_w * hi_h);
    var hi = std.heap.page_allocator.alloc(u8, hi_len) catch return false;
    defer std.heap.page_allocator.free(hi);
    @memset(hi, 0);

    const fw = @as(f32, @floatFromInt(hi_w));
    const fh = @as(f32, @floatFromInt(hi_h));
    var py: i32 = 0;
    while (py < hi_h) : (py += 1) {
        var px: i32 = 0;
        while (px < hi_w) : (px += 1) {
            const x = @as(f32, @floatFromInt(px)) + 0.5;
            const y = @as(f32, @floatFromInt(py)) + 0.5;
            const hi_idx: usize = @intCast(py * hi_w + px);
            hi[hi_idx] = powerlineCoverageHard(mode, fw, fh, x, y);
        }
    }

    const ss_area: u32 = @intCast(ss * ss);
    py = 0;
    while (py < height) : (py += 1) {
        var px: i32 = 0;
        while (px < width) : (px += 1) {
            var sum: u32 = 0;
            var sy: i32 = 0;
            while (sy < ss) : (sy += 1) {
                var sx: i32 = 0;
                while (sx < ss) : (sx += 1) {
                    const hix = px * ss + sx;
                    const hiy = py * ss + sy;
                    const hi_idx: usize = @intCast(hiy * hi_w + hix);
                    sum += hi[hi_idx];
                }
            }
            const out_idx: usize = @intCast(py * width + px);
            const avg: u8 = @intCast(@divTrunc(sum + ss_area / 2, ss_area));
            out_alpha[out_idx] = avg;
        }
    }

    return true;
}

fn drawPowerlineGlyphAnalytic(
    drawRect: *const fn (ctx: *anyopaque, x: i32, y: i32, w: i32, h: i32, color: Color) void,
    ctx: *anyopaque,
    mode: PowerlineMode,
    ix: i32,
    iy: i32,
    iw: i32,
    ih: i32,
    color: Color,
) void {
    const len: usize = @intCast(iw * ih);
    const mask = std.heap.page_allocator.alloc(u8, len) catch return;
    defer std.heap.page_allocator.free(mask);
    if (!rasterizePowerlineMask(mode, iw, ih, mask)) return;
    var py: i32 = 0;
    while (py < ih) : (py += 1) {
        var px: i32 = 0;
        while (px < iw) : (px += 1) {
            const idx: usize = @intCast(py * iw + px);
            if (mask[idx] == 0) continue;
            var c = color;
            c.a = @intCast(@divTrunc(@as(i32, color.a) * mask[idx] + 127, 255));
            if (c.a == 0) continue;
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
            drawPowerlineGlyphAnalytic(drawRect, ctx, .filled_right, ix, iy, iw, ih, color);
            return true;
        },
        0xE0B1 => { // 
            drawPowerlineGlyphAnalytic(drawRect, ctx, .thin_right, ix, iy, iw, ih, color);
            return true;
        },
        0xE0B2 => { // 
            drawPowerlineGlyphAnalytic(drawRect, ctx, .filled_left, ix, iy, iw, ih, color);
            return true;
        },
        0xE0B3 => { // 
            drawPowerlineGlyphAnalytic(drawRect, ctx, .thin_left, ix, iy, iw, ih, color);
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

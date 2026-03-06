const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const iface = @import("interface.zig");
const types = @import("types.zig");

const Color = iface.Color;

const PowerlineMode = enum {
    filled_right, // 
    thin_right, // 
    filled_left, // 
    thin_left, // 
    filled_right_round, // 
    thin_right_round, // 
    filled_left_round, // 
    thin_left_round, // 
};

const DownsampleKernel = enum {
    box,
    tent,
};

const PowerlineRasterParams = struct {
    supersample: i32,
    thin_stroke_logical: f32,
    seam_extension: f32,
    downsample_kernel: DownsampleKernel,
};

fn powerlineModeForCodepoint(codepoint: u32) ?PowerlineMode {
    return switch (codepoint) {
        0xE0B0 => .filled_right,
        0xE0B1 => .thin_right,
        0xE0B2 => .filled_left,
        0xE0B3 => .thin_left,
        0xE0B4 => .filled_right_round,
        0xE0B5 => .thin_right_round,
        0xE0B6 => .filled_left_round,
        0xE0B7 => .thin_left_round,
        else => null,
    };
}

pub fn specialVariantForCodepoint(codepoint: u32) ?types.SpecialGlyphVariant {
    if (codepoint == 0xE0B1 or codepoint == 0xE0B3 or
        codepoint == 0xE0B4 or codepoint == 0xE0B5 or
        codepoint == 0xE0B6 or codepoint == 0xE0B7)
    {
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

fn quantizeStep(value: f32, step: f32) f32 {
    if (step <= 0.0) return value;
    return std.math.round(value / step) * step;
}

fn choosePowerlineRasterParams(width: i32, height: i32) PowerlineRasterParams {
    const min_dim = @max(1, @min(width, height));
    const logical_w = @as(f32, @floatFromInt(@max(1, width)));
    const logical_h = @as(f32, @floatFromInt(@max(1, height)));

    const supersample: i32 = if (min_dim <= 10)
        16
    else if (min_dim <= 14)
        14
    else if (min_dim <= 20)
        12
    else if (min_dim <= 28)
        10
    else
        8;

    const width_ratio = std.math.clamp(logical_h / logical_w, 0.85, 1.25);
    const stroke_base = std.math.clamp((logical_h / 15.5) * width_ratio, 1.2, 2.1);
    const stroke_quant_step: f32 = if (logical_h <= 14.0) 0.125 else 0.25;
    const thin_stroke_logical = std.math.clamp(quantizeStep(stroke_base, stroke_quant_step), 1.2, 2.1);

    const ss_f = @as(f32, @floatFromInt(supersample));
    const seam_extension = std.math.clamp(ss_f * 0.12, 0.75, 1.8);
    const downsample_kernel: DownsampleKernel = if (min_dim <= 16) .tent else .box;

    return .{
        .supersample = supersample,
        .thin_stroke_logical = thin_stroke_logical,
        .seam_extension = seam_extension,
        .downsample_kernel = downsample_kernel,
    };
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
    const min_dim = @min(iw, ih);
    const thin_stroke = std.math.clamp(min_dim / 13.5, 1.2, 1.9);
    return switch (mode) {
        .filled_right => triangleCoverage(x, y, 0.0, 0.0, iw, mid_y, 0.0, ih),
        .filled_left => triangleCoverage(x, y, iw, 0.0, 0.0, mid_y, iw, ih),
        .thin_right => blk: {
            const stroke = thin_stroke;
            const half_w = stroke * 0.5;
            const d0 = distToStrokeExtended(x, y, 0.0, 0.0, iw, mid_y, half_w);
            const d1 = distToStrokeExtended(x, y, 0.0, ih, iw, mid_y, half_w);
            const c0 = clamp01(half_w + 0.5 - d0);
            const c1 = clamp01(half_w + 0.5 - d1);
            break :blk @max(c0, c1);
        },
        .thin_left => blk: {
            const stroke = thin_stroke;
            const half_w = stroke * 0.5;
            const d0 = distToStrokeExtended(x, y, iw, 0.0, 0.0, mid_y, half_w);
            const d1 = distToStrokeExtended(x, y, iw, ih, 0.0, mid_y, half_w);
            const c0 = clamp01(half_w + 0.5 - d0);
            const c1 = clamp01(half_w + 0.5 - d1);
            break :blk @max(c0, c1);
        },
    };
}

fn powerlineCoverageHard(
    mode: PowerlineMode,
    iw: f32,
    ih: f32,
    x: f32,
    y: f32,
    params: PowerlineRasterParams,
) u8 {
    const mid_y = ih * 0.5;
    const ss_f = @as(f32, @floatFromInt(@max(1, params.supersample)));
    const thin_stroke_logical = params.thin_stroke_logical;
    const thin_stroke = thin_stroke_logical * ss_f;
    return switch (mode) {
        .filled_right => blk: {
            // Extend diagonals slightly beyond cell joins to avoid 1px seam leaks
            // after supersample/downsample quantization at fractional render scales.
            const ext_x = params.seam_extension;
            const ext_y = params.seam_extension;
            break :blk if (insideTriangle(x, y, -ext_x, -ext_y, iw + ext_x, mid_y, -ext_x, ih + ext_y)) 255 else 0;
        },
        .filled_left => blk: {
            const ext_x = params.seam_extension;
            const ext_y = params.seam_extension;
            break :blk if (insideTriangle(x, y, iw + ext_x, -ext_y, -ext_x, mid_y, iw + ext_x, ih + ext_y)) 255 else 0;
        },
        .thin_right => blk: {
            const stroke = thin_stroke;
            const half_w = stroke * 0.5;
            const d0 = distToStrokeExtended(x, y, 0.0, 0.0, iw, mid_y, half_w);
            const d1 = distToStrokeExtended(x, y, 0.0, ih, iw, mid_y, half_w);
            break :blk if (d0 <= half_w or d1 <= half_w) 255 else 0;
        },
        .thin_left => blk: {
            const stroke = thin_stroke;
            const half_w = stroke * 0.5;
            const d0 = distToStrokeExtended(x, y, iw, 0.0, 0.0, mid_y, half_w);
            const d1 = distToStrokeExtended(x, y, iw, ih, 0.0, mid_y, half_w);
            break :blk if (d0 <= half_w or d1 <= half_w) 255 else 0;
        },
        .filled_right_round => blk: {
            const ext = params.seam_extension;
            const rx = iw + ext;
            const ry = ih * 0.5 + ext;
            const nx = x / @max(1.0, rx);
            const ny = (y - mid_y) / @max(1.0, ry);
            const inside = (x >= -ext) and (x <= rx) and (nx * nx + ny * ny <= 1.0);
            break :blk if (inside) 255 else 0;
        },
        .filled_left_round => blk: {
            const ext = params.seam_extension;
            const rx = iw + ext;
            const ry = ih * 0.5 + ext;
            const xr = iw - x;
            const nx = xr / @max(1.0, rx);
            const ny = (y - mid_y) / @max(1.0, ry);
            const inside = (xr >= -ext) and (xr <= rx) and (nx * nx + ny * ny <= 1.0);
            break :blk if (inside) 255 else 0;
        },
        .thin_right_round => blk: {
            const ext = params.seam_extension * 0.5;
            const rx = iw + ext;
            const ry = ih * 0.5 + ext;
            const nx = x / @max(1.0, rx);
            const ny = (y - mid_y) / @max(1.0, ry);
            const radial = std.math.sqrt(nx * nx + ny * ny);
            const dist_norm = @abs(radial - 1.0);
            const half_norm = (thin_stroke * 0.5) / @max(1.0, rx);
            break :blk if (x >= -ext and x <= rx and dist_norm <= half_norm) 255 else 0;
        },
        .thin_left_round => blk: {
            const ext = params.seam_extension * 0.5;
            const rx = iw + ext;
            const ry = ih * 0.5 + ext;
            const xr = iw - x;
            const nx = xr / @max(1.0, rx);
            const ny = (y - mid_y) / @max(1.0, ry);
            const radial = std.math.sqrt(nx * nx + ny * ny);
            const dist_norm = @abs(radial - 1.0);
            const half_norm = (thin_stroke * 0.5) / @max(1.0, rx);
            break :blk if (xr >= -ext and xr <= rx and dist_norm <= half_norm) 255 else 0;
        },
    };
}

fn downsampleWeight(kernel: DownsampleKernel, ss: i32, sample_idx: i32) f32 {
    return switch (kernel) {
        .box => 1.0,
        .tent => blk: {
            const center = (@as(f32, @floatFromInt(ss)) - 1.0) * 0.5;
            const d = @abs(@as(f32, @floatFromInt(sample_idx)) - center);
            const denom = center + 0.5;
            break :blk 1.0 - 0.5 * (d / denom);
        },
    };
}

fn rasterizePowerlineMask(mode: PowerlineMode, width: i32, height: i32, out_alpha: []u8) bool {
    const log = app_logger.logger("renderer.terminal.glyphs");
    if (width <= 0 or height <= 0) return false;
    const out_len: usize = @intCast(width * height);
    if (out_alpha.len < out_len) return false;

    const params = choosePowerlineRasterParams(width, height);
    const ss = params.supersample;
    const hi_w = width * ss;
    const hi_h = height * ss;
    const hi_len: usize = @intCast(hi_w * hi_h);
    var hi = std.heap.page_allocator.alloc(u8, hi_len) catch |err| {
        log.logf(.warning, "powerline supersample alloc failed bytes={d} err={s}", .{ hi_len, @errorName(err) });
        return false;
    };
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
            hi[hi_idx] = powerlineCoverageHard(mode, fw, fh, x, y, params);
        }
    }

    const ss_area: u32 = @intCast(ss * ss);
    py = 0;
    while (py < height) : (py += 1) {
        var px: i32 = 0;
        while (px < width) : (px += 1) {
            const out_idx: usize = @intCast(py * width + px);
            switch (params.downsample_kernel) {
                .box => {
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
                    const avg: u8 = @intCast(@divTrunc(sum + ss_area / 2, ss_area));
                    out_alpha[out_idx] = avg;
                },
                .tent => {
                    var sum_w: f32 = 0.0;
                    var sum_a: f32 = 0.0;
                    var sy: i32 = 0;
                    while (sy < ss) : (sy += 1) {
                        const wy = downsampleWeight(.tent, ss, sy);
                        var sx: i32 = 0;
                        while (sx < ss) : (sx += 1) {
                            const wx = downsampleWeight(.tent, ss, sx);
                            const w = wx * wy;
                            const hix = px * ss + sx;
                            const hiy = py * ss + sy;
                            const hi_idx: usize = @intCast(hiy * hi_w + hix);
                            sum_a += @as(f32, @floatFromInt(hi[hi_idx])) * w;
                            sum_w += w;
                        }
                    }
                    if (sum_w <= 0.0) {
                        out_alpha[out_idx] = 0;
                    } else {
                        const avg_f = std.math.clamp(sum_a / sum_w, 0.0, 255.0);
                        out_alpha[out_idx] = @intFromFloat(std.math.round(avg_f));
                    }
                },
            }
        }
    }

    // Filled separators should have a hard, fully-opaque vertical edge on the
    // flat side so adjacent-cell joins don't leak background at fractional scales.
    switch (mode) {
        .filled_right, .filled_right_round => {
            py = 0;
            while (py < height) : (py += 1) {
                const out_idx: usize = @intCast(py * width);
                out_alpha[out_idx] = 255;
            }
        },
        .filled_left, .filled_left_round => {
            const edge_x = width - 1;
            py = 0;
            while (py < height) : (py += 1) {
                const out_idx: usize = @intCast(py * width + edge_x);
                out_alpha[out_idx] = 255;
            }
        },
        else => {},
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
    const log = app_logger.logger("renderer.terminal.glyphs");
    const len: usize = @intCast(iw * ih);
    const mask = std.heap.page_allocator.alloc(u8, len) catch |err| {
                    log.logf(.warning, "analytic powerline mask alloc failed bytes={d} err={s}", .{ len, @errorName(err) });
        return;
    };
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

fn drawBrailleGlyph(
    drawRect: *const fn (ctx: *anyopaque, x: i32, y: i32, w: i32, h: i32, color: Color) void,
    ctx: *anyopaque,
    codepoint: u32,
    ix: i32,
    iy: i32,
    iw: i32,
    ih: i32,
    color: Color,
) void {
    const pattern: u8 = @intCast(codepoint - 0x2800);
    if (pattern == 0) return;

    // Partition the full cell into a 2x4 grid using integer edge splits so
    // adjacent braille cells tile cleanly with no inter-cell padding seams.
    const x_edges = [_]i32{
        0,
        @divTrunc(iw, 2),
        iw,
    };
    const y_edges = [_]i32{
        0,
        @divTrunc(ih, 4),
        @divTrunc(ih * 2, 4),
        @divTrunc(ih * 3, 4),
        ih,
    };

    const Dot = struct { bit: u3, col: u1, row: u2 };
    const dots = [_]Dot{
        .{ .bit = 0, .col = 0, .row = 0 }, // dot 1
        .{ .bit = 1, .col = 0, .row = 1 }, // dot 2
        .{ .bit = 2, .col = 0, .row = 2 }, // dot 3
        .{ .bit = 6, .col = 0, .row = 3 }, // dot 7
        .{ .bit = 3, .col = 1, .row = 0 }, // dot 4
        .{ .bit = 4, .col = 1, .row = 1 }, // dot 5
        .{ .bit = 5, .col = 1, .row = 2 }, // dot 6
        .{ .bit = 7, .col = 1, .row = 3 }, // dot 8
    };

    for (dots) |d| {
        if ((pattern & (@as(u8, 1) << d.bit)) == 0) continue;
        const col: usize = @intCast(d.col);
        const row: usize = @intCast(d.row);
        const x0 = x_edges[col];
        const x1 = x_edges[col + 1];
        const y0 = y_edges[row];
        const y1 = y_edges[row + 1];
        const w = x1 - x0;
        const h = y1 - y0;
        if (w <= 0 or h <= 0) continue;
        drawRect(ctx, ix + x0, iy + y0, w, h, color);
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

    if (codepoint >= 0x2800 and codepoint <= 0x28FF) {
        drawBrailleGlyph(drawRect, ctx, codepoint, ix, iy, iw, ih, color);
        return true;
    }

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
            const radius: i32 = if (iw >= 6 and ih >= 6) 1 else 0;
            const fill_center_pivot = iw <= 6 or ih <= 6;
            const h_x = mid_x + radius;
            const h_w = iw - (h_x - ix);
            if (h_w > 0) drawRect(ctx, h_x, mid_y, h_w, thin, color);
            const v_y = mid_y + radius;
            const v_h = ih - (v_y - iy) + extend;
            if (v_h > 0) drawRect(ctx, mid_x, v_y, thin, v_h, color);
            if (radius > 0) {
                drawRect(ctx, mid_x + radius, mid_y + radius, thin, thin, color);
                if (fill_center_pivot) drawRect(ctx, mid_x, mid_y, thin, thin, color);
            }
            return true;
        },
        0x256e => { // ╮
            const radius: i32 = if (iw >= 6 and ih >= 6) 1 else 0;
            const fill_center_pivot = iw <= 6 or ih <= 6;
            const h_w = (mid_x - ix + thin) - radius;
            if (h_w > 0) drawRect(ctx, ix, mid_y, h_w, thin, color);
            const v_y = mid_y + radius;
            const v_h = ih - (v_y - iy) + extend;
            if (v_h > 0) drawRect(ctx, mid_x, v_y, thin, v_h, color);
            if (radius > 0) {
                drawRect(ctx, mid_x - radius, mid_y + radius, thin, thin, color);
                if (fill_center_pivot) drawRect(ctx, mid_x, mid_y, thin, thin, color);
            }
            return true;
        },
        0x256f => { // ╯
            const radius: i32 = if (iw >= 6 and ih >= 6) 1 else 0;
            const fill_center_pivot = iw <= 6 or ih <= 6;
            const h_w = (mid_x - ix + thin) - radius;
            if (h_w > 0) drawRect(ctx, ix, mid_y, h_w, thin, color);
            const v_h = (mid_y - iy + thin + extend) - radius;
            if (v_h > 0) drawRect(ctx, mid_x, iy - extend, thin, v_h, color);
            if (radius > 0) {
                drawRect(ctx, mid_x - radius, mid_y - radius, thin, thin, color);
                if (fill_center_pivot) drawRect(ctx, mid_x, mid_y, thin, thin, color);
            }
            return true;
        },
        0x2570 => { // ╰
            const radius: i32 = if (iw >= 6 and ih >= 6) 1 else 0;
            const fill_center_pivot = iw <= 6 or ih <= 6;
            const h_x = mid_x + radius;
            const h_w = iw - (h_x - ix);
            if (h_w > 0) drawRect(ctx, h_x, mid_y, h_w, thin, color);
            const v_h = (mid_y - iy + thin + extend) - radius;
            if (v_h > 0) drawRect(ctx, mid_x, iy - extend, thin, v_h, color);
            if (radius > 0) {
                drawRect(ctx, mid_x + radius, mid_y - radius, thin, thin, color);
                if (fill_center_pivot) drawRect(ctx, mid_x, mid_y, thin, thin, color);
            }
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

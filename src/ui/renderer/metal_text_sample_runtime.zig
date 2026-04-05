const std = @import("std");
const terminal_font_mod = @import("../terminal_font.zig");
const metal_backend = @import("metal_backend.zig");
const renderer_root = @import("../renderer.zig");
const types = @import("types.zig");

const TerminalFont = terminal_font_mod.TerminalFont;
const Renderer = renderer_root.Renderer;

fn isSymbolGlyph(codepoint: u32) bool {
    return (codepoint >= 0xE000 and codepoint <= 0xF8FF) or
        (codepoint >= 0xF0000 and codepoint <= 0xFFFFD) or
        (codepoint >= 0x100000 and codepoint <= 0x10FFFD) or
        (codepoint >= 0x2700 and codepoint <= 0x27BF) or
        (codepoint >= 0x2600 and codepoint <= 0x26FF);
}

fn snapToDevicePixel(value: f32, render_scale: f32) f32 {
    const scale = if (render_scale > 0.0) render_scale else 1.0;
    if (!std.math.approxEqAbs(f32, scale, @round(scale), 0.0001)) {
        return value;
    }
    return @as(f32, @floatFromInt(@as(i32, @intFromFloat(@round(value * scale))))) / scale;
}

fn snapVerticalDevicePixel(value: f32, render_scale: f32) f32 {
    const scale = if (render_scale > 0.0) render_scale else 1.0;
    return @as(f32, @floatFromInt(@as(i32, @intFromFloat(@round(value * scale))))) / scale;
}

const QuantizedAxis = struct {
    origin: f32,
    size: f32,
};

fn quantizeHorizontalAxis(origin: f32, size: f32, render_scale: f32) QuantizedAxis {
    const scale = if (render_scale > 0.0) render_scale else 1.0;
    const snapped_origin = snapToDevicePixel(origin, render_scale);
    const snapped_end = snapToDevicePixel(origin + size, render_scale);
    return .{
        .origin = snapped_origin,
        .size = @max(1.0 / scale, snapped_end - snapped_origin),
    };
}

fn quantizeVerticalAxis(origin: f32, size: f32, render_scale: f32) QuantizedAxis {
    const scale = if (render_scale > 0.0) render_scale else 1.0;
    const snapped_origin = snapVerticalDevicePixel(origin, render_scale);
    return .{
        .origin = snapped_origin,
        .size = @max(1.0 / scale, size),
    };
}

/// Pixel destination for one glyph, matching `font/shaping.zig` `drawGlyph` placement (row top at `pen_y`).
pub fn atlasSampleForGlyph(
    renderer: *const Renderer,
    font: *TerminalFont,
    codepoint: u32,
    pen_x: f32,
    pen_y: f32,
    tint: types.Rgba,
    clip_rect: ?metal_backend.PixelClipRect,
) ?metal_backend.AtlasSampleDraw {
    const render_scale = if (renderer.scale.render_scale > 0.0) renderer.scale.render_scale else 1.0;
    const inv_scale = 1.0 / render_scale;
    const baseline = pen_y + font.baseline_from_top * inv_scale;
    const glyph = blk: {
        const direct = font.directFastGlyphForCodepoint(codepoint) orelse return null;
        break :blk font.getGlyphById(direct.face, direct.glyph_id, direct.want_color, false, 0) catch return null;
    };
    if (glyph.rect.width <= 0 or glyph.rect.height <= 0) return null;

    const glyph_w = @as(f32, @floatFromInt(glyph.width)) * inv_scale;
    const glyph_h = @as(f32, @floatFromInt(glyph.height)) * inv_scale;
    const symbol = isSymbolGlyph(codepoint);
    const overflow_scale_x: f32 = 1.0;
    const bearing = @as(f32, @floatFromInt(glyph.bearing_x)) * inv_scale;
    const bearing_y = @as(f32, @floatFromInt(glyph.bearing_y)) * inv_scale;
    const draw_x = if (symbol)
        @max(pen_x, pen_x + bearing * overflow_scale_x)
    else
        @max(pen_x, pen_x + bearing * overflow_scale_x);
    const draw_y = baseline - bearing_y;
    const axis_x = quantizeHorizontalAxis(draw_x, glyph_w, render_scale);
    const axis_y = quantizeVerticalAxis(draw_y, glyph_h, render_scale);
    const draw_color = if (glyph.is_color) types.Rgba{ .r = 255, .g = 255, .b = 255, .a = 255 } else tint;

    return .{
        .atlas = if (glyph.is_color) .color else .coverage,
        .source_rect = glyph.rect,
        .dest_x = @max(0, @as(i32, @intFromFloat(std.math.round(renderer.logicalLengthToRaster(axis_x.origin))))),
        .dest_y = @max(0, @as(i32, @intFromFloat(std.math.round(renderer.logicalLengthToRaster(axis_y.origin))))),
        .tint = draw_color,
        .clip_rect = clip_rect,
    };
}

pub const SampleTextRequest = struct {
    pub const LayoutMode = enum {
        glyph_advance,
        monospace_cell,
    };

    text: []const u8,
    x: f32,
    y: f32,
    tint: types.Rgba = .{ .r = 255, .g = 255, .b = 255, .a = 255 },
    layout: LayoutMode = .glyph_advance,
    clip_rect: ?types.Rect = null,
};

pub const TerminalCellRunRequest = struct {
    text: []const u8,
    x: f32,
    y: f32,
    cell_width: f32,
    cell_height: f32,
    tint: types.Rgba = .{ .r = 255, .g = 255, .b = 255, .a = 255 },
    clip_rect: ?types.Rect = null,
};

pub fn pixelClipRect(renderer: *const Renderer, clip_rect: types.Rect) ?metal_backend.PixelClipRect {
    const x0 = @as(i32, @intFromFloat(std.math.round(renderer.logicalLengthToRaster(clip_rect.x))));
    const y0 = @as(i32, @intFromFloat(std.math.round(renderer.logicalLengthToRaster(clip_rect.y))));
    const x1 = @as(i32, @intFromFloat(std.math.round(renderer.logicalLengthToRaster(clip_rect.x + clip_rect.width))));
    const y1 = @as(i32, @intFromFloat(std.math.round(renderer.logicalLengthToRaster(clip_rect.y + clip_rect.height))));
    const width = x1 - x0;
    const height = y1 - y0;
    if (width <= 0 or height <= 0) return null;
    return .{
        .x = x0,
        .y = y0,
        .width = width,
        .height = height,
    };
}

fn intersectRect(lhs: types.Rect, rhs: types.Rect) ?types.Rect {
    const x0 = @max(lhs.x, rhs.x);
    const y0 = @max(lhs.y, rhs.y);
    const x1 = @min(lhs.x + lhs.width, rhs.x + rhs.width);
    const y1 = @min(lhs.y + lhs.height, rhs.y + rhs.height);
    const width = x1 - x0;
    const height = y1 - y0;
    if (width <= 0 or height <= 0) return null;
    return .{ .x = x0, .y = y0, .width = width, .height = height };
}

fn effectiveClipRect(renderer: *const Renderer, request_clip_rect: ?types.Rect) ?types.Rect {
    return if (request_clip_rect) |requested|
        if (renderer.currentClipRect()) |current|
            intersectRect(current, requested) orelse types.Rect{
                .x = requested.x,
                .y = requested.y,
                .width = 0,
                .height = 0,
            }
        else
            requested
    else
        renderer.currentClipRect();
}

pub fn appendUtf8Run(
    renderer: *const Renderer,
    font: *TerminalFont,
    request: SampleTextRequest,
    draws: *std.ArrayListUnmanaged(metal_backend.SurfaceDraw),
    allocator: std.mem.Allocator,
) bool {
    if (request.text.len == 0) return false;

    const render_scale = if (renderer.scale.render_scale > 0.0) renderer.scale.render_scale else 1.0;
    const line_height = font.line_height / render_scale;
    const cell_width = font.cell_width / render_scale;
    const clip = if (effectiveClipRect(renderer, request.clip_rect)) |clip_rect| pixelClipRect(renderer, clip_rect) else null;
    var pen_x = request.x;
    var pen_y = request.y;
    var drew_any = false;

    var it = std.unicode.Utf8View.init(request.text) catch return false;
    var iterator = it.iterator();
    while (iterator.nextCodepoint()) |codepoint| {
        if (codepoint == '\n') {
            pen_x = request.x;
            pen_y += line_height;
            continue;
        }
        if (codepoint == ' ') {
            pen_x += cell_width;
            continue;
        }

        const sample = atlasSampleForGlyph(renderer, font, codepoint, pen_x, pen_y, request.tint, clip) orelse return drew_any;
        const advance_glyph = blk: {
            const direct = font.directFastGlyphForCodepoint(codepoint) orelse return drew_any;
            break :blk font.getGlyphById(direct.face, direct.glyph_id, direct.want_color, false, 0) catch return drew_any;
        };
        draws.append(allocator, .{ .atlas = sample }) catch return drew_any;
        drew_any = true;
        pen_x += switch (request.layout) {
            .glyph_advance => advance_glyph.advance / render_scale,
            .monospace_cell => cell_width,
        };
    }

    return drew_any;
}

pub fn appendTerminalUtf8Cells(
    renderer: *const Renderer,
    font: *TerminalFont,
    request: TerminalCellRunRequest,
    draws: *std.ArrayListUnmanaged(metal_backend.SurfaceDraw),
    allocator: std.mem.Allocator,
) bool {
    if (request.text.len == 0) return false;
    const render_scale = if (renderer.scale.render_scale > 0.0) renderer.scale.render_scale else 1.0;
    const clip = if (effectiveClipRect(renderer, request.clip_rect)) |clip_rect| pixelClipRect(renderer, clip_rect) else null;
    var pen_x = request.x;
    var pen_y = request.y;
    var drew_any = false;

    var it = std.unicode.Utf8View.init(request.text) catch return false;
    var iterator = it.iterator();
    while (iterator.nextCodepoint()) |codepoint| {
        if (codepoint == '\n') {
            pen_x = request.x;
            pen_y += request.cell_height;
            continue;
        }
        if (codepoint == ' ') {
            pen_x += request.cell_width;
            continue;
        }

        const sample = atlasSampleForGlyph(renderer, font, codepoint, pen_x, pen_y, request.tint, clip) orelse {
            pen_x += request.cell_width;
            continue;
        };
        draws.append(allocator, .{ .atlas = sample }) catch return drew_any;
        drew_any = true;
        pen_x += request.cell_width;
    }

    _ = render_scale;
    return drew_any;
}

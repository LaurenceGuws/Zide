const std = @import("std");

const common = @import("common.zig");

pub const VerticalGeometry = struct {
    visible: bool,
    focus_t: f32,
    scrollbar_x: f32,
    scrollbar_y: f32,
    scrollbar_w: f32,
    scrollbar_h: f32,
    hit_margin: f32,
    max_scroll_offset: usize,
    effective_scroll_offset: usize,
    thumb: common.ScrollbarThumb,
};

pub fn shouldShowVertical(rows: usize, total_lines: usize, scroll_offset: usize) bool {
    _ = scroll_offset;
    return rows > 0 and total_lines > rows;
}

pub fn computeVerticalHoverTarget(
    scale: f32,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    mouse: anytype,
    rows: usize,
    total_lines: usize,
    scroll_offset: usize,
    dragging: bool,
    visible: bool,
) VerticalGeometry {
    const focus_t = if (visible)
        computeHoverFocusT(scale, x, y, width, height, mouse, dragging)
    else
        0.0;
    return computeVerticalForFocus(scale, x, y, width, height, rows, total_lines, scroll_offset, focus_t, visible);
}

pub fn computeVerticalForFocus(
    scale: f32,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    rows: usize,
    total_lines: usize,
    scroll_offset: usize,
    focus_t: f32,
    visible: bool,
) VerticalGeometry {
    if (!visible or width <= 0 or height <= 0 or rows == 0 or total_lines <= rows) {
        return .{
            .visible = false,
            .focus_t = 0,
            .scrollbar_x = x + width,
            .scrollbar_y = y,
            .scrollbar_w = 0,
            .scrollbar_h = height,
            .hit_margin = 0,
            .max_scroll_offset = 0,
            .effective_scroll_offset = 0,
            .thumb = .{ .thumb_h = 0, .available = 0, .thumb_y = y },
        };
    }

    const clamped_focus_t = std.math.clamp(focus_t, 0.0, 1.0);
    const scrollbar_w: f32 = common.scrollbarHoverWidth(scale);
    const slide_x = common.lerp(0.0, common.scrollbarWidth(scale) * 0.5, clamped_focus_t);
    const scrollbar_x = x + width - scrollbar_w - slide_x;
    const max_scroll_offset = total_lines - rows;
    const effective_scroll_offset = @min(scroll_offset, max_scroll_offset);
    const thumb = common.computeScrollbarThumb(
        y,
        height,
        rows,
        total_lines,
        18,
        common.scrollbarTrackRatio(max_scroll_offset, effective_scroll_offset),
    );

    return .{
        .visible = true,
        .focus_t = clamped_focus_t,
        .scrollbar_x = scrollbar_x,
        .scrollbar_y = y,
        .scrollbar_w = scrollbar_w,
        .scrollbar_h = height,
        .hit_margin = common.scrollbarHitMargin(scale),
        .max_scroll_offset = max_scroll_offset,
        .effective_scroll_offset = effective_scroll_offset,
        .thumb = thumb,
    };
}

fn computeHoverFocusT(
    scale: f32,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    mouse: anytype,
    dragging: bool,
) f32 {
    const hit_margin: f32 = common.scrollbarHitMargin(scale);
    const proximity: f32 = common.scrollbarProximityRange(scale);
    const in_y = mouse.y >= y and mouse.y <= y + height;
    const dist_from_right = (x + width) - mouse.x;
    const proximity_raw: f32 = if (in_y and dist_from_right <= proximity and dist_from_right >= -hit_margin)
        (1.0 - std.math.clamp(dist_from_right / proximity, 0.0, 1.0))
    else
        0.0;
    return if (dragging) 1.0 else common.smoothstep01(proximity_raw);
}

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
    max_scroll: usize,
    effective_scroll_line: usize,
    thumb: common.ScrollbarThumb,
};

pub const HorizontalGeometry = struct {
    visible: bool,
    focus_t: f32,
    track_x: f32,
    track_y: f32,
    track_h: f32,
    track_max_y: f32,
    track_max_h: f32,
    track_w: f32,
    hit_margin: f32,
    max_scroll: usize,
    effective_scroll_col: usize,
    thumb_x: f32,
    thumb_w: f32,
    available: f32,
};

pub fn computeVertical(
    scale: f32,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    mouse: anytype,
    visible_lines: usize,
    total_lines: usize,
    scroll_line: usize,
    dragging: bool,
) VerticalGeometry {
    if (total_lines <= visible_lines or width <= 0 or height <= 0) {
        return .{
            .visible = false,
            .focus_t = 0,
            .scrollbar_x = x,
            .scrollbar_y = y,
            .scrollbar_w = 0,
            .scrollbar_h = height,
            .hit_margin = 0,
            .max_scroll = 0,
            .effective_scroll_line = 0,
            .thumb = .{ .thumb_h = 0, .available = 0, .thumb_y = y },
        };
    }

    const base_w: f32 = common.scrollbarWidth(scale);
    const hover_w: f32 = common.scrollbarHoverWidth(scale);
    const hit_margin: f32 = common.scrollbarHitMargin(scale);
    const proximity: f32 = common.scrollbarProximityRange(scale);
    const in_y = mouse.y >= y and mouse.y <= y + height;
    const dist_from_right = (x + width) - mouse.x;
    const proximity_raw: f32 = if (in_y and dist_from_right <= proximity and dist_from_right >= -hit_margin)
        (1.0 - std.math.clamp(dist_from_right / proximity, 0.0, 1.0))
    else
        0.0;
    const t = if (dragging) 1.0 else common.smoothstep01(proximity_raw);
    const scrollbar_w: f32 = common.lerp(base_w, hover_w, t);
    const scrollbar_x = x + width - scrollbar_w;
    const scrollbar_y = y;
    const scrollbar_h = height;

    const max_scroll = total_lines - visible_lines;
    const effective_scroll_line = @min(scroll_line, max_scroll);
    const ratio = if (max_scroll > 0)
        @as(f32, @floatFromInt(effective_scroll_line)) / @as(f32, @floatFromInt(max_scroll))
    else
        0.0;
    const min_thumb_h: f32 = 32 * scale;
    const thumb = common.computeScrollbarThumb(scrollbar_y, scrollbar_h, visible_lines, total_lines, min_thumb_h, ratio);

    return .{
        .visible = true,
        .focus_t = t,
        .scrollbar_x = scrollbar_x,
        .scrollbar_y = scrollbar_y,
        .scrollbar_w = scrollbar_w,
        .scrollbar_h = scrollbar_h,
        .hit_margin = hit_margin,
        .max_scroll = max_scroll,
        .effective_scroll_line = effective_scroll_line,
        .thumb = thumb,
    };
}

pub fn computeHorizontal(
    scale: f32,
    gutter_width: f32,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    mouse: anytype,
    max_visible_width: usize,
    cols: usize,
    total_lines: usize,
    visible_lines: usize,
    scroll_col: usize,
    dragging: bool,
) HorizontalGeometry {
    if (width <= 0 or height <= 0 or cols == 0 or max_visible_width <= cols) {
        return .{
            .visible = false,
            .focus_t = 0,
            .track_x = x + gutter_width,
            .track_y = y + height,
            .track_h = 0,
            .track_max_y = y + height,
            .track_max_h = 0,
            .track_w = 0,
            .hit_margin = 0,
            .max_scroll = 0,
            .effective_scroll_col = 0,
            .thumb_x = x + gutter_width,
            .thumb_w = 0,
            .available = 0,
        };
    }

    const show_vscroll = total_lines > visible_lines;
    const vscroll_w: f32 = if (show_vscroll) common.scrollbarWidth(scale) else 0;
    const track_base_h: f32 = common.scrollbarWidth(scale);
    const track_hover_h: f32 = common.scrollbarHoverWidth(scale);
    const hit_margin: f32 = common.scrollbarHitMargin(scale);
    const proximity: f32 = common.scrollbarProximityRange(scale);
    const in_x = mouse.x >= x + gutter_width and mouse.x <= x + width;
    const dist_from_bottom = (y + height) - mouse.y;
    const proximity_raw: f32 = if (in_x and dist_from_bottom <= proximity and dist_from_bottom >= -hit_margin)
        (1.0 - std.math.clamp(dist_from_bottom / proximity, 0.0, 1.0))
    else
        0.0;
    const t = if (dragging) 1.0 else common.smoothstep01(proximity_raw);
    const track_h: f32 = common.lerp(track_base_h, track_hover_h, t);
    const track_y = y + height - track_h;
    const track_max_h = @max(track_base_h, track_hover_h);
    const track_max_y = y + height - track_max_h;
    const track_x = x + gutter_width;
    const track_w = @max(@as(f32, 1), width - gutter_width - vscroll_w);
    const max_scroll = max_visible_width - cols;
    const effective_scroll_col = @min(scroll_col, max_scroll);

    const min_thumb_w: f32 = 32 * scale;
    const thumb_w = @max(min_thumb_w, track_w * (@as(f32, @floatFromInt(cols)) / @as(f32, @floatFromInt(max_visible_width))));
    const available = @max(@as(f32, 1), track_w - thumb_w);
    const ratio = if (max_scroll > 0)
        @as(f32, @floatFromInt(effective_scroll_col)) / @as(f32, @floatFromInt(max_scroll))
    else
        0.0;
    const thumb_x = track_x + available * ratio;

    return .{
        .visible = true,
        .focus_t = t,
        .track_x = track_x,
        .track_y = track_y,
        .track_h = track_h,
        .track_max_y = track_max_y,
        .track_max_h = track_max_h,
        .track_w = track_w,
        .hit_margin = hit_margin,
        .max_scroll = max_scroll,
        .effective_scroll_col = effective_scroll_col,
        .thumb_x = thumb_x,
        .thumb_w = thumb_w,
        .available = available,
    };
}

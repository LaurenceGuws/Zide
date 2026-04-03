const app_shell = @import("../../app_shell.zig");
const scrollback_view = @import("../../terminal/core/scrollback_view.zig");
const shared_types = @import("../../types/mod.zig");
const widgets = @import("../../ui/widgets.zig");
const terminal_runtime = @import("../../terminal/core/terminal_runtime.zig");
const terminal_scrollbar_mod = @import("../../ui/widgets/terminal_scrollbar.zig");

const Shell = app_shell.Shell;
const MousePos = shared_types.input.MousePos;
const InputBatch = shared_types.input.InputBatch;
const TerminalWidget = widgets.TerminalWidget;
const Color = app_shell.Color;

pub const Result = struct {
    blocking: bool = false,
    needs_redraw: bool = false,
    note_input: bool = false,
};

pub fn wantsPassiveHoverWake(
    widget: *const TerminalWidget,
    shell: *Shell,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    mouse: MousePos,
    dragging: bool,
) bool {
    const model = widget.scrollbarModel();
    const chrome_visible = model.visible or dragging;
    if (!chrome_visible or !shell.windowFocused()) return false;
    const geometry = terminal_scrollbar_mod.computeVerticalHoverTarget(
        shell.uiScaleFactor(),
        x,
        y,
        width,
        height,
        mouse,
        model.rows,
        model.total_lines,
        model.scroll_offset,
        dragging,
        chrome_visible,
    );
    return geometry.visible and geometry.focus_t > 0.01;
}

pub fn handleInput(
    widget: *TerminalWidget,
    shell: *Shell,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    input_batch: *InputBatch,
    dragging: *bool,
    grab_offset: *f32,
    hovered: *bool,
) Result {
    var out: Result = .{};
    const model = widget.scrollbarModel();
    const focused = shell.windowFocused();
    const chrome_visible = model.visible or dragging.*;
    const geometry = terminal_scrollbar_mod.computeVerticalHoverTarget(
        shell.uiScaleFactor(),
        x,
        y,
        width,
        height,
        input_batch.mouse_pos,
        model.rows,
        model.total_lines,
        model.scroll_offset,
        dragging.*,
        chrome_visible and focused,
    );
    const hovering = wantsPassiveHoverWake(widget, shell, x, y, width, height, input_batch.mouse_pos, dragging.*);
    if (hovered.* != hovering) {
        hovered.* = hovering;
        out.needs_redraw = true;
    }

    if (!focused or !model.allowed) {
        if (dragging.*) {
            dragging.* = false;
            grab_offset.* = 0;
            out.needs_redraw = true;
        }
        return out;
    }

    const mouse = input_batch.mouse_pos;
    const over_track = pointInVerticalScrollbar(mouse, geometry);
    const over_thumb = over_track and pointInThumb(mouse, geometry);
    const mouse_down = input_batch.mouseDown(.left);
    const mouse_pressed = input_batch.mousePressed(.left);
    const mouse_released = input_batch.mouseReleased(.left);

    if (dragging.* and mouse_released) {
        dragging.* = false;
        grab_offset.* = 0;
        out.blocking = true;
        out.needs_redraw = true;
        out.note_input = true;
        return out;
    }
    if (dragging.* and !mouse_down) {
        dragging.* = false;
        grab_offset.* = 0;
        out.needs_redraw = true;
        return out;
    }
    if ((mouse_pressed or (!dragging.* and mouse_down)) and over_track) {
        dragging.* = true;
        grab_offset.* = if (over_thumb) mouse.y - geometry.thumb.thumb_y else geometry.thumb.thumb_h * 0.5;
        out.blocking = true;
        if (updateFromMouse(widget.session, mouse.y, geometry, grab_offset.*)) {
            out.needs_redraw = true;
            out.note_input = true;
        }
        return out;
    }
    if (dragging.* and mouse_down) {
        out.blocking = true;
        if (updateFromMouse(widget.session, mouse.y, geometry, grab_offset.*)) {
            out.needs_redraw = true;
            out.note_input = true;
        }
        return out;
    }
    if (over_track and (mouse_pressed or mouse_down)) {
        out.blocking = true;
    }
    return out;
}

pub fn draw(
    widget: *const TerminalWidget,
    shell: *Shell,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    mouse: MousePos,
    dragging: bool,
) void {
    const model = widget.scrollbarModel();
    const chrome_visible = model.visible or dragging;
    if (!chrome_visible or !shell.windowFocused() or width <= 0 or height <= 0) return;
    const r = shell.rendererPtr();
    const geometry = terminal_scrollbar_mod.computeVerticalHoverTarget(
        r.uiScaleFactor(),
        x,
        y,
        width,
        height,
        mouse,
        model.rows,
        model.total_lines,
        model.scroll_offset,
        dragging,
        chrome_visible,
    );
    const thumb_inset = @max(1.0, geometry.scrollbar_w * 0.25);
    const thumb_w = @max(1.0, geometry.scrollbar_w - thumb_inset * 2);
    const thumb_color = alphaScale(r.theme.selection, 0.85);
    r.drawRect(
        @intFromFloat(geometry.scrollbar_x + thumb_inset),
        @intFromFloat(geometry.thumb.thumb_y),
        @intFromFloat(thumb_w),
        @intFromFloat(geometry.thumb.thumb_h),
        thumb_color,
    );
}

fn updateFromMouse(session: *terminal_runtime.TerminalRuntimeShell, mouse_y: f32, geometry: terminal_scrollbar_mod.VerticalGeometry, grab_offset: f32) bool {
    const available = geometry.thumb.available;
    const clamped_mouse = @min(@max(mouse_y - grab_offset, geometry.scrollbar_y), geometry.scrollbar_y + available);
    const ratio = if (available > 0) (clamped_mouse - geometry.scrollbar_y) / available else 0;
    return scrollback_view.setScrollOffsetFromNormalizedTrack(session, ratio) != null;
}

fn pointInVerticalScrollbar(mouse: MousePos, geometry: terminal_scrollbar_mod.VerticalGeometry) bool {
    return mouse.x >= geometry.scrollbar_x - geometry.hit_margin and
        mouse.x <= geometry.scrollbar_x + geometry.scrollbar_w + geometry.hit_margin and
        mouse.y >= geometry.scrollbar_y and
        mouse.y <= geometry.scrollbar_y + geometry.scrollbar_h;
}

fn pointInThumb(mouse: MousePos, geometry: terminal_scrollbar_mod.VerticalGeometry) bool {
    return mouse.x >= geometry.scrollbar_x - geometry.hit_margin and
        mouse.x <= geometry.scrollbar_x + geometry.scrollbar_w + geometry.hit_margin and
        mouse.y >= geometry.thumb.thumb_y and
        mouse.y <= geometry.thumb.thumb_y + geometry.thumb.thumb_h;
}

fn alphaScale(color: Color, scale: f32) Color {
    return .{
        .r = color.r,
        .g = color.g,
        .b = color.b,
        .a = @intFromFloat(@min(255.0, @max(0.0, @as(f32, @floatFromInt(color.a)) * scale))),
    };
}

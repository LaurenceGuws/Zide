const app_shell = @import("../../app_shell.zig");
const scroll_mod = @import("../../editor/view/scroll.zig");
const app_logger = @import("../../app_logger.zig");
const shared_types = @import("../../types/mod.zig");
const common = @import("common.zig");

const Shell = app_shell.Shell;

pub fn handleMouseClick(
    widget: anytype,
    shell: *Shell,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    mouse_x: f32,
    mouse_y: f32,
) bool {
    if (widget.cursorFromMouse(shell, x, y, width, height, mouse_x, mouse_y, false)) |pos| {
        widget.editor.setCursor(pos.line, pos.col);
        const log = app_logger.logger("editor.input");
        log.logf("mouse click line={d} col={d}", .{ pos.line, pos.col });
        return true;
    }
    return false;
}

/// Handle input, returns true if any input was processed
pub fn handleInput(widget: anytype, shell: *Shell, height: f32, input_batch: *shared_types.input.InputBatch) !bool {
    var handled = false;
    var chars_inserted: usize = 0;

    // Character input
    for (input_batch.events.items) |event| {
        if (event == .text) {
            const char = event.text.codepoint;
            if (!input_batch.mods.ctrl and !input_batch.mods.alt and !input_batch.mods.super and char >= 32 and char < 127) {
                try widget.editor.insertChar(@intCast(char));
                handled = true;
                chars_inserted += 1;
            }
        }
    }
    if (chars_inserted > 0) {
        const log = app_logger.logger("editor.input");
        log.logf("chars inserted={d}", .{chars_inserted});
    }

    // Control keys
    if (input_batch.keyPressed(.enter)) {
        try widget.editor.insertNewline();
        handled = true;
        app_logger.logger("editor.input").logf("key=enter", .{});
    } else if (input_batch.keyPressed(.backspace) or input_batch.keyRepeated(.backspace)) {
        try widget.editor.deleteCharBackward();
        handled = true;
        app_logger.logger("editor.input").logf("key=backspace", .{});
    } else if (input_batch.keyPressed(.delete) or input_batch.keyRepeated(.delete)) {
        try widget.editor.deleteCharForward();
        handled = true;
        app_logger.logger("editor.input").logf("key=delete", .{});
    } else if (input_batch.keyPressed(.up) or input_batch.keyRepeated(.up)) {
        if (widget.moveCursorVisual(shell, -1)) {
            widget.ensureCursorVisible(shell, height);
            handled = true;
            app_logger.logger("editor.input").logf("key=up", .{});
        }
    } else if (input_batch.keyPressed(.down) or input_batch.keyRepeated(.down)) {
        if (widget.moveCursorVisual(shell, 1)) {
            widget.ensureCursorVisible(shell, height);
            handled = true;
            app_logger.logger("editor.input").logf("key=down", .{});
        }
    } else if (input_batch.keyPressed(.left) or input_batch.keyRepeated(.left)) {
        widget.editor.moveCursorLeft();
        widget.ensureCursorVisible(shell, height);
        handled = true;
        app_logger.logger("editor.input").logf("key=left", .{});
    } else if (input_batch.keyPressed(.right) or input_batch.keyRepeated(.right)) {
        widget.editor.moveCursorRight();
        widget.ensureCursorVisible(shell, height);
        handled = true;
        app_logger.logger("editor.input").logf("key=right", .{});
    } else if (input_batch.keyPressed(.home) or input_batch.keyRepeated(.home)) {
        widget.editor.moveCursorToLineStart();
        widget.ensureCursorVisible(shell, height);
        handled = true;
        app_logger.logger("editor.input").logf("key=home", .{});
    } else if (input_batch.keyPressed(.end) or input_batch.keyRepeated(.end)) {
        widget.editor.moveCursorToLineEnd();
        widget.ensureCursorVisible(shell, height);
        handled = true;
        app_logger.logger("editor.input").logf("key=end", .{});
    }

    // Scroll handling
    const wheel = input_batch.scroll.y;
    if (wheel != 0) {
        const shift = input_batch.mods.shift;
        const delta = @as(i32, @intFromFloat(-wheel * 3));
        if (shift and !widget.wrap_enabled) {
            widget.scrollHorizontal(shell, delta);
            handled = true;
            app_logger.logger("editor.input").logf("hscroll delta={d} scroll_col={d}", .{ delta, widget.editor.scroll_col });
        } else {
            widget.scrollVisual(shell, delta);
            handled = true;
            app_logger.logger("editor.input").logf("scroll delta={d} new_line={d} row_offset={d}", .{ delta, widget.editor.scroll_line, widget.editor.scroll_row_offset });
        }
    }

    return handled;
}

pub fn handleHorizontalScrollbarInput(
    widget: anytype,
    shell: *Shell,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    mouse: app_shell.MousePos,
    dragging: *bool,
    grab_offset: *f32,
    input_batch: *shared_types.input.InputBatch,
) bool {
    if (widget.wrap_enabled) return false;
    if (width <= 0 or height <= 0) return false;
    const cols = widget.viewportColumns(shell);
    if (cols == 0) return false;
    const visible_lines = @as(usize, @intFromFloat(height / shell.charHeight()));
    if (visible_lines == 0) return false;

    const scan = widget.editor.advanceMaxLineWidthCache(64);
    const max_visible_width = scan.max;
    if (max_visible_width <= cols) return false;

    const show_vscroll = widget.editor.lineCount() > visible_lines;
    const scale = shell.uiScaleFactor();
    const vscroll_w: f32 = if (show_vscroll) 16 * scale else 0;
    const track_h: f32 = 16 * scale;
    const track_y = y + height - track_h;
    const track_x = x + widget.gutter_width;
    const track_w = @max(@as(f32, 1), width - widget.gutter_width - vscroll_w);
    const max_scroll = max_visible_width - cols;
    if (widget.editor.scroll_col > max_scroll) {
        widget.editor.scroll_col = max_scroll;
    }

    const min_thumb_w: f32 = 24 * scale;
    const thumb_w = @max(min_thumb_w, track_w * (@as(f32, @floatFromInt(cols)) / @as(f32, @floatFromInt(max_visible_width))));
    const available = @max(@as(f32, 1), track_w - thumb_w);
    const ratio = if (max_scroll > 0)
        @as(f32, @floatFromInt(widget.editor.scroll_col)) / @as(f32, @floatFromInt(max_scroll))
    else
        0.0;
    const thumb_x = track_x + available * ratio;

    const over_track = mouse.x >= track_x and mouse.x <= track_x + track_w and mouse.y >= track_y and mouse.y <= track_y + track_h;
    const over_thumb = mouse.x >= thumb_x and mouse.x <= thumb_x + thumb_w and mouse.y >= track_y and mouse.y <= track_y + track_h;

    const mouse_down = input_batch.mouseDown(.left);
    const mouse_pressed = input_batch.mousePressed(.left);
    const mouse_released = input_batch.mouseReleased(.left);
    if (dragging.* and mouse_released) {
        dragging.* = false;
        return true;
    }
    if (dragging.* and !mouse_down) {
        dragging.* = false;
        return false;
    }
    if (dragging.* and mouse_pressed and !over_track) {
        dragging.* = false;
        return false;
    }
    if ((mouse_pressed or (!dragging.* and mouse_down)) and over_track) {
        dragging.* = true;
        grab_offset.* = if (over_thumb) mouse.x - thumb_x else thumb_w * 0.5;
        scroll_mod.updateHorizontalScrollFromMouse(widget.editor, mouse.x, track_x, available, grab_offset.*, max_scroll);
        return true;
    }

    if (dragging.* and mouse_down) {
        scroll_mod.updateHorizontalScrollFromMouse(widget.editor, mouse.x, track_x, available, grab_offset.*, max_scroll);
        return true;
    }

    return false;
}

pub fn handleVerticalScrollbarInput(
    widget: anytype,
    shell: *Shell,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    mouse: app_shell.MousePos,
    dragging: *bool,
    grab_offset: *f32,
    input_batch: *shared_types.input.InputBatch,
) bool {
    if (widget.wrap_enabled) return false;
    if (width <= 0 or height <= 0) return false;
    const visible_lines = @as(usize, @intFromFloat(height / shell.charHeight()));
    if (visible_lines == 0) return false;
    const total_lines = widget.editor.lineCount();
    if (total_lines <= visible_lines) return false;

    const scale = shell.uiScaleFactor();
    const scrollbar_w: f32 = 16 * scale;
    const scrollbar_x = x + width - scrollbar_w;
    const scrollbar_y = y;
    const scrollbar_h = height;
    const max_scroll = total_lines - visible_lines;
    if (widget.editor.scroll_line > max_scroll) {
        widget.editor.scroll_line = max_scroll;
    }

    const ratio = if (max_scroll > 0)
        @as(f32, @floatFromInt(widget.editor.scroll_line)) / @as(f32, @floatFromInt(max_scroll))
    else
        0.0;
    const min_thumb_h: f32 = 32 * scale;
    const thumb = common.computeScrollbarThumb(scrollbar_y, scrollbar_h, visible_lines, total_lines, min_thumb_h, ratio);

    const over_track = mouse.x >= scrollbar_x and mouse.x <= scrollbar_x + scrollbar_w and mouse.y >= scrollbar_y and mouse.y <= scrollbar_y + scrollbar_h;
    const over_thumb = mouse.x >= scrollbar_x and mouse.x <= scrollbar_x + scrollbar_w and mouse.y >= thumb.thumb_y and mouse.y <= thumb.thumb_y + thumb.thumb_h;

    const mouse_down = input_batch.mouseDown(.left);
    const mouse_pressed = input_batch.mousePressed(.left);
    const mouse_released = input_batch.mouseReleased(.left);
    if (dragging.* and mouse_released) {
        dragging.* = false;
        return true;
    }
    if (dragging.* and !mouse_down) {
        dragging.* = false;
        return false;
    }
    if (dragging.* and mouse_pressed and !over_track) {
        dragging.* = false;
        return false;
    }
    if ((mouse_pressed or (!dragging.* and mouse_down)) and over_track) {
        dragging.* = true;
        grab_offset.* = if (over_thumb) mouse.y - thumb.thumb_y else thumb.thumb_h * 0.5;
        scroll_mod.updateVerticalScrollFromMouse(widget.editor, mouse.y, scrollbar_y, thumb.available, grab_offset.*, max_scroll);
        return true;
    }

    if (dragging.* and mouse_down) {
        scroll_mod.updateVerticalScrollFromMouse(widget.editor, mouse.y, scrollbar_y, thumb.available, grab_offset.*, max_scroll);
        return true;
    }

    return false;
}

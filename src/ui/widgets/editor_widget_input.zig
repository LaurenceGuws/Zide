const app_shell = @import("../../app_shell.zig");
const scroll_mod = @import("../../editor/view/scroll.zig");
const app_logger = @import("../../app_logger.zig");

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
pub fn handleInput(widget: anytype, shell: *Shell, height: f32) !bool {
    const r = shell.rendererPtr();
    var handled = false;
    var chars_inserted: usize = 0;
    var group_started = false;
    errdefer if (group_started) widget.editor.endUndoGroup() catch {};

    // Character input
    while (r.getCharPressed()) |char| {
        if (char >= 32 and char < 127) {
            if (!group_started) {
                widget.editor.beginUndoGroup();
                group_started = true;
            }
            try widget.editor.insertChar(@intCast(char));
            handled = true;
            chars_inserted += 1;
        }
    }
    if (chars_inserted > 0) {
        const log = app_logger.logger("editor.input");
        log.logf("chars inserted={d}", .{chars_inserted});
    }

    // Control keys
    const ctrl = r.isKeyDown(app_shell.KEY_LEFT_CONTROL) or r.isKeyDown(app_shell.KEY_RIGHT_CONTROL);

    if (r.isKeyPressed(app_shell.KEY_ENTER)) {
        if (!group_started) {
            widget.editor.beginUndoGroup();
            group_started = true;
        }
        try widget.editor.insertNewline();
        handled = true;
        app_logger.logger("editor.input").logf("key=enter", .{});
    } else if (r.isKeyRepeated(app_shell.KEY_BACKSPACE)) {
        if (!group_started) {
            widget.editor.beginUndoGroup();
            group_started = true;
        }
        try widget.editor.deleteCharBackward();
        handled = true;
        app_logger.logger("editor.input").logf("key=backspace", .{});
    } else if (r.isKeyRepeated(app_shell.KEY_DELETE)) {
        if (!group_started) {
            widget.editor.beginUndoGroup();
            group_started = true;
        }
        try widget.editor.deleteCharForward();
        handled = true;
        app_logger.logger("editor.input").logf("key=delete", .{});
    } else if (r.isKeyRepeated(app_shell.KEY_UP)) {
        if (widget.moveCursorVisual(shell, -1)) {
            widget.ensureCursorVisible(shell, height);
            handled = true;
            app_logger.logger("editor.input").logf("key=up", .{});
        }
    } else if (r.isKeyRepeated(app_shell.KEY_DOWN)) {
        if (widget.moveCursorVisual(shell, 1)) {
            widget.ensureCursorVisible(shell, height);
            handled = true;
            app_logger.logger("editor.input").logf("key=down", .{});
        }
    } else if (r.isKeyRepeated(app_shell.KEY_LEFT)) {
        widget.editor.moveCursorLeft();
        widget.ensureCursorVisible(shell, height);
        handled = true;
        app_logger.logger("editor.input").logf("key=left", .{});
    } else if (r.isKeyRepeated(app_shell.KEY_RIGHT)) {
        widget.editor.moveCursorRight();
        widget.ensureCursorVisible(shell, height);
        handled = true;
        app_logger.logger("editor.input").logf("key=right", .{});
    } else if (r.isKeyRepeated(app_shell.KEY_HOME)) {
        widget.editor.moveCursorToLineStart();
        widget.ensureCursorVisible(shell, height);
        handled = true;
        app_logger.logger("editor.input").logf("key=home", .{});
    } else if (r.isKeyRepeated(app_shell.KEY_END)) {
        widget.editor.moveCursorToLineEnd();
        widget.ensureCursorVisible(shell, height);
        handled = true;
        app_logger.logger("editor.input").logf("key=end", .{});
    } else if (ctrl and r.isKeyPressed(app_shell.KEY_S)) {
        try widget.editor.save();
        handled = true;
        app_logger.logger("editor.input").logf("key=ctrl+s", .{});
    } else if (ctrl and r.isKeyPressed(app_shell.KEY_Z)) {
        _ = try widget.editor.undo();
        handled = true;
        app_logger.logger("editor.input").logf("key=ctrl+z", .{});
    } else if (ctrl and r.isKeyPressed(app_shell.KEY_Y)) {
        _ = try widget.editor.redo();
        handled = true;
        app_logger.logger("editor.input").logf("key=ctrl+y", .{});
    }

    if (group_started) {
        try widget.editor.endUndoGroup();
    }

    // Scroll handling
    const wheel = r.getMouseWheelMove();
    if (wheel != 0) {
        const shift = r.isKeyDown(app_shell.KEY_LEFT_SHIFT) or r.isKeyDown(app_shell.KEY_RIGHT_SHIFT);
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
) bool {
    const r = shell.rendererPtr();
    if (widget.wrap_enabled) return false;
    if (width <= 0 or height <= 0) return false;
    const cols = widget.viewportColumns(shell);
    if (cols == 0) return false;
    const visible_lines = @as(usize, @intFromFloat(height / r.char_height));
    if (visible_lines == 0) return false;

    const scan = widget.editor.advanceMaxLineWidthCache(64);
    const max_visible_width = scan.max;
    if (max_visible_width <= cols) return false;

    const show_vscroll = widget.editor.lineCount() > visible_lines;
    const scale = r.uiScaleFactor();
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

    const mouse_down = r.isMouseButtonDown(app_shell.MOUSE_LEFT);
    const mouse_pressed = r.isMouseButtonPressed(app_shell.MOUSE_LEFT);
    const mouse_released = r.isMouseButtonReleased(app_shell.MOUSE_LEFT);
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
) bool {
    const r = shell.rendererPtr();
    if (widget.wrap_enabled) return false;
    if (width <= 0 or height <= 0) return false;
    const visible_lines = @as(usize, @intFromFloat(height / r.char_height));
    if (visible_lines == 0) return false;
    const total_lines = widget.editor.lineCount();
    if (total_lines <= visible_lines) return false;

    const scale = r.uiScaleFactor();
    const scrollbar_w: f32 = 16 * scale;
    const scrollbar_x = x + width - scrollbar_w;
    const scrollbar_y = y;
    const scrollbar_h = height;
    const max_scroll = total_lines - visible_lines;
    if (widget.editor.scroll_line > max_scroll) {
        widget.editor.scroll_line = max_scroll;
    }

    const min_thumb_h: f32 = 32 * scale;
    const thumb_h = @max(min_thumb_h, scrollbar_h * (@as(f32, @floatFromInt(visible_lines)) / @as(f32, @floatFromInt(total_lines))));
    const available = @max(@as(f32, 1), scrollbar_h - thumb_h);
    const ratio = if (max_scroll > 0)
        @as(f32, @floatFromInt(widget.editor.scroll_line)) / @as(f32, @floatFromInt(max_scroll))
    else
        0.0;
    const thumb_y = scrollbar_y + available * ratio;

    const over_track = mouse.x >= scrollbar_x and mouse.x <= scrollbar_x + scrollbar_w and mouse.y >= scrollbar_y and mouse.y <= scrollbar_y + scrollbar_h;
    const over_thumb = mouse.x >= scrollbar_x and mouse.x <= scrollbar_x + scrollbar_w and mouse.y >= thumb_y and mouse.y <= thumb_y + thumb_h;

    const mouse_down = r.isMouseButtonDown(app_shell.MOUSE_LEFT);
    const mouse_pressed = r.isMouseButtonPressed(app_shell.MOUSE_LEFT);
    const mouse_released = r.isMouseButtonReleased(app_shell.MOUSE_LEFT);
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
        grab_offset.* = if (over_thumb) mouse.y - thumb_y else thumb_h * 0.5;
        scroll_mod.updateVerticalScrollFromMouse(widget.editor, mouse.y, scrollbar_y, available, grab_offset.*, max_scroll);
        return true;
    }

    if (dragging.* and mouse_down) {
        scroll_mod.updateVerticalScrollFromMouse(widget.editor, mouse.y, scrollbar_y, available, grab_offset.*, max_scroll);
        return true;
    }

    return false;
}

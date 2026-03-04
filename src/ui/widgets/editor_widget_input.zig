const app_shell = @import("../../app_shell.zig");
const scroll_mod = @import("../../editor/view/scroll.zig");
const app_logger = @import("../../app_logger.zig");
const shared_types = @import("../../types/mod.zig");
const common = @import("common.zig");
const scrollbar_mod = @import("editor_scrollbar.zig");

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
    const plain_text_input = !input_batch.mods.ctrl and !input_batch.mods.alt and !input_batch.mods.super;
    const plain_nav_input = plain_text_input and !input_batch.mods.shift;

    // Character input
    for (input_batch.events.items) |event| {
        if (event == .text) {
            const char = event.text.codepoint;
            if (plain_text_input and char >= 32 and char < 127) {
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
    if (plain_text_input and input_batch.keyPressed(.enter)) {
        try widget.editor.insertNewline();
        handled = true;
        app_logger.logger("editor.input").logf("key=enter", .{});
    } else if (plain_text_input and (input_batch.keyPressed(.backspace) or input_batch.keyRepeated(.backspace))) {
        try widget.editor.deleteCharBackward();
        handled = true;
        app_logger.logger("editor.input").logf("key=backspace", .{});
    } else if (plain_text_input and (input_batch.keyPressed(.delete) or input_batch.keyRepeated(.delete))) {
        try widget.editor.deleteCharForward();
        handled = true;
        app_logger.logger("editor.input").logf("key=delete", .{});
    } else if (plain_nav_input and (input_batch.keyPressed(.up) or input_batch.keyRepeated(.up))) {
        if (widget.moveCursorVisual(shell, -1)) {
            widget.ensureCursorVisible(shell, height);
            handled = true;
            app_logger.logger("editor.input").logf("key=up", .{});
        }
    } else if (plain_nav_input and (input_batch.keyPressed(.down) or input_batch.keyRepeated(.down))) {
        if (widget.moveCursorVisual(shell, 1)) {
            widget.ensureCursorVisible(shell, height);
            handled = true;
            app_logger.logger("editor.input").logf("key=down", .{});
        }
    } else if (plain_nav_input and (input_batch.keyPressed(.left) or input_batch.keyRepeated(.left))) {
        widget.editor.moveCursorLeft();
        widget.ensureCursorVisible(shell, height);
        handled = true;
        app_logger.logger("editor.input").logf("key=left", .{});
    } else if (plain_nav_input and (input_batch.keyPressed(.right) or input_batch.keyRepeated(.right))) {
        widget.editor.moveCursorRight();
        widget.ensureCursorVisible(shell, height);
        handled = true;
        app_logger.logger("editor.input").logf("key=right", .{});
    } else if (plain_nav_input and (input_batch.keyPressed(.home) or input_batch.keyRepeated(.home))) {
        widget.editor.moveCursorToLineStart();
        widget.ensureCursorVisible(shell, height);
        handled = true;
        app_logger.logger("editor.input").logf("key=home", .{});
    } else if (plain_nav_input and (input_batch.keyPressed(.end) or input_batch.keyRepeated(.end))) {
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

    const max_visible_width = widget.editor.maxLineWidthCached();
    if (max_visible_width <= cols) return false;

    const h = scrollbar_mod.computeHorizontal(
        shell.uiScaleFactor(),
        widget.gutter_width,
        x,
        y,
        width,
        height,
        mouse,
        max_visible_width,
        cols,
        widget.editor.lineCount(),
        visible_lines,
        widget.editor.scroll_col,
        dragging.*,
    );
    if (!h.visible) return false;
    if (widget.editor.scroll_col > h.max_scroll) {
        widget.editor.scroll_col = h.max_scroll;
    }

    const over_track = common.pointInRect(mouse.x, mouse.y, h.track_x, h.track_y - h.hit_margin, h.track_w, h.track_h + h.hit_margin);
    const over_thumb = common.pointInRect(mouse.x, mouse.y, h.thumb_x, h.track_y - h.hit_margin, h.thumb_w, h.track_h + h.hit_margin);

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
        grab_offset.* = if (over_thumb) mouse.x - h.thumb_x else h.thumb_w * 0.5;
        scroll_mod.updateHorizontalScrollFromMouse(widget.editor, mouse.x, h.track_x, h.available, grab_offset.*, h.max_scroll);
        return true;
    }

    if (dragging.* and mouse_down) {
        scroll_mod.updateHorizontalScrollFromMouse(widget.editor, mouse.x, h.track_x, h.available, grab_offset.*, h.max_scroll);
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

    const v = scrollbar_mod.computeVertical(
        shell.uiScaleFactor(),
        x,
        y,
        width,
        height,
        mouse,
        visible_lines,
        total_lines,
        widget.editor.scroll_line,
        dragging.*,
    );
    if (!v.visible) return false;
    if (widget.editor.scroll_line > v.max_scroll) {
        widget.editor.scroll_line = v.max_scroll;
    }

    const over_track = common.pointInRect(mouse.x, mouse.y, v.scrollbar_x - v.hit_margin, v.scrollbar_y, v.scrollbar_w + v.hit_margin, v.scrollbar_h);
    const over_thumb = common.pointInRect(mouse.x, mouse.y, v.scrollbar_x - v.hit_margin, v.thumb.thumb_y, v.scrollbar_w + v.hit_margin, v.thumb.thumb_h);

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
        grab_offset.* = if (over_thumb) mouse.y - v.thumb.thumb_y else v.thumb.thumb_h * 0.5;
        scroll_mod.updateVerticalScrollFromMouse(widget.editor, mouse.y, v.scrollbar_y, v.thumb.available, grab_offset.*, v.max_scroll);
        return true;
    }

    if (dragging.* and mouse_down) {
        scroll_mod.updateVerticalScrollFromMouse(widget.editor, mouse.y, v.scrollbar_y, v.thumb.available, grab_offset.*, v.max_scroll);
        return true;
    }

    return false;
}

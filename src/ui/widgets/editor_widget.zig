const std = @import("std");
const renderer_mod = @import("../renderer.zig");
const editor_mod = @import("../../editor/editor.zig");
const syntax_mod = @import("../../editor/syntax.zig");
const types = @import("../../editor/types.zig");
const app_logger = @import("../../app_logger.zig");

const Renderer = renderer_mod.Renderer;
const Color = renderer_mod.Color;
const Editor = editor_mod.Editor;
const HighlightToken = syntax_mod.HighlightToken;
const TokenKind = syntax_mod.TokenKind;

/// Editor widget for drawing a text editor view
pub const EditorWidget = struct {
    editor: *Editor,
    gutter_width: f32,
    scroll_x: f32,
    scroll_y: f32,

    pub fn init(editor: *Editor) EditorWidget {
        return .{
            .editor = editor,
            .gutter_width = 50,
            .scroll_x = 0,
            .scroll_y = 0,
        };
    }

    pub fn draw(self: *EditorWidget, r: *Renderer, x: f32, y: f32, width: f32, height: f32) void {
        self.gutter_width = 50 * r.uiScaleFactor();
        const visible_lines = @as(usize, @intFromFloat(height / r.char_height));
        const start_line = self.editor.scroll_line;
        const end_line = @min(start_line + visible_lines + 1, self.editor.lineCount());
        const total_lines = self.editor.lineCount();

        var highlight_tokens: []HighlightToken = &[_]HighlightToken{};
        var highlight_tokens_allocated = false;
        self.editor.ensureHighlighter();
        if (self.editor.highlighter) |highlighter| {
            if (total_lines > 0 and start_line < total_lines) {
                const range_start = self.editor.lineStart(start_line);
                const range_end = if (end_line < total_lines) self.editor.lineStart(end_line) else self.editor.totalLen();
                const log = app_logger.logger("editor.highlight");
                log.logf(
                    "highlight batch start lines={d}-{d} bytes={d}-{d}",
                    .{ start_line, end_line, range_start, range_end },
                );
                const t_start = std.time.nanoTimestamp();
                const tokens_opt: ?[]HighlightToken = highlighter.highlightRange(range_start, range_end, self.editor.allocator) catch null;
                const elapsed_ns = std.time.nanoTimestamp() - t_start;
                if (tokens_opt) |tokens| {
                    highlight_tokens = tokens;
                    highlight_tokens_allocated = true;
                    if (highlight_tokens.len > 1) {
                        std.sort.heap(HighlightToken, highlight_tokens, {}, highlightTokenLessThan);
                    }
                }
                log.logf(
                    "highlight batch lines={d}-{d} bytes={d}-{d} tokens={d} time_us={d}",
                    .{
                        start_line,
                        end_line,
                        range_start,
                        range_end,
                        highlight_tokens.len,
                        @as(i64, @intCast(@divTrunc(elapsed_ns, 1000))),
                    },
                );
            }
        }
        defer if (highlight_tokens_allocated) self.editor.allocator.free(highlight_tokens);

        // Draw gutter background
        r.drawRect(
            @intFromFloat(x),
            @intFromFloat(y),
            @intFromFloat(self.gutter_width),
            @intFromFloat(height),
            r.theme.line_number_bg,
        );

        // Draw lines
        var line_buf: [4096]u8 = undefined;
        var line_idx = start_line;
        var token_idx: usize = 0;
        const text_start_x = x + self.gutter_width + 8 * r.uiScaleFactor();
        while (line_idx < end_line) : (line_idx += 1) {
            const line_y = y + @as(f32, @floatFromInt(line_idx - start_line)) * r.char_height;
            const is_current = line_idx == self.editor.cursor.line;

            const len = self.editor.getLine(line_idx, &line_buf);
            const line_text = line_buf[0..len];
            const line_start = self.editor.lineStart(line_idx);
            const line_end = line_start + len;
            const line_len = len;

            if (highlight_tokens_allocated) {
                while (token_idx < highlight_tokens.len and highlight_tokens[token_idx].end <= line_start) {
                    token_idx += 1;
                }
                var line_token_end = token_idx;
                while (line_token_end < highlight_tokens.len and highlight_tokens[line_token_end].start < line_end) {
                    line_token_end += 1;
                }
                const tokens = highlight_tokens[token_idx..line_token_end];
                r.drawEditorLineBase(line_idx, line_y, x, self.gutter_width, width, is_current);
                var ranges: [8]SelectionRange = undefined;
                var range_count: usize = 0;
                collectSelectionRanges(self.editor, line_idx, line_len, &ranges, &range_count);
                if (range_count > 0) {
                    var i: usize = 0;
                    while (i < range_count) : (i += 1) {
                        const range = ranges[i];
                        const sel_x = text_start_x + @as(f32, @floatFromInt(range.start_col)) * r.char_width;
                        const sel_w = @as(f32, @floatFromInt(range.end_col - range.start_col)) * r.char_width;
                        r.drawRect(
                            @intFromFloat(sel_x),
                            @intFromFloat(line_y),
                            @intFromFloat(sel_w),
                            @intFromFloat(r.char_height),
                            r.theme.selection,
                        );
                    }
                }
                if (tokens.len == 0) {
                    r.drawText(line_text, text_start_x, line_y, r.theme.foreground);
                } else {
                    drawHighlightedLineText(
                        r,
                        line_text,
                        line_y,
                        text_start_x,
                        line_start,
                        line_end,
                        tokens,
                    );
                }
            } else {
                r.drawEditorLineBase(line_idx, line_y, x, self.gutter_width, width, is_current);
                var ranges: [8]SelectionRange = undefined;
                var range_count: usize = 0;
                collectSelectionRanges(self.editor, line_idx, line_len, &ranges, &range_count);
                if (range_count > 0) {
                    var i: usize = 0;
                    while (i < range_count) : (i += 1) {
                        const range = ranges[i];
                        const sel_x = text_start_x + @as(f32, @floatFromInt(range.start_col)) * r.char_width;
                        const sel_w = @as(f32, @floatFromInt(range.end_col - range.start_col)) * r.char_width;
                        r.drawRect(
                            @intFromFloat(sel_x),
                            @intFromFloat(line_y),
                            @intFromFloat(sel_w),
                            @intFromFloat(r.char_height),
                            r.theme.selection,
                        );
                    }
                }
                r.drawText(line_text, text_start_x, line_y, r.theme.foreground);
            }
        }

        // Draw cursor
        if (self.editor.cursor.line >= start_line and self.editor.cursor.line < end_line) {
            const cursor_x = x + self.gutter_width + 8 * r.uiScaleFactor() + @as(f32, @floatFromInt(self.editor.cursor.col)) * r.char_width;
            const cursor_y = y + @as(f32, @floatFromInt(self.editor.cursor.line - start_line)) * r.char_height;
            r.drawCursor(cursor_x, cursor_y, .line);
        }
    }

    pub fn handleMouseClick(
        self: *EditorWidget,
        r: *Renderer,
        x: f32,
        y: f32,
        width: f32,
        height: f32,
        mouse_x: f32,
        mouse_y: f32,
    ) bool {
        if (self.cursorFromMouse(r, x, y, width, height, mouse_x, mouse_y, false)) |pos| {
            self.editor.setCursor(pos.line, pos.col);
            const log = app_logger.logger("editor.input");
            log.logf("mouse click line={d} col={d}", .{ pos.line, pos.col });
            return true;
        }
        return false;
    }

    pub fn cursorFromMouse(
        self: *EditorWidget,
        r: *Renderer,
        x: f32,
        y: f32,
        width: f32,
        height: f32,
        mouse_x: f32,
        mouse_y: f32,
        clamp: bool,
    ) ?types.CursorPos {
        self.gutter_width = 50 * r.uiScaleFactor();
        if (width <= 0 or height <= 0) return null;
        if (self.editor.lineCount() == 0) return null;
        var local_x = mouse_x;
        var local_y = mouse_y;
        if (clamp) {
            local_x = @min(@max(mouse_x, x), x + width);
            local_y = @min(@max(mouse_y, y), y + height);
        } else {
            if (mouse_x < x or mouse_x > x + width) return null;
            if (mouse_y < y or mouse_y > y + height) return null;
        }
        const line_offset = @as(usize, @intFromFloat((local_y - y) / r.char_height));
        const max_line = self.editor.lineCount() - 1;
        const line = @min(self.editor.scroll_line + line_offset, max_line);

        const text_start_x = x + self.gutter_width + 8 * r.uiScaleFactor();
        var col: usize = 0;
        if (local_x > text_start_x) {
            col = @as(usize, @intFromFloat((local_x - text_start_x) / r.char_width));
        }
        const line_len = self.editor.lineLen(line);
        const clamped_col = @min(col, line_len);
        const line_start = self.editor.lineStart(line);
        return .{
            .line = line,
            .col = clamped_col,
            .offset = line_start + clamped_col,
        };
    }

    /// Handle input, returns true if any input was processed
    pub fn handleInput(self: *EditorWidget, r: *Renderer) !bool {
        var handled = false;
        var chars_inserted: usize = 0;
        var group_started = false;
        errdefer if (group_started) self.editor.endUndoGroup() catch {};

        // Character input
        while (r.getCharPressed()) |char| {
            if (char >= 32 and char < 127) {
                if (!group_started) {
                    self.editor.beginUndoGroup();
                    group_started = true;
                }
                try self.editor.insertChar(@intCast(char));
                handled = true;
                chars_inserted += 1;
            }
        }
        if (chars_inserted > 0) {
            const log = app_logger.logger("editor.input");
            log.logf("chars inserted={d}", .{chars_inserted});
        }

        // Control keys
        const ctrl = r.isKeyDown(renderer_mod.KEY_LEFT_CONTROL) or r.isKeyDown(renderer_mod.KEY_RIGHT_CONTROL);

        if (r.isKeyPressed(renderer_mod.KEY_ENTER)) {
            if (!group_started) {
                self.editor.beginUndoGroup();
                group_started = true;
            }
            try self.editor.insertNewline();
            handled = true;
            app_logger.logger("editor.input").logf("key=enter", .{});
        } else if (r.isKeyRepeated(renderer_mod.KEY_BACKSPACE)) {
            if (!group_started) {
                self.editor.beginUndoGroup();
                group_started = true;
            }
            try self.editor.deleteCharBackward();
            handled = true;
            app_logger.logger("editor.input").logf("key=backspace", .{});
        } else if (r.isKeyRepeated(renderer_mod.KEY_DELETE)) {
            if (!group_started) {
                self.editor.beginUndoGroup();
                group_started = true;
            }
            try self.editor.deleteCharForward();
            handled = true;
            app_logger.logger("editor.input").logf("key=delete", .{});
        } else if (r.isKeyRepeated(renderer_mod.KEY_UP)) {
            self.editor.moveCursorUp();
            handled = true;
            app_logger.logger("editor.input").logf("key=up", .{});
        } else if (r.isKeyRepeated(renderer_mod.KEY_DOWN)) {
            self.editor.moveCursorDown();
            handled = true;
            app_logger.logger("editor.input").logf("key=down", .{});
        } else if (r.isKeyRepeated(renderer_mod.KEY_LEFT)) {
            self.editor.moveCursorLeft();
            handled = true;
            app_logger.logger("editor.input").logf("key=left", .{});
        } else if (r.isKeyRepeated(renderer_mod.KEY_RIGHT)) {
            self.editor.moveCursorRight();
            handled = true;
            app_logger.logger("editor.input").logf("key=right", .{});
        } else if (r.isKeyRepeated(renderer_mod.KEY_HOME)) {
            self.editor.moveCursorToLineStart();
            handled = true;
            app_logger.logger("editor.input").logf("key=home", .{});
        } else if (r.isKeyRepeated(renderer_mod.KEY_END)) {
            self.editor.moveCursorToLineEnd();
            handled = true;
            app_logger.logger("editor.input").logf("key=end", .{});
        } else if (ctrl and r.isKeyPressed(renderer_mod.KEY_S)) {
            try self.editor.save();
            handled = true;
            app_logger.logger("editor.input").logf("key=ctrl+s", .{});
        } else if (ctrl and r.isKeyPressed(renderer_mod.KEY_Z)) {
            _ = try self.editor.undo();
            handled = true;
            app_logger.logger("editor.input").logf("key=ctrl+z", .{});
        } else if (ctrl and r.isKeyPressed(renderer_mod.KEY_Y)) {
            _ = try self.editor.redo();
            handled = true;
            app_logger.logger("editor.input").logf("key=ctrl+y", .{});
        }

        if (group_started) {
            try self.editor.endUndoGroup();
        }

        // Scroll handling
        const wheel = r.getMouseWheelMove();
        if (wheel != 0) {
            const delta = @as(i32, @intFromFloat(-wheel * 3));
            const new_scroll = @as(i64, @intCast(self.editor.scroll_line)) + delta;
            self.editor.scroll_line = @intCast(@max(0, @min(new_scroll, @as(i64, @intCast(self.editor.lineCount())))));
            handled = true;
            app_logger.logger("editor.input").logf("scroll delta={d} new_line={d}", .{ delta, self.editor.scroll_line });
        }

        return handled;
    }
};

fn drawHighlightedLineText(
    r: *Renderer,
    line_text: []const u8,
    y: f32,
    text_x: f32,
    line_start: usize,
    line_end: usize,
    tokens: []HighlightToken,
) void {
    if (line_text.len == 0) return;
    if (tokens.len == 0) return;

    var cursor = line_start;
    for (tokens) |token| {
        if (token.end <= line_start or token.start >= line_end) continue;
        const start = @max(token.start, line_start);
        const end = @min(token.end, line_end);
        if (start > cursor) {
            const slice_start = cursor - line_start;
            const slice_end = start - line_start;
            const x = text_x + @as(f32, @floatFromInt(slice_start)) * r.char_width;
            r.drawText(line_text[slice_start..slice_end], x, y, r.theme.foreground);
        }
        const slice_start = start - line_start;
        const slice_end = end - line_start;
        const x = text_x + @as(f32, @floatFromInt(slice_start)) * r.char_width;
        r.drawText(line_text[slice_start..slice_end], x, y, colorForToken(r, token.kind));
        cursor = end;
    }

    if (cursor < line_end) {
        const slice_start = cursor - line_start;
        const x = text_x + @as(f32, @floatFromInt(slice_start)) * r.char_width;
        r.drawText(line_text[slice_start..], x, y, r.theme.foreground);
    }
}

const SelectionRange = struct {
    start_col: usize,
    end_col: usize,
};

fn addSelectionRange(ranges: *[8]SelectionRange, count: *usize, start_col: usize, end_col: usize) void {
    if (end_col <= start_col) return;
    if (count.* >= ranges.len) return;
    ranges[count.*] = .{ .start_col = start_col, .end_col = end_col };
    count.* += 1;
}

fn collectSelectionRanges(
    editor: *Editor,
    line_idx: usize,
    line_len: usize,
    ranges: *[8]SelectionRange,
    count: *usize,
) void {
    if (line_len == 0) {
        if (editor.selection) |sel| {
            const norm = sel.normalized();
            if (!norm.isEmpty() and line_idx >= norm.start.line and line_idx <= norm.end.line) {
                addSelectionRange(ranges, count, 0, 1);
            }
        }
        for (editor.selections.items) |sel| {
            const norm = sel.normalized();
            if (norm.isEmpty()) continue;
            if (line_idx < norm.start.line or line_idx > norm.end.line) continue;
            addSelectionRange(ranges, count, 0, 1);
        }
        return;
    }
    if (editor.selection) |sel| {
        const norm = sel.normalized();
        if (line_idx >= norm.start.line and line_idx <= norm.end.line) {
            var start_col: usize = 0;
            var end_col: usize = line_len;
            if (line_idx == norm.start.line) start_col = @min(norm.start.col, line_len);
            if (line_idx == norm.end.line) end_col = @min(norm.end.col, line_len);
            addSelectionRange(ranges, count, start_col, end_col);
        }
    }
    for (editor.selections.items) |sel| {
        const norm = sel.normalized();
        if (line_idx < norm.start.line or line_idx > norm.end.line) continue;
        var start_col: usize = 0;
        var end_col: usize = line_len;
        if (line_idx == norm.start.line) start_col = @min(norm.start.col, line_len);
        if (line_idx == norm.end.line) end_col = @min(norm.end.col, line_len);
        addSelectionRange(ranges, count, start_col, end_col);
    }
}

fn highlightTokenLessThan(_: void, a: HighlightToken, b: HighlightToken) bool {
    if (a.start == b.start) return a.end < b.end;
    return a.start < b.start;
}

fn colorForToken(r: *Renderer, kind: TokenKind) Color {
    return switch (kind) {
        .comment => r.theme.comment_color,
        .string => r.theme.string,
        .keyword => r.theme.keyword,
        .number => r.theme.number,
        .function => r.theme.function,
        .variable => r.theme.variable,
        .type_name => r.theme.type_name,
        .operator => r.theme.operator,
        .builtin => r.theme.builtin_color,
        .punctuation => r.theme.punctuation,
        .constant => r.theme.constant,
        .attribute => r.theme.attribute,
        .namespace => r.theme.namespace,
        .label => r.theme.label,
        .error_token => r.theme.error_token,
        else => r.theme.foreground,
    };
}

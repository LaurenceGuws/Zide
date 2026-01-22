const std = @import("std");
const renderer_mod = @import("../renderer.zig");
const editor_mod = @import("../../editor/editor.zig");
const syntax_mod = @import("../../editor/syntax.zig");
const types = @import("../../editor/types.zig");
const app_logger = @import("../../app_logger.zig");

const hb = @import("../terminal_font.zig").c;

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
    cluster_cache: ?*ClusterCache,
    wrap_enabled: bool,

    pub fn init(editor: *Editor, wrap_enabled: bool) EditorWidget {
        return .{
            .editor = editor,
            .gutter_width = 50,
            .scroll_x = 0,
            .scroll_y = 0,
            .cluster_cache = null,
            .wrap_enabled = wrap_enabled,
        };
    }

    pub fn initWithCache(editor: *Editor, cache: *ClusterCache, wrap_enabled: bool) EditorWidget {
        var widget = init(editor, wrap_enabled);
        widget.cluster_cache = cache;
        return widget;
    }

    pub fn draw(self: *EditorWidget, r: *Renderer, x: f32, y: f32, width: f32, height: f32) void {
        self.gutter_width = 50 * r.uiScaleFactor();
        const visible_lines = @as(usize, @intFromFloat(height / r.char_height));
        const start_line = self.editor.scroll_line;
        const start_seg = self.editor.scroll_row_offset;
        const total_lines = self.editor.lineCount();
        const end_line = @min(start_line + visible_lines + 1, total_lines);
        var cursor_draw_x: ?f32 = null;
        var cursor_draw_y: ?f32 = null;

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
        var visual_row: usize = 0;
        var token_idx: usize = 0;
        const text_start_x = x + self.gutter_width + 8 * r.uiScaleFactor();
        while (line_idx < total_lines and visual_row < visible_lines) : (line_idx += 1) {
            const is_current = line_idx == self.editor.cursor.line;

            const line_len = self.editor.lineLen(line_idx);
            var line_alloc: ?[]u8 = null;
            const line_text = if (line_len <= line_buf.len)
                line_buf[0..self.editor.getLine(line_idx, &line_buf)]
            else blk: {
                const owned = self.editor.getLineAlloc(line_idx) catch break :blk &[_]u8{};
                line_alloc = owned;
                break :blk owned;
            };
            defer if (line_alloc) |owned| self.editor.allocator.free(owned);
            const line_start = self.editor.lineStart(line_idx);
            const line_end = line_start + line_len;

            const cluster_result = getClusterOffsets(
                self.cluster_cache,
                self.editor.allocator,
                r.terminal_font.hb_font,
                line_idx,
                line_text,
            );
            defer if (cluster_result.owned) {
                if (cluster_result.slice) |clusters| self.editor.allocator.free(clusters);
            };

            var tokens: []HighlightToken = &[_]HighlightToken{};
            if (highlight_tokens_allocated) {
                while (token_idx < highlight_tokens.len and highlight_tokens[token_idx].end <= line_start) {
                    token_idx += 1;
                }
                var line_token_end = token_idx;
                while (line_token_end < highlight_tokens.len and highlight_tokens[line_token_end].start < line_end) {
                    line_token_end += 1;
                }
                tokens = highlight_tokens[token_idx..line_token_end];
            }

            var ranges: [8]SelectionRange = undefined;
            var range_count: usize = 0;
            collectSelectionRanges(self.editor, line_idx, line_text, cluster_result.slice, &ranges, &range_count);

            const cols = self.viewportColumns(r);
            const width_cached = self.editor.lineWidthCached(line_idx, line_text, cluster_result.slice);
            const line_width = if (line_len == 0) 1 else if (width_cached == 0 and range_count > 0) 1 else width_cached;
            const total_visual_lines = if (self.wrap_enabled) visualLineCountForWidth(cols, line_width) else 1;
            const seg_start_idx = if (self.wrap_enabled and line_idx == start_line) @min(start_seg, total_visual_lines) else 0;

            var cursor_col_vis: usize = 0;
            var cursor_seg: usize = 0;
            if (is_current) {
                cursor_col_vis = visualColumnForByteIndex(line_text, self.editor.cursor.col, cluster_result.slice);
                if (cols > 0 and self.wrap_enabled) {
                    cursor_seg = @min(cursor_col_vis / cols, if (total_visual_lines > 0) total_visual_lines - 1 else 0);
                }
            }

            var seg: usize = seg_start_idx;
            while (seg < total_visual_lines and visual_row < visible_lines) : (seg += 1) {
                const seg_start_col = if (self.wrap_enabled) seg * cols else 0;
                const seg_end_col = if (self.wrap_enabled) @min(line_width, seg_start_col + cols) else @min(line_width, cols);
                if (seg_start_col >= seg_end_col and range_count == 0) continue;
                const seg_y = y + @as(f32, @floatFromInt(visual_row)) * r.char_height;
                const seg_start_byte = byteIndexForVisualColumn(line_text, seg_start_col, cluster_result.slice);
                const seg_end_byte = byteIndexForVisualColumn(line_text, seg_end_col, cluster_result.slice);

                if (seg == seg_start_idx) {
                    r.drawEditorLineBase(line_idx, seg_y, x, self.gutter_width, width, is_current);
                } else if (is_current) {
                    r.drawRect(
                        @intFromFloat(x),
                        @intFromFloat(seg_y),
                        @intFromFloat(self.gutter_width),
                        @intFromFloat(r.char_height),
                        r.theme.current_line,
                    );
                    r.drawRect(
                        @intFromFloat(x + self.gutter_width),
                        @intFromFloat(seg_y),
                        @intFromFloat(width - self.gutter_width),
                        @intFromFloat(r.char_height),
                        r.theme.current_line,
                    );
                }

                if (range_count > 0) {
                    var r_i: usize = 0;
                    while (r_i < range_count) : (r_i += 1) {
                        const range = ranges[r_i];
                        const sel_start = @max(range.start_col, seg_start_col);
                        const sel_end = @min(range.end_col, seg_end_col);
                        if (sel_end <= sel_start) continue;
                        const sel_x = text_start_x + @as(f32, @floatFromInt(sel_start - seg_start_col)) * r.char_width;
                        const sel_w = @as(f32, @floatFromInt(sel_end - sel_start)) * r.char_width;
                        r.drawRect(
                            @intFromFloat(sel_x),
                            @intFromFloat(seg_y),
                            @intFromFloat(sel_w),
                            @intFromFloat(r.char_height),
                            r.theme.selection,
                        );
                    }
                }

                if (tokens.len == 0) {
                    r.drawText(line_text[seg_start_byte..seg_end_byte], text_start_x, seg_y, r.theme.foreground);
                } else {
                    drawHighlightedLineSegment(
                        r,
                        line_text,
                        seg_y,
                        text_start_x,
                        line_start,
                        seg_start_byte,
                        seg_end_byte,
                        tokens,
                    );
                }

                if (is_current and seg == cursor_seg) {
                    const local_col = cursor_col_vis - seg_start_col;
                    cursor_draw_x = text_start_x + @as(f32, @floatFromInt(local_col)) * r.char_width;
                    cursor_draw_y = seg_y;
                }
                visual_row += 1;
            }
        }

        // Draw cursor
        if (cursor_draw_x != null and cursor_draw_y != null) {
            r.drawCursor(cursor_draw_x.?, cursor_draw_y.?, .line);
        }
    }

    fn viewportColumns(self: *EditorWidget, r: *Renderer) usize {
        const editor_width = @max(0, r.width - @as(i32, @intFromFloat(self.gutter_width)));
        if (r.char_width <= 0) return 0;
        return @as(usize, @intFromFloat(@as(f32, @floatFromInt(editor_width)) / r.char_width));
    }

    fn visualLinesForLine(self: *EditorWidget, r: *Renderer, line_idx: usize, cols: usize) usize {
        if (!self.wrap_enabled) return 1;
        var line_buf: [4096]u8 = undefined;
        const line_len = self.editor.lineLen(line_idx);
        var line_alloc: ?[]u8 = null;
        const line_text = if (line_len <= line_buf.len)
            line_buf[0..self.editor.getLine(line_idx, &line_buf)]
        else blk: {
            const owned = self.editor.getLineAlloc(line_idx) catch break :blk &[_]u8{};
            line_alloc = owned;
            break :blk owned;
        };
        defer if (line_alloc) |owned| self.editor.allocator.free(owned);

        const cluster_result = getClusterOffsets(
            self.cluster_cache,
            self.editor.allocator,
            r.terminal_font.hb_font,
            line_idx,
            line_text,
        );
        defer if (cluster_result.owned) {
            if (cluster_result.slice) |clusters| self.editor.allocator.free(clusters);
        };

        const width_cached = self.editor.lineWidthCached(line_idx, line_text, cluster_result.slice);
        const line_width = if (line_len == 0) 1 else width_cached;
        return visualLineCountForWidth(cols, line_width);
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
        const line = self.lineForVisualRow(r, line_offset) orelse return null;

        const text_start_x = x + self.gutter_width + 8 * r.uiScaleFactor();
        var col: usize = 0;
        if (local_x > text_start_x) {
            col = @as(usize, @intFromFloat((local_x - text_start_x) / r.char_width));
        }
        const line_len = self.editor.lineLen(line.line_idx);
        var byte_col = col;
        var line_buf: [4096]u8 = undefined;
        if (line_len <= line_buf.len) {
            const len = self.editor.getLine(line.line_idx, &line_buf);
            const line_text = line_buf[0..len];
            const cluster_result = getClusterOffsets(
                self.cluster_cache,
                self.editor.allocator,
                r.terminal_font.hb_font,
                line.line_idx,
                line_text,
            );
            defer if (cluster_result.owned) {
                if (cluster_result.slice) |clusters| self.editor.allocator.free(clusters);
            };
            const seg_start_col = line.seg_idx * line.cols;
            byte_col = byteIndexForVisualColumn(line_text, seg_start_col + col, cluster_result.slice);
        } else {
            if (self.editor.getLineAlloc(line.line_idx)) |owned| {
                defer self.editor.allocator.free(owned);
                const cluster_result = getClusterOffsets(
                    self.cluster_cache,
                    self.editor.allocator,
                    r.terminal_font.hb_font,
                    line.line_idx,
                    owned,
                );
                defer if (cluster_result.owned) {
                    if (cluster_result.slice) |clusters| self.editor.allocator.free(clusters);
                };
                const seg_start_col = line.seg_idx * line.cols;
                byte_col = byteIndexForVisualColumn(owned, seg_start_col + col, cluster_result.slice);
            } else |_| {}
        }
        const clamped_col = @min(byte_col, line_len);
        const line_start = self.editor.lineStart(line.line_idx);
        return .{
            .line = line.line_idx,
            .col = clamped_col,
            .offset = line_start + clamped_col,
        };
    }

    const VisualLinePos = struct {
        line_idx: usize,
        seg_idx: usize,
        cols: usize,
    };

    fn lineForVisualRow(self: *EditorWidget, r: *Renderer, visual_row: usize) ?VisualLinePos {
        const line_count = self.editor.lineCount();
        if (line_count == 0) return null;
        const cols = self.viewportColumns(r);
        if (cols == 0) return null;
        if (!self.wrap_enabled) {
            const line = self.editor.scroll_line + visual_row;
            if (line >= line_count) return null;
            return .{ .line_idx = line, .seg_idx = 0, .cols = cols };
        }

        var line = self.editor.scroll_line;
        var seg = self.editor.scroll_row_offset;
        if (line >= line_count) {
            line = line_count - 1;
            seg = 0;
        }

        var remaining = visual_row;
        while (line < line_count) {
            const lines = self.visualLinesForLine(r, line, cols);
            const available = if (lines > seg) lines - seg else 0;
            if (remaining < available) {
                return .{ .line_idx = line, .seg_idx = seg + remaining, .cols = cols };
            }
            remaining -= available;
            line += 1;
            seg = 0;
        }
        return null;
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
            if (self.moveCursorVisual(r, -1)) {
                handled = true;
                app_logger.logger("editor.input").logf("key=up", .{});
            }
        } else if (r.isKeyRepeated(renderer_mod.KEY_DOWN)) {
            if (self.moveCursorVisual(r, 1)) {
                handled = true;
                app_logger.logger("editor.input").logf("key=down", .{});
            }
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
            self.scrollVisual(r, delta);
            handled = true;
            app_logger.logger("editor.input").logf("scroll delta={d} new_line={d} row_offset={d}", .{ delta, self.editor.scroll_line, self.editor.scroll_row_offset });
        }

        return handled;
    }

    fn scrollVisual(self: *EditorWidget, r: *Renderer, delta_rows: i32) void {
        if (delta_rows == 0) return;
        const line_count = self.editor.lineCount();
        if (line_count == 0) return;
        const cols = self.viewportColumns(r);
        if (cols == 0) return;
        if (!self.wrap_enabled) {
            if (delta_rows > 0) {
                self.editor.scroll_line = @min(self.editor.scroll_line + @as(usize, @intCast(delta_rows)), line_count - 1);
            } else {
                const delta_abs: usize = @intCast(-delta_rows);
                self.editor.scroll_line = if (self.editor.scroll_line > delta_abs) self.editor.scroll_line - delta_abs else 0;
            }
            self.editor.scroll_row_offset = 0;
            return;
        }

        var line = self.editor.scroll_line;
        var seg = self.editor.scroll_row_offset;
        if (line >= line_count) {
            line = line_count - 1;
            seg = 0;
        }

        if (delta_rows > 0) {
            var remaining: usize = @intCast(delta_rows);
            while (remaining > 0 and line < line_count) {
                const lines = self.visualLinesForLine(r, line, cols);
                const available = if (lines > seg) lines - seg else 0;
                if (remaining < available) {
                    seg += remaining;
                    remaining = 0;
                    break;
                }
                remaining -= available;
                if (line + 1 >= line_count) {
                    seg = 0;
                    break;
                }
                line += 1;
                seg = 0;
            }
        } else {
            var remaining: usize = @intCast(-delta_rows);
            while (remaining > 0) {
                if (line == 0 and seg == 0) break;
                if (seg >= remaining) {
                    seg -= remaining;
                    remaining = 0;
                    break;
                }
                remaining -= seg;
                if (line == 0) {
                    seg = 0;
                    break;
                }
                line -= 1;
                const lines = self.visualLinesForLine(r, line, cols);
                seg = if (lines > 0) lines - 1 else 0;
                if (remaining > 0) {
                    remaining -= 1;
                }
            }
        }

        self.editor.scroll_line = line;
        self.editor.scroll_row_offset = seg;
    }

    fn moveCursorVisual(self: *EditorWidget, r: *Renderer, delta: i32) bool {
        if (!self.wrap_enabled) {
            const before = self.editor.cursor.line;
            if (delta < 0) {
                self.editor.moveCursorUp();
            } else {
                self.editor.moveCursorDown();
            }
            return self.editor.cursor.line != before;
        }
        const line_count = self.editor.lineCount();
        if (line_count == 0) return false;
        const cols = self.viewportColumns(r);
        if (cols == 0) return false;

        var cur_line = self.editor.cursor.line;
        var cur_col_byte = self.editor.cursor.col;
        if (cur_line >= line_count) {
            cur_line = line_count - 1;
            cur_col_byte = self.editor.lineLen(cur_line);
        }

        var line_buf: [4096]u8 = undefined;
        var line_alloc: ?[]u8 = null;
        const line_len = self.editor.lineLen(cur_line);
        const line_text = if (line_len <= line_buf.len)
            line_buf[0..self.editor.getLine(cur_line, &line_buf)]
        else blk: {
            const owned = self.editor.getLineAlloc(cur_line) catch break :blk &[_]u8{};
            line_alloc = owned;
            break :blk owned;
        };
        defer if (line_alloc) |owned| self.editor.allocator.free(owned);

        const cluster_result = getClusterOffsets(
            self.cluster_cache,
            self.editor.allocator,
            r.terminal_font.hb_font,
            cur_line,
            line_text,
        );
        defer if (cluster_result.owned) {
            if (cluster_result.slice) |clusters| self.editor.allocator.free(clusters);
        };

        const cur_vis_col = visualColumnForByteIndex(line_text, cur_col_byte, cluster_result.slice);
        const preferred_vis_col = self.editor.preferred_visual_col orelse cur_vis_col;
        if (self.editor.preferred_visual_col == null) {
            self.editor.preferred_visual_col = preferred_vis_col;
        }
        const cur_line_width = self.editor.lineWidthCached(cur_line, line_text, cluster_result.slice);
        const cur_visual_lines = visualLineCountForWidth(cols, cur_line_width);
        const cur_seg = if (cur_visual_lines == 0) 0 else @min(cur_vis_col / cols, cur_visual_lines - 1);
        const cur_seg_col = cur_vis_col - cur_seg * cols;

        var target_line = cur_line;
        var target_seg: usize = cur_seg;
        var target_use_preferred = false;
        if (delta < 0) {
            if (cur_seg > 0) {
                target_seg = cur_seg - 1;
            } else if (cur_line > 0) {
                target_line = cur_line - 1;
                target_use_preferred = true;
            } else {
                return false;
            }
        } else {
            if (cur_seg + 1 < cur_visual_lines) {
                target_seg = cur_seg + 1;
            } else if (cur_line + 1 < line_count) {
                target_line = cur_line + 1;
                target_use_preferred = true;
            } else {
                return false;
            }
        }

        var target_text = line_text;
        var target_alloc: ?[]u8 = null;
        var target_clusters = cluster_result;
        if (target_line != cur_line) {
            var target_line_buf: [4096]u8 = undefined;
            const target_len = self.editor.lineLen(target_line);
            target_text = if (target_len <= target_line_buf.len)
                target_line_buf[0..self.editor.getLine(target_line, &target_line_buf)]
            else blk: {
                const owned = self.editor.getLineAlloc(target_line) catch break :blk &[_]u8{};
                target_alloc = owned;
                break :blk owned;
            };
            defer if (target_alloc) |owned| self.editor.allocator.free(owned);

            target_clusters = getClusterOffsets(
                self.cluster_cache,
                self.editor.allocator,
                r.terminal_font.hb_font,
                target_line,
                target_text,
            );
        }
        defer if (target_line != cur_line and target_clusters.owned) {
            if (target_clusters.slice) |clusters| self.editor.allocator.free(clusters);
        };

        const target_width = self.editor.lineWidthCached(target_line, target_text, target_clusters.slice);
        const target_visual_lines = visualLineCountForWidth(cols, target_width);
        if (target_use_preferred and target_visual_lines > 0) {
            target_seg = @min(preferred_vis_col / cols, target_visual_lines - 1);
        }
        if (target_seg >= target_visual_lines) {
            target_seg = if (target_visual_lines > 0) target_visual_lines - 1 else 0;
        }
        const target_seg_start = target_seg * cols;
        const target_seg_len = if (target_width > target_seg_start) @min(cols, target_width - target_seg_start) else 0;
        const desired_seg_col = if (target_use_preferred)
            @min(preferred_vis_col - target_seg_start, target_seg_len)
        else
            @min(cur_seg_col, target_seg_len);
        const target_col_vis = target_seg_start + desired_seg_col;
        const target_col_byte = byteIndexForVisualColumn(target_text, target_col_vis, target_clusters.slice);

        self.editor.setCursor(target_line, target_col_byte);
        return true;
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

fn drawHighlightedLineSegment(
    r: *Renderer,
    line_text: []const u8,
    y: f32,
    text_x: f32,
    line_start: usize,
    seg_start: usize,
    seg_end: usize,
    tokens: []HighlightToken,
) void {
    if (seg_start >= seg_end or line_text.len == 0) return;

    var cursor = seg_start;
    for (tokens) |token| {
        if (token.end <= line_start + seg_start or token.start >= line_start + seg_end) continue;
        const start = @max(token.start - line_start, seg_start);
        const end = @min(token.end - line_start, seg_end);
        if (start > cursor) {
            const slice_start = cursor;
            const slice_end = start;
            const x = text_x + @as(f32, @floatFromInt(slice_start - seg_start)) * r.char_width;
            r.drawText(line_text[slice_start..slice_end], x, y, r.theme.foreground);
        }
        const slice_start = start;
        const slice_end = end;
        const x = text_x + @as(f32, @floatFromInt(slice_start - seg_start)) * r.char_width;
        r.drawText(line_text[slice_start..slice_end], x, y, colorForToken(r, token.kind));
        cursor = end;
    }

    if (cursor < seg_end) {
        const slice_start = cursor;
        const x = text_x + @as(f32, @floatFromInt(slice_start - seg_start)) * r.char_width;
        r.drawText(line_text[slice_start..seg_end], x, y, r.theme.foreground);
    }
}

fn visualLineCountForWidth(cols: usize, width: usize) usize {
    if (cols == 0) return 1;
    if (width == 0) return 1;
    return @max(@as(usize, 1), (width + cols - 1) / cols);
}

const SelectionRange = struct {
    start_col: usize,
    end_col: usize,
};

pub const ClusterCache = struct {
    allocator: std.mem.Allocator,
    frame_id: u64,
    entries: std.AutoHashMap(usize, []u32),

    pub fn init(allocator: std.mem.Allocator) ClusterCache {
        return .{
            .allocator = allocator,
            .frame_id = 0,
            .entries = std.AutoHashMap(usize, []u32).init(allocator),
        };
    }

    pub fn deinit(self: *ClusterCache) void {
        self.clear();
        self.entries.deinit();
    }

    pub fn beginFrame(self: *ClusterCache, frame_id: u64) void {
        if (self.frame_id == frame_id) return;
        self.clear();
        self.frame_id = frame_id;
    }

    pub fn clear(self: *ClusterCache) void {
        var it = self.entries.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.value_ptr.*);
        }
        self.entries.clearRetainingCapacity();
    }

    pub fn getOrCompute(
        self: *ClusterCache,
        line_idx: usize,
        hb_font: *hb.hb_font_t,
        text: []const u8,
    ) ?[]const u32 {
        if (!hasNonAscii(text)) return null;
        if (self.entries.get(line_idx)) |cached| return cached;
        const clusters = graphemeClusterOffsets(self.allocator, hb_font, text) catch return null;
        self.entries.put(line_idx, clusters) catch {
            self.allocator.free(clusters);
            return null;
        };
        return clusters;
    }
};

const ClusterResult = struct {
    slice: ?[]const u32,
    owned: bool,
};

fn getClusterOffsets(
    cache: ?*ClusterCache,
    allocator: std.mem.Allocator,
    hb_font: *hb.hb_font_t,
    line_idx: usize,
    text: []const u8,
) ClusterResult {
    if (cache) |cluster_cache| {
        const slice = cluster_cache.getOrCompute(line_idx, hb_font, text);
        return .{ .slice = slice, .owned = false };
    }
    if (!hasNonAscii(text)) return .{ .slice = null, .owned = false };
    const slice = graphemeClusterOffsets(allocator, hb_font, text) catch null;
    return .{ .slice = slice, .owned = slice != null };
}

fn addSelectionRange(ranges: *[8]SelectionRange, count: *usize, start_col: usize, end_col: usize) void {
    if (end_col <= start_col) return;
    if (count.* >= ranges.len) return;
    ranges[count.*] = .{ .start_col = start_col, .end_col = end_col };
    count.* += 1;
}

fn collectSelectionRanges(
    editor: *Editor,
    line_idx: usize,
    line_text: []const u8,
    cluster_offsets: ?[]const u32,
    ranges: *[8]SelectionRange,
    count: *usize,
) void {
    const line_len = line_text.len;
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
            const start_vis = visualColumnForByteIndex(line_text, start_col, cluster_offsets);
            const end_vis = visualColumnForByteIndex(line_text, end_col, cluster_offsets);
            addSelectionRange(ranges, count, start_vis, end_vis);
        }
    }
    for (editor.selections.items) |sel| {
        const norm = sel.normalized();
        if (line_idx < norm.start.line or line_idx > norm.end.line) continue;
        var start_col: usize = 0;
        var end_col: usize = line_len;
        if (line_idx == norm.start.line) start_col = @min(norm.start.col, line_len);
        if (line_idx == norm.end.line) end_col = @min(norm.end.col, line_len);
        const start_vis = visualColumnForByteIndex(line_text, start_col, cluster_offsets);
        const end_vis = visualColumnForByteIndex(line_text, end_col, cluster_offsets);
        addSelectionRange(ranges, count, start_vis, end_vis);
    }
}

fn hasNonAscii(text: []const u8) bool {
    for (text) |byte| {
        if (byte & 0x80 != 0) return true;
    }
    return false;
}

fn graphemeClusterOffsets(allocator: std.mem.Allocator, hb_font: *hb.hb_font_t, text: []const u8) ![]u32 {
    if (text.len == 0) return allocator.alloc(u32, 0);
    const buffer = hb.hb_buffer_create();
    defer hb.hb_buffer_destroy(buffer);
    hb.hb_buffer_add_utf8(buffer, text.ptr, @intCast(text.len), 0, @intCast(text.len));
    hb.hb_buffer_guess_segment_properties(buffer);
    hb.hb_shape(hb_font, buffer, null, 0);

    var length: u32 = 0;
    const infos = hb.hb_buffer_get_glyph_infos(buffer, &length);
    if (infos == null or length == 0) return allocator.alloc(u32, 0);

    var clusters = std.ArrayList(u32).empty;
    defer clusters.deinit(allocator);
    try clusters.ensureTotalCapacity(allocator, @intCast(length));
    for (infos[0..length]) |info| {
        clusters.appendAssumeCapacity(info.cluster);
    }

    std.sort.block(u32, clusters.items, {}, struct {
        fn lessThan(_: void, a: u32, b: u32) bool {
            return a < b;
        }
    }.lessThan);

    var write: usize = 0;
    for (clusters.items) |cluster| {
        if (write == 0 or cluster != clusters.items[write - 1]) {
            clusters.items[write] = cluster;
            write += 1;
        }
    }
    clusters.items.len = write;
    return try clusters.toOwnedSlice(allocator);
}

fn visualColumnForByteIndex(text: []const u8, byte_index: usize, cluster_offsets: ?[]const u32) usize {
    if (cluster_offsets) |clusters| {
        if (clusters.len == 0) return utf8ColumnForByteIndex(text, byte_index);
        const target = @min(byte_index, text.len);
        var idx: usize = 0;
        while (idx < clusters.len and clusters[idx] < target) : (idx += 1) {}
        return idx;
    }
    return utf8ColumnForByteIndex(text, byte_index);
}

fn byteIndexForVisualColumn(text: []const u8, column: usize, cluster_offsets: ?[]const u32) usize {
    if (cluster_offsets) |clusters| {
        if (clusters.len == 0) return utf8ByteIndexForColumn(text, column);
        if (column >= clusters.len) return text.len;
        return @min(@as(usize, clusters[column]), text.len);
    }
    return utf8ByteIndexForColumn(text, column);
}

fn utf8ColumnForByteIndex(line_text: []const u8, byte_index: usize) usize {
    if (byte_index == 0 or line_text.len == 0) return 0;
    const target = @min(byte_index, line_text.len);
    var it = std.unicode.Utf8View.initUnchecked(line_text).iterator();
    var col: usize = 0;
    var idx: usize = 0;
    while (it.nextCodepointSlice()) |slice| {
        const next_idx = idx + slice.len;
        if (target < next_idx) return col;
        idx = next_idx;
        col += 1;
    }
    return col;
}

fn utf8ByteIndexForColumn(line_text: []const u8, column: usize) usize {
    if (column == 0 or line_text.len == 0) return 0;
    var it = std.unicode.Utf8View.initUnchecked(line_text).iterator();
    var col: usize = 0;
    var idx: usize = 0;
    while (it.nextCodepointSlice()) |slice| {
        if (col == column) return idx;
        idx += slice.len;
        col += 1;
    }
    return line_text.len;
}

test "utf8 column/byte mapping is consistent" {
    const s = "aé文𐍈z";
    try std.testing.expectEqual(@as(usize, 0), utf8ColumnForByteIndex(s, 0));
    try std.testing.expectEqual(@as(usize, 1), utf8ColumnForByteIndex(s, 1));
    try std.testing.expectEqual(@as(usize, 2), utf8ColumnForByteIndex(s, 3));
    try std.testing.expectEqual(@as(usize, 3), utf8ColumnForByteIndex(s, 6));
    try std.testing.expectEqual(@as(usize, 4), utf8ColumnForByteIndex(s, 10));

    try std.testing.expectEqual(@as(usize, 0), utf8ByteIndexForColumn(s, 0));
    try std.testing.expectEqual(@as(usize, 1), utf8ByteIndexForColumn(s, 1));
    try std.testing.expectEqual(@as(usize, 3), utf8ByteIndexForColumn(s, 2));
    try std.testing.expectEqual(@as(usize, 6), utf8ByteIndexForColumn(s, 3));
    try std.testing.expectEqual(@as(usize, 10), utf8ByteIndexForColumn(s, 4));
    try std.testing.expectEqual(@as(usize, s.len), utf8ByteIndexForColumn(s, 5));
}

test "visual line count rounds to viewport columns" {
    const cols: usize = 4;
    try std.testing.expectEqual(@as(usize, 3), visualLineCountForWidth(cols, 10));
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

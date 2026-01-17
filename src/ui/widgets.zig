const std = @import("std");
const renderer_mod = @import("renderer.zig");
const editor_mod = @import("../editor/editor.zig");
const terminal_mod = @import("../terminal/terminal.zig");
const syntax_mod = @import("../editor/syntax.zig");

const Renderer = renderer_mod.Renderer;
const Color = renderer_mod.Color;
const Editor = editor_mod.Editor;
const TerminalSession = terminal_mod.TerminalSession;
const CursorPos = terminal_mod.CursorPos;
const Cell = terminal_mod.Cell;
const HighlightToken = syntax_mod.HighlightToken;
const TokenKind = syntax_mod.TokenKind;

const TruncResult = struct {
    drawn_width: f32,
    truncated: bool,
    drawn_len: usize,
};

fn drawTruncatedText(r: *Renderer, text: []const u8, x: f32, y: f32, color: Color, max_width: f32) TruncResult {
    if (max_width <= 0 or text.len == 0) {
        return .{ .drawn_width = 0, .truncated = text.len > 0, .drawn_len = 0 };
    }
    const max_chars: usize = @intCast(@max(0, @as(i32, @intFromFloat(max_width / r.char_width))));
    if (max_chars == 0) {
        return .{ .drawn_width = 0, .truncated = text.len > 0, .drawn_len = 0 };
    }

    var buf: [256]u8 = undefined;
    var out_len: usize = 0;
    const truncated = text.len > max_chars;
    if (text.len <= max_chars) {
        out_len = @min(text.len, buf.len);
        @memcpy(buf[0..out_len], text[0..out_len]);
    } else if (max_chars <= 3) {
        out_len = @min(max_chars, buf.len);
        @memcpy(buf[0..out_len], text[0..out_len]);
    } else {
        const prefix_len = @min(max_chars - 3, buf.len - 3);
        @memcpy(buf[0..prefix_len], text[0..prefix_len]);
        buf[prefix_len + 0] = '.';
        buf[prefix_len + 1] = '.';
        buf[prefix_len + 2] = '.';
        out_len = prefix_len + 3;
    }

    r.drawText(buf[0..out_len], x, y, color);
    return .{
        .drawn_width = @as(f32, @floatFromInt(out_len)) * r.char_width,
        .truncated = truncated,
        .drawn_len = out_len,
    };
}

const Tooltip = struct {
    text: []const u8,
    x: f32,
    y: f32,
};

fn drawTooltip(r: *Renderer, text: []const u8, x: f32, y: f32) void {
    if (text.len == 0) return;
    const padding: f32 = 6;
    const text_w = @as(f32, @floatFromInt(text.len)) * r.char_width;
    const text_h = r.char_height;
    const w = text_w + padding * 2;
    const h = text_h + padding * 2;

    const max_w = @as(f32, @floatFromInt(r.width));
    const max_h = @as(f32, @floatFromInt(r.height));
    var draw_x = x + 12;
    var draw_y = y + 12;
    if (draw_x + w > max_w) draw_x = max_w - w - 4;
    if (draw_y + h > max_h) draw_y = max_h - h - 4;
    if (draw_x < 4) draw_x = 4;
    if (draw_y < 4) draw_y = 4;

    const bg = Color{ .r = 24, .g = 25, .b = 33, .a = 235 };
    r.drawRect(@intFromFloat(draw_x), @intFromFloat(draw_y), @intFromFloat(w), @intFromFloat(h), bg);
    r.drawRectOutline(@intFromFloat(draw_x), @intFromFloat(draw_y), @intFromFloat(w), @intFromFloat(h), Color.light_gray);
    r.drawText(text, draw_x + padding, draw_y + padding, Color.fg);
}

/// Tab bar for multiple open files/terminals
pub const TabBar = struct {
    allocator: std.mem.Allocator,
    tabs: std.ArrayList(Tab),
    active_index: usize,
    height: f32,

    pub const Tab = struct {
        title: []const u8,
        kind: Kind,
        modified: bool,

        pub const Kind = enum { editor, terminal };
    };

    pub fn init(allocator: std.mem.Allocator) TabBar {
        return .{
            .allocator = allocator,
            .tabs = .empty,
            .active_index = 0,
            .height = 28,
        };
    }

    pub fn deinit(self: *TabBar) void {
        self.tabs.deinit(self.allocator);
    }

    pub fn addTab(self: *TabBar, title: []const u8, kind: Tab.Kind) !void {
        try self.tabs.append(self.allocator, .{
            .title = title,
            .kind = kind,
            .modified = false,
        });
    }

    pub fn draw(self: *TabBar, r: *Renderer, x: f32, y: f32, width: f32) void {
        // Draw tab bar background
        r.drawRect(@intFromFloat(x), @intFromFloat(y), @intFromFloat(width), @intFromFloat(self.height), Color{ .r = 30, .g = 31, .b = 41 });

        if (width <= 0 or self.height <= 0) return;

        r.beginClip(@intFromFloat(x), @intFromFloat(y), @intFromFloat(width), @intFromFloat(self.height));

        var tooltip: ?Tooltip = null;
        const mouse = r.getMousePos();

        var cursor_x: f32 = x;
        for (self.tabs.items, 0..) |tab, i| {
            const tab_width: f32 = 150;
            const is_active = i == self.active_index;

            // Tab background
            const bg = if (is_active)
                Color.bg
            else
                Color{ .r = 35, .g = 36, .b = 48 };
            r.drawRect(@intFromFloat(cursor_x), @intFromFloat(y), @intFromFloat(tab_width), @intFromFloat(self.height), bg);

            // Tab border
            if (is_active) {
                r.drawRect(@intFromFloat(cursor_x), @intFromFloat(y + self.height - 2), @intFromFloat(tab_width), 2, Color.purple);
            }

            // Tab title
            const title_x = cursor_x + 8;
            const title_y = y + (self.height - r.char_height) / 2;

            // Modified indicator
            if (tab.modified) {
                r.drawText("* ", title_x, title_y, Color.orange);
            }

            const prefix_width: f32 = if (tab.modified) r.char_width * 2 else 0;
            const title_max = tab_width - 16 - prefix_width;
            const result = drawTruncatedText(
                r,
                tab.title,
                title_x + prefix_width,
                title_y,
                if (is_active) Color.fg else Color.comment,
                title_max,
            );
            const in_tab = mouse.x >= cursor_x and mouse.x <= cursor_x + tab_width and
                mouse.y >= y and mouse.y <= y + self.height;
            if (result.truncated and in_tab) {
                tooltip = .{ .text = tab.title, .x = mouse.x, .y = mouse.y };
            }

            cursor_x += tab_width + 1;
        }

        r.endClip();

        if (tooltip) |tip| {
            drawTooltip(r, tip.text, tip.x, tip.y);
        }
    }

    pub fn handleClick(self: *TabBar, x: f32, y: f32, bar_x: f32, bar_y: f32) bool {
        if (y < bar_y or y > bar_y + self.height) return false;
        if (x < bar_x) return false;

        const tab_width: f32 = 150;
        const clicked_index = @as(usize, @intFromFloat((x - bar_x) / (tab_width + 1)));

        if (clicked_index < self.tabs.items.len) {
            self.active_index = clicked_index;
            return true;
        }
        return false;
    }
};

/// Top options bar (VSCode-style app menu)
pub const OptionsBar = struct {
    height: f32 = 26,

    pub fn draw(self: *OptionsBar, r: *Renderer, width: f32) void {
        // Background
        r.drawRect(0, 0, @intFromFloat(width), @intFromFloat(self.height), Color{ .r = 24, .g = 25, .b = 33 });

        // Menu labels
        const labels = [_][]const u8{ "File", "Edit", "Selection", "View", "Go", "Run", "Terminal", "Help" };
        var x: f32 = 10;
        const y: f32 = (self.height - r.char_height) / 2;
        const mouse = r.getMousePos();
        const pressed = r.isMouseButtonDown(renderer_mod.MOUSE_LEFT);
        for (labels) |label| {
            const text_w = @as(f32, @floatFromInt(label.len)) * r.char_width;
            const pad_x: f32 = 6;
            const pad_y: f32 = 4;
            const bx = x - pad_x;
            const by = y - pad_y;
            const bw = text_w + pad_x * 2;
            const bh = r.char_height + pad_y * 2;
            const hovered = mouse.x >= bx and mouse.x <= bx + bw and mouse.y >= by and mouse.y <= by + bh;
            if (hovered) {
                const bg = if (pressed) Color{ .r = 58, .g = 60, .b = 78 } else Color.selection;
                r.drawRect(@intFromFloat(bx), @intFromFloat(by), @intFromFloat(bw), @intFromFloat(bh), bg);
            }
            r.drawText(label, x, y, if (hovered) Color.fg else Color.comment);
            x += text_w + 16;
        }
    }
};

/// Side navigation bar (VSCode activity bar)
pub const SideNav = struct {
    width: f32 = 52,

    pub fn draw(self: *SideNav, r: *Renderer, height: f32, y: f32) void {
        // Background
        r.drawRect(0, @intFromFloat(y), @intFromFloat(self.width), @intFromFloat(height), Color{ .r = 30, .g = 31, .b = 41 });

        const Item = struct {
            icon: []const u8,
            badge: ?u8,
            active: bool,
        };
        const top_items = [_]Item{
            .{ .icon = "", .badge = 1, .active = true }, // Workspace 1
            .{ .icon = "", .badge = 2, .active = false }, // Workspace 2
            .{ .icon = "", .badge = 3, .active = false }, // Workspace 3
        };
        const bottom_items = [_]Item{
            .{ .icon = "", .badge = null, .active = false }, // Search
            .{ .icon = "", .badge = null, .active = false }, // Source Control
            .{ .icon = "", .badge = null, .active = false }, // Run/Debug
            .{ .icon = "", .badge = null, .active = false }, // Extensions
            .{ .icon = "", .badge = null, .active = false }, // Settings
            .{ .icon = "󰏗", .badge = null, .active = false }, // Accounts
        };

        const icon_size: f32 = 32;
        const icon_h_unit: f32 = r.icon_char_height;
        const badge_size: f32 = r.font_size * 1.0;
        const badge_h_unit: f32 = r.char_height * (badge_size / r.font_size);
        const spacing: f32 = 12;
        const mouse = r.getMousePos();
        const pressed = r.isMouseButtonDown(renderer_mod.MOUSE_LEFT);

        const icon_x_pad: f32 = self.width * 0.30;
        const icon_text_offset: f32 = 1;
        var icon_y: f32 = y + 10;
        for (top_items) |item| {
            const icon_x: f32 = icon_x_pad;
            const bx = icon_x - 8;
            const by = icon_y - 6;
            const bw = icon_size + 16;
            const bh = icon_size + 12;
            const hovered = mouse.x >= bx and mouse.x <= bx + bw and mouse.y >= by and mouse.y <= by + bh;

            if (hovered or item.active) {
                const bg = if (pressed and hovered) Color{ .r = 58, .g = 60, .b = 78 } else Color.selection;
                r.drawRect(@intFromFloat(bx), @intFromFloat(by), @intFromFloat(bw), @intFromFloat(bh), bg);
            }
            if (item.active) {
                r.drawRect(0, @intFromFloat(by), 2, @intFromFloat(bh), Color.purple);
            }

            const icon_color = if (item.active or hovered) Color.fg else Color.comment;
            const icon_text_x = icon_x + icon_text_offset;
            const icon_text_y = icon_y + (icon_size - icon_h_unit) / 2;
            r.drawIconText(item.icon, icon_text_x, icon_text_y, icon_color);

            if (item.badge) |count| {
                var buf: [4]u8 = undefined;
                const text = std.fmt.bufPrint(&buf, "{d}", .{count}) catch "";
                const text_h = badge_h_unit;
                const badge_x = icon_x + icon_text_offset + 2;
                const badge_y = icon_y + (icon_size - text_h) / 2 + 1;
                r.drawTextSized(text, badge_x, badge_y, badge_size, Color.fg);
            }

            icon_y += icon_size + spacing;
        }

        var bottom_y: f32 = y + height - 10 - icon_size;
        var i: usize = 0;
        while (i < bottom_items.len) : (i += 1) {
            const item = bottom_items[bottom_items.len - 1 - i];
            const icon_x: f32 = icon_x_pad;
            const bx = icon_x - 8;
            const by = bottom_y - 6;
            const bw = icon_size + 16;
            const bh = icon_size + 12;
            const hovered = mouse.x >= bx and mouse.x <= bx + bw and mouse.y >= by and mouse.y <= by + bh;

            if (hovered or item.active) {
                const bg = if (pressed and hovered) Color{ .r = 58, .g = 60, .b = 78 } else Color.selection;
                r.drawRect(@intFromFloat(bx), @intFromFloat(by), @intFromFloat(bw), @intFromFloat(bh), bg);
            }
            if (item.active) {
                r.drawRect(0, @intFromFloat(by), 2, @intFromFloat(bh), Color.purple);
            }

            const icon_color = if (item.active or hovered) Color.fg else Color.comment;
            const icon_text_x = icon_x + icon_text_offset;
            const icon_text_y = bottom_y + (icon_size - icon_h_unit) / 2;
            r.drawIconText(item.icon, icon_text_x, icon_text_y, icon_color);

            bottom_y -= icon_size + spacing;
        }
    }
};

/// Status bar at the bottom
pub const StatusBar = struct {
    height: f32 = 24,

    pub fn draw(
        self: *StatusBar,
        r: *Renderer,
        width: f32,
        y: f32,
        mode: []const u8,
        file_path: ?[]const u8,
        line: usize,
        col: usize,
        modified: bool,
    ) void {
        // Background
        r.drawRect(0, @intFromFloat(y), @intFromFloat(width), @intFromFloat(self.height), Color{ .r = 30, .g = 31, .b = 41 });

        // Line/column (reserve space on right)
        var pos_buf: [32]u8 = undefined;
        const pos_str = std.fmt.bufPrint(&pos_buf, "Ln {d}, Col {d}", .{ line + 1, col + 1 }) catch return;
        const pos_width = @as(f32, @floatFromInt(pos_str.len)) * r.char_width;
        const pos_start = width - pos_width - 16;

        // Mode indicator
        const mode_bg = if (std.mem.eql(u8, mode, "INSERT"))
            Color.green
        else if (std.mem.eql(u8, mode, "VISUAL"))
            Color.purple
        else
            Color.cyan;

        const mouse = r.getMousePos();
        const pressed = r.isMouseButtonDown(renderer_mod.MOUSE_LEFT);
        const mode_hover = mouse.x >= 0 and mouse.x <= 80 and mouse.y >= y and mouse.y <= y + self.height;
        const mode_bg_final = if (mode_hover and pressed) Color{ .r = 58, .g = 60, .b = 78 } else if (mode_hover) Color.selection else mode_bg;
        r.drawRect(0, @intFromFloat(y), 80, @intFromFloat(self.height), mode_bg_final);
        r.drawText(mode, 8, y + 4, if (mode_hover) Color.fg else Color.black);

        // File path
        var x: f32 = 88;
        if (file_path) |path| {
            const available = pos_start - 16 - x;
            const result = drawTruncatedText(r, path, x, y + 4, Color.fg, available);
            const mouse_path = r.getMousePos();
            const in_path = mouse_path.x >= x and mouse_path.x <= x + result.drawn_width and
                mouse_path.y >= y and mouse_path.y <= y + self.height;
            if (result.truncated and in_path) {
                drawTooltip(r, path, mouse_path.x, mouse_path.y);
            }
            x += result.drawn_width + 16;
        }

        // Modified indicator
        if (modified) {
            const indicator = "[+]";
            const indicator_width = @as(f32, @floatFromInt(indicator.len)) * r.char_width;
            if (x + indicator_width <= pos_start - 8) {
                r.drawText(indicator, x, y + 4, Color.orange);
            }
        }

        const pos_hover = mouse.x >= pos_start and mouse.x <= pos_start + pos_width and mouse.y >= y and mouse.y <= y + self.height;
        if (pos_hover) {
            const bg = if (pressed) Color{ .r = 58, .g = 60, .b = 78 } else Color.selection;
            r.drawRect(@intFromFloat(pos_start - 4), @intFromFloat(y + 2), @intFromFloat(pos_width + 8), @intFromFloat(self.height - 4), bg);
        }
        r.drawText(pos_str, pos_start, y + 4, if (pos_hover) Color.fg else Color.comment);
    }
};

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
        const visible_lines = @as(usize, @intFromFloat(height / r.char_height));
        const start_line = self.editor.scroll_line;
        const end_line = @min(start_line + visible_lines + 1, self.editor.lineCount());

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
        while (line_idx < end_line) : (line_idx += 1) {
            const line_y = y + @as(f32, @floatFromInt(line_idx - start_line)) * r.char_height;
            const is_current = line_idx == self.editor.cursor.line;

            const len = self.editor.getLine(line_idx, &line_buf);
            const line_text = line_buf[0..len];
            const line_start = self.editor.lineStart(line_idx);
            const line_end = line_start + len;

            if (self.editor.highlighter) |highlighter| {
                const tokens = highlighter.highlightRange(line_start, line_end, self.editor.allocator) catch {
                    r.drawEditorLine(line_idx, line_text, line_y, x, self.gutter_width, width, is_current);
                    continue;
                };
                defer self.editor.allocator.free(tokens);

                if (tokens.len == 0) {
                    r.drawEditorLine(line_idx, line_text, line_y, x, self.gutter_width, width, is_current);
                } else {
                    r.drawEditorLineBase(line_idx, line_y, x, self.gutter_width, width, is_current);
                    drawHighlightedLineText(
                        r,
                        line_text,
                        line_y,
                        x + self.gutter_width + 8,
                        line_start,
                        line_end,
                        tokens,
                    );
                }
            } else {
                r.drawEditorLine(line_idx, line_text, line_y, x, self.gutter_width, width, is_current);
            }
        }

        // Draw cursor
        if (self.editor.cursor.line >= start_line and self.editor.cursor.line < end_line) {
            const cursor_x = x + self.gutter_width + 8 + @as(f32, @floatFromInt(self.editor.cursor.col)) * r.char_width;
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
        if (width <= 0 or height <= 0) return false;
        if (mouse_x < x or mouse_x > x + width) return false;
        if (mouse_y < y or mouse_y > y + height) return false;
        if (self.editor.lineCount() == 0) return false;

        const line_offset = @as(usize, @intFromFloat((mouse_y - y) / r.char_height));
        const max_line = self.editor.lineCount() - 1;
        const line = @min(self.editor.scroll_line + line_offset, max_line);

        const text_start_x = x + self.gutter_width + 8;
        var col: usize = 0;
        if (mouse_x > text_start_x) {
            col = @as(usize, @intFromFloat((mouse_x - text_start_x) / r.char_width));
        }
        const line_len = self.editor.lineLen(line);
        const clamped_col = @min(col, line_len);
        self.editor.setCursor(line, clamped_col);
        return true;
    }

    /// Handle input, returns true if any input was processed
    pub fn handleInput(self: *EditorWidget, r: *Renderer) !bool {
        var handled = false;

        // Character input
        while (r.getCharPressed()) |char| {
            if (char >= 32 and char < 127) {
                try self.editor.insertChar(@intCast(char));
                handled = true;
            }
        }

        // Control keys
        const ctrl = r.isKeyDown(renderer_mod.KEY_LEFT_CONTROL) or r.isKeyDown(renderer_mod.KEY_RIGHT_CONTROL);

        if (r.isKeyPressed(renderer_mod.KEY_ENTER)) {
            try self.editor.insertNewline();
            handled = true;
        } else if (r.isKeyPressed(renderer_mod.KEY_BACKSPACE)) {
            try self.editor.deleteCharBackward();
            handled = true;
        } else if (r.isKeyPressed(renderer_mod.KEY_DELETE)) {
            try self.editor.deleteCharForward();
            handled = true;
        } else if (r.isKeyPressed(renderer_mod.KEY_UP)) {
            self.editor.moveCursorUp();
            handled = true;
        } else if (r.isKeyPressed(renderer_mod.KEY_DOWN)) {
            self.editor.moveCursorDown();
            handled = true;
        } else if (r.isKeyPressed(renderer_mod.KEY_LEFT)) {
            self.editor.moveCursorLeft();
            handled = true;
        } else if (r.isKeyPressed(renderer_mod.KEY_RIGHT)) {
            self.editor.moveCursorRight();
            handled = true;
        } else if (r.isKeyPressed(renderer_mod.KEY_HOME)) {
            self.editor.moveCursorToLineStart();
            handled = true;
        } else if (r.isKeyPressed(renderer_mod.KEY_END)) {
            self.editor.moveCursorToLineEnd();
            handled = true;
        } else if (ctrl and r.isKeyPressed(renderer_mod.KEY_S)) {
            try self.editor.save();
            handled = true;
        } else if (ctrl and r.isKeyPressed(renderer_mod.KEY_Z)) {
            _ = try self.editor.undo();
            handled = true;
        } else if (ctrl and r.isKeyPressed(renderer_mod.KEY_Y)) {
            _ = try self.editor.redo();
            handled = true;
        }

        // Scroll handling
        const wheel = r.getMouseWheelMove();
        if (wheel != 0) {
            const delta = @as(i32, @intFromFloat(-wheel * 3));
            const new_scroll = @as(i64, @intCast(self.editor.scroll_line)) + delta;
            self.editor.scroll_line = @intCast(@max(0, @min(new_scroll, @as(i64, @intCast(self.editor.lineCount())))));
            handled = true;
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

    std.sort.heap(HighlightToken, tokens, {}, highlightTokenLessThan);

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

/// Terminal widget for drawing a terminal view
pub const TerminalWidget = struct {
    session: *TerminalSession,

    pub fn init(session: *TerminalSession) TerminalWidget {
        return .{
            .session = session,
        };
    }

    pub fn draw(self: *TerminalWidget, r: *Renderer, x: f32, y: f32, width: f32, height: f32) void {
        const snapshot = self.session.snapshot();
        const rows = snapshot.rows;
        const cols = snapshot.cols;
        const history_len = self.session.scrollbackCount();
        const total_lines = history_len + rows;
        var scroll_offset = self.session.scrollOffset();
        const max_scroll_offset = if (total_lines > rows) total_lines - rows else 0;
        if (scroll_offset > max_scroll_offset) {
            self.session.setScrollOffset(max_scroll_offset);
            scroll_offset = max_scroll_offset;
        }
        const end_line = total_lines - scroll_offset;
        const start_line = if (end_line > rows) end_line - rows else 0;
        const draw_cursor = scroll_offset == 0;
        const cursor = if (draw_cursor) snapshot.cursor else CursorPos{ .row = rows + 1, .col = cols + 1 };

        // No clipping - let icons overflow freely
        // (sidebar draws last to cover any left overflow, right overflow goes into empty space)

        const base_x = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(x)))));
        const base_y = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(y)))));

        const scrollbar_w: f32 = 10;
        const scrollbar_x = x + width - scrollbar_w;
        const scrollbar_y = y;
        const scrollbar_h = height;

        const rowSlice = struct {
            fn get(parent: *TerminalWidget, snapshot_cells: []const Cell, history: usize, cols_count: usize, start: usize, row: usize) []const Cell {
                const global_row = start + row;
                if (global_row < history) {
                    if (parent.session.scrollbackRow(global_row)) |history_row| {
                        return history_row;
                    }
                }
                const grid_row = global_row - history;
                const row_start = grid_row * cols_count;
                return snapshot_cells[row_start .. row_start + cols_count];
            }
        }.get;

        const drawRowRange = struct {
            fn render(
                parent: *TerminalWidget,
                renderer: *Renderer,
                snapshot_cells: []const Cell,
                history: usize,
                cols_count: usize,
                start: usize,
                row_idx: usize,
                col_start_in: usize,
                col_end_in: usize,
                base_x_local: f32,
                base_y_local: f32,
            ) void {
                const row_cells = rowSlice(parent, snapshot_cells, history, cols_count, start, row_idx);
                const col_start = @min(col_start_in, cols_count - 1);
                const col_end = @min(col_end_in, cols_count - 1);
                if (col_start > col_end) return;

                var col: usize = col_start;
                while (col <= col_end and col < cols_count) : (col += 1) {
                    const cell = row_cells[col];
                    const cell_width_units = @as(usize, @max(@as(u8, 1), cell.width));
                    const cell_x = base_x_local + @as(f32, @floatFromInt(col)) * renderer.terminal_cell_width;
                    const cell_y = base_y_local + @as(f32, @floatFromInt(row_idx)) * renderer.terminal_cell_height;
                    const cell_w = renderer.terminal_cell_width * @as(f32, @floatFromInt(cell_width_units));

                    const fg = Color{
                        .r = cell.attrs.fg.r,
                        .g = cell.attrs.fg.g,
                        .b = cell.attrs.fg.b,
                    };
                    const bg = Color{
                        .r = cell.attrs.bg.r,
                        .g = cell.attrs.bg.g,
                        .b = cell.attrs.bg.b,
                    };

                    renderer.drawRect(
                        @intFromFloat(cell_x),
                        @intFromFloat(cell_y),
                        @intFromFloat(cell_w),
                        @intFromFloat(renderer.terminal_cell_height),
                        if (cell.attrs.reverse) fg else bg,
                    );

                    if (cell.width > 1) {
                        col += cell_width_units - 1;
                    }
                }

                col = col_start;
                while (col <= col_end and col < cols_count) : (col += 1) {
                    const cell = row_cells[col];
                    const cell_width_units = @as(usize, @max(@as(u8, 1), cell.width));
                    const cell_x = base_x_local + @as(f32, @floatFromInt(col)) * renderer.terminal_cell_width;
                    const cell_y = base_y_local + @as(f32, @floatFromInt(row_idx)) * renderer.terminal_cell_height;

                    const fg = Color{
                        .r = cell.attrs.fg.r,
                        .g = cell.attrs.fg.g,
                        .b = cell.attrs.fg.b,
                    };
                    const bg = Color{
                        .r = cell.attrs.bg.r,
                        .g = cell.attrs.bg.g,
                        .b = cell.attrs.bg.b,
                    };

                    const followed_by_space = blk: {
                        const next_col = col + cell_width_units;
                        if (next_col < cols_count) {
                            const next_cell = row_cells[next_col];
                            break :blk next_cell.codepoint == ' ' or next_cell.codepoint == 0;
                        }
                        break :blk true;
                    };

                    renderer.drawTerminalCell(
                        cell.codepoint,
                        cell_x,
                        cell_y,
                        renderer.terminal_cell_width * @as(f32, @floatFromInt(cell_width_units)),
                        renderer.terminal_cell_height,
                        if (cell.attrs.reverse) bg else fg,
                        if (cell.attrs.reverse) fg else bg,
                        cell.attrs.bold,
                        false,
                        followed_by_space,
                    );

                    if (cell.width > 1) {
                        col += cell_width_units - 1;
                    }
                }
            }
        }.render;

        var updated = false;
        if (rows > 0 and cols > 0) {
            const texture_w = @as(i32, @intFromFloat(@round(r.terminal_cell_width * @as(f32, @floatFromInt(cols)))));
            const texture_h = @as(i32, @intFromFloat(@round(r.terminal_cell_height * @as(f32, @floatFromInt(rows)))));
            const recreated = r.ensureTerminalTexture(texture_w, texture_h);
            const needs_full = recreated or snapshot.dirty == .full or (snapshot.dirty != .none and scroll_offset > 0);
            const needs_partial = snapshot.dirty == .partial and !needs_full and scroll_offset == 0;

            if ((needs_full or needs_partial) and r.beginTerminalTexture()) {
                // Disable scissor while updating the offscreen texture.
                // The main draw pass will restore the clip for on-screen drawing.
                r.endClip();
                const base_x_local: f32 = 0;
                const base_y_local: f32 = 0;

                if (needs_full) {
                    var row: usize = 0;
                    while (row < rows) : (row += 1) {
                        drawRowRange(self, r, snapshot.cells, history_len, cols, start_line, row, 0, cols - 1, base_x_local, base_y_local);
                    }
                } else if (needs_partial) {
                    var row: usize = 0;
                    while (row < rows) : (row += 1) {
                        if (row < snapshot.dirty_rows.len and snapshot.dirty_rows[row]) {
                            var col_start: usize = 0;
                            var col_end: usize = cols - 1;
                            if (row < snapshot.dirty_cols_start.len and row < snapshot.dirty_cols_end.len) {
                                col_start = @intCast(snapshot.dirty_cols_start[row]);
                                col_end = @intCast(snapshot.dirty_cols_end[row]);
                                if (col_start >= cols) col_start = 0;
                                if (col_end >= cols) col_end = cols - 1;
                                if (col_end < col_start) {
                                    col_start = 0;
                                    col_end = cols - 1;
                                }
                            }
                            const draw_start = if (col_start > 0) col_start - 1 else 0;
                            const draw_end = @min(cols - 1, col_end + 1);
                            drawRowRange(self, r, snapshot.cells, history_len, cols, start_line, row, draw_start, draw_end, base_x_local, base_y_local);
                        }
                    }
                }
                r.endTerminalTexture();
                r.beginClip(
                    @intFromFloat(x),
                    @intFromFloat(y),
                    @intFromFloat(width),
                    @intFromFloat(height),
                );
                updated = true;
            }

            r.drawTerminalTexture(base_x, base_y);
        }

        if (rows > 0 and cols > 0) {
            if (self.session.selectionState()) |selection| {
                const total_lines_sel = history_len + rows;
                if (total_lines_sel > 0) {
                    var start_sel = selection.start;
                    var end_sel = selection.end;
                    if (start_sel.row > end_sel.row or (start_sel.row == end_sel.row and start_sel.col > end_sel.col)) {
                        const tmp = start_sel;
                        start_sel = end_sel;
                        end_sel = tmp;
                    }
                    start_sel.row = @min(start_sel.row, total_lines_sel - 1);
                    end_sel.row = @min(end_sel.row, total_lines_sel - 1);
                    start_sel.col = @min(start_sel.col, cols - 1);
                    end_sel.col = @min(end_sel.col, cols - 1);

                    const selection_color = Color{
                        .r = r.theme.selection.r,
                        .g = r.theme.selection.g,
                        .b = r.theme.selection.b,
                        .a = 140,
                    };

                    var row_idx: usize = 0;
                    while (row_idx < rows) : (row_idx += 1) {
                        const global_row = start_line + row_idx;
                        if (global_row < start_sel.row or global_row > end_sel.row) continue;

                        const col_start = if (global_row == start_sel.row) start_sel.col else 0;
                        const col_end = if (global_row == end_sel.row) end_sel.col else cols - 1;
                        if (col_end < col_start) continue;

                        const rect_x = base_x + @as(f32, @floatFromInt(col_start)) * r.terminal_cell_width;
                        const rect_y = base_y + @as(f32, @floatFromInt(row_idx)) * r.terminal_cell_height;
                        const rect_w = r.terminal_cell_width * @as(f32, @floatFromInt(col_end - col_start + 1));
                        const rect_h = r.terminal_cell_height;

                        r.drawRect(
                            @intFromFloat(rect_x),
                            @intFromFloat(rect_y),
                            @intFromFloat(rect_w),
                            @intFromFloat(rect_h),
                            selection_color,
                        );
                    }
                }
            }
        }

        if (draw_cursor and rows > 0 and cols > 0 and cursor.row < rows and cursor.col < cols) {
            const row_cells = rowSlice(self, snapshot.cells, history_len, cols, start_line, cursor.row);
            const cell = row_cells[cursor.col];
            const cell_width_units = @as(usize, @max(@as(u8, 1), cell.width));
            const cell_x = base_x + @as(f32, @floatFromInt(cursor.col)) * r.terminal_cell_width;
            const cell_y = base_y + @as(f32, @floatFromInt(cursor.row)) * r.terminal_cell_height;

            const fg = Color{
                .r = cell.attrs.fg.r,
                .g = cell.attrs.fg.g,
                .b = cell.attrs.fg.b,
            };
            const bg = Color{
                .r = cell.attrs.bg.r,
                .g = cell.attrs.bg.g,
                .b = cell.attrs.bg.b,
            };

            const followed_by_space = blk: {
                const next_col = cursor.col + cell_width_units;
                if (next_col < cols) {
                    const next_cell = row_cells[next_col];
                    break :blk next_cell.codepoint == ' ' or next_cell.codepoint == 0;
                }
                break :blk true;
            };

            r.drawTerminalCell(
                cell.codepoint,
                cell_x,
                cell_y,
                r.terminal_cell_width * @as(f32, @floatFromInt(cell_width_units)),
                r.terminal_cell_height,
                if (cell.attrs.reverse) bg else fg,
                if (cell.attrs.reverse) fg else bg,
                cell.attrs.bold,
                true,
                followed_by_space,
            );
        }

        if (height > 0 and width > 0) {
            const track_h = scrollbar_h;
            const min_thumb_h: f32 = 18;
            const thumb_h = if (total_lines > rows)
                @max(min_thumb_h, track_h * (@as(f32, @floatFromInt(rows)) / @as(f32, @floatFromInt(total_lines))))
            else
                track_h;
            const available = @max(@as(f32, 1), track_h - thumb_h);
            const ratio = if (max_scroll_offset > 0)
                @as(f32, @floatFromInt(max_scroll_offset - scroll_offset)) / @as(f32, @floatFromInt(max_scroll_offset))
            else
                1.0;
            const thumb_y = scrollbar_y + available * ratio;

            r.drawRect(
                @intFromFloat(scrollbar_x),
                @intFromFloat(scrollbar_y),
                @intFromFloat(scrollbar_w),
                @intFromFloat(scrollbar_h),
                r.theme.line_number_bg,
            );
            r.drawRect(
                @intFromFloat(scrollbar_x + 2),
                @intFromFloat(thumb_y),
                @intFromFloat(scrollbar_w - 4),
                @intFromFloat(thumb_h),
                r.theme.selection,
            );

            // Scrollbar only; no debug chip.
        }

        if (updated or snapshot.dirty == .none) {
            self.session.clearDirty();
        }
    }

    /// Handle input, returns true if any input was processed
    pub fn handleInput(
        self: *TerminalWidget,
        r: *Renderer,
        x: f32,
        y: f32,
        width: f32,
        height: f32,
        allow_input: bool,
        scroll_dragging: *bool,
        scroll_grab_offset: *f32,
    ) !bool {
        var handled = false;
        const mouse = r.getMousePos();
        const in_terminal = mouse.x >= x and mouse.x <= x + width and mouse.y >= y and mouse.y <= y + height;
        const scrollbar_w: f32 = 10;
        const scrollbar_x = x + width - scrollbar_w;
        const scrollbar_y = y;
        const scrollbar_h = height;

        const history_len = self.session.scrollbackCount();
        const rows = self.session.gridRows();
        const cols = self.session.gridCols();
        const total_lines = history_len + rows;
        const max_scroll_offset = if (total_lines > rows) total_lines - rows else 0;

        if (allow_input) {
            const ctrl = r.isKeyDown(renderer_mod.KEY_LEFT_CONTROL) or r.isKeyDown(renderer_mod.KEY_RIGHT_CONTROL);
            const shift = r.isKeyDown(renderer_mod.KEY_LEFT_SHIFT) or r.isKeyDown(renderer_mod.KEY_RIGHT_SHIFT);
            var skip_chars = false;

            if (ctrl and shift and r.isKeyPressed(renderer_mod.KEY_C)) {
                if (self.session.selectionState()) |selection| {
                    const snapshot = self.session.snapshot();
                    const rows_snapshot = snapshot.rows;
                    const cols_snapshot = snapshot.cols;
                    const history = self.session.scrollbackCount();
                    const total_lines_copy = history + rows_snapshot;
                    if (rows_snapshot > 0 and cols_snapshot > 0 and total_lines_copy > 0) {
                        var start_sel = selection.start;
                        var end_sel = selection.end;
                        if (start_sel.row > end_sel.row or (start_sel.row == end_sel.row and start_sel.col > end_sel.col)) {
                            const tmp = start_sel;
                            start_sel = end_sel;
                            end_sel = tmp;
                        }
                        start_sel.row = @min(start_sel.row, total_lines_copy - 1);
                        end_sel.row = @min(end_sel.row, total_lines_copy - 1);
                        start_sel.col = @min(start_sel.col, cols_snapshot - 1);
                        end_sel.col = @min(end_sel.col, cols_snapshot - 1);

                        var buffer = std.ArrayList(u8).empty;
                        defer buffer.deinit(self.session.allocator);

                        const appendCodepoint = struct {
                            fn write(list: *std.ArrayList(u8), allocator: std.mem.Allocator, cp: u32) !void {
                                var buf: [4]u8 = undefined;
                                if (cp == 0) {
                                    try list.append(allocator, ' ');
                                    return;
                                }
                                const len = std.unicode.utf8Encode(@intCast(cp), &buf) catch {
                                    try list.append(allocator, ' ');
                                    return;
                                };
                                try list.appendSlice(allocator, buf[0..len]);
                            }
                        }.write;

                        const rowSliceSelection = struct {
                            fn get(parent: *TerminalWidget, cells: []const Cell, history_count: usize, cols_count: usize, global_row: usize) []const Cell {
                                if (global_row < history_count) {
                                    if (parent.session.scrollbackRow(global_row)) |history_row| {
                                        return history_row;
                                    }
                                    return cells[0..cols_count];
                                }
                                const grid_row = global_row - history_count;
                                const row_start = grid_row * cols_count;
                                return cells[row_start .. row_start + cols_count];
                            }
                        }.get;

                        var row_idx: usize = start_sel.row;
                        while (row_idx <= end_sel.row and row_idx < total_lines_copy) : (row_idx += 1) {
                            const col_start = if (row_idx == start_sel.row) start_sel.col else 0;
                            const col_end = if (row_idx == end_sel.row) end_sel.col else cols_snapshot - 1;
                            if (col_end < col_start) continue;

                            const row_cells = rowSliceSelection(self, snapshot.cells, history, cols_snapshot, row_idx);
                            const line_start = buffer.items.len;

                            var col: usize = col_start;
                            while (col <= col_end and col < cols_snapshot) : (col += 1) {
                                try appendCodepoint(&buffer, self.session.allocator, row_cells[col].codepoint);
                            }

                            while (buffer.items.len > line_start and buffer.items[buffer.items.len - 1] == ' ') {
                                _ = buffer.pop();
                            }

                            if (row_idx < end_sel.row) {
                                try buffer.append(self.session.allocator, '\n');
                            }
                        }

                        if (buffer.items.len > 0) {
                            try buffer.append(self.session.allocator, 0);
                            const cstr: [*:0]const u8 = @ptrCast(buffer.items.ptr);
                            r.setClipboardText(cstr);
                            handled = true;
                            skip_chars = true;
                        }
                    }
                }
            }

            if (!skip_chars and ctrl and shift and r.isKeyPressed(renderer_mod.KEY_V)) {
                if (r.getClipboardText()) |clip| {
                    if (self.session.selectionState() != null) {
                        self.session.clearSelection();
                    }
                    if (self.session.scrollOffset() > 0) {
                        self.session.setScrollOffset(0);
                    }
                    if (self.session.bracketedPasteEnabled()) {
                        try self.session.sendText("\x1b[200~");
                        var filtered = std.ArrayList(u8).empty;
                        defer filtered.deinit(self.session.allocator);
                        for (clip) |b| {
                            if (b == 0x1b or b == 0x03) continue;
                            try filtered.append(self.session.allocator, b);
                        }
                        if (filtered.items.len > 0) {
                            try self.session.sendText(filtered.items);
                        }
                        try self.session.sendText("\x1b[201~");
                    } else {
                        try self.session.sendText(clip);
                    }
                    handled = true;
                    skip_chars = true;
                }
            }

            // Character input
            if (!skip_chars) {
                while (r.getCharPressed()) |char| {
                    if (self.session.selectionState() != null) {
                        self.session.clearSelection();
                    }
                    if (self.session.scrollOffset() > 0) {
                        self.session.setScrollOffset(0);
                    }
                    try self.session.sendChar(char, terminal_mod.VTERM_MOD_NONE);
                    handled = true;
                }
            }

            // Special keys
            if (r.isKeyPressed(renderer_mod.KEY_ENTER)) {
                if (self.session.selectionState() != null) {
                    self.session.clearSelection();
                }
                if (self.session.scrollOffset() > 0) {
                    self.session.setScrollOffset(0);
                }
                try self.session.sendKey(terminal_mod.VTERM_KEY_ENTER, terminal_mod.VTERM_MOD_NONE);
                handled = true;
            } else if (r.isKeyPressed(renderer_mod.KEY_BACKSPACE)) {
                if (self.session.selectionState() != null) {
                    self.session.clearSelection();
                }
                if (self.session.scrollOffset() > 0) {
                    self.session.setScrollOffset(0);
                }
                try self.session.sendKey(terminal_mod.VTERM_KEY_BACKSPACE, terminal_mod.VTERM_MOD_NONE);
                handled = true;
            } else if (r.isKeyPressed(renderer_mod.KEY_TAB)) {
                if (self.session.selectionState() != null) {
                    self.session.clearSelection();
                }
                if (self.session.scrollOffset() > 0) {
                    self.session.setScrollOffset(0);
                }
                try self.session.sendKey(terminal_mod.VTERM_KEY_TAB, terminal_mod.VTERM_MOD_NONE);
                handled = true;
            } else if (r.isKeyPressed(renderer_mod.KEY_ESCAPE)) {
                if (self.session.selectionState() != null) {
                    self.session.clearSelection();
                }
                if (self.session.scrollOffset() > 0) {
                    self.session.setScrollOffset(0);
                }
                try self.session.sendKey(terminal_mod.VTERM_KEY_ESCAPE, terminal_mod.VTERM_MOD_NONE);
                handled = true;
            } else if (r.isKeyPressed(renderer_mod.KEY_UP)) {
                if (self.session.selectionState() != null) {
                    self.session.clearSelection();
                }
                if (self.session.scrollOffset() > 0) {
                    self.session.setScrollOffset(0);
                }
                try self.session.sendKey(terminal_mod.VTERM_KEY_UP, terminal_mod.VTERM_MOD_NONE);
                handled = true;
            } else if (r.isKeyPressed(renderer_mod.KEY_DOWN)) {
                if (self.session.selectionState() != null) {
                    self.session.clearSelection();
                }
                if (self.session.scrollOffset() > 0) {
                    self.session.setScrollOffset(0);
                }
                try self.session.sendKey(terminal_mod.VTERM_KEY_DOWN, terminal_mod.VTERM_MOD_NONE);
                handled = true;
            } else if (r.isKeyPressed(renderer_mod.KEY_LEFT)) {
                if (self.session.selectionState() != null) {
                    self.session.clearSelection();
                }
                if (self.session.scrollOffset() > 0) {
                    self.session.setScrollOffset(0);
                }
                try self.session.sendKey(terminal_mod.VTERM_KEY_LEFT, terminal_mod.VTERM_MOD_NONE);
                handled = true;
            } else if (r.isKeyPressed(renderer_mod.KEY_RIGHT)) {
                if (self.session.selectionState() != null) {
                    self.session.clearSelection();
                }
                if (self.session.scrollOffset() > 0) {
                    self.session.setScrollOffset(0);
                }
                try self.session.sendKey(terminal_mod.VTERM_KEY_RIGHT, terminal_mod.VTERM_MOD_NONE);
                handled = true;
            }
        }

        if (allow_input and r.isKeyPressed(renderer_mod.KEY_PAGE_UP)) {
            self.session.scrollBy(@as(isize, @intCast(self.session.gridRows() / 2 + 1)));
            handled = true;
        } else if (allow_input and r.isKeyPressed(renderer_mod.KEY_PAGE_DOWN)) {
            self.session.scrollBy(-@as(isize, @intCast(self.session.gridRows() / 2 + 1)));
            handled = true;
        } else if (allow_input and r.isKeyPressed(renderer_mod.KEY_HOME)) {
            self.session.setScrollOffset(self.session.scrollbackCount());
            handled = true;
        } else if (allow_input and r.isKeyPressed(renderer_mod.KEY_END)) {
            self.session.setScrollOffset(0);
            handled = true;
        }

        const wheel = r.getMouseWheelMove();
        if (wheel != 0 and in_terminal) {
            var lines: isize = @intFromFloat(wheel * 3);
            if (lines == 0) {
                lines = if (wheel > 0) 1 else -1;
            }
            self.session.scrollBy(lines);
            handled = true;
        }

        if (scrollbar_h > 0 and width > 0 and height > 0 and max_scroll_offset > 0) {
            const track_h = scrollbar_h;
            const min_thumb_h: f32 = 18;
            const thumb_h = @max(min_thumb_h, track_h * (@as(f32, @floatFromInt(rows)) / @as(f32, @floatFromInt(total_lines))));
            const available = @max(@as(f32, 1), track_h - thumb_h);
            const ratio = @as(f32, @floatFromInt(max_scroll_offset - self.session.scrollOffset())) / @as(f32, @floatFromInt(max_scroll_offset));
            const thumb_y = scrollbar_y + available * ratio;
            const thumb_x = scrollbar_x + 2;
            const thumb_w = scrollbar_w - 4;

            const over_thumb = mouse.x >= thumb_x and mouse.x <= thumb_x + thumb_w and mouse.y >= thumb_y and mouse.y <= thumb_y + thumb_h;
            const over_track = mouse.x >= scrollbar_x and mouse.x <= scrollbar_x + scrollbar_w and mouse.y >= scrollbar_y and mouse.y <= scrollbar_y + scrollbar_h;

            if (r.isMouseButtonPressed(renderer_mod.MOUSE_LEFT) and (over_thumb or over_track)) {
                scroll_dragging.* = true;
                scroll_grab_offset.* = if (over_thumb) mouse.y - thumb_y else thumb_h / 2;
                handled = true;
            }

            if (!r.isMouseButtonDown(renderer_mod.MOUSE_LEFT)) {
                scroll_dragging.* = false;
            }

            if (scroll_dragging.*) {
                const new_thumb_y = @min(@max(mouse.y - scroll_grab_offset.*, scrollbar_y), scrollbar_y + available);
                const pos_ratio = (new_thumb_y - scrollbar_y) / available;
                const new_offset = @as(usize, @intFromFloat(@round((1.0 - pos_ratio) * @as(f32, @floatFromInt(max_scroll_offset)))));
                self.session.setScrollOffset(new_offset);
                handled = true;
            }
        } else {
            scroll_dragging.* = false;
        }

        if (rows > 0 and cols > 0) {
            const mouse_pressed = r.isMouseButtonPressed(renderer_mod.MOUSE_LEFT);
            const middle_pressed = r.isMouseButtonPressed(renderer_mod.MOUSE_MIDDLE);
            const mouse_down = r.isMouseButtonDown(renderer_mod.MOUSE_LEFT);
            const over_scrollbar = mouse.x >= scrollbar_x and mouse.x <= scrollbar_x + scrollbar_w and mouse.y >= scrollbar_y and mouse.y <= scrollbar_y + scrollbar_h;

            if (mouse_pressed and !in_terminal) {
                if (self.session.selectionState() != null) {
                    self.session.clearSelection();
                    handled = true;
                }
            }

            if (mouse_pressed and in_terminal and !over_scrollbar) {
                const total_lines_select = history_len + rows;
                if (total_lines_select > 0) {
                    var col: usize = 0;
                    if (mouse.x > x) {
                        col = @as(usize, @intFromFloat((mouse.x - x) / r.terminal_cell_width));
                    }
                    var row: usize = 0;
                    if (mouse.y > y) {
                        row = @as(usize, @intFromFloat((mouse.y - y) / r.terminal_cell_height));
                    }
                    row = @min(row, rows - 1);
                    col = @min(col, cols - 1);

                    const end_line = total_lines_select - self.session.scrollOffset();
                    const start_line = if (end_line > rows) end_line - rows else 0;
                    const global_row = @min(start_line + row, total_lines_select - 1);

                    self.session.startSelection(global_row, col);
                    handled = true;
                }
            }

            if (allow_input and middle_pressed and in_terminal and !over_scrollbar) {
                if (r.getClipboardText()) |clip| {
                    if (self.session.selectionState() != null) {
                        self.session.clearSelection();
                    }
                    if (self.session.scrollOffset() > 0) {
                        self.session.setScrollOffset(0);
                    }
                    if (self.session.bracketedPasteEnabled()) {
                        try self.session.sendText("\x1b[200~");
                        var filtered = std.ArrayList(u8).empty;
                        defer filtered.deinit(self.session.allocator);
                        for (clip) |b| {
                            if (b == 0x1b or b == 0x03) continue;
                            try filtered.append(self.session.allocator, b);
                        }
                        if (filtered.items.len > 0) {
                            try self.session.sendText(filtered.items);
                        }
                        try self.session.sendText("\x1b[201~");
                    } else {
                        try self.session.sendText(clip);
                    }
                    handled = true;
                }
            }

            if (mouse_down and !scroll_dragging.*) {
                if (self.session.selectionState()) |selection| {
                    if (selection.selecting) {
                        const total_lines_select = history_len + rows;
                        if (total_lines_select > 0) {
                            var col: usize = 0;
                            if (mouse.x > x) {
                                col = @as(usize, @intFromFloat((mouse.x - x) / r.terminal_cell_width));
                            }
                            var row: usize = 0;
                            if (mouse.y > y) {
                                row = @as(usize, @intFromFloat((mouse.y - y) / r.terminal_cell_height));
                            }
                            row = @min(row, rows - 1);
                            col = @min(col, cols - 1);

                            const end_line = total_lines_select - self.session.scrollOffset();
                            const start_line = if (end_line > rows) end_line - rows else 0;
                            const global_row = @min(start_line + row, total_lines_select - 1);

                            self.session.updateSelection(global_row, col);
                            handled = true;
                        }
                    }
                }
            }

            if (!mouse_down) {
                if (self.session.selectionState()) |selection| {
                    if (selection.selecting) {
                        self.session.finishSelection();
                        handled = true;
                    }
                }
            }
        }

        return handled;
    }
};

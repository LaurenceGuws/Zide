const std = @import("std");
const renderer_mod = @import("renderer.zig");
const editor_mod = @import("../editor/editor.zig");
const terminal_mod = @import("../terminal/terminal.zig");
const syntax_mod = @import("../editor/syntax.zig");

const Renderer = renderer_mod.Renderer;
const Color = renderer_mod.Color;
const Editor = editor_mod.Editor;
const TerminalSession = terminal_mod.TerminalSession;

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
            r.drawText(tab.title, title_x + prefix_width, title_y, if (is_active) Color.fg else Color.comment);

            cursor_x += tab_width + 1;
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
        for (labels) |label| {
            r.drawText(label, x, y, Color.comment);
            x += @as(f32, @floatFromInt(label.len)) * r.char_width + 16;
        }

    }
};

/// Side navigation bar (VSCode activity bar)
pub const SideNav = struct {
    width: f32 = 52,

    pub fn draw(self: *SideNav, r: *Renderer, height: f32, y: f32) void {
        // Background
        r.drawRect(0, @intFromFloat(y), @intFromFloat(self.width), @intFromFloat(height), Color{ .r = 30, .g = 31, .b = 41 });

        // Simple icon placeholders
        const icon_size: f32 = 20;
        const spacing: f32 = 16;
        var icon_y: f32 = y + 12;
        var i: usize = 0;
        while (i < 5) : (i += 1) {
            const icon_x: f32 = (self.width - icon_size) / 2;
            const icon_color = if (i == 0) Color.purple else Color.comment;
            r.drawRect(@intFromFloat(icon_x), @intFromFloat(icon_y), @intFromFloat(icon_size), @intFromFloat(icon_size), icon_color);
            icon_y += icon_size + spacing;
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

        // Mode indicator
        const mode_bg = if (std.mem.eql(u8, mode, "INSERT"))
            Color.green
        else if (std.mem.eql(u8, mode, "VISUAL"))
            Color.purple
        else
            Color.cyan;

        r.drawRect(0, @intFromFloat(y), 80, @intFromFloat(self.height), mode_bg);
        r.drawText(mode, 8, y + 4, Color.black);

        // File path
        var x: f32 = 88;
        if (file_path) |path| {
            r.drawText(path, x, y + 4, Color.fg);
            x += @as(f32, @floatFromInt(path.len)) * r.char_width + 16;
        }

        // Modified indicator
        if (modified) {
            r.drawText("[+]", x, y + 4, Color.orange);
        }

        // Line/column
        var pos_buf: [32]u8 = undefined;
        const pos_str = std.fmt.bufPrint(&pos_buf, "Ln {d}, Col {d}", .{ line + 1, col + 1 }) catch return;
        const pos_width = @as(f32, @floatFromInt(pos_str.len)) * r.char_width;
        r.drawText(pos_str, width - pos_width - 16, y + 4, Color.comment);
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

            r.drawEditorLine(line_idx, line_text, line_y, x, self.gutter_width, width, is_current);
        }

        // Draw cursor
        const cursor_x = x + self.gutter_width + 8 + @as(f32, @floatFromInt(self.editor.cursor.col)) * r.char_width;
        const cursor_y = y + @as(f32, @floatFromInt(self.editor.cursor.line - start_line)) * r.char_height;
        if (self.editor.cursor.line >= start_line and self.editor.cursor.line < end_line) {
            r.drawCursor(cursor_x, cursor_y, .line);
        }

    }

    pub fn handleInput(self: *EditorWidget, r: *Renderer) !void {
        // Character input
        while (r.getCharPressed()) |char| {
            if (char >= 32 and char < 127) {
                try self.editor.insertChar(@intCast(char));
            }
        }

        // Control keys
        const ctrl = r.isKeyDown(renderer_mod.KEY_LEFT_CONTROL) or r.isKeyDown(renderer_mod.KEY_RIGHT_CONTROL);

        if (r.isKeyPressed(renderer_mod.KEY_ENTER)) {
            try self.editor.insertNewline();
        } else if (r.isKeyPressed(renderer_mod.KEY_BACKSPACE)) {
            try self.editor.deleteCharBackward();
        } else if (r.isKeyPressed(renderer_mod.KEY_DELETE)) {
            try self.editor.deleteCharForward();
        } else if (r.isKeyPressed(renderer_mod.KEY_UP)) {
            self.editor.moveCursorUp();
        } else if (r.isKeyPressed(renderer_mod.KEY_DOWN)) {
            self.editor.moveCursorDown();
        } else if (r.isKeyPressed(renderer_mod.KEY_LEFT)) {
            self.editor.moveCursorLeft();
        } else if (r.isKeyPressed(renderer_mod.KEY_RIGHT)) {
            self.editor.moveCursorRight();
        } else if (r.isKeyPressed(renderer_mod.KEY_HOME)) {
            self.editor.moveCursorToLineStart();
        } else if (r.isKeyPressed(renderer_mod.KEY_END)) {
            self.editor.moveCursorToLineEnd();
        } else if (ctrl and r.isKeyPressed(renderer_mod.KEY_S)) {
            try self.editor.save();
        } else if (ctrl and r.isKeyPressed(renderer_mod.KEY_Z)) {
            _ = try self.editor.undo();
        } else if (ctrl and r.isKeyPressed(renderer_mod.KEY_Y)) {
            _ = try self.editor.redo();
        }

        // Scroll handling
        const wheel = r.getMouseWheelMove();
        if (wheel != 0) {
            const delta = @as(i32, @intFromFloat(-wheel * 3));
            const new_scroll = @as(i64, @intCast(self.editor.scroll_line)) + delta;
            self.editor.scroll_line = @intCast(@max(0, @min(new_scroll, @as(i64, @intCast(self.editor.lineCount())))));
        }
    }
};

/// Terminal widget for drawing a terminal view
pub const TerminalWidget = struct {
    session: *TerminalSession,
    scroll_offset: usize,

    pub fn init(session: *TerminalSession) TerminalWidget {
        return .{
            .session = session,
            .scroll_offset = 0,
        };
    }

    pub fn draw(self: *TerminalWidget, r: *Renderer, x: f32, y: f32, width: f32, height: f32) void {
        const cursor = self.session.getCursorPos();

        // No clipping - let icons overflow freely
        // (sidebar draws last to cover any left overflow, right overflow goes into empty space)
        _ = width;
        _ = height;

        // Pass 1: draw backgrounds so glyphs aren't overwritten by neighbor cells.
        var row: usize = 0;
        while (row < self.session.rows) : (row += 1) {
            var col: usize = 0;
            while (col < self.session.cols) : (col += 1) {
                const cell = self.session.getCell(row, col);

                const cell_x = x + @as(f32, @floatFromInt(col)) * r.terminal_cell_width;
                const cell_y = y + @as(f32, @floatFromInt(row)) * r.terminal_cell_height;
                const cell_w = r.terminal_cell_width * @as(f32, @floatFromInt(@max(1, cell.width)));

                const is_cursor = row == cursor.row and col == cursor.col;

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

                r.drawRect(
                    @intFromFloat(cell_x),
                    @intFromFloat(cell_y),
                    @intFromFloat(cell_w),
                    @intFromFloat(r.terminal_cell_height),
                    if (is_cursor) fg else if (cell.attrs.reverse) fg else bg,
                );

                if (cell.width > 1) {
                    col += cell.width - 1;
                }
            }
        }

        // Pass 2: draw glyphs
        var glyph_row: usize = 0;
        while (glyph_row < self.session.rows) : (glyph_row += 1) {
            var col: usize = 0;
            while (col < self.session.cols) : (col += 1) {
                const cell = self.session.getCell(glyph_row, col);

                const cell_x = x + @as(f32, @floatFromInt(col)) * r.terminal_cell_width;
                const cell_y = y + @as(f32, @floatFromInt(glyph_row)) * r.terminal_cell_height;

                const is_cursor = glyph_row == cursor.row and col == cursor.col;

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

                r.drawTerminalCell(
                    cell.codepoint,
                    cell_x,
                    cell_y,
                    if (cell.attrs.reverse) bg else fg,
                    if (cell.attrs.reverse) fg else bg,
                    cell.attrs.bold,
                    is_cursor,
                );

                // Skip wide characters
                if (cell.width > 1) {
                    col += cell.width - 1;
                }
            }
        }
    }

    pub fn handleInput(self: *TerminalWidget, r: *Renderer) !void {
        // Character input
        while (r.getCharPressed()) |char| {
            try self.session.sendChar(char, terminal_mod.VTERM_MOD_NONE);
        }

        // Special keys
        if (r.isKeyPressed(renderer_mod.KEY_ENTER)) {
            try self.session.sendKey(terminal_mod.VTERM_KEY_ENTER, terminal_mod.VTERM_MOD_NONE);
        } else if (r.isKeyPressed(renderer_mod.KEY_BACKSPACE)) {
            try self.session.sendKey(terminal_mod.VTERM_KEY_BACKSPACE, terminal_mod.VTERM_MOD_NONE);
        } else if (r.isKeyPressed(renderer_mod.KEY_TAB)) {
            try self.session.sendKey(terminal_mod.VTERM_KEY_TAB, terminal_mod.VTERM_MOD_NONE);
        } else if (r.isKeyPressed(renderer_mod.KEY_ESCAPE)) {
            try self.session.sendKey(terminal_mod.VTERM_KEY_ESCAPE, terminal_mod.VTERM_MOD_NONE);
        } else if (r.isKeyPressed(renderer_mod.KEY_UP)) {
            try self.session.sendKey(terminal_mod.VTERM_KEY_UP, terminal_mod.VTERM_MOD_NONE);
        } else if (r.isKeyPressed(renderer_mod.KEY_DOWN)) {
            try self.session.sendKey(terminal_mod.VTERM_KEY_DOWN, terminal_mod.VTERM_MOD_NONE);
        } else if (r.isKeyPressed(renderer_mod.KEY_LEFT)) {
            try self.session.sendKey(terminal_mod.VTERM_KEY_LEFT, terminal_mod.VTERM_MOD_NONE);
        } else if (r.isKeyPressed(renderer_mod.KEY_RIGHT)) {
            try self.session.sendKey(terminal_mod.VTERM_KEY_RIGHT, terminal_mod.VTERM_MOD_NONE);
        }
    }
};

const std = @import("std");
const buffer_mod = @import("buffer.zig");
const types = @import("types.zig");
const syntax_mod = @import("syntax.zig");

const TextBuffer = buffer_mod.TextBuffer;
const CursorPos = types.CursorPos;
const Selection = types.Selection;

/// High-level editor state wrapping a text buffer
pub const Editor = struct {
    allocator: std.mem.Allocator,
    buffer: *TextBuffer,
    cursor: CursorPos,
    selection: ?Selection,
    scroll_line: usize,
    scroll_col: usize,
    highlighter: ?*syntax_mod.SyntaxHighlighter,
    file_path: ?[]const u8,
    modified: bool,
    tab_width: usize,

    pub fn init(allocator: std.mem.Allocator) !*Editor {
        const buffer = try buffer_mod.createBuffer(allocator, "");
        return initWithBuffer(allocator, buffer);
    }

    pub fn initWithBuffer(allocator: std.mem.Allocator, buffer: *TextBuffer) !*Editor {
        const editor = try allocator.create(Editor);
        editor.* = .{
            .allocator = allocator,
            .buffer = buffer,
            .cursor = .{ .line = 0, .col = 0, .offset = 0 },
            .selection = null,
            .scroll_line = 0,
            .scroll_col = 0,
            .highlighter = null,
            .file_path = null,
            .modified = false,
            .tab_width = 4,
        };
        return editor;
    }

    pub fn deinit(self: *Editor) void {
        if (self.highlighter) |h| {
            h.destroy();
        }
        if (self.file_path) |path| {
            self.allocator.free(path);
        }
        buffer_mod.destroyBuffer(self.buffer);
        self.allocator.destroy(self);
    }

    pub fn openFile(self: *Editor, path: []const u8) !void {
        // Clean up old state
        if (self.highlighter) |h| {
            h.destroy();
            self.highlighter = null;
        }
        buffer_mod.destroyBuffer(self.buffer);

        // Create new buffer from file
        self.buffer = try buffer_mod.createBufferFromFile(self.allocator, path);

        // Store path
        if (self.file_path) |old_path| {
            self.allocator.free(old_path);
        }
        self.file_path = try self.allocator.dupe(u8, path);

        // Reset state
        self.cursor = .{ .line = 0, .col = 0, .offset = 0 };
        self.selection = null;
        self.scroll_line = 0;
        self.scroll_col = 0;
        self.modified = false;
    }

    pub fn save(self: *Editor) !void {
        if (self.file_path) |path| {
            try buffer_mod.saveToFile(self.buffer, path);
            self.modified = false;
        }
    }

    pub fn saveAs(self: *Editor, path: []const u8) !void {
        try buffer_mod.saveToFile(self.buffer, path);
        if (self.file_path) |old_path| {
            self.allocator.free(old_path);
        }
        self.file_path = try self.allocator.dupe(u8, path);
        self.modified = false;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Cursor movement
    // ─────────────────────────────────────────────────────────────────────────

    pub fn moveCursorLeft(self: *Editor) void {
        if (self.cursor.offset == 0) return;
        self.cursor.offset -= 1;
        self.updateCursorPosition();
        self.selection = null;
    }

    pub fn moveCursorRight(self: *Editor) void {
        const total = buffer_mod.totalLen(self.buffer);
        if (self.cursor.offset >= total) return;
        self.cursor.offset += 1;
        self.updateCursorPosition();
        self.selection = null;
    }

    pub fn moveCursorUp(self: *Editor) void {
        if (self.cursor.line == 0) return;
        const target_col = self.cursor.col;
        self.cursor.line -= 1;
        const line_len = buffer_mod.lineLen(self.buffer, self.cursor.line);
        self.cursor.col = @min(target_col, line_len);
        self.updateCursorOffset();
        self.selection = null;
    }

    pub fn moveCursorDown(self: *Editor) void {
        const line_count = buffer_mod.lineCount(self.buffer);
        if (self.cursor.line + 1 >= line_count) return;
        const target_col = self.cursor.col;
        self.cursor.line += 1;
        const line_len = buffer_mod.lineLen(self.buffer, self.cursor.line);
        self.cursor.col = @min(target_col, line_len);
        self.updateCursorOffset();
        self.selection = null;
    }

    pub fn moveCursorToLineStart(self: *Editor) void {
        self.cursor.col = 0;
        self.updateCursorOffset();
        self.selection = null;
    }

    pub fn moveCursorToLineEnd(self: *Editor) void {
        const line_len = buffer_mod.lineLen(self.buffer, self.cursor.line);
        self.cursor.col = line_len;
        self.updateCursorOffset();
        self.selection = null;
    }

    fn updateCursorPosition(self: *Editor) void {
        self.cursor.line = buffer_mod.lineIndexForOffset(self.buffer, self.cursor.offset);
        const line_start = buffer_mod.lineStart(self.buffer, self.cursor.line);
        self.cursor.col = self.cursor.offset - line_start;
    }

    fn updateCursorOffset(self: *Editor) void {
        const line_start = buffer_mod.lineStart(self.buffer, self.cursor.line);
        self.cursor.offset = line_start + self.cursor.col;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Text editing
    // ─────────────────────────────────────────────────────────────────────────

    pub fn insertChar(self: *Editor, char: u8) !void {
        try self.deleteSelection();
        const bytes = [_]u8{char};
        try buffer_mod.insertBytes(self.buffer, self.cursor.offset, &bytes);
        self.cursor.offset += 1;
        self.updateCursorPosition();
        self.modified = true;
        if (self.highlighter) |h| {
            _ = h.reparse();
        }
    }

    pub fn insertText(self: *Editor, text: []const u8) !void {
        try self.deleteSelection();
        try buffer_mod.insertBytes(self.buffer, self.cursor.offset, text);
        self.cursor.offset += text.len;
        self.updateCursorPosition();
        self.modified = true;
        if (self.highlighter) |h| {
            _ = h.reparse();
        }
    }

    pub fn insertNewline(self: *Editor) !void {
        try self.insertChar('\n');
    }

    pub fn deleteCharBackward(self: *Editor) !void {
        if (self.selection) |_| {
            try self.deleteSelection();
            return;
        }
        if (self.cursor.offset == 0) return;
        try buffer_mod.deleteRange(self.buffer, self.cursor.offset - 1, 1);
        self.cursor.offset -= 1;
        self.updateCursorPosition();
        self.modified = true;
        if (self.highlighter) |h| {
            _ = h.reparse();
        }
    }

    pub fn deleteCharForward(self: *Editor) !void {
        if (self.selection) |_| {
            try self.deleteSelection();
            return;
        }
        const total = buffer_mod.totalLen(self.buffer);
        if (self.cursor.offset >= total) return;
        try buffer_mod.deleteRange(self.buffer, self.cursor.offset, 1);
        self.modified = true;
        if (self.highlighter) |h| {
            _ = h.reparse();
        }
    }

    pub fn deleteSelection(self: *Editor) !void {
        if (self.selection) |sel| {
            const norm = sel.normalized();
            const len = norm.end.offset - norm.start.offset;
            if (len > 0) {
                try buffer_mod.deleteRange(self.buffer, norm.start.offset, len);
                self.cursor = norm.start;
                self.modified = true;
                if (self.highlighter) |h| {
                    _ = h.reparse();
                }
            }
            self.selection = null;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Undo/Redo
    // ─────────────────────────────────────────────────────────────────────────

    pub fn undo(self: *Editor) !bool {
        const result = try buffer_mod.undo(self.buffer);
        if (result) {
            self.updateCursorPosition();
            if (self.highlighter) |h| {
                _ = h.reparse();
            }
        }
        return result;
    }

    pub fn redo(self: *Editor) !bool {
        const result = try buffer_mod.redo(self.buffer);
        if (result) {
            self.updateCursorPosition();
            if (self.highlighter) |h| {
                _ = h.reparse();
            }
        }
        return result;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Queries
    // ─────────────────────────────────────────────────────────────────────────

    pub fn lineCount(self: *Editor) usize {
        return buffer_mod.lineCount(self.buffer);
    }

    pub fn totalLen(self: *Editor) usize {
        return buffer_mod.totalLen(self.buffer);
    }

    pub fn getLine(self: *Editor, line_index: usize, out: []u8) usize {
        return buffer_mod.readLine(self.buffer, line_index, out);
    }

    pub fn getLineAlloc(self: *Editor, line_index: usize) ![]u8 {
        const len = buffer_mod.lineLen(self.buffer, line_index);
        if (len == 0) return try self.allocator.alloc(u8, 0);
        const out = try self.allocator.alloc(u8, len);
        const read = buffer_mod.readLine(self.buffer, line_index, out);
        if (read < len) {
            return self.allocator.realloc(out, read);
        }
        return out;
    }
};

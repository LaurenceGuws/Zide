const std = @import("std");
const text_store = @import("text_store.zig");
const types = @import("types.zig");
const syntax_mod = @import("syntax.zig");
const app_logger = @import("../app_logger.zig");

const TextStore = text_store.TextStore;
const CursorPos = types.CursorPos;
const Selection = types.Selection;

/// High-level editor state wrapping a text buffer
pub const Editor = struct {
    allocator: std.mem.Allocator,
    buffer: *TextStore,
    cursor: CursorPos,
    selection: ?Selection,
    selections: std.ArrayList(Selection),
    scroll_line: usize,
    scroll_col: usize,
    highlighter: ?*syntax_mod.SyntaxHighlighter,
    highlight_pending: bool,
    file_path: ?[]const u8,
    modified: bool,
    tab_width: usize,

    pub fn init(allocator: std.mem.Allocator) !*Editor {
        const buffer = try text_store.TextStore.init(allocator, "");
        return initWithStore(allocator, buffer);
    }

    pub fn initWithStore(allocator: std.mem.Allocator, buffer: *TextStore) !*Editor {
        const editor = try allocator.create(Editor);
        editor.* = .{
            .allocator = allocator,
            .buffer = buffer,
            .cursor = .{ .line = 0, .col = 0, .offset = 0 },
            .selection = null,
            .selections = .empty,
            .scroll_line = 0,
            .scroll_col = 0,
            .highlighter = null,
            .highlight_pending = false,
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
        self.selections.deinit(self.allocator);
        self.buffer.deinit();
        self.allocator.destroy(self);
    }

    pub fn openFile(self: *Editor, path: []const u8) !void {
        const log = app_logger.logger("editor.core");
        log.logf("openFile path=\"{s}\"", .{path});
        // Clean up old state
        if (self.highlighter) |h| {
            h.destroy();
            self.highlighter = null;
        }
        self.buffer.deinit();

        // Create new buffer from file
        self.buffer = try text_store.TextStore.initFromFile(self.allocator, path);

        // Store path
        if (self.file_path) |old_path| {
            self.allocator.free(old_path);
        }
        self.file_path = try self.allocator.dupe(u8, path);

        // Reset state
        self.cursor = .{ .line = 0, .col = 0, .offset = 0 };
        self.selection = null;
        self.clearSelections();
        self.scroll_line = 0;
        self.scroll_col = 0;
        self.modified = false;

        self.scheduleHighlighter(path);
    }

    pub fn save(self: *Editor) !void {
        if (self.file_path) |path| {
            const log = app_logger.logger("editor.core");
            log.logf("save path=\"{s}\"", .{path});
            try self.buffer.saveToFile(path);
            self.modified = false;
        }
    }

    pub fn saveAs(self: *Editor, path: []const u8) !void {
        const log = app_logger.logger("editor.core");
        log.logf("saveAs path=\"{s}\"", .{path});
        try self.buffer.saveToFile(path);
        if (self.file_path) |old_path| {
            self.allocator.free(old_path);
        }
        self.file_path = try self.allocator.dupe(u8, path);
        self.modified = false;
        try self.tryInitHighlighter(path);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Cursor movement
    // ─────────────────────────────────────────────────────────────────────────

    pub fn moveCursorLeft(self: *Editor) void {
        if (self.cursor.offset == 0) return;
        self.cursor.offset -= 1;
        self.updateCursorPosition();
        self.selection = null;
        self.clearSelections();
    }

    pub fn moveCursorRight(self: *Editor) void {
        const total = self.buffer.totalLen();
        if (self.cursor.offset >= total) return;
        self.cursor.offset += 1;
        self.updateCursorPosition();
        self.selection = null;
        self.clearSelections();
    }

    pub fn moveCursorUp(self: *Editor) void {
        if (self.cursor.line == 0) return;
        const target_col = self.cursor.col;
        self.cursor.line -= 1;
        const line_len = self.buffer.lineLen(self.cursor.line);
        self.cursor.col = @min(target_col, line_len);
        self.updateCursorOffset();
        self.selection = null;
        self.clearSelections();
    }

    pub fn moveCursorDown(self: *Editor) void {
        const line_count = self.buffer.lineCount();
        if (self.cursor.line + 1 >= line_count) return;
        const target_col = self.cursor.col;
        self.cursor.line += 1;
        const line_len = self.buffer.lineLen(self.cursor.line);
        self.cursor.col = @min(target_col, line_len);
        self.updateCursorOffset();
        self.selection = null;
        self.clearSelections();
    }

    pub fn moveCursorToLineStart(self: *Editor) void {
        self.cursor.col = 0;
        self.updateCursorOffset();
        self.selection = null;
        self.clearSelections();
    }

    pub fn moveCursorToLineEnd(self: *Editor) void {
        const line_len = self.buffer.lineLen(self.cursor.line);
        self.cursor.col = line_len;
        self.updateCursorOffset();
        self.selection = null;
        self.clearSelections();
    }

    pub fn setCursor(self: *Editor, line: usize, col: usize) void {
        self.cursor.line = line;
        self.cursor.col = col;
        self.updateCursorOffset();
        self.selection = null;
        self.clearSelections();
    }

    pub fn setCursorNoClear(self: *Editor, line: usize, col: usize) void {
        self.cursor.line = line;
        self.cursor.col = col;
        self.updateCursorOffset();
    }

    pub fn setCursorOffsetNoClear(self: *Editor, offset: usize) void {
        self.cursor.offset = offset;
        self.updateCursorPosition();
    }

    pub fn clearSelections(self: *Editor) void {
        self.selections.clearRetainingCapacity();
    }

    pub fn addSelection(self: *Editor, selection: Selection) !void {
        try self.selections.append(self.allocator, selection);
    }

    pub fn selectionCount(self: *Editor) usize {
        return self.selections.items.len;
    }

    pub fn selectionAt(self: *Editor, index: usize) ?Selection {
        if (index >= self.selections.items.len) return null;
        return self.selections.items[index];
    }

    pub fn normalizeSelections(self: *Editor) !void {
        if (self.selections.items.len == 0) return;
        for (self.selections.items) |*sel| {
            sel.* = sel.normalized();
        }
        std.sort.block(Selection, self.selections.items, {}, struct {
            fn lessThan(_: void, a: Selection, b: Selection) bool {
                return a.start.offset < b.start.offset;
            }
        }.lessThan);

        var merged = std.ArrayList(Selection).empty;
        defer merged.deinit(self.allocator);
        try merged.append(self.allocator, self.selections.items[0]);
        for (self.selections.items[1..]) |sel| {
            var last = &merged.items[merged.items.len - 1];
            if (!sel.is_rectangular and !last.is_rectangular and sel.start.offset <= last.end.offset) {
                if (sel.end.offset > last.end.offset) {
                    last.end = sel.end;
                }
            } else {
                try merged.append(self.allocator, sel);
            }
        }
        self.selections.clearRetainingCapacity();
        try self.selections.appendSlice(self.allocator, merged.items);
    }

    pub fn addRectSelection(self: *Editor, start: CursorPos, end: CursorPos) !void {
        try self.selections.append(self.allocator, .{
            .start = start,
            .end = end,
            .is_rectangular = true,
        });
    }

    pub fn expandRectSelection(self: *Editor, start_line: usize, end_line: usize, start_col: usize, end_col: usize) !void {
        if (start_line > end_line) return;
        var line = start_line;
        while (line <= end_line) : (line += 1) {
            const line_start = self.buffer.lineStart(line);
            const line_len = self.buffer.lineLen(line);
            const start_clamped = @min(start_col, line_len);
            const end_clamped = @min(end_col, line_len);
            const start = CursorPos{ .line = line, .col = start_clamped, .offset = line_start + start_clamped };
            const end = CursorPos{ .line = line, .col = end_clamped, .offset = line_start + end_clamped };
            try self.addRectSelection(start, end);
        }
    }

    fn normalizeSelectionsDescending(self: *Editor) !void {
        try self.normalizeSelections();
        if (self.selections.items.len == 0) return;
        std.sort.block(Selection, self.selections.items, {}, struct {
            fn lessThan(_: void, a: Selection, b: Selection) bool {
                return a.start.offset > b.start.offset;
            }
        }.lessThan);
    }

    fn updateCursorPosition(self: *Editor) void {
        self.cursor.line = self.buffer.lineIndexForOffset(self.cursor.offset);
        const line_start = self.buffer.lineStart(self.cursor.line);
        self.cursor.col = self.cursor.offset - line_start;
    }

    fn updateCursorOffset(self: *Editor) void {
        const line_start = self.buffer.lineStart(self.cursor.line);
        self.cursor.offset = line_start + self.cursor.col;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Text editing
    // ─────────────────────────────────────────────────────────────────────────

    pub fn insertChar(self: *Editor, char: u8) !void {
        if (self.selections.items.len > 0) {
            self.beginUndoGroup();
            errdefer self.endUndoGroup() catch {};
            try self.normalizeSelectionsDescending();
            const bytes = [_]u8{char};
            for (self.selections.items) |sel| {
                const norm = sel.normalized();
                const len = norm.end.offset - norm.start.offset;
                if (len > 0) {
                    try self.buffer.deleteRange(norm.start.offset, len);
                }
                try self.buffer.insertBytes(norm.start.offset, &bytes);
                self.cursor = norm.start;
                self.cursor.offset += 1;
                self.updateCursorPosition();
            }
            self.modified = true;
            if (self.highlighter) |h| {
                _ = h.reparse();
            }
            self.clearSelections();
            try self.endUndoGroup();
            return;
        }
        if (self.selection != null) {
            self.beginUndoGroup();
            errdefer self.endUndoGroup() catch {};
            try self.deleteSelection();
            const bytes = [_]u8{char};
            try self.buffer.insertBytes(self.cursor.offset, &bytes);
            self.cursor.offset += 1;
            self.updateCursorPosition();
            self.modified = true;
            if (self.highlighter) |h| {
                _ = h.reparse();
            }
            try self.endUndoGroup();
            return;
        }
        const bytes = [_]u8{char};
        try self.buffer.insertBytes(self.cursor.offset, &bytes);
        self.cursor.offset += 1;
        self.updateCursorPosition();
        self.modified = true;
        if (self.highlighter) |h| {
            _ = h.reparse();
        }
    }

    pub fn insertText(self: *Editor, text: []const u8) !void {
        if (self.selections.items.len > 0) {
            self.beginUndoGroup();
            errdefer self.endUndoGroup() catch {};
            try self.normalizeSelectionsDescending();
            for (self.selections.items) |sel| {
                const norm = sel.normalized();
                const len = norm.end.offset - norm.start.offset;
                if (len > 0) {
                    try self.buffer.deleteRange(norm.start.offset, len);
                }
                try self.buffer.insertBytes(norm.start.offset, text);
                self.cursor = norm.start;
            }
            self.modified = true;
            if (self.highlighter) |h| {
                _ = h.reparse();
            }
            self.clearSelections();
            try self.endUndoGroup();
            return;
        }
        if (self.selection != null) {
            self.beginUndoGroup();
            errdefer self.endUndoGroup() catch {};
            try self.deleteSelection();
            try self.buffer.insertBytes(self.cursor.offset, text);
            self.cursor.offset += text.len;
            self.updateCursorPosition();
            self.modified = true;
            if (self.highlighter) |h| {
                _ = h.reparse();
            }
            try self.endUndoGroup();
            return;
        }
        try self.buffer.insertBytes(self.cursor.offset, text);
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
        try self.buffer.deleteRange(self.cursor.offset - 1, 1);
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
        const total = self.buffer.totalLen();
        if (self.cursor.offset >= total) return;
        try self.buffer.deleteRange(self.cursor.offset, 1);
        self.modified = true;
        if (self.highlighter) |h| {
            _ = h.reparse();
        }
    }

    pub fn deleteSelection(self: *Editor) !void {
        if (self.selections.items.len > 0) {
            try self.normalizeSelectionsDescending();
            var idx: usize = self.selections.items.len;
            while (idx > 0) {
                idx -= 1;
                const sel = self.selections.items[idx];
                const norm = sel.normalized();
                const len = norm.end.offset - norm.start.offset;
                if (len > 0) {
                    try self.buffer.deleteRange(norm.start.offset, len);
                    self.cursor = norm.start;
                    self.modified = true;
                }
            }
            if (self.modified) {
                if (self.highlighter) |h| {
                    _ = h.reparse();
                }
            }
            self.clearSelections();
            self.selection = null;
            return;
        }
        if (self.selection) |sel| {
            const norm = sel.normalized();
            const len = norm.end.offset - norm.start.offset;
            if (len > 0) {
                try self.buffer.deleteRange(norm.start.offset, len);
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

    pub fn beginUndoGroup(self: *Editor) void {
        self.buffer.beginUndoGroup();
    }

    pub fn endUndoGroup(self: *Editor) !void {
        try self.buffer.endUndoGroup();
    }

    pub fn undo(self: *Editor) !bool {
        const result = try self.buffer.undoWithCursor();
        if (result.changed) {
            const log = app_logger.logger("editor.core");
            log.logf("undo ok", .{});
        }
        if (result.changed) {
            if (result.cursor) |cursor_offset| {
                const clamped = @min(cursor_offset, self.buffer.totalLen());
                self.setCursorOffsetNoClear(clamped);
            } else {
                if (self.cursor.offset > self.buffer.totalLen()) {
                    self.cursor.offset = self.buffer.totalLen();
                }
                self.updateCursorPosition();
            }
            if (self.highlighter) |h| {
                _ = h.reparse();
            }
        }
        return result.changed;
    }

    pub fn redo(self: *Editor) !bool {
        const result = try self.buffer.redoWithCursor();
        if (result.changed) {
            const log = app_logger.logger("editor.core");
            log.logf("redo ok", .{});
        }
        if (result.changed) {
            if (result.cursor) |cursor_offset| {
                const clamped = @min(cursor_offset, self.buffer.totalLen());
                self.setCursorOffsetNoClear(clamped);
            } else {
                if (self.cursor.offset > self.buffer.totalLen()) {
                    self.cursor.offset = self.buffer.totalLen();
                }
                self.updateCursorPosition();
            }
            if (self.highlighter) |h| {
                _ = h.reparse();
            }
        }
        return result.changed;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Queries
    // ─────────────────────────────────────────────────────────────────────────

    pub fn lineCount(self: *Editor) usize {
        return self.buffer.lineCount();
    }

    pub fn totalLen(self: *Editor) usize {
        return self.buffer.totalLen();
    }

    pub fn getLine(self: *Editor, line_index: usize, out: []u8) usize {
        return self.buffer.readLine(line_index, out);
    }

    pub fn lineLen(self: *Editor, line_index: usize) usize {
        return self.buffer.lineLen(line_index);
    }

    pub fn lineStart(self: *Editor, line_index: usize) usize {
        return self.buffer.lineStart(line_index);
    }

    pub fn getLineAlloc(self: *Editor, line_index: usize) ![]u8 {
        const len = self.buffer.lineLen(line_index);
        if (len == 0) return try self.allocator.alloc(u8, 0);
        const out = try self.allocator.alloc(u8, len);
        const read = self.buffer.readLine(line_index, out);
        if (read < len) {
            return self.allocator.realloc(out, read);
        }
        return out;
    }

    fn shouldEnableZigHighlight(path: ?[]const u8) bool {
        if (path == null) return true;
        return std.mem.endsWith(u8, path.?, ".zig");
    }

    fn scheduleHighlighter(self: *Editor, path: ?[]const u8) void {
        const log = app_logger.logger("editor.highlight");
        if (!shouldEnableZigHighlight(path)) {
            if (self.highlighter) |h| {
                h.destroy();
                self.highlighter = null;
            }
            self.highlight_pending = false;
            log.logf("highlight disabled path=\"{s}\"", .{path orelse ""});
            return;
        }
        self.highlight_pending = true;
        log.logf("highlight scheduled path=\"{s}\"", .{path orelse ""});
    }

    fn tryInitHighlighter(self: *Editor, path: ?[]const u8) !void {
        const log = app_logger.logger("editor.highlight");
        log.logf("highlight init check path=\"{s}\"", .{path orelse ""});
        self.highlight_pending = false;
        if (!shouldEnableZigHighlight(path)) {
            if (self.highlighter) |h| {
                h.destroy();
                self.highlighter = null;
            }
            log.logf("highlight disabled path=\"{s}\"", .{path orelse ""});
            return;
        }
        if (self.highlighter == null) {
            const t_start = std.time.nanoTimestamp();
            log.logf("highlight init start", .{});
            self.highlighter = try syntax_mod.createZigHighlighter(self.allocator, self.buffer);
            const elapsed_ns = std.time.nanoTimestamp() - t_start;
            log.logf(
                "highlight enabled path=\"{s}\" time_us={d}",
                .{ path orelse "", @as(i64, @intCast(@divTrunc(elapsed_ns, 1000))) },
            );
        }
    }

    pub fn ensureHighlighter(self: *Editor) void {
        if (!self.highlight_pending) return;
        self.tryInitHighlighter(self.file_path) catch {};
    }
};

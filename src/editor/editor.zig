const std = @import("std");
const text_store = @import("text_store.zig");
const types = @import("types.zig");
const syntax_mod = @import("syntax.zig");
const ts_api = @import("treesitter_api.zig");
const grammar_manager_mod = @import("grammar_manager.zig");
const syntax_registry_mod = @import("syntax_registry.zig");
const app_logger = @import("../app_logger.zig");

const TextStore = text_store.TextStore;
const CursorPos = types.CursorPos;
const Selection = types.Selection;
const c = ts_api.c_api;

/// High-level editor state wrapping a text buffer
pub const Editor = struct {
    allocator: std.mem.Allocator,
    buffer: *TextStore,
    cursor: CursorPos,
    preferred_visual_col: ?usize,
    selection: ?Selection,
    selections: std.ArrayList(Selection),
    scroll_line: usize,
    scroll_col: usize,
    scroll_row_offset: usize,
    line_width_cache: std.AutoHashMap(usize, usize),
    max_line_width_cache: usize,
    max_line_width_scan_index: usize,
    max_line_width_scan_complete: bool,
    highlighter: ?*syntax_mod.SyntaxHighlighter,
    highlight_dirty_start_line: ?usize,
    highlight_dirty_end_line: ?usize,
    highlight_pending: bool,
    change_tick: u64,
    highlight_epoch: u64,
    file_path: ?[]const u8,
    modified: bool,
    tab_width: usize,
    grammar_manager: *grammar_manager_mod.GrammarManager,

    pub fn init(allocator: std.mem.Allocator, grammar_manager: *grammar_manager_mod.GrammarManager) !*Editor {
        const buffer = try text_store.TextStore.init(allocator, "");
        return initWithStore(allocator, buffer, grammar_manager);
    }

    pub fn initWithStore(
        allocator: std.mem.Allocator,
        buffer: *TextStore,
        grammar_manager: *grammar_manager_mod.GrammarManager,
    ) !*Editor {
        const editor = try allocator.create(Editor);
        editor.* = .{
            .allocator = allocator,
            .buffer = buffer,
            .cursor = .{ .line = 0, .col = 0, .offset = 0 },
            .preferred_visual_col = null,
            .selection = null,
            .selections = .empty,
            .scroll_line = 0,
            .scroll_col = 0,
            .scroll_row_offset = 0,
            .line_width_cache = std.AutoHashMap(usize, usize).init(allocator),
            .max_line_width_cache = 0,
            .max_line_width_scan_index = 0,
            .max_line_width_scan_complete = false,
            .highlighter = null,
            .highlight_dirty_start_line = null,
            .highlight_dirty_end_line = null,
            .highlight_pending = false,
            .change_tick = 0,
            .highlight_epoch = 0,
            .file_path = null,
            .modified = false,
            .tab_width = 4,
            .grammar_manager = grammar_manager,
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
        self.line_width_cache.deinit();
        self.buffer.deinit();
        self.allocator.destroy(self);
    }

    pub const HighlightDirtyRange = struct {
        start_line: usize,
        end_line: usize,
    };

    pub fn takeHighlightDirtyRange(self: *Editor) ?HighlightDirtyRange {
        if (self.highlight_dirty_start_line == null) return null;
        const start = self.highlight_dirty_start_line.?;
        const end = self.highlight_dirty_end_line orelse (start + 1);
        self.highlight_dirty_start_line = null;
        self.highlight_dirty_end_line = null;
        return .{ .start_line = start, .end_line = end };
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
        self.preferred_visual_col = null;
        self.selection = null;
        self.clearSelections();
        self.scroll_line = 0;
        self.scroll_col = 0;
        self.scroll_row_offset = 0;
        self.invalidateLineWidthCache();
        self.modified = false;
        self.highlight_dirty_start_line = null;
        self.highlight_dirty_end_line = null;

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

    pub fn invalidateLineWidthCache(self: *Editor) void {
        self.line_width_cache.clearRetainingCapacity();
        self.max_line_width_cache = 0;
        self.max_line_width_scan_index = 0;
        self.max_line_width_scan_complete = false;
    }

    pub fn lineWidthCached(self: *Editor, line_idx: usize, line_text: []const u8, cluster_offsets: ?[]const u32) usize {
        if (self.line_width_cache.get(line_idx)) |cached| return cached;
        var count: usize = 0;
        if (cluster_offsets) |clusters| {
            count = clusters.len;
        } else {
            var it = std.unicode.Utf8View.initUnchecked(line_text).iterator();
            while (it.nextCodepointSlice()) |_| {
                count += 1;
            }
        }
        self.line_width_cache.put(line_idx, count) catch {};
        if (count > self.max_line_width_cache) self.max_line_width_cache = count;
        return count;
    }

    pub fn advanceMaxLineWidthCache(self: *Editor, budget_lines: usize) struct { max: usize, complete: bool } {
        if (self.max_line_width_scan_complete) {
            return .{ .max = self.max_line_width_cache, .complete = true };
        }

        const total_lines = self.lineCount();
        var line_idx = self.max_line_width_scan_index;
        var remaining = budget_lines;
        while (line_idx < total_lines and remaining > 0) : (line_idx += 1) {
            var line_buf: [4096]u8 = undefined;
            const line_len = self.lineLen(line_idx);
            var line_alloc: ?[]u8 = null;
            const line_text = if (line_len <= line_buf.len)
                line_buf[0..self.getLine(line_idx, &line_buf)]
            else blk: {
                const owned = self.getLineAlloc(line_idx) catch break :blk &[_]u8{};
                line_alloc = owned;
                break :blk owned;
            };
            defer if (line_alloc) |owned| self.allocator.free(owned);

            const width = self.lineWidthCached(line_idx, line_text, null);
            if (width > self.max_line_width_cache) {
                self.max_line_width_cache = width;
            }
            remaining -= 1;
        }

        self.max_line_width_scan_index = line_idx;
        if (line_idx >= total_lines) {
            self.max_line_width_scan_complete = true;
        }

        return .{ .max = self.max_line_width_cache, .complete = self.max_line_width_scan_complete };
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Cursor movement
    // ─────────────────────────────────────────────────────────────────────────

    pub fn moveCursorLeft(self: *Editor) void {
        if (self.cursor.offset == 0) return;
        self.cursor.offset -= 1;
        self.updateCursorPosition();
        self.preferred_visual_col = null;
        self.selection = null;
        self.clearSelections();
    }

    pub fn moveCursorRight(self: *Editor) void {
        const total = self.buffer.totalLen();
        if (self.cursor.offset >= total) return;
        self.cursor.offset += 1;
        self.updateCursorPosition();
        self.preferred_visual_col = null;
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
        self.preferred_visual_col = null;
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
        self.preferred_visual_col = null;
        self.selection = null;
        self.clearSelections();
    }

    pub fn moveCursorToLineStart(self: *Editor) void {
        self.cursor.col = 0;
        self.updateCursorOffset();
        self.preferred_visual_col = null;
        self.selection = null;
        self.clearSelections();
    }

    pub fn moveCursorToLineEnd(self: *Editor) void {
        const line_len = self.buffer.lineLen(self.cursor.line);
        self.cursor.col = line_len;
        self.updateCursorOffset();
        self.preferred_visual_col = null;
        self.selection = null;
        self.clearSelections();
    }

    pub fn setCursor(self: *Editor, line: usize, col: usize) void {
        self.cursor.line = line;
        self.cursor.col = col;
        self.updateCursorOffset();
        self.preferred_visual_col = null;
        self.selection = null;
        self.clearSelections();
    }

    pub fn setCursorPreservePreferred(self: *Editor, line: usize, col: usize) void {
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
        self.preferred_visual_col = null;
    }

    pub fn setCursorOffsetNoClear(self: *Editor, offset: usize) void {
        self.cursor.offset = offset;
        self.updateCursorPosition();
        self.preferred_visual_col = null;
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

    fn noteTextChanged(self: *Editor) void {
        self.modified = true;
        self.invalidateLineWidthCache();
        self.change_tick +|= 1;
    }

    fn noteHighlightDirtyRange(self: *Editor, start_byte: usize, end_byte: usize) void {
        const start_line = self.buffer.lineIndexForOffset(start_byte);
        const end_line = self.buffer.lineIndexForOffset(end_byte) + 1;
        const start = self.highlight_dirty_start_line orelse start_line;
        const end = self.highlight_dirty_end_line orelse end_line;
        self.highlight_dirty_start_line = @min(start, start_line);
        self.highlight_dirty_end_line = @max(end, end_line);
    }

    fn applyHighlightEdit(
        self: *Editor,
        start_byte: usize,
        old_end_byte: usize,
        new_end_byte: usize,
        start_point: c.TSPoint,
        old_end_point: c.TSPoint,
    ) void {
        if (self.highlighter == null) return;
        const h = self.highlighter.?;
        const new_end_point = self.pointForByte(new_end_byte);
        const ranges = h.applyEdit(
            start_byte,
            old_end_byte,
            new_end_byte,
            start_point,
            old_end_point,
            new_end_point,
            self.allocator,
        ) catch {
            _ = h.reparseFull();
            self.noteHighlightDirtyRange(0, self.buffer.totalLen());
            return;
        };
        defer self.allocator.free(ranges);

        if (ranges.len == 0) {
            const min_byte = @min(start_byte, @min(old_end_byte, new_end_byte));
            const max_byte = @max(start_byte, @max(old_end_byte, new_end_byte));
            self.noteHighlightDirtyRange(min_byte, max_byte);
            return;
        }
        for (ranges) |range| {
            self.noteHighlightDirtyRange(range.start_byte, range.end_byte);
        }
    }

    fn pointForByte(self: *Editor, byte_offset: usize) c.TSPoint {
        const line = self.buffer.lineIndexForOffset(byte_offset);
        const line_start = self.buffer.lineStart(line);
        return .{
            .row = @as(u32, @intCast(line)),
            .column = @as(u32, @intCast(byte_offset - line_start)),
        };
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Text editing
    // ─────────────────────────────────────────────────────────────────────────

    pub fn insertChar(self: *Editor, char: u8) !void {
        self.preferred_visual_col = null;
        if (self.selections.items.len > 0) {
            self.beginUndoGroup();
            errdefer self.endUndoGroup() catch {};
            try self.normalizeSelectionsDescending();
            const bytes = [_]u8{char};
            for (self.selections.items) |sel| {
                const norm = sel.normalized();
                const len = norm.end.offset - norm.start.offset;
                if (len > 0) {
                    const start = norm.start.offset;
                    const end = norm.end.offset;
                    const start_point = self.pointForByte(start);
                    const end_point = self.pointForByte(end);
                    try self.buffer.deleteRange(start, len);
                    self.applyHighlightEdit(start, end, start, start_point, end_point);
                }
                const insert_start = norm.start.offset;
                const insert_point = self.pointForByte(insert_start);
                try self.buffer.insertBytes(insert_start, &bytes);
                self.applyHighlightEdit(insert_start, insert_start, insert_start + 1, insert_point, insert_point);
                self.cursor = norm.start;
                self.cursor.offset += 1;
                self.updateCursorPosition();
            }
            self.noteTextChanged();
            self.clearSelections();
            try self.endUndoGroup();
            return;
        }
        if (self.selection != null) {
            self.beginUndoGroup();
            errdefer self.endUndoGroup() catch {};
            try self.deleteSelection();
            const bytes = [_]u8{char};
            const insert_start = self.cursor.offset;
            const insert_point = self.pointForByte(insert_start);
            try self.buffer.insertBytes(insert_start, &bytes);
            self.applyHighlightEdit(insert_start, insert_start, insert_start + 1, insert_point, insert_point);
            self.cursor.offset += 1;
            self.updateCursorPosition();
            self.noteTextChanged();
            try self.endUndoGroup();
            return;
        }
        const bytes = [_]u8{char};
        const insert_start = self.cursor.offset;
        const insert_point = self.pointForByte(insert_start);
        try self.buffer.insertBytes(insert_start, &bytes);
        self.applyHighlightEdit(insert_start, insert_start, insert_start + 1, insert_point, insert_point);
        self.cursor.offset += 1;
        self.updateCursorPosition();
        self.noteTextChanged();
    }

    pub fn insertText(self: *Editor, text: []const u8) !void {
        self.preferred_visual_col = null;
        if (self.selections.items.len > 0) {
            self.beginUndoGroup();
            errdefer self.endUndoGroup() catch {};
            try self.normalizeSelectionsDescending();
            for (self.selections.items) |sel| {
                const norm = sel.normalized();
                const len = norm.end.offset - norm.start.offset;
                if (len > 0) {
                    const start = norm.start.offset;
                    const end = norm.end.offset;
                    const start_point = self.pointForByte(start);
                    const end_point = self.pointForByte(end);
                    try self.buffer.deleteRange(start, len);
                    self.applyHighlightEdit(start, end, start, start_point, end_point);
                }
                const insert_start = norm.start.offset;
                const insert_point = self.pointForByte(insert_start);
                try self.buffer.insertBytes(insert_start, text);
                self.applyHighlightEdit(insert_start, insert_start, insert_start + text.len, insert_point, insert_point);
                self.cursor = norm.start;
            }
            self.noteTextChanged();
            self.clearSelections();
            try self.endUndoGroup();
            return;
        }
        if (self.selection != null) {
            self.beginUndoGroup();
            errdefer self.endUndoGroup() catch {};
            try self.deleteSelection();
            const insert_start = self.cursor.offset;
            const insert_point = self.pointForByte(insert_start);
            try self.buffer.insertBytes(insert_start, text);
            self.applyHighlightEdit(insert_start, insert_start, insert_start + text.len, insert_point, insert_point);
            self.cursor.offset += text.len;
            self.updateCursorPosition();
            self.noteTextChanged();
            try self.endUndoGroup();
            return;
        }
        const insert_start = self.cursor.offset;
        const insert_point = self.pointForByte(insert_start);
        try self.buffer.insertBytes(insert_start, text);
        self.applyHighlightEdit(insert_start, insert_start, insert_start + text.len, insert_point, insert_point);
        self.cursor.offset += text.len;
        self.updateCursorPosition();
        self.noteTextChanged();
    }

    pub fn insertNewline(self: *Editor) !void {
        try self.insertChar('\n');
    }

    pub fn deleteCharBackward(self: *Editor) !void {
        self.preferred_visual_col = null;
        if (self.selection) |_| {
            try self.deleteSelection();
            return;
        }
        if (self.cursor.offset == 0) return;
        const start = self.cursor.offset - 1;
        const end = self.cursor.offset;
        const start_point = self.pointForByte(start);
        const end_point = self.pointForByte(end);
        try self.buffer.deleteRange(start, 1);
        self.applyHighlightEdit(start, end, start, start_point, end_point);
        self.cursor.offset -= 1;
        self.updateCursorPosition();
        self.noteTextChanged();
    }

    pub fn deleteCharForward(self: *Editor) !void {
        self.preferred_visual_col = null;
        if (self.selection) |_| {
            try self.deleteSelection();
            return;
        }
        const total = self.buffer.totalLen();
        if (self.cursor.offset >= total) return;
        const start = self.cursor.offset;
        const end = self.cursor.offset + 1;
        const start_point = self.pointForByte(start);
        const end_point = self.pointForByte(end);
        try self.buffer.deleteRange(start, 1);
        self.applyHighlightEdit(start, end, start, start_point, end_point);
        self.noteTextChanged();
    }

    pub fn deleteSelection(self: *Editor) !void {
        self.preferred_visual_col = null;
        if (self.selections.items.len > 0) {
            self.beginUndoGroup();
            errdefer self.endUndoGroup() catch {};
            try self.normalizeSelectionsDescending();
            var changed = false;
            var idx: usize = self.selections.items.len;
            while (idx > 0) {
                idx -= 1;
                const sel = self.selections.items[idx];
                const norm = sel.normalized();
                const len = norm.end.offset - norm.start.offset;
                if (len > 0) {
                    const start = norm.start.offset;
                    const end = norm.end.offset;
                    const start_point = self.pointForByte(start);
                    const end_point = self.pointForByte(end);
                    try self.buffer.deleteRange(start, len);
                    self.applyHighlightEdit(start, end, start, start_point, end_point);
                    self.cursor = norm.start;
                    changed = true;
                }
            }
            if (changed) self.noteTextChanged();
            self.clearSelections();
            self.selection = null;
            try self.endUndoGroup();
            return;
        }
        if (self.selection) |sel| {
            const norm = sel.normalized();
            const len = norm.end.offset - norm.start.offset;
            if (len > 0) {
                const start = norm.start.offset;
                const end = norm.end.offset;
                const start_point = self.pointForByte(start);
                const end_point = self.pointForByte(end);
                try self.buffer.deleteRange(start, len);
                self.applyHighlightEdit(start, end, start, start_point, end_point);
                self.cursor = norm.start;
                self.noteTextChanged();
            }
            self.selection = null;
        }
    }

    pub fn selectionTextAlloc(self: *Editor) !?[]u8 {
        var selections = std.ArrayList(Selection).empty;
        defer selections.deinit(self.allocator);

        if (self.selection) |sel| {
            try selections.append(self.allocator, sel.normalized());
        }
        if (self.selections.items.len > 0) {
            for (self.selections.items) |sel| {
                try selections.append(self.allocator, sel.normalized());
            }
        }
        if (selections.items.len == 0) return null;

        std.sort.block(Selection, selections.items, {}, struct {
            fn lessThan(_: void, a: Selection, b: Selection) bool {
                return a.start.offset < b.start.offset;
            }
        }.lessThan);

        var merged = std.ArrayList(Selection).empty;
        defer merged.deinit(self.allocator);
        try merged.append(self.allocator, selections.items[0]);
        for (selections.items[1..]) |sel| {
            var last = &merged.items[merged.items.len - 1];
            if (!sel.is_rectangular and !last.is_rectangular and sel.start.offset <= last.end.offset) {
                if (sel.end.offset > last.end.offset) {
                    last.end = sel.end;
                }
            } else {
                try merged.append(self.allocator, sel);
            }
        }

        var out = std.ArrayList(u8).empty;
        errdefer out.deinit(self.allocator);
        var idx: usize = 0;
        while (idx < merged.items.len) : (idx += 1) {
            const sel = merged.items[idx];
            if (sel.isEmpty()) continue;
            const norm = sel.normalized();
            const len = norm.end.offset - norm.start.offset;
            if (len == 0) continue;
            const chunk = try self.buffer.readRangeAlloc(norm.start.offset, len);
            defer self.allocator.free(chunk);
            try out.appendSlice(self.allocator, chunk);
            if (idx + 1 < merged.items.len) {
                try out.append(self.allocator, '\n');
            }
        }

        return try out.toOwnedSlice(self.allocator);
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
        self.preferred_visual_col = null;
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
                _ = h.reparseFull();
                self.noteHighlightDirtyRange(0, self.buffer.totalLen());
                self.highlight_epoch +|= 1;
            }
            self.invalidateLineWidthCache();
            self.change_tick +|= 1;
        }
        return result.changed;
    }

    pub fn redo(self: *Editor) !bool {
        self.preferred_visual_col = null;
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
                _ = h.reparseFull();
                self.noteHighlightDirtyRange(0, self.buffer.totalLen());
                self.highlight_epoch +|= 1;
            }
            self.invalidateLineWidthCache();
            self.change_tick +|= 1;
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

    fn scheduleHighlighter(self: *Editor, path: ?[]const u8) void {
        const log = app_logger.logger("editor.highlight");
        if (syntax_registry_mod.SyntaxRegistry.resolveLanguage(path) == null) {
            if (self.highlighter) |h| {
                h.destroy();
                self.highlighter = null;
            }
            self.highlight_epoch +|= 1;
            self.highlight_dirty_start_line = null;
            self.highlight_dirty_end_line = null;
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
        const lang = syntax_registry_mod.SyntaxRegistry.resolveLanguage(path);
        if (lang == null) {
            if (self.highlighter) |h| {
                h.destroy();
                self.highlighter = null;
            }
            self.highlight_epoch +|= 1;
            self.highlight_dirty_start_line = null;
            self.highlight_dirty_end_line = null;
            log.logf("highlight disabled path=\"{s}\"", .{path orelse ""});
            return;
        }
        if (self.highlighter == null) {
            const t_start = std.time.nanoTimestamp();
            log.logf("highlight init start", .{});
            const grammar = try self.grammar_manager.getOrLoad(lang.?) orelse {
                log.logf("highlight missing grammar lang={s}", .{lang.?});
                return;
            };
            self.highlighter = syntax_mod.createHighlighterForLanguage(
                self.allocator,
                self.buffer,
                lang.?,
                grammar.ts_language,
                grammar.query_paths,
                self.grammar_manager,
            ) catch |err| {
                log.logf("highlight init failed err={any}", .{err});
                return err;
            };
            self.highlight_epoch +|= 1;
            self.noteHighlightDirtyRange(0, self.buffer.totalLen());
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

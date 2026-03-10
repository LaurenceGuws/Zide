const std = @import("std");
const text_store = @import("text_store.zig");
const text_columns = @import("text_columns.zig");
const types = @import("types.zig");
const syntax_mod = @import("syntax.zig");
const ts_api = @import("treesitter_api.zig");
const grammar_manager_mod = @import("grammar_manager.zig");
const editor_search_highlight = @import("search_highlight.zig");
const editor_selection_state = @import("selection_state.zig");
const editor_navigation = @import("navigation.zig");
const app_logger = @import("../app_logger.zig");

const TextStore = text_store.TextStore;
const CursorPos = types.CursorPos;
const Selection = types.Selection;
const c = ts_api.c_api;

/// High-level editor state wrapping a text buffer
pub const Editor = struct {
    const highlighter_large_file_threshold_bytes: usize = 8 * 1024 * 1024;
    const SearchHighlight = editor_search_highlight.SearchHighlightOps(@This());
    const SelectionState = editor_selection_state.SelectionStateOps(@This());
    const Navigation = editor_navigation.NavigationOps(@This());

    pub const ClusterProvider = struct {
        ctx: *anyopaque,
        getClusters: *const fn (ctx: *anyopaque, line_idx: usize, line_text: []const u8) ?[]const u32,
    };

    const StoredSelection = editor_selection_state.StoredSelection;
    const UndoSelectionState = editor_selection_state.UndoSelectionState;
    const SelectionReplacementOp = editor_selection_state.SelectionReplacementOp;

    pub const SearchMatch = editor_search_highlight.SearchMatch;
    pub const SearchMode = editor_search_highlight.SearchMode;
    const SearchWorkRequest = editor_search_highlight.SearchWorkRequest;
    const SearchWorkResult = editor_search_highlight.SearchWorkResult;
    pub const HighlightDirtyRange = editor_search_highlight.HighlightDirtyRange;

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
    highlighter: ?*syntax_mod.SyntaxHighlighter,
    highlight_dirty_start_line: ?usize,
    highlight_dirty_end_line: ?usize,
    highlight_pending: bool,
    highlight_disabled_for_large_file: bool,
    search_query: ?[]u8,
    search_matches: std.ArrayList(SearchMatch),
    search_active: ?usize,
    search_mode: SearchMode,
    search_epoch: u64,
    search_worker: ?std.Thread,
    search_worker_running: bool,
    search_mutex: std.Thread.Mutex,
    search_cond: std.Thread.Condition,
    search_generation: u64,
    search_request: ?SearchWorkRequest,
    search_result: ?SearchWorkResult,
    change_tick: u64,
    highlight_epoch: u64,
    file_path: ?[]const u8,
    modified: bool,
    tab_width: usize,
    grammar_manager: *grammar_manager_mod.GrammarManager,
    undo_selection_states: std.ArrayList(UndoSelectionState),
    next_undo_selection_state_id: u64,

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
            .highlighter = null,
            .highlight_dirty_start_line = null,
            .highlight_dirty_end_line = null,
            .highlight_pending = false,
            .highlight_disabled_for_large_file = buffer.totalLen() >= highlighter_large_file_threshold_bytes,
            .search_query = null,
            .search_matches = .empty,
            .search_active = null,
            .search_mode = .literal,
            .search_epoch = 0,
            .search_worker = null,
            .search_worker_running = false,
            .search_mutex = .{},
            .search_cond = .{},
            .search_generation = 0,
            .search_request = null,
            .search_result = null,
            .change_tick = 0,
            .highlight_epoch = 0,
            .file_path = null,
            .modified = false,
            .tab_width = 4,
            .grammar_manager = grammar_manager,
            .undo_selection_states = .empty,
            .next_undo_selection_state_id = 1,
        };
        return editor;
    }

    pub fn deinit(self: *Editor) void {
        self.stopSearchWorker();
        if (self.highlighter) |h| {
            h.destroy();
        }
        if (self.file_path) |path| {
            self.allocator.free(path);
        }
        if (self.search_query) |query| {
            self.allocator.free(query);
        }
        self.search_matches.deinit(self.allocator);
        for (self.undo_selection_states.items) |state| {
            self.allocator.free(state.selections);
        }
        self.undo_selection_states.deinit(self.allocator);
        self.selections.deinit(self.allocator);
        self.line_width_cache.deinit();
        self.buffer.deinit();
        self.allocator.destroy(self);
    }

    pub fn openFile(self: *Editor, path: []const u8) !void {
        const log = app_logger.logger("editor.core");
        log.logf(.info, "openFile path=\"{s}\"", .{path});
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
        self.highlight_disabled_for_large_file = self.buffer.totalLen() >= highlighter_large_file_threshold_bytes;

        self.scheduleHighlighter(path);
    }

    pub fn save(self: *Editor) !void {
        if (self.file_path) |path| {
            const log = app_logger.logger("editor.core");
            log.logf(.info, "save path=\"{s}\"", .{path});
            try self.buffer.saveToFile(path);
            self.modified = false;
        }
    }

    pub fn saveAs(self: *Editor, path: []const u8) !void {
        const log = app_logger.logger("editor.core");
        log.logf(.info, "saveAs path=\"{s}\"", .{path});
        try self.buffer.saveToFile(path);
        if (self.file_path) |old_path| {
            self.allocator.free(old_path);
        }
        self.file_path = try self.allocator.dupe(u8, path);
        self.modified = false;
        self.highlight_disabled_for_large_file = self.buffer.totalLen() >= highlighter_large_file_threshold_bytes;
        if (!self.highlight_disabled_for_large_file) {
            try self.tryInitHighlighter(path);
        } else {
            self.highlight_pending = false;
        }
    }

    pub fn invalidateLineWidthCache(self: *Editor) void {
        self.line_width_cache.clearRetainingCapacity();
        self.max_line_width_cache = 0;
    }

    pub fn lineWidthCached(self: *Editor, line_idx: usize, line_text: []const u8, cluster_offsets: ?[]const u32) usize {
        if (self.line_width_cache.get(line_idx)) |cached| return cached;
        var count: usize = 0;
        if (cluster_offsets) |clusters| {
            count = clusters.len;
        } else {
            var it = std.unicode.Utf8View.initUnchecked(line_text).iterator();
            while (it.nextCodepointSlice()) |slice| {
                const cp = std.unicode.utf8Decode(slice) catch 0xFFFD;
                if (cp == '\t') {
                    count += self.tab_width - (count % self.tab_width);
                } else {
                    count += 1;
                }
            }
        }
        self.line_width_cache.put(line_idx, count) catch |err| {
            const log = app_logger.logger("editor.core");
            log.logf(.warning, "line width cache insert failed idx={d}: {s}", .{ line_idx, @errorName(err) });
        };
        if (count > self.max_line_width_cache) self.max_line_width_cache = count;
        return count;
    }

    pub fn maxLineWidthCached(self: *const Editor) usize {
        return self.max_line_width_cache;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Cursor movement
    // ─────────────────────────────────────────────────────────────────────────

    pub fn moveCursorLeft(self: *Editor) void { Navigation.moveCursorLeft(self); }
    pub fn moveCursorRight(self: *Editor) void { Navigation.moveCursorRight(self); }
    pub fn moveCursorUp(self: *Editor) void { Navigation.moveCursorUp(self); }
    pub fn moveCursorDown(self: *Editor) void { Navigation.moveCursorDown(self); }
    pub fn moveCursorToLineStart(self: *Editor) void { Navigation.moveCursorToLineStart(self); }
    pub fn moveCursorToLineEnd(self: *Editor) void { Navigation.moveCursorToLineEnd(self); }
    pub fn moveCursorWordLeft(self: *Editor) void { Navigation.moveCursorWordLeft(self); }
    pub fn moveCursorWordRight(self: *Editor) void { Navigation.moveCursorWordRight(self); }

    pub fn hasRectangularSelectionState(self: *Editor) bool {
        return SelectionState.hasRectangularSelectionState(self);
    }

    pub fn hasSelectionSetState(self: *Editor) bool {
        return SelectionState.hasSelectionSetState(self);
    }

    pub fn collectSelectionAnchorsAndHeads(self: *Editor, anchors: *std.ArrayList(usize), heads: *std.ArrayList(usize)) !void {
        try SelectionState.collectSelectionAnchorsAndHeads(self, anchors, heads);
    }

    fn tryAppendCollapseOffset(self: *Editor, offsets: *std.ArrayList(usize), offset: usize) void {
        SelectionState.tryAppendCollapseOffset(self, offsets, offset);
    }

    fn extendSelectionSetWithHeads(self: *Editor, target_heads: []const usize) !void {
        try SelectionState.extendSelectionSetWithHeads(self, target_heads);
    }

    pub fn extendSelectionLeft(self: *Editor) void { Navigation.extendSelectionLeft(self); }
    pub fn extendSelectionRight(self: *Editor) void { Navigation.extendSelectionRight(self); }
    pub fn extendSelectionToLineStart(self: *Editor) void { Navigation.extendSelectionToLineStart(self); }
    pub fn extendSelectionToLineEnd(self: *Editor) void { Navigation.extendSelectionToLineEnd(self); }
    pub fn extendSelectionWordLeft(self: *Editor) void { Navigation.extendSelectionWordLeft(self); }
    pub fn extendSelectionWordRight(self: *Editor) void { Navigation.extendSelectionWordRight(self); }
    pub fn setCursor(self: *Editor, line: usize, col: usize) void { Navigation.setCursor(self, line, col); }
    pub fn setCursorPreservePreferred(self: *Editor, line: usize, col: usize) void { Navigation.setCursorPreservePreferred(self, line, col); }
    pub fn setCursorNoClear(self: *Editor, line: usize, col: usize) void { Navigation.setCursorNoClear(self, line, col); }
    pub fn setCursorOffsetNoClear(self: *Editor, offset: usize) void { Navigation.setCursorOffsetNoClear(self, offset); }

    pub fn clearSelections(self: *Editor) void { SelectionState.clearSelections(self); }
    pub fn primaryCaret(self: *Editor) CursorPos { return SelectionState.primaryCaret(self); }
    pub fn auxiliaryCaretCount(self: *Editor) usize { return SelectionState.auxiliaryCaretCount(self); }
    pub fn auxiliaryCaretAt(self: *Editor, index: usize) ?CursorPos { return SelectionState.auxiliaryCaretAt(self, index); }
    fn storedSelectionFromSelection(sel: Selection) StoredSelection { return SelectionState.storedSelectionFromSelection(sel); }
    fn selectionFromStored(self: *Editor, stored: StoredSelection) Selection { return SelectionState.selectionFromStored(self, stored); }
    fn rectangularPasteLines(self: *Editor, text: []const u8) !?[][]const u8 { return try SelectionState.rectangularPasteLines(self, text); }
    fn captureUndoSelectionState(self: *Editor) !u64 { return try SelectionState.captureUndoSelectionState(self); }
    fn restoreUndoSelectionState(self: *Editor, state_id: u64) !bool { return try SelectionState.restoreUndoSelectionState(self, state_id); }
    fn annotateLastUndoSelectionState(self: *Editor, before_id: u64, after_id: u64) void { SelectionState.annotateLastUndoSelectionState(self, before_id, after_id); }
    fn beginTrackedUndoGroup(self: *Editor) !u64 { return try SelectionState.beginTrackedUndoGroup(self); }
    fn endTrackedUndoGroup(self: *Editor) !void { try SelectionState.endTrackedUndoGroup(self); }
    pub fn addSelection(self: *Editor, selection: Selection) !void { try SelectionState.addSelection(self, selection); }
    pub fn selectionCount(self: *Editor) usize { return SelectionState.selectionCount(self); }
    pub fn selectionAt(self: *Editor, index: usize) ?Selection { return SelectionState.selectionAt(self, index); }
    pub fn normalizeSelections(self: *Editor) !void { try SelectionState.normalizeSelections(self); }
    pub fn addRectSelection(self: *Editor, start: CursorPos, end: CursorPos) !void { try SelectionState.addRectSelection(self, start, end); }
    pub fn expandRectSelection(self: *Editor, start_line: usize, end_line: usize, start_col: usize, end_col: usize) !void { try SelectionState.expandRectSelection(self, start_line, end_line, start_col, end_col); }
    pub fn expandRectSelectionVisual(self: *Editor, start_line: usize, end_line: usize, start_col_vis: usize, end_col_vis: usize) !void { try SelectionState.expandRectSelectionVisual(self, start_line, end_line, start_col_vis, end_col_vis); }
    pub fn expandRectSelectionVisualWithClusters(self: *Editor, start_line: usize, end_line: usize, start_col_vis: usize, end_col_vis: usize, provider: ?*const ClusterProvider) !void { try SelectionState.expandRectSelectionVisualWithClusters(self, start_line, end_line, start_col_vis, end_col_vis, provider); }
    fn normalizeSelectionsDescending(self: *Editor) !void { try SelectionState.normalizeSelectionsDescending(self); }
    fn duplicateNormalizedSelectionsDescending(self: *Editor) ![]Selection { return try SelectionState.duplicateNormalizedSelectionsDescending(self); }
    pub fn addCaretUp(self: *Editor) !bool { return try SelectionState.addCaretUp(self); }
    pub fn addCaretDown(self: *Editor) !bool { return try SelectionState.addCaretDown(self); }
    fn addCaretVertical(self: *Editor, delta: i32) !bool { return try SelectionState.addCaretVertical(self, delta); }
    fn cursorPosForOffset(self: *Editor, offset: usize) CursorPos { return SelectionState.cursorPosForOffset(self, offset); }
    fn shiftCaretOffsets(caret_offsets: *std.ArrayList(usize), delta: isize) void { SelectionState.shiftCaretOffsets(caret_offsets, delta); }
    fn hasOnlyCaretSelections(self: *Editor) bool { return SelectionState.hasOnlyCaretSelections(self); }
    fn collectCaretOffsets(self: *Editor) !std.ArrayList(usize) { return try SelectionState.collectCaretOffsets(self); }
    fn collectCaretOffsetsDescending(self: *Editor) !std.ArrayList(usize) { return try SelectionState.collectCaretOffsetsDescending(self); }
    fn restoreCaretSelections(self: *Editor, caret_offsets: []const usize, primary_offset: usize) !void { try SelectionState.restoreCaretSelections(self, caret_offsets, primary_offset); }
    pub fn restoreExtendedCaretSelections(self: *Editor, anchor_offsets: []const usize, target_offsets: []const usize) !void { try SelectionState.restoreExtendedCaretSelections(self, anchor_offsets, target_offsets); }
    fn moveCaretSetHorizontal(self: *Editor, delta: isize) !void { try SelectionState.moveCaretSetHorizontal(self, delta); }
    fn moveCaretSetToLineBoundary(self: *Editor, to_start: bool) !void { try SelectionState.moveCaretSetToLineBoundary(self, to_start); }
    fn moveCaretSetByWord(self: *Editor, left: bool) !void { try SelectionState.moveCaretSetByWord(self, left); }
    fn extendCaretSetToOffsets(self: *Editor, target_offsets: []const usize) !void { try SelectionState.extendCaretSetToOffsets(self, target_offsets); }
    fn adjustPrimaryOffsetForReplacement(primary_offset: *usize, start: usize, end: usize, replacement_len: usize) void { SelectionState.adjustPrimaryOffsetForReplacement(primary_offset, start, end, replacement_len); }
    fn applySelectionReplacementOps(self: *Editor, ops: []const SelectionReplacementOp, initial_primary_offset: usize) !void { try SelectionState.applySelectionReplacementOps(self, ops, initial_primary_offset); }
    fn isWordByte(byte: u8) bool { return SelectionState.isWordByte(byte); }
    fn byteAt(self: *Editor, offset: usize) ?u8 { return SelectionState.byteAt(self, offset); }
    fn wordLeftOffset(self: *Editor, offset: usize) usize { return SelectionState.wordLeftOffset(self, offset); }
    fn wordRightOffset(self: *Editor, offset: usize) usize { return SelectionState.wordRightOffset(self, offset); }
    fn extendPrimarySelectionToOffset(self: *Editor, target_offset: usize) void { SelectionState.extendPrimarySelectionToOffset(self, target_offset); }

    fn byteIndexForVisualColumn(self: *Editor, line_text: []const u8, column: usize, clusters: ?[]const u32) usize {
        _ = self;
        return text_columns.byteIndexForVisualColumnWithClusters(line_text, column, clusters);
    }

    fn updateCursorPosition(self: *Editor) void { Navigation.updateCursorPosition(self); }
    fn updateCursorOffset(self: *Editor) void { Navigation.updateCursorOffset(self); }

    fn noteTextChangedBase(self: *Editor) void {
        self.modified = true;
        self.invalidateLineWidthCache();
        self.change_tick +|= 1;
    }

    fn pointForByte(self: *Editor, byte_offset: usize) c.TSPoint {
        const line = self.buffer.lineIndexForOffset(byte_offset);
        const line_start = self.buffer.lineStart(line);
        return .{
            .row = @as(u32, @intCast(line)),
            .column = @as(u32, @intCast(byte_offset - line_start)),
        };
    }

    fn replaceByteRangeInternal(
        self: *Editor,
        start: usize,
        end: usize,
        replacement: []const u8,
        refresh_search: bool,
    ) !void {
        const len = end - start;
        if (len > 0) {
            const start_point = self.pointForByte(start);
            const end_point = self.pointForByte(end);
            try self.buffer.deleteRange(start, len);
            self.applyHighlightEdit(start, end, start, start_point, end_point);
        }
        if (replacement.len > 0) {
            const insert_point = self.pointForByte(start);
            try self.buffer.insertBytes(start, replacement);
            self.applyHighlightEdit(start, start, start + replacement.len, insert_point, insert_point);
        }
        self.setCursorOffsetNoClear(start + replacement.len);
        self.selection = null;
        self.clearSelections();
        if (refresh_search) {
            self.noteTextChanged();
        } else {
            self.noteTextChangedNoSearchRefresh();
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Text editing
    // ─────────────────────────────────────────────────────────────────────────

    pub fn insertChar(self: *Editor, char: u8) !void {
        self.preferred_visual_col = null;
        if (self.selections.items.len > 0) {
            if (self.hasOnlyCaretSelections()) {
                _ = try self.beginTrackedUndoGroup();
                errdefer self.endTrackedUndoGroup() catch |err| {
                    const log = app_logger.logger("editor.core");
                    log.logf(.warning, "tracked undo cleanup failed (insert char caret set): {s}", .{@errorName(err)});
                };
                var caret_offsets = try self.collectCaretOffsetsDescending();
                defer caret_offsets.deinit(self.allocator);
                var new_offsets = std.ArrayList(usize).empty;
                defer new_offsets.deinit(self.allocator);
                var primary_offset = self.cursor.offset;
                const bytes = [_]u8{char};
                for (caret_offsets.items) |offset| {
                    const insert_point = self.pointForByte(offset);
                    try self.buffer.insertBytes(offset, &bytes);
                    self.applyHighlightEdit(offset, offset, offset + 1, insert_point, insert_point);
                    adjustPrimaryOffsetForReplacement(&primary_offset, offset, offset, 1);
                    shiftCaretOffsets(&new_offsets, 1);
                    try new_offsets.append(self.allocator, offset + 1);
                }
                self.noteTextChanged();
                try self.restoreCaretSelections(new_offsets.items, primary_offset);
                try self.endTrackedUndoGroup();
                return;
            }
            _ = try self.beginTrackedUndoGroup();
            errdefer self.endTrackedUndoGroup() catch |err| {
                const log = app_logger.logger("editor.core");
                log.logf(.warning, "tracked undo cleanup failed (insert char selection set): {s}", .{@errorName(err)});
            };
            const selections = try self.duplicateNormalizedSelectionsDescending();
            defer self.allocator.free(selections);
            const bytes = [_]u8{char};
            var ops = std.ArrayList(SelectionReplacementOp).empty;
            defer ops.deinit(self.allocator);
            for (selections) |sel| {
                const norm = sel.normalized();
                try ops.append(self.allocator, .{
                    .start = norm.start.offset,
                    .end = norm.end.offset,
                    .replacement = &bytes,
                });
            }
            try self.applySelectionReplacementOps(ops.items, self.cursor.offset);
            try self.endTrackedUndoGroup();
            return;
        }
        if (self.selection != null) {
            _ = try self.beginTrackedUndoGroup();
            errdefer self.endTrackedUndoGroup() catch |err| {
                const log = app_logger.logger("editor.core");
                log.logf(.warning, "tracked undo cleanup failed (insert char primary selection): {s}", .{@errorName(err)});
            };
            try self.deleteSelection();
            const bytes = [_]u8{char};
            const insert_start = self.cursor.offset;
            const insert_point = self.pointForByte(insert_start);
            try self.buffer.insertBytes(insert_start, &bytes);
            self.applyHighlightEdit(insert_start, insert_start, insert_start + 1, insert_point, insert_point);
            self.cursor.offset += 1;
            self.updateCursorPosition();
            self.noteTextChanged();
            try self.endTrackedUndoGroup();
            return;
        }
        const before_id = try self.captureUndoSelectionState();
        const bytes = [_]u8{char};
        const insert_start = self.cursor.offset;
        const insert_point = self.pointForByte(insert_start);
        try self.buffer.insertBytes(insert_start, &bytes);
        self.applyHighlightEdit(insert_start, insert_start, insert_start + 1, insert_point, insert_point);
        self.cursor.offset += 1;
        self.updateCursorPosition();
        self.noteTextChanged();
        const after_id = try self.captureUndoSelectionState();
        self.annotateLastUndoSelectionState(before_id, after_id);
    }

    pub fn insertText(self: *Editor, text: []const u8) !void {
        self.preferred_visual_col = null;
        if (self.selections.items.len > 0) {
            if (self.hasOnlyCaretSelections()) {
                _ = try self.beginTrackedUndoGroup();
                errdefer self.endTrackedUndoGroup() catch |err| {
                    const log = app_logger.logger("editor.core");
                    log.logf(.warning, "tracked undo cleanup failed (insert text caret set): {s}", .{@errorName(err)});
                };
                var caret_offsets = try self.collectCaretOffsetsDescending();
                defer caret_offsets.deinit(self.allocator);
                var new_offsets = std.ArrayList(usize).empty;
                defer new_offsets.deinit(self.allocator);
                var primary_offset = self.cursor.offset;
                for (caret_offsets.items) |offset| {
                    const insert_point = self.pointForByte(offset);
                    try self.buffer.insertBytes(offset, text);
                    self.applyHighlightEdit(offset, offset, offset + text.len, insert_point, insert_point);
                    adjustPrimaryOffsetForReplacement(&primary_offset, offset, offset, text.len);
                    shiftCaretOffsets(&new_offsets, @intCast(text.len));
                    try new_offsets.append(self.allocator, offset + text.len);
                }
                self.noteTextChanged();
                try self.restoreCaretSelections(new_offsets.items, primary_offset);
                try self.endTrackedUndoGroup();
                return;
            }
            _ = try self.beginTrackedUndoGroup();
            errdefer self.endTrackedUndoGroup() catch |err| {
                const log = app_logger.logger("editor.core");
                log.logf(.warning, "tracked undo cleanup failed (insert text selection set): {s}", .{@errorName(err)});
            };
            const selections = try self.duplicateNormalizedSelectionsDescending();
            defer self.allocator.free(selections);
            const rect_lines = try self.rectangularPasteLines(text);
            defer if (rect_lines) |lines| self.allocator.free(lines);
            var ops = std.ArrayList(SelectionReplacementOp).empty;
            defer ops.deinit(self.allocator);
            for (selections, 0..) |sel, idx| {
                const norm = sel.normalized();
                const replacement = if (rect_lines) |lines|
                    lines[selections.len - 1 - idx]
                else
                    text;
                try ops.append(self.allocator, .{
                    .start = norm.start.offset,
                    .end = norm.end.offset,
                    .replacement = replacement,
                });
            }
            try self.applySelectionReplacementOps(ops.items, self.cursor.offset);
            try self.endTrackedUndoGroup();
            return;
        }
        if (self.selection != null) {
            _ = try self.beginTrackedUndoGroup();
            errdefer self.endTrackedUndoGroup() catch |err| {
                const log = app_logger.logger("editor.core");
                log.logf(.warning, "tracked undo cleanup failed (insert text primary selection): {s}", .{@errorName(err)});
            };
            try self.deleteSelection();
            const insert_start = self.cursor.offset;
            const insert_point = self.pointForByte(insert_start);
            try self.buffer.insertBytes(insert_start, text);
            self.applyHighlightEdit(insert_start, insert_start, insert_start + text.len, insert_point, insert_point);
            self.cursor.offset += text.len;
            self.updateCursorPosition();
            self.noteTextChanged();
            try self.endTrackedUndoGroup();
            return;
        }
        const before_id = try self.captureUndoSelectionState();
        const insert_start = self.cursor.offset;
        const insert_point = self.pointForByte(insert_start);
        try self.buffer.insertBytes(insert_start, text);
        self.applyHighlightEdit(insert_start, insert_start, insert_start + text.len, insert_point, insert_point);
        self.cursor.offset += text.len;
        self.updateCursorPosition();
        self.noteTextChanged();
        const after_id = try self.captureUndoSelectionState();
        self.annotateLastUndoSelectionState(before_id, after_id);
    }

    pub fn insertNewline(self: *Editor) !void {
        try self.insertChar('\n');
    }

    pub fn deleteCharBackward(self: *Editor) !void {
        self.preferred_visual_col = null;
        if (self.hasOnlyCaretSelections()) {
            _ = try self.beginTrackedUndoGroup();
            errdefer self.endTrackedUndoGroup() catch |err| {
                const log = app_logger.logger("editor.core");
                log.logf(.warning, "tracked undo cleanup failed (backspace caret set): {s}", .{@errorName(err)});
            };
            var caret_offsets = try self.collectCaretOffsetsDescending();
            defer caret_offsets.deinit(self.allocator);
            var new_offsets = std.ArrayList(usize).empty;
            defer new_offsets.deinit(self.allocator);
            var primary_offset = self.cursor.offset;
            var changed = false;
            for (caret_offsets.items) |offset| {
                if (offset == 0) {
                    try new_offsets.append(self.allocator, 0);
                    continue;
                }
                const delete_start = offset - 1;
                const delete_end = offset;
                const start_point = self.pointForByte(delete_start);
                const end_point = self.pointForByte(delete_end);
                try self.buffer.deleteRange(delete_start, 1);
                self.applyHighlightEdit(delete_start, delete_end, delete_start, start_point, end_point);
                adjustPrimaryOffsetForReplacement(&primary_offset, delete_start, delete_end, 0);
                shiftCaretOffsets(&new_offsets, -1);
                try new_offsets.append(self.allocator, delete_start);
                changed = true;
            }
            if (changed) self.noteTextChanged();
            try self.restoreCaretSelections(new_offsets.items, primary_offset);
            self.selection = null;
            try self.endTrackedUndoGroup();
            return;
        }
        if (self.selections.items.len > 0) {
            _ = try self.beginTrackedUndoGroup();
            errdefer self.endTrackedUndoGroup() catch |err| {
                const log = app_logger.logger("editor.core");
                log.logf(.warning, "tracked undo cleanup failed (backspace selection set): {s}", .{@errorName(err)});
            };
            const selections = try self.duplicateNormalizedSelectionsDescending();
            defer self.allocator.free(selections);
            var ops = std.ArrayList(SelectionReplacementOp).empty;
            defer ops.deinit(self.allocator);
            for (selections) |sel| {
                const norm = sel.normalized();
                var delete_start = norm.start.offset;
                var delete_len: usize = norm.end.offset - norm.start.offset;
                if (delete_len == 0 and delete_start > 0) {
                    delete_start -= 1;
                    delete_len = 1;
                }
                try ops.append(self.allocator, .{
                    .start = delete_start,
                    .end = delete_start + delete_len,
                    .replacement = "",
                });
            }
            try self.applySelectionReplacementOps(ops.items, self.cursor.offset);
            try self.endTrackedUndoGroup();
            return;
        }
        if (self.selection) |_| {
            try self.deleteSelection();
            return;
        }
        if (self.cursor.offset == 0) return;
        const before_id = try self.captureUndoSelectionState();
        const start = self.cursor.offset - 1;
        const end = self.cursor.offset;
        const start_point = self.pointForByte(start);
        const end_point = self.pointForByte(end);
        try self.buffer.deleteRange(start, 1);
        self.applyHighlightEdit(start, end, start, start_point, end_point);
        self.cursor.offset -= 1;
        self.updateCursorPosition();
        self.noteTextChanged();
        const after_id = try self.captureUndoSelectionState();
        self.annotateLastUndoSelectionState(before_id, after_id);
    }

    pub fn deleteCharForward(self: *Editor) !void {
        self.preferred_visual_col = null;
        if (self.hasOnlyCaretSelections()) {
            _ = try self.beginTrackedUndoGroup();
            errdefer self.endTrackedUndoGroup() catch |err| {
                const log = app_logger.logger("editor.core");
                log.logf(.warning, "tracked undo cleanup failed (delete forward caret set): {s}", .{@errorName(err)});
            };
            var caret_offsets = try self.collectCaretOffsetsDescending();
            defer caret_offsets.deinit(self.allocator);
            var new_offsets = std.ArrayList(usize).empty;
            defer new_offsets.deinit(self.allocator);
            var primary_offset = self.cursor.offset;
            var changed = false;
            const total = self.buffer.totalLen();
            for (caret_offsets.items) |offset| {
                if (offset >= total) {
                    try new_offsets.append(self.allocator, offset);
                    continue;
                }
                const delete_start = offset;
                const delete_end = offset + 1;
                const start_point = self.pointForByte(delete_start);
                const end_point = self.pointForByte(delete_end);
                try self.buffer.deleteRange(delete_start, 1);
                self.applyHighlightEdit(delete_start, delete_end, delete_start, start_point, end_point);
                adjustPrimaryOffsetForReplacement(&primary_offset, delete_start, delete_end, 0);
                shiftCaretOffsets(&new_offsets, -1);
                try new_offsets.append(self.allocator, delete_start);
                changed = true;
            }
            if (changed) self.noteTextChanged();
            try self.restoreCaretSelections(new_offsets.items, primary_offset);
            self.selection = null;
            try self.endTrackedUndoGroup();
            return;
        }
        if (self.selections.items.len > 0) {
            _ = try self.beginTrackedUndoGroup();
            errdefer self.endTrackedUndoGroup() catch |err| {
                const log = app_logger.logger("editor.core");
                log.logf(.warning, "tracked undo cleanup failed (delete forward selection set): {s}", .{@errorName(err)});
            };
            const selections = try self.duplicateNormalizedSelectionsDescending();
            defer self.allocator.free(selections);
            var ops = std.ArrayList(SelectionReplacementOp).empty;
            defer ops.deinit(self.allocator);
            for (selections) |sel| {
                const norm = sel.normalized();
                const delete_start = norm.start.offset;
                var delete_len: usize = norm.end.offset - norm.start.offset;
                if (delete_len == 0 and delete_start < self.buffer.totalLen()) {
                    delete_len = 1;
                }
                try ops.append(self.allocator, .{
                    .start = delete_start,
                    .end = delete_start + delete_len,
                    .replacement = "",
                });
            }
            try self.applySelectionReplacementOps(ops.items, self.cursor.offset);
            try self.endTrackedUndoGroup();
            return;
        }
        if (self.selection) |_| {
            try self.deleteSelection();
            return;
        }
        const total = self.buffer.totalLen();
        if (self.cursor.offset >= total) return;
        const before_id = try self.captureUndoSelectionState();
        const start = self.cursor.offset;
        const end = self.cursor.offset + 1;
        const start_point = self.pointForByte(start);
        const end_point = self.pointForByte(end);
        try self.buffer.deleteRange(start, 1);
        self.applyHighlightEdit(start, end, start, start_point, end_point);
        self.noteTextChanged();
        const after_id = try self.captureUndoSelectionState();
        self.annotateLastUndoSelectionState(before_id, after_id);
    }

    pub fn deleteSelection(self: *Editor) !void {
        self.preferred_visual_col = null;
        if (self.hasOnlyCaretSelections()) {
            var caret_offsets = try self.collectCaretOffsets();
            defer caret_offsets.deinit(self.allocator);
            try self.restoreCaretSelections(caret_offsets.items, self.cursor.offset);
            self.selection = null;
            return;
        }
        if (self.selections.items.len > 0) {
            _ = try self.beginTrackedUndoGroup();
            errdefer self.endTrackedUndoGroup() catch |err| {
                const log = app_logger.logger("editor.core");
                log.logf(.warning, "tracked undo cleanup failed (delete selection set): {s}", .{@errorName(err)});
            };
            const selections = try self.duplicateNormalizedSelectionsDescending();
            defer self.allocator.free(selections);
            var ops = std.ArrayList(SelectionReplacementOp).empty;
            defer ops.deinit(self.allocator);
            for (selections) |sel| {
                const norm = sel.normalized();
                try ops.append(self.allocator, .{
                    .start = norm.start.offset,
                    .end = norm.end.offset,
                    .replacement = "",
                });
            }
            try self.applySelectionReplacementOps(ops.items, self.cursor.offset);
            try self.endTrackedUndoGroup();
            return;
        }
        if (self.selection) |sel| {
            const before_id = try self.captureUndoSelectionState();
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
            const after_id = try self.captureUndoSelectionState();
            self.annotateLastUndoSelectionState(before_id, after_id);
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
        var emitted_any = false;
        for (merged.items) |sel| {
            if (sel.isEmpty()) continue;
            const norm = sel.normalized();
            const len = norm.end.offset - norm.start.offset;
            if (len == 0) continue;
            const chunk = try self.buffer.readRangeAlloc(norm.start.offset, len);
            defer self.allocator.free(chunk);
            if (emitted_any) {
                try out.append(self.allocator, '\n');
            }
            try out.appendSlice(self.allocator, chunk);
            emitted_any = true;
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
            log.logf(.info, "undo ok", .{});
        }
        if (result.changed) {
            if (result.state) |state_id| {
                if (!(try self.restoreUndoSelectionState(state_id)) and result.cursor != null) {
                    const clamped = @min(result.cursor.?, self.buffer.totalLen());
                    self.setCursorOffsetNoClear(clamped);
                    self.selection = null;
                    self.clearSelections();
                }
            } else if (result.cursor) |cursor_offset| {
                const clamped = @min(cursor_offset, self.buffer.totalLen());
                self.setCursorOffsetNoClear(clamped);
                self.selection = null;
                self.clearSelections();
            } else {
                if (self.cursor.offset > self.buffer.totalLen()) {
                    self.cursor.offset = self.buffer.totalLen();
                }
                self.updateCursorPosition();
                self.selection = null;
                self.clearSelections();
            }
            if (self.highlighter) |h| {
                _ = h.reparseFull();
                self.noteHighlightDirtyRange(0, self.buffer.totalLen());
                self.highlight_epoch +|= 1;
            }
            self.invalidateLineWidthCache();
            self.change_tick +|= 1;
            if (self.search_query != null) {
                const log = app_logger.logger("editor.core");
                self.recomputeSearchMatches() catch |err| {
                    log.logf(.warning, "recompute search matches after undo failed: {s}", .{@errorName(err)});
                };
            }
        }
        return result.changed;
    }

    pub fn redo(self: *Editor) !bool {
        self.preferred_visual_col = null;
        const result = try self.buffer.redoWithCursor();
        if (result.changed) {
            const log = app_logger.logger("editor.core");
            log.logf(.info, "redo ok", .{});
        }
        if (result.changed) {
            if (result.state) |state_id| {
                if (!(try self.restoreUndoSelectionState(state_id)) and result.cursor != null) {
                    const clamped = @min(result.cursor.?, self.buffer.totalLen());
                    self.setCursorOffsetNoClear(clamped);
                    self.selection = null;
                    self.clearSelections();
                }
            } else if (result.cursor) |cursor_offset| {
                const clamped = @min(cursor_offset, self.buffer.totalLen());
                self.setCursorOffsetNoClear(clamped);
                self.selection = null;
                self.clearSelections();
            } else {
                if (self.cursor.offset > self.buffer.totalLen()) {
                    self.cursor.offset = self.buffer.totalLen();
                }
                self.updateCursorPosition();
                self.selection = null;
                self.clearSelections();
            }
            if (self.highlighter) |h| {
                _ = h.reparseFull();
                self.noteHighlightDirtyRange(0, self.buffer.totalLen());
                self.highlight_epoch +|= 1;
            }
            self.invalidateLineWidthCache();
            self.change_tick +|= 1;
            if (self.search_query != null) {
                const log = app_logger.logger("editor.core");
                self.recomputeSearchMatches() catch |err| {
                    log.logf(.warning, "recompute search matches after redo failed: {s}", .{@errorName(err)});
                };
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

    pub fn takeHighlightDirtyRange(self: *Editor) ?HighlightDirtyRange {
        return SearchHighlight.takeHighlightDirtyRange(self);
    }

    fn noteTextChanged(self: *Editor) void {
        SearchHighlight.noteTextChanged(self);
    }

    fn noteTextChangedNoSearchRefresh(self: *Editor) void {
        SearchHighlight.noteTextChangedNoSearchRefresh(self);
    }

    fn noteHighlightDirtyRange(self: *Editor, start_byte: usize, end_byte: usize) void {
        SearchHighlight.noteHighlightDirtyRange(self, start_byte, end_byte);
    }

    fn applyHighlightEdit(
        self: *Editor,
        start_byte: usize,
        old_end_byte: usize,
        new_end_byte: usize,
        start_point: c.TSPoint,
        old_end_point: c.TSPoint,
    ) void {
        SearchHighlight.applyHighlightEdit(self, start_byte, old_end_byte, new_end_byte, start_point, old_end_point);
    }

    fn scheduleHighlighter(self: *Editor, path: ?[]const u8) void {
        SearchHighlight.scheduleHighlighter(self, path);
    }

    fn tryInitHighlighter(self: *Editor, path: ?[]const u8) !void {
        try SearchHighlight.tryInitHighlighter(self, path);
    }

    pub fn ensureHighlighter(self: *Editor) void {
        SearchHighlight.ensureHighlighter(self);
    }

    pub fn applyPendingSearchWork(self: *Editor) void {
        SearchHighlight.applyPendingSearchWork(self);
    }

    pub fn setSearchQuery(self: *Editor, query: ?[]const u8) !void {
        try SearchHighlight.setSearchQuery(self, query);
    }

    pub fn setSearchQueryRegex(self: *Editor, query: ?[]const u8) !void {
        try SearchHighlight.setSearchQueryRegex(self, query);
    }

    pub fn searchMatches(self: *const Editor) []const SearchMatch {
        return SearchHighlight.searchMatches(self);
    }

    pub fn searchQuery(self: *const Editor) ?[]const u8 {
        return SearchHighlight.searchQuery(self);
    }

    pub fn searchActiveMatch(self: *const Editor) ?SearchMatch {
        return SearchHighlight.searchActiveMatch(self);
    }

    pub fn searchActiveIndex(self: *const Editor) ?usize {
        return SearchHighlight.searchActiveIndex(self);
    }

    pub fn focusSearchActiveMatch(self: *Editor) bool {
        return SearchHighlight.focusSearchActiveMatch(self);
    }

    pub fn activateNextSearchMatch(self: *Editor) bool {
        return SearchHighlight.activateNextSearchMatch(self);
    }

    pub fn activatePrevSearchMatch(self: *Editor) bool {
        return SearchHighlight.activatePrevSearchMatch(self);
    }

    pub fn replaceActiveSearchMatch(self: *Editor, replacement: []const u8) !bool {
        return try SearchHighlight.replaceActiveSearchMatch(self, replacement);
    }

    pub fn replaceAllSearchMatches(self: *Editor, replacement: []const u8) !usize {
        return try SearchHighlight.replaceAllSearchMatches(self, replacement);
    }

    fn jumpToSearchActive(self: *Editor) void {
        SearchHighlight.jumpToSearchActive(self);
    }

    fn findSearchMatchAtOrAfter(self: *const Editor, offset: usize) ?usize {
        return SearchHighlight.findSearchMatchAtOrAfter(self, offset);
    }

    fn clearSearchState(self: *Editor) void {
        SearchHighlight.clearSearchState(self);
    }

    fn recomputeSearchMatches(self: *Editor) !void {
        try SearchHighlight.recomputeSearchMatches(self);
    }

    fn recomputeSearchMatchesPrefer(self: *Editor, preferred_offset: usize) !void {
        try SearchHighlight.recomputeSearchMatchesPrefer(self, preferred_offset);
    }

    fn recomputeSearchMatchesSync(self: *Editor) !void {
        try SearchHighlight.recomputeSearchMatchesSync(self);
    }

    fn recomputeSearchMatchesSyncPrefer(self: *Editor, preferred_offset: usize) !void {
        try SearchHighlight.recomputeSearchMatchesSyncPrefer(self, preferred_offset);
    }

    fn queueSearchRequest(
        self: *Editor,
        preferred_offset: usize,
        mode: SearchMode,
        query: []u8,
        content: []u8,
    ) ?u64 {
        return SearchHighlight.queueSearchRequest(self, preferred_offset, mode, query, content);
    }

    fn ensureSearchWorker(self: *Editor) void {
        SearchHighlight.ensureSearchWorker(self);
    }

    fn stopSearchWorker(self: *Editor) void {
        SearchHighlight.stopSearchWorker(self);
    }

    fn cancelPendingSearchWork(self: *Editor) void {
        SearchHighlight.cancelPendingSearchWork(self);
    }

    fn applyPendingSearchResult(self: *Editor) void {
        SearchHighlight.applyPendingSearchResult(self);
    }
};

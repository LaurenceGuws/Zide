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
const editor_edit_ops = @import("edit_ops.zig");
const app_logger = @import("../app_logger.zig");

const TextStore = text_store.TextStore;
const CursorPos = types.CursorPos;
const Selection = types.Selection;
const c = ts_api.c_api;

/// High-level editor state wrapping a text buffer
pub const Editor = struct {
    pub const highlighter_large_file_threshold_bytes: usize = 8 * 1024 * 1024;
    const SearchHighlight = editor_search_highlight.SearchHighlightOps(@This());
    const SelectionState = editor_selection_state.SelectionStateOps(@This());
    const Navigation = editor_navigation.NavigationOps(@This());
    const EditOps = editor_edit_ops.EditOps(@This());

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

    pub fn moveCursorLeft(self: *Editor) void {
        Navigation.moveCursorLeft(self);
    }
    pub fn moveCursorRight(self: *Editor) void {
        Navigation.moveCursorRight(self);
    }
    pub fn moveCursorUp(self: *Editor) void {
        Navigation.moveCursorUp(self);
    }
    pub fn moveCursorDown(self: *Editor) void {
        Navigation.moveCursorDown(self);
    }
    pub fn moveCursorToLineStart(self: *Editor) void {
        Navigation.moveCursorToLineStart(self);
    }
    pub fn moveCursorToLineEnd(self: *Editor) void {
        Navigation.moveCursorToLineEnd(self);
    }
    pub fn moveCursorWordLeft(self: *Editor) void {
        Navigation.moveCursorWordLeft(self);
    }
    pub fn moveCursorWordRight(self: *Editor) void {
        Navigation.moveCursorWordRight(self);
    }

    pub fn hasRectangularSelectionState(self: *Editor) bool {
        return SelectionState.hasRectangularSelectionState(self);
    }

    pub fn hasSelectionSetState(self: *Editor) bool {
        return SelectionState.hasSelectionSetState(self);
    }

    pub fn collectSelectionAnchorsAndHeads(self: *Editor, anchors: *std.ArrayList(usize), heads: *std.ArrayList(usize)) !void {
        try SelectionState.collectSelectionAnchorsAndHeads(self, anchors, heads);
    }

    pub fn tryAppendCollapseOffset(self: *Editor, offsets: *std.ArrayList(usize), offset: usize) void {
        SelectionState.tryAppendCollapseOffset(self, offsets, offset);
    }

    fn extendSelectionSetWithHeads(self: *Editor, target_heads: []const usize) !void {
        try SelectionState.extendSelectionSetWithHeads(self, target_heads);
    }

    pub fn extendSelectionLeft(self: *Editor) void {
        Navigation.extendSelectionLeft(self);
    }
    pub fn extendSelectionRight(self: *Editor) void {
        Navigation.extendSelectionRight(self);
    }
    pub fn extendSelectionToLineStart(self: *Editor) void {
        Navigation.extendSelectionToLineStart(self);
    }
    pub fn extendSelectionToLineEnd(self: *Editor) void {
        Navigation.extendSelectionToLineEnd(self);
    }
    pub fn extendSelectionWordLeft(self: *Editor) void {
        Navigation.extendSelectionWordLeft(self);
    }
    pub fn extendSelectionWordRight(self: *Editor) void {
        Navigation.extendSelectionWordRight(self);
    }
    pub fn setCursor(self: *Editor, line: usize, col: usize) void {
        Navigation.setCursor(self, line, col);
    }
    pub fn setCursorPreservePreferred(self: *Editor, line: usize, col: usize) void {
        Navigation.setCursorPreservePreferred(self, line, col);
    }
    pub fn setCursorNoClear(self: *Editor, line: usize, col: usize) void {
        Navigation.setCursorNoClear(self, line, col);
    }
    pub fn setCursorOffsetNoClear(self: *Editor, offset: usize) void {
        Navigation.setCursorOffsetNoClear(self, offset);
    }

    pub fn clearSelections(self: *Editor) void {
        SelectionState.clearSelections(self);
    }
    pub fn primaryCaret(self: *Editor) CursorPos {
        return SelectionState.primaryCaret(self);
    }
    pub fn auxiliaryCaretCount(self: *Editor) usize {
        return SelectionState.auxiliaryCaretCount(self);
    }
    pub fn auxiliaryCaretAt(self: *Editor, index: usize) ?CursorPos {
        return SelectionState.auxiliaryCaretAt(self, index);
    }
    fn storedSelectionFromSelection(sel: Selection) StoredSelection {
        return SelectionState.storedSelectionFromSelection(sel);
    }
    pub fn selectionFromStored(self: *Editor, stored: StoredSelection) Selection {
        return SelectionState.selectionFromStored(self, stored);
    }
    pub fn rectangularPasteLines(self: *Editor, text: []const u8) !?[][]const u8 {
        return try SelectionState.rectangularPasteLines(self, text);
    }
    pub fn captureUndoSelectionState(self: *Editor) !u64 {
        return try SelectionState.captureUndoSelectionState(self);
    }
    fn restoreUndoSelectionState(self: *Editor, state_id: u64) !bool {
        return try SelectionState.restoreUndoSelectionState(self, state_id);
    }
    pub fn annotateLastUndoSelectionState(self: *Editor, before_id: u64, after_id: u64) void {
        SelectionState.annotateLastUndoSelectionState(self, before_id, after_id);
    }
    pub fn beginTrackedUndoGroup(self: *Editor) !u64 {
        return try SelectionState.beginTrackedUndoGroup(self);
    }
    pub fn endTrackedUndoGroup(self: *Editor) !void {
        try SelectionState.endTrackedUndoGroup(self);
    }
    pub fn addSelection(self: *Editor, selection: Selection) !void {
        try SelectionState.addSelection(self, selection);
    }
    pub fn selectionCount(self: *Editor) usize {
        return SelectionState.selectionCount(self);
    }
    pub fn selectionAt(self: *Editor, index: usize) ?Selection {
        return SelectionState.selectionAt(self, index);
    }
    pub fn normalizeSelections(self: *Editor) !void {
        try SelectionState.normalizeSelections(self);
    }
    pub fn addRectSelection(self: *Editor, start: CursorPos, end: CursorPos) !void {
        try SelectionState.addRectSelection(self, start, end);
    }
    pub fn expandRectSelection(self: *Editor, start_line: usize, end_line: usize, start_col: usize, end_col: usize) !void {
        try SelectionState.expandRectSelection(self, start_line, end_line, start_col, end_col);
    }
    pub fn expandRectSelectionVisual(self: *Editor, start_line: usize, end_line: usize, start_col_vis: usize, end_col_vis: usize) !void {
        try SelectionState.expandRectSelectionVisual(self, start_line, end_line, start_col_vis, end_col_vis);
    }
    pub fn expandRectSelectionVisualWithClusters(self: *Editor, start_line: usize, end_line: usize, start_col_vis: usize, end_col_vis: usize, provider: ?*const ClusterProvider) !void {
        try SelectionState.expandRectSelectionVisualWithClusters(self, start_line, end_line, start_col_vis, end_col_vis, provider);
    }
    pub fn normalizeSelectionsDescending(self: *Editor) !void {
        try SelectionState.normalizeSelectionsDescending(self);
    }
    pub fn duplicateNormalizedSelectionsDescending(self: *Editor) ![]Selection {
        return try SelectionState.duplicateNormalizedSelectionsDescending(self);
    }
    pub fn addCaretUp(self: *Editor) !bool {
        return try SelectionState.addCaretUp(self);
    }
    pub fn addCaretDown(self: *Editor) !bool {
        return try SelectionState.addCaretDown(self);
    }
    pub fn addCaretVertical(self: *Editor, delta: i32) !bool {
        return try SelectionState.addCaretVertical(self, delta);
    }
    pub fn cursorPosForOffset(self: *Editor, offset: usize) CursorPos {
        return SelectionState.cursorPosForOffset(self, offset);
    }
    pub fn shiftCaretOffsets(self: *Editor, caret_offsets: *std.ArrayList(usize), delta: isize) void {
        _ = self;
        SelectionState.shiftCaretOffsets(caret_offsets, delta);
    }
    pub fn hasOnlyCaretSelections(self: *Editor) bool {
        return SelectionState.hasOnlyCaretSelections(self);
    }
    pub fn collectCaretOffsets(self: *Editor) !std.ArrayList(usize) {
        return try SelectionState.collectCaretOffsets(self);
    }
    pub fn collectCaretOffsetsDescending(self: *Editor) !std.ArrayList(usize) {
        return try SelectionState.collectCaretOffsetsDescending(self);
    }
    pub fn restoreCaretSelections(self: *Editor, caret_offsets: []const usize, primary_offset: usize) !void {
        try SelectionState.restoreCaretSelections(self, caret_offsets, primary_offset);
    }
    pub fn restoreExtendedCaretSelections(self: *Editor, anchor_offsets: []const usize, target_offsets: []const usize) !void {
        try SelectionState.restoreExtendedCaretSelections(self, anchor_offsets, target_offsets);
    }
    pub fn moveCaretSetHorizontal(self: *Editor, delta: isize) !void {
        try SelectionState.moveCaretSetHorizontal(self, delta);
    }
    pub fn moveCaretSetToLineBoundary(self: *Editor, to_start: bool) !void {
        try SelectionState.moveCaretSetToLineBoundary(self, to_start);
    }
    pub fn moveCaretSetByWord(self: *Editor, left: bool) !void {
        try SelectionState.moveCaretSetByWord(self, left);
    }
    pub fn extendCaretSetToOffsets(self: *Editor, target_offsets: []const usize) !void {
        try SelectionState.extendCaretSetToOffsets(self, target_offsets);
    }
    pub fn adjustPrimaryOffsetForReplacement(self: *Editor, primary_offset: *usize, start: usize, end: usize, replacement_len: usize) void {
        _ = self;
        SelectionState.adjustPrimaryOffsetForReplacement(primary_offset, start, end, replacement_len);
    }
    pub fn applySelectionReplacementOps(self: *Editor, ops: []const SelectionReplacementOp, initial_primary_offset: usize) !void {
        try SelectionState.applySelectionReplacementOps(self, ops, initial_primary_offset);
    }
    pub fn isWordByte(byte: u8) bool {
        return SelectionState.isWordByte(byte);
    }
    pub fn byteAt(self: *Editor, offset: usize) ?u8 {
        return SelectionState.byteAt(self, offset);
    }
    pub fn wordLeftOffset(self: *Editor, offset: usize) usize {
        return SelectionState.wordLeftOffset(self, offset);
    }
    pub fn wordRightOffset(self: *Editor, offset: usize) usize {
        return SelectionState.wordRightOffset(self, offset);
    }
    pub fn extendPrimarySelectionToOffset(self: *Editor, target_offset: usize) void {
        SelectionState.extendPrimarySelectionToOffset(self, target_offset);
    }

    fn byteIndexForVisualColumn(self: *Editor, line_text: []const u8, column: usize, clusters: ?[]const u32) usize {
        _ = self;
        return text_columns.byteIndexForVisualColumnWithClusters(line_text, column, clusters);
    }

    pub fn updateCursorPosition(self: *Editor) void {
        Navigation.updateCursorPosition(self);
    }
    pub fn updateCursorOffset(self: *Editor) void {
        Navigation.updateCursorOffset(self);
    }

    pub fn noteTextChangedBase(self: *Editor) void {
        self.modified = true;
        self.invalidateLineWidthCache();
        self.change_tick +|= 1;
    }

    pub fn pointForByte(self: *Editor, byte_offset: usize) c.TSPoint {
        return EditOps.pointForByte(self, byte_offset);
    }
    pub fn replaceByteRangeInternal(self: *Editor, start: usize, end: usize, replacement: []const u8, refresh_search: bool) !void {
        try EditOps.replaceByteRangeInternal(self, start, end, replacement, refresh_search);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Text editing
    // ─────────────────────────────────────────────────────────────────────────

    pub fn insertChar(self: *Editor, char: u8) !void {
        try EditOps.insertChar(self, char);
    }
    pub fn insertText(self: *Editor, text: []const u8) !void {
        try EditOps.insertText(self, text);
    }
    pub fn insertNewline(self: *Editor) !void {
        try EditOps.insertNewline(self);
    }
    pub fn deleteCharBackward(self: *Editor) !void {
        try EditOps.deleteCharBackward(self);
    }
    pub fn deleteCharForward(self: *Editor) !void {
        try EditOps.deleteCharForward(self);
    }
    pub fn deleteSelection(self: *Editor) !void {
        try EditOps.deleteSelection(self);
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

    pub fn noteTextChanged(self: *Editor) void {
        SearchHighlight.noteTextChanged(self);
    }

    pub fn noteTextChangedNoSearchRefresh(self: *Editor) void {
        SearchHighlight.noteTextChangedNoSearchRefresh(self);
    }

    pub fn noteHighlightDirtyRange(self: *Editor, start_byte: usize, end_byte: usize) void {
        SearchHighlight.noteHighlightDirtyRange(self, start_byte, end_byte);
    }

    pub fn applyHighlightEdit(
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

    pub fn tryInitHighlighter(self: *Editor, path: ?[]const u8) !void {
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

    pub fn jumpToSearchActive(self: *Editor) void {
        SearchHighlight.jumpToSearchActive(self);
    }

    pub fn findSearchMatchAtOrAfter(self: *const Editor, offset: usize) ?usize {
        return SearchHighlight.findSearchMatchAtOrAfter(self, offset);
    }

    pub fn clearSearchState(self: *Editor) void {
        SearchHighlight.clearSearchState(self);
    }

    pub fn recomputeSearchMatches(self: *Editor) !void {
        try SearchHighlight.recomputeSearchMatches(self);
    }

    pub fn recomputeSearchMatchesPrefer(self: *Editor, preferred_offset: usize) !void {
        try SearchHighlight.recomputeSearchMatchesPrefer(self, preferred_offset);
    }

    pub fn recomputeSearchMatchesSync(self: *Editor) !void {
        try SearchHighlight.recomputeSearchMatchesSync(self);
    }

    pub fn recomputeSearchMatchesSyncPrefer(self: *Editor, preferred_offset: usize) !void {
        try SearchHighlight.recomputeSearchMatchesSyncPrefer(self, preferred_offset);
    }

    pub fn queueSearchRequest(
        self: *Editor,
        preferred_offset: usize,
        mode: SearchMode,
        query: []u8,
        content: []u8,
    ) ?u64 {
        return SearchHighlight.queueSearchRequest(self, preferred_offset, mode, query, content);
    }

    pub fn emitMissingGrammarNotice(self: *Editor, auto_bootstrap_enabled: bool, bootstrap_attempted: bool, bootstrap_succeeded: bool) void {
        SearchHighlight.emitMissingGrammarNotice(self, auto_bootstrap_enabled, bootstrap_attempted, bootstrap_succeeded);
    }

    pub fn ensureSearchWorker(self: *Editor) void {
        SearchHighlight.ensureSearchWorker(self);
    }

    fn stopSearchWorker(self: *Editor) void {
        SearchHighlight.stopSearchWorker(self);
    }

    pub fn cancelPendingSearchWork(self: *Editor) void {
        SearchHighlight.cancelPendingSearchWork(self);
    }

    pub fn tryAutoBootstrapGrammars(self: *Editor) bool {
        return SearchHighlight.tryAutoBootstrapGrammars(self);
    }

    pub fn pickSearchActiveIndex(self: *const Editor, preferred_offset: usize) ?usize {
        return SearchHighlight.pickSearchActiveIndex(self, preferred_offset);
    }

    pub fn applyPendingSearchResult(self: *Editor) void {
        SearchHighlight.applyPendingSearchResult(self);
    }
};

const std = @import("std");
const text_store = @import("text_store.zig");
const text_columns = @import("text_columns.zig");
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
const c_allocator = std.heap.c_allocator;

var grammar_auto_bootstrap_lock: std.Thread.Mutex = .{};
const GrammarAutoBootstrapState = enum {
    idle,
    running,
    succeeded,
    failed,
};
var grammar_auto_bootstrap_state: GrammarAutoBootstrapState = .idle;
var grammar_missing_notice_lock: std.Thread.Mutex = .{};
var grammar_missing_notice_emitted: bool = false;

/// High-level editor state wrapping a text buffer
pub const Editor = struct {
    const highlighter_large_file_threshold_bytes: usize = 8 * 1024 * 1024;

    pub const ClusterProvider = struct {
        ctx: *anyopaque,
        getClusters: *const fn (ctx: *anyopaque, line_idx: usize, line_text: []const u8) ?[]const u32,
    };

    const StoredSelection = struct {
        start_offset: usize,
        end_offset: usize,
        is_rectangular: bool = false,
    };

    const UndoSelectionState = struct {
        id: u64,
        cursor_offset: usize,
        selection: ?StoredSelection,
        selections: []StoredSelection,
    };

    pub const SearchMatch = struct {
        start: usize,
        end: usize,
    };

    pub const SearchMode = enum {
        literal,
        regex,
    };

    const SearchWorkRequest = struct {
        generation: u64,
        preferred_offset: usize,
        mode: SearchMode,
        query: []u8,
        content: []u8,
    };

    const SearchWorkResult = struct {
        generation: u64,
        preferred_offset: usize,
        matches: []SearchMatch,
    };

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
        const log = app_logger.logger("editor.input");
        if (self.hasOnlyCaretSelections()) {
            self.moveCaretSetHorizontal(-1) catch |err| {
                log.logf(.warning, "move caret set left failed: {s}", .{@errorName(err)});
            };
            return;
        }
        if (self.hasSelectionSetState() and !self.hasRectangularSelectionState()) {
            var collapsed = std.ArrayList(usize).empty;
            defer collapsed.deinit(self.allocator);
            if (self.selection) |sel| {
                self.tryAppendCollapseOffset(&collapsed, sel.normalized().start.offset);
            } else {
                self.tryAppendCollapseOffset(&collapsed, self.cursor.offset);
            }
            for (self.selections.items) |sel| {
                self.tryAppendCollapseOffset(&collapsed, sel.normalized().start.offset);
            }
            self.restoreCaretSelections(collapsed.items, collapsed.items[0]) catch |err| {
                log.logf(.warning, "restore collapsed carets (left) failed: {s}", .{@errorName(err)});
            };
            self.selection = null;
            return;
        }
        if (self.cursor.offset == 0) return;
        self.cursor.offset -= 1;
        self.updateCursorPosition();
        self.preferred_visual_col = null;
        self.selection = null;
        self.clearSelections();
    }

    pub fn moveCursorRight(self: *Editor) void {
        const log = app_logger.logger("editor.input");
        if (self.hasOnlyCaretSelections()) {
            self.moveCaretSetHorizontal(1) catch |err| {
                log.logf(.warning, "move caret set right failed: {s}", .{@errorName(err)});
            };
            return;
        }
        if (self.hasSelectionSetState() and !self.hasRectangularSelectionState()) {
            var collapsed = std.ArrayList(usize).empty;
            defer collapsed.deinit(self.allocator);
            if (self.selection) |sel| {
                self.tryAppendCollapseOffset(&collapsed, sel.normalized().end.offset);
            } else {
                self.tryAppendCollapseOffset(&collapsed, self.cursor.offset);
            }
            for (self.selections.items) |sel| {
                self.tryAppendCollapseOffset(&collapsed, sel.normalized().end.offset);
            }
            self.restoreCaretSelections(collapsed.items, collapsed.items[0]) catch |err| {
                log.logf(.warning, "restore collapsed carets (right) failed: {s}", .{@errorName(err)});
            };
            self.selection = null;
            return;
        }
        const total = self.buffer.totalLen();
        if (self.cursor.offset >= total) return;
        self.cursor.offset += 1;
        self.updateCursorPosition();
        self.preferred_visual_col = null;
        self.selection = null;
        self.clearSelections();
    }

    pub fn moveCursorUp(self: *Editor) void {
        const log = app_logger.logger("editor.input");
        if (self.hasOnlyCaretSelections()) return;
        if (self.hasSelectionSetState() and !self.hasRectangularSelectionState()) {
            var collapsed = std.ArrayList(usize).empty;
            defer collapsed.deinit(self.allocator);
            if (self.selection) |sel| {
                self.tryAppendCollapseOffset(&collapsed, sel.normalized().start.offset);
            } else {
                self.tryAppendCollapseOffset(&collapsed, self.cursor.offset);
            }
            for (self.selections.items) |sel| {
                self.tryAppendCollapseOffset(&collapsed, sel.normalized().start.offset);
            }
            self.restoreCaretSelections(collapsed.items, collapsed.items[0]) catch |err| {
                log.logf(.warning, "restore collapsed carets (up) failed: {s}", .{@errorName(err)});
            };
            self.selection = null;
            return;
        }
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
        const log = app_logger.logger("editor.input");
        if (self.hasOnlyCaretSelections()) return;
        if (self.hasSelectionSetState() and !self.hasRectangularSelectionState()) {
            var collapsed = std.ArrayList(usize).empty;
            defer collapsed.deinit(self.allocator);
            if (self.selection) |sel| {
                self.tryAppendCollapseOffset(&collapsed, sel.normalized().end.offset);
            } else {
                self.tryAppendCollapseOffset(&collapsed, self.cursor.offset);
            }
            for (self.selections.items) |sel| {
                self.tryAppendCollapseOffset(&collapsed, sel.normalized().end.offset);
            }
            self.restoreCaretSelections(collapsed.items, collapsed.items[0]) catch |err| {
                log.logf(.warning, "restore collapsed carets (down) failed: {s}", .{@errorName(err)});
            };
            self.selection = null;
            return;
        }
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
        const log = app_logger.logger("editor.input");
        if (self.hasOnlyCaretSelections()) {
            self.moveCaretSetToLineBoundary(true) catch |err| {
                log.logf(.warning, "move caret set to line start failed: {s}", .{@errorName(err)});
            };
            return;
        }
        self.cursor.col = 0;
        self.updateCursorOffset();
        self.preferred_visual_col = null;
        self.selection = null;
        self.clearSelections();
    }

    pub fn moveCursorToLineEnd(self: *Editor) void {
        const log = app_logger.logger("editor.input");
        if (self.hasOnlyCaretSelections()) {
            self.moveCaretSetToLineBoundary(false) catch |err| {
                log.logf(.warning, "move caret set to line end failed: {s}", .{@errorName(err)});
            };
            return;
        }
        const line_len = self.buffer.lineLen(self.cursor.line);
        self.cursor.col = line_len;
        self.updateCursorOffset();
        self.preferred_visual_col = null;
        self.selection = null;
        self.clearSelections();
    }

    pub fn moveCursorWordLeft(self: *Editor) void {
        const log = app_logger.logger("editor.input");
        if (self.hasOnlyCaretSelections()) {
            self.moveCaretSetByWord(true) catch |err| {
                log.logf(.warning, "move caret set word-left failed: {s}", .{@errorName(err)});
            };
            return;
        }
        const target = self.wordLeftOffset(self.cursor.offset);
        self.setCursorOffsetNoClear(target);
        self.selection = null;
        self.clearSelections();
    }

    pub fn moveCursorWordRight(self: *Editor) void {
        const log = app_logger.logger("editor.input");
        if (self.hasOnlyCaretSelections()) {
            self.moveCaretSetByWord(false) catch |err| {
                log.logf(.warning, "move caret set word-right failed: {s}", .{@errorName(err)});
            };
            return;
        }
        const target = self.wordRightOffset(self.cursor.offset);
        self.setCursorOffsetNoClear(target);
        self.selection = null;
        self.clearSelections();
    }

    pub fn hasRectangularSelectionState(self: *Editor) bool {
        if (self.selection) |sel| {
            if (sel.is_rectangular) return true;
        }
        for (self.selections.items) |sel| {
            if (sel.is_rectangular) return true;
        }
        return false;
    }

    pub fn hasSelectionSetState(self: *Editor) bool {
        return self.selection != null or self.selections.items.len > 0;
    }

    pub fn collectSelectionAnchorsAndHeads(self: *Editor, anchors: *std.ArrayList(usize), heads: *std.ArrayList(usize)) !void {
        if (self.selection) |sel| {
            try anchors.append(self.allocator, sel.start.offset);
            try heads.append(self.allocator, sel.end.offset);
        } else {
            try anchors.append(self.allocator, self.cursor.offset);
            try heads.append(self.allocator, self.cursor.offset);
        }
        for (self.selections.items) |sel| {
            try anchors.append(self.allocator, sel.start.offset);
            try heads.append(self.allocator, sel.end.offset);
        }
    }

    fn tryAppendCollapseOffset(self: *Editor, offsets: *std.ArrayList(usize), offset: usize) void {
        if (std.mem.indexOfScalar(usize, offsets.items, offset) != null) return;
        offsets.append(self.allocator, offset) catch |err| {
            const log = app_logger.logger("editor.input");
            log.logf(.warning, "append collapse offset failed offset={d}: {s}", .{ offset, @errorName(err) });
        };
    }

    fn extendSelectionSetWithHeads(self: *Editor, target_heads: []const usize) !void {
        var anchor_offsets = std.ArrayList(usize).empty;
        defer anchor_offsets.deinit(self.allocator);
        var head_offsets = std.ArrayList(usize).empty;
        defer head_offsets.deinit(self.allocator);
        try self.collectSelectionAnchorsAndHeads(&anchor_offsets, &head_offsets);
        std.debug.assert(anchor_offsets.items.len == target_heads.len);
        try self.restoreExtendedCaretSelections(anchor_offsets.items, target_heads);
    }

    pub fn extendSelectionLeft(self: *Editor) void {
        const log = app_logger.logger("editor.input");
        if (self.hasSelectionSetState() and !self.hasRectangularSelectionState()) {
            var anchors = std.ArrayList(usize).empty;
            defer anchors.deinit(self.allocator);
            var target_heads = std.ArrayList(usize).empty;
            defer target_heads.deinit(self.allocator);
            self.collectSelectionAnchorsAndHeads(&anchors, &target_heads) catch |err| {
                log.logf(.warning, "collect selection anchors/heads (left) failed: {s}", .{@errorName(err)});
                return;
            };
            for (target_heads.items) |*offset| {
                if (offset.* > 0) offset.* -= 1;
            }
            self.restoreExtendedCaretSelections(anchors.items, target_heads.items) catch |err| {
                log.logf(.warning, "restore extended carets (left) failed: {s}", .{@errorName(err)});
            };
            return;
        }
        self.extendPrimarySelectionToOffset(if (self.cursor.offset > 0) self.cursor.offset - 1 else 0);
    }

    pub fn extendSelectionRight(self: *Editor) void {
        const log = app_logger.logger("editor.input");
        if (self.hasSelectionSetState() and !self.hasRectangularSelectionState()) {
            var anchors = std.ArrayList(usize).empty;
            defer anchors.deinit(self.allocator);
            var target_heads = std.ArrayList(usize).empty;
            defer target_heads.deinit(self.allocator);
            self.collectSelectionAnchorsAndHeads(&anchors, &target_heads) catch |err| {
                log.logf(.warning, "collect selection anchors/heads (right) failed: {s}", .{@errorName(err)});
                return;
            };
            const total = self.buffer.totalLen();
            for (target_heads.items) |*offset| {
                if (offset.* < total) offset.* += 1;
            }
            self.restoreExtendedCaretSelections(anchors.items, target_heads.items) catch |err| {
                log.logf(.warning, "restore extended carets (right) failed: {s}", .{@errorName(err)});
            };
            return;
        }
        const total = self.buffer.totalLen();
        self.extendPrimarySelectionToOffset(if (self.cursor.offset < total) self.cursor.offset + 1 else total);
    }

    pub fn extendSelectionToLineStart(self: *Editor) void {
        const log = app_logger.logger("editor.input");
        if (self.hasSelectionSetState() and !self.hasRectangularSelectionState()) {
            var anchors = std.ArrayList(usize).empty;
            defer anchors.deinit(self.allocator);
            var target_heads = std.ArrayList(usize).empty;
            defer target_heads.deinit(self.allocator);
            self.collectSelectionAnchorsAndHeads(&anchors, &target_heads) catch |err| {
                log.logf(.warning, "collect selection anchors/heads (line-start) failed: {s}", .{@errorName(err)});
                return;
            };
            for (target_heads.items) |*offset| {
                const caret = self.cursorPosForOffset(offset.*);
                offset.* = self.buffer.lineStart(caret.line);
            }
            self.restoreExtendedCaretSelections(anchors.items, target_heads.items) catch |err| {
                log.logf(.warning, "restore extended carets (line-start) failed: {s}", .{@errorName(err)});
            };
            return;
        }
        self.extendPrimarySelectionToOffset(self.buffer.lineStart(self.cursor.line));
    }

    pub fn extendSelectionToLineEnd(self: *Editor) void {
        const log = app_logger.logger("editor.input");
        if (self.hasSelectionSetState() and !self.hasRectangularSelectionState()) {
            var anchors = std.ArrayList(usize).empty;
            defer anchors.deinit(self.allocator);
            var target_heads = std.ArrayList(usize).empty;
            defer target_heads.deinit(self.allocator);
            self.collectSelectionAnchorsAndHeads(&anchors, &target_heads) catch |err| {
                log.logf(.warning, "collect selection anchors/heads (line-end) failed: {s}", .{@errorName(err)});
                return;
            };
            for (target_heads.items) |*offset| {
                const caret = self.cursorPosForOffset(offset.*);
                offset.* = self.buffer.lineStart(caret.line) + self.buffer.lineLen(caret.line);
            }
            self.restoreExtendedCaretSelections(anchors.items, target_heads.items) catch |err| {
                log.logf(.warning, "restore extended carets (line-end) failed: {s}", .{@errorName(err)});
            };
            return;
        }
        self.extendPrimarySelectionToOffset(self.buffer.lineStart(self.cursor.line) + self.buffer.lineLen(self.cursor.line));
    }

    pub fn extendSelectionWordLeft(self: *Editor) void {
        const log = app_logger.logger("editor.input");
        if (self.hasSelectionSetState() and !self.hasRectangularSelectionState()) {
            var anchors = std.ArrayList(usize).empty;
            defer anchors.deinit(self.allocator);
            var target_heads = std.ArrayList(usize).empty;
            defer target_heads.deinit(self.allocator);
            self.collectSelectionAnchorsAndHeads(&anchors, &target_heads) catch |err| {
                log.logf(.warning, "collect selection anchors/heads (word-left) failed: {s}", .{@errorName(err)});
                return;
            };
            for (target_heads.items) |*offset| {
                offset.* = self.wordLeftOffset(offset.*);
            }
            self.restoreExtendedCaretSelections(anchors.items, target_heads.items) catch |err| {
                log.logf(.warning, "restore extended carets (word-left) failed: {s}", .{@errorName(err)});
            };
            return;
        }
        self.extendPrimarySelectionToOffset(self.wordLeftOffset(self.cursor.offset));
    }

    pub fn extendSelectionWordRight(self: *Editor) void {
        const log = app_logger.logger("editor.input");
        if (self.hasSelectionSetState() and !self.hasRectangularSelectionState()) {
            var anchors = std.ArrayList(usize).empty;
            defer anchors.deinit(self.allocator);
            var target_heads = std.ArrayList(usize).empty;
            defer target_heads.deinit(self.allocator);
            self.collectSelectionAnchorsAndHeads(&anchors, &target_heads) catch |err| {
                log.logf(.warning, "collect selection anchors/heads (word-right) failed: {s}", .{@errorName(err)});
                return;
            };
            for (target_heads.items) |*offset| {
                offset.* = self.wordRightOffset(offset.*);
            }
            self.restoreExtendedCaretSelections(anchors.items, target_heads.items) catch |err| {
                log.logf(.warning, "restore extended carets (word-right) failed: {s}", .{@errorName(err)});
            };
            return;
        }
        self.extendPrimarySelectionToOffset(self.wordRightOffset(self.cursor.offset));
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

    pub fn primaryCaret(self: *Editor) CursorPos {
        return self.cursor;
    }

    pub fn auxiliaryCaretCount(self: *Editor) usize {
        var count: usize = 0;
        for (self.selections.items) |sel| {
            if (sel.normalized().isEmpty()) count += 1;
        }
        return count;
    }

    pub fn auxiliaryCaretAt(self: *Editor, index: usize) ?CursorPos {
        var seen: usize = 0;
        for (self.selections.items) |sel| {
            const norm = sel.normalized();
            if (!norm.isEmpty()) continue;
            if (seen == index) return norm.start;
            seen += 1;
        }
        return null;
    }

    fn storedSelectionFromSelection(sel: Selection) StoredSelection {
        return .{
            .start_offset = sel.start.offset,
            .end_offset = sel.end.offset,
            .is_rectangular = sel.is_rectangular,
        };
    }

    fn selectionFromStored(self: *Editor, stored: StoredSelection) Selection {
        const total = self.buffer.totalLen();
        const start = self.cursorPosForOffset(@min(stored.start_offset, total));
        const end = self.cursorPosForOffset(@min(stored.end_offset, total));
        return .{
            .start = start,
            .end = end,
            .is_rectangular = stored.is_rectangular,
        };
    }

    fn rectangularPasteLines(self: *Editor, text: []const u8) !?[][]const u8 {
        if (self.selections.items.len == 0) return null;
        for (self.selections.items) |sel| {
            if (!sel.is_rectangular) return null;
        }

        var line_count: usize = 1;
        for (text) |byte| {
            if (byte == '\n') line_count += 1;
        }
        var clipboard_lines = try self.allocator.alloc([]const u8, line_count);
        errdefer self.allocator.free(clipboard_lines);
        var start: usize = 0;
        var line_idx: usize = 0;
        for (text, 0..) |byte, idx| {
            if (byte != '\n') continue;
            const raw = text[start..idx];
            clipboard_lines[line_idx] = if (raw.len > 0 and raw[raw.len - 1] == '\r') raw[0 .. raw.len - 1] else raw;
            line_idx += 1;
            start = idx + 1;
        }
        const raw_tail = text[start..];
        clipboard_lines[line_idx] = if (raw_tail.len > 0 and raw_tail[raw_tail.len - 1] == '\r') raw_tail[0 .. raw_tail.len - 1] else raw_tail;

        const lines = try self.allocator.alloc([]const u8, self.selections.items.len);
        errdefer self.allocator.free(lines);
        if (clipboard_lines.len == 1) {
            for (lines) |*line| {
                line.* = clipboard_lines[0];
            }
        } else if (clipboard_lines.len == self.selections.items.len) {
            for (lines, clipboard_lines) |*line, clip_line| {
                line.* = clip_line;
            }
        } else {
            for (lines, 0..) |*line, idx| {
                line.* = clipboard_lines[idx % clipboard_lines.len];
            }
        }
        self.allocator.free(clipboard_lines);
        return lines;
    }

    fn captureUndoSelectionState(self: *Editor) !u64 {
        const id = self.next_undo_selection_state_id;
        self.next_undo_selection_state_id +|= 1;

        var extra = try self.allocator.alloc(StoredSelection, self.selections.items.len);
        for (self.selections.items, 0..) |sel, idx| {
            extra[idx] = storedSelectionFromSelection(sel);
        }

        try self.undo_selection_states.append(self.allocator, .{
            .id = id,
            .cursor_offset = self.cursor.offset,
            .selection = if (self.selection) |sel| storedSelectionFromSelection(sel) else null,
            .selections = extra,
        });
        return id;
    }

    fn restoreUndoSelectionState(self: *Editor, state_id: u64) !bool {
        for (self.undo_selection_states.items) |state| {
            if (state.id != state_id) continue;
            const total = self.buffer.totalLen();
            self.cursor = self.cursorPosForOffset(@min(state.cursor_offset, total));
            self.preferred_visual_col = null;
            self.selection = if (state.selection) |sel| self.selectionFromStored(sel) else null;
            self.clearSelections();
            for (state.selections) |sel| {
                try self.selections.append(self.allocator, self.selectionFromStored(sel));
            }
            return true;
        }
        return false;
    }

    fn annotateLastUndoSelectionState(self: *Editor, before_id: u64, after_id: u64) void {
        self.buffer.annotateLastUndoState(before_id, after_id);
    }

    fn beginTrackedUndoGroup(self: *Editor) !u64 {
        const before_id = try self.captureUndoSelectionState();
        self.buffer.beginUndoGroup();
        self.buffer.annotateCurrentUndoGroupBefore(before_id);
        return before_id;
    }

    fn endTrackedUndoGroup(self: *Editor) !void {
        const after_id = try self.captureUndoSelectionState();
        try self.buffer.endUndoGroup();
        self.buffer.annotateClosedUndoGroupAfter(after_id);
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

    pub fn expandRectSelectionVisual(self: *Editor, start_line: usize, end_line: usize, start_col_vis: usize, end_col_vis: usize) !void {
        return self.expandRectSelectionVisualWithClusters(start_line, end_line, start_col_vis, end_col_vis, null);
    }

    pub fn expandRectSelectionVisualWithClusters(
        self: *Editor,
        start_line: usize,
        end_line: usize,
        start_col_vis: usize,
        end_col_vis: usize,
        provider: ?*const ClusterProvider,
    ) !void {
        if (start_line > end_line) return;
        var line = start_line;
        while (line <= end_line) : (line += 1) {
            const line_start = self.buffer.lineStart(line);
            const line_text = try self.getLineAlloc(line);
            defer self.allocator.free(line_text);
            const clusters = if (provider) |cluster_provider| cluster_provider.getClusters(cluster_provider.ctx, line, line_text) else null;
            const start_byte = self.byteIndexForVisualColumn(line_text, start_col_vis, clusters);
            const end_byte = self.byteIndexForVisualColumn(line_text, end_col_vis, clusters);
            const start = CursorPos{ .line = line, .col = start_byte, .offset = line_start + start_byte };
            const end = CursorPos{ .line = line, .col = end_byte, .offset = line_start + end_byte };
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

    fn duplicateNormalizedSelectionsDescending(self: *Editor) ![]Selection {
        try self.normalizeSelectionsDescending();
        return self.allocator.dupe(Selection, self.selections.items);
    }

    const SelectionReplacementOp = struct {
        start: usize,
        end: usize,
        replacement: []const u8,
    };

    pub fn addCaretUp(self: *Editor) !bool {
        return self.addCaretVertical(-1);
    }

    pub fn addCaretDown(self: *Editor) !bool {
        return self.addCaretVertical(1);
    }

    fn addCaretVertical(self: *Editor, delta: i32) !bool {
        if (delta == 0) return false;
        if (self.selection != null) return false;
        if (self.auxiliaryCaretCount() != self.selections.items.len) return false;

        var caret_offsets = std.ArrayList(usize).empty;
        defer caret_offsets.deinit(self.allocator);

        try caret_offsets.append(self.allocator, self.primaryCaret().offset);
        var idx: usize = 0;
        while (idx < self.auxiliaryCaretCount()) : (idx += 1) {
            const caret = self.auxiliaryCaretAt(idx) orelse continue;
            if (caret.offset == self.primaryCaret().offset) continue;
            if (std.mem.indexOfScalar(usize, caret_offsets.items, caret.offset) != null) continue;
            try caret_offsets.append(self.allocator, caret.offset);
        }

        var added_any = false;
        for (caret_offsets.items) |offset| {
            const caret = self.cursorPosForOffset(offset);
            const target_line = if (delta < 0) blk: {
                if (caret.line == 0) continue;
                break :blk caret.line - 1;
            } else blk: {
                if (caret.line + 1 >= self.buffer.lineCount()) continue;
                break :blk caret.line + 1;
            };
            const target_col = @min(caret.col, self.buffer.lineLen(target_line));
            const target_offset = self.buffer.lineStart(target_line) + target_col;
            if (target_offset == self.cursor.offset) continue;
            if (std.mem.indexOfScalar(usize, caret_offsets.items, target_offset) != null) continue;
            try self.selections.append(self.allocator, .{
                .start = .{
                    .line = target_line,
                    .col = target_col,
                    .offset = target_offset,
                },
                .end = .{
                    .line = target_line,
                    .col = target_col,
                    .offset = target_offset,
                },
            });
            try caret_offsets.append(self.allocator, target_offset);
            added_any = true;
        }

        if (added_any) {
            try self.normalizeSelections();
        }
        return added_any;
    }

    fn cursorPosForOffset(self: *Editor, offset: usize) CursorPos {
        const line = self.buffer.lineIndexForOffset(offset);
        const line_start = self.buffer.lineStart(line);
        return .{
            .line = line,
            .col = offset - line_start,
            .offset = offset,
        };
    }

    fn shiftCaretOffsets(caret_offsets: *std.ArrayList(usize), delta: isize) void {
        if (delta == 0) return;
        for (caret_offsets.items) |*offset| {
            const shifted = @as(isize, @intCast(offset.*)) + delta;
            offset.* = @intCast(shifted);
        }
    }

    fn hasOnlyCaretSelections(self: *Editor) bool {
        return self.auxiliaryCaretCount() > 0 and self.auxiliaryCaretCount() == self.selections.items.len;
    }

    fn collectCaretOffsets(self: *Editor) !std.ArrayList(usize) {
        var caret_offsets = std.ArrayList(usize).empty;
        errdefer caret_offsets.deinit(self.allocator);

        try caret_offsets.append(self.allocator, self.primaryCaret().offset);
        var idx: usize = 0;
        while (idx < self.auxiliaryCaretCount()) : (idx += 1) {
            const caret = self.auxiliaryCaretAt(idx) orelse continue;
            if (std.mem.indexOfScalar(usize, caret_offsets.items, caret.offset) != null) continue;
            try caret_offsets.append(self.allocator, caret.offset);
        }
        return caret_offsets;
    }

    fn collectCaretOffsetsDescending(self: *Editor) !std.ArrayList(usize) {
        const caret_offsets = try self.collectCaretOffsets();
        std.sort.block(usize, caret_offsets.items, {}, struct {
            fn lessThan(_: void, a: usize, b: usize) bool {
                return a > b;
            }
        }.lessThan);
        return caret_offsets;
    }

    fn restoreCaretSelections(self: *Editor, caret_offsets: []const usize, primary_offset: usize) !void {
        self.clearSelections();
        self.cursor = self.cursorPosForOffset(primary_offset);
        for (caret_offsets) |offset| {
            if (offset == primary_offset) continue;
            const caret = self.cursorPosForOffset(offset);
            try self.selections.append(self.allocator, .{
                .start = caret,
                .end = caret,
            });
        }
        if (self.selections.items.len > 0) {
            try self.normalizeSelections();
            var idx: usize = 0;
            while (idx < self.selections.items.len) {
                if (self.selections.items[idx].start.offset == primary_offset and self.selections.items[idx].isEmpty()) {
                    _ = self.selections.orderedRemove(idx);
                } else {
                    idx += 1;
                }
            }
        }
    }

    pub fn restoreExtendedCaretSelections(self: *Editor, anchor_offsets: []const usize, target_offsets: []const usize) !void {
        std.debug.assert(anchor_offsets.len == target_offsets.len);
        std.debug.assert(anchor_offsets.len > 0);

        self.preferred_visual_col = null;
        self.clearSelections();

        const primary_anchor = self.cursorPosForOffset(anchor_offsets[0]);
        const primary_target = self.cursorPosForOffset(target_offsets[0]);
        self.cursor = primary_target;
        self.selection = if (primary_anchor.offset == primary_target.offset)
            null
        else
            .{ .start = primary_anchor, .end = primary_target };

        var idx: usize = 1;
        while (idx < anchor_offsets.len) : (idx += 1) {
            const anchor = self.cursorPosForOffset(anchor_offsets[idx]);
            const target = self.cursorPosForOffset(target_offsets[idx]);
            try self.selections.append(self.allocator, if (anchor.offset == target.offset)
                .{ .start = target, .end = target }
            else
                .{ .start = anchor, .end = target });
        }
    }

    fn moveCaretSetHorizontal(self: *Editor, delta: isize) !void {
        var caret_offsets = try self.collectCaretOffsets();
        defer caret_offsets.deinit(self.allocator);
        const primary_offset = caret_offsets.items[0];

        const total = self.buffer.totalLen();
        for (caret_offsets.items) |*offset| {
            if (delta < 0) {
                if (offset.* > 0) offset.* -= 1;
            } else if (delta > 0) {
                if (offset.* < total) offset.* += 1;
            }
        }

        self.preferred_visual_col = null;
        self.selection = null;
        try self.restoreCaretSelections(caret_offsets.items, if (delta < 0) if (primary_offset > 0) primary_offset - 1 else 0 else @min(primary_offset + 1, total));
    }

    fn moveCaretSetToLineBoundary(self: *Editor, to_start: bool) !void {
        var caret_offsets = try self.collectCaretOffsets();
        defer caret_offsets.deinit(self.allocator);
        var primary_offset = caret_offsets.items[0];

        for (caret_offsets.items) |*offset| {
            const caret = self.cursorPosForOffset(offset.*);
            if (to_start) {
                offset.* = self.buffer.lineStart(caret.line);
            } else {
                offset.* = self.buffer.lineStart(caret.line) + self.buffer.lineLen(caret.line);
            }
            if (offset == &caret_offsets.items[0]) primary_offset = offset.*;
        }

        self.preferred_visual_col = null;
        self.selection = null;
        try self.restoreCaretSelections(caret_offsets.items, primary_offset);
    }

    fn moveCaretSetByWord(self: *Editor, left: bool) !void {
        var caret_offsets = try self.collectCaretOffsets();
        defer caret_offsets.deinit(self.allocator);

        for (caret_offsets.items) |*offset| {
            offset.* = if (left) self.wordLeftOffset(offset.*) else self.wordRightOffset(offset.*);
        }

        self.preferred_visual_col = null;
        self.selection = null;
        try self.restoreCaretSelections(caret_offsets.items, caret_offsets.items[0]);
    }

    fn extendCaretSetToOffsets(self: *Editor, target_offsets: []const usize) !void {
        var anchor_offsets = try self.collectCaretOffsets();
        defer anchor_offsets.deinit(self.allocator);
        try self.restoreExtendedCaretSelections(anchor_offsets.items, target_offsets);
    }

    fn adjustPrimaryOffsetForReplacement(primary_offset: *usize, start: usize, end: usize, replacement_len: usize) void {
        const deleted_len = end - start;
        if (primary_offset.* > end) {
            primary_offset.* = @intCast(@as(isize, @intCast(primary_offset.*)) + @as(isize, @intCast(replacement_len)) - @as(isize, @intCast(deleted_len)));
        } else if (primary_offset.* >= start) {
            primary_offset.* = start + replacement_len;
        }
    }

    fn applySelectionReplacementOps(
        self: *Editor,
        ops: []const SelectionReplacementOp,
        initial_primary_offset: usize,
    ) !void {
        var changed = false;
        var caret_offsets = std.ArrayList(usize).empty;
        defer caret_offsets.deinit(self.allocator);
        var primary_offset = initial_primary_offset;

        for (ops) |op| {
            const delete_len = op.end - op.start;
            if (delete_len > 0) {
                const start_point = self.pointForByte(op.start);
                const end_point = self.pointForByte(op.end);
                try self.buffer.deleteRange(op.start, delete_len);
                self.applyHighlightEdit(op.start, op.end, op.start, start_point, end_point);
                changed = true;
            }
            if (op.replacement.len > 0) {
                const insert_point = self.pointForByte(op.start);
                try self.buffer.insertBytes(op.start, op.replacement);
                self.applyHighlightEdit(op.start, op.start, op.start + op.replacement.len, insert_point, insert_point);
                changed = true;
            }
            shiftCaretOffsets(&caret_offsets, @as(isize, @intCast(op.replacement.len)) - @as(isize, @intCast(delete_len)));
            adjustPrimaryOffsetForReplacement(&primary_offset, op.start, op.end, op.replacement.len);
            try caret_offsets.append(self.allocator, op.start + op.replacement.len);
        }

        if (changed) self.noteTextChanged();
        try self.restoreCaretSelections(caret_offsets.items, primary_offset);
        self.selection = null;
    }

    fn isWordByte(byte: u8) bool {
        return std.ascii.isAlphanumeric(byte) or byte == '_';
    }

    fn byteAt(self: *Editor, offset: usize) ?u8 {
        if (offset >= self.buffer.totalLen()) return null;
        var buf: [1]u8 = undefined;
        return if (self.buffer.readRange(offset, &buf) == 1) buf[0] else null;
    }

    fn wordLeftOffset(self: *Editor, offset: usize) usize {
        if (offset == 0) return 0;
        var idx = offset - 1;
        while (idx > 0) : (idx -= 1) {
            const byte = self.byteAt(idx) orelse break;
            if (isWordByte(byte)) break;
        }
        while (idx > 0) {
            const prev = self.byteAt(idx - 1) orelse break;
            if (!isWordByte(prev)) break;
            idx -= 1;
        }
        return idx;
    }

    fn wordRightOffset(self: *Editor, offset: usize) usize {
        const total = self.buffer.totalLen();
        var idx = offset;
        while (idx < total) : (idx += 1) {
            const byte = self.byteAt(idx) orelse break;
            if (!isWordByte(byte)) break;
        }
        while (idx < total) : (idx += 1) {
            const byte = self.byteAt(idx) orelse break;
            if (isWordByte(byte)) break;
        }
        return idx;
    }

    fn extendPrimarySelectionToOffset(self: *Editor, target_offset: usize) void {
        const anchor = if (self.selection) |sel| sel.normalized().start else self.cursor;
        const target = self.cursorPosForOffset(target_offset);
        self.cursor = target;
        self.preferred_visual_col = null;
        self.clearSelections();
        if (anchor.offset == target.offset) {
            self.selection = null;
            return;
        }
        self.selection = .{ .start = anchor, .end = target };
    }

    fn byteIndexForVisualColumn(self: *Editor, line_text: []const u8, column: usize, clusters: ?[]const u32) usize {
        _ = self;
        return text_columns.byteIndexForVisualColumnWithClusters(line_text, column, clusters);
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
        self.noteTextChangedBase();
        if (self.search_query != null) {
            self.recomputeSearchMatches() catch |err| {
                const log = app_logger.logger("editor.search");
                log.logf(.warning, "recompute search matches on text change failed: {s}", .{@errorName(err)});
            };
        }
    }

    fn noteTextChangedNoSearchRefresh(self: *Editor) void {
        self.noteTextChangedBase();
    }

    fn noteTextChangedBase(self: *Editor) void {
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

    fn scheduleHighlighter(self: *Editor, path: ?[]const u8) void {
        const log = app_logger.logger("editor.highlight");
        if (self.highlight_disabled_for_large_file) {
            if (self.highlighter) |h| {
                h.destroy();
                self.highlighter = null;
            }
            self.highlight_epoch +|= 1;
            self.highlight_dirty_start_line = null;
            self.highlight_dirty_end_line = null;
            self.highlight_pending = false;
            log.logf(
                .info,
                "highlight skipped large_file bytes={d} threshold={d} path=\"{s}\"",
                .{ self.buffer.totalLen(), highlighter_large_file_threshold_bytes, path orelse "" },
            );
            return;
        }
        if (syntax_registry_mod.SyntaxRegistry.resolveLanguage(path) == null) {
            if (self.highlighter) |h| {
                h.destroy();
                self.highlighter = null;
            }
            self.highlight_epoch +|= 1;
            self.highlight_dirty_start_line = null;
            self.highlight_dirty_end_line = null;
            self.highlight_pending = false;
            log.logf(.info, "highlight disabled path=\"{s}\"", .{path orelse ""});
            return;
        }
        self.highlight_pending = true;
        log.logf(.info, "highlight scheduled path=\"{s}\"", .{path orelse ""});
    }

    fn tryInitHighlighter(self: *Editor, path: ?[]const u8) !void {
        const log = app_logger.logger("editor.highlight");
        log.logf(.info, "highlight init check path=\"{s}\"", .{path orelse ""});
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
            log.logf(.info, "highlight disabled path=\"{s}\"", .{path orelse ""});
            return;
        }
        if (self.highlighter == null) {
            const t_start = std.time.nanoTimestamp();
            log.logf(.info, "highlight init start", .{});
            const grammar = try self.grammar_manager.getOrLoad(lang.?) orelse blk: {
                log.logf(.info, "highlight missing grammar lang={s}", .{lang.?});
                if (shouldAutoBootstrapGrammars()) {
                    _ = self.tryAutoBootstrapGrammars();
                    switch (grammarAutoBootstrapState()) {
                        .running => return,
                        .succeeded => {
                            if (try self.grammar_manager.getOrLoad(lang.?)) |loaded| {
                                log.logf(.info, "highlight grammar loaded after bootstrap lang={s}", .{lang.?});
                                break :blk loaded;
                            }
                            log.logf(.info, "highlight grammar still missing after bootstrap lang={s}", .{lang.?});
                            self.emitMissingGrammarNotice(true, true, false);
                        },
                        .failed => self.emitMissingGrammarNotice(true, true, false),
                        .idle => self.emitMissingGrammarNotice(true, false, false),
                    }
                } else {
                    self.emitMissingGrammarNotice(false, false, false);
                }
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
                log.logf(.info, "highlight init failed err={any}", .{err});
                return err;
            };
            self.highlight_epoch +|= 1;
            self.noteHighlightDirtyRange(0, self.buffer.totalLen());
            const elapsed_ns = std.time.nanoTimestamp() - t_start;
            log.logf(
                .info,
                "highlight enabled path=\"{s}\" time_us={d}",
                .{ path orelse "", @as(i64, @intCast(@divTrunc(elapsed_ns, 1000))) },
            );
        }
    }

    fn tryAutoBootstrapGrammars(self: *Editor) bool {
        _ = self;
        grammar_auto_bootstrap_lock.lock();
        defer grammar_auto_bootstrap_lock.unlock();
        if (grammar_auto_bootstrap_state != .idle) return false;
        grammar_auto_bootstrap_state = .running;

        const worker = std.Thread.spawn(.{}, grammarAutoBootstrapWorker, .{}) catch |err| {
            grammar_auto_bootstrap_state = .failed;
            const log = app_logger.logger("editor.grammar");
            log.logf(.info, "auto bootstrap worker spawn failed err={any}", .{err});
            return false;
        };
        worker.detach();
        return true;
    }

    fn grammarAutoBootstrapWorker() void {
        const log = app_logger.logger("editor.grammar");
        log.logf(.info, "auto bootstrap start cmd=\"zig build grammar-update -- --skip-git --continue-on-error\"", .{});

        var child = std.process.Child.init(&.{
            "zig",
            "build",
            "grammar-update",
            "--",
            "--skip-git",
            "--continue-on-error",
        }, std.heap.page_allocator);
        child.stdout_behavior = .Inherit;
        child.stderr_behavior = .Inherit;
        const result = child.spawnAndWait() catch |err| {
            log.logf(.info, "auto bootstrap spawn failed err={any}", .{err});
            grammar_auto_bootstrap_lock.lock();
            grammar_auto_bootstrap_state = .failed;
            grammar_auto_bootstrap_lock.unlock();
            return;
        };

        grammar_auto_bootstrap_lock.lock();
        defer grammar_auto_bootstrap_lock.unlock();
        switch (result) {
            .Exited => |code| {
                if (code == 0) {
                    log.logf(.info, "auto bootstrap succeeded", .{});
                    grammar_auto_bootstrap_state = .succeeded;
                    return;
                }
                log.logf(.info, "auto bootstrap failed exit_code={d}", .{code});
                grammar_auto_bootstrap_state = .failed;
                return;
            },
            .Signal => |sig| {
                log.logf(.info, "auto bootstrap failed signal={d}", .{sig});
                grammar_auto_bootstrap_state = .failed;
                return;
            },
            else => {
                log.logf(.info, "auto bootstrap failed status={any}", .{result});
                grammar_auto_bootstrap_state = .failed;
                return;
            },
        }
    }

    fn grammarAutoBootstrapState() GrammarAutoBootstrapState {
        grammar_auto_bootstrap_lock.lock();
        defer grammar_auto_bootstrap_lock.unlock();
        return grammar_auto_bootstrap_state;
    }

    fn shouldAutoBootstrapGrammars() bool {
        return envFlagEnabled("ZIDE_GRAMMAR_AUTO_BOOTSTRAP");
    }

    fn emitMissingGrammarNotice(
        self: *Editor,
        auto_bootstrap_enabled: bool,
        bootstrap_attempted: bool,
        bootstrap_succeeded: bool,
    ) void {
        _ = self;
        _ = bootstrap_succeeded;

        grammar_missing_notice_lock.lock();
        defer grammar_missing_notice_lock.unlock();
        if (grammar_missing_notice_emitted) return;
        grammar_missing_notice_emitted = true;

        if (auto_bootstrap_enabled and bootstrap_attempted) {
            std.debug.print(
                "zide: tree-sitter grammar missing; auto-bootstrap failed or incomplete. Run `zig build grammar-update` and restart.\n",
                .{},
            );
            return;
        }
        std.debug.print(
            "zide: tree-sitter grammar missing. Run `zig build grammar-update` (or set ZIDE_GRAMMAR_AUTO_BOOTSTRAP=1) and restart.\n",
            .{},
        );
    }

    fn envFlagEnabled(name: [:0]const u8) bool {
        const raw = std.c.getenv(name) orelse return false;
        const value = std.mem.sliceTo(raw, 0);
        if (std.mem.eql(u8, value, "1")) return true;
        if (std.mem.eql(u8, value, "true")) return true;
        if (std.mem.eql(u8, value, "TRUE")) return true;
        if (std.mem.eql(u8, value, "yes")) return true;
        if (std.mem.eql(u8, value, "YES")) return true;
        return false;
    }

    pub fn ensureHighlighter(self: *Editor) void {
        if (self.highlight_disabled_for_large_file) return;
        if (!self.highlight_pending) return;
        self.tryInitHighlighter(self.file_path) catch |err| {
            const log = app_logger.logger("editor.highlight");
            log.logf(.warning, "ensure highlighter init failed: {s}", .{@errorName(err)});
        };
    }

    pub fn applyPendingSearchWork(self: *Editor) void {
        self.applyPendingSearchResult();
    }

    pub fn setSearchQuery(self: *Editor, query: ?[]const u8) !void {
        self.search_mode = .literal;
        if (self.search_query) |prev| {
            self.allocator.free(prev);
            self.search_query = null;
        }
        if (query) |value| {
            if (value.len == 0) {
                self.clearSearchState();
                return;
            }
            self.search_query = try self.allocator.dupe(u8, value);
        } else {
            self.clearSearchState();
            return;
        }
        try self.recomputeSearchMatchesPrefer(self.cursor.offset);
    }

    pub fn setSearchQueryRegex(self: *Editor, query: ?[]const u8) !void {
        self.search_mode = .regex;
        if (self.search_query) |prev| {
            self.allocator.free(prev);
            self.search_query = null;
        }
        if (query) |value| {
            if (value.len == 0) {
                self.clearSearchState();
                return;
            }
            self.search_query = try self.allocator.dupe(u8, value);
        } else {
            self.clearSearchState();
            return;
        }
        try self.recomputeSearchMatchesPrefer(self.cursor.offset);
    }

    pub fn searchMatches(self: *const Editor) []const SearchMatch {
        return self.search_matches.items;
    }

    pub fn searchQuery(self: *const Editor) ?[]const u8 {
        return self.search_query;
    }

    pub fn searchActiveMatch(self: *const Editor) ?SearchMatch {
        const idx = self.search_active orelse return null;
        if (idx >= self.search_matches.items.len) return null;
        return self.search_matches.items[idx];
    }

    pub fn searchActiveIndex(self: *const Editor) ?usize {
        const idx = self.search_active orelse return null;
        if (idx >= self.search_matches.items.len) return null;
        return idx;
    }

    pub fn focusSearchActiveMatch(self: *Editor) bool {
        if (self.searchActiveMatch() == null) return false;
        self.jumpToSearchActive();
        return true;
    }

    pub fn activateNextSearchMatch(self: *Editor) bool {
        if (self.search_matches.items.len == 0) return false;
        const next = if (self.search_active) |idx|
            (idx + 1) % self.search_matches.items.len
        else
            0;
        self.search_active = next;
        self.jumpToSearchActive();
        return true;
    }

    pub fn activatePrevSearchMatch(self: *Editor) bool {
        if (self.search_matches.items.len == 0) return false;
        const prev = if (self.search_active) |idx|
            if (idx == 0) self.search_matches.items.len - 1 else idx - 1
        else
            self.search_matches.items.len - 1;
        self.search_active = prev;
        self.jumpToSearchActive();
        return true;
    }

    pub fn replaceActiveSearchMatch(self: *Editor, replacement: []const u8) !bool {
        const active_idx = self.search_active orelse return false;
        if (active_idx >= self.search_matches.items.len) return false;
        const active = self.search_matches.items[active_idx];

        _ = try self.beginTrackedUndoGroup();
        errdefer self.endTrackedUndoGroup() catch |err| {
            const log = app_logger.logger("editor.search");
            log.logf(.warning, "tracked undo cleanup failed (replace active): {s}", .{@errorName(err)});
        };
        try self.replaceByteRangeInternal(active.start, active.end, replacement, false);
        try self.recomputeSearchMatchesSync();
        self.search_active = self.findSearchMatchAtOrAfter(active.start + replacement.len);
        if (self.search_active != null) {
            self.jumpToSearchActive();
        }
        try self.endTrackedUndoGroup();
        return true;
    }

    pub fn replaceAllSearchMatches(self: *Editor, replacement: []const u8) !usize {
        if (self.search_matches.items.len == 0) return 0;

        const matches = try self.allocator.dupe(SearchMatch, self.search_matches.items);
        defer self.allocator.free(matches);

        _ = try self.beginTrackedUndoGroup();
        errdefer self.endTrackedUndoGroup() catch |err| {
            const log = app_logger.logger("editor.search");
            log.logf(.warning, "tracked undo cleanup failed (replace all): {s}", .{@errorName(err)});
        };
        var idx = matches.len;
        while (idx > 0) {
            idx -= 1;
            const match = matches[idx];
            try self.replaceByteRangeInternal(match.start, match.end, replacement, false);
        }
        try self.recomputeSearchMatchesSync();
        try self.endTrackedUndoGroup();
        return matches.len;
    }

    fn jumpToSearchActive(self: *Editor) void {
        const active = self.searchActiveMatch() orelse return;
        self.setCursorOffsetNoClear(active.start);
        self.selection = null;
        self.clearSelections();
    }

    fn findSearchMatchAtOrAfter(self: *const Editor, offset: usize) ?usize {
        for (self.search_matches.items, 0..) |match, idx| {
            if (match.start >= offset) return idx;
        }
        return null;
    }

    fn clearSearchState(self: *Editor) void {
        self.cancelPendingSearchWork();
        self.search_matches.clearRetainingCapacity();
        self.search_active = null;
        self.search_epoch +|= 1;
    }

    fn recomputeSearchMatches(self: *Editor) !void {
        const preferred = if (self.searchActiveMatch()) |active| active.start else self.cursor.offset;
        try self.recomputeSearchMatchesPrefer(preferred);
    }

    fn recomputeSearchMatchesPrefer(self: *Editor, preferred_offset: usize) !void {
        const query = self.search_query orelse {
            self.clearSearchState();
            return;
        };
        if (query.len == 0) {
            self.clearSearchState();
            return;
        }

        const total = self.buffer.totalLen();
        const content_owned = try self.buffer.readRangeAlloc(0, total);
        defer self.allocator.free(content_owned);
        const query_copy = try c_allocator.dupe(u8, query);
        errdefer c_allocator.free(query_copy);
        const content_copy = try c_allocator.dupe(u8, content_owned);
        errdefer c_allocator.free(content_copy);

        const generation_opt = self.queueSearchRequest(.{
            .preferred_offset = preferred_offset,
            .mode = self.search_mode,
            .query = query_copy,
            .content = content_copy,
        });
        if (generation_opt == null) {
            c_allocator.free(query_copy);
            c_allocator.free(content_copy);
            try self.recomputeSearchMatchesSyncPrefer(preferred_offset);
            return;
        }
        const generation = generation_opt.?;

        self.search_matches.clearRetainingCapacity();
        self.search_active = null;
        self.search_epoch +|= 1;
        if (total > 0) self.noteHighlightDirtyRange(0, total - 1);

        const log = app_logger.logger("editor.search");
        log.logf(.debug, "search scheduled generation={d} query_len={d} content_len={d} mode={s}", .{
            generation,
            query.len,
            content_owned.len,
            @tagName(self.search_mode),
        });
    }

    fn recomputeSearchMatchesSync(self: *Editor) !void {
        const preferred = if (self.searchActiveMatch()) |active| active.start else self.cursor.offset;
        try self.recomputeSearchMatchesSyncPrefer(preferred);
    }

    fn recomputeSearchMatchesSyncPrefer(self: *Editor, preferred_offset: usize) !void {
        self.search_matches.clearRetainingCapacity();
        const query = self.search_query orelse {
            self.search_active = null;
            self.search_epoch +|= 1;
            return;
        };
        if (query.len == 0) {
            self.search_active = null;
            self.search_epoch +|= 1;
            return;
        }

        const total = self.buffer.totalLen();
        const content = try self.buffer.readRangeAlloc(0, total);
        defer self.allocator.free(content);

        const matches = try computeSearchMatchesAlloc(self.allocator, self.search_mode, query, content);
        defer self.allocator.free(matches);
        try self.search_matches.appendSlice(self.allocator, matches);
        self.search_active = self.pickSearchActiveIndex(preferred_offset);
        self.search_epoch +|= 1;
        if (total > 0) self.noteHighlightDirtyRange(0, total - 1);
    }

    fn queueSearchRequest(self: *Editor, request: struct {
        preferred_offset: usize,
        mode: SearchMode,
        query: []u8,
        content: []u8,
    }) ?u64 {
        self.ensureSearchWorker();
        self.search_mutex.lock();
        defer self.search_mutex.unlock();
        if (!self.search_worker_running) return null;

        self.search_generation +|= 1;
        const generation = self.search_generation;
        if (self.search_request) |pending| {
            c_allocator.free(pending.query);
            c_allocator.free(pending.content);
        }
        self.search_request = .{
            .generation = generation,
            .preferred_offset = request.preferred_offset,
            .mode = request.mode,
            .query = request.query,
            .content = request.content,
        };
        self.search_cond.signal();
        return generation;
    }

    fn ensureSearchWorker(self: *Editor) void {
        self.search_mutex.lock();
        if (self.search_worker_running) {
            self.search_mutex.unlock();
            return;
        }
        self.search_worker_running = true;
        self.search_mutex.unlock();

        const worker = std.Thread.spawn(.{}, searchWorkerMain, .{self}) catch |err| {
            const log = app_logger.logger("editor.search");
            log.logf(.warning, "search worker spawn failed err={s}", .{@errorName(err)});
            self.search_mutex.lock();
            self.search_worker_running = false;
            self.search_mutex.unlock();
            return;
        };
        self.search_worker = worker;
    }

    fn stopSearchWorker(self: *Editor) void {
        self.search_mutex.lock();
        self.search_worker_running = false;
        if (self.search_request) |pending| {
            c_allocator.free(pending.query);
            c_allocator.free(pending.content);
            self.search_request = null;
        }
        self.search_cond.signal();
        self.search_mutex.unlock();

        if (self.search_worker) |thread| {
            thread.join();
            self.search_worker = null;
        }

        self.search_mutex.lock();
        defer self.search_mutex.unlock();
        if (self.search_result) |result| {
            c_allocator.free(result.matches);
            self.search_result = null;
        }
    }

    fn cancelPendingSearchWork(self: *Editor) void {
        self.search_mutex.lock();
        defer self.search_mutex.unlock();
        self.search_generation +|= 1;
        if (self.search_request) |pending| {
            c_allocator.free(pending.query);
            c_allocator.free(pending.content);
            self.search_request = null;
        }
        if (self.search_result) |result| {
            c_allocator.free(result.matches);
            self.search_result = null;
        }
    }

    fn applyPendingSearchResult(self: *Editor) void {
        self.search_mutex.lock();
        const result_opt = self.search_result;
        if (result_opt == null) {
            self.search_mutex.unlock();
            return;
        }
        const result = result_opt.?;
        self.search_result = null;
        const latest_generation = self.search_generation;
        self.search_mutex.unlock();

        defer c_allocator.free(result.matches);
        if (result.generation != latest_generation) {
            return;
        }

        self.search_matches.clearRetainingCapacity();
        self.search_matches.appendSlice(self.allocator, result.matches) catch |err| {
            const log = app_logger.logger("editor.search");
            log.logf(.warning, "apply search result append failed err={s}", .{@errorName(err)});
            self.search_active = null;
            self.search_epoch +|= 1;
            return;
        };
        self.search_active = self.pickSearchActiveIndex(result.preferred_offset);
        self.search_epoch +|= 1;
        const total = self.buffer.totalLen();
        if (total > 0) self.noteHighlightDirtyRange(0, total - 1);
    }

    fn searchWorkerMain(self: *Editor) void {
        while (true) {
            self.search_mutex.lock();
            while (self.search_worker_running and self.search_request == null) {
                self.search_cond.wait(&self.search_mutex);
            }
            if (!self.search_worker_running) {
                self.search_mutex.unlock();
                return;
            }
            const request = self.search_request.?;
            self.search_request = null;
            self.search_mutex.unlock();

            const matches = computeSearchMatchesAlloc(c_allocator, request.mode, request.query, request.content) catch |err| {
                const log = app_logger.logger("editor.search");
                log.logf(.warning, "search worker compute failed generation={d} err={s}", .{ request.generation, @errorName(err) });
                c_allocator.free(request.query);
                c_allocator.free(request.content);
                continue;
            };
            c_allocator.free(request.query);
            c_allocator.free(request.content);

            self.search_mutex.lock();
            if (!self.search_worker_running) {
                self.search_mutex.unlock();
                c_allocator.free(matches);
                return;
            }
            if (request.generation != self.search_generation) {
                self.search_mutex.unlock();
                c_allocator.free(matches);
                continue;
            }
            if (self.search_result) |old| {
                c_allocator.free(old.matches);
            }
            self.search_result = .{
                .generation = request.generation,
                .preferred_offset = request.preferred_offset,
                .matches = matches,
            };
            self.search_mutex.unlock();
        }
    }

    fn computeSearchMatchesAlloc(
        allocator: std.mem.Allocator,
        mode: SearchMode,
        query: []const u8,
        content: []const u8,
    ) ![]SearchMatch {
        var out = std.ArrayList(SearchMatch).empty;
        errdefer out.deinit(allocator);
        switch (mode) {
            .literal => {
                var pos: usize = 0;
                while (pos <= content.len) {
                    const found = std.mem.indexOfPos(u8, content, pos, query) orelse break;
                    try out.append(allocator, .{
                        .start = found,
                        .end = found + query.len,
                    });
                    pos = found + 1;
                }
            },
            .regex => {
                var pos: usize = 0;
                while (pos < content.len) : (pos += 1) {
                    const len = regexMatchLengthAt(query, content, pos) orelse continue;
                    if (len == 0) continue;
                    try out.append(allocator, .{
                        .start = pos,
                        .end = pos + len,
                    });
                }
            },
        }
        return out.toOwnedSlice(allocator);
    }

    fn pickSearchActiveIndex(self: *const Editor, preferred_offset: usize) ?usize {
        if (self.search_matches.items.len == 0) return null;
        for (self.search_matches.items, 0..) |match, idx| {
            if (match.start >= preferred_offset) return idx;
        }
        return 0;
    }

    fn regexMatchLengthAt(pattern: []const u8, text: []const u8, start: usize) ?usize {
        if (start >= text.len) return null;
        var best: ?usize = null;
        var end = start + 1;
        while (end <= text.len) : (end += 1) {
            if (simpleRegexFullMatch(pattern, text[start..end])) {
                best = end - start;
            }
        }
        return best;
    }

    fn simpleRegexFullMatch(pattern: []const u8, text: []const u8) bool {
        var pat = pattern;
        if (pat.len > 0 and pat[0] == '^') {
            pat = pat[1..];
        }
        if (pat.len > 0 and pat[pat.len - 1] == '$') {
            pat = pat[0 .. pat.len - 1];
        }
        return simpleRegexMatchHere(pat, text, true);
    }

    fn simpleRegexMatch(pattern: []const u8, text: []const u8) bool {
        var pat = pattern;
        var anchored_start = false;
        var anchored_end = false;
        if (pat.len > 0 and pat[0] == '^') {
            anchored_start = true;
            pat = pat[1..];
        }
        if (pat.len > 0 and pat[pat.len - 1] == '$') {
            anchored_end = true;
            pat = pat[0 .. pat.len - 1];
        }

        if (anchored_start) {
            return simpleRegexMatchHere(pat, text, anchored_end);
        }
        var i: usize = 0;
        while (i <= text.len) : (i += 1) {
            if (simpleRegexMatchHere(pat, text[i..], anchored_end)) return true;
            if (i == text.len) break;
        }
        return false;
    }

    fn simpleRegexMatchHere(pattern: []const u8, text: []const u8, anchored_end: bool) bool {
        if (pattern.len == 0) return !anchored_end or text.len == 0;
        const token = simpleRegexNextToken(pattern);
        const rest = pattern[token.next_index..];
        switch (token.quantifier) {
            '*' => {
                var i: usize = 0;
                while (i <= text.len and (i == 0 or simpleRegexCharMatches(token, text[i - 1]))) : (i += 1) {
                    if (simpleRegexMatchHere(rest, text[i..], anchored_end)) return true;
                }
                return false;
            },
            '+' => {
                if (text.len == 0 or !simpleRegexCharMatches(token, text[0])) return false;
                var i: usize = 1;
                while (i <= text.len and (i == 1 or simpleRegexCharMatches(token, text[i - 1]))) : (i += 1) {
                    if (simpleRegexMatchHere(rest, text[i..], anchored_end)) return true;
                }
                return false;
            },
            '?' => {
                if (simpleRegexMatchHere(rest, text, anchored_end)) return true;
                if (text.len > 0 and simpleRegexCharMatches(token, text[0])) {
                    return simpleRegexMatchHere(rest, text[1..], anchored_end);
                }
                return false;
            },
            else => {
                if (text.len == 0) return false;
                if (!simpleRegexCharMatches(token, text[0])) return false;
                return simpleRegexMatchHere(rest, text[1..], anchored_end);
            },
        }
    }

    const SimpleRegexToken = struct {
        byte: u8,
        any: bool,
        next_index: usize,
        quantifier: u8,
    };

    fn simpleRegexNextToken(pattern: []const u8) SimpleRegexToken {
        if (pattern.len == 0) return .{ .byte = 0, .any = false, .next_index = 0, .quantifier = 0 };
        var idx: usize = 1;
        var byte = pattern[0];
        var any = false;
        if (byte == '\\' and pattern.len > 1) {
            byte = pattern[1];
            idx = 2;
        } else if (byte == '.') {
            any = true;
        }
        var quant: u8 = 0;
        if (idx < pattern.len) {
            const q = pattern[idx];
            if (q == '*' or q == '+' or q == '?') {
                quant = q;
                idx += 1;
            }
        }
        return .{ .byte = byte, .any = any, .next_index = idx, .quantifier = quant };
    }

    fn simpleRegexCharMatches(token: SimpleRegexToken, b: u8) bool {
        return token.any or token.byte == b;
    }
};

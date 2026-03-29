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
const runtime_policy = @import("../app/runtime_policy.zig");

const TextStore = text_store.TextStore;
const CursorPos = types.CursorPos;
const Selection = types.Selection;
const c = ts_api.c_api;
const c_allocator = std.heap.c_allocator;

/// High-level editor state wrapping a text buffer
pub const Editor = struct {
    pub const highlighter_large_file_threshold_bytes: usize = 2 * 1024 * 1024;
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

    pub const SearchRuntimeState = struct {
        worker: ?std.Thread,
        worker_running: bool,
        mutex: std.Thread.Mutex,
        cond: std.Thread.Condition,
        generation: u64,
        request: ?SearchWorkRequest,
        result: ?SearchWorkResult,
    };

    pub const SearchRuntimeCounters = struct {
        epoch: u64 = 0,
        scheduled_async: u64 = 0,
        sync_fallbacks: u64 = 0,
        results_applied: u64 = 0,
        stale_results_dropped: u64 = 0,
        worker_spawns: u64 = 0,
        worker_spawn_failures: u64 = 0,
    };

    pub const HighlightRuntimeCounters = struct {
        epoch: u64 = 0,
        scheduled: u64 = 0,
        skipped_large_file: u64 = 0,
        disabled_no_language: u64 = 0,
        init_attempts: u64 = 0,
        init_successes: u64 = 0,
        init_failures: u64 = 0,
    };

    pub const HighlightWorkState = struct {
        start: usize,
        end: usize,
        next: usize,
        epoch: u64,
        change_tick: u64,
        active: bool,
        completed_start: usize,
        completed_end: usize,
        completed_epoch: u64,
        completed_change_tick: u64,
    };

    pub const VisibleHighlightWorkRequest = struct {
        start_line: usize,
        end_line: usize,
        epoch: u64,
        change_tick: u64,
    };

    pub const VisibleHighlightLineResult = struct {
        line_idx: usize,
        line_start: usize,
        line_text_hash: u64,
        tokens: []syntax_mod.HighlightToken,
    };

    pub const VisibleHighlightWorkResult = struct {
        request: VisibleHighlightWorkRequest,
        lines: []VisibleHighlightLineResult,
    };

    pub const HighlightInvalidationRange = editor_search_highlight.HighlightInvalidationRange;
    pub const HighlightInvalidationBatch = editor_search_highlight.HighlightInvalidationBatch;

    pub const HighlightInvalidationState = struct {
        full_document: bool,
        ranges: std.ArrayList(HighlightInvalidationRange),
    };

    pub const VisibleHighlightRuntimeState = struct {
        work: HighlightWorkState,
        worker: ?std.Thread,
        worker_running: bool,
        mutex: std.Thread.Mutex,
        cond: std.Thread.Condition,
        compute_in_flight: bool,
        request: ?VisibleHighlightWorkRequest,
        result: ?VisibleHighlightWorkResult,
    };

    pub const DocumentCore = struct {
        buffer: *TextStore,
        highlighter: ?*syntax_mod.SyntaxHighlighter,
        highlight_invalidation: HighlightInvalidationState,
        highlight_pending: bool,
        highlight_disabled_for_large_file: bool,
        search_query: ?[]u8,
        search_matches: std.ArrayList(SearchMatch),
        search_active: ?usize,
        search_mode: SearchMode,
        search_refresh_on_text_change: bool,
        search_epoch: u64,
        search_runtime: SearchRuntimeState,
        change_tick: u64,
        highlight_epoch: u64,
        file_path: ?[]const u8,
        modified: bool,
        saved_content_hash: u64,
        grammar_manager: *grammar_manager_mod.GrammarManager,
        undo_selection_states: std.ArrayList(UndoSelectionState),
        next_undo_selection_state_id: u64,

        pub fn filePath(self: DocumentCore) ?[]const u8 {
            return self.file_path;
        }

        pub fn isModified(self: DocumentCore) bool {
            return self.modified;
        }

        pub fn textStore(self: DocumentCore) *TextStore {
            return self.buffer;
        }

        pub fn changeTick(self: DocumentCore) u64 {
            return self.change_tick;
        }

        pub fn highlightEpoch(self: DocumentCore) u64 {
            return self.highlight_epoch;
        }
    };

    pub const EditorViewState = struct {
        preferred_visual_col: ?usize,
        scroll_line: usize,
        scroll_col: usize,
        scroll_row_offset: usize,

        pub fn scrollLine(self: EditorViewState) usize {
            return self.scroll_line;
        }

        pub fn scrollCol(self: EditorViewState) usize {
            return self.scroll_col;
        }

        pub fn scrollRowOffset(self: EditorViewState) usize {
            return self.scroll_row_offset;
        }

        pub fn preferredVisualCol(self: EditorViewState) ?usize {
            return self.preferred_visual_col;
        }
    };

    pub const SearchMatch = editor_search_highlight.SearchMatch;
    pub const SearchMode = editor_search_highlight.SearchMode;
    const SearchWorkRequest = editor_search_highlight.SearchWorkRequest;
    const SearchWorkResult = editor_search_highlight.SearchWorkResult;

    allocator: std.mem.Allocator,
    doc: DocumentCore,
    cursor: CursorPos,
    selection: ?Selection,
    selections: std.ArrayList(Selection),
    view: EditorViewState,
    line_width_cache: std.AutoHashMap(usize, usize),
    cluster_offset_cache: std.AutoHashMap(usize, ClusterOffsetEntry),
    max_line_width_cache: usize,
    visible_highlight_runtime: VisibleHighlightRuntimeState,
    search_runtime_counters: SearchRuntimeCounters,
    highlight_runtime_counters: HighlightRuntimeCounters,
    highlight_defer_frames: u8,
    visible_cache_precompute_defer_frames: u8,
    cluster_offsets_defer_frames: u8,
    startup_defer_last_frame_id: u64,
    tab_width: usize,
    runtime_wake_fn: ?*const fn () void,

    const ClusterOffsetEntry = struct {
        text_hash: u64,
        offsets: []u32,
    };

    pub fn documentCore(self: *Editor) DocumentCore {
        return self.doc;
    }

    pub fn documentCoreMut(self: *Editor) *DocumentCore {
        return &self.doc;
    }

    pub fn viewState(self: *Editor) EditorViewState {
        return self.view;
    }

    pub fn viewStateMut(self: *Editor) *EditorViewState {
        return &self.view;
    }

    pub fn setRuntimeWakeFn(self: *Editor, wake_fn: *const fn () void) void {
        self.runtime_wake_fn = wake_fn;
    }

    pub fn requestRuntimeWake(self: *const Editor) void {
        const wake_fn = self.runtime_wake_fn orelse return;
        wake_fn();
    }

    pub fn clearPreferredVisualCol(self: *Editor) void {
        self.view.preferred_visual_col = null;
    }

    pub fn setPreferredVisualCol(self: *Editor, col: ?usize) void {
        self.view.preferred_visual_col = col;
    }

    pub fn resetScrollState(self: *Editor) void {
        self.view.scroll_line = 0;
        self.view.scroll_col = 0;
        self.view.scroll_row_offset = 0;
    }

    pub fn setScrollLine(self: *Editor, line: usize) void {
        self.view.scroll_line = line;
    }

    pub fn setScrollCol(self: *Editor, col: usize) void {
        self.view.scroll_col = col;
    }

    pub fn setScrollRowOffset(self: *Editor, row_offset: usize) void {
        self.view.scroll_row_offset = row_offset;
    }

    pub fn setVerticalScroll(self: *Editor, line: usize, row_offset: usize) void {
        self.view.scroll_line = line;
        self.view.scroll_row_offset = row_offset;
    }

    pub fn clearHighlighter(self: *Editor) void {
        if (self.doc.highlighter) |h| {
            h.destroy();
            self.doc.highlighter = null;
        }
    }

    pub fn setFilePath(self: *Editor, path: ?[]const u8) !void {
        if (self.doc.file_path) |old_path| {
            self.allocator.free(old_path);
            self.doc.file_path = null;
        }
        if (path) |value| {
            self.doc.file_path = try self.allocator.dupe(u8, value);
        }
    }

    pub fn markSaved(self: *Editor) void {
        self.doc.modified = false;
        self.doc.saved_content_hash = contentHash(self.doc.buffer);
    }

    pub fn setModified(self: *Editor, modified: bool) void {
        self.doc.modified = modified;
    }

    pub fn recomputeModifiedFromContent(self: *Editor) void {
        self.doc.modified = contentHash(self.doc.buffer) != self.doc.saved_content_hash;
    }

    pub fn clearHighlightInvalidation(self: *Editor) void {
        self.doc.highlight_invalidation.full_document = false;
        self.doc.highlight_invalidation.ranges.clearRetainingCapacity();
    }

    pub fn setHighlightDisabledForLargeFile(self: *Editor) void {
        self.doc.highlight_disabled_for_large_file = self.doc.buffer.totalLen() >= highlighter_large_file_threshold_bytes;
    }

    pub fn setHighlightPending(self: *Editor, pending: bool) void {
        self.doc.highlight_pending = pending;
    }

    pub fn searchRuntimeCounters(self: *const Editor) SearchRuntimeCounters {
        return self.search_runtime_counters;
    }

    pub fn highlightRuntimeCounters(self: *const Editor) HighlightRuntimeCounters {
        return self.highlight_runtime_counters;
    }

    pub fn recordSearchScheduledAsync(self: *Editor) void {
        self.search_runtime_counters.scheduled_async +%= 1;
    }

    pub fn recordSearchSyncFallback(self: *Editor) void {
        self.search_runtime_counters.sync_fallbacks +%= 1;
    }

    pub fn recordSearchResultApplied(self: *Editor) void {
        self.search_runtime_counters.results_applied +%= 1;
    }

    pub fn recordSearchStaleResultDropped(self: *Editor) void {
        self.search_runtime_counters.stale_results_dropped +%= 1;
    }

    pub fn recordSearchWorkerSpawn(self: *Editor) void {
        self.search_runtime_counters.worker_spawns +%= 1;
    }

    pub fn recordSearchWorkerSpawnFailure(self: *Editor) void {
        self.search_runtime_counters.worker_spawn_failures +%= 1;
    }

    pub fn recordHighlightScheduled(self: *Editor) void {
        self.highlight_runtime_counters.scheduled +%= 1;
    }

    pub fn recordHighlightSkippedLargeFile(self: *Editor) void {
        self.highlight_runtime_counters.skipped_large_file +%= 1;
    }

    pub fn recordHighlightDisabledNoLanguage(self: *Editor) void {
        self.highlight_runtime_counters.disabled_no_language +%= 1;
    }

    pub fn recordHighlightInitAttempt(self: *Editor) void {
        self.highlight_runtime_counters.init_attempts +%= 1;
    }

    pub fn recordHighlightInitSuccess(self: *Editor) void {
        self.highlight_runtime_counters.init_successes +%= 1;
    }

    pub fn recordHighlightInitFailure(self: *Editor) void {
        self.highlight_runtime_counters.init_failures +%= 1;
    }

    pub fn resetSearchRuntimeCounters(self: *Editor) void {
        self.search_runtime_counters = .{
            .epoch = self.search_runtime_counters.epoch + 1,
        };
    }

    pub fn resetHighlightRuntimeCounters(self: *Editor) void {
        self.highlight_runtime_counters = .{
            .epoch = self.highlight_runtime_counters.epoch + 1,
        };
    }

    pub fn bumpHighlightEpoch(self: *Editor) void {
        self.doc.highlight_epoch +|= 1;
        self.clearVisibleHighlightWork();
    }

    pub fn bumpChangeTick(self: *Editor) void {
        self.doc.change_tick +|= 1;
    }

    pub fn setSearchRefreshOnTextChange(self: *Editor, enabled: bool) void {
        self.doc.search_refresh_on_text_change = enabled;
    }

    pub fn setSearchMode(self: *Editor, mode: SearchMode) void {
        self.doc.search_mode = mode;
    }

    pub fn clearSearchQuery(self: *Editor) void {
        if (self.doc.search_query) |prev| {
            self.allocator.free(prev);
            self.doc.search_query = null;
        }
    }

    pub fn setSearchQueryOwned(self: *Editor, query: []const u8) !void {
        self.clearSearchQuery();
        self.doc.search_query = try self.allocator.dupe(u8, query);
    }

    pub fn clearSearchMatches(self: *Editor) void {
        self.doc.search_matches.clearRetainingCapacity();
    }

    pub fn replaceSearchMatches(self: *Editor, matches: []const SearchMatch) !void {
        self.clearSearchMatches();
        try self.doc.search_matches.appendSlice(self.allocator, matches);
    }

    pub fn setSearchActive(self: *Editor, active: ?usize) void {
        self.doc.search_active = active;
    }

    pub fn bumpSearchEpoch(self: *Editor) void {
        self.doc.search_epoch +|= 1;
    }

    pub fn bumpSearchGeneration(self: *Editor) u64 {
        self.doc.search_runtime.generation +|= 1;
        return self.doc.search_runtime.generation;
    }

    pub fn isSearchWorkerRunning(self: *const Editor) bool {
        return self.doc.search_runtime.worker_running;
    }

    pub fn setSearchWorkerRunning(self: *Editor, running: bool) void {
        self.doc.search_runtime.worker_running = running;
    }

    pub fn setSearchWorker(self: *Editor, worker: ?std.Thread) void {
        self.doc.search_runtime.worker = worker;
    }

    pub fn takeSearchWorker(self: *Editor) ?std.Thread {
        const worker = self.doc.search_runtime.worker;
        self.doc.search_runtime.worker = null;
        return worker;
    }

    pub fn clearPendingSearchRequest(self: *Editor) void {
        if (self.doc.search_runtime.request) |pending| {
            c_allocator.free(pending.query);
            c_allocator.free(pending.content);
            self.doc.search_runtime.request = null;
        }
    }

    pub fn replaceSearchRequest(self: *Editor, request: SearchWorkRequest) void {
        self.clearPendingSearchRequest();
        self.doc.search_runtime.request = request;
    }

    pub fn takeSearchRequest(self: *Editor) ?SearchWorkRequest {
        const request = self.doc.search_runtime.request;
        self.doc.search_runtime.request = null;
        return request;
    }

    pub fn clearPendingSearchResult(self: *Editor) void {
        if (self.doc.search_runtime.result) |result| {
            c_allocator.free(result.matches);
            self.doc.search_runtime.result = null;
        }
    }

    pub fn replaceSearchResult(self: *Editor, result: SearchWorkResult) void {
        self.clearPendingSearchResult();
        self.doc.search_runtime.result = result;
    }

    pub fn takeSearchResult(self: *Editor) ?SearchWorkResult {
        const result = self.doc.search_runtime.result;
        self.doc.search_runtime.result = null;
        return result;
    }

    pub fn lockSearchRuntime(self: *Editor) void {
        self.doc.search_runtime.mutex.lock();
    }

    pub fn unlockSearchRuntime(self: *Editor) void {
        self.doc.search_runtime.mutex.unlock();
    }

    pub fn waitSearchRuntime(self: *Editor) void {
        self.doc.search_runtime.cond.wait(&self.doc.search_runtime.mutex);
    }

    pub fn signalSearchRuntime(self: *Editor) void {
        self.doc.search_runtime.cond.signal();
    }

    pub fn hasPendingSearchRequest(self: *const Editor) bool {
        return self.doc.search_runtime.request != null;
    }

    pub fn currentSearchGeneration(self: *const Editor) u64 {
        return self.doc.search_runtime.generation;
    }

    pub const HighlightWorkBatch = struct {
        start_line: usize,
        end_line: usize,
    };

    pub fn beginVisibleHighlightWork(self: *Editor, start_line: usize, end_line: usize, epoch: u64, change_tick: u64) void {
        if (end_line <= start_line) {
            self.visible_highlight_runtime.work.active = false;
            return;
        }
        const completed_same_range = !self.visible_highlight_runtime.work.active and
            start_line == self.visible_highlight_runtime.work.completed_start and
            end_line == self.visible_highlight_runtime.work.completed_end and
            epoch == self.visible_highlight_runtime.work.completed_epoch and
            change_tick == self.visible_highlight_runtime.work.completed_change_tick;
        if (completed_same_range) return;
        const range_changed = !self.visible_highlight_runtime.work.active or
            start_line != self.visible_highlight_runtime.work.start or
            end_line != self.visible_highlight_runtime.work.end or
            epoch != self.visible_highlight_runtime.work.epoch or
            change_tick != self.visible_highlight_runtime.work.change_tick;
        if (range_changed) {
            self.visible_highlight_runtime.work.start = start_line;
            self.visible_highlight_runtime.work.end = end_line;
            self.visible_highlight_runtime.work.next = start_line;
            self.visible_highlight_runtime.work.epoch = epoch;
            self.visible_highlight_runtime.work.change_tick = change_tick;
            self.visible_highlight_runtime.work.active = true;
        }
    }

    pub fn takeVisibleHighlightWorkBatch(self: *Editor, max_lines: usize) ?HighlightWorkBatch {
        if (!self.visible_highlight_runtime.work.active or max_lines == 0) return null;
        if (self.visible_highlight_runtime.work.next >= self.visible_highlight_runtime.work.end) {
            self.visible_highlight_runtime.work.active = false;
            return null;
        }
        const start_line = self.visible_highlight_runtime.work.next;
        const end_line = @min(self.visible_highlight_runtime.work.end, start_line + max_lines);
        self.visible_highlight_runtime.work.next = end_line;
        if (self.visible_highlight_runtime.work.next >= self.visible_highlight_runtime.work.end) {
            self.visible_highlight_runtime.work.active = false;
            self.visible_highlight_runtime.work.completed_start = self.visible_highlight_runtime.work.start;
            self.visible_highlight_runtime.work.completed_end = self.visible_highlight_runtime.work.end;
            self.visible_highlight_runtime.work.completed_epoch = self.visible_highlight_runtime.work.epoch;
            self.visible_highlight_runtime.work.completed_change_tick = self.visible_highlight_runtime.work.change_tick;
        }
        return .{ .start_line = start_line, .end_line = end_line };
    }

    pub fn hasPendingVisibleHighlightWork(self: *const Editor) bool {
        return self.visible_highlight_runtime.work.active;
    }

    pub fn canScheduleVisibleHighlightRequest(self: *Editor) bool {
        self.lockVisibleHighlightRuntime();
        defer self.unlockVisibleHighlightRuntime();
        return !self.visible_highlight_runtime.compute_in_flight and
            self.visible_highlight_runtime.request == null and
            self.visible_highlight_runtime.result == null;
    }

    pub fn replaceVisibleHighlightRequest(self: *Editor, request: VisibleHighlightWorkRequest) void {
        self.lockVisibleHighlightRuntime();
        defer self.unlockVisibleHighlightRuntime();
        self.visible_highlight_runtime.request = request;
    }

    pub fn takeVisibleHighlightRequest(self: *Editor) ?VisibleHighlightWorkRequest {
        self.lockVisibleHighlightRuntime();
        defer self.unlockVisibleHighlightRuntime();
        const request = self.visible_highlight_runtime.request;
        self.visible_highlight_runtime.request = null;
        return request;
    }

    pub fn clearVisibleHighlightRequest(self: *Editor) void {
        self.lockVisibleHighlightRuntime();
        defer self.unlockVisibleHighlightRuntime();
        self.visible_highlight_runtime.request = null;
    }

    pub fn replaceVisibleHighlightResult(self: *Editor, result: VisibleHighlightWorkResult) void {
        self.lockVisibleHighlightRuntime();
        defer self.unlockVisibleHighlightRuntime();
        if (self.visible_highlight_runtime.result) |*existing| {
            self.deinitVisibleHighlightResult(existing);
        }
        self.visible_highlight_runtime.result = result;
    }

    pub fn takeVisibleHighlightResult(self: *Editor) ?VisibleHighlightWorkResult {
        self.lockVisibleHighlightRuntime();
        defer self.unlockVisibleHighlightRuntime();
        const result = self.visible_highlight_runtime.result;
        self.visible_highlight_runtime.result = null;
        return result;
    }

    pub fn hasPendingVisibleHighlightResult(self: *Editor) bool {
        self.visible_highlight_runtime.mutex.lock();
        defer self.visible_highlight_runtime.mutex.unlock();
        return self.visible_highlight_runtime.result != null;
    }

    pub fn lockVisibleHighlightRuntime(self: *Editor) void {
        self.visible_highlight_runtime.mutex.lock();
    }

    pub fn unlockVisibleHighlightRuntime(self: *Editor) void {
        self.visible_highlight_runtime.mutex.unlock();
    }

    pub fn waitVisibleHighlightRuntime(self: *Editor) void {
        self.visible_highlight_runtime.cond.wait(&self.visible_highlight_runtime.mutex);
    }

    pub fn signalVisibleHighlightRuntime(self: *Editor) void {
        self.visible_highlight_runtime.cond.signal();
    }

    pub fn isVisibleHighlightWorkerRunning(self: *const Editor) bool {
        return self.visible_highlight_runtime.worker_running;
    }

    pub fn setVisibleHighlightWorkerRunning(self: *Editor, running: bool) void {
        self.visible_highlight_runtime.worker_running = running;
    }

    pub fn setVisibleHighlightWorker(self: *Editor, worker: std.Thread) void {
        self.visible_highlight_runtime.worker = worker;
    }

    pub fn takeVisibleHighlightWorker(self: *Editor) ?std.Thread {
        const worker = self.visible_highlight_runtime.worker;
        self.visible_highlight_runtime.worker = null;
        return worker;
    }

    pub fn hasPendingVisibleHighlightRequest(self: *Editor) bool {
        self.visible_highlight_runtime.mutex.lock();
        defer self.visible_highlight_runtime.mutex.unlock();
        return self.visible_highlight_runtime.request != null;
    }

    pub fn visibleHighlightWorkInFlight(self: *Editor) bool {
        return self.hasPendingVisibleHighlightWork() or
            self.visibleHighlightComputeInFlight() or
            self.hasPendingVisibleHighlightRequest() or
            self.hasPendingVisibleHighlightResult();
    }

    pub fn visibleHighlightComputeInFlight(self: *Editor) bool {
        self.visible_highlight_runtime.mutex.lock();
        defer self.visible_highlight_runtime.mutex.unlock();
        return self.visible_highlight_runtime.compute_in_flight;
    }

    pub fn applyPendingVisibleHighlightResult(self: *Editor, cache: anytype) bool {
        self.lockVisibleHighlightRuntime();
        const owned_result = self.visible_highlight_runtime.result orelse {
            self.unlockVisibleHighlightRuntime();
            return false;
        };
        self.visible_highlight_runtime.result = null;
        self.unlockVisibleHighlightRuntime();
        var result = owned_result;
        defer self.deinitVisibleHighlightResult(&result);
        if (result.request.change_tick != self.doc.change_tick or result.request.epoch != self.doc.highlight_epoch) {
            return false;
        }

        for (result.lines) |line| {
            cache.storeHighlightTokens(
                line.line_idx,
                line.line_start,
                line.line_text_hash,
                result.request.epoch,
                line.tokens,
            );
        }
        const perf_log = app_logger.logger("editor.perf");
        perf_log.logf(
            .info,
            "visible_highlight_publish lines={d} start_line={d} end_line={d}",
            .{ result.lines.len, result.request.start_line, result.request.end_line },
        );
        return result.lines.len > 0;
    }

    fn computeVisibleHighlightRequest(self: *Editor, request: VisibleHighlightWorkRequest) ?VisibleHighlightWorkResult {
        const perf_log = app_logger.logger("editor.perf");
        const highlighter = self.doc.highlighter orelse {
            perf_log.logf(.info, "visible_precompute_highlight lines=0 budget=0 time_us=0", .{});
            return null;
        };

        const t_start = std.time.nanoTimestamp();
        const range_start = self.lineStart(request.start_line);
        const range_end = if (request.end_line < self.lineCount()) self.lineStart(request.end_line) else self.totalLen();
        var tokens = highlighter.highlightRange(range_start, range_end, self.allocator) catch |err| blk: {
            const log = app_logger.logger("editor.draw");
            log.logf(.warning, "visible precompute highlight range failed start={d} end={d} err={s}", .{ range_start, range_end, @errorName(err) });
            break :blk &[_]syntax_mod.HighlightToken{};
        };
        const allocated = tokens.ptr != (&[_]syntax_mod.HighlightToken{}).ptr;
        defer if (allocated) self.allocator.free(tokens);
        if (tokens.len > 1) {
            std.sort.heap(syntax_mod.HighlightToken, @constCast(tokens), {}, struct {
                fn lessThan(_: void, a: syntax_mod.HighlightToken, b: syntax_mod.HighlightToken) bool {
                    return syntax_mod.highlightTokenLessThanStable(a, b);
                }
            }.lessThan);
        }

        var lines_done: usize = 0;
        var line_results = std.ArrayList(VisibleHighlightLineResult).empty;
        defer line_results.deinit(self.allocator);
        var token_idx: usize = 0;
        var line_idx = request.start_line;
        while (line_idx < request.end_line) : (line_idx += 1) {
            const line_text = self.getLineAlloc(line_idx) catch |err| {
                const log = app_logger.logger("editor.draw");
                log.logf(.warning, "visible highlight line load failed line={d} err={s}", .{ line_idx, @errorName(err) });
                continue;
            };
            defer self.allocator.free(line_text);
            const line_start = self.lineStart(line_idx);
            const line_end = line_start + line_text.len;
            while (token_idx < tokens.len and tokens[token_idx].end <= line_start) {
                token_idx += 1;
            }
            var line_token_end = token_idx;
            while (line_token_end < tokens.len and tokens[line_token_end].start < line_end) {
                line_token_end += 1;
            }
            const line_tokens = self.allocator.dupe(syntax_mod.HighlightToken, tokens[token_idx..line_token_end]) catch |err| {
                const log = app_logger.logger("editor.draw");
                log.logf(.warning, "visible highlight line token dup failed line={d} err={s}", .{ line_idx, @errorName(err) });
                continue;
            };
            line_results.append(self.allocator, .{
                .line_idx = line_idx,
                .line_start = line_start,
                .line_text_hash = hashLine(line_text),
                .tokens = line_tokens,
            }) catch |err| {
                const log = app_logger.logger("editor.draw");
                self.allocator.free(line_tokens);
                log.logf(.warning, "visible highlight result append failed line={d} err={s}", .{ line_idx, @errorName(err) });
                continue;
            };
            lines_done += 1;
        }
        const owned_lines = line_results.toOwnedSlice(self.allocator) catch |err| {
            const log = app_logger.logger("editor.draw");
            for (line_results.items) |line| self.allocator.free(line.tokens);
            log.logf(.warning, "visible highlight result ownership failed err={s}", .{@errorName(err)});
            return null;
        };
        const result: VisibleHighlightWorkResult = .{
            .request = request,
            .lines = owned_lines,
        };
        const elapsed_us = @as(i64, @intCast(@divTrunc(std.time.nanoTimestamp() - t_start, 1000)));
        perf_log.logf(.info, "visible_precompute_highlight lines={d} budget={d} time_us={d}", .{ lines_done, request.end_line - request.start_line, elapsed_us });
        return result;
    }

    pub fn executePendingVisibleHighlightRequest(self: *Editor) bool {
        const perf_log = app_logger.logger("editor.perf");
        const request = self.takeVisibleHighlightRequest() orelse {
            perf_log.logf(.info, "visible_precompute_highlight lines=0 budget=0 time_us=0", .{});
            return false;
        };
        self.lockVisibleHighlightRuntime();
        self.visible_highlight_runtime.compute_in_flight = true;
        self.unlockVisibleHighlightRuntime();
        perf_log.logf(
            .info,
            "visible_highlight_execute_inline start_line={d} end_line={d}",
            .{ request.start_line, request.end_line },
        );
        const result = self.computeVisibleHighlightRequest(request) orelse {
            self.lockVisibleHighlightRuntime();
            self.visible_highlight_runtime.compute_in_flight = false;
            self.unlockVisibleHighlightRuntime();
            return false;
        };
        self.lockVisibleHighlightRuntime();
        self.visible_highlight_runtime.compute_in_flight = false;
        self.unlockVisibleHighlightRuntime();
        self.replaceVisibleHighlightResult(result);
        return result.lines.len > 0;
    }

    pub fn ensureVisibleHighlightWorker(self: *Editor) void {
        self.lockVisibleHighlightRuntime();
        if (self.isVisibleHighlightWorkerRunning()) {
            self.unlockVisibleHighlightRuntime();
            return;
        }
        self.setVisibleHighlightWorkerRunning(true);
        self.unlockVisibleHighlightRuntime();

        const worker = std.Thread.spawn(.{}, visibleHighlightWorkerMain, .{self}) catch |err| {
            const log = app_logger.logger("editor.highlight");
            log.logf(.warning, "visible highlight worker spawn failed err={s}", .{@errorName(err)});
            self.lockVisibleHighlightRuntime();
            self.setVisibleHighlightWorkerRunning(false);
            self.unlockVisibleHighlightRuntime();
            return;
        };
        self.setVisibleHighlightWorker(worker);
        const perf_log = app_logger.logger("editor.perf");
        perf_log.logf(.info, "visible_highlight_worker started=true", .{});
    }

    fn stopVisibleHighlightWorker(self: *Editor) void {
        self.lockVisibleHighlightRuntime();
        self.setVisibleHighlightWorkerRunning(false);
        self.visible_highlight_runtime.compute_in_flight = false;
        self.visible_highlight_runtime.request = null;
        self.signalVisibleHighlightRuntime();
        self.unlockVisibleHighlightRuntime();

        if (self.takeVisibleHighlightWorker()) |thread| {
            thread.join();
        }

        self.lockVisibleHighlightRuntime();
        self.clearVisibleHighlightResult();
        self.unlockVisibleHighlightRuntime();
        const perf_log = app_logger.logger("editor.perf");
        perf_log.logf(.info, "visible_highlight_worker started=false", .{});
    }

    fn visibleHighlightWorkerMain(self: *Editor) void {
        while (true) {
            self.lockVisibleHighlightRuntime();
            while (self.visible_highlight_runtime.worker_running and self.visible_highlight_runtime.request == null) {
                self.waitVisibleHighlightRuntime();
            }
            if (!self.visible_highlight_runtime.worker_running) {
                self.unlockVisibleHighlightRuntime();
                return;
            }
            const request = self.visible_highlight_runtime.request.?;
            self.visible_highlight_runtime.request = null;
            self.visible_highlight_runtime.compute_in_flight = true;
            self.unlockVisibleHighlightRuntime();
            const perf_log = app_logger.logger("editor.perf");
            perf_log.logf(
                .info,
                "visible_highlight_worker_compute start_line={d} end_line={d}",
                .{ request.start_line, request.end_line },
            );

            var result = self.computeVisibleHighlightRequest(request) orelse continue;

            self.lockVisibleHighlightRuntime();
            self.visible_highlight_runtime.compute_in_flight = false;
            if (!self.visible_highlight_runtime.worker_running) {
                self.unlockVisibleHighlightRuntime();
                self.deinitVisibleHighlightResult(&result);
                return;
            }
            if (result.request.change_tick != self.doc.change_tick or result.request.epoch != self.doc.highlight_epoch) {
                self.unlockVisibleHighlightRuntime();
                self.deinitVisibleHighlightResult(&result);
                continue;
            }
            perf_log.logf(
                .info,
                "visible_highlight_worker_ready lines={d} start_line={d} end_line={d}",
                .{ result.lines.len, result.request.start_line, result.request.end_line },
            );
            if (self.visible_highlight_runtime.result) |*existing| {
                self.deinitVisibleHighlightResult(existing);
            }
            self.visible_highlight_runtime.result = result;
            self.unlockVisibleHighlightRuntime();
            self.requestRuntimeWake();
        }
    }

    pub fn clearVisibleHighlightResult(self: *Editor) void {
        if (self.visible_highlight_runtime.result) |*result| {
            self.deinitVisibleHighlightResult(result);
        }
        self.visible_highlight_runtime.result = null;
    }

    pub fn deinitVisibleHighlightResult(self: *Editor, result: *VisibleHighlightWorkResult) void {
        for (result.lines) |line| {
            self.allocator.free(line.tokens);
        }
        self.allocator.free(result.lines);
    }

    pub fn clearVisibleHighlightWork(self: *Editor) void {
        self.visible_highlight_runtime.work.active = false;
        self.visible_highlight_runtime.work.start = 0;
        self.visible_highlight_runtime.work.end = 0;
        self.visible_highlight_runtime.work.next = 0;
        self.visible_highlight_runtime.work.epoch = 0;
        self.visible_highlight_runtime.work.change_tick = 0;
        self.visible_highlight_runtime.work.completed_start = 0;
        self.visible_highlight_runtime.work.completed_end = 0;
        self.visible_highlight_runtime.work.completed_epoch = 0;
        self.visible_highlight_runtime.work.completed_change_tick = 0;
        self.clearVisibleHighlightRequest();
        self.clearVisibleHighlightResult();
    }

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
            .doc = .{
                .buffer = buffer,
                .highlighter = null,
                .highlight_invalidation = .{
                    .full_document = false,
                    .ranges = .empty,
                },
                .highlight_pending = false,
                .highlight_disabled_for_large_file = buffer.totalLen() >= highlighter_large_file_threshold_bytes,
                .search_query = null,
                .search_matches = .empty,
                .search_active = null,
                .search_mode = .literal,
                .search_refresh_on_text_change = false,
                .search_epoch = 0,
                .search_runtime = .{
                    .worker = null,
                    .worker_running = false,
                    .mutex = .{},
                    .cond = .{},
                    .generation = 0,
                    .request = null,
                    .result = null,
                },
                .change_tick = 0,
                .highlight_epoch = 0,
                .file_path = null,
                .modified = false,
                .saved_content_hash = contentHash(buffer),
                .grammar_manager = grammar_manager,
                .undo_selection_states = .empty,
                .next_undo_selection_state_id = 1,
            },
            .cursor = .{ .line = 0, .col = 0, .offset = 0 },
            .view = .{
                .preferred_visual_col = null,
                .scroll_line = 0,
                .scroll_col = 0,
                .scroll_row_offset = 0,
            },
            .selection = null,
            .selections = .empty,
            .line_width_cache = std.AutoHashMap(usize, usize).init(allocator),
            .cluster_offset_cache = std.AutoHashMap(usize, ClusterOffsetEntry).init(allocator),
            .max_line_width_cache = 0,
            .visible_highlight_runtime = .{
                .work = .{
                    .start = 0,
                    .end = 0,
                    .next = 0,
                    .epoch = 0,
                    .change_tick = 0,
                    .active = false,
                    .completed_start = 0,
                    .completed_end = 0,
                    .completed_epoch = 0,
                    .completed_change_tick = 0,
                },
                .worker = null,
                .worker_running = false,
                .mutex = .{},
                .cond = .{},
                .compute_in_flight = false,
                .request = null,
                .result = null,
            },
            .search_runtime_counters = .{},
            .highlight_runtime_counters = .{},
            .highlight_defer_frames = 0,
            .visible_cache_precompute_defer_frames = 0,
            .cluster_offsets_defer_frames = 0,
            .startup_defer_last_frame_id = 0,
            .tab_width = 4,
            .runtime_wake_fn = null,
        };
        return editor;
    }

    pub fn deinit(self: *Editor) void {
        self.stopVisibleHighlightWorker();
        self.stopSearchWorker();
        if (self.doc.highlighter) |h| {
            h.destroy();
        }
        if (self.doc.file_path) |path| {
            self.allocator.free(path);
        }
        if (self.doc.search_query) |query| {
            self.allocator.free(query);
        }
        self.doc.search_matches.deinit(self.allocator);
        self.doc.highlight_invalidation.ranges.deinit(self.allocator);
        for (self.doc.undo_selection_states.items) |state| {
            self.allocator.free(state.selections);
        }
        self.doc.undo_selection_states.deinit(self.allocator);
        self.selections.deinit(self.allocator);
        self.clearClusterOffsetCache();
        self.cluster_offset_cache.deinit();
        self.line_width_cache.deinit();
        self.doc.buffer.deinit();
        self.allocator.destroy(self);
    }

    pub fn openFile(self: *Editor, path: []const u8) !void {
        const log = app_logger.logger("editor.core");
        const perf_log = app_logger.logger("editor.perf");
        const t_start = std.time.nanoTimestamp();
        log.logf(.info, "openFile path=\"{s}\"", .{path});
        // Clean up old state
        self.clearHighlighter();
        self.doc.buffer.deinit();

        // Create new buffer from file
        self.doc.buffer = try text_store.TextStore.initFromFile(self.allocator, path);

        // Store path
        try self.setFilePath(path);

        // Reset state
        self.cursor = .{ .line = 0, .col = 0, .offset = 0 };
        self.clearPreferredVisualCol();
        self.selection = null;
        self.clearSelections();
        self.resetScrollState();
        self.invalidateLineWidthCache();
        self.markSaved();
        self.clearHighlightInvalidation();
        self.setHighlightDisabledForLargeFile();
        const startup_deferrals = runtime_policy.editorStartupDeferrals(runtime_policy.editorBackgroundIntent(), self.doc.highlight_disabled_for_large_file);
        self.highlight_defer_frames = startup_deferrals.highlight_frames;
        self.visible_cache_precompute_defer_frames = startup_deferrals.visible_cache_frames;
        self.cluster_offsets_defer_frames = startup_deferrals.cluster_offset_frames;
        self.startup_defer_last_frame_id = 0;
        self.scheduleHighlighter(path);
        const elapsed_us = @as(i64, @intCast(@divTrunc(std.time.nanoTimestamp() - t_start, 1000)));
        perf_log.logf(
            .info,
            "startup openFile path=\"{s}\" bytes={d} lines={d} highlight_disabled={any} defer_highlight={d} defer_precompute={d} defer_clusters={d} time_us={d}",
            .{
                path,
                self.doc.buffer.totalLen(),
                self.doc.buffer.lineCount(),
                self.doc.highlight_disabled_for_large_file,
                self.highlight_defer_frames,
                self.visible_cache_precompute_defer_frames,
                self.cluster_offsets_defer_frames,
                elapsed_us,
            },
        );
    }

    pub fn save(self: *Editor) !void {
        if (self.doc.file_path) |path| {
            const log = app_logger.logger("editor.core");
            log.logf(.info, "save path=\"{s}\"", .{path});
            try self.doc.buffer.saveToFile(path);
            self.markSaved();
        }
    }

    pub fn saveAs(self: *Editor, path: []const u8) !void {
        const log = app_logger.logger("editor.core");
        log.logf(.info, "saveAs path=\"{s}\"", .{path});
        try self.doc.buffer.saveToFile(path);
        try self.setFilePath(path);
        self.markSaved();
        self.setHighlightDisabledForLargeFile();
        self.highlight_defer_frames = 0;
        self.visible_cache_precompute_defer_frames = 0;
        self.cluster_offsets_defer_frames = 0;
        self.startup_defer_last_frame_id = 0;
        if (!self.doc.highlight_disabled_for_large_file) {
            try self.tryInitHighlighter(path);
        } else {
            self.setHighlightPending(false);
        }
    }

    pub fn invalidateLineWidthCache(self: *Editor) void {
        self.line_width_cache.clearRetainingCapacity();
        self.clearClusterOffsetCache();
        self.max_line_width_cache = 0;
    }

    pub fn cachedClusterOffsets(self: *Editor, line_idx: usize, line_text: []const u8) ?[]const u32 {
        if (!hasNonAscii(line_text)) return null;
        const text_hash = hashLine(line_text);
        if (self.cluster_offset_cache.getPtr(line_idx)) |entry| {
            if (entry.text_hash == text_hash) return entry.offsets;
            self.allocator.free(entry.offsets);
            _ = self.cluster_offset_cache.remove(line_idx);
        }
        return null;
    }

    pub fn cacheClusterOffsets(self: *Editor, line_idx: usize, line_text: []const u8, offsets: []u32) ?[]const u32 {
        if (!hasNonAscii(line_text)) {
            self.allocator.free(offsets);
            return null;
        }
        const text_hash = hashLine(line_text);
        if (self.cluster_offset_cache.getPtr(line_idx)) |entry| {
            self.allocator.free(entry.offsets);
            entry.* = .{ .text_hash = text_hash, .offsets = offsets };
            return entry.offsets;
        }
        self.cluster_offset_cache.put(line_idx, .{
            .text_hash = text_hash,
            .offsets = offsets,
        }) catch {
            self.allocator.free(offsets);
            return null;
        };
        return self.cluster_offset_cache.get(line_idx).?.offsets;
    }

    pub fn clearClusterOffsetCache(self: *Editor) void {
        var it = self.cluster_offset_cache.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.value_ptr.offsets);
        }
        self.cluster_offset_cache.clearRetainingCapacity();
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
    pub fn selectAll(self: *Editor) void {
        self.clearPreferredVisualCol();
        self.clearSelections();
        if (self.doc.buffer.totalLen() == 0) {
            self.cursor = .{ .line = 0, .col = 0, .offset = 0 };
            self.selection = null;
            return;
        }
        self.cursor = self.cursorPosForOffset(self.doc.buffer.totalLen());
        self.selection = .{
            .start = .{ .line = 0, .col = 0, .offset = 0 },
            .end = self.cursor,
        };
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
        self.setModified(true);
        self.invalidateLineWidthCache();
        self.bumpChangeTick();
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

    pub fn deleteCurrentLine(self: *Editor) !void {
        self.clearPreferredVisualCol();

        const line_count = self.doc.buffer.lineCount();
        if (line_count == 0) return;

        const before_id = try self.captureUndoSelectionState();
        const line_idx = @min(self.cursor.line, line_count - 1);
        const line_start = self.doc.buffer.lineStart(line_idx);
        const line_len = self.doc.buffer.lineLen(line_idx);

        var delete_start = line_start;
        var delete_end = line_start + line_len;

        if (line_count > 1) {
            if (line_idx + 1 < line_count) {
                delete_end = self.doc.buffer.lineStart(line_idx + 1);
            } else if (delete_start > 0) {
                delete_start -= 1;
            }
        }

        if (delete_end <= delete_start) return;

        const start_point = self.pointForByte(delete_start);
        const end_point = self.pointForByte(delete_end);
        try self.doc.buffer.deleteRange(delete_start, delete_end - delete_start);
        self.applyHighlightEdit(delete_start, delete_end, delete_start, start_point, end_point);
        self.setCursorOffsetNoClear(@min(delete_start, self.doc.buffer.totalLen()));
        self.selection = null;
        self.clearSelections();
        self.noteTextChanged();
        const after_id = try self.captureUndoSelectionState();
        self.annotateLastUndoSelectionState(before_id, after_id);
    }

    pub fn duplicateCurrentLine(self: *Editor) !void {
        self.clearPreferredVisualCol();

        const line_count = self.doc.buffer.lineCount();
        if (line_count == 0) return;

        const before_id = try self.captureUndoSelectionState();
        const line_idx = @min(self.cursor.line, line_count - 1);
        const line_start = self.doc.buffer.lineStart(line_idx);
        const line_len = self.doc.buffer.lineLen(line_idx);
        const line_text = try self.doc.buffer.readRangeAlloc(line_start, line_len);
        defer self.allocator.free(line_text);

        const insert_offset = if (line_idx + 1 < line_count) self.doc.buffer.lineStart(line_idx + 1) else self.doc.buffer.totalLen();
        const insert_text = if (line_idx + 1 < line_count)
            try std.fmt.allocPrint(self.allocator, "{s}\n", .{line_text})
        else
            try std.fmt.allocPrint(self.allocator, "\n{s}", .{line_text});
        defer self.allocator.free(insert_text);

        const insert_point = self.pointForByte(insert_offset);
        try self.doc.buffer.insertBytes(insert_offset, insert_text);
        self.applyHighlightEdit(insert_offset, insert_offset, insert_offset + insert_text.len, insert_point, insert_point);

        const target_line = @min(line_idx + 1, self.doc.buffer.lineCount() - 1);
        const target_col = @min(self.cursor.col, self.doc.buffer.lineLen(target_line));
        self.setCursor(target_line, target_col);
        self.selection = null;
        self.clearSelections();
        self.noteTextChanged();
        const after_id = try self.captureUndoSelectionState();
        self.annotateLastUndoSelectionState(before_id, after_id);
    }

    fn selectedLineRange(self: *Editor) struct { start: usize, end: usize } {
        if (self.selection) |sel| {
            const norm = sel.normalized();
            return .{
                .start = norm.start.line,
                .end = norm.end.line,
            };
        }
        return .{ .start = self.cursor.line, .end = self.cursor.line };
    }

    fn leadingOutdentWidth(self: *Editor, line_idx: usize) !usize {
        const line = try self.getLineAlloc(line_idx);
        defer self.allocator.free(line);
        if (line.len == 0) return 0;
        if (line[0] == '\t') return 1;

        var width: usize = 0;
        while (width < line.len and width < self.tab_width and line[width] == ' ') : (width += 1) {}
        return width;
    }

    fn shiftPrimarySelectionAfterLineTransform(
        self: *Editor,
        start_line: usize,
        end_line: usize,
        delta_cols: i32,
    ) void {
        if (self.selection) |sel| {
            var next = sel;
            if (next.start.line >= start_line and next.start.line <= end_line) {
                next.start.col = if (delta_cols >= 0)
                    next.start.col + @as(usize, @intCast(delta_cols))
                else
                    next.start.col -| @as(usize, @intCast(-delta_cols));
            }
            if (next.end.line >= start_line and next.end.line <= end_line) {
                next.end.col = if (delta_cols >= 0)
                    next.end.col + @as(usize, @intCast(delta_cols))
                else
                    next.end.col -| @as(usize, @intCast(-delta_cols));
            }
            next.start.offset = self.lineStart(next.start.line) + @min(next.start.col, self.lineLen(next.start.line));
            next.end.offset = self.lineStart(next.end.line) + @min(next.end.col, self.lineLen(next.end.line));
            self.selection = next;
        }
    }

    pub fn indentSelectedLines(self: *Editor) !void {
        self.clearPreferredVisualCol();
        const range = self.selectedLineRange();
        const before_id = try self.captureUndoSelectionState();

        var line_idx = range.end + 1;
        while (line_idx > range.start) {
            line_idx -= 1;
            const insert_offset = self.lineStart(line_idx);
            const insert_point = self.pointForByte(insert_offset);
            try self.doc.buffer.insertBytes(insert_offset, "\t");
            self.applyHighlightEdit(insert_offset, insert_offset, insert_offset + 1, insert_point, insert_point);
        }

        self.setCursorNoClear(self.cursor.line, self.cursor.col + 1);
        self.shiftPrimarySelectionAfterLineTransform(range.start, range.end, 1);
        self.noteTextChanged();
        const after_id = try self.captureUndoSelectionState();
        self.annotateLastUndoSelectionState(before_id, after_id);
    }

    pub fn outdentSelectedLines(self: *Editor) !void {
        self.clearPreferredVisualCol();
        const range = self.selectedLineRange();
        const before_id = try self.captureUndoSelectionState();

        var max_removed: usize = 0;
        var line_idx = range.end + 1;
        while (line_idx > range.start) {
            line_idx -= 1;
            const remove_len = try self.leadingOutdentWidth(line_idx);
            if (remove_len == 0) continue;
            if (remove_len > max_removed) max_removed = remove_len;
            const delete_start = self.lineStart(line_idx);
            const delete_end = delete_start + remove_len;
            const start_point = self.pointForByte(delete_start);
            const end_point = self.pointForByte(delete_end);
            try self.doc.buffer.deleteRange(delete_start, remove_len);
            self.applyHighlightEdit(delete_start, delete_end, delete_start, start_point, end_point);
        }

        if (max_removed > 0) {
            self.setCursorNoClear(self.cursor.line, self.cursor.col -| max_removed);
            self.shiftPrimarySelectionAfterLineTransform(range.start, range.end, -@as(i32, @intCast(max_removed)));
            self.noteTextChanged();
        }

        const after_id = try self.captureUndoSelectionState();
        self.annotateLastUndoSelectionState(before_id, after_id);
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
            const chunk = try self.doc.buffer.readRangeAlloc(norm.start.offset, len);
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
        self.clearPreferredVisualCol();
        const result = try self.doc.buffer.undoWithCursor();
        if (result.changed) {
            const log = app_logger.logger("editor.core");
            log.logf(.info, "undo ok", .{});
        }
        if (result.changed) {
            if (result.state) |state_id| {
                if (!(try self.restoreUndoSelectionState(state_id)) and result.cursor != null) {
                    const clamped = @min(result.cursor.?, self.doc.buffer.totalLen());
                    self.setCursorOffsetNoClear(clamped);
                    self.selection = null;
                    self.clearSelections();
                }
            } else if (result.cursor) |cursor_offset| {
                const clamped = @min(cursor_offset, self.doc.buffer.totalLen());
                self.setCursorOffsetNoClear(clamped);
                self.selection = null;
                self.clearSelections();
            } else {
                if (self.cursor.offset > self.doc.buffer.totalLen()) {
                    self.cursor.offset = self.doc.buffer.totalLen();
                }
                self.updateCursorPosition();
                self.selection = null;
                self.clearSelections();
            }
            if (self.doc.highlighter) |h| {
                _ = h.reparseFull();
                self.noteHighlightFullInvalidation();
                self.bumpHighlightEpoch();
            }
            self.invalidateLineWidthCache();
            self.bumpChangeTick();
            self.recomputeModifiedFromContent();
            if (self.doc.search_query != null) {
                const log = app_logger.logger("editor.core");
                self.recomputeSearchMatches() catch |err| {
                    log.logf(.warning, "recompute search matches after undo failed: {s}", .{@errorName(err)});
                };
            }
        }
        return result.changed;
    }

    pub fn redo(self: *Editor) !bool {
        self.clearPreferredVisualCol();
        const result = try self.doc.buffer.redoWithCursor();
        if (result.changed) {
            const log = app_logger.logger("editor.core");
            log.logf(.info, "redo ok", .{});
        }
        if (result.changed) {
            if (result.state) |state_id| {
                if (!(try self.restoreUndoSelectionState(state_id)) and result.cursor != null) {
                    const clamped = @min(result.cursor.?, self.doc.buffer.totalLen());
                    self.setCursorOffsetNoClear(clamped);
                    self.selection = null;
                    self.clearSelections();
                }
            } else if (result.cursor) |cursor_offset| {
                const clamped = @min(cursor_offset, self.doc.buffer.totalLen());
                self.setCursorOffsetNoClear(clamped);
                self.selection = null;
                self.clearSelections();
            } else {
                if (self.cursor.offset > self.doc.buffer.totalLen()) {
                    self.cursor.offset = self.doc.buffer.totalLen();
                }
                self.updateCursorPosition();
                self.selection = null;
                self.clearSelections();
            }
            if (self.doc.highlighter) |h| {
                _ = h.reparseFull();
                self.noteHighlightFullInvalidation();
                self.bumpHighlightEpoch();
            }
            self.invalidateLineWidthCache();
            self.bumpChangeTick();
            self.recomputeModifiedFromContent();
            if (self.doc.search_query != null) {
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
        return self.doc.buffer.lineCount();
    }

    pub fn totalLen(self: *Editor) usize {
        return self.doc.buffer.totalLen();
    }

    pub fn getLine(self: *Editor, line_index: usize, out: []u8) usize {
        return self.doc.buffer.readLine(line_index, out);
    }

    pub fn lineLen(self: *Editor, line_index: usize) usize {
        return self.doc.buffer.lineLen(line_index);
    }

    pub fn lineStart(self: *Editor, line_index: usize) usize {
        return self.doc.buffer.lineStart(line_index);
    }

    pub fn getLineAlloc(self: *Editor, line_index: usize) ![]u8 {
        const len = self.doc.buffer.lineLen(line_index);
        if (len == 0) return try self.allocator.alloc(u8, 0);
        const out = try self.allocator.alloc(u8, len);
        const read = self.doc.buffer.readLine(line_index, out);
        if (read < len) {
            return self.allocator.realloc(out, read);
        }
        return out;
    }

    pub fn takeHighlightInvalidationBatch(self: *Editor) ?HighlightInvalidationBatch {
        return SearchHighlight.takeHighlightInvalidationBatch(self);
    }

    pub fn noteTextChanged(self: *Editor) void {
        SearchHighlight.noteTextChanged(self);
    }

    pub fn noteTextChangedNoSearchRefresh(self: *Editor) void {
        SearchHighlight.noteTextChangedNoSearchRefresh(self);
    }

    pub fn noteHighlightInvalidationBytes(self: *Editor, start_byte: usize, end_byte: usize) void {
        SearchHighlight.noteHighlightInvalidationBytes(self, start_byte, end_byte);
    }

    pub fn noteHighlightInvalidationLines(self: *Editor, start_line: usize, end_line: usize) void {
        SearchHighlight.noteHighlightInvalidationLines(self, start_line, end_line);
    }

    pub fn noteHighlightFullInvalidation(self: *Editor) void {
        SearchHighlight.noteHighlightFullInvalidation(self);
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

    pub fn applyPendingSearchWork(self: *Editor) bool {
        return SearchHighlight.applyPendingSearchWork(self);
    }

    pub fn shouldDeferVisibleCachePrecompute(self: *Editor) bool {
        return self.visible_cache_precompute_defer_frames > 0;
    }

    pub fn advanceStartupDeferrals(self: *Editor, frame_id: u64) void {
        if (self.startup_defer_last_frame_id == frame_id) return;
        self.startup_defer_last_frame_id = frame_id;
        if (self.highlight_defer_frames > 0) self.highlight_defer_frames -= 1;
        if (self.visible_cache_precompute_defer_frames > 0) self.visible_cache_precompute_defer_frames -= 1;
        if (self.cluster_offsets_defer_frames > 0) self.cluster_offsets_defer_frames -= 1;
    }

    pub fn shouldDeferClusterOffsets(self: *Editor) bool {
        return self.cluster_offsets_defer_frames > 0;
    }

    pub fn isVisibleHighlightRangeComplete(self: *const Editor, start_line: usize, end_line: usize, epoch: u64) bool {
        return !self.visible_highlight_runtime.work.active and
            start_line == self.visible_highlight_runtime.work.completed_start and
            end_line == self.visible_highlight_runtime.work.completed_end and
            epoch == self.visible_highlight_runtime.work.completed_epoch;
    }

    pub fn shouldThrottleVisibleHighlightRange(self: *const Editor, start_line: usize, end_line: usize, epoch: u64) bool {
        return !self.isVisibleHighlightRangeComplete(start_line, end_line, epoch);
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

    pub fn applyPendingSearchResult(self: *Editor) bool {
        return SearchHighlight.applyPendingSearchResult(self);
    }

    fn contentHash(buffer: *TextStore) u64 {
        var hasher = std.hash.Wyhash.init(0);
        const total = buffer.totalLen();
        var offset: usize = 0;
        var scratch: [4096]u8 = undefined;
        while (offset < total) {
            const chunk_len = @min(scratch.len, total - offset);
            const read = buffer.readRange(offset, scratch[0..chunk_len]);
            if (read == 0) break;
            hasher.update(scratch[0..read]);
            offset += read;
        }
        hasher.update(std.mem.asBytes(&total));
        return hasher.final();
    }

    fn hashLine(text: []const u8) u64 {
        var h: u64 = 1469598103934665603;
        for (text) |byte| {
            h ^= byte;
            h *%= 1099511628211;
        }
        return h;
    }

    fn hasNonAscii(text: []const u8) bool {
        for (text) |byte| {
            if (byte & 0x80 != 0) return true;
        }
        return false;
    }
};

test "deleteCurrentLine removes middle line and keeps cursor on following line" {
    var grammar_manager = grammar_manager_mod.GrammarManager.init(std.testing.allocator);
    defer grammar_manager.deinit();

    const buffer = try text_store.TextStore.init(std.testing.allocator, "alpha\nbeta\ngamma");
    var editor = try Editor.initWithStore(std.testing.allocator, buffer, &grammar_manager);
    defer editor.deinit();

    editor.setCursor(1, 2);
    try editor.deleteCurrentLine();

    const snapshot = try @import("snapshot.zig").capture(std.testing.allocator, editor);
    defer std.testing.allocator.free(snapshot);

    try std.testing.expectEqualStrings("alpha\ngamma", snapshot);
    try std.testing.expectEqual(@as(usize, 1), editor.cursor.line);
    try std.testing.expectEqual(@as(usize, 0), editor.cursor.col);
    try std.testing.expect(editor.modified);
}

test "duplicateCurrentLine duplicates middle line and keeps cursor on duplicate" {
    var grammar_manager = grammar_manager_mod.GrammarManager.init(std.testing.allocator);
    defer grammar_manager.deinit();

    const buffer = try text_store.TextStore.init(std.testing.allocator, "alpha\nbeta\ngamma");
    var editor = try Editor.initWithStore(std.testing.allocator, buffer, &grammar_manager);
    defer editor.deinit();

    editor.setCursor(1, 2);
    try editor.duplicateCurrentLine();

    const snapshot = try @import("snapshot.zig").capture(std.testing.allocator, editor);
    defer std.testing.allocator.free(snapshot);

    try std.testing.expectEqualStrings("alpha\nbeta\nbeta\ngamma", snapshot);
    try std.testing.expectEqual(@as(usize, 2), editor.cursor.line);
    try std.testing.expectEqual(@as(usize, 2), editor.cursor.col);
    try std.testing.expect(editor.modified);
}

test "indentSelectedLines indents current line when no selection" {
    var grammar_manager = grammar_manager_mod.GrammarManager.init(std.testing.allocator);
    defer grammar_manager.deinit();

    const buffer = try text_store.TextStore.init(std.testing.allocator, "alpha\nbeta");
    var editor = try Editor.initWithStore(std.testing.allocator, buffer, &grammar_manager);
    defer editor.deinit();

    editor.setCursor(1, 2);
    try editor.indentSelectedLines();

    const snapshot = try @import("snapshot.zig").capture(std.testing.allocator, editor);
    defer std.testing.allocator.free(snapshot);

    try std.testing.expectEqualStrings("alpha\n\tbeta", snapshot);
    try std.testing.expectEqual(@as(usize, 1), editor.cursor.line);
    try std.testing.expectEqual(@as(usize, 3), editor.cursor.col);
}

test "outdentSelectedLines removes leading tab from selected lines" {
    var grammar_manager = grammar_manager_mod.GrammarManager.init(std.testing.allocator);
    defer grammar_manager.deinit();

    const buffer = try text_store.TextStore.init(std.testing.allocator, "\tone\n\ttwo\nthree");
    var editor = try Editor.initWithStore(std.testing.allocator, buffer, &grammar_manager);
    defer editor.deinit();

    editor.selection = .{
        .start = .{ .line = 0, .col = 0, .offset = 0 },
        .end = .{ .line = 1, .col = 1, .offset = 6 },
    };
    editor.setCursorNoClear(1, 1);
    try editor.outdentSelectedLines();

    const snapshot = try @import("snapshot.zig").capture(std.testing.allocator, editor);
    defer std.testing.allocator.free(snapshot);

    try std.testing.expectEqualStrings("one\ntwo\nthree", snapshot);
}

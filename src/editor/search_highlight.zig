const std = @import("std");
const manual_highlights_mod = @import("manual_highlights.zig");
const syntax_mod = @import("syntax.zig");
const ts_api = @import("treesitter_api.zig");
const syntax_registry_mod = @import("syntax_registry.zig");
const app_logger = @import("../app_logger.zig");
const runtime_policy = @import("../app/runtime_policy.zig");

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

pub const SearchMatch = struct {
    start: usize,
    end: usize,
};

pub const SearchMode = enum {
    literal,
    regex,
};

pub const SearchWorkRequest = struct {
    generation: u64,
    preferred_offset: usize,
    mode: SearchMode,
    query: []u8,
    content: []u8,
};

pub const SearchWorkResult = struct {
    generation: u64,
    preferred_offset: usize,
    matches: []SearchMatch,
};

pub const HighlightInvalidationRange = struct {
    start_line: usize,
    end_line: usize,
};

pub const HighlightInvalidationBatch = struct {
    full_document: bool,
    ranges: []HighlightInvalidationRange,
};

pub fn SearchHighlightOps(comptime Editor: type) type {
    return struct {
        pub fn takeHighlightInvalidationBatch(self: *Editor) ?HighlightInvalidationBatch {
            if (!self.doc.highlight_invalidation.full_document and self.doc.highlight_invalidation.ranges.items.len == 0) return null;
            const batch = HighlightInvalidationBatch{
                .full_document = self.doc.highlight_invalidation.full_document,
                .ranges = self.doc.highlight_invalidation.ranges.items,
            };
            self.doc.highlight_invalidation = .{
                .full_document = false,
                .ranges = .empty,
            };
            return batch;
        }

        pub fn noteTextChanged(self: *Editor) void {
            self.noteTextChangedBase();
            if (self.doc.search_query != null and self.doc.search_refresh_on_text_change) {
                self.recomputeSearchMatches() catch |err| {
                    const log = app_logger.logger("editor.search");
                    log.logf(.warning, "recompute search matches on text change failed: {s}", .{@errorName(err)});
                };
            }
        }

        pub fn noteTextChangedNoSearchRefresh(self: *Editor) void {
            self.noteTextChangedBase();
        }

        pub fn noteHighlightInvalidationLines(self: *Editor, start_line: usize, end_line: usize) void {
            if (self.doc.highlight_invalidation.full_document) return;
            if (end_line <= start_line) return;

            var merged_start = start_line;
            var merged_end = end_line;
            var idx: usize = 0;
            while (idx < self.doc.highlight_invalidation.ranges.items.len) {
                const existing = self.doc.highlight_invalidation.ranges.items[idx];
                if (merged_end < existing.start_line or existing.end_line < merged_start) {
                    idx += 1;
                    continue;
                }
                merged_start = @min(merged_start, existing.start_line);
                merged_end = @max(merged_end, existing.end_line);
                _ = self.doc.highlight_invalidation.ranges.orderedRemove(idx);
            }
            self.doc.highlight_invalidation.ranges.append(self.allocator, .{
                .start_line = merged_start,
                .end_line = merged_end,
            }) catch |err| {
                const log = app_logger.logger("editor.highlight");
                log.logf(.warning, "highlight invalidation append failed start_line={d} end_line={d} err={s}", .{ merged_start, merged_end, @errorName(err) });
                self.noteHighlightFullInvalidation();
            };
        }

        pub fn noteHighlightInvalidationBytes(self: *Editor, start_byte: usize, end_byte: usize) void {
            const start_line = self.doc.buffer.lineIndexForOffset(start_byte);
            const end_line = self.doc.buffer.lineIndexForOffset(end_byte) + 1;
            self.noteHighlightInvalidationLines(start_line, end_line);
        }

        pub fn noteHighlightFullInvalidation(self: *Editor) void {
            self.doc.highlight_invalidation.full_document = true;
            self.doc.highlight_invalidation.ranges.clearRetainingCapacity();
        }

        pub fn applyHighlightEdit(
            self: *Editor,
            start_byte: usize,
            old_end_byte: usize,
            new_end_byte: usize,
            start_point: c.TSPoint,
            old_end_point: c.TSPoint,
        ) void {
            if (self.doc.highlighter == null) return;
            const h = self.doc.highlighter.?;
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
                self.noteHighlightFullInvalidation();
                return;
            };
            defer self.allocator.free(ranges);

            if (ranges.len == 0) {
                const min_byte = @min(start_byte, @min(old_end_byte, new_end_byte));
                const max_byte = @max(start_byte, @max(old_end_byte, new_end_byte));
                self.noteHighlightInvalidationBytes(min_byte, max_byte);
                return;
            }
            for (ranges) |range| {
                self.noteHighlightInvalidationBytes(range.start_byte, range.end_byte);
            }
        }

        pub fn scheduleHighlighter(self: *Editor, path: ?[]const u8) void {
            const log = app_logger.logger("editor.highlight");
            const intent = runtime_policy.editorBackgroundIntent();
            self.resetHighlightRuntimeCounters();
            if (self.doc.highlight_disabled_for_large_file) {
                self.recordHighlightSkippedLargeFile();
                if (self.doc.highlighter) |h| {
                    h.destroy();
                    self.clearHighlighter();
                }
                self.bumpHighlightEpoch();
                self.clearHighlightInvalidation();
                self.setHighlightPending(false);
                log.logf(
                    .info,
                    "highlight skipped large_file lifecycle={s} work_class={s} bytes={d} threshold={d} path=\"{s}\"",
                    .{
                        runtime_policy.lifecycleLabel(intent.lifecycle),
                        runtime_policy.workClassLabel(intent.work_class),
                        self.doc.buffer.totalLen(),
                        Editor.highlighter_large_file_threshold_bytes,
                        path orelse "",
                    },
                );
                return;
            }
            const lang = syntax_registry_mod.SyntaxRegistry.resolveLanguage(path);
            const manual_override = manual_highlights_mod.resolve(path, lang);
            if (lang == null and manual_override == null) {
                self.recordHighlightDisabledNoLanguage();
                if (self.doc.highlighter) |h| {
                    h.destroy();
                    self.clearHighlighter();
                }
                self.bumpHighlightEpoch();
                self.clearHighlightInvalidation();
                self.setHighlightPending(false);
                log.logf(
                    .info,
                    "highlight disabled lifecycle={s} work_class={s} path=\"{s}\"",
                    .{
                        runtime_policy.lifecycleLabel(intent.lifecycle),
                        runtime_policy.workClassLabel(intent.work_class),
                        path orelse "",
                    },
                );
                return;
            }
            self.setHighlightPending(true);
            self.recordHighlightScheduled();
            log.logf(
                .info,
                "highlight scheduled lifecycle={s} work_class={s} path=\"{s}\" lang={s} manual_parser={s} manual_mode={s}",
                .{
                    runtime_policy.lifecycleLabel(intent.lifecycle),
                    runtime_policy.workClassLabel(intent.work_class),
                    path orelse "",
                    lang orelse "(none)",
                    if (manual_override) |spec| spec.parser else "(none)",
                    if (manual_override) |spec| @tagName(spec.mode) else "(none)",
                },
            );
        }

        pub fn tryInitHighlighter(self: *Editor, path: ?[]const u8) !void {
            const log = app_logger.logger("editor.highlight");
            log.logf(.info, "highlight init check path=\"{s}\"", .{path orelse ""});
            self.setHighlightPending(false);
            self.recordHighlightInitAttempt();
            const lang = syntax_registry_mod.SyntaxRegistry.resolveLanguage(path);
            const manual_override = manual_highlights_mod.resolve(path, lang);
            const effective_lang = if (manual_override) |spec| spec.parser else lang;
            log.logf(
                .info,
                "highlight language decision path=\"{s}\" lang={s} manual_parser={s} effective_lang={s}",
                .{
                    path orelse "",
                    lang orelse "(none)",
                    if (manual_override) |spec| spec.parser else "(none)",
                    effective_lang orelse "(none)",
                },
            );
            if (effective_lang == null) {
                if (self.doc.highlighter) |h| {
                    h.destroy();
                    self.clearHighlighter();
                }
                self.bumpHighlightEpoch();
                self.clearHighlightInvalidation();
                log.logf(.info, "highlight disabled path=\"{s}\"", .{path orelse ""});
                return;
            }
            if (self.doc.highlighter == null) {
                const t_start = std.time.nanoTimestamp();
                log.logf(.info, "highlight init start", .{});
                const grammar = try self.doc.grammar_manager.getOrLoad(effective_lang.?) orelse blk: {
                    log.logf(.info, "highlight missing grammar lang={s}", .{effective_lang.?});
                    if (shouldAutoBootstrapGrammars()) {
                        _ = self.tryAutoBootstrapGrammars();
                        switch (grammarAutoBootstrapState()) {
                            .running => return,
                            .succeeded => {
                                if (try self.doc.grammar_manager.getOrLoad(effective_lang.?)) |loaded| {
                                    log.logf(.info, "highlight grammar loaded after bootstrap lang={s}", .{effective_lang.?});
                                    break :blk loaded;
                                }
                                log.logf(.info, "highlight grammar still missing after bootstrap lang={s}", .{effective_lang.?});
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
                var query_paths = grammar.query_paths;
                if (manual_override) |spec| {
                    if (spec.query_path) |query_path| {
                        if (spec.mode == .replace) {
                            query_paths.highlights = @constCast(query_path);
                            query_paths.highlights_overlay = null;
                            query_paths.highlights_overlay_mode = .replace;
                        } else {
                            query_paths.highlights_overlay = query_path;
                            query_paths.highlights_overlay_mode = spec.mode;
                        }
                    }
                }
                self.doc.highlighter = syntax_mod.createHighlighterForLanguage(
                    self.allocator,
                    self.doc.buffer,
                    effective_lang.?,
                    grammar.ts_language,
                    query_paths,
                    self.doc.grammar_manager,
                ) catch |err| {
                    self.recordHighlightInitFailure();
                    log.logf(.info, "highlight init failed err={any}", .{err});
                    return err;
                };
                self.recordHighlightInitSuccess();
                self.bumpHighlightEpoch();
                self.noteHighlightFullInvalidation();
                const elapsed_ns = std.time.nanoTimestamp() - t_start;
                log.logf(
                    .info,
                    "highlight enabled path=\"{s}\" time_us={d}",
                    .{ path orelse "", @as(i64, @intCast(@divTrunc(elapsed_ns, 1000))) },
                );
            }
        }

        pub fn tryAutoBootstrapGrammars(self: *Editor) bool {
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

        pub fn emitMissingGrammarNotice(
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

        pub fn ensureHighlighter(self: *Editor) void {
            if (self.doc.highlight_disabled_for_large_file) return;
            if (!self.doc.highlight_pending) return;
            if (self.highlight_defer_frames > 0) return;
            self.tryInitHighlighter(self.doc.file_path) catch |err| {
                const log = app_logger.logger("editor.highlight");
                log.logf(.warning, "ensure highlighter init failed: {s}", .{@errorName(err)});
            };
        }

        pub fn applyPendingSearchWork(self: *Editor) bool {
            return self.applyPendingSearchResult();
        }

        pub fn setSearchQuery(self: *Editor, query: ?[]const u8) !void {
            self.setSearchMode(.literal);
            if (query) |value| {
                if (value.len == 0) {
                    self.clearSearchState();
                    return;
                }
                try self.setSearchQueryOwned(value);
            } else {
                self.clearSearchState();
                return;
            }
            try self.recomputeSearchMatchesPrefer(self.cursor.offset);
        }

        pub fn setSearchQueryRegex(self: *Editor, query: ?[]const u8) !void {
            self.setSearchMode(.regex);
            if (query) |value| {
                if (value.len == 0) {
                    self.clearSearchState();
                    return;
                }
                try self.setSearchQueryOwned(value);
            } else {
                self.clearSearchState();
                return;
            }
            try self.recomputeSearchMatchesPrefer(self.cursor.offset);
        }

        pub fn searchMatches(self: *const Editor) []const SearchMatch {
            return self.doc.search_matches.items;
        }

        pub fn searchQuery(self: *const Editor) ?[]const u8 {
            return self.doc.search_query;
        }

        pub fn searchActiveMatch(self: *const Editor) ?SearchMatch {
            const idx = self.doc.search_active orelse return null;
            if (idx >= self.doc.search_matches.items.len) return null;
            return self.doc.search_matches.items[idx];
        }

        pub fn searchActiveIndex(self: *const Editor) ?usize {
            const idx = self.doc.search_active orelse return null;
            if (idx >= self.doc.search_matches.items.len) return null;
            return idx;
        }

        pub fn focusSearchActiveMatch(self: *Editor) bool {
            if (self.searchActiveMatch() == null) return false;
            self.jumpToSearchActive();
            return true;
        }

        pub fn activateNextSearchMatch(self: *Editor) bool {
            if (self.doc.search_matches.items.len == 0) return false;
            const next = if (self.doc.search_active) |idx|
                (idx + 1) % self.doc.search_matches.items.len
            else
                0;
            self.setSearchActive(next);
            self.jumpToSearchActive();
            return true;
        }

        pub fn activatePrevSearchMatch(self: *Editor) bool {
            if (self.doc.search_matches.items.len == 0) return false;
            const prev = if (self.doc.search_active) |idx|
                if (idx == 0) self.doc.search_matches.items.len - 1 else idx - 1
            else
                self.doc.search_matches.items.len - 1;
            self.setSearchActive(prev);
            self.jumpToSearchActive();
            return true;
        }

        pub fn replaceActiveSearchMatch(self: *Editor, replacement: []const u8) !bool {
            const active_idx = self.doc.search_active orelse return false;
            if (active_idx >= self.doc.search_matches.items.len) return false;
            const active = self.doc.search_matches.items[active_idx];

            _ = try self.beginTrackedUndoGroup();
            errdefer self.endTrackedUndoGroup() catch |err| {
                const log = app_logger.logger("editor.search");
                log.logf(.warning, "tracked undo cleanup failed (replace active): {s}", .{@errorName(err)});
            };
            try self.replaceByteRangeInternal(active.start, active.end, replacement, false);
            try self.recomputeSearchMatchesSync();
            self.setSearchActive(self.findSearchMatchAtOrAfter(active.start + replacement.len));
            if (self.doc.search_active != null) {
                self.jumpToSearchActive();
            }
            try self.endTrackedUndoGroup();
            return true;
        }

        pub fn replaceAllSearchMatches(self: *Editor, replacement: []const u8) !usize {
            if (self.doc.search_matches.items.len == 0) return 0;

            const matches = try self.allocator.dupe(SearchMatch, self.doc.search_matches.items);
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

        pub fn jumpToSearchActive(self: *Editor) void {
            const active = self.searchActiveMatch() orelse return;
            self.setCursorOffsetNoClear(active.start);
            self.selection = null;
            self.clearSelections();
        }

        pub fn findSearchMatchAtOrAfter(self: *const Editor, offset: usize) ?usize {
            for (self.doc.search_matches.items, 0..) |match, idx| {
                if (match.start >= offset) return idx;
            }
            return null;
        }

        pub fn clearSearchState(self: *Editor) void {
            self.resetSearchRuntimeCounters();
            self.cancelPendingSearchWork();
            self.clearSearchMatches();
            self.setSearchActive(null);
            self.bumpSearchEpoch();
        }

        pub fn recomputeSearchMatches(self: *Editor) !void {
            const preferred = if (self.searchActiveMatch()) |active| active.start else self.cursor.offset;
            try self.recomputeSearchMatchesPrefer(preferred);
        }

        pub fn recomputeSearchMatchesPrefer(self: *Editor, preferred_offset: usize) !void {
            const schedule_intent = runtime_policy.editorInteractiveIntent();
            const worker_intent = runtime_policy.editorBackgroundIntent();
            const query = self.doc.search_query orelse {
                self.clearSearchState();
                return;
            };
            if (query.len == 0) {
                self.clearSearchState();
                return;
            }

            const total = self.doc.buffer.totalLen();
            const content_owned = try self.doc.buffer.readRangeAlloc(0, total);
            defer self.allocator.free(content_owned);
            const query_copy = try c_allocator.dupe(u8, query);
            errdefer c_allocator.free(query_copy);
            const content_copy = try c_allocator.dupe(u8, content_owned);
            errdefer c_allocator.free(content_copy);

            const generation_opt = self.queueSearchRequest(preferred_offset, self.doc.search_mode, query_copy, content_copy);
            if (generation_opt == null) {
                self.recordSearchSyncFallback();
                c_allocator.free(query_copy);
                c_allocator.free(content_copy);
                const log = app_logger.logger("editor.search");
                log.logf(
                    .debug,
                    "search sync fallback lifecycle={s} work_class={s} query_len={d} content_len={d} mode={s}",
                    .{
                        runtime_policy.lifecycleLabel(schedule_intent.lifecycle),
                        runtime_policy.workClassLabel(schedule_intent.work_class),
                        query.len,
                        content_owned.len,
                        @tagName(self.doc.search_mode),
                    },
                );
                try self.recomputeSearchMatchesSyncPrefer(preferred_offset);
                return;
            }
            const generation = generation_opt.?;
            self.recordSearchScheduledAsync();

            self.clearSearchMatches();
            self.setSearchActive(null);
            self.bumpSearchEpoch();
            if (total > 0) self.noteHighlightInvalidationBytes(0, total - 1);

            const log = app_logger.logger("editor.search");
            log.logf(
                .debug,
                "search scheduled generation={d} schedule_lifecycle={s} schedule_work_class={s} worker_lifecycle={s} worker_work_class={s} query_len={d} content_len={d} mode={s}",
                .{
                    generation,
                    runtime_policy.lifecycleLabel(schedule_intent.lifecycle),
                    runtime_policy.workClassLabel(schedule_intent.work_class),
                    runtime_policy.lifecycleLabel(worker_intent.lifecycle),
                    runtime_policy.workClassLabel(worker_intent.work_class),
                    query.len,
                    content_owned.len,
                    @tagName(self.doc.search_mode),
                },
            );
        }

        pub fn recomputeSearchMatchesSync(self: *Editor) !void {
            const preferred = if (self.searchActiveMatch()) |active| active.start else self.cursor.offset;
            try self.recomputeSearchMatchesSyncPrefer(preferred);
        }

        pub fn recomputeSearchMatchesSyncPrefer(self: *Editor, preferred_offset: usize) !void {
            self.clearSearchMatches();
            const query = self.doc.search_query orelse {
                self.setSearchActive(null);
                self.bumpSearchEpoch();
                return;
            };
            if (query.len == 0) {
                self.setSearchActive(null);
                self.bumpSearchEpoch();
                return;
            }

            const total = self.doc.buffer.totalLen();
            const content = try self.doc.buffer.readRangeAlloc(0, total);
            defer self.allocator.free(content);

            const matches = try computeSearchMatchesAlloc(self.allocator, self.doc.search_mode, query, content);
            defer self.allocator.free(matches);
            try self.replaceSearchMatches(matches);
            self.setSearchActive(self.pickSearchActiveIndex(preferred_offset));
            self.bumpSearchEpoch();
            if (total > 0) self.noteHighlightInvalidationBytes(0, total - 1);
        }

        pub fn queueSearchRequest(
            self: *Editor,
            preferred_offset: usize,
            mode: SearchMode,
            query: []u8,
            content: []u8,
        ) ?u64 {
            self.ensureSearchWorker();
            self.lockSearchRuntime();
            defer self.unlockSearchRuntime();
            if (!self.isSearchWorkerRunning()) return null;

            const generation = self.bumpSearchGeneration();
            self.replaceSearchRequest(.{
                .generation = generation,
                .preferred_offset = preferred_offset,
                .mode = mode,
                .query = query,
                .content = content,
            });
            self.signalSearchRuntime();
            return generation;
        }

        pub fn ensureSearchWorker(self: *Editor) void {
            self.lockSearchRuntime();
            if (self.isSearchWorkerRunning()) {
                self.unlockSearchRuntime();
                return;
            }
            self.setSearchWorkerRunning(true);
            self.unlockSearchRuntime();

            const worker = std.Thread.spawn(.{}, searchWorkerMain, .{self}) catch |err| {
                self.recordSearchWorkerSpawnFailure();
                const log = app_logger.logger("editor.search");
                log.logf(.warning, "search worker spawn failed err={s}", .{@errorName(err)});
                self.lockSearchRuntime();
                self.setSearchWorkerRunning(false);
                self.unlockSearchRuntime();
                return;
            };
            self.recordSearchWorkerSpawn();
            self.setSearchWorker(worker);
        }

        pub fn stopSearchWorker(self: *Editor) void {
            self.lockSearchRuntime();
            self.setSearchWorkerRunning(false);
            self.clearPendingSearchRequest();
            self.signalSearchRuntime();
            self.unlockSearchRuntime();

            if (self.takeSearchWorker()) |thread| {
                thread.join();
            }

            self.lockSearchRuntime();
            defer self.unlockSearchRuntime();
            self.clearPendingSearchResult();
        }

        pub fn cancelPendingSearchWork(self: *Editor) void {
            self.lockSearchRuntime();
            defer self.unlockSearchRuntime();
            _ = self.bumpSearchGeneration();
            self.clearPendingSearchRequest();
            self.clearPendingSearchResult();
        }

        pub fn applyPendingSearchResult(self: *Editor) bool {
            self.lockSearchRuntime();
            const result_opt = self.takeSearchResult();
            if (result_opt == null) {
                self.unlockSearchRuntime();
                return false;
            }
            const result = result_opt.?;
            const latest_generation = self.currentSearchGeneration();
            self.unlockSearchRuntime();

            defer c_allocator.free(result.matches);
            if (result.generation != latest_generation) {
                self.recordSearchStaleResultDropped();
                return false;
            }

            self.replaceSearchMatches(result.matches) catch |err| {
                const log = app_logger.logger("editor.search");
                log.logf(.warning, "apply search result append failed err={s}", .{@errorName(err)});
                self.setSearchActive(null);
                self.bumpSearchEpoch();
                return false;
            };
            self.recordSearchResultApplied();
            self.setSearchActive(self.pickSearchActiveIndex(result.preferred_offset));
            self.bumpSearchEpoch();
            const total = self.doc.buffer.totalLen();
            if (total > 0) self.noteHighlightInvalidationBytes(0, total - 1);
            return true;
        }

        fn searchWorkerMain(self: *Editor) void {
            while (true) {
                self.lockSearchRuntime();
                while (self.isSearchWorkerRunning() and !self.hasPendingSearchRequest()) {
                    self.waitSearchRuntime();
                }
                if (!self.isSearchWorkerRunning()) {
                    self.unlockSearchRuntime();
                    return;
                }
                const request = self.takeSearchRequest().?;
                self.unlockSearchRuntime();

                const matches = computeSearchMatchesAlloc(c_allocator, request.mode, request.query, request.content) catch |err| {
                    const log = app_logger.logger("editor.search");
                    log.logf(.warning, "search worker compute failed generation={d} err={s}", .{ request.generation, @errorName(err) });
                    c_allocator.free(request.query);
                    c_allocator.free(request.content);
                    continue;
                };
                c_allocator.free(request.query);
                c_allocator.free(request.content);

                self.lockSearchRuntime();
                if (!self.isSearchWorkerRunning()) {
                    self.unlockSearchRuntime();
                    c_allocator.free(matches);
                    return;
                }
                if (request.generation != self.currentSearchGeneration()) {
                    self.recordSearchStaleResultDropped();
                    const log = app_logger.logger("editor.search");
                    log.logf(
                        .debug,
                        "search worker dropped stale generation={d} lifecycle={s} work_class={s}",
                        .{
                            request.generation,
                            runtime_policy.lifecycleLabel(runtime_policy.editorBackgroundIntent().lifecycle),
                            runtime_policy.workClassLabel(runtime_policy.editorBackgroundIntent().work_class),
                        },
                    );
                    self.unlockSearchRuntime();
                    c_allocator.free(matches);
                    continue;
                }
                self.replaceSearchResult(.{
                    .generation = request.generation,
                    .preferred_offset = request.preferred_offset,
                    .matches = matches,
                });
                self.unlockSearchRuntime();
                self.requestRuntimeWake();
            }
        }

        pub fn pickSearchActiveIndex(self: *const Editor, preferred_offset: usize) ?usize {
            if (self.doc.search_matches.items.len == 0) return null;
            for (self.doc.search_matches.items, 0..) |match, idx| {
                if (match.start >= preferred_offset) return idx;
            }
            return 0;
        }
    };
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

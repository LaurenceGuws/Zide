const std = @import("std");
const syntax_mod = @import("syntax.zig");
const ts_api = @import("treesitter_api.zig");
const syntax_registry_mod = @import("syntax_registry.zig");
const app_logger = @import("../app_logger.zig");

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

pub const HighlightDirtyRange = struct {
    start_line: usize,
    end_line: usize,
};

pub fn SearchHighlightOps(comptime Editor: type) type {
    return struct {
        pub fn takeHighlightDirtyRange(self: *Editor) ?HighlightDirtyRange {
            if (self.highlight_dirty_start_line == null) return null;
            const start = self.highlight_dirty_start_line.?;
            const end = self.highlight_dirty_end_line orelse (start + 1);
            self.highlight_dirty_start_line = null;
            self.highlight_dirty_end_line = null;
            return .{ .start_line = start, .end_line = end };
        }

        pub fn noteTextChanged(self: *Editor) void {
            self.noteTextChangedBase();
            if (self.search_query != null) {
                self.recomputeSearchMatches() catch |err| {
                    const log = app_logger.logger("editor.search");
                    log.logf(.warning, "recompute search matches on text change failed: {s}", .{@errorName(err)});
                };
            }
        }

        pub fn noteTextChangedNoSearchRefresh(self: *Editor) void {
            self.noteTextChangedBase();
        }

        pub fn noteHighlightDirtyRange(self: *Editor, start_byte: usize, end_byte: usize) void {
            const start_line = self.buffer.lineIndexForOffset(start_byte);
            const end_line = self.buffer.lineIndexForOffset(end_byte) + 1;
            const start = self.highlight_dirty_start_line orelse start_line;
            const end = self.highlight_dirty_end_line orelse end_line;
            self.highlight_dirty_start_line = @min(start, start_line);
            self.highlight_dirty_end_line = @max(end, end_line);
        }

        pub fn applyHighlightEdit(
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

        pub fn scheduleHighlighter(self: *Editor, path: ?[]const u8) void {
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
                    .{ self.buffer.totalLen(), Editor.highlighter_large_file_threshold_bytes, path orelse "" },
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

        pub fn tryInitHighlighter(self: *Editor, path: ?[]const u8) !void {
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

        pub fn jumpToSearchActive(self: *Editor) void {
            const active = self.searchActiveMatch() orelse return;
            self.setCursorOffsetNoClear(active.start);
            self.selection = null;
            self.clearSelections();
        }

        pub fn findSearchMatchAtOrAfter(self: *const Editor, offset: usize) ?usize {
            for (self.search_matches.items, 0..) |match, idx| {
                if (match.start >= offset) return idx;
            }
            return null;
        }

        pub fn clearSearchState(self: *Editor) void {
            self.cancelPendingSearchWork();
            self.search_matches.clearRetainingCapacity();
            self.search_active = null;
            self.search_epoch +|= 1;
        }

        pub fn recomputeSearchMatches(self: *Editor) !void {
            const preferred = if (self.searchActiveMatch()) |active| active.start else self.cursor.offset;
            try self.recomputeSearchMatchesPrefer(preferred);
        }

        pub fn recomputeSearchMatchesPrefer(self: *Editor, preferred_offset: usize) !void {
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

            const generation_opt = self.queueSearchRequest(preferred_offset, self.search_mode, query_copy, content_copy);
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

        pub fn recomputeSearchMatchesSync(self: *Editor) !void {
            const preferred = if (self.searchActiveMatch()) |active| active.start else self.cursor.offset;
            try self.recomputeSearchMatchesSyncPrefer(preferred);
        }

        pub fn recomputeSearchMatchesSyncPrefer(self: *Editor, preferred_offset: usize) !void {
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

        pub fn queueSearchRequest(
            self: *Editor,
            preferred_offset: usize,
            mode: SearchMode,
            query: []u8,
            content: []u8,
        ) ?u64 {
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
                .preferred_offset = preferred_offset,
                .mode = mode,
                .query = query,
                .content = content,
            };
            self.search_cond.signal();
            return generation;
        }

        pub fn ensureSearchWorker(self: *Editor) void {
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

        pub fn stopSearchWorker(self: *Editor) void {
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

        pub fn cancelPendingSearchWork(self: *Editor) void {
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

        pub fn applyPendingSearchResult(self: *Editor) void {
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

        fn pickSearchActiveIndex(self: *const Editor, preferred_offset: usize) ?usize {
            if (self.search_matches.items.len == 0) return null;
            for (self.search_matches.items, 0..) |match, idx| {
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

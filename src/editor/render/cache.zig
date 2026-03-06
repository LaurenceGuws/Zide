const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const syntax_mod = @import("../syntax.zig");
const draw_list_mod = @import("draw_list.zig");

const HighlightToken = syntax_mod.HighlightToken;
const SyntaxHighlighter = syntax_mod.SyntaxHighlighter;
const TokenKind = syntax_mod.TokenKind;

pub const EditorRenderCache = struct {
    allocator: std.mem.Allocator,
    line_entries: std.AutoHashMap(LineKey, LineEntry),
    highlight_entries: std.AutoHashMap(usize, HighlightEntry),
    wrap_entries: std.AutoHashMap(usize, WrapEntry),
    draw_list: draw_list_mod.EditorDrawList,
    max_entries: usize,
    last_cols: usize,
    last_wrap: bool,
    last_width: i32,
    last_height: i32,
    last_change_tick: u64,
    last_highlight_epoch: u64,
    last_scroll_line: usize,
    last_scroll_row_offset: usize,
    last_scroll_col: usize,
    last_selection_hash: u64,
    last_scroll_hash: u64,
    frame_id: u64,
    highlight_work_start: usize,
    highlight_work_end: usize,
    highlight_work_next: usize,
    highlight_work_epoch: u64,
    highlight_work_active: bool,
    line_width_work_start: usize,
    line_width_work_end: usize,
    line_width_work_next: usize,
    line_width_work_tick: u64,
    line_width_work_active: bool,
    wrap_work_start: usize,
    wrap_work_end: usize,
    wrap_work_next: usize,
    wrap_work_tick: u64,
    wrap_work_cols: usize,
    wrap_work_active: bool,

    pub fn init(allocator: std.mem.Allocator, max_entries: usize) EditorRenderCache {
        return .{
            .allocator = allocator,
            .line_entries = std.AutoHashMap(LineKey, LineEntry).init(allocator),
            .highlight_entries = std.AutoHashMap(usize, HighlightEntry).init(allocator),
            .wrap_entries = std.AutoHashMap(usize, WrapEntry).init(allocator),
            .draw_list = draw_list_mod.EditorDrawList.init(allocator),
            .max_entries = if (max_entries == 0) 1 else max_entries,
            .last_cols = 0,
            .last_wrap = false,
            .last_width = 0,
            .last_height = 0,
            .last_change_tick = 0,
            .last_highlight_epoch = 0,
            .last_scroll_line = 0,
            .last_scroll_row_offset = 0,
            .last_scroll_col = 0,
            .last_selection_hash = 0,
            .last_scroll_hash = 0,
            .frame_id = 0,
            .highlight_work_start = 0,
            .highlight_work_end = 0,
            .highlight_work_next = 0,
            .highlight_work_epoch = 0,
            .highlight_work_active = false,
            .line_width_work_start = 0,
            .line_width_work_end = 0,
            .line_width_work_next = 0,
            .line_width_work_tick = 0,
            .line_width_work_active = false,
            .wrap_work_start = 0,
            .wrap_work_end = 0,
            .wrap_work_next = 0,
            .wrap_work_tick = 0,
            .wrap_work_cols = 0,
            .wrap_work_active = false,
        };
    }

    pub fn deinit(self: *EditorRenderCache) void {
        self.draw_list.deinit();
        self.clearHighlightEntries();
        self.line_entries.deinit();
        self.highlight_entries.deinit();
        self.wrap_entries.deinit();
    }

    pub fn beginFrame(
        self: *EditorRenderCache,
        frame_id: u64,
        cols: usize,
        wrap_enabled: bool,
        width: i32,
        height: i32,
        change_tick: u64,
        highlight_epoch: u64,
        scroll_line: usize,
        scroll_row_offset: usize,
        scroll_col: usize,
        selection_hash: u64,
    ) bool {
        self.frame_id = frame_id;
        const line_cache_dirty = cols != self.last_cols or wrap_enabled != self.last_wrap or width != self.last_width or height != self.last_height or change_tick != self.last_change_tick or scroll_line != self.last_scroll_line or scroll_row_offset != self.last_scroll_row_offset or scroll_col != self.last_scroll_col or selection_hash != self.last_selection_hash;
        const highlight_dirty = highlight_epoch != self.last_highlight_epoch;
        const full_redraw = line_cache_dirty or highlight_dirty;
        if (line_cache_dirty) {
            self.clearLineEntries();
        }
        if (highlight_dirty) {
            self.clearHighlightEntries();
            self.clearHighlightWork();
        }
        if (cols != self.last_cols or wrap_enabled != self.last_wrap or change_tick != self.last_change_tick) {
            self.clearWrapEntries();
            self.clearWrapWork();
        }
        if (change_tick != self.last_change_tick) {
            self.clearLineWidthWork();
        }
        self.last_cols = cols;
        self.last_wrap = wrap_enabled;
        self.last_width = width;
        self.last_height = height;
        self.last_change_tick = change_tick;
        self.last_highlight_epoch = highlight_epoch;
        self.last_scroll_line = scroll_line;
        self.last_scroll_row_offset = scroll_row_offset;
        self.last_scroll_col = scroll_col;
        self.last_selection_hash = selection_hash;
        return full_redraw;
    }

    pub fn invalidateHighlightRange(self: *EditorRenderCache, start_line: usize, end_line: usize) void {
        if (start_line >= end_line) return;
        var line = start_line;
        while (line < end_line) : (line += 1) {
            if (self.highlight_entries.getPtr(line)) |entry| {
                self.allocator.free(entry.tokens);
                _ = self.highlight_entries.remove(line);
            }
        }
        self.clearHighlightWork();
    }

    pub fn segmentDirty(self: *EditorRenderCache, key: LineKey, hash: u64) bool {
        const log = app_logger.logger("editor.render.cache");
        if (self.line_entries.getPtr(key)) |entry| {
            if (entry.hash == hash) {
                entry.last_used = self.frame_id;
                return false;
            }
            entry.hash = hash;
            entry.last_used = self.frame_id;
            return true;
        }
        self.line_entries.put(key, .{ .hash = hash, .last_used = self.frame_id }) catch |err| {
            if (log.enabled_file or log.enabled_console) {
                log.logf(.warning, "line cache insert failed line={d} seg={d} err={s}", .{ key.line_idx, key.seg_idx, @errorName(err) });
            }
        };
        self.maybeEvictLineEntries();
        return true;
    }

    pub fn scrollDirty(self: *EditorRenderCache, hash: u64) bool {
        if (self.last_scroll_hash == hash) return false;
        self.last_scroll_hash = hash;
        return true;
    }

    pub fn highlightTokens(
        self: *EditorRenderCache,
        highlighter: ?*SyntaxHighlighter,
        line_idx: usize,
        line_start: usize,
        line_end: usize,
        line_text_hash: u64,
        highlight_epoch: u64,
    ) []HighlightToken {
        const log = app_logger.logger("editor.render.cache");
        if (highlighter == null) return &[_]HighlightToken{};
        if (self.highlight_entries.getPtr(line_idx)) |entry| {
            if (entry.text_hash == line_text_hash and entry.epoch == highlight_epoch and entry.line_start == line_start) {
                entry.last_used = self.frame_id;
                return entry.tokens;
            }
            self.allocator.free(entry.tokens);
            entry.* = .{
                .text_hash = line_text_hash,
                .line_start = line_start,
                .epoch = highlight_epoch,
                .tokens = highlightLine(highlighter.?, line_start, line_end, self.allocator),
                .last_used = self.frame_id,
            };
            sortTokens(entry.tokens);
            return entry.tokens;
        }

        const tokens = highlightLine(highlighter.?, line_start, line_end, self.allocator);
        sortTokens(tokens);
        self.highlight_entries.put(line_idx, .{
            .text_hash = line_text_hash,
            .line_start = line_start,
            .epoch = highlight_epoch,
            .tokens = tokens,
            .last_used = self.frame_id,
        }) catch |err| {
            if (log.enabled_file or log.enabled_console) {
                log.logf(.warning, "highlight cache insert failed line={d} err={s}", .{ line_idx, @errorName(err) });
            }
        };
        self.maybeEvictHighlightEntries();
        return tokens;
    }

    pub fn tryHighlightTokens(
        self: *EditorRenderCache,
        line_idx: usize,
        line_start: usize,
        line_text_hash: u64,
        highlight_epoch: u64,
    ) []HighlightToken {
        if (self.highlight_entries.getPtr(line_idx)) |entry| {
            if (entry.text_hash == line_text_hash and entry.epoch == highlight_epoch and entry.line_start == line_start) {
                entry.last_used = self.frame_id;
                return entry.tokens;
            }
            self.allocator.free(entry.tokens);
            _ = self.highlight_entries.remove(line_idx);
        }
        return &[_]HighlightToken{};
    }

    pub fn clear(self: *EditorRenderCache) void {
        self.clearLineEntries();
        self.clearHighlightEntries();
        self.clearHighlightWork();
        self.clearLineWidthWork();
        self.clearWrapEntries();
        self.clearWrapWork();
    }

    fn clearLineEntries(self: *EditorRenderCache) void {
        self.line_entries.clearRetainingCapacity();
    }

    fn clearHighlightEntries(self: *EditorRenderCache) void {
        var it = self.highlight_entries.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.value_ptr.tokens);
        }
        self.highlight_entries.clearRetainingCapacity();
    }

    pub fn wrapLineCount(self: *EditorRenderCache, line_idx: usize, cols: usize, line_width: usize) ?usize {
        if (self.wrap_entries.getPtr(line_idx)) |entry| {
            if (entry.cols == cols and entry.line_width == line_width) {
                entry.last_used = self.frame_id;
                return entry.count;
            }
            _ = self.wrap_entries.remove(line_idx);
        }
        return null;
    }

    pub fn setWrapLineCount(self: *EditorRenderCache, line_idx: usize, cols: usize, line_width: usize, count: usize) void {
        const log = app_logger.logger("editor.render.cache");
        if (self.wrap_entries.getPtr(line_idx)) |entry| {
            entry.* = .{
                .cols = cols,
                .line_width = line_width,
                .count = count,
                .last_used = self.frame_id,
            };
            return;
        }
        self.wrap_entries.put(line_idx, .{
            .cols = cols,
            .line_width = line_width,
            .count = count,
            .last_used = self.frame_id,
        }) catch |err| {
            if (log.enabled_file or log.enabled_console) {
                log.logf(.warning, "wrap cache insert failed line={d} cols={d} err={s}", .{ line_idx, cols, @errorName(err) });
            }
        };
        self.maybeEvictWrapEntries();
    }

    pub fn beginHighlightWork(self: *EditorRenderCache, start_line: usize, end_line: usize, epoch: u64) void {
        if (end_line <= start_line) {
            self.highlight_work_active = false;
            return;
        }
        const range_changed = !self.highlight_work_active or start_line != self.highlight_work_start or end_line != self.highlight_work_end or epoch != self.highlight_work_epoch;
        if (range_changed) {
            self.highlight_work_start = start_line;
            self.highlight_work_end = end_line;
            self.highlight_work_next = start_line;
            self.highlight_work_epoch = epoch;
            self.highlight_work_active = true;
        }
    }

    pub fn nextHighlightWorkLine(self: *EditorRenderCache) ?usize {
        if (!self.highlight_work_active) return null;
        if (self.highlight_work_next >= self.highlight_work_end) {
            self.highlight_work_active = false;
            return null;
        }
        const line = self.highlight_work_next;
        self.highlight_work_next += 1;
        return line;
    }

    fn clearHighlightWork(self: *EditorRenderCache) void {
        self.highlight_work_active = false;
        self.highlight_work_start = 0;
        self.highlight_work_end = 0;
        self.highlight_work_next = 0;
        self.highlight_work_epoch = 0;
    }

    pub fn beginLineWidthWork(self: *EditorRenderCache, start_line: usize, end_line: usize, change_tick: u64) void {
        if (end_line <= start_line) {
            self.line_width_work_active = false;
            return;
        }
        const range_changed = !self.line_width_work_active or start_line != self.line_width_work_start or end_line != self.line_width_work_end or change_tick != self.line_width_work_tick;
        if (range_changed) {
            self.line_width_work_start = start_line;
            self.line_width_work_end = end_line;
            self.line_width_work_next = start_line;
            self.line_width_work_tick = change_tick;
            self.line_width_work_active = true;
        }
    }

    pub fn nextLineWidthWorkLine(self: *EditorRenderCache) ?usize {
        if (!self.line_width_work_active) return null;
        if (self.line_width_work_next >= self.line_width_work_end) {
            self.line_width_work_active = false;
            return null;
        }
        const line = self.line_width_work_next;
        self.line_width_work_next += 1;
        return line;
    }

    fn clearLineWidthWork(self: *EditorRenderCache) void {
        self.line_width_work_active = false;
        self.line_width_work_start = 0;
        self.line_width_work_end = 0;
        self.line_width_work_next = 0;
        self.line_width_work_tick = 0;
    }

    pub fn beginWrapWork(self: *EditorRenderCache, start_line: usize, end_line: usize, cols: usize, change_tick: u64) void {
        if (end_line <= start_line) {
            self.wrap_work_active = false;
            return;
        }
        const range_changed = !self.wrap_work_active or start_line != self.wrap_work_start or end_line != self.wrap_work_end or cols != self.wrap_work_cols or change_tick != self.wrap_work_tick;
        if (range_changed) {
            self.wrap_work_start = start_line;
            self.wrap_work_end = end_line;
            self.wrap_work_next = start_line;
            self.wrap_work_tick = change_tick;
            self.wrap_work_cols = cols;
            self.wrap_work_active = true;
        }
    }

    pub fn nextWrapWorkLine(self: *EditorRenderCache) ?usize {
        if (!self.wrap_work_active) return null;
        if (self.wrap_work_next >= self.wrap_work_end) {
            self.wrap_work_active = false;
            return null;
        }
        const line = self.wrap_work_next;
        self.wrap_work_next += 1;
        return line;
    }

    fn clearWrapEntries(self: *EditorRenderCache) void {
        self.wrap_entries.clearRetainingCapacity();
    }

    fn maybeEvictLineEntries(self: *EditorRenderCache) void {
        if (self.line_entries.count() <= self.max_entries) return;
        const target = @max(self.max_entries, 1);
        var evicted: usize = 0;
        var it = self.line_entries.iterator();
        while (it.next()) |entry| {
            if (self.frame_id - entry.value_ptr.last_used <= 1) continue;
            _ = self.line_entries.remove(entry.key_ptr.*);
            evicted += 1;
            if (self.line_entries.count() <= target) break;
        }
        if (evicted == 0) {
            self.clearLineEntries();
        }
    }

    fn maybeEvictHighlightEntries(self: *EditorRenderCache) void {
        if (self.highlight_entries.count() <= self.max_entries) return;
        const target = @max(self.max_entries, 1);
        var evicted: usize = 0;
        var it = self.highlight_entries.iterator();
        while (it.next()) |entry| {
            if (self.frame_id - entry.value_ptr.last_used <= 1) continue;
            self.allocator.free(entry.value_ptr.tokens);
            _ = self.highlight_entries.remove(entry.key_ptr.*);
            evicted += 1;
            if (self.highlight_entries.count() <= target) break;
        }
        if (evicted == 0) {
            self.clearHighlightEntries();
        }
    }

    fn maybeEvictWrapEntries(self: *EditorRenderCache) void {
        if (self.wrap_entries.count() <= self.max_entries) return;
        const target = @max(self.max_entries, 1);
        var evicted: usize = 0;
        var it = self.wrap_entries.iterator();
        while (it.next()) |entry| {
            if (self.frame_id - entry.value_ptr.last_used <= 1) continue;
            _ = self.wrap_entries.remove(entry.key_ptr.*);
            evicted += 1;
            if (self.wrap_entries.count() <= target) break;
        }
        if (evicted == 0) {
            self.clearWrapEntries();
        }
    }

    fn clearWrapWork(self: *EditorRenderCache) void {
        self.wrap_work_active = false;
        self.wrap_work_start = 0;
        self.wrap_work_end = 0;
        self.wrap_work_next = 0;
        self.wrap_work_tick = 0;
        self.wrap_work_cols = 0;
    }
};

const LineKey = struct {
    line_idx: usize,
    seg_idx: usize,
};

const LineEntry = struct {
    hash: u64,
    last_used: u64,
};

const HighlightEntry = struct {
    text_hash: u64,
    line_start: usize,
    epoch: u64,
    tokens: []HighlightToken,
    last_used: u64,
};

const WrapEntry = struct {
    cols: usize,
    line_width: usize,
    count: usize,
    last_used: u64,
};

fn highlightLine(
    highlighter: *SyntaxHighlighter,
    start: usize,
    end: usize,
    allocator: std.mem.Allocator,
) []HighlightToken {
    return highlighter.highlightRange(start, end, allocator) catch allocator.alloc(HighlightToken, 0) catch &[_]HighlightToken{};
}

fn sortTokens(tokens: []HighlightToken) void {
    if (tokens.len <= 1) return;
    std.sort.heap(HighlightToken, tokens, {}, struct {
        fn lessThan(_: void, a: HighlightToken, b: HighlightToken) bool {
            return syntax_mod.highlightTokenLessThanStable(a, b);
        }
    }.lessThan);
}

test "sortTokens uses stable highlight ordering" {
    const allocator = std.testing.allocator;
    const tokens = [_]HighlightToken{
        .{ .start = 0, .end = 4, .kind = .link, .priority = 10, .conceal = null, .url = "https://zide.dev", .conceal_lines = false },
        .{ .start = 0, .end = 4, .kind = .link, .priority = 10, .conceal = null, .url = "https://a.dev", .conceal_lines = false },
        .{ .start = 0, .end = 4, .kind = .string, .priority = 10, .conceal = null, .url = null, .conceal_lines = false },
        .{ .start = 0, .end = 4, .kind = .link, .priority = 10, .conceal = "*", .url = null, .conceal_lines = false },
    };
    const owned = try allocator.dupe(HighlightToken, &tokens);
    defer allocator.free(owned);

    sortTokens(owned);

    try std.testing.expectEqual(TokenKind.string, owned[0].kind);
    try std.testing.expectEqualStrings("https://a.dev", owned[1].url.?);
    try std.testing.expectEqualStrings("https://zide.dev", owned[2].url.?);
    try std.testing.expectEqualStrings("*", owned[3].conceal.?);
}

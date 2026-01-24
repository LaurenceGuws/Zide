const std = @import("std");
const syntax_mod = @import("../syntax.zig");

const HighlightToken = syntax_mod.HighlightToken;
const SyntaxHighlighter = syntax_mod.SyntaxHighlighter;

pub const EditorRenderCache = struct {
    allocator: std.mem.Allocator,
    line_entries: std.AutoHashMap(LineKey, LineEntry),
    highlight_entries: std.AutoHashMap(usize, HighlightEntry),
    max_entries: usize,
    last_cols: usize,
    last_wrap: bool,
    last_width: i32,
    last_height: i32,
    last_change_tick: u64,
    last_scroll_line: usize,
    last_scroll_row_offset: usize,
    last_scroll_col: usize,
    last_scroll_hash: u64,
    frame_id: u64,

    pub fn init(allocator: std.mem.Allocator, max_entries: usize) EditorRenderCache {
        return .{
            .allocator = allocator,
            .line_entries = std.AutoHashMap(LineKey, LineEntry).init(allocator),
            .highlight_entries = std.AutoHashMap(usize, HighlightEntry).init(allocator),
            .max_entries = if (max_entries == 0) 1 else max_entries,
            .last_cols = 0,
            .last_wrap = false,
            .last_width = 0,
            .last_height = 0,
            .last_change_tick = 0,
            .last_scroll_line = 0,
            .last_scroll_row_offset = 0,
            .last_scroll_col = 0,
            .last_scroll_hash = 0,
            .frame_id = 0,
        };
    }

    pub fn deinit(self: *EditorRenderCache) void {
        self.clearHighlightEntries();
        self.line_entries.deinit();
        self.highlight_entries.deinit();
    }

    pub fn beginFrame(
        self: *EditorRenderCache,
        frame_id: u64,
        cols: usize,
        wrap_enabled: bool,
        width: i32,
        height: i32,
        change_tick: u64,
        scroll_line: usize,
        scroll_row_offset: usize,
        scroll_col: usize,
    ) bool {
        self.frame_id = frame_id;
        const full_redraw = cols != self.last_cols or wrap_enabled != self.last_wrap or width != self.last_width or height != self.last_height or change_tick != self.last_change_tick or scroll_line != self.last_scroll_line or scroll_row_offset != self.last_scroll_row_offset or scroll_col != self.last_scroll_col;
        if (full_redraw) {
            self.clear();
        }
        self.last_cols = cols;
        self.last_wrap = wrap_enabled;
        self.last_width = width;
        self.last_height = height;
        self.last_change_tick = change_tick;
        self.last_scroll_line = scroll_line;
        self.last_scroll_row_offset = scroll_row_offset;
        self.last_scroll_col = scroll_col;
        return full_redraw;
    }

    pub fn segmentDirty(self: *EditorRenderCache, key: LineKey, hash: u64) bool {
        if (self.line_entries.getPtr(key)) |entry| {
            if (entry.hash == hash) {
                entry.last_used = self.frame_id;
                return false;
            }
            entry.hash = hash;
            entry.last_used = self.frame_id;
            return true;
        }
        _ = self.line_entries.put(key, .{ .hash = hash, .last_used = self.frame_id }) catch {};
        if (self.line_entries.count() > self.max_entries) {
            self.clearLineEntries();
        }
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
        if (highlighter == null) return &[_]HighlightToken{};
        if (self.highlight_entries.getPtr(line_idx)) |entry| {
            if (entry.text_hash == line_text_hash and entry.epoch == highlight_epoch) {
                entry.last_used = self.frame_id;
                return entry.tokens;
            }
            self.allocator.free(entry.tokens);
            entry.* = .{
                .text_hash = line_text_hash,
                .epoch = highlight_epoch,
                .tokens = highlightLine(highlighter.?, line_start, line_end, self.allocator),
                .last_used = self.frame_id,
            };
            return entry.tokens;
        }

        const tokens = highlightLine(highlighter.?, line_start, line_end, self.allocator);
        _ = self.highlight_entries.put(line_idx, .{
            .text_hash = line_text_hash,
            .epoch = highlight_epoch,
            .tokens = tokens,
            .last_used = self.frame_id,
        }) catch {};
        if (self.highlight_entries.count() > self.max_entries) {
            self.clearHighlightEntries();
        }
        return tokens;
    }

    pub fn clear(self: *EditorRenderCache) void {
        self.clearLineEntries();
        self.clearHighlightEntries();
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
    epoch: u64,
    tokens: []HighlightToken,
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

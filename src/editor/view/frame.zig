const editor_mod = @import("../editor.zig");
const syntax_mod = @import("../syntax.zig");
const types = @import("../types.zig");

const Editor = editor_mod.Editor;
const CursorPos = types.CursorPos;
const Selection = types.Selection;
const SyntaxHighlighter = syntax_mod.SyntaxHighlighter;

pub const EditorFrameView = struct {
    editor: *Editor,
    wrap_enabled: bool,
    cursor: CursorPos,
    selection: ?Selection,
    selections: []const Selection,
    scroll_line: usize,
    scroll_row_offset: usize,
    scroll_col: usize,
    change_tick: u64,
    highlight_epoch: u64,
    search_epoch: u64,
    highlighter: ?*SyntaxHighlighter,
    search_matches: []const Editor.SearchMatch,
    search_active_match: ?Editor.SearchMatch,

    pub fn init(editor: *Editor, wrap_enabled: bool) EditorFrameView {
        return .{
            .editor = editor,
            .wrap_enabled = wrap_enabled,
            .cursor = editor.cursor,
            .selection = editor.selection,
            .selections = editor.selections.items,
            .scroll_line = editor.scroll_line,
            .scroll_row_offset = editor.scroll_row_offset,
            .scroll_col = editor.scroll_col,
            .change_tick = editor.change_tick,
            .highlight_epoch = editor.highlight_epoch,
            .search_epoch = editor.search_epoch,
            .highlighter = editor.highlighter,
            .search_matches = editor.searchMatches(),
            .search_active_match = editor.searchActiveMatch(),
        };
    }

    pub fn lineCount(self: *const EditorFrameView) usize {
        return self.editor.lineCount();
    }

    pub fn totalLen(self: *const EditorFrameView) usize {
        return self.editor.totalLen();
    }

    pub fn lineStart(self: *const EditorFrameView, line_idx: usize) usize {
        return self.editor.lineStart(line_idx);
    }

    pub fn lineLen(self: *const EditorFrameView, line_idx: usize) usize {
        return self.editor.lineLen(line_idx);
    }

    pub fn getLine(self: *const EditorFrameView, line_idx: usize, buf: []u8) usize {
        return self.editor.getLine(line_idx, buf);
    }

    pub fn getLineAlloc(self: *const EditorFrameView, line_idx: usize) ![]u8 {
        return self.editor.getLineAlloc(line_idx);
    }

    pub fn lineWidthCached(self: *const EditorFrameView, line_idx: usize, line_text: []const u8, cluster_offsets: ?[]const u32) usize {
        return self.editor.lineWidthCached(line_idx, line_text, cluster_offsets);
    }

    pub fn maxLineWidthCached(self: *const EditorFrameView) usize {
        return self.editor.maxLineWidthCached();
    }

    pub fn searchMatches(self: *const EditorFrameView) []const Editor.SearchMatch {
        return self.search_matches;
    }

    pub fn searchActiveMatch(self: *const EditorFrameView) ?Editor.SearchMatch {
        return self.search_active_match;
    }

    pub fn selectionStateHash(self: *const EditorFrameView) u64 {
        var h: u64 = 1469598103934665603;
        h ^= @as(u64, self.cursor.offset);
        h *%= 1099511628211;
        if (self.selection) |sel| {
            h ^= @as(u64, sel.start.offset);
            h *%= 1099511628211;
            h ^= @as(u64, sel.end.offset);
            h *%= 1099511628211;
        }
        h ^= @as(u64, self.selections.len);
        h *%= 1099511628211;
        for (self.selections) |sel| {
            h ^= @as(u64, sel.start.offset);
            h *%= 1099511628211;
            h ^= @as(u64, sel.end.offset);
            h *%= 1099511628211;
        }
        h ^= self.search_epoch;
        h *%= 1099511628211;
        return h;
    }
};

const builtin = @import("builtin");
const parser_mod = @import("../parser/parser.zig");
const selection_mod = @import("selection.zig");
const types = @import("../model/types.zig");

pub fn debugSnapshot(self: anytype) @import("snapshot.zig").DebugSnapshot {
    if (!debugAccessAllowed()) @panic("debugSnapshot is test-only");
    return .{
        .title = self.core.title,
        .cwd = self.core.cwd,
        .osc_clipboard = self.core.osc_clipboard.items,
        .osc_clipboard_pending = self.core.osc_clipboard_pending,
        .hyperlinks = self.core.hyperlink_table.items,
        .scrollback_count = self.core.history.scrollbackCount(),
        .scrollback_offset = self.core.history.scrollOffset(),
        .focus_reporting = self.focus_reporting,
        .selection = selection_mod.selectionState(self),
        .base_default_attrs = self.core.base_default_attrs,
        .render_cache = self.renderCache(),
    };
}

pub fn debugScrollbackRow(self: anytype, index: usize) ?[]const @import("../model/types.zig").Cell {
    if (!debugAccessAllowed()) @panic("debugScrollbackRow is test-only");
    return self.core.history.scrollbackRow(index);
}

pub fn debugSetCursor(self: anytype, row: usize, col: usize) void {
    if (!debugAccessAllowed()) @panic("debugSetCursor is test-only");
    self.activeScreen().setCursor(row, col);
}

pub fn debugFeedBytes(self: anytype, bytes: []const u8) void {
    if (!debugAccessAllowed()) @panic("debugFeedBytes is test-only");
    self.core.parser.handleSlice(parser_mod.Parser.SessionFacade.from(self), bytes);
}

pub fn debugScrollUp(self: anytype) void {
    if (!debugAccessAllowed()) @panic("debugScrollUp is test-only");
    @import("scrolling.zig").scrollUp(self);
    _ = self.output_generation.fetchAdd(1, .acq_rel);
    @import("view_cache.zig").updateViewCacheNoLockTagged(self, self.output_generation.load(.acquire), self.core.history.scrollOffset(), "debug_push_output");
}

pub fn debugSetScrollOffset(self: anytype, offset: usize) void {
    if (!debugAccessAllowed()) @panic("debugSetScrollOffset is test-only");
    self.core.history.ensureViewCache(self.core.primary.grid.cols, self.core.primary.defaultCell());
    const before = self.core.history.scrollOffset();
    self.core.history.setScrollOffset(self.core.primary.grid.rows, offset);
    const after = self.core.history.scrollOffset();
    if (after != before) {
        _ = self.output_generation.fetchAdd(1, .acq_rel);
    }
    self.view_cache_request_offset.store(@intCast(self.core.history.scrollOffset()), .release);
    self.view_cache_pending.store(false, .release);
    @import("view_cache.zig").updateViewCacheNoLockTagged(self, self.output_generation.load(.acquire), self.core.history.scrollOffset(), "debug_apply_without_pending");
}

pub fn debugSetScrollbackCell(self: anytype, row: usize, col: usize, codepoint: u32) void {
    if (!debugAccessAllowed()) @panic("debugSetScrollbackCell is test-only");
    const line = self.core.history.scrollback.lineByIndexMut(row) orelse return;
    if (col >= line.cells.len) return;
    line.cells[col].codepoint = codepoint;
    self.core.history.markScrollbackChanged();
    _ = self.output_generation.fetchAdd(1, .acq_rel);
    @import("view_cache.zig").updateViewCacheNoLockTagged(self, self.output_generation.load(.acquire), self.core.history.scrollOffset(), "debug_scrollback_row");
}

pub fn debugPushScrollbackRow(self: anytype, text: []const u8) void {
    if (!debugAccessAllowed()) @panic("debugPushScrollbackRow is test-only");
    const cols = self.core.primary.grid.cols;
    if (cols == 0) return;
    const base = self.core.primary.defaultCell();
    var row = self.allocator.alloc(types.Cell, cols) catch return;
    defer self.allocator.free(row);
    for (row) |*cell| cell.* = base;
    const limit = @min(text.len, cols);
    var i: usize = 0;
    while (i < limit) : (i += 1) {
        row[i].codepoint = text[i];
    }
    self.core.history.pushRow(row, false, base);
    self.core.history.ensureViewCache(cols, base);
    _ = self.output_generation.fetchAdd(1, .acq_rel);
    @import("view_cache.zig").updateViewCacheNoLockTagged(self, self.output_generation.load(.acquire), self.core.history.scrollOffset(), "debug_grid_row");
}

pub fn debugSetGridRow(self: anytype, row_index: usize, text: []const u8) void {
    if (!debugAccessAllowed()) @panic("debugSetGridRow is test-only");
    const cols = self.core.primary.grid.cols;
    const rows = self.core.primary.grid.rows;
    if (row_index >= rows or cols == 0) return;
    const base = self.core.primary.defaultCell();
    const start = row_index * cols;
    for (self.core.primary.grid.cells.items[start .. start + cols]) |*cell| cell.* = base;
    const limit = @min(text.len, cols);
    var i: usize = 0;
    while (i < limit) : (i += 1) {
        self.core.primary.grid.cells.items[start + i].codepoint = text[i];
    }
    self.core.primary.grid.markDirtyRange(row_index, row_index, 0, cols - 1);
    _ = self.output_generation.fetchAdd(1, .acq_rel);
    @import("view_cache.zig").updateViewCacheNoLockTagged(self, self.output_generation.load(.acquire), self.core.history.scrollOffset(), "debug_cursor");
}

fn debugAccessAllowed() bool {
    if (builtin.is_test) return true;
    const root = @import("root");
    return @hasDecl(root, "terminal_replay_enabled") and root.terminal_replay_enabled;
}

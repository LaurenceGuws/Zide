const std = @import("std");
const builtin = @import("builtin");
const parser_mod = @import("../../parser/parser.zig");
const selection_mod = @import("../selection.zig");
const types = @import("../../model/types.zig");
const terminal_publication = @import("../publication/terminal_publication.zig");
const kitty_mod = @import("../../kitty/graphics.zig");

pub fn debugSnapshot(self: anytype) @import("../publication/snapshot.zig").DebugSnapshot {
    if (!debugAccessAllowed()) @panic("debugSnapshot is test-only");
    return .{
        .title = self.core.title,
        .cwd = self.core.cwd,
        .osc_clipboard = self.core.osc_clipboard.items,
        .osc_clipboard_pending = self.core.osc_clipboard_pending,
        .hyperlinks = self.core.hyperlink_table.items,
        .scrollback_count = self.core.history.scrollbackCount(),
        .scrollback_offset = self.core.history.scrollOffset(),
        .focus_reporting = self.interaction.focus_reporting,
        .selection = selection_mod.selectionState(self),
        .base_default_attrs = self.core.base_default_attrs,
        .render_cache = terminal_publication.renderCache(self),
    };
}

pub fn debugScrollbackRow(self: anytype, index: usize) ?[]const @import("../../model/types.zig").Cell {
    if (!debugAccessAllowed()) @panic("debugScrollbackRow is test-only");
    return self.core.history.scrollbackRow(index);
}

pub fn debugSetCursor(self: anytype, row: usize, col: usize) void {
    if (!debugAccessAllowed()) @panic("debugSetCursor is test-only");
    self.core.activeScreen().setCursor(row, col);
}

pub fn debugFeedBytes(self: anytype, bytes: []const u8) void {
    if (!debugAccessAllowed()) @panic("debugFeedBytes is test-only");
    self.core.parser.handleSlice(self, bytes);
}

pub fn debugScrollUp(self: anytype) void {
    if (!debugAccessAllowed()) @panic("debugScrollUp is test-only");
    @import("../scrolling.zig").scrollUp(self);
    _ = terminal_publication.bumpAndPublishCurrentViewLocked(self, "debug_push_output");
}

pub fn debugSetScrollOffset(self: anytype, offset: usize) void {
    if (!debugAccessAllowed()) @panic("debugSetScrollOffset is test-only");
    self.core.history.ensureViewCache(self.core.primary.grid.cols, self.core.primary.defaultCell());
    const before = self.core.history.scrollOffset();
    self.core.history.setScrollOffset(self.core.primary.grid.rows, offset);
    const after = self.core.history.scrollOffset();
    if (after != before) {
        _ = terminal_publication.bumpGeneration(self);
    }
    terminal_publication.replacePendingRefreshWithCurrentViewLocked(self, "debug_apply_without_pending");
}

pub fn debugSetScrollbackCell(self: anytype, row: usize, col: usize, codepoint: u32) void {
    if (!debugAccessAllowed()) @panic("debugSetScrollbackCell is test-only");
    const line = self.core.history.scrollback.lineByIndexMut(row) orelse return;
    if (col >= line.cells.len) return;
    line.cells[col].codepoint = codepoint;
    self.core.history.markScrollbackChanged();
    _ = terminal_publication.bumpAndPublishCurrentViewLocked(self, "debug_scrollback_row");
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
    _ = terminal_publication.bumpAndPublishCurrentViewLocked(self, "debug_grid_row");
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
    _ = terminal_publication.bumpAndPublishCurrentViewLocked(self, "debug_cursor");
}

pub const KittyStateSelector = enum {
    primary,
    alt,
};

pub const KittyStateCounts = struct {
    images: usize,
    placements: usize,
    total_bytes: usize,
};

pub fn debugSeedOsc5522Clipboard(
    self: anytype,
    text: ?[]const u8,
    html: ?[]const u8,
    uri_list: ?[]const u8,
    png: ?[]const u8,
) !void {
    if (!debugAccessAllowed()) @panic("debugSeedOsc5522Clipboard is test-only");
    try replaceOwnedBytes(self, &self.core.kitty_osc5522_clipboard_text, text);
    try replaceOwnedBytes(self, &self.core.kitty_osc5522_clipboard_html, html);
    try replaceOwnedBytes(self, &self.core.kitty_osc5522_clipboard_uri_list, uri_list);
    try replaceOwnedBytes(self, &self.core.kitty_osc5522_clipboard_png, png);
}

pub fn debugSeedKittyState(
    self: anytype,
    which: KittyStateSelector,
    image: kitty_mod.KittyImage,
    placement: kitty_mod.KittyPlacement,
) !void {
    if (!debugAccessAllowed()) @panic("debugSeedKittyState is test-only");
    const state = switch (which) {
        .primary => &self.core.kitty_primary,
        .alt => &self.core.kitty_alt,
    };
    try state.images.append(self.allocator, image);
    try state.placements.append(self.allocator, placement);
    state.total_bytes = image.data.len;
}

pub fn debugKittyStateCounts(self: anytype, which: KittyStateSelector) KittyStateCounts {
    if (!debugAccessAllowed()) @panic("debugKittyStateCounts is test-only");
    const state = switch (which) {
        .primary => &self.core.kitty_primary,
        .alt => &self.core.kitty_alt,
    };
    return .{
        .images = state.images.items.len,
        .placements = state.placements.items.len,
        .total_bytes = state.total_bytes,
    };
}

fn replaceOwnedBytes(self: anytype, list: *std.ArrayList(u8), value: ?[]const u8) !void {
    list.clearRetainingCapacity();
    if (value) |bytes| {
        try list.ensureTotalCapacity(self.allocator, bytes.len);
        try list.appendSlice(self.allocator, bytes);
    }
}

fn debugAccessAllowed() bool {
    if (builtin.is_test) return true;
    const root = @import("root");
    return @hasDecl(root, "terminal_replay_enabled") and root.terminal_replay_enabled;
}

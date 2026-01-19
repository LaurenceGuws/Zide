const std = @import("std");
const scrollback_mod = @import("scrollback.zig");
const types = @import("types.zig");

const Scrollback = scrollback_mod.Scrollback(types.Cell);

pub const TerminalHistory = struct {
    allocator: std.mem.Allocator,
    scrollback: Scrollback,
    scrollback_offset: usize,
    saved_scrollback_offset: usize,
    selection: types.TerminalSelection,

    pub fn init(allocator: std.mem.Allocator, max_rows: usize, cols: u16) !TerminalHistory {
        const scrollback = try Scrollback.init(allocator, max_rows, cols);
        return .{
            .allocator = allocator,
            .scrollback = scrollback,
            .scrollback_offset = 0,
            .saved_scrollback_offset = 0,
            .selection = .{
                .active = false,
                .selecting = false,
                .start = .{ .row = 0, .col = 0 },
                .end = .{ .row = 0, .col = 0 },
            },
        };
    }

    pub fn deinit(self: *TerminalHistory) void {
        self.scrollback.deinit();
    }

    pub fn resizePreserve(self: *TerminalHistory, cols: u16, default_cell: types.Cell) !void {
        try self.scrollback.resizePreserve(cols, default_cell);
    }

    pub fn updateDefaultColors(
        self: *TerminalHistory,
        old_fg: types.Color,
        old_bg: types.Color,
        new_fg: types.Color,
        new_bg: types.Color,
    ) void {
        for (self.scrollback.rows.items) |*cell| {
            if (cell.attrs.fg.r == old_fg.r and
                cell.attrs.fg.g == old_fg.g and
                cell.attrs.fg.b == old_fg.b and
                cell.attrs.fg.a == old_fg.a and
                cell.attrs.bg.r == old_bg.r and
                cell.attrs.bg.g == old_bg.g and
                cell.attrs.bg.b == old_bg.b and
                cell.attrs.bg.a == old_bg.a)
            {
                cell.attrs.fg = new_fg;
                cell.attrs.bg = new_bg;
            }
        }
    }

    pub fn pushRow(self: *TerminalHistory, row: []const types.Cell) void {
        self.scrollback.pushRow(row);
    }

    pub fn scrollbackCount(self: *TerminalHistory) usize {
        return self.scrollback.count();
    }

    pub fn scrollbackRow(self: *TerminalHistory, index: usize) ?[]const types.Cell {
        return self.scrollback.rowSlice(index);
    }

    pub fn scrollOffset(self: *TerminalHistory) usize {
        return self.scrollback_offset;
    }

    pub fn maxScrollOffset(self: *TerminalHistory, rows: u16) usize {
        const visible = @as(usize, rows);
        const total = self.scrollback.count() + visible;
        if (total <= visible) return 0;
        return total - visible;
    }

    pub fn setScrollOffset(self: *TerminalHistory, rows: u16, offset: usize) void {
        if (rows == 0) {
            self.scrollback_offset = 0;
            return;
        }
        const max_offset = self.maxScrollOffset(rows);
        self.scrollback_offset = @min(offset, max_offset);
    }

    pub fn scrollBy(self: *TerminalHistory, rows: u16, delta: isize) void {
        if (rows == 0) return;
        const max_offset = self.maxScrollOffset(rows);
        var offset: isize = @intCast(self.scrollback_offset);
        offset += delta;
        if (offset < 0) offset = 0;
        if (offset > @as(isize, @intCast(max_offset))) offset = @intCast(max_offset);
        self.scrollback_offset = @intCast(offset);
    }

    pub fn saveScrollOffset(self: *TerminalHistory) void {
        self.saved_scrollback_offset = self.scrollback_offset;
        self.scrollback_offset = 0;
    }

    pub fn restoreScrollOffset(self: *TerminalHistory, rows: u16) void {
        self.setScrollOffset(rows, self.saved_scrollback_offset);
    }

    pub fn clearSelection(self: *TerminalHistory) void {
        self.selection.active = false;
        self.selection.selecting = false;
    }

    pub fn startSelection(self: *TerminalHistory, row: usize, col: usize) void {
        self.selection.active = true;
        self.selection.selecting = true;
        self.selection.start = .{ .row = row, .col = col };
        self.selection.end = .{ .row = row, .col = col };
    }

    pub fn updateSelection(self: *TerminalHistory, row: usize, col: usize) void {
        if (!self.selection.active) return;
        self.selection.end = .{ .row = row, .col = col };
    }

    pub fn finishSelection(self: *TerminalHistory) void {
        if (!self.selection.active) return;
        self.selection.selecting = false;
    }

    pub fn selectionState(self: *TerminalHistory) ?types.TerminalSelection {
        if (!self.selection.active) return null;
        return self.selection;
    }
};

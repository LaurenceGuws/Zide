const builtin = @import("builtin");
const parser_mod = @import("../parser/parser.zig");
const selection_mod = @import("selection.zig");

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

fn debugAccessAllowed() bool {
    if (builtin.is_test) return true;
    const root = @import("root");
    return @hasDecl(root, "terminal_replay_enabled") and root.terminal_replay_enabled;
}

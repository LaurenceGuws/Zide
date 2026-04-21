const std = @import("std");

const host_queries = @import("../../terminal/core/session/host_queries.zig");
const scrollback_view = @import("../../terminal/core/scrollback_view.zig");
const session_input = @import("../../terminal/core/session/input.zig");
const session_interaction = @import("../../terminal/core/session/interaction.zig");
const terminal_runtime = @import("../../terminal/core/terminal_runtime.zig");
const terminal_selection = @import("../../terminal/core/selection.zig");
const key_encoder = @import("../../terminal/input/key_encoder.zig");
const input_mod = @import("../../terminal/input/input.zig");
const terminal_types = @import("../../terminal/model/types.zig");

const TerminalRuntimeShell = terminal_runtime.TerminalRuntimeShell;
const SelectionGesture = terminal_selection.SelectionGesture;
const ClickSelectionResult = terminal_selection.ClickSelectionResult;

pub const TerminalInputAdapter = struct {
    session: *TerminalRuntimeShell,

    const Self = @This();

    pub fn init(session: *TerminalRuntimeShell) Self {
        return .{ .session = session };
    }

    pub fn allocator(self: *const Self) std.mem.Allocator {
        return self.session.allocator;
    }

    pub fn mouseReportingEnabled(self: *const Self) bool {
        return session_interaction.mouseReportingEnabled(self.session);
    }

    pub fn keyModeFlags(self: *const Self) u32 {
        return session_interaction.keyModeFlagsValue(self.session);
    }

    pub fn autoRepeatEnabled(self: *const Self) bool {
        return session_interaction.autoRepeatEnabled(self.session);
    }

    pub fn copyCwdText(self: *const Self, alloc: std.mem.Allocator, cwd_out: *std.ArrayList(u8)) ![]const u8 {
        return host_queries.copyCwdText(self.session, alloc, cwd_out);
    }

    pub fn copyHyperlinkUri(self: *const Self, alloc: std.mem.Allocator, out: *std.ArrayList(u8), link_id: u32) !?[]const u8 {
        return host_queries.copyHyperlinkUri(self.session, alloc, out, link_id);
    }

    pub fn takeOscClipboardCopy(self: *const Self, alloc: std.mem.Allocator, out: *std.ArrayList(u8)) !bool {
        if (!self.session.tryLock()) return false;
        defer self.session.unlock();
        return self.session.core.takeOscClipboardCopy(alloc, out);
    }

    pub fn sendCharActionWithMetadata(self: *const Self, ch: u32, mod: terminal_types.Modifier, action: input_mod.KeyAction, meta: terminal_types.KeyboardAlternateMetadata) !void {
        try session_input.sendCharActionWithMetadata(self.session, ch, mod, action, meta);
    }

    pub fn sendKeyAction(self: *const Self, key: anytype, key_mod: terminal_types.Modifier, action: anytype) !bool {
        return key_encoder.sendKeyAction(self.session, key, key_mod, action);
    }

    pub fn sendCharForKey(self: *const Self, key: anytype, key_mod: terminal_types.Modifier, action: anytype, ctrl: bool, alt: bool) !bool {
        return key_encoder.sendCharForKey(self.session, key, key_mod, action, ctrl, alt);
    }

    pub fn resetToLiveBottom(self: *const Self) bool {
        self.session.lock();
        defer self.session.unlock();
        return scrollback_view.resetToLiveBottomLocked(self.session);
    }

    pub fn resetToLiveBottomForInput(self: *const Self, saw_non_modifier_key_press: bool, saw_text_input: bool) bool {
        return scrollback_view.resetToLiveBottomForInput(self.session, saw_non_modifier_key_press, saw_text_input);
    }

    pub fn clearSelectionIfActive(self: *const Self) bool {
        return terminal_selection.clearSelectionIfActive(self.session);
    }

    pub fn beginClickSelection(self: *const Self, row_cells: []const terminal_types.Cell, global_row: usize, col: usize, click_count: u8) ClickSelectionResult {
        return terminal_selection.beginClickSelection(self.session, row_cells, global_row, col, click_count);
    }

    pub fn extendGestureSelection(self: *const Self, gesture: SelectionGesture, row_cells: []const terminal_types.Cell, global_row: usize, col: usize) bool {
        return terminal_selection.extendGestureSelection(self.session, gesture, row_cells, global_row, col);
    }

    pub fn selectRange(self: *const Self, start: terminal_types.SelectionPos, end: terminal_types.SelectionPos, finished: bool) void {
        terminal_selection.selectRange(self.session, start, end, finished);
    }

    pub fn selectOrUpdateCell(self: *const Self, pos: terminal_types.SelectionPos) bool {
        self.session.lock();
        defer self.session.unlock();
        return terminal_selection.selectOrUpdateCellLocked(self.session, pos);
    }

    pub fn selectOrUpdateCellInRow(self: *const Self, row_cells: []const terminal_types.Cell, global_row: usize, col: usize) bool {
        return terminal_selection.selectOrUpdateCellInRow(self.session, row_cells, global_row, col);
    }

    pub fn finishSelectionIfActive(self: *const Self) bool {
        return terminal_selection.finishSelectionIfActive(self.session);
    }

    pub fn scrollSelectionDrag(self: *const Self, up: bool) bool {
        return scrollback_view.scrollSelectionDrag(self.session, up);
    }

    pub fn reportAlternateScrollWheel(self: *const Self, wheel_steps: i32, mod: terminal_types.Modifier) !bool {
        return session_input.reportAlternateScrollWheel(self.session, wheel_steps, mod);
    }

    pub fn scrollWheel(self: *const Self, wheel_steps: i32) bool {
        return scrollback_view.scrollWheel(self.session, wheel_steps);
    }

    pub fn setScrollOffset(self: *const Self, scroll_offset: usize) void {
        scrollback_view.setScrollOffset(self.session, scroll_offset);
    }

    pub fn sendKittyPasteEvent5522WithMimeRich(self: *const Self, clip: []const u8, html: ?[]const u8, uri_list: ?[]const u8, png: ?[]const u8) !bool {
        return session_interaction.sendKittyPasteEvent5522WithMimeRich(self.session, clip, html, uri_list, png);
    }

    pub fn bracketedPasteEnabled(self: *const Self) bool {
        return session_interaction.bracketedPasteEnabled(self.session);
    }

    pub fn sendText(self: *const Self, text: []const u8) !void {
        try session_input.sendText(self.session, text);
    }

    pub fn reportMouseEvent(self: *const Self, event: terminal_types.MouseEvent) !bool {
        return session_input.reportMouseEvent(self.session, event);
    }
};

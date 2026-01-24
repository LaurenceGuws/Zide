const types = @import("types.zig");

pub const SelectionState = struct {
    selection: types.TerminalSelection,

    pub fn init() SelectionState {
        return .{
            .selection = .{
                .active = false,
                .selecting = false,
                .start = .{ .row = 0, .col = 0 },
                .end = .{ .row = 0, .col = 0 },
            },
        };
    }

    pub fn clear(self: *SelectionState) void {
        self.selection.active = false;
        self.selection.selecting = false;
    }

    pub fn start(self: *SelectionState, row: usize, col: usize) void {
        self.selection.active = true;
        self.selection.selecting = true;
        self.selection.start = .{ .row = row, .col = col };
        self.selection.end = .{ .row = row, .col = col };
    }

    pub fn update(self: *SelectionState, row: usize, col: usize) void {
        if (!self.selection.active) return;
        self.selection.end = .{ .row = row, .col = col };
    }

    pub fn finish(self: *SelectionState) void {
        if (!self.selection.active) return;
        self.selection.selecting = false;
    }

    pub fn state(self: *const SelectionState) ?types.TerminalSelection {
        if (!self.selection.active) return null;
        return self.selection;
    }
};

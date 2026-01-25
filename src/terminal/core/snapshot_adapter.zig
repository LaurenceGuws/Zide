const shared = @import("../../types/mod.zig").snapshots;
const term_mod = @import("terminal.zig");

pub fn toSharedSnapshot(snapshot: term_mod.TerminalSnapshot) shared.TerminalSnapshot {
    _ = snapshot;
    // TODO: map terminal snapshot to shared types once widget/core split lands.
    return shared.TerminalSnapshot{
        .rows = 0,
        .cols = 0,
        .cells = &[_]shared.TerminalCell{},
        .cursor_row = 0,
        .cursor_col = 0,
        .selection = null,
    };
}

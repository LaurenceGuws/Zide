const shared = @import("../../types/mod.zig").snapshots;
const terminal_publication = @import("publication/terminal_publication.zig");

pub fn toSharedSnapshot(snapshot: terminal_publication.TerminalSnapshot) shared.TerminalSnapshot {
    // TODO: map terminal snapshot to shared types once widget/core split lands.
    return shared.TerminalSnapshot{
        .rows = @intCast(snapshot.rows),
        .cols = @intCast(snapshot.cols),
        .cells = &[_]shared.TerminalCell{},
        .cursor_row = @intCast(snapshot.cursor.row),
        .cursor_col = @intCast(snapshot.cursor.col),
        .selection = null,
    };
}

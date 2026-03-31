const session_mod = @import("terminal_session.zig");

pub const debugSnapshot = session_mod.debugSnapshot;
pub const debugScrollbackRow = session_mod.debugScrollbackRow;
pub const debugSetCursor = session_mod.debugSetCursor;
pub const debugFeedBytes = session_mod.debugFeedBytes;
pub const debugScrollUp = session_mod.debugScrollUp;
pub const debugSetScrollOffset = session_mod.debugSetScrollOffset;
pub const debugSetScrollbackCell = session_mod.debugSetScrollbackCell;
pub const debugPushScrollbackRow = session_mod.debugPushScrollbackRow;
pub const debugSetGridRow = session_mod.debugSetGridRow;

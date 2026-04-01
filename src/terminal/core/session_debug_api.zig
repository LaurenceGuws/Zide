const session_debug = @import("terminal_session_debug.zig");

pub const debugSnapshot = session_debug.debugSnapshot;
pub const debugScrollbackRow = session_debug.debugScrollbackRow;
pub const debugSetCursor = session_debug.debugSetCursor;
pub const debugFeedBytes = session_debug.debugFeedBytes;
pub const debugScrollUp = session_debug.debugScrollUp;
pub const debugSetScrollOffset = session_debug.debugSetScrollOffset;
pub const debugSetScrollbackCell = session_debug.debugSetScrollbackCell;
pub const debugPushScrollbackRow = session_debug.debugPushScrollbackRow;
pub const debugSetGridRow = session_debug.debugSetGridRow;

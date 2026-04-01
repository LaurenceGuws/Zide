const session_debug_api = @import("session/session_debug_api.zig");

pub const debugSnapshot = session_debug_api.debugSnapshot;
pub const debugScrollbackRow = session_debug_api.debugScrollbackRow;
pub const debugSetCursor = session_debug_api.debugSetCursor;
pub const debugFeedBytes = session_debug_api.debugFeedBytes;
pub const debugScrollUp = session_debug_api.debugScrollUp;
pub const debugSetScrollOffset = session_debug_api.debugSetScrollOffset;
pub const debugSetScrollbackCell = session_debug_api.debugSetScrollbackCell;
pub const debugPushScrollbackRow = session_debug_api.debugPushScrollbackRow;
pub const debugSetGridRow = session_debug_api.debugSetGridRow;

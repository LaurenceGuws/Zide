const types = @import("../model/types.zig");

pub const InitOptions = struct {
    scrollback_rows: ?usize = null,
    cursor_style: ?types.CursorStyle = null,
};

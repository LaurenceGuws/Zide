const std = @import("std");

/// Cursor position in the buffer
pub const CursorPos = struct {
    line: usize,
    col: usize,
    /// Byte offset in the buffer
    offset: usize,
};

/// Selection range
pub const Selection = struct {
    start: CursorPos,
    end: CursorPos,
    is_rectangular: bool = false,

    pub fn isEmpty(self: Selection) bool {
        return self.start.offset == self.end.offset;
    }

    pub fn normalized(self: Selection) Selection {
        if (self.start.offset <= self.end.offset) {
            return self;
        }
        return .{ .start = self.end, .end = self.start, .is_rectangular = self.is_rectangular };
    }
};

/// Edit operation for higher-level editor commands
pub const EditOp = enum {
    insert_char,
    delete_char,
    delete_selection,
    newline,
    indent,
    dedent,
};

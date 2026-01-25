pub const HighlightSpan = struct {
    start: usize,
    end: usize,
    kind: u16,
};

pub const EditorSnapshot = struct {
    text: []const u8,
    line_offsets: []const u32,
    cursor_line: u32,
    cursor_col: u32,
    selection_start: ?usize,
    selection_end: ?usize,
    highlights: []const HighlightSpan,
};

pub const TerminalCell = struct {
    codepoint: u32,
    fg: u32,
    bg: u32,
    attrs: u16,
};

pub const TerminalSelection = struct {
    start_row: u16,
    start_col: u16,
    end_row: u16,
    end_col: u16,
};

pub const TerminalSnapshot = struct {
    rows: u16,
    cols: u16,
    cells: []const TerminalCell,
    cursor_row: u16,
    cursor_col: u16,
    selection: ?TerminalSelection,
};

const input = @import("input.zig");

pub const EditorWidgetAction = union(enum) {
    scroll_rows: i32,
    scroll_cols: i32,
    move_cursor: struct { delta_rows: i32, delta_cols: i32 },
    set_cursor: struct { line: usize, col: usize },
    insert_text: []const u8,
    delete_backward: usize,
    delete_forward: usize,
    select_range: struct { start: usize, end: usize },
    request_save: void,
};

pub const TerminalWidgetAction = union(enum) {
    input_bytes: []const u8,
    input_key: struct { key: input.Key, mods: input.Modifiers },
    resize: struct { cols: u16, rows: u16 },
    copy_selection: void,
    paste_text: []const u8,
    open_link: []const u8,
};

pub const WidgetAction = union(enum) {
    editor: EditorWidgetAction,
    terminal: TerminalWidgetAction,
};

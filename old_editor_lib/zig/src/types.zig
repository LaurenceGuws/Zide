const std = @import("std");

pub const BufferKind = enum(u8) {
    original,
    add,
};

pub const Piece = struct {
    buffer: BufferKind,
    start: usize,
    len: usize,
};

pub const TextBuffer = struct {
    allocator: std.mem.Allocator,
    mutex: std.Thread.Mutex,
    original: []const u8,
    add: std.ArrayList(u8),
    pieces: std.ArrayList(Piece),
    line_starts: std.ArrayList(usize),
    line_index_dirty: bool,
    undo_stack: std.ArrayList(UndoOp),
    redo_stack: std.ArrayList(UndoOp),
    history_suspended: bool,
    original_in_file: bool,
    file: ?std.fs.File,
    file_len: usize,
    index_thread: ?std.Thread,
    index_building: std.atomic.Value(bool),
    index_ready: std.atomic.Value(bool),
    index_progress: std.atomic.Value(usize),
    index_total: usize,
    index_epoch: usize,
    index_suspended: bool,
    last_piece_valid: bool,
    last_piece_index: usize,
    last_piece_start: usize,
    last_piece_end: usize,
};

pub const UndoKind = enum(u8) {
    insert,
    delete,
};

pub const UndoOp = struct {
    kind: UndoKind,
    pos: usize,
    text: []u8,
};

const std = @import("std");

/// Minimal terminal stub so the UI panel stays wired while backend is removed.
pub const TerminalSession = struct {
    allocator: std.mem.Allocator,
    rows: u16,
    cols: u16,
    title: []const u8,
    pty: DummyPty,

    pub fn init(allocator: std.mem.Allocator, rows: u16, cols: u16) !*TerminalSession {
        const session = try allocator.create(TerminalSession);
        session.* = .{
            .allocator = allocator,
            .rows = rows,
            .cols = cols,
            .title = "Terminal",
            .pty = .{},
        };
        return session;
    }

    pub fn deinit(self: *TerminalSession) void {
        self.allocator.destroy(self);
    }

    pub fn start(self: *TerminalSession, shell: ?[:0]const u8) !void {
        _ = self;
        _ = shell;
    }

    pub fn poll(self: *TerminalSession) !void {
        _ = self;
    }

    pub fn sendKey(self: *TerminalSession, key: Key, mod: Modifier) !void {
        _ = self;
        _ = key;
        _ = mod;
    }

    pub fn sendChar(self: *TerminalSession, char: u32, mod: Modifier) !void {
        _ = self;
        _ = char;
        _ = mod;
    }

    pub fn resize(self: *TerminalSession, rows: u16, cols: u16) !void {
        self.rows = rows;
        self.cols = cols;
    }

    pub fn getCell(self: *TerminalSession, row: usize, col: usize) Cell {
        _ = self;
        _ = row;
        _ = col;
        return Cell{
            .codepoint = 0,
            .width = 1,
            .attrs = CellAttrs{
                .fg = Color{ .r = 220, .g = 220, .b = 220 },
                .bg = Color{ .r = 24, .g = 25, .b = 33 },
                .bold = false,
                .reverse = false,
            },
        };
    }

    pub fn getCursorPos(self: *TerminalSession) CursorPos {
        _ = self;
        return .{ .row = 0, .col = 0 };
    }

    pub fn isAlive(self: *TerminalSession) bool {
        _ = self;
        return false;
    }

    pub fn getDamage(self: *TerminalSession) ?struct {
        start_row: usize,
        end_row: usize,
        start_col: usize,
        end_col: usize,
    } {
        _ = self;
        return null;
    }

    pub fn markDirty(self: *TerminalSession) void {
        _ = self;
    }
};

const DummyPty = struct {
    pub fn hasData(self: DummyPty) bool {
        _ = self;
        return false;
    }
};

pub const CursorPos = struct {
    row: usize,
    col: usize,
};

pub const Cell = struct {
    codepoint: u32,
    width: u8,
    attrs: CellAttrs,
};

pub const CellAttrs = struct {
    fg: Color,
    bg: Color,
    bold: bool,
    reverse: bool,
};

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
};

pub const Key = u32;
pub const Modifier = u8;

pub const VTERM_KEY_NONE: Key = 0;
pub const VTERM_KEY_ENTER: Key = 1;
pub const VTERM_KEY_TAB: Key = 2;
pub const VTERM_KEY_BACKSPACE: Key = 3;
pub const VTERM_KEY_ESCAPE: Key = 4;
pub const VTERM_KEY_UP: Key = 5;
pub const VTERM_KEY_DOWN: Key = 6;
pub const VTERM_KEY_LEFT: Key = 7;
pub const VTERM_KEY_RIGHT: Key = 8;
pub const VTERM_KEY_INS: Key = 9;
pub const VTERM_KEY_DEL: Key = 10;
pub const VTERM_KEY_HOME: Key = 11;
pub const VTERM_KEY_END: Key = 12;
pub const VTERM_KEY_PAGEUP: Key = 13;
pub const VTERM_KEY_PAGEDOWN: Key = 14;

pub const VTERM_MOD_NONE: Modifier = 0;
pub const VTERM_MOD_SHIFT: Modifier = 1;
pub const VTERM_MOD_ALT: Modifier = 2;
pub const VTERM_MOD_CTRL: Modifier = 4;

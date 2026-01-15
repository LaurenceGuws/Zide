const std = @import("std");
const builtin = @import("builtin");
const vterm = @import("vterm.zig");

// Platform-specific PTY
const Pty = if (builtin.os.tag == .windows)
    @import("pty_windows.zig").Pty
else
    @import("pty_unix.zig").Pty;

/// High-level terminal session combining PTY + VTerm emulator
pub const TerminalSession = struct {
    allocator: std.mem.Allocator,
    pty: Pty,
    term: *vterm.Terminal,
    rows: u16,
    cols: u16,
    title: []const u8,
    read_buffer: [16 * 1024]u8,

    pub fn init(allocator: std.mem.Allocator, rows: u16, cols: u16) !*TerminalSession {
        const pty = try Pty.init(rows, cols);
        errdefer {
            var p = pty;
            p.deinit();
        }

        const term = try vterm.Terminal.init(allocator, rows, cols);
        errdefer term.deinit();

        const session = try allocator.create(TerminalSession);
        session.* = .{
            .allocator = allocator,
            .pty = pty,
            .term = term,
            .rows = rows,
            .cols = cols,
            .title = "Terminal",
            .read_buffer = undefined,
        };

        return session;
    }

    pub fn deinit(self: *TerminalSession) void {
        self.pty.deinit();
        self.term.deinit();
        self.allocator.destroy(self);
    }

    /// Start the shell process
    pub fn start(self: *TerminalSession, shell: ?[:0]const u8) !void {
        try self.pty.spawn(shell);
    }

    /// Poll for new data from PTY and feed to terminal emulator
    pub fn poll(self: *TerminalSession) !void {
        const n = try self.pty.read(&self.read_buffer);
        if (n > 0) {
            self.term.feed(self.read_buffer[0..n]);
        }

        // Send any pending output from terminal to PTY
        const output = self.term.flushOutput();
        if (output.len > 0) {
            _ = try self.pty.write(output);
            self.term.clearOutput();
        }
    }

    /// Send keyboard input
    pub fn sendKey(self: *TerminalSession, key: vterm.Key, mod: vterm.Modifier) !void {
        self.term.sendKey(key, mod);
        const output = self.term.flushOutput();
        if (output.len > 0) {
            _ = try self.pty.write(output);
            self.term.clearOutput();
        }
    }

    /// Send a character
    pub fn sendChar(self: *TerminalSession, char: u32, mod: vterm.Modifier) !void {
        self.term.sendChar(char, mod);
        const output = self.term.flushOutput();
        if (output.len > 0) {
            _ = try self.pty.write(output);
            self.term.clearOutput();
        }
    }

    /// Resize terminal
    pub fn resize(self: *TerminalSession, rows: u16, cols: u16) !void {
        self.rows = rows;
        self.cols = cols;
        try self.pty.resize(rows, cols);
        self.term.resize(rows, cols);
    }

    /// Get a cell at position
    pub fn getCell(self: *TerminalSession, row: usize, col: usize) vterm.Cell {
        return self.term.getCell(row, col);
    }


    /// Get cursor position
    pub fn getCursorPos(self: *TerminalSession) vterm.Terminal.CursorPos {
        return self.term.getCursorPos();
    }

    /// Check if terminal is still alive
    pub fn isAlive(self: *TerminalSession) bool {
        return self.pty.isAlive();
    }

    /// Check for screen damage (areas that need redrawing)
    pub fn getDamage(self: *TerminalSession) ?struct {
        start_row: usize,
        end_row: usize,
        start_col: usize,
        end_col: usize,
    } {
        return self.term.getDamageAndClear();
    }

    /// Mark entire screen for redraw
    pub fn markDirty(self: *TerminalSession) void {
        self.term.markFullDamage();
    }
};

// Re-export vterm types
pub const Terminal = vterm.Terminal;
pub const Cell = vterm.Cell;
pub const CellAttrs = vterm.CellAttrs;
pub const Color = vterm.Color;
pub const Key = vterm.Key;
pub const Modifier = vterm.Modifier;

pub const VTERM_KEY_NONE = vterm.VTERM_KEY_NONE;
pub const VTERM_KEY_ENTER = vterm.VTERM_KEY_ENTER;
pub const VTERM_KEY_TAB = vterm.VTERM_KEY_TAB;
pub const VTERM_KEY_BACKSPACE = vterm.VTERM_KEY_BACKSPACE;
pub const VTERM_KEY_ESCAPE = vterm.VTERM_KEY_ESCAPE;
pub const VTERM_KEY_UP = vterm.VTERM_KEY_UP;
pub const VTERM_KEY_DOWN = vterm.VTERM_KEY_DOWN;
pub const VTERM_KEY_LEFT = vterm.VTERM_KEY_LEFT;
pub const VTERM_KEY_RIGHT = vterm.VTERM_KEY_RIGHT;
pub const VTERM_KEY_INS = vterm.VTERM_KEY_INS;
pub const VTERM_KEY_DEL = vterm.VTERM_KEY_DEL;
pub const VTERM_KEY_HOME = vterm.VTERM_KEY_HOME;
pub const VTERM_KEY_END = vterm.VTERM_KEY_END;
pub const VTERM_KEY_PAGEUP = vterm.VTERM_KEY_PAGEUP;
pub const VTERM_KEY_PAGEDOWN = vterm.VTERM_KEY_PAGEDOWN;

pub const VTERM_MOD_NONE = vterm.VTERM_MOD_NONE;
pub const VTERM_MOD_SHIFT = vterm.VTERM_MOD_SHIFT;
pub const VTERM_MOD_ALT = vterm.VTERM_MOD_ALT;
pub const VTERM_MOD_CTRL = vterm.VTERM_MOD_CTRL;

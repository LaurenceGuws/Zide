const std = @import("std");
const builtin = @import("builtin");

/// libvterm C bindings
const c = @cImport({
    @cInclude("vterm.h");
});

const ZideVTermCell = extern struct {
    codepoint: u32,
    width: u8,
    bold: u8,
    italic: u8,
    underline: u8,
    blink: u8,
    reverse: u8,
    strike: u8,
    fg_r: u8,
    fg_g: u8,
    fg_b: u8,
    bg_r: u8,
    bg_g: u8,
    bg_b: u8,
};

extern "c" fn zide_vterm_get_cell(screen: *c.VTermScreen, row: c_int, col: c_int, out: *ZideVTermCell) c_int;

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,

    pub fn fromVterm(vc: c.VTermColor) Color {
        if (vc.type == c.VTERM_COLOR_RGB) {
            return .{
                .r = vc.rgb.red,
                .g = vc.rgb.green,
                .b = vc.rgb.blue,
            };
        }
        // Index color - return a basic palette color
        return indexToRgb(vc.indexed.idx);
    }

    fn indexToRgb(idx: u8) Color {
        // Basic 16-color palette
        const palette = [16]Color{
            .{ .r = 0, .g = 0, .b = 0 }, // Black
            .{ .r = 205, .g = 49, .b = 49 }, // Red
            .{ .r = 13, .g = 188, .b = 121 }, // Green
            .{ .r = 229, .g = 229, .b = 16 }, // Yellow
            .{ .r = 36, .g = 114, .b = 200 }, // Blue
            .{ .r = 188, .g = 63, .b = 188 }, // Magenta
            .{ .r = 17, .g = 168, .b = 205 }, // Cyan
            .{ .r = 229, .g = 229, .b = 229 }, // White
            .{ .r = 102, .g = 102, .b = 102 }, // Bright Black
            .{ .r = 241, .g = 76, .b = 76 }, // Bright Red
            .{ .r = 35, .g = 209, .b = 139 }, // Bright Green
            .{ .r = 245, .g = 245, .b = 67 }, // Bright Yellow
            .{ .r = 59, .g = 142, .b = 234 }, // Bright Blue
            .{ .r = 214, .g = 112, .b = 214 }, // Bright Magenta
            .{ .r = 41, .g = 184, .b = 219 }, // Bright Cyan
            .{ .r = 255, .g = 255, .b = 255 }, // Bright White
        };
        if (idx < 16) return palette[idx];

        // 256-color palette (216 color cube + 24 grayscale)
        if (idx < 232) {
            const color_idx = idx - 16;
            const r_idx = color_idx / 36;
            const g_idx = (color_idx % 36) / 6;
            const b_idx = color_idx % 6;
            return .{
                .r = if (r_idx == 0) 0 else @as(u8, @intCast(55 + r_idx * 40)),
                .g = if (g_idx == 0) 0 else @as(u8, @intCast(55 + g_idx * 40)),
                .b = if (b_idx == 0) 0 else @as(u8, @intCast(55 + b_idx * 40)),
            };
        }

        // Grayscale
        const gray = @as(u8, @intCast(8 + (idx - 232) * 10));
        return .{ .r = gray, .g = gray, .b = gray };
    }
};

pub const CellAttrs = struct {
    bold: bool = false,
    italic: bool = false,
    underline: bool = false,
    blink: bool = false,
    reverse: bool = false,
    strike: bool = false,
    fg: Color = .{ .r = 229, .g = 229, .b = 229 },
    bg: Color = .{ .r = 0, .g = 0, .b = 0 },
};

pub const Cell = struct {
    char: [4]u8 = .{ 0, 0, 0, 0 },
    char_len: u8 = 0,
    codepoint: u32 = 0,
    attrs: CellAttrs = .{},
    width: u8 = 1,

    pub fn getChar(self: Cell) []const u8 {
        return self.char[0..self.char_len];
    }
};

pub const Terminal = struct {
    allocator: std.mem.Allocator,
    vt: *c.VTerm,
    screen: *c.VTermScreen,
    rows: usize,
    cols: usize,
    /// Callback for output data (to be sent to PTY)
    output_callback: ?*const fn (data: []const u8, userdata: ?*anyopaque) void,
    output_userdata: ?*anyopaque,
    /// Ring buffer for output
    output_buffer: std.ArrayList(u8),
    /// Damage tracking
    damage_start_row: usize,
    damage_end_row: usize,
    damage_start_col: usize,
    damage_end_col: usize,
    has_damage: bool,

    pub fn init(allocator: std.mem.Allocator, rows: usize, cols: usize) !*Terminal {
        const vt = c.vterm_new(@intCast(rows), @intCast(cols)) orelse return error.InitFailed;
        errdefer c.vterm_free(vt);

        c.vterm_set_utf8(vt, 1);

        const screen = c.vterm_obtain_screen(vt) orelse return error.InitFailed;
        c.vterm_screen_reset(screen, 1);

        const term = try allocator.create(Terminal);
        term.* = .{
            .allocator = allocator,
            .vt = vt,
            .screen = screen,
            .rows = rows,
            .cols = cols,
            .output_callback = null,
            .output_userdata = null,
            .output_buffer = .empty,
            .damage_start_row = 0,
            .damage_end_row = 0,
            .damage_start_col = 0,
            .damage_end_col = 0,
            .has_damage = false,
        };

        // Set up output callback
        c.vterm_output_set_callback(vt, vtermOutputCallback, term);

        // Note: Damage callback setup removed due to Zig @cImport limitations
        // with VTermScreenCallbacks type. We'll use full-screen redraw instead.
        term.markFullDamage();

        return term;
    }

    pub fn deinit(self: *Terminal) void {
        c.vterm_free(self.vt);
        self.output_buffer.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// Feed input data from PTY to the terminal
    pub fn feed(self: *Terminal, data: []const u8) void {
        _ = c.vterm_input_write(self.vt, data.ptr, data.len);
    }

    /// Send keyboard input
    pub fn sendKey(self: *Terminal, key: c.VTermKey, mod: c.VTermModifier) void {
        c.vterm_keyboard_key(self.vt, key, mod);
    }

    /// Send a character
    pub fn sendChar(self: *Terminal, char: u32, mod: c.VTermModifier) void {
        c.vterm_keyboard_unichar(self.vt, char, mod);
    }

    /// Get a cell at the given position
    pub fn getCell(self: *Terminal, row: usize, col: usize) Cell {
        if (row >= self.rows or col >= self.cols) {
            return Cell{};
        }

        var vcell: ZideVTermCell = undefined;
        if (zide_vterm_get_cell(self.screen, @intCast(row), @intCast(col), &vcell) == 0) {
            return Cell{};
        }

        var cell = Cell{};

        // Copy character (UTF-32 to UTF-8)
        if (vcell.codepoint != 0) {
            var utf8_buf: [4]u8 = undefined;
            const len = std.unicode.utf8Encode(@intCast(vcell.codepoint), &utf8_buf) catch 0;
            if (len > 0) {
                @memcpy(cell.char[0..len], utf8_buf[0..len]);
                cell.char_len = @intCast(len);
            }
            cell.codepoint = vcell.codepoint;
        }

        // Copy attributes from packed struct
        cell.attrs = .{
            .bold = vcell.bold != 0,
            .italic = vcell.italic != 0,
            .underline = vcell.underline != 0,
            .blink = vcell.blink != 0,
            .reverse = vcell.reverse != 0,
            .strike = vcell.strike != 0,
            .fg = .{ .r = vcell.fg_r, .g = vcell.fg_g, .b = vcell.fg_b },
            .bg = .{ .r = vcell.bg_r, .g = vcell.bg_g, .b = vcell.bg_b },
        };

        cell.width = @intCast(vcell.width);

        return cell;
    }

    pub const CursorPos = struct { row: usize, col: usize };

    /// Get cursor position
    pub fn getCursorPos(self: *Terminal) CursorPos {
        var pos: c.VTermPos = undefined;
        _ = c.vterm_state_get_cursorpos(c.vterm_obtain_state(self.vt), &pos);
        return .{
            .row = @intCast(pos.row),
            .col = @intCast(pos.col),
        };
    }

    /// Resize the terminal
    pub fn resize(self: *Terminal, rows: usize, cols: usize) void {
        c.vterm_set_size(self.vt, @intCast(rows), @intCast(cols));
        self.rows = rows;
        self.cols = cols;
    }

    /// Flush pending output
    pub fn flushOutput(self: *Terminal) []const u8 {
        const data = self.output_buffer.items;
        return data;
    }

    /// Clear the output buffer after it's been sent to PTY
    pub fn clearOutput(self: *Terminal) void {
        self.output_buffer.clearRetainingCapacity();
    }

    /// Check and clear damage
    pub fn getDamageAndClear(self: *Terminal) ?struct {
        start_row: usize,
        end_row: usize,
        start_col: usize,
        end_col: usize,
    } {
        if (!self.has_damage) return null;
        const damage = .{
            .start_row = self.damage_start_row,
            .end_row = self.damage_end_row,
            .start_col = self.damage_start_col,
            .end_col = self.damage_end_col,
        };
        self.has_damage = false;
        self.damage_start_row = self.rows;
        self.damage_end_row = 0;
        self.damage_start_col = self.cols;
        self.damage_end_col = 0;
        return damage;
    }

    /// Mark entire screen as damaged (for full redraw)
    pub fn markFullDamage(self: *Terminal) void {
        self.has_damage = true;
        self.damage_start_row = 0;
        self.damage_end_row = self.rows;
        self.damage_start_col = 0;
        self.damage_end_col = self.cols;
    }

    fn vtermOutputCallback(data: [*c]const u8, len: usize, user: ?*anyopaque) callconv(.c) void {
        const self: *Terminal = @ptrCast(@alignCast(user));
        self.output_buffer.appendSlice(self.allocator, data[0..len]) catch {};
    }
};

// Re-export some vterm constants for keyboard handling
pub const Key = c.VTermKey;
pub const Modifier = c.VTermModifier;

pub const VTERM_KEY_NONE = c.VTERM_KEY_NONE;
pub const VTERM_KEY_ENTER = c.VTERM_KEY_ENTER;
pub const VTERM_KEY_TAB = c.VTERM_KEY_TAB;
pub const VTERM_KEY_BACKSPACE = c.VTERM_KEY_BACKSPACE;
pub const VTERM_KEY_ESCAPE = c.VTERM_KEY_ESCAPE;
pub const VTERM_KEY_UP = c.VTERM_KEY_UP;
pub const VTERM_KEY_DOWN = c.VTERM_KEY_DOWN;
pub const VTERM_KEY_LEFT = c.VTERM_KEY_LEFT;
pub const VTERM_KEY_RIGHT = c.VTERM_KEY_RIGHT;
pub const VTERM_KEY_INS = c.VTERM_KEY_INS;
pub const VTERM_KEY_DEL = c.VTERM_KEY_DEL;
pub const VTERM_KEY_HOME = c.VTERM_KEY_HOME;
pub const VTERM_KEY_END = c.VTERM_KEY_END;
pub const VTERM_KEY_PAGEUP = c.VTERM_KEY_PAGEUP;
pub const VTERM_KEY_PAGEDOWN = c.VTERM_KEY_PAGEDOWN;

pub const VTERM_MOD_NONE: c.VTermModifier = 0;
pub const VTERM_MOD_SHIFT: c.VTermModifier = c.VTERM_MOD_SHIFT;
pub const VTERM_MOD_ALT: c.VTermModifier = c.VTERM_MOD_ALT;
pub const VTERM_MOD_CTRL: c.VTermModifier = c.VTERM_MOD_CTRL;

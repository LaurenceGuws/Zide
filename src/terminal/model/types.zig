pub const CursorPos = struct {
    row: usize,
    col: usize,
};

pub const CursorShape = enum {
    block,
    underline,
    bar,
};

pub const CursorStyle = struct {
    shape: CursorShape,
    blink: bool,
};

pub const default_cursor_style = CursorStyle{ .shape = .block, .blink = true };

const selection_mod = @import("selection.zig");

pub const SelectionPos = selection_mod.SelectionPos;
pub const TerminalSelection = selection_mod.TerminalSelection;

pub const Cell = struct {
    codepoint: u32,
    combining_len: u8 = 0,
    combining: [2]u32 = .{ 0, 0 },
    width: u8 = 1,
    height: u8 = 1,
    x: u8 = 0,
    y: u8 = 0,
    attrs: CellAttrs,
};

pub fn isCellContinuation(cell: Cell) bool {
    return cell.x != 0 or cell.y != 0;
}

pub fn isMultiRowCellRoot(cell: Cell) bool {
    return cell.height > 1 and cell.x == 0 and cell.y == 0;
}

pub const CellAttrs = struct {
    fg: Color,
    bg: Color,
    bold: bool,
    blink: bool,
    blink_fast: bool,
    reverse: bool,
    underline: bool,
    underline_color: Color,
    link_id: u32,
};

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,
};

pub const Key = u32;
pub const Modifier = u8;
pub const PhysicalKey = u32;

pub const KeyboardAlternateMetadata = struct {
    // Logical/physical key identity for layout-aware alternate reporting.
    physical_key: ?PhysicalKey = null,
    // UTF-8 text produced by the event (if any).
    produced_text_utf8: ?[]const u8 = null,
    // Layout-derived codepoints used for kitty alternate-key reporting.
    base_codepoint: ?u32 = null,
    shifted_codepoint: ?u32 = null,
    alternate_layout_codepoint: ?u32 = null,
    // Marks IME/compose output where alternate inference may be suppressed.
    text_is_composed: bool = false,
};

pub const MouseButton = enum(u8) {
    none = 0,
    left = 1,
    middle = 2,
    right = 3,
    wheel_up = 4,
    wheel_down = 5,
};

pub const MouseEventKind = enum(u8) {
    press,
    release,
    move,
    wheel,
};

pub const MouseEvent = struct {
    kind: MouseEventKind,
    button: MouseButton,
    row: usize,
    col: usize,
    pixel_x: ?u32 = null,
    pixel_y: ?u32 = null,
    mod: Modifier,
    buttons_down: u8,
};

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
pub const VTERM_KEY_LEFT_SHIFT: Key = 15;
pub const VTERM_KEY_RIGHT_SHIFT: Key = 16;
pub const VTERM_KEY_LEFT_CTRL: Key = 17;
pub const VTERM_KEY_RIGHT_CTRL: Key = 18;
pub const VTERM_KEY_LEFT_ALT: Key = 19;
pub const VTERM_KEY_RIGHT_ALT: Key = 20;
pub const VTERM_KEY_LEFT_SUPER: Key = 21;
pub const VTERM_KEY_RIGHT_SUPER: Key = 22;

pub const VTERM_MOD_NONE: Modifier = 0;
pub const VTERM_MOD_SHIFT: Modifier = 1;
pub const VTERM_MOD_ALT: Modifier = 2;
pub const VTERM_MOD_CTRL: Modifier = 4;

pub fn defaultCell() Cell {
    return Cell{
        .codepoint = 0,
        .width = 1,
        .attrs = CellAttrs{
            .fg = default_fg,
            .bg = default_bg,
            .bold = false,
            .blink = false,
            .blink_fast = false,
            .reverse = false,
            .underline = false,
            .underline_color = default_fg,
            .link_id = 0,
        },
    };
}

pub const default_fg = Color{ .r = 220, .g = 220, .b = 220 };
pub const default_bg = Color{ .r = 24, .g = 25, .b = 33 };
pub const default_underline_color = Color{ .r = 0, .g = 0, .b = 0, .a = 0 };
pub const default_cell_attrs = CellAttrs{
    .fg = default_fg,
    .bg = default_bg,
    .bold = false,
    .blink = false,
    .blink_fast = false,
    .reverse = false,
    .underline = false,
    .underline_color = default_underline_color,
    .link_id = 0,
};
pub const default_cell = Cell{
    .codepoint = 0,
    .attrs = default_cell_attrs,
};

pub const ansiColors = [_]Color{
    .{ .r = 0, .g = 0, .b = 0 }, // black
    .{ .r = 205, .g = 49, .b = 49 }, // red
    .{ .r = 13, .g = 188, .b = 121 }, // green
    .{ .r = 229, .g = 229, .b = 16 }, // yellow
    .{ .r = 36, .g = 114, .b = 200 }, // blue
    .{ .r = 188, .g = 63, .b = 188 }, // magenta
    .{ .r = 17, .g = 168, .b = 205 }, // cyan
    .{ .r = 229, .g = 229, .b = 229 }, // white
};

pub const ansiBrightColors = [_]Color{
    .{ .r = 102, .g = 102, .b = 102 }, // bright black
    .{ .r = 241, .g = 76, .b = 76 }, // bright red
    .{ .r = 35, .g = 209, .b = 139 }, // bright green
    .{ .r = 245, .g = 245, .b = 67 }, // bright yellow
    .{ .r = 59, .g = 142, .b = 234 }, // bright blue
    .{ .r = 214, .g = 112, .b = 214 }, // bright magenta
    .{ .r = 41, .g = 184, .b = 219 }, // bright cyan
    .{ .r = 255, .g = 255, .b = 255 }, // bright white
};

pub fn clampColorIndex(value: i32) u8 {
    if (value <= 0) return 0;
    if (value >= 255) return 255;
    return @intCast(value);
}

pub fn indexToRgb(idx: u8) Color {
    if (idx < 8) return ansiColors[idx];
    if (idx < 16) return ansiBrightColors[idx - 8];

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

    const gray = @as(u8, @intCast(8 + (idx - 232) * 10));
    return .{ .r = gray, .g = gray, .b = gray };
}

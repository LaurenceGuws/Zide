const std = @import("std");
const types = @import("types.zig");

pub const FontFamily = enum {
    iosevka,
    jetbrains_mono,
};

pub const FONT_FAMILY: FontFamily = .jetbrains_mono;

pub const FONT_PATH: [*:0]const u8 = switch (FONT_FAMILY) {
    .iosevka => "assets/fonts/IosevkaTermNerdFont-Regular.ttf",
    .jetbrains_mono => "assets/fonts/JetBrainsMonoNerdFont-Regular.ttf",
};

pub const SYMBOLS_FALLBACK_PATH: ?[*:0]const u8 = null;
pub const UNICODE_SYMBOLS2_PATH: ?[*:0]const u8 = null;
pub const UNICODE_SYMBOLS_PATH: ?[*:0]const u8 = null;
pub const UNICODE_MONO_PATH: ?[*:0]const u8 = null;
pub const UNICODE_SANS_PATH: ?[*:0]const u8 = null;
pub const EMOJI_COLOR_FALLBACK_PATH: ?[*:0]const u8 = null;
pub const EMOJI_TEXT_FALLBACK_PATH: ?[*:0]const u8 = null;

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,

    pub fn toRgba(self: Color) types.Rgba {
        return .{ .r = self.r, .g = self.g, .b = self.b, .a = self.a };
    }

    pub const black = Color{ .r = 0, .g = 0, .b = 0 };
    pub const white = Color{ .r = 255, .g = 255, .b = 255 };
    pub const gray = Color{ .r = 76, .g = 86, .b = 106 };
    pub const dark_gray = Color{ .r = 46, .g = 52, .b = 64 };
    pub const light_gray = Color{ .r = 67, .g = 76, .b = 94 };

    // Nordic palette colors
    pub const bg = Color{ .r = 36, .g = 41, .b = 51 };
    pub const fg = Color{ .r = 187, .g = 195, .b = 212 };
    pub const selection = Color{ .r = 59, .g = 66, .b = 82 };
    pub const comment = Color{ .r = 76, .g = 86, .b = 106 };
    pub const cyan = Color{ .r = 143, .g = 188, .b = 187 };
    pub const green = Color{ .r = 163, .g = 190, .b = 140 };
    pub const orange = Color{ .r = 208, .g = 135, .b = 112 };
    pub const pink = Color{ .r = 180, .g = 142, .b = 173 };
    pub const purple = Color{ .r = 190, .g = 157, .b = 184 };
    pub const red = Color{ .r = 197, .g = 114, .b = 122 };
    pub const yellow = Color{ .r = 235, .g = 203, .b = 139 };
};

pub const MousePos = struct {
    x: f32,
    y: f32,
};

pub const Theme = struct {
    background: Color = Color.bg,
    foreground: Color = Color.fg,
    selection: Color = Color.selection,
    cursor: Color = Color{ .r = 216, .g = 222, .b = 233 },
    link: Color = Color{ .r = 129, .g = 161, .b = 193 },
    line_number: Color = Color.comment,
    line_number_bg: Color = Color{ .r = 30, .g = 34, .b = 42 },
    current_line: Color = Color{ .r = 25, .g = 29, .b = 36 },
    ui_bar_bg: Color = Color{ .r = 30, .g = 31, .b = 41 },
    ui_panel_bg: Color = Color{ .r = 24, .g = 25, .b = 33 },
    ui_panel_overlay: Color = Color{ .r = 24, .g = 25, .b = 33, .a = 235 },
    ui_hover: Color = Color.selection,
    ui_pressed: Color = Color{ .r = 58, .g = 60, .b = 78 },
    ui_tab_inactive_bg: Color = Color{ .r = 35, .g = 36, .b = 48 },
    ui_accent: Color = Color.purple,
    ui_border: Color = Color.light_gray,
    ui_modified: Color = Color.orange,
    ui_text: Color = Color.fg,
    ui_text_inactive: Color = Color.comment,

    // Syntax colors
    comment_color: Color = Color.comment,
    string: Color = Color.green,
    keyword: Color = Color.orange,
    number: Color = Color.purple,
    function: Color = Color{ .r = 136, .g = 192, .b = 208 },
    variable: Color = Color.fg,
    type_name: Color = Color.yellow,
    operator: Color = Color.fg,
    builtin_color: Color = Color{ .r = 94, .g = 129, .b = 172 },
    punctuation: Color = Color{ .r = 96, .g = 114, .b = 138 },
    constant: Color = Color.purple,
    attribute: Color = Color.cyan,
    namespace: Color = Color{ .r = 231, .g = 193, .b = 115 },
    label: Color = Color.orange,
    error_token: Color = Color.red,
    preproc: Color = Color{ .r = 143, .g = 188, .b = 187 },
    macro: Color = Color{ .r = 180, .g = 142, .b = 173 },
    escape: Color = Color{ .r = 136, .g = 192, .b = 208 },

    // Optional override for terminal ANSI colors 0-15
    ansi_colors: ?[16]Color = null,
};

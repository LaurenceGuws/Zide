const std = @import("std");
const renderer = @import("../ui/renderer.zig");
const input_actions = @import("../input/input_actions.zig");
const term_types = @import("../terminal/model/types.zig");
const app_logger = @import("../app_logger.zig");

pub const Color = renderer.Color;
pub const Theme = renderer.Theme;

pub const LuaConfigError = error{
    LuaInitFailed,
    LuaLoadFailed,
    LuaRunFailed,
    InvalidConfig,
    OutOfMemory,
};

pub const FontHinting = enum {
    default,
    none,
    light,
    normal,
};

pub const GlyphOverflowPolicy = enum {
    when_followed_by_space,
    never,
    always,
};

pub const TerminalBlinkStyle = enum {
    kitty,
    off,
};

pub const TerminalDisableLigaturesStrategy = enum {
    never,
    cursor,
    always,
};

pub const TerminalNewTabStartLocationMode = enum {
    current,
    default,
};

pub const TabBarWidthMode = enum {
    fixed,
    dynamic,
    label_length,
};

pub const ThemeConfig = struct {
    background: ?Color = null,
    foreground: ?Color = null,
    selection: ?Color = null,
    cursor: ?Color = null,
    link: ?Color = null,
    line_number: ?Color = null,
    line_number_bg: ?Color = null,
    current_line: ?Color = null,
    ui_bar_bg: ?Color = null,
    ui_panel_bg: ?Color = null,
    ui_panel_overlay: ?Color = null,
    ui_hover: ?Color = null,
    ui_pressed: ?Color = null,
    ui_tab_inactive_bg: ?Color = null,
    ui_accent: ?Color = null,
    ui_border: ?Color = null,
    ui_modified: ?Color = null,
    ui_text: ?Color = null,
    ui_text_inactive: ?Color = null,
    comment_color: ?Color = null,
    string: ?Color = null,
    keyword: ?Color = null,
    number: ?Color = null,
    function: ?Color = null,
    variable: ?Color = null,
    type_name: ?Color = null,
    operator: ?Color = null,
    builtin_color: ?Color = null,
    punctuation: ?Color = null,
    constant: ?Color = null,
    attribute: ?Color = null,
    namespace: ?Color = null,
    label: ?Color = null,
    error_token: ?Color = null,
    preproc: ?Color = null,
    macro: ?Color = null,
    escape: ?Color = null,
    keyword_control: ?Color = null,
    function_method: ?Color = null,
    type_builtin: ?Color = null,
    ansi_colors: [16]?Color = .{null} ** 16,
};

pub const Config = struct {
    log_file_filter: ?[]u8,
    log_console_filter: ?[]u8,
    log_file_level: ?app_logger.Level = null,
    log_console_level: ?app_logger.Level = null,
    log_file_level_overrides: ?[]u8 = null,
    log_console_level_overrides: ?[]u8 = null,
    sdl_log_level: ?c_int,
    editor_wrap: ?bool,
    editor_large_jump_rows: ?usize,
    editor_highlight_budget: ?usize,
    editor_width_budget: ?usize,
    selection_overlay_smooth: ?bool,
    selection_overlay_corner_px: ?f32,
    selection_overlay_pad_px: ?f32,
    editor_selection_overlay_smooth: ?bool,
    editor_selection_overlay_corner_px: ?f32,
    editor_selection_overlay_pad_px: ?f32,
    terminal_selection_overlay_smooth: ?bool,
    terminal_selection_overlay_corner_px: ?f32,
    terminal_selection_overlay_pad_px: ?f32,
    app_font_path: ?[]u8,
    app_font_size: ?f32,
    editor_font_path: ?[]u8,
    editor_font_size: ?f32,
    editor_font_features: ?[]u8,
    editor_disable_ligatures: ?TerminalDisableLigaturesStrategy,
    terminal_font_path: ?[]u8,
    terminal_font_size: ?f32,
    terminal_blink_style: ?TerminalBlinkStyle,
    terminal_disable_ligatures: ?TerminalDisableLigaturesStrategy,
    terminal_font_features: ?[]u8,
    terminal_default_start_location: ?[]u8,
    terminal_new_tab_start_location: ?TerminalNewTabStartLocationMode,
    terminal_scrollback_rows: ?usize,
    terminal_cursor_shape: ?term_types.CursorShape,
    terminal_cursor_blink: ?bool,
    terminal_texture_shift: ?bool,
    terminal_recent_input_force_full: ?bool,
    terminal_recent_input_force_full_ms: ?usize,
    editor_tab_bar_width_mode: ?TabBarWidthMode,
    terminal_tab_bar_show_single_tab: ?bool,
    terminal_tab_bar_width_mode: ?TabBarWidthMode,
    terminal_focus_report_window: ?bool,
    terminal_focus_report_pane: ?bool,
    font_lcd: ?bool,
    font_hinting: ?FontHinting,
    font_autohint: ?bool,
    font_glyph_overflow: ?GlyphOverflowPolicy,
    text_gamma: ?f32,
    text_contrast: ?f32,
    text_linear_correction: ?bool,
    theme: ?ThemeConfig,
    app_theme: ?ThemeConfig,
    editor_theme: ?ThemeConfig,
    terminal_theme: ?ThemeConfig,
    keybinds_no_defaults: ?bool,
    keybinds: ?[]input_actions.BindSpec,
};

pub const LoadConfigFn = fn (allocator: std.mem.Allocator) LuaConfigError!Config;
pub const EmptyConfigFn = fn () Config;
pub const FreeConfigFn = fn (allocator: std.mem.Allocator, config: *Config) void;
pub const ApplyThemeConfigFn = fn (theme: *Theme, overlay: ThemeConfig) void;

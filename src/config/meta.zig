const std = @import("std");
const iface = @import("lua_config_iface.zig");
const input_actions = @import("../input/input_actions.zig");
const shared_types = @import("../types/mod.zig");
const app_logger = @import("../app_logger.zig");
const term_types = @import("../terminal/model/types.zig");

pub const FieldMeta = struct {
    name: []const u8,
    type_expr: []const u8,
    doc: []const u8 = "",
    snippet_value: []const u8 = "nil",
};

pub const SectionMeta = struct {
    class_name: []const u8,
    doc: []const u8 = "",
    fields: []const FieldMeta,
};

pub const root_sections = [_]FieldMeta{
    .{ .name = "log", .type_expr = "string|string[]|ZideLogConfig", .doc = "File/console tag filter shorthand or nested log config.", .snippet_value = "{ enable = { \"app.core\" } }" },
    .{ .name = "logs", .type_expr = "ZideLogsConfig", .doc = "Structured logging levels, output modes, and grouped sinks.", .snippet_value = "{ file_level = \"info\", console_level = \"info\" }" },
    .{ .name = "sdl", .type_expr = "ZideSdlConfig", .doc = "SDL logging integration.", .snippet_value = "{ log_level = \"info\" }" },
    .{ .name = "theme", .type_expr = "ZideThemeConfig", .doc = "Shared base theme.", .snippet_value = "{ palette = {}, syntax = {} }" },
    .{ .name = "app", .type_expr = "ZideAppConfig", .doc = "App shell defaults and app-level theme override.", .snippet_value = "{ font = { path = \"assets/fonts/JetBrainsMonoNerdFont-Regular.ttf\", size = 16 } }" },
    .{ .name = "font_rendering", .type_expr = "ZideFontRenderingConfig", .doc = "Text rasterization and blending controls.", .snippet_value = "{ lcd = false, hinting = \"default\", autohint = false, glyph_overflow = \"when_followed_by_space\", text = { gamma = 1.0, contrast = 1.0, linear_correction = true } }" },
    .{ .name = "selection_overlay", .type_expr = "ZideSelectionOverlayConfig", .doc = "Shared selection overlay defaults.", .snippet_value = "{ smooth = true, corner_px = 1.0, pad_px = 1.0 }" },
    .{ .name = "editor", .type_expr = "ZideEditorConfig", .doc = "Editor-specific settings.", .snippet_value = "{ wrap = false }" },
    .{ .name = "terminal", .type_expr = "ZideTerminalConfig", .doc = "Terminal-specific settings.", .snippet_value = "{ blink = \"kitty\" }" },
    .{ .name = "keybinds", .type_expr = "ZideKeybindConfig", .doc = "Custom key bindings.", .snippet_value = "{ no_defaults = false, bindings = { { scope = \"global\", key = \"r\", mods = { \"ctrl\" }, action = \"reload_config\" } } }" },
    .{ .name = "log_file_filter", .type_expr = "string|string[]", .doc = "Legacy alias for file log filter.", .snippet_value = "\"none\"" },
    .{ .name = "log_console_filter", .type_expr = "string|string[]", .doc = "Legacy alias for console log filter.", .snippet_value = "\"none\"" },
    .{ .name = "editor_font_features", .type_expr = "string|string[]", .doc = "Legacy alias for editor font features.", .snippet_value = "{ \"liga\", \"calt\" }" },
    .{ .name = "terminal_font_features", .type_expr = "string|string[]", .doc = "Legacy alias for terminal font features.", .snippet_value = "{ \"liga\", \"calt\" }" },
};

pub const log_fields = [_]FieldMeta{
    .{ .name = "enable", .type_expr = "string|string[]", .doc = "Shared file + console filter shorthand.", .snippet_value = "{ \"app.core\", \"terminal.core\" }" },
    .{ .name = "file", .type_expr = "string|string[]", .doc = "File sink filter.", .snippet_value = "{ \"app.core\" }" },
    .{ .name = "console", .type_expr = "string|string[]", .doc = "Console sink filter.", .snippet_value = "{ \"app.core\" }" },
};

pub const logs_fields = [_]FieldMeta{
    .{ .name = "mode", .type_expr = "ZideOutputMode", .doc = "Shared output-mode default for file + console.", .snippet_value = "\"text\"" },
    .{ .name = "file_mode", .type_expr = "ZideOutputMode", .doc = "File sink output mode.", .snippet_value = "\"text\"" },
    .{ .name = "console_mode", .type_expr = "ZideOutputMode", .doc = "Console sink output mode.", .snippet_value = "\"text\"" },
    .{ .name = "file_level", .type_expr = "ZideLogLevel", .doc = "Default file log level.", .snippet_value = "\"info\"" },
    .{ .name = "console_level", .type_expr = "ZideLogLevel", .doc = "Default console log level.", .snippet_value = "\"info\"" },
    .{ .name = "file_levels", .type_expr = "table<string, ZideLogLevel>", .doc = "Per-tag file level overrides.", .snippet_value = "{ [\"terminal.ui.redraw\"] = \"debug\" }" },
    .{ .name = "console_levels", .type_expr = "table<string, ZideLogLevel>", .doc = "Per-tag console level overrides.", .snippet_value = "{ [\"terminal.ui.redraw\"] = \"error\" }" },
    .{ .name = "groups", .type_expr = "table<string, ZideLogGroupConfig>", .doc = "Additional grouped sink definitions.", .snippet_value = "{ terminal = { tags = { \"terminal.*\" }, file = \"zide-terminal.log\", mode = \"text\" } }" },
};

pub const log_group_fields = [_]FieldMeta{
    .{ .name = "tags", .type_expr = "string|string[]", .doc = "Exact tags and prefix.* patterns.", .snippet_value = "{ \"terminal.*\" }" },
    .{ .name = "file", .type_expr = "string", .doc = "Output file path.", .snippet_value = "\"zide-terminal.log\"" },
    .{ .name = "mode", .type_expr = "ZideOutputMode", .doc = "Grouped sink output mode.", .snippet_value = "\"text\"" },
};

pub const sdl_fields = [_]FieldMeta{
    .{ .name = "log_level", .type_expr = "ZideSdlLogLevel", .doc = "SDL log verbosity.", .snippet_value = "\"info\"" },
};

pub const theme_palette_fields = [_]FieldMeta{
    .{ .name = "background", .type_expr = "ZideColor", .snippet_value = "\"#222436\"" },
    .{ .name = "foreground", .type_expr = "ZideColor", .snippet_value = "\"#c8d3f5\"" },
    .{ .name = "selection", .type_expr = "ZideColor", .snippet_value = "\"#2d3f76\"" },
    .{ .name = "cursor", .type_expr = "ZideColor", .snippet_value = "\"#c8d3f5\"" },
    .{ .name = "link", .type_expr = "ZideColor", .snippet_value = "\"#4fd6be\"" },
    .{ .name = "line_number", .type_expr = "ZideColor", .snippet_value = "\"#545c7e\"" },
    .{ .name = "line_number_bg", .type_expr = "ZideColor", .snippet_value = "\"#1e2030\"" },
    .{ .name = "current_line", .type_expr = "ZideColor", .snippet_value = "\"#2f334d\"" },
    .{ .name = "ui_bar_bg", .type_expr = "ZideColor", .snippet_value = "\"#1e2030\"" },
    .{ .name = "ui_panel_bg", .type_expr = "ZideColor", .snippet_value = "\"#191B29\"" },
    .{ .name = "ui_panel_overlay", .type_expr = "ZideColor", .snippet_value = "\"#191B29EB\"" },
    .{ .name = "ui_hover", .type_expr = "ZideColor", .snippet_value = "\"#2f334d\"" },
    .{ .name = "ui_pressed", .type_expr = "ZideColor", .snippet_value = "\"#444a73\"" },
    .{ .name = "ui_tab_inactive_bg", .type_expr = "ZideColor", .snippet_value = "\"#222436\"" },
    .{ .name = "ui_accent", .type_expr = "ZideColor", .snippet_value = "\"#82aaff\"" },
    .{ .name = "ui_border", .type_expr = "ZideColor", .snippet_value = "\"#3b4261\"" },
    .{ .name = "ui_modified", .type_expr = "ZideColor", .snippet_value = "\"#ffc777\"" },
    .{ .name = "ui_text", .type_expr = "ZideColor", .snippet_value = "\"#c8d3f5\"" },
    .{ .name = "ui_text_inactive", .type_expr = "ZideColor", .snippet_value = "\"#828bb8\"" },
    .{ .name = "ui_window_control_fg", .type_expr = "ZideColor", .snippet_value = "\"#c8d3f5\"" },
    .{ .name = "color0", .type_expr = "ZideColor", .snippet_value = "\"#1b1d2b\"" },
    .{ .name = "color1", .type_expr = "ZideColor", .snippet_value = "\"#ff757f\"" },
    .{ .name = "color2", .type_expr = "ZideColor", .snippet_value = "\"#c3e88d\"" },
    .{ .name = "color3", .type_expr = "ZideColor", .snippet_value = "\"#ffc777\"" },
    .{ .name = "color4", .type_expr = "ZideColor", .snippet_value = "\"#82aaff\"" },
    .{ .name = "color5", .type_expr = "ZideColor", .snippet_value = "\"#c099ff\"" },
    .{ .name = "color6", .type_expr = "ZideColor", .snippet_value = "\"#86e1fc\"" },
    .{ .name = "color7", .type_expr = "ZideColor", .snippet_value = "\"#828bb8\"" },
    .{ .name = "color8", .type_expr = "ZideColor", .snippet_value = "\"#444a73\"" },
    .{ .name = "color9", .type_expr = "ZideColor", .snippet_value = "\"#ff8d94\"" },
    .{ .name = "color10", .type_expr = "ZideColor", .snippet_value = "\"#c7fb6d\"" },
    .{ .name = "color11", .type_expr = "ZideColor", .snippet_value = "\"#ffd8ab\"" },
    .{ .name = "color12", .type_expr = "ZideColor", .snippet_value = "\"#9ab8ff\"" },
    .{ .name = "color13", .type_expr = "ZideColor", .snippet_value = "\"#caabff\"" },
    .{ .name = "color14", .type_expr = "ZideColor", .snippet_value = "\"#b2ebff\"" },
    .{ .name = "color15", .type_expr = "ZideColor", .snippet_value = "\"#c8d3f5\"" },
};

pub const theme_syntax_fields = [_]FieldMeta{
    .{ .name = "comment", .type_expr = "ZideColor", .snippet_value = "\"#636da6\"" },
    .{ .name = "string", .type_expr = "ZideColor", .snippet_value = "\"#c3e88d\"" },
    .{ .name = "keyword", .type_expr = "ZideColor", .snippet_value = "\"#c099ff\"" },
    .{ .name = "number", .type_expr = "ZideColor", .snippet_value = "\"#ff966c\"" },
    .{ .name = "function", .type_expr = "ZideColor", .snippet_value = "\"#82aaff\"" },
    .{ .name = "variable", .type_expr = "ZideColor", .snippet_value = "\"#c8d3f5\"" },
    .{ .name = "type_name", .type_expr = "ZideColor", .snippet_value = "\"#86e1fc\"" },
    .{ .name = "operator", .type_expr = "ZideColor", .snippet_value = "\"#89ddff\"" },
    .{ .name = "builtin", .type_expr = "ZideColor", .snippet_value = "\"#86e1fc\"" },
    .{ .name = "punctuation", .type_expr = "ZideColor", .snippet_value = "\"#89ddff\"" },
    .{ .name = "constant", .type_expr = "ZideColor", .snippet_value = "\"#ff966c\"" },
    .{ .name = "attribute", .type_expr = "ZideColor", .snippet_value = "\"#c099ff\"" },
    .{ .name = "namespace", .type_expr = "ZideColor", .snippet_value = "\"#82aaff\"" },
    .{ .name = "label", .type_expr = "ZideColor", .snippet_value = "\"#ff966c\"" },
    .{ .name = "error", .type_expr = "ZideColor", .snippet_value = "\"#ff757f\"" },
};

pub const theme_fields = [_]FieldMeta{
    .{ .name = "palette", .type_expr = "ZideThemePalette", .doc = "Global palette and terminal ANSI colors.", .snippet_value = "{ background = \"#222436\" }" },
    .{ .name = "syntax", .type_expr = "ZideThemeSyntax", .doc = "Coarse editor syntax colors.", .snippet_value = "{ comment = \"#636da6\" }" },
};

pub const app_font_fields = [_]FieldMeta{
    .{ .name = "path", .type_expr = "string", .doc = "Font file path.", .snippet_value = "\"assets/fonts/JetBrainsMonoNerdFont-Regular.ttf\"" },
    .{ .name = "size", .type_expr = "number", .doc = "Font size in points.", .snippet_value = "16" },
};

pub const app_fields = [_]FieldMeta{
    .{ .name = "font", .type_expr = "ZideFontConfig", .doc = "Base app/UI font.", .snippet_value = "{ path = \"assets/fonts/JetBrainsMonoNerdFont-Regular.ttf\", size = 16 }" },
    .{ .name = "theme", .type_expr = "ZideThemeConfig", .doc = "App-specific theme overlay.", .snippet_value = "{ palette = {} }" },
};

pub const font_rendering_text_fields = [_]FieldMeta{
    .{ .name = "gamma", .type_expr = "number", .snippet_value = "1.0" },
    .{ .name = "contrast", .type_expr = "number", .snippet_value = "1.0" },
    .{ .name = "linear_correction", .type_expr = "boolean", .snippet_value = "true" },
};

pub const font_rendering_fields = [_]FieldMeta{
    .{ .name = "lcd", .type_expr = "boolean", .snippet_value = "false" },
    .{ .name = "hinting", .type_expr = "ZideFontHinting", .snippet_value = "\"default\"" },
    .{ .name = "autohint", .type_expr = "boolean", .snippet_value = "false" },
    .{ .name = "glyph_overflow", .type_expr = "ZideGlyphOverflowPolicy", .snippet_value = "\"when_followed_by_space\"" },
    .{ .name = "text", .type_expr = "ZideFontRenderingTextConfig", .snippet_value = "{ gamma = 1.0, contrast = 1.0, linear_correction = true }" },
};

pub const selection_overlay_fields = [_]FieldMeta{
    .{ .name = "smooth", .type_expr = "boolean", .snippet_value = "true" },
    .{ .name = "corner_px", .type_expr = "number", .snippet_value = "1.0" },
    .{ .name = "pad_px", .type_expr = "number", .snippet_value = "1.0" },
};

pub const editor_render_fields = [_]FieldMeta{
    .{ .name = "highlight_budget", .type_expr = "integer", .snippet_value = "0" },
    .{ .name = "width_budget", .type_expr = "integer", .snippet_value = "0" },
};

pub const manual_highlight_rule_fields = [_]FieldMeta{
    .{ .name = "extension", .type_expr = "string", .snippet_value = "\"log\"" },
    .{ .name = "parser", .type_expr = "string", .snippet_value = "\"comment\"" },
    .{ .name = "builtin", .type_expr = "string", .snippet_value = "\"log_levels\"" },
    .{ .name = "query_path", .type_expr = "string", .snippet_value = "\"queries/highlights.scm\"" },
    .{ .name = "mode", .type_expr = "ZideEditorManualHighlightMode", .snippet_value = "\"append\"" },
};

pub const manual_highlight_fallback_fields = [_]FieldMeta{
    .{ .name = "parser", .type_expr = "string", .snippet_value = "\"comment\"" },
    .{ .name = "builtin", .type_expr = "string", .snippet_value = "\"log_levels\"" },
    .{ .name = "query_path", .type_expr = "string", .snippet_value = "\"queries/highlights.scm\"" },
    .{ .name = "mode", .type_expr = "ZideEditorManualHighlightMode", .snippet_value = "\"append\"" },
};

pub const editor_theme_fields = [_]FieldMeta{
    .{ .name = "palette", .type_expr = "ZideThemePalette", .snippet_value = "{ background = \"#222436\" }" },
    .{ .name = "syntax", .type_expr = "ZideThemeSyntax", .snippet_value = "{ comment = \"#636da6\" }" },
    .{ .name = "groups", .type_expr = "table<string, ZideEditorHighlightGroup>", .snippet_value = "{ Comment = { fg = \"#636da6\", italic = true } }" },
    .{ .name = "captures", .type_expr = "table<string, ZideEditorHighlightGroup>", .snippet_value = "{ [\"@keyword.control\"] = { fg = \"#c099ff\" } }" },
    .{ .name = "links", .type_expr = "table<string, string>", .snippet_value = "{ Conditional = \"Keyword\" }" },
};

pub const editor_highlight_group_fields = [_]FieldMeta{
    .{ .name = "fg", .type_expr = "ZideColor", .snippet_value = "\"#c8d3f5\"" },
    .{ .name = "bg", .type_expr = "ZideColor", .snippet_value = "\"#222436\"" },
    .{ .name = "sp", .type_expr = "ZideColor", .snippet_value = "\"#ff757f\"" },
    .{ .name = "bold", .type_expr = "boolean", .snippet_value = "true" },
    .{ .name = "italic", .type_expr = "boolean", .snippet_value = "true" },
    .{ .name = "underline", .type_expr = "boolean", .snippet_value = "true" },
    .{ .name = "undercurl", .type_expr = "boolean", .snippet_value = "true" },
    .{ .name = "strikethrough", .type_expr = "boolean", .snippet_value = "true" },
    .{ .name = "reverse", .type_expr = "boolean", .snippet_value = "true" },
    .{ .name = "nocombine", .type_expr = "boolean", .snippet_value = "true" },
    .{ .name = "link", .type_expr = "string", .snippet_value = "\"Keyword\"" },
};

pub const editor_tab_bar_fields = [_]FieldMeta{
    .{ .name = "width_mode", .type_expr = "ZideTabBarWidthMode", .snippet_value = "\"dynamic\"" },
};

pub const editor_fields = [_]FieldMeta{
    .{ .name = "wrap", .type_expr = "boolean", .snippet_value = "false" },
    .{ .name = "imported_theme", .type_expr = "string", .snippet_value = "\"tokyonight-night\"" },
    .{ .name = "large_jump_rows", .type_expr = "integer", .snippet_value = "24" },
    .{ .name = "font", .type_expr = "ZideFontConfig", .snippet_value = "{ path = \"assets/fonts/JetBrainsMonoNerdFont-Regular.ttf\", size = 16 }" },
    .{ .name = "font_features", .type_expr = "string|string[]", .snippet_value = "{ \"liga\", \"calt\" }" },
    .{ .name = "disable_ligatures", .type_expr = "ZideLigatureStrategy", .snippet_value = "\"cursor\"" },
    .{ .name = "render", .type_expr = "ZideEditorRenderConfig", .snippet_value = "{ highlight_budget = 0, width_budget = 0 }" },
    .{ .name = "theme", .type_expr = "ZideEditorThemeConfig", .snippet_value = "{ syntax = {} }" },
    .{ .name = "selection_overlay", .type_expr = "ZideSelectionOverlayConfig", .snippet_value = "{ smooth = true, corner_px = 1.0, pad_px = 1.0 }" },
    .{ .name = "manual_highlight", .type_expr = "ZideManualHighlightConfig", .snippet_value = "{ rules = { { extension = \"log\", parser = \"comment\" } } }" },
    .{ .name = "tab_bar", .type_expr = "ZideEditorTabBarConfig", .snippet_value = "{ width_mode = \"dynamic\" }" },
};

pub const manual_highlight_fields = [_]FieldMeta{
    .{ .name = "rules", .type_expr = "ZideEditorManualHighlightRule[]", .snippet_value = "{ { extension = \"log\", parser = \"comment\" } }" },
    .{ .name = "unsupported", .type_expr = "ZideEditorManualHighlightFallback", .snippet_value = "{ parser = \"comment\" }" },
};

pub const terminal_shell_fields = [_]FieldMeta{
    .{ .name = "path", .type_expr = "string", .snippet_value = "\"/bin/bash\"" },
    .{ .name = "default_start_location", .type_expr = "string", .snippet_value = "\"~\"" },
    .{ .name = "new_tab_start_location", .type_expr = "ZideTerminalNewTabStartLocationMode", .snippet_value = "\"current\"" },
};

pub const terminal_tab_bar_shell_icon_fields = [_]FieldMeta{
    .{ .name = "shell", .type_expr = "string", .snippet_value = "\"bash\"" },
    .{ .name = "icon_path", .type_expr = "string", .snippet_value = "\"assets/icons/bash.svg\"" },
};

pub const terminal_tab_bar_fields = [_]FieldMeta{
    .{ .name = "show_single_tab", .type_expr = "boolean", .snippet_value = "false" },
    .{ .name = "width_mode", .type_expr = "ZideTabBarWidthMode", .snippet_value = "\"dynamic\"" },
    .{ .name = "show_shell_icon", .type_expr = "boolean", .snippet_value = "true" },
    .{ .name = "shell_icons", .type_expr = "table<string, string>|ZideTerminalShellIconMapping[]", .snippet_value = "{ bash = \"assets/icons/bash.svg\" }" },
};

pub const terminal_window_chrome_fields = [_]FieldMeta{
    .{ .name = "mode", .type_expr = "ZideTerminalWindowChromeMode", .snippet_value = "\"native\"" },
};

pub const terminal_fields = [_]FieldMeta{
    .{ .name = "font", .type_expr = "ZideFontConfig", .snippet_value = "{ path = \"assets/fonts/IosevkaTermNerdFont-Regular.ttf\", size = 16 }" },
    .{ .name = "font_features", .type_expr = "string|string[]", .snippet_value = "{ \"liga\", \"calt\" }" },
    .{ .name = "disable_ligatures", .type_expr = "ZideLigatureStrategy", .snippet_value = "\"cursor\"" },
    .{ .name = "blink", .type_expr = "boolean|ZideTerminalBlinkStyle", .snippet_value = "\"kitty\"" },
    .{ .name = "scrollback_rows", .type_expr = "integer", .snippet_value = "10000" },
    .{ .name = "cursor_shape", .type_expr = "ZideTerminalCursorShape", .snippet_value = "\"block\"" },
    .{ .name = "cursor_blink", .type_expr = "boolean", .snippet_value = "true" },
    .{ .name = "texture_shift", .type_expr = "boolean", .snippet_value = "false" },
    .{ .name = "recent_input_force_full", .type_expr = "boolean", .snippet_value = "false" },
    .{ .name = "recent_input_force_full_ms", .type_expr = "integer", .snippet_value = "120" },
    .{ .name = "focus_report_window", .type_expr = "boolean", .snippet_value = "false" },
    .{ .name = "focus_report_pane", .type_expr = "boolean", .snippet_value = "false" },
    .{ .name = "shell", .type_expr = "ZideTerminalShellConfig", .snippet_value = "{ path = \"/bin/bash\", default_start_location = \"~\", new_tab_start_location = \"current\" }" },
    .{ .name = "window_chrome", .type_expr = "ZideTerminalWindowChromeConfig", .snippet_value = "{ mode = \"native\" }" },
    .{ .name = "tab_bar", .type_expr = "ZideTerminalTabBarConfig", .snippet_value = "{ show_single_tab = false, width_mode = \"dynamic\" }" },
    .{ .name = "theme", .type_expr = "ZideThemeConfig", .snippet_value = "{ palette = {} }" },
    .{ .name = "selection_overlay", .type_expr = "ZideSelectionOverlayConfig", .snippet_value = "{ smooth = true, corner_px = 1.0, pad_px = 1.0 }" },
};

pub const keybind_item_fields = [_]FieldMeta{
    .{ .name = "scope", .type_expr = "ZideBindScope", .snippet_value = "\"global\"" },
    .{ .name = "key", .type_expr = "ZideKey", .snippet_value = "\"r\"" },
    .{ .name = "mods", .type_expr = "ZideModFlag[]", .snippet_value = "{ \"ctrl\" }" },
    .{ .name = "action", .type_expr = "ZideActionKind", .snippet_value = "\"reload_config\"" },
    .{ .name = "repeat", .type_expr = "boolean", .snippet_value = "false" },
};

pub const keybind_fields = [_]FieldMeta{
    .{ .name = "no_defaults", .type_expr = "boolean", .snippet_value = "false" },
    .{ .name = "bindings", .type_expr = "ZideKeybindItem[]", .snippet_value = "{ { scope = \"global\", key = \"r\", mods = { \"ctrl\" }, action = \"reload_config\" } }" },
};

pub const sections = [_]SectionMeta{
    .{ .class_name = "ZideLogConfig", .fields = &log_fields },
    .{ .class_name = "ZideLogsConfig", .fields = &logs_fields },
    .{ .class_name = "ZideLogGroupConfig", .fields = &log_group_fields },
    .{ .class_name = "ZideSdlConfig", .fields = &sdl_fields },
    .{ .class_name = "ZideThemePalette", .fields = &theme_palette_fields },
    .{ .class_name = "ZideThemeSyntax", .fields = &theme_syntax_fields },
    .{ .class_name = "ZideThemeConfig", .fields = &theme_fields },
    .{ .class_name = "ZideFontConfig", .fields = &app_font_fields },
    .{ .class_name = "ZideAppConfig", .fields = &app_fields },
    .{ .class_name = "ZideFontRenderingTextConfig", .fields = &font_rendering_text_fields },
    .{ .class_name = "ZideFontRenderingConfig", .fields = &font_rendering_fields },
    .{ .class_name = "ZideSelectionOverlayConfig", .fields = &selection_overlay_fields },
    .{ .class_name = "ZideEditorRenderConfig", .fields = &editor_render_fields },
    .{ .class_name = "ZideEditorManualHighlightRule", .fields = &manual_highlight_rule_fields },
    .{ .class_name = "ZideEditorManualHighlightFallback", .fields = &manual_highlight_fallback_fields },
    .{ .class_name = "ZideEditorHighlightGroup", .fields = &editor_highlight_group_fields },
    .{ .class_name = "ZideEditorThemeConfig", .fields = &editor_theme_fields },
    .{ .class_name = "ZideEditorTabBarConfig", .fields = &editor_tab_bar_fields },
    .{ .class_name = "ZideManualHighlightConfig", .fields = &manual_highlight_fields },
    .{ .class_name = "ZideEditorConfig", .fields = &editor_fields },
    .{ .class_name = "ZideTerminalShellConfig", .fields = &terminal_shell_fields },
    .{ .class_name = "ZideTerminalShellIconMapping", .fields = &terminal_tab_bar_shell_icon_fields },
    .{ .class_name = "ZideTerminalTabBarConfig", .fields = &terminal_tab_bar_fields },
    .{ .class_name = "ZideTerminalWindowChromeConfig", .fields = &terminal_window_chrome_fields },
    .{ .class_name = "ZideTerminalConfig", .fields = &terminal_fields },
    .{ .class_name = "ZideKeybindItem", .fields = &keybind_item_fields },
    .{ .class_name = "ZideKeybindConfig", .fields = &keybind_fields },
};

pub const LogLevel = app_logger.Level;
pub const OutputMode = app_logger.OutputMode;
pub const FontHinting = iface.FontHinting;
pub const GlyphOverflowPolicy = iface.GlyphOverflowPolicy;
pub const TerminalBlinkStyle = iface.TerminalBlinkStyle;
pub const LigatureStrategy = iface.TerminalDisableLigaturesStrategy;
pub const TerminalNewTabStartLocationMode = iface.TerminalNewTabStartLocationMode;
pub const TerminalWindowChromeMode = iface.TerminalWindowChromeMode;
pub const TabBarWidthMode = iface.TabBarWidthMode;
pub const EditorManualHighlightMode = iface.EditorManualHighlightMode;
pub const BindScope = input_actions.BindScope;
pub const ActionKind = input_actions.ActionKind;
pub const Key = shared_types.input.Key;
pub const TerminalCursorShape = term_types.CursorShape;

pub const mod_flags = [_][]const u8{ "shift", "alt", "ctrl", "super", "altgr" };
pub const sdl_log_levels = [_][]const u8{ "none", "critical", "error", "warning", "warn", "info", "debug", "trace" };

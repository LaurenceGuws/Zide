---@meta

---@alias ZideColor string|{ r: integer, g: integer, b: integer, a?: integer }
---@alias ZideLogLevel "critical" | "error" | "warning" | "info" | "debug" | "trace"
---@alias ZideOutputMode "text" | "jsonl"
---@alias ZideFontHinting "default" | "none" | "light" | "normal"
---@alias ZideGlyphOverflowPolicy "when_followed_by_space" | "never" | "always"
---@alias ZideTerminalBlinkStyle "kitty" | "off"
---@alias ZideLigatureStrategy "never" | "cursor" | "always"
---@alias ZideTerminalNewTabStartLocationMode "current" | "default"
---@alias ZideTerminalWindowChromeMode "native" | "integrated"
---@alias ZideTabBarWidthMode "fixed" | "dynamic" | "label_length"
---@alias ZideEditorManualHighlightMode "replace" | "append" | "prepend"
---@alias ZideBindScope "global" | "editor" | "terminal"
---@alias ZideActionKind "none" | "copy" | "paste" | "zoom_in" | "zoom_out" | "zoom_reset" | "new_editor" | "open_file" | "close_editor" | "next_document" | "prev_document" | "toggle_terminal" | "quit_app" | "save" | "save_as" | "undo" | "redo" | "cut" | "select_all" | "delete_line" | "duplicate_line" | "indent_lines" | "outdent_lines" | "go_to_line" | "reload_config" | "terminal_scrollback_pager" | "terminal_new_tab" | "terminal_close_tab" | "terminal_next_tab" | "terminal_prev_tab" | "terminal_focus_tab_1" | "terminal_focus_tab_2" | "terminal_focus_tab_3" | "terminal_focus_tab_4" | "terminal_focus_tab_5" | "terminal_focus_tab_6" | "terminal_focus_tab_7" | "terminal_focus_tab_8" | "terminal_focus_tab_9" | "editor_add_caret_up" | "editor_add_caret_down" | "editor_move_word_left" | "editor_move_word_right" | "editor_move_large_up" | "editor_move_large_down" | "editor_extend_left" | "editor_extend_right" | "editor_extend_line_start" | "editor_extend_line_end" | "editor_extend_word_left" | "editor_extend_word_right" | "editor_extend_up" | "editor_extend_down" | "editor_extend_large_up" | "editor_extend_large_down" | "editor_search_open" | "editor_replace_open" | "editor_search_next" | "editor_search_prev" | "editor_cycle_imported_theme_prev" | "editor_cycle_imported_theme_next"
---@alias ZideKey "unknown" | "enter" | "backspace" | "tab" | "escape" | "up" | "down" | "left" | "right" | "home" | "end" | "page_up" | "page_down" | "insert" | "delete" | "f1" | "f2" | "f3" | "f4" | "f5" | "f6" | "f7" | "f8" | "f9" | "f10" | "f11" | "f12" | "a" | "b" | "c" | "d" | "e" | "f" | "g" | "h" | "i" | "j" | "k" | "l" | "m" | "n" | "o" | "p" | "q" | "r" | "s" | "t" | "u" | "v" | "w" | "x" | "y" | "z" | "zero" | "one" | "two" | "three" | "four" | "five" | "six" | "seven" | "eight" | "nine" | "space" | "minus" | "equal" | "left_bracket" | "right_bracket" | "backslash" | "semicolon" | "apostrophe" | "comma" | "period" | "slash" | "grave" | "kp_0" | "kp_1" | "kp_2" | "kp_3" | "kp_4" | "kp_5" | "kp_6" | "kp_7" | "kp_8" | "kp_9" | "kp_decimal" | "kp_divide" | "kp_multiply" | "kp_subtract" | "kp_add" | "kp_enter" | "kp_equal" | "left_shift" | "right_shift" | "left_ctrl" | "right_ctrl" | "left_alt" | "right_alt" | "left_super" | "right_super"
---@alias ZideModFlag "shift" | "alt" | "ctrl" | "super" | "altgr"
---@alias ZideTerminalCursorShape "block" | "underline" | "bar"
---@alias ZideSdlLogLevel "none" | "critical" | "error" | "warning" | "warn" | "info" | "debug" | "trace"

---@class ZideLogConfig
---@field enable? string|string[] Shared file + console filter shorthand.
---@field file? string|string[] File sink filter.
---@field console? string|string[] Console sink filter.

---@class ZideLogsConfig
---@field mode? ZideOutputMode Shared output-mode default for file + console.
---@field file_mode? ZideOutputMode File sink output mode.
---@field console_mode? ZideOutputMode Console sink output mode.
---@field file_level? ZideLogLevel Default file log level.
---@field console_level? ZideLogLevel Default console log level.
---@field file_levels? table<string, ZideLogLevel> Per-tag file level overrides.
---@field console_levels? table<string, ZideLogLevel> Per-tag console level overrides.
---@field groups? table<string, ZideLogGroupConfig> Additional grouped sink definitions.

---@class ZideLogGroupConfig
---@field tags? string|string[] Exact tags and prefix.* patterns.
---@field file? string Output file path.
---@field mode? ZideOutputMode Grouped sink output mode.

---@class ZideSdlConfig
---@field log_level? ZideSdlLogLevel SDL log verbosity.

---@class ZideThemePalette
---@field background? ZideColor
---@field foreground? ZideColor
---@field selection? ZideColor
---@field cursor? ZideColor
---@field link? ZideColor
---@field line_number? ZideColor
---@field line_number_bg? ZideColor
---@field current_line? ZideColor
---@field ui_bar_bg? ZideColor
---@field ui_panel_bg? ZideColor
---@field ui_panel_overlay? ZideColor
---@field ui_hover? ZideColor
---@field ui_pressed? ZideColor
---@field ui_tab_inactive_bg? ZideColor
---@field ui_accent? ZideColor
---@field ui_border? ZideColor
---@field ui_modified? ZideColor
---@field ui_text? ZideColor
---@field ui_text_inactive? ZideColor
---@field ui_window_control_fg? ZideColor
---@field color0? ZideColor
---@field color1? ZideColor
---@field color2? ZideColor
---@field color3? ZideColor
---@field color4? ZideColor
---@field color5? ZideColor
---@field color6? ZideColor
---@field color7? ZideColor
---@field color8? ZideColor
---@field color9? ZideColor
---@field color10? ZideColor
---@field color11? ZideColor
---@field color12? ZideColor
---@field color13? ZideColor
---@field color14? ZideColor
---@field color15? ZideColor

---@class ZideThemeSyntax
---@field comment? ZideColor
---@field string? ZideColor
---@field keyword? ZideColor
---@field number? ZideColor
---@field function? ZideColor
---@field variable? ZideColor
---@field type_name? ZideColor
---@field operator? ZideColor
---@field builtin? ZideColor
---@field punctuation? ZideColor
---@field constant? ZideColor
---@field attribute? ZideColor
---@field namespace? ZideColor
---@field label? ZideColor
---@field error? ZideColor

---@class ZideThemeConfig
---@field palette? ZideThemePalette Global palette and terminal ANSI colors.
---@field syntax? ZideThemeSyntax Coarse editor syntax colors.

---@class ZideFontConfig
---@field path? string Font file path.
---@field size? number Font size in points.

---@class ZideAppConfig
---@field font? ZideFontConfig Base app/UI font.
---@field theme? ZideThemeConfig App-specific theme overlay.

---@class ZideFontRenderingTextConfig
---@field gamma? number
---@field contrast? number
---@field linear_correction? boolean

---@class ZideFontRenderingConfig
---@field lcd? boolean
---@field hinting? ZideFontHinting
---@field autohint? boolean
---@field glyph_overflow? ZideGlyphOverflowPolicy
---@field text? ZideFontRenderingTextConfig

---@class ZideSelectionOverlayConfig
---@field smooth? boolean
---@field corner_px? number
---@field pad_px? number

---@class ZideEditorRenderConfig
---@field highlight_budget? integer
---@field width_budget? integer

---@class ZideEditorManualHighlightRule
---@field extension? string
---@field parser? string
---@field builtin? string
---@field query_path? string
---@field mode? ZideEditorManualHighlightMode

---@class ZideEditorManualHighlightFallback
---@field parser? string
---@field builtin? string
---@field query_path? string
---@field mode? ZideEditorManualHighlightMode

---@class ZideEditorHighlightGroup
---@field fg? ZideColor
---@field bg? ZideColor
---@field sp? ZideColor
---@field bold? boolean
---@field italic? boolean
---@field underline? boolean
---@field undercurl? boolean
---@field strikethrough? boolean
---@field reverse? boolean
---@field nocombine? boolean
---@field link? string

---@class ZideEditorThemeConfig
---@field palette? ZideThemePalette
---@field syntax? ZideThemeSyntax
---@field groups? table<string, ZideEditorHighlightGroup>
---@field captures? table<string, ZideEditorHighlightGroup>
---@field links? table<string, string>

---@class ZideEditorTabBarConfig
---@field width_mode? ZideTabBarWidthMode

---@class ZideManualHighlightConfig
---@field rules? ZideEditorManualHighlightRule[]
---@field unsupported? ZideEditorManualHighlightFallback

---@class ZideEditorConfig
---@field wrap? boolean
---@field imported_theme? string
---@field large_jump_rows? integer
---@field font? ZideFontConfig
---@field font_features? string|string[]
---@field disable_ligatures? ZideLigatureStrategy
---@field render? ZideEditorRenderConfig
---@field theme? ZideEditorThemeConfig
---@field selection_overlay? ZideSelectionOverlayConfig
---@field manual_highlight? ZideManualHighlightConfig
---@field tab_bar? ZideEditorTabBarConfig

---@class ZideTerminalShellConfig
---@field path? string
---@field default_start_location? string
---@field new_tab_start_location? ZideTerminalNewTabStartLocationMode

---@class ZideTerminalShellIconMapping
---@field shell? string
---@field icon_path? string

---@class ZideTerminalTabBarConfig
---@field show_single_tab? boolean
---@field width_mode? ZideTabBarWidthMode
---@field show_shell_icon? boolean
---@field shell_icons? table<string, string>|ZideTerminalShellIconMapping[]

---@class ZideTerminalWindowChromeConfig
---@field mode? ZideTerminalWindowChromeMode

---@class ZideTerminalConfig
---@field font? ZideFontConfig
---@field font_features? string|string[]
---@field disable_ligatures? ZideLigatureStrategy
---@field blink? boolean|ZideTerminalBlinkStyle
---@field scrollback_rows? integer
---@field cursor_shape? ZideTerminalCursorShape
---@field cursor_blink? boolean
---@field texture_shift? boolean
---@field recent_input_force_full? boolean
---@field recent_input_force_full_ms? integer
---@field focus_report_window? boolean
---@field focus_report_pane? boolean
---@field shell? ZideTerminalShellConfig
---@field window_chrome? ZideTerminalWindowChromeConfig
---@field tab_bar? ZideTerminalTabBarConfig
---@field theme? ZideThemeConfig
---@field selection_overlay? ZideSelectionOverlayConfig

---@class ZideKeybindItem
---@field scope? ZideBindScope
---@field key? ZideKey
---@field mods? ZideModFlag[]
---@field action? ZideActionKind
---@field repeat? boolean

---@class ZideKeybindConfig
---@field no_defaults? boolean
---@field bindings? ZideKeybindItem[]

---@class ZideConfig
---@field log? string|string[]|ZideLogConfig File/console tag filter shorthand or nested log config.
---@field logs? ZideLogsConfig Structured logging levels, output modes, and grouped sinks.
---@field sdl? ZideSdlConfig SDL logging integration.
---@field theme? ZideThemeConfig Shared base theme.
---@field app? ZideAppConfig App shell defaults and app-level theme override.
---@field font_rendering? ZideFontRenderingConfig Text rasterization and blending controls.
---@field selection_overlay? ZideSelectionOverlayConfig Shared selection overlay defaults.
---@field editor? ZideEditorConfig Editor-specific settings.
---@field terminal? ZideTerminalConfig Terminal-specific settings.
---@field keybinds? ZideKeybindConfig Custom key bindings.
---@field log_file_filter? string|string[] Legacy alias for file log filter.
---@field log_console_filter? string|string[] Legacy alias for console log filter.
---@field editor_font_features? string|string[] Legacy alias for editor font features.
---@field terminal_font_features? string|string[] Legacy alias for terminal font features.

---@class ZideModule
---@field config fun(opts: ZideConfig): ZideConfig

---@type ZideModule
local zide = {
  config = function(opts)
    return opts
  end,
}

return zide

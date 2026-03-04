-- Zide default config reference (loaded as system defaults).
-- This file doubles as documentation; values here are active defaults.
-- Copy it to ~/.config/zide/init.lua or ./.zide.lua to customize.

local function file_exists(path)
    local f = io.open(path, "r")
    if f ~= nil then
        f:close()
        return true
    end
    return false
end

local home = os.getenv("HOME") or ""
local theme_import_ok, theme_import = pcall(dofile, "assets/config/theme_import.lua")
local kitty_theme = nil

if theme_import_ok and type(theme_import) == "table" and type(theme_import.from_kitty) == "function" then
    local kitty_theme_path = home .. "/.config/kitty/current-theme.conf"
    local import_ok, imported_theme = pcall(theme_import.from_kitty, kitty_theme_path)
    if import_ok and type(imported_theme) == "table" then
        kitty_theme = imported_theme
    end
end

local app_font_path = "assets/fonts/JetBrainsMonoNerdFont-Regular.ttf"
if file_exists("assets/fonts/IosevkaTermNerdFont-Regular.ttf") then
    app_font_path = "assets/fonts/IosevkaTermNerdFont-Regular.ttf"
end

return {
    -- Logging configuration.
    -- Options:
    --   log = "all" / "none" / "app.core,editor.core,editor.input,editor.highlight,terminal.core,terminal.metrics,terminal.alt,terminal.font,terminal.font.jitter,ui.zoom.shortcut,terminal.io,terminal.csi,terminal.sgr,terminal.osc,terminal.replay" (comma-separated)
    --   log = "all" / "none" / "... ,editor.perf" for file load + rope init timings
    --   log = { enable = { "app.core", "editor.core", "editor.input", "editor.highlight", "terminal.core", "terminal.metrics", "terminal.alt", "terminal.font", "terminal.font.jitter", "ui.zoom.shortcut", "terminal.io", "terminal.csi", "terminal.sgr", "terminal.osc", "terminal.replay" } }
    --   log = { file = { ... }, console = { ... } }
    -- If file/console are not set, enable is used for both.
    log = {
        enable = { "app.core", "terminal.core", "ui.zoom.shortcut" },
        -- file = { "terminal.metrics" },
        -- console = { "app.core" },
    },
    -- terminal.font.jitter is gated by env: ZIDE_TERMINAL_FONT_JITTER=1

    -- SDL logging configuration.
    -- log_level options: "none", "critical", "error", "warning", "warn", "info", "debug", "trace"
    sdl = {
        log_level = "info",
    },

    -- Theme configuration.
    -- Colors accept hex strings (#RRGGBB or #RRGGBBAA) or tables { r = 0, g = 0, b = 0, a = 255 }.
    -- Optional importer helper:
    --   local theme_import = dofile("assets/config/theme_import.lua")
    --   local ghostty_theme = theme_import.from_ghostty("/path/to/ghostty/theme")
    --   local kitty_theme = theme_import.from_kitty("/path/to/kitty.conf")
    --   theme = theme_import.merge(ghostty_theme, { syntax = { comment = "#6f7a94" } })
    
    -- Tokyo Night Moon palette defaults.
    theme = kitty_theme or {
        palette = {
            background = "#222436",
            foreground = "#c8d3f5",
            selection = "#2d3f76",
            cursor = "#c8d3f5",
            link = "#4fd6be",
            line_number = "#545c7e",
            line_number_bg = "#1e2030",
            current_line = "#2f334d",
            ui_bar_bg = "#1e2030",
            ui_panel_bg = "#191B29",
            ui_panel_overlay = "#191B29EB",
            ui_hover = "#2f334d",
            ui_pressed = "#444a73",
            ui_tab_inactive_bg = "#222436",
            ui_accent = "#82aaff",
            ui_border = "#3b4261",
            ui_modified = "#ffc777",
            ui_text = "#c8d3f5",
            ui_text_inactive = "#828bb8",
            color0 = "#1b1d2b",
            color1 = "#ff757f",
            color2 = "#c3e88d",
            color3 = "#ffc777",
            color4 = "#82aaff",
            color5 = "#c099ff",
            color6 = "#86e1fc",
            color7 = "#828bb8",
            color8 = "#444a73",
            color9 = "#ff8d94",
            color10 = "#c7fb6d",
            color11 = "#ffd8ab",
            color12 = "#9ab8ff",
            color13 = "#caabff",
            color14 = "#b2ebff",
            color15 = "#c8d3f5",
        },
        syntax = {
            comment = "#636da6",
            string = "#c3e88d",
            keyword = "#c099ff",
            number = "#ff966c",
            ["function"] = "#82aaff",
            variable = "#c8d3f5",
            type_name = "#86e1fc",
            operator = "#89ddff",
            builtin = "#86e1fc",
            punctuation = "#89ddff",
            constant = "#ff966c",
            attribute = "#c099ff",
            namespace = "#82aaff",
            label = "#ff966c",
            error = "#ff757f",
        },
    },

    -- Tokyo Night Day palette defaults.
    -- theme = {
    --     palette = {
    --         background = "#e1e2e7",
    --         foreground = "#1f2335",
    --         selection = "#b7c1e3",
    --         cursor = "#1f2335",
    --         link = "#387068",
    --         line_number = "#6b7394",
    --         line_number_bg = "#d0d5e3",
    --         current_line = "#c4c8da",
    --         ui_bar_bg = "#d0d5e3",
    --         ui_panel_bg = "#c4c8da",
    --         ui_panel_overlay = "#c4c8daEB",
    --         ui_hover = "#b7c1e3",
    --         ui_pressed = "#a1a6c5",
    --         ui_tab_inactive_bg = "#e1e2e7",
    --         ui_accent = "#2e7de9",
    --         ui_border = "#8990b3",
    --         ui_modified = "#8c6c3e",
    --         ui_text = "#1f2335",
    --         ui_text_inactive = "#4c5a91",
    --         color0 = "#b4b5b9",
    --         color1 = "#f52a65",
    --         color2 = "#587539",
    --         color3 = "#8c6c3e",
    --         color4 = "#2e7de9",
    --         color5 = "#9854f1",
    --         color6 = "#007197",
    --         color7 = "#6172b0",
    --         color8 = "#a1a6c5",
    --         color9 = "#ff4774",
    --         color10 = "#5c8524",
    --         color11 = "#a27629",
    --         color12 = "#358aff",
    --         color13 = "#a463ff",
    --         color14 = "#007ea8",
    --         color15 = "#3760bf",
    --     },
    --     syntax = {
    --         comment = "#848cb5",
    --         string = "#587539",
    --         keyword = "#9854f1",
    --         number = "#b15c00",
    --         ["function"] = "#2e7de9",
    --         variable = "#3760bf",
    --         type_name = "#007197",
    --         operator = "#007197",
    --         builtin = "#007197",
    --         punctuation = "#007197",
    --         constant = "#b15c00",
    --         attribute = "#9854f1",
    --         namespace = "#2e7de9",
    --         label = "#b15c00",
    --         error = "#f52a65",
    --     },
    -- },

    -- App shell configuration.
    -- Current runtime uses one effective font stack across app/editor/terminal.
    -- If multiple font blocks are set, precedence is: terminal.font > editor.font > app.font.
    app = {
        -- App-specific theme override (affects UI chrome: tabs, status bar, side nav).
        -- theme = {
        --     palette = { background = "#1E222A" },
        -- },
        font = {
            path = app_font_path,
            size = 16,
        },
    },

    -- Font rendering configuration.
    -- These settings affect rasterization/shaping and text blending quality.
    -- Changes can be reloaded; font path/size changes are still restart-oriented.
    font_rendering = {
        -- Rasterization
        -- lcd: enable subpixel (LCD) rendering path. Not final; use cautiously.
        lcd = false,
        -- hinting: "default", "none", "light", "normal"
        hinting = "default",
        -- autohint: force FreeType autohinter
        autohint = false,
        -- glyph_overflow: "when_followed_by_space" (default), "never", "always"
        glyph_overflow = "when_followed_by_space",

        -- Coverage/text blending
        text = {
            -- gamma and contrast are applied to the coverage (mask) atlas.
            gamma = 1.0,
            contrast = 1.0,
            -- Linear correction improves small text in the linear blending path.
            linear_correction = true,
        },
    },

    -- Editor configuration.
    editor = {
        -- Editor-specific theme override.
        -- theme = {
        --     palette = { background = "#2E3440" },
        --     groups = {
        --         Comment = "#6f7a94",
        --         Function = { fg = "#82aaff" },
        --     },
        --     captures = {
        --         ["@keyword.control"] = "#c099ff",
        --         ["@function.method"] = { link = "Function" },
        --     },
        --     links = {
        --         Statement = "Keyword",
        --         ["@variable"] = "Statement",
        --     },
        -- },
        -- Number of visual rows used by Ctrl+Up/Down and Ctrl+Shift+Up/Down.
        large_cursor_jump_rows = 5,
        -- Soft wrap long lines.
        wrap = false,
        -- Ligature strategy (matches terminal semantics):
        --   "never"  = never disable ligatures (default)
        --   "cursor" = disable programming ligatures under cursor segment
        --   "always" = always disable programming ligatures
        disable_ligatures = "never",
        -- Optional editor-specific shaping features (falls back to terminal.font_features when unset).
        -- Examples:
        -- font_features = "+calt"
        -- font_features = "-calt,-liga"
        -- font_features = { "+calt", "-liga" }
        -- font_features = "+calt",
        -- Render work budgets (lines per frame). Set to 0 to disable precompute.
        render = {
            -- highlight_budget = 120,
            -- width_budget = 120,
        },
        -- Optional override. Current runtime still resolves one shared effective font
        -- stack using precedence: terminal.font > editor.font > app.font.
        -- font = { path = "/usr/share/fonts/...", size = 16 },
    },

    -- Terminal configuration.
    terminal = {
        -- Terminal-specific theme override.
        -- Supports full terminal palette overrides suitable for kitty/ghostty style themes.
        -- You can use:
        --   palette.color0..palette.color15
        --   palette.ansi = { "#..", ... }            -- 1..16 => color0..color15
        --   palette.ansi = { black = "#..", bright_red = "#.." }
        --   palette.selection_background = "#.."      -- alias of `selection`
        -- theme = {
        --     palette = { background = "#000000" },
        -- },
        theme = kitty_theme,

        -- Optional override. Current runtime still resolves one shared effective font
        -- stack using precedence: terminal.font > editor.font > app.font.
        -- font = { path = "/usr/share/fonts/...", size = 16 },

        -- Ligature strategy (kitty-style semantics):
        --   "never"  = never disable ligatures (default)
        --   "cursor" = disable programming ligatures under cursor
        --   "always" = always disable programming ligatures
        disable_ligatures = "never",

        -- Extra OpenType features passed to HarfBuzz for terminal shaping.
        -- String or string-list table. Examples:
        --   font_features = "-calt"
        --   font_features = "-calt,-liga,-dlig"
        --   font_features = { "+calt", "-liga" }
        -- font_features = "+calt",

        -- Blink style: "kitty" (default) or "off".
        -- blink = "kitty",
        -- Scrollback line cap (min 100, max 100000). Invalid values warn and fall back to 1000.
        scrollback = 1000,
        -- Cursor configuration.
        -- Valid shapes: "block", "underline", "bar". Blink is boolean.
        -- Invalid values warn and fall back to block/true.
        cursor = { shape = "bar", blink = true },

        -- Focus reporting source controls for CSI ?1004 event emission.
        -- Boolean shorthand applies to both sources:
        --   focus_reporting = true   -- enable window + pane focus events
        --   focus_reporting = false  -- disable window + pane focus events
        -- Table form controls each source independently.
        -- Defaults: window = true, pane = false
        focus_reporting = {
            window = true,  -- SDL window focus gain/loss
            pane = false,   -- terminal pane focus within the IDE
        },
    },

    -- Keybindings (keycode-based). Key names match `shared_types.input.Key` tags.
    -- Supported mods: "ctrl", "shift", "alt", "super", "altgr".
    -- "altgr" is an advanced desktop/layout-specific modifier; use it deliberately.
    -- Example:
    --   { key = "b", mods = { "ctrl" }, action = "toggle_terminal" }
    -- Use ["repeat"] = true for repeatable actions (zoom, undo).
    -- By default user/project configs fill gaps on top of these bindings.
    -- Set `no_defaults = true` in an override config to replace the default set entirely.
    keybinds = {
        -- no_defaults = false,
        global = {
            -- Config hot reload.
            { key = "n", mods = { "ctrl" }, action = "new_editor" },
            { key = "equal", mods = { "ctrl" }, action = "zoom_in", ["repeat"] = true },
            { key = "kp_add", mods = { "ctrl" }, action = "zoom_in", ["repeat"] = true },
            { key = "minus", mods = { "ctrl" }, action = "zoom_out", ["repeat"] = true },
            { key = "kp_subtract", mods = { "ctrl" }, action = "zoom_out", ["repeat"] = true },
            { key = "zero", mods = { "ctrl" }, action = "zoom_reset" },
            { key = "grave", mods = { "ctrl" }, action = "toggle_terminal" },
            { key = "f5", mods = { "ctrl", "shift" }, action = "reload_config" },
        },
        editor = {
            { key = "s", mods = { "ctrl" }, action = "save" },
            { key = "z", mods = { "ctrl" }, action = "undo", ["repeat"] = true },
            { key = "y", mods = { "ctrl" }, action = "redo", ["repeat"] = true },
            { key = "c", mods = { "ctrl" }, action = "copy" },
            { key = "x", mods = { "ctrl" }, action = "cut" },
            { key = "v", mods = { "ctrl" }, action = "paste" },
            { key = "left", mods = { "ctrl" }, action = "editor_move_word_left", ["repeat"] = true },
            { key = "right", mods = { "ctrl" }, action = "editor_move_word_right", ["repeat"] = true },
            { key = "up", mods = { "ctrl" }, action = "editor_move_large_up", ["repeat"] = true },
            { key = "down", mods = { "ctrl" }, action = "editor_move_large_down", ["repeat"] = true },
            { key = "left", mods = { "shift" }, action = "editor_extend_left", ["repeat"] = true },
            { key = "right", mods = { "shift" }, action = "editor_extend_right", ["repeat"] = true },
            { key = "home", mods = { "shift" }, action = "editor_extend_line_start", ["repeat"] = true },
            { key = "end", mods = { "shift" }, action = "editor_extend_line_end", ["repeat"] = true },
            { key = "left", mods = { "ctrl", "shift" }, action = "editor_extend_word_left", ["repeat"] = true },
            { key = "right", mods = { "ctrl", "shift" }, action = "editor_extend_word_right", ["repeat"] = true },
            { key = "up", mods = { "shift" }, action = "editor_extend_up", ["repeat"] = true },
            { key = "down", mods = { "shift" }, action = "editor_extend_down", ["repeat"] = true },
            { key = "up", mods = { "ctrl", "shift" }, action = "editor_extend_large_up", ["repeat"] = true },
            { key = "down", mods = { "ctrl", "shift" }, action = "editor_extend_large_down", ["repeat"] = true },
            { key = "f", mods = { "ctrl" }, action = "editor_search_open" },
            { key = "f3", mods = {}, action = "editor_search_next" },
            { key = "f3", mods = { "shift" }, action = "editor_search_prev" },
            { key = "up", mods = { "shift", "alt" }, action = "editor_add_caret_up" },
            { key = "down", mods = { "shift", "alt" }, action = "editor_add_caret_down" },
        },
        terminal = {
            { key = "t", mods = { "ctrl", "shift" }, action = "terminal_new_tab" },
            { key = "w", mods = { "ctrl", "shift" }, action = "terminal_close_tab" },
            { key = "tab", mods = { "ctrl" }, action = "terminal_next_tab" },
            { key = "tab", mods = { "ctrl", "shift" }, action = "terminal_prev_tab" },
            { key = "one", mods = { "ctrl" }, action = "terminal_focus_tab_1" },
            { key = "two", mods = { "ctrl" }, action = "terminal_focus_tab_2" },
            { key = "three", mods = { "ctrl" }, action = "terminal_focus_tab_3" },
            { key = "four", mods = { "ctrl" }, action = "terminal_focus_tab_4" },
            { key = "five", mods = { "ctrl" }, action = "terminal_focus_tab_5" },
            { key = "six", mods = { "ctrl" }, action = "terminal_focus_tab_6" },
            { key = "seven", mods = { "ctrl" }, action = "terminal_focus_tab_7" },
            { key = "eight", mods = { "ctrl" }, action = "terminal_focus_tab_8" },
            { key = "nine", mods = { "ctrl" }, action = "terminal_focus_tab_9" },
            { key = "c", mods = { "ctrl", "shift" }, action = "copy" },
            { key = "v", mods = { "ctrl", "shift" }, action = "paste" },
            -- Debug helper: dump current terminal scrollback + visible grid to a temp file and open in pager.
            { key = "h", mods = { "ctrl", "shift" }, action = "terminal_scrollback_pager" },
        },
    },
}

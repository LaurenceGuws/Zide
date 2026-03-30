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

local is_windows = package.config:sub(1, 1) == "\\"
local home = os.getenv("HOME") or ""
local userprofile = os.getenv("USERPROFILE") or home
local theme_import_ok, theme_import = pcall(dofile, "assets/config/theme_import.lua")
local kitty_theme = nil

if theme_import_ok and type(theme_import) == "table" and type(theme_import.from_kitty) == "function" then
	local kitty_theme_path = home .. "/.config/kitty/current-theme.conf"
	local import_ok, imported_theme = pcall(theme_import.from_kitty, kitty_theme_path)
	if import_ok and type(imported_theme) == "table" then
		kitty_theme = imported_theme
	end
end

local jetbrains_font_path = "assets/fonts/JetBrainsMonoNerdFont-Regular.ttf"
local iosevka_font_path = "assets/fonts/IosevkaTermNerdFont-Regular.ttf"

local app_font_path = jetbrains_font_path
if file_exists(iosevka_font_path) then
	app_font_path = iosevka_font_path
end

local editor_font_path = app_font_path
if file_exists(iosevka_font_path) then
	editor_font_path = jetbrains_font_path
end

local terminal_font_path = app_font_path
if file_exists(iosevka_font_path) then
	terminal_font_path = iosevka_font_path
end

local terminal_shell_path = nil
if is_windows then
	local pwsh7_path = "C:/Program Files/PowerShell/7/pwsh.exe"
	if file_exists(pwsh7_path) then
		terminal_shell_path = pwsh7_path
	end
end

local terminal_default_start_location = home
if is_windows then
	terminal_default_start_location = userprofile
end

return {
	-- Logging configuration.
	-- Options:
	--   log = "all" / "none" / "app.core,editor.core,editor.input,editor.highlight,terminal.core,terminal.metrics,terminal.alt,terminal.font,terminal.font.jitter,ui.zoom.shortcut,terminal.io,terminal.csi,terminal.sgr,terminal.osc,terminal.replay" (comma-separated)
	--   log = "all" / "none" / "... ,editor.perf" for file load + rope init timings
	--   log = { enable = { "app.core", "editor.core", "editor.input", "editor.highlight", "terminal.core", "terminal.metrics", "terminal.alt", "terminal.font", "terminal.font.jitter", "ui.zoom.shortcut", "terminal.io", "terminal.csi", "terminal.sgr", "terminal.osc", "terminal.replay" } }
	--   log = { file = { ... }, console = { ... } }
	--   logs.file_level / logs.console_level: "critical" | "error" | "warning" | "info" | "debug" | "trace"
	--   logs.file_levels / logs.console_levels: per-tag overrides, e.g.
	--     { ["terminal.ui.redraw"] = "debug", ["terminal.ui.perf"] = "info" }
	-- If file/console are not set, enable is used for both.
	log = {
		enable = { "app.core", "terminal.core", "ui.zoom.shortcut" },
		-- file = { "terminal.metrics" },
		-- console = { "app.core" },
	},
	logs = {
		file_level = "info",
		console_level = "info",
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
	        ui_window_control_fg = "#c8d3f5",
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

	-- -- Tokyo Night Day palette defaults.
	-- theme = {
	-- 	palette = {
	-- 		background = "#e1e2e7",
	-- 		foreground = "#1f2335",
	-- 		selection = "#b7c1e3",
	-- 		cursor = "#1f2335",
	-- 		link = "#387068",
	-- 		line_number = "#6b7394",
	-- 		line_number_bg = "#d0d5e3",
	-- 		current_line = "#c4c8da",
	-- 		ui_bar_bg = "#d0d5e3",
	-- 		ui_panel_bg = "#c4c8da",
	-- 		ui_panel_overlay = "#c4c8daEB",
	-- 		ui_hover = "#b7c1e3",
	-- 		ui_pressed = "#a1a6c5",
	-- 		ui_tab_inactive_bg = "#e1e2e7",
	-- 		ui_accent = "#2e7de9",
	-- 		ui_border = "#8990b3",
	-- 		ui_modified = "#8c6c3e",
	-- 		ui_text = "#1f2335",
	-- 		ui_text_inactive = "#4c5a91",
	-- 		ui_window_control_fg = "#1f2335",
	-- 		color0 = "#b4b5b9",
	-- 		color1 = "#f52a65",
	-- 		color2 = "#587539",
	-- 		color3 = "#8c6c3e",
	-- 		color4 = "#2e7de9",
	-- 		color5 = "#9854f1",
	-- 		color6 = "#007197",
	-- 		color7 = "#6172b0",
	-- 		color8 = "#a1a6c5",
	-- 		color9 = "#ff4774",
	-- 		color10 = "#5c8524",
	-- 		color11 = "#a27629",
	-- 		color12 = "#358aff",
	-- 		color13 = "#a463ff",
	-- 		color14 = "#007ea8",
	-- 		color15 = "#3760bf",
	-- 	},
	-- 	syntax = {
	-- 		comment = "#848cb5",
	-- 		string = "#587539",
	-- 		keyword = "#9854f1",
	-- 		number = "#b15c00",
	-- 		["function"] = "#2e7de9",
	-- 		variable = "#3760bf",
	-- 		type_name = "#007197",
	-- 		operator = "#007197",
	-- 		builtin = "#007197",
	-- 		punctuation = "#007197",
	-- 		constant = "#b15c00",
	-- 		attribute = "#9854f1",
	-- 		namespace = "#2e7de9",
	-- 		label = "#b15c00",
	-- 		error = "#f52a65",
	-- 	},
	-- },

	-- App shell configuration.
	-- app.font drives app/UI chrome and is the fallback for editor/terminal when
	-- their own font block is unset.
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
	-- Changes can be reloaded at runtime. Font path/size changes rebuild the
	-- app, editor, and terminal font stacks immediately.
	font_rendering = {
		-- Rasterization
		-- lcd: enable subpixel (LCD) rendering path. Not final; use cautiously.
		lcd = false,
		-- hinting: "default", "none", "light", "normal"
		hinting = is_windows and "light" or "default",
		-- autohint: force FreeType autohinter
		autohint = is_windows,
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

	-- Selection overlay smoothing defaults (applies to editor and terminal unless overridden).
	-- smooth: false disables contour smoothing and draws rectangular selection fills.
	-- corner_px: smoothing corner amount in px.
	-- pad_px: extra horizontal pad in px to keep wide-leading glyph edges covered (e.g. "W").
	selection_overlay = {
		smooth = true,
		corner_px = 1.0,
		pad_px = 1.0,
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
		-- Tab bar width mode (IDE/editor mode):
		-- "fixed"       = fixed chip width
		-- "dynamic"     = split available width evenly across tabs
		-- "label_length"= size by label length and normalize to fill width
		tab_bar = {
			width_mode = "fixed",
		},
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
		-- Load a shipped imported editor theme artifact by name.
		-- The imported theme is merged first, then the rest of this config file
		-- can override it normally.
		-- imported_theme = "tokyonight-night",
		-- Render work budgets (lines per frame). Set to 0 to disable precompute.
		render = {
			-- highlight_budget = 120,
			-- width_budget = 120,
		},
		-- Manual highlight overrides for plain-text-ish files or local custom rules.
		-- `extensions` keys are file extensions without the dot.
		-- `parser`/`language` is the tree-sitter grammar to use.
		-- `builtin` points at a shipped preset in `assets/queries/manual/*.scm`.
		-- `query_path` can point at your own `.scm` file instead.
		-- `mode` controls how the manual query combines with grammar defaults:
		--   "append"  (default) = default query first, manual query after
		--   "prepend"           = manual query first, default query after
		--   "replace"           = manual query only
		--
		-- Shipped defaults currently route unsupported / plain-text-ish buffers
		-- through the `comment` grammar with the richer `log_levels` preset
		-- layered on top. That covers untitled buffers, `.txt`, `.log`, and
		-- other unmapped extensions until a real grammar mapping exists.
		highlights = {
			extensions = {},
			unsupported = { parser = "comment", builtin = "log_levels", mode = "append" },
		},
		-- Optional per-editor selection overlay override.
		-- selection_overlay = {
		--     smooth = true,
		--     corner_px = 1.0,
		--     pad_px = 1.0,
		-- },
		-- Optional override. Runtime reloads the editor font stack immediately.
		-- Comment out the editor_font_path switch block above to compare directly
		-- against app.font or another explicit test font.
		font = {
			path = editor_font_path,
			size = 16,
		},
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

		-- Optional override. Runtime reloads the terminal font stack immediately.
		-- Comment out the terminal_font_path switch block above to compare
		-- directly against app.font or another explicit test font.
		font = {
			path = terminal_font_path,
			size = 16,
		},

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
		-- Optional per-terminal selection overlay override.
		-- selection_overlay = {
		--     smooth = true,
		--     corner_px = 1.0,
		--     pad_px = 1.0,
		-- },

		-- Blink style: "kitty" (default) or "off".
		-- blink = "kitty",
		-- Viewport texture shift optimization used for scroll-like updates.
		-- Disable to force redraw fallback instead of the texture self-copy path.
		texture_shift = true,
		-- Wayland-present mitigation for the current beta terminal lane.
		-- During recent terminal input, Zide can temporarily force full terminal
		-- texture publication to avoid the post-swap row remap bug seen under
		-- sustained scroll/input pressure.
		presentation = {
			-- Master switch for the recent-input force-full policy.
			recent_input_force_full = true,
			-- Keep the aggressive publication path active for this many
			-- milliseconds after recent terminal input/modifier pressure.
			recent_input_force_full_ms = 2000,
		},
		-- Scrollback line cap (min 100, max 100000). Invalid values warn and fall back to 1000.
		scrollback = 10000,
		-- Shared terminal shell policy across terminal-only mode and terminals
		-- created from IDE/editor surfaces.
		shell = {
			path = terminal_shell_path,
		},
		-- Terminal start-location policy.
		-- default: directory used for first terminal startup and as fallback.
		-- new_tab:
		--   "current" -> inherit active tab cwd when available (default)
		--   "default" -> always start tabs at start_location.default
		start_location = {
			default = terminal_default_start_location,
			new_tab = "current",
		},
		-- Terminal-only window chrome policy.
		-- mode:
		--   "native"      ordinary platform frame/titlebar (default)
		--   "integrated"  integrated titlebar/tab strip contract
		-- Current first native implementation is Windows terminal-only mode.
		window_chrome = {
			mode = "native",
		},
		-- Tab bar visibility in --mode terminal:
		-- false: hide tab bar until there are 2+ tabs (default)
		-- true: always show the ordinary content-row tab bar, even with a single tab
		-- Note: integrated terminal chrome keeps the titleband visible either way.
		-- width_mode options:
		--   "fixed"        fixed chip width
		--   "dynamic"      equal split across available width
		--   "label_length" label-aware widths normalized to fill bar
		-- Note: integrated terminal chrome normalizes to a compact internal width
		-- policy instead of stretching tabs across the whole titleband.
		-- show_shell_icon:
		--   false  no per-shell image prefix (default)
		--   true   show a PNG icon when terminal.tab_bar.shell_icons has a match
		-- shell_icons:
		--   Lua table mapping shell path / basename / basename stem to a PNG path.
		--   Examples:
		--     ["C:/Program Files/PowerShell/7/pwsh.exe"] = "C:/Icons/pwsh.png"
		--     ["pwsh.exe"] = "C:/Icons/pwsh.png"
		--     bash = "assets/icon/bash.png"
		tab_bar = {
			show_single_tab = false,
			show_shell_icon = false,
			width_mode = "dynamic",
			-- shell_icons = {
			--     ["pwsh.exe"] = "C:/Icons/pwsh.png",
			--     bash = "assets/icon/bash.png",
			-- },
		},
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
			window = true, -- SDL window focus gain/loss
			pane = false, -- terminal pane focus within the IDE
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
			{ key = "o", mods = { "ctrl" }, action = "open_file" },
			{ key = "q", mods = { "ctrl" }, action = "quit_app" },
			{ key = "equal", mods = { "ctrl" }, action = "zoom_in", ["repeat"] = true },
			{ key = "kp_add", mods = { "ctrl" }, action = "zoom_in", ["repeat"] = true },
			{ key = "minus", mods = { "ctrl" }, action = "zoom_out", ["repeat"] = true },
			{ key = "kp_subtract", mods = { "ctrl" }, action = "zoom_out", ["repeat"] = true },
			{ key = "zero", mods = { "ctrl" }, action = "zoom_reset" },
			{ key = "grave", mods = { "ctrl" }, action = "toggle_terminal" },
			{ key = "f5", mods = { "ctrl", "shift" }, action = "reload_config" },
		},
		editor = {
			{ key = "a", mods = { "ctrl" }, action = "select_all" },
			{ key = "tab", mods = { "ctrl" }, action = "next_document" },
			{ key = "tab", mods = { "ctrl", "shift" }, action = "prev_document" },
			{ key = "w", mods = { "ctrl" }, action = "close_editor" },
			{ key = "g", mods = { "ctrl" }, action = "go_to_line" },
			{ key = "s", mods = { "ctrl" }, action = "save" },
			{ key = "s", mods = { "ctrl", "shift" }, action = "save_as" },
			{ key = "z", mods = { "ctrl" }, action = "undo", ["repeat"] = true },
			{ key = "y", mods = { "ctrl" }, action = "redo", ["repeat"] = true },
			{ key = "c", mods = { "ctrl" }, action = "copy" },
			{ key = "x", mods = { "ctrl" }, action = "cut" },
			{ key = "v", mods = { "ctrl" }, action = "paste" },
			{ key = "k", mods = { "ctrl", "shift" }, action = "delete_line" },
			{ key = "d", mods = { "ctrl" }, action = "duplicate_line" },
			{ key = "tab", mods = {}, action = "indent_lines" },
			{ key = "tab", mods = { "shift" }, action = "outdent_lines" },
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
			{ key = "h", mods = { "ctrl" }, action = "editor_replace_open" },
			{ key = "f3", mods = {}, action = "editor_search_next" },
			{ key = "f3", mods = { "shift" }, action = "editor_search_prev" },
			{ key = "left_bracket", mods = { "ctrl", "alt" }, action = "editor_cycle_imported_theme_prev" },
			{ key = "right_bracket", mods = { "ctrl", "alt" }, action = "editor_cycle_imported_theme_next" },
			{ key = "up", mods = { "shift", "alt" }, action = "editor_add_caret_up" },
			{ key = "down", mods = { "shift", "alt" }, action = "editor_add_caret_down" },
		},
		terminal = {
			{ key = "t", mods = { "ctrl", "shift" }, action = "terminal_new_tab" },
			{ key = "w", mods = { "ctrl", "shift" }, action = "terminal_close_tab" },
			{ key = "tab", mods = { "ctrl" }, action = "terminal_next_tab" },
			{ key = "tab", mods = { "ctrl", "shift" }, action = "terminal_prev_tab" },
			{ key = "right", mods = { "ctrl", "shift" }, action = "terminal_next_tab" },
			{ key = "left", mods = { "ctrl", "shift" }, action = "terminal_prev_tab" },
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

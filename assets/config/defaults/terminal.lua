return function(ctx)
	return {
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
			theme = ctx.kitty_theme,

			-- Optional override. Runtime reloads the terminal font stack immediately.
			-- Comment out the terminal_font_path switch block above to compare
			-- directly against app.font or another explicit test font.
			font = {
				path = ctx.terminal_font_path,
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
				path = ctx.terminal_shell_path,
			},
			-- Terminal start-location policy.
			-- default: directory used for first terminal startup and as fallback.
			-- new_tab:
			--   "current" -> inherit active tab cwd when available (default)
			--   "default" -> always start tabs at start_location.default
			start_location = {
				default = ctx.terminal_default_start_location,
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
	}
end

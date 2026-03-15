-- Zide full theme key/value reference.
-- This file is a template/reference only.
-- Copy sections into `assets/config/init.lua`, `~/.config/zide/init.lua`, or `./.zide.lua`.

return {
	-- Global theme fallback (feeds app/editor/terminal unless domain overrides are set).
	theme = {
		palette = {
			background = "#222436",
			foreground = "#c8d3f5",
			selection = "#2d3f76",
			-- aliases accepted:
			selection_background = "#2d3f76",
			["selection-background"] = "#2d3f76",
			cursor = "#c8d3f5",
			link = "#4fd6be",
			line_number = "#545c7e",
			line_number_bg = "#1e2030",
			current_line = "#2f334d",
			ui_bar_bg = "#1e2030",
			ui_panel_bg = "#191b29",
			ui_panel_overlay = "#191b29eb",
			ui_hover = "#2f334d",
			ui_pressed = "#444a73",
			ui_tab_inactive_bg = "#222436",
			ui_accent = "#82aaff",
			ui_border = "#3b4261",
			ui_modified = "#ffc777",
			ui_text = "#c8d3f5",
			ui_text_inactive = "#828bb8",

			-- canonical ANSI keys:
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

			-- optional ANSI formats (portable kitty/ghostty-style input):
			-- ansi = {
			--     "#1b1d2b", "#ff757f", "#c3e88d", "#ffc777",
			--     "#82aaff", "#c099ff", "#86e1fc", "#828bb8",
			--     "#444a73", "#ff8d94", "#c7fb6d", "#ffd8ab",
			--     "#9ab8ff", "#caabff", "#b2ebff", "#c8d3f5",
			-- },
			-- ansi = {
			--     black = "#1b1d2b",
			--     red = "#ff757f",
			--     green = "#c3e88d",
			--     yellow = "#ffc777",
			--     blue = "#82aaff",
			--     magenta = "#c099ff",
			--     cyan = "#86e1fc",
			--     white = "#828bb8",
			--     bright_black = "#444a73",
			--     bright_red = "#ff8d94",
			--     bright_green = "#c7fb6d",
			--     bright_yellow = "#ffd8ab",
			--     bright_blue = "#9ab8ff",
			--     bright_magenta = "#caabff",
			--     bright_cyan = "#b2ebff",
			--     bright_white = "#c8d3f5",
			-- },
		},
		syntax = {
			comment = "#636da6",
			-- alias:
			comment_color = "#636da6",
			string = "#c3e88d",
			keyword = "#c099ff",
			number = "#ff966c",
			["function"] = "#82aaff",
			variable = "#c8d3f5",
			type_name = "#86e1fc",
			operator = "#89ddff",
			builtin = "#86e1fc",
			-- alias:
			builtin_color = "#86e1fc",
			punctuation = "#89ddff",
			constant = "#ff966c",
			attribute = "#c099ff",
			namespace = "#82aaff",
			label = "#ff966c",
			error = "#ff757f",
			-- alias:
			error_token = "#ff757f",
			preproc = "#ff9e64",
			macro = "#ff9e64",
			escape = "#ff966c",
			keyword_control = "#c099ff",
			["keyword.control"] = "#c099ff",
			function_method = "#82aaff",
			["function.method"] = "#82aaff",
			type_builtin = "#86e1fc",
			["type.builtin"] = "#86e1fc",
		},
	},

	-- App surfaces: chrome, tabs, status, overlays.
	app = {
		theme = {
			palette = {
				-- typically UI-oriented overrides:
				ui_bar_bg = "#1a1c2a",
				ui_panel_bg = "#171927",
				ui_panel_overlay = "#171927eb",
				ui_hover = "#2a2f48",
				ui_pressed = "#3b4163",
				ui_tab_inactive_bg = "#202338",
				ui_accent = "#82aaff",
				ui_border = "#343a58",
				ui_modified = "#ffc777",
				ui_text = "#c8d3f5",
				ui_text_inactive = "#7e86b0",
			},
		},
	},

	-- Terminal full scheme.
	terminal = {
		theme = {
			palette = {
				background = "#0f111b",
				foreground = "#c8d3f5",
				cursor = "#c8d3f5",
				selection = "#2d3f76",
				selection_background = "#2d3f76",
				-- include either color0..color15 or ansi table (or both):
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
		},
	},

	-- Editor theme supports palette/syntax + nvim-style groups/captures/links.
	editor = {
		theme = {
			palette = {
				background = "#222436",
				foreground = "#c8d3f5",
				selection = "#2d3f76",
				current_line = "#2f334d",
				line_number = "#545c7e",
				line_number_bg = "#1e2030",
				cursor = "#c8d3f5",
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
				preproc = "#ff9e64",
				macro = "#ff9e64",
				escape = "#ff966c",
				keyword_control = "#c099ff",
				function_method = "#82aaff",
				type_builtin = "#86e1fc",
			},

			-- nvim-style named groups:
			groups = {
				Normal = "#c8d3f5",
				Comment = "#636da6",
				Keyword = "#c099ff",
				["Function"] = { fg = "#82aaff" },
				Visual = { bg = "#2d3f76" },
				CursorLine = { bg = "#2f334d" },
				LineNr = "#545c7e",
				Statement = { link = "Keyword" },
			},

			-- tree-sitter captures:
			captures = {
				["@comment"] = "#636da6",
				["@keyword.control"] = "#c099ff",
				["@function"] = "#82aaff",
				["@function.method"] = { link = "Function" },
				["@variable"] = { link = "Statement" },
			},

			-- explicit link table:
			links = {
				Statement = "Keyword",
				["@variable"] = "Statement",
			},
		},
	},
}

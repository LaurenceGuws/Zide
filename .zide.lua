return {
	editor = {
		imported_theme = "kanagawa-dragon",
	},
	sdl = {
		log_level = "info",
	},
	logs = {
		file = {
			"editor.highlight",
			"editor.grammar",
		},
		file_level = "info",
		console_level = "warning",
		file_levels = {
			["editor.highlight"] = "info",
			["editor.grammar"] = "info",
		},
	},
}

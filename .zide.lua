return {
	sdl = {
		log_level = "info",
	},
	logs = {
		file = {
			"terminal.generation_handoff",
			"terminal.ui.texture_shift",
			"terminal.ui.dirty_retirement",
		},
		file_level = "info",
		console_level = "warning",
		file_levels = {
			["terminal.generation_handoff"] = "info",
			["terminal.ui.texture_shift"] = "info",
			["terminal.ui.dirty_retirement"] = "info",
		},
	},
}

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
}

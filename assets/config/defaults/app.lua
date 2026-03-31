return function(ctx)
	return {
		-- App shell configuration.
		-- app.font drives app/UI chrome and is the fallback for editor/terminal when
		-- their own font block is unset.
		app = {
			-- App-specific theme override (affects UI chrome: tabs, status bar, side nav).
			-- theme = {
			--     palette = { background = "#1E222A" },
			-- },
			font = {
				path = ctx.app_font_path,
				size = 16,
			},
		},
	}
end

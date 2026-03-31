return function(ctx)
	return {
		-- Font rendering configuration.
		-- These settings affect rasterization/shaping and text blending quality.
		-- Changes can be reloaded at runtime. Font path/size changes rebuild the
		-- app, editor, and terminal font stacks immediately.
		font_rendering = {
			-- Rasterization
			-- lcd: enable subpixel (LCD) rendering path. Not final; use cautiously.
			lcd = false,
			-- hinting: "default", "none", "light", "normal"
			hinting = ctx.is_windows and "light" or "default",
			-- autohint: force FreeType autohinter
			autohint = ctx.is_windows,
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
	}
end

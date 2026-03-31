return {
	-- Selection overlay smoothing defaults (applies to editor and terminal unless overridden).
	-- smooth: false disables contour smoothing and draws rectangular selection fills.
	-- corner_px: smoothing corner amount in px.
	-- pad_px: extra horizontal pad in px to keep wide-leading glyph edges covered (e.g. "W").
	selection_overlay = {
		smooth = true,
		corner_px = 1.0,
		pad_px = 1.0,
	},
}

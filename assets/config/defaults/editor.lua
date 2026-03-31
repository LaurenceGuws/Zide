return function(ctx)
	return {
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
				path = ctx.editor_font_path,
				size = 16,
			},
		},
	}
end

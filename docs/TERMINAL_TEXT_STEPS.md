# Terminal text rendering: steps

Goal: achieve terminal-quality text rendering comparable to Kitty/Alacritty.

## Phase 1 — Pixel correctness (biggest win for box drawing)

- Snap terminal grid to integer pixels.
- Make `terminal_cell_width`/`terminal_cell_height` integer pixel values.
- Snap glyph draw positions to integer pixels.
- Disable filtering or use nearest sampling for the glyph atlas.

## Phase 2 — Rasterization quality

- Use FreeType LCD rendering (`FT_LOAD_TARGET_LCD` + `FT_RENDER_MODE_LCD`).
- Upload subpixel RGB glyph bitmaps and handle gamma correction.
- Add a grayscale fallback path for non-LCD environments.

## Phase 3 — Shaping and clusters

- Shape grapheme clusters with HarfBuzz instead of single codepoints.
- Cache shaped clusters to avoid per-frame shaping costs.
- Support combining marks and ligatures where appropriate.

## Phase 4 — Font fallback + styles

- Add font fallback stack (primary mono + symbols + emoji).
- Load bold/italic faces when available (avoid synthetic styles).
- Respect terminal attributes: bold, italic, underline, strikethrough.

## Phase 5 — Metrics + wide glyph handling

- Use exact font metrics for cell sizing and baseline.
- Center wide glyphs within the cell, or expand to double-cell width when needed.
- Ensure box-drawing glyphs align to grid without seams.

## Validation checklist

- btop and nvim box drawing lines render cleanly with no striping.
- Powerline/nerd glyphs do not clip on the right.
- Cursor and underline align to font metrics.
- High-DPI + fractional scaling still renders crisp text.

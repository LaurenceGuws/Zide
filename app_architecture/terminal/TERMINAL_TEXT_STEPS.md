# Terminal text rendering: steps

Goal: achieve terminal-quality text rendering comparable to Kitty/Alacritty.

## Phase 1 — Pixel correctness (done)

- Snap terminal grid to integer pixels.
- `terminal_cell_width`/`terminal_cell_height` use integer pixel values.
- Glyph draw positions are snapped to integer pixels.
- Glyph atlas uses point filtering.

## Phase 2 — Rasterization quality (pending)

- Use FreeType LCD rendering (`FT_LOAD_TARGET_LCD` + `FT_RENDER_MODE_LCD`).
- Upload subpixel RGB glyph bitmaps and handle gamma correction.
- Add a grayscale fallback path for non-LCD environments.

## Phase 3 — Shaping and clusters (pending)

- Shape grapheme clusters with HarfBuzz instead of single codepoints.
- Cache shaped clusters to avoid per-frame shaping costs.
- Support combining marks and ligatures where appropriate.

## Phase 4 — Font fallback + styles (partial)

- System font fallback via fontconfig on Linux is implemented; CoreText/DirectWrite still TODO.
- Keep embedded symbol/emoji fallbacks optional for distribution size control.
- Load bold/italic faces when available (avoid synthetic styles).
- Respect terminal attributes: bold, italic, underline, strikethrough.

## Phase 5 — Metrics + wide glyph handling (partial)

- Use exact font metrics for cell sizing and baseline. (partial; integer snapping in place)
- Wide/square glyphs: allow overflow when followed by space; otherwise scale to fit.
- Symbols/PUA glyphs: always allow overflow (no scaling), clamped to cell origin.
- Ensure box-drawing glyphs align to grid without seams.

## Validation checklist

- btop and nvim box drawing lines render cleanly with no striping (mostly OK; verify on new fonts).
- Powerline/nerd glyphs do not clip on the right.
- Cursor and underline align to font metrics.
- High-DPI + fractional scaling still renders crisp text.

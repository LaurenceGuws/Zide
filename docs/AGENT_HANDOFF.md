# Agent Handoff (Zide)

Date: 2026-01-16

## Summary of active work

- Goal: improve terminal font rendering (Nerd icons + box drawing) to match Kitty/Alacritty/WezTerm quality.
- Current state: implemented WezTerm-like overflow policy. Box drawing still shows striping in some cases.

## Key code changes made in this session

### WezTerm-like overflow policy (2026-01-16)
- `src/ui/terminal_font.zig`
  - Added `AllowSquareGlyphOverflow` enum with three policies: `never`, `always`, `when_followed_by_space` (default).
  - `drawGlyph` now accepts `cell_height` and `followed_by_space` parameters.
  - Determines "square or wide" glyphs by aspect ratio (>= 0.7 threshold, typical monospace is ~0.5).
  - If overflow not allowed and glyph oversized: scales glyph down using `DrawTexturePro`.
  - If overflow allowed and glyph oversized: centers glyph in cell (allows overflow into adjacent space).
  - Configurable via `ZIDE_GLYPH_OVERFLOW` env var (`never`, `always`, or default `when_followed_by_space`).
- `src/ui/renderer.zig`
  - `drawTerminalCell` now accepts `followed_by_space` parameter.
- `src/ui/widgets.zig`
  - Terminal rendering now looks ahead to detect if next cell is space/empty.

### Prior changes (2026-01-15)
- Added `src/platform/compositor.zig` for Wayland compositor scale detection (Hyprland via `hyprctl -j monitors`).
- LCD subpixel rendering support via `ZIDE_FONT_LCD=1`.
- Gamma correction on glyph data.
- Box drawing fallback renderer in `drawTerminalBoxGlyph`.

## Known issues / current behavior

- Box drawing fallback did not fully resolve striping.
- Overflow policy needs user testing to validate icon appearance.

## Environment variables

- `ZIDE_GLYPH_OVERFLOW`: Set to `never` (always scale to fit), `always` (always allow overflow), or leave unset for default `when_followed_by_space`.
- `ZIDE_FONT_LCD`: Set to `1` to enable LCD subpixel rendering.
- `ZIDE_MOUSE_SCALE`: Override mouse scaling factor.

## Suggested next steps

1) ~~Implement WezTerm-like overflow policy~~ **DONE**
2) Add optional Nerd font fallback (Symbols Nerd Font Mono) for PUA glyphs.
3) Consider treating PUA as double-width (span 2 cells) when configured.
4) Improve box drawing fallback to cover more glyphs or use a dedicated box-drawing font atlas.

## Files to review first

- `src/ui/terminal_font.zig`
- `src/ui/renderer.zig`
- `src/ui/widgets.zig`
- `docs/TERMINAL_TEXT_RESEARCH.md`
- `docs/TERMINAL_TEXT_STEPS.md`

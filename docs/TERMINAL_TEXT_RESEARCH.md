# Terminal Text Rendering Research (Nerd Font Icons)

Date: 2026-01-15

## What we tried (and why it failed)

- Scale-down oversized glyphs to fit cell width. This made Nerd icons noticeably smaller and worse than the current baseline; visual regression (icons tiny and low impact).
- Point filtering for terminal glyph atlas. Helped reduce some blur, but did not fix clipping/overflow of large Nerd icons.
- Pixel snapping of terminal grid and glyph positions. Reduced gaps slightly, but icon clipping remained; box drawing artifacts persisted.
- Box drawing fallback renderer. Improved consistency for some box/block glyphs, but did not address Nerd icon clipping and did not materially fix stripe artifacts for all cases.
- LCD subpixel rendering (FreeType LCD). Improved clarity but did not resolve icon clipping/overlap issues.

## Analysis of cloned terminals

### Kitty

- Uses a built-in Nerd Font fallback (Symbols Nerd Font Mono) when available. This stabilizes icon coverage independent of the user’s chosen main font.
- Prevents bleed by scaling glyphs down if the glyph’s bounding box would exceed the target cell width. This is done at render-time by adjusting the effective font size when needed.
- Takeaway: Kitty is willing to rescale glyphs to avoid overflow, and it relies on a known Nerd font fallback.

Relevant locations:
- `reference_repos/terminals/kitty/kitty/fonts/render.py` (builtin Nerd font setup + symbol map swap)
- `reference_repos/terminals/kitty/kitty/core_text.m` (`do_render`: resizes glyphs when width exceeds cell width)

### Alacritty

- No Nerd-font-specific handling for large icon glyphs. It renders glyphs at rasterized size into the cell quad.
- Handles wide glyphs at the terminal layer using WIDE_CHAR flags, but doesn’t use a Nerd-specific width policy.
- Provides a built-in font only for box drawing/powerline, not for Nerd icons.

Relevant locations:
- `reference_repos/terminals/alacritty/alacritty/src/renderer/text/builtin_font.rs` (built-in box/powerline glyphs)
- `reference_repos/terminals/alacritty/alacritty/src/renderer/text/gles2.rs` (wide glyphs span 2 cells)

### WezTerm

- Has an explicit policy for oversized/square glyphs: allow overflow or scale-to-fit based on config.
- Uses glyph aspect ratio (square-ish vs typical monospace) and a `allow_square_glyphs_to_overflow_width` setting with modes: Never, Always, WhenFollowedBySpace.
- Scales glyphs to fit max width if overflow not allowed; allows overflow in controlled cases.
- Vendors Symbols Nerd Font Mono as an optional built-in font so icons are consistent out of the box.

Relevant locations:
- `reference_repos/terminals/wezterm/wezterm-gui/src/glyphcache.rs` (overflow policy + scaling)
- `reference_repos/terminals/wezterm/config/src/font.rs` (AllowSquareGlyphOverflow enum)
- `reference_repos/terminals/wezterm/README-DISTRO-MAINTAINER.md` (vendored Nerd font)

## Key takeaways for Zide

- The high-quality terminals explicitly manage Nerd icons rather than treating them like regular monospace glyphs.
- Two common strategies:
  - Use a known Nerd font fallback for PUA glyphs (Symbols Nerd Font Mono).
  - Apply an overflow policy (allow overflow or scale-to-fit) based on glyph aspect ratio and context.
- Kitty/WezTerm both change glyph rendering size for overflow control; Alacritty does not.

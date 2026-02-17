# Terminal Special Glyph Coverage (Kitty + Ghostty parity)

This is the canonical list of codepoints/ranges that reference terminals special-case
through sprite/box rendering paths rather than normal font outlines.

Sources:
- `reference_repos/terminals/kitty/kitty/fonts.c:733`
- `reference_repos/terminals/kitty/kitty/decorations.c:1538`
- `reference_repos/terminals/ghostty/src/font/sprite/Face.zig:64`
- `reference_repos/terminals/ghostty/src/font/sprite/draw/*.zig`

## Shared (Kitty + Ghostty)
- `U+2500..U+259F` (box drawing + block elements)
- `U+25E2..U+25E5` (black lower/upper triangles)
- `U+2800..U+28FF` (braille patterns)
- `U+E0B0..U+E0BF` (powerline block symbols)
- `U+F5D0..U+F60D` (branch drawing)
- `U+1CD00..U+1CDE5` (octants)
- `U+1FB00..U+1FBAE` (symbols for legacy computing)
- `U+1FBE6..U+1FBE7`

## Kitty-only special routing (`BOX_FONT`)
- `U+25C9`, `U+25CB`, `U+25CF`
- `U+25D6..U+25D7`
- `U+25DC..U+25E1`
- `U+E0D6..U+E0D7`
- `U+EE00..U+EE0B` (Fira Code progress/spinner)

## Ghostty-only sprite coverage
- `U+25F8..U+25FA`
- `U+25FF`
- `U+E0D2`
- `U+E0D4`
- `U+1CC1B..U+1CC1E`
- `U+1CC21..U+1CC3F`
- `U+1CE00..U+1CE01`
- `U+1CE0B..U+1CE0C`
- `U+1CE16..U+1CE19`
- `U+1CE51..U+1CEAF`
- `U+1FBAF`
- `U+1FBBD..U+1FBBF`
- `U+1FBCE..U+1FBE5`
- `U+1FBE8..U+1FBEF`

## Immediate Zide target (visual quality first)
- Powerline: `U+E0B0..U+E0BF`, `U+E0D2`, `U+E0D4`, `U+E0D6..U+E0D7`
- Shades: `U+2591`, `U+2592`, `U+2593`
- Core box continuity: `U+2500..U+257F`, `U+2580..U+259F`

## "Perfect" acceptance criteria
- No visible seams/gaps at zoom steps `0.5..1.6` on fractional render scales (`1.25`, `1.5`, `1.6`, `1.75`).
- Neighbor cell joins remain stable when zooming in/out repeatedly.
- No per-step width oscillation in terminal rows containing these glyphs.
- btop/nvim/tui status bars render continuously with no vertical bars/artifacts.

## Test strings to keep in the fixture
- ``
- `░▒▓█▇▆▅▄▃▂▁`
- `┌┬┐├┼┤└┴┘│─╭╮╯╰`

## Implementation Status (Zide)
- `U+E0B0..U+E0B3` (core powerline separators): `in_progress` (experimental; seams improved, edge quality not accepted)
- `U+E0B4..U+E0BF`, `U+E0D2`, `U+E0D4`, `U+E0D6..U+E0D7`: `not_started`
- `U+2591..U+2593` (shades): `not_started`
- `U+2500..U+259F` core box/block continuity migration to sprite path: `not_started`
- `U+2800..U+28FF` (braille): `not_started`
- `U+F5D0..U+F60D` (branch): `not_started`
- Legacy/octal supplemental ranges from this matrix: `not_started`

Status source:
- Execution plan and task states: `app_architecture/ui/terminal_special_glyph_todo.yaml`

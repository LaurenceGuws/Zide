# Terminal Special Glyph TODO

## Scope

Build a high-quality terminal special-glyph pipeline for powerline, shades, box, braille, branch, and legacy symbols with stable quality across zoom and fractional DPI.

## Constraints

- No per-frame procedural reraster after the sprite pipeline lands.
- Cache keys must include effective cell metrics.
- Do not regress baseline terminal or editor text rendering while this work lands.
- Keep Linux/OpenGL quality locked before platform divergence.

## Authority

- Coverage matrix: `app_architecture/ui/terminal_special_glyph_coverage.md`
- Parent rendering track: `docs/todo/ui/font_rendering.md`

## Acceptance Criteria

- [ ] No visible seams for `   ` across zoom and fractional render scales
- [ ] No row-to-row width oscillation or thick/thin flicker
- [ ] `░▒▓` density remains stable at small sizes
- [ ] Special glyphs stay cell-bounded with no cursor, selection, or underline regressions
- [ ] No resize or zoom cache safety regressions
- [ ] Sprite generation is amortized by cache with no major redraw regression

## TODO

### TSG-0 Baseline and Fixtures

- [ ] `TSG-0-01` Lock separator-focused fixtures and capture matrix
- [ ] `TSG-0-02` Add manual QA checklist for zoom sweeps

### TSG-1 Sprite Pipeline Skeleton

- [ ] `TSG-1-01` Introduce sprite cache type and keys
  - Cache scaffolding exists; draw integration is still being finished.
- [ ] `TSG-1-02` Add coverage-atlas upload path for precomputed sprite masks
  - On-demand rasterize and upload is working; quality and eviction policy remain.
- [ ] `TSG-1-03` Integrate sprite draw dispatch in terminal draw

### TSG-2 Powerline First

- [ ] `TSG-2-01` Implement geometric raster for `U+E0B0..U+E0B3`
- [ ] `TSG-2-02` Expand to the full powerline set used by references
- [ ] `TSG-2-03` Add seam and stroke-thickness invariants
- [ ] `TSG-2-04` Prototype a dedicated analytic or vector stroke-plus-fill path
  - Current 2026-02-20 baseline: thick `/` stay out of the special path; thin `/` stay on the analytic path.
- [ ] `TSG-2-05` Prototype real font-outline raster for powerline codepoints
  - Previous attempt was reverted after severe pixelation regression.

### TSG-3 Blocks, Shades, and Box Continuity

- [ ] `TSG-3-01` Move `░▒▓` to sprite masks with density-consistent patterns
- [ ] `TSG-3-02` Migrate core box and block ranges incrementally
  Notes:
  - 2026-03-16 dogfood bug from `lazydocker`: some box-drawing characters were
    disappearing entirely, leaving visible gaps in borders.
  - Root cause: `specialVariantForCodepoint()` was routing the whole
    `U+2500..U+259F` block through the special-glyph path even though Zide only
    has analytic coverage for a small subset today. Unsupported codepoints could
    miss both sprite creation and analytic fallback and disappear instead of
    falling back to font rendering.
  - Immediate fix landed in code: only currently implemented analytic box
    codepoints are claimed by the special-glyph router; the rest now fall back
    to normal font rendering until the real box/block migration exists.
  - This is a deliberate postponement of incomplete special routing, not a
    scope cut. Full `U+2500..U+259F` special-path parity is still in scope for
    this track; unsupported codepoints were returned to safe font fallback so
    they render correctly while the broader migration remains pending.

### TSG-4 Extended Symbol Parity

- [ ] `TSG-4-01` Braille parity pass
- [ ] `TSG-4-02` Branch drawing parity pass
- [ ] `TSG-4-03` Legacy computing and octants parity pass
  Notes:
  - The current router no longer claims branch/legacy ranges speculatively.
    That rollback is intentional until real sprite/analytic coverage exists.
  - These ranges remain in scope for parity work; they were postponed out of
    the fast path to preserve correctness and fallback rendering.

### TSG-5 Verification and Hardening

- [ ] `TSG-5-01` Automate special-glyph visual snapshots
- [ ] `TSG-5-02` Stress-test resize and zoom cache safety
- [ ] `TSG-5-03` Document final architecture and maintenance rules

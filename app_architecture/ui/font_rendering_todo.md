# Font Rendering TODO

## Scope

Make editor and terminal text rendering competitive with modern terminals: crisp small sizes, correct blending, stable metrics, and explicit editor/terminal font-stack differences.

## Constraints

- Introduce repeatable visual or metric harnesses before large rendering changes.
- SDL3/OpenGL is the baseline path.
- Lock Linux/OpenGL quality first.
- Keep glyph upload incremental and bounded per frame.

## Primary Fonts

- `assets/fonts/JetBrainsMonoNerdFont-Regular.ttf`
- `assets/fonts/IosevkaTermNerdFont-Regular.ttf`

## Key References

- Architecture: `app_architecture/ui/font_rendering_architecture.md`
- Special glyph coverage: `app_architecture/ui/terminal_special_glyph_coverage.md`
- Special glyph execution plan: `app_architecture/ui/terminal_special_glyph_todo.md`
- Ligature track: `app_architecture/ui/terminal_ligatures_todo.md`
- Zide code: `src/ui/terminal_font.zig`, `src/ui/renderer/gl_backend.zig`, `src/ui/renderer/font_manager.zig`, `src/ui/renderer/text_draw.zig`

## Validation Commands

- Always: `zig build`, `zig build test`, `zig build check-app-imports`, `zig build check-input-imports`, `zig build check-editor-imports`
- Smoke: `zig build run -- --mode terminal`, `zig build run`

## TODO

- [x] `FR-0-00` Document architecture and module contracts
  - Authority lives in `app_architecture/ui/font_rendering_architecture.md`.
- [x] `FR-0-01` Add deterministic font sample mode
- [x] `FR-0-02` Expand reference captures
- [x] `FR-1-01` Split terminal atlas into coverage vs color
- [x] `FR-1-02` Add linear-blending shader path
- [x] `FR-1-03` Remove CPU-side gamma baking during upload
- [x] `FR-1-04` Add text weight and gamma tuning knob
- [x] `FR-2-01` Add configurable hinting policy
- [x] `FR-2-02` Match HarfBuzz FT load flags to rasterization
- [x] `FR-3-00` Support combining marks in terminal cells
- [x] `FR-3-01` Implement run-based terminal shaping
- [x] `FR-4-01` Add background-aware editor text correction
- [ ] `FR-5-01` Evaluate LCD and subpixel AA as an opt-in experiment
  - Tooling and report helpers exist.
  - Current decision: keep LCD off by default until visual QA signs off.
  - Exit criteria:
    - [ ] Visual QA for JetBrainsMono and IosevkaTerm at 12/14/16/20
    - [ ] No obvious color fringing under selections, cursor inversion, or gutter overlays
    - [ ] Repeatable reports from `tools/font_sample_lcd_report.sh`
    - [ ] Snapshot history from `tools/font_sample_lcd_snapshot.sh`
- [x] `FR-V-01` Smoke terminal mode and default run
- [x] `FR-V-02` Regression-check the font sample capture path


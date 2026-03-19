# Font Rendering TODO

## Scope

Make editor and terminal text rendering competitive with modern terminals: crisp small sizes, correct blending, stable metrics, and explicit editor/terminal font-stack differences.

Status note, 2026-03-15:

- Most foundational font-rendering work is landed.
- The live queue is now narrower:
  - LCD/subpixel evaluation as an opt-in quality experiment
  - keeping terminal special-glyph quality moving through its dedicated queue
- This is still relevant, but no longer the broad primary execution lane it was
  earlier in the rewrite.

Status note, 2026-03-19:

- Windows editor text QA exposed flaky stems and dropped stroke fragments under
  the current OpenGL path at fractional DPI.
- The most important fix so far is to stop per-glyph device-pixel snapping when
  the render scale is non-integer; that removed most severe Windows artifacts at
  `render_scale = 1.25`.
- The current remaining Windows issue is no longer "missing fragments"; it is a
  softer sampling/placement problem that still makes editor text look less
  stable than native Windows references.
- The queue now needs a Windows-specific fixture/review lane instead of more
  blind tuning.

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
- Special glyph execution plan: `docs/todo/ui/terminal_special_glyphs.md`
- Ligature track: `docs/todo/ui/terminal_ligatures.md`
- Zide code: `src/ui/terminal_font.zig`, `src/ui/renderer/gl_backend.zig`, `src/ui/renderer/font_manager.zig`, `src/ui/renderer/text_draw.zig`
- Cross-platform runtime references:
  - `reference_repos/terminals/wezterm/wezterm-gui/src/utilsprites.rs`
  - `reference_repos/terminals/alacritty/alacritty/src/event.rs`
  - `reference_repos/terminals/alacritty/alacritty/src/window_context.rs`
  - `reference_repos/backends/sdl/src/render/SDL_render.c`

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
- [ ] `FR-4-02` Add a Windows fractional-DPI fixture/review lane
  - Required coverage:
    - 100/125/150/175/200/250/300% DPI
    - same text in Zide vs a Windows-native reference app
    - JetBrainsMono and IosevkaTerm at 12/14/16/20
  - Required artifacts:
    - repeatable sample text
    - cropped comparison captures or equivalent deterministic sample mode
    - brief review notes in the owning Windows queue
- [ ] `FR-4-03` Finish the fractional-DPI geometry contract
  - The current likely remaining seam is destination quad sizing / baseline
    stability / atlas sampling interaction, not hinting policy alone.
  - Current prerequisite seam:
    - OS/display truth now belongs to `src/platform/display_metrics.zig`
    - renderer/font code should use that contract instead of adding new raw SDL
      scale reads
    - Windows contract correction, 2026-03-19:
      - `render_scale` now follows actual pixel density / drawable ratio
      - Windows content/display scale now enters layout through `ui_scale`
      - this should remove the old "layout 16 -> raster 20 -> present back into
        a 1x buffer" path that was smearing fractional-DPI text quality
    - 2026-03-19 extraction landed:
      - renderer-owned scaled font metrics now carry logical cell width/height
        and baseline-from-top for terminal/icon fonts
      - editor/terminal text draw paths now consume that shared scaled baseline
        instead of recomputing it directly from `font.baseline_from_top`
      - terminal widget/grid/hover/input consumers now read shared scaled cell
        metrics, so the remaining drift is in how those metrics are derived and
        quantized, not in multiple competing sources of truth
      - the shared scaled metric set now includes ascent/descent/line-height in
        addition to cell width/height and baseline-from-top
  - Reference-backed next pass:
    - follow `alacritty` for runtime scale-factor -> effective font-size updates
    - follow `wezterm` for pixel-rounded cell metrics and baseline/descender
      discipline
    - follow SDL view-scale math for scaled destination geometry and ceil/round
      boundary handling
  - Reverted experiment, 2026-03-19:
    - fractional linear filtering for the coverage atlas caused half-drawn
      glyphs and obvious fuzz in both editor and terminal mode
    - current policy remains nearest-filtered coverage atlases while the
      fractional-DPI quality work continues through geometry/metric fixes
  - Current geometry pass, 2026-03-19:
    - glyph destination rects now quantize width/height from the same snapped
      edge contract as their current origins, instead of mixing snapped origins
      with independently fractional extents
    - editor shaped text, terminal shaping, and direct terminal glyph draws are
      all on that extent-quantized path now
    - glyph fit-to-cell behavior now compresses width only; it no longer scales
      height/baseline vertically just because a glyph is slightly too wide for
      the monospace cell
    - terminal font cell width rounding now uses `ceil`, matching the existing
      line-height policy and the WezTerm-style reference direction; this is
      intended to reduce unnecessary horizontal squeeze at fractional DPI
    - direct glyph draws no longer inset coverage-atlas UVs by half a texel;
      they now match the glyph-cache path and sample the full atlas rect
    - width-fit decisions for regular glyphs now use advance width instead of
      raw raster bitmap width, so overshoot/antialias fringe no longer causes
      per-glyph horizontal squeeze
    - regular text glyphs no longer apply horizontal fit-to-cell squeeze at
      all; only explicit symbol/powerline handling is allowed to overhang
    - vertical quantization now snaps glyph origin only and preserves raster
      height, instead of snapping both top and bottom edges and flattening the
      lower parts of letters
  - Reverted rasterization experiment, 2026-03-19:
    - switching Windows defaults to `"normal"` hinting with `autohint = false`
      did not materially improve the remaining uneven stroke weight
    - current focus stays on metric/geometry behavior rather than more hinting
      churn
  - Do not flip filtering/hinting settings casually without preserving a
    repeatable comparison.
- [ ] `FR-5-01` Evaluate LCD and subpixel AA as an opt-in experiment
  - Tooling and report helpers exist.
  - Current decision: keep LCD off by default until visual QA signs off.
  - Windows-specific note:
    - DirectWrite references confirm ClearType/subpixel rendering is not the
      same as compositing grayscale coverage through a transparent intermediate.
    - If Windows quality remains below bar after geometry fixes, evaluate LCD as
      an explicit Windows experiment, not as an accidental side effect.
  - Exit criteria:
    - [ ] Visual QA for JetBrainsMono and IosevkaTerm at 12/14/16/20
    - [ ] No obvious color fringing under selections, cursor inversion, or gutter overlays
    - [ ] Repeatable reports from `tools/font_sample_lcd_report.sh`
    - [ ] Snapshot history from `tools/font_sample_lcd_snapshot.sh`
- [x] `FR-V-01` Smoke terminal mode and default run
- [x] `FR-V-02` Regression-check the font sample capture path

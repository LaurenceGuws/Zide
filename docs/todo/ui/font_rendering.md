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

Status note, 2026-03-20:

- The main Windows fractional-DPI bug was the wrong scale split: content scale
  and raster scale were both effectively flowing through `render_scale`.
- After correcting the Windows `ui_scale` / `render_scale` contract and
  landing the follow-up glyph geometry fixes, editor and terminal text at 125%
  are now user-accepted on the current Windows validation machine.
- JetBrainsMono and IosevkaTerm both now render cleanly enough on that
  corrected path that font choice is no longer hiding a shared renderer bug.
- The remaining work is narrower:
  - fixture/review authority across the broader DPI matrix
  - reference-app comparison
  - startup font-init churn cleanup

Status note, 2026-03-30:

- Terminal/editor/app font init now wires the bundled fallback stack directly
  instead of leaving all fallback slots null and relying entirely on host
  system fallback.
- Active bundled fallback paths now include:
  - `SymbolsNerdFontMono-Regular.ttf`
  - `NotoSansSymbols2-Regular.ttf`
  - `NotoSansSymbols-Regular.ttf`
  - `NotoSansMono-Regular.ttf`
  - `NotoSans-Regular.ttf`
  - `NotoColorEmoji.ttf`
  - `NotoEmoji-Regular.ttf`
- This is intended to reduce cross-platform drift, especially the Linux case
  where Fontconfig can route some emoji-presenting codepoints and emoji-style
  sequences into non-emoji fonts even when a color emoji font is installed.
- This does not by itself close sequence-level emoji shaping parity; it is a
  fallback-stack correctness baseline.

Status note, 2026-04-04:

- The renderer/font-side fractional-DPI contract is no longer the whole scale
  problem.
- A broader app-wide geometry ownership contradiction is now explicit:
  - widgets still see raw scale surfaces
  - widgets still do their own snap math
  - terminal draw/overlay/input/hover still own too much last-mile geometry
- That broader lane now has its own queue:
  - [window_scale_geometry.md](/home/home/personal/zide/docs/todo/ui/window_scale_geometry.md)
- Read `FR-4-03` as a renderer/font contract checkpoint, not as closure of the
  app-wide geometry ownership problem.

Status note, 2026-04-12:

- Android pinch testing reopened one shared renderer font lifecycle seam and
  forced real cleanup in terminal font ownership.
- That lane is now good enough to stop as an active polish front:
  release-build Android validation puts pinch/zoom responsiveness at the
  accepted product boundary for the current terminal goal.
- Keep the architecture lesson, not the old urgency framing:
  hinted bitmap text still commits by pixel-sized raster state, so future work
  should continue treating terminal font lifecycle as size-keyed renderer-core
  ownership, not Android gesture glue.

Status note, 2026-04-12 (fast-pinch boundary):

- The Android host gesture seam is now materially cleaner:
  - `ProductGestureController` owns single-tap and pinch policy explicitly
  - raw detector churn is quantized/coalesced before native apply
  - native apply cadence is host-budgeted instead of forwarding every raw
    gesture burst
- Device result after that cleanup:
  - slow and medium pinch are strong
  - aggressive fast pinch is acceptable on the current release-build Android
    product path
- Interpretation:
  - Android host gesture policy is no longer the active blocker
  - the useful outcome of this lane was renderer-core cleanup:
    size-keyed terminal font caching, async visible-glyph prep, committed-target
    cache population, and prepared-target promotion after adopt
  - any further extreme-burst refinement is deferred until it is justified by
    a stronger product need
- Do not keep this open as an active Android pinch-polish lane.

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
  - `dev_references/terminals/wezterm/wezterm-gui/src/utilsprites.rs`
  - `dev_references/terminals/alacritty/alacritty/src/event.rs`
  - `dev_references/terminals/alacritty/alacritty/src/window_context.rs`
  - `dev_references/backends/sdl/src/render/SDL_render.c`

## Validation Commands

- Always: `zig build`, `zig build test`, `zig build check-app-imports`, `zig build check-input-imports`, `zig build check-editor-imports`
- Smoke: `zig build run -- --mode terminal`, `zig build run`
- Cross-platform regression after Windows DPI/rendering work:
  - Linux: `zig build`, `zig build -Dmode=editor`, `zig build -Dmode=terminal`
  - Linux visual fixture: `zig build run -- --mode font-sample`

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
- [x] `FR-4-03` Finish the fractional-DPI geometry contract
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
  - Terminal overlay/input correction, 2026-04-04:
    - the terminal widget now snaps its viewport origin to device pixels once
      from `render_scale`, then reuses that same origin for draw, hover, open,
      pointer, and mouse-reporting paths
    - the terminal cursor overlay no longer rounds per-cell logical positions
      to integer logical pixels; it derives cursor rects from the snapped
      origin plus exact logical cell metrics so fractional-scale drift cannot
      accumulate down rows/columns
  - Reverted rasterization experiment, 2026-03-19:
    - switching Windows defaults to `"normal"` hinting with `autohint = false`
      did not materially improve the remaining uneven stroke weight
    - current focus stays on metric/geometry behavior rather than more hinting
      churn
  - Validated state, 2026-03-20:
    - on the current Windows machine, `125%` editor and terminal rendering are
      now user-accepted for both JetBrainsMono and IosevkaTerm
    - broader regression authority still belongs to `FR-4-02`, native
      reference-app comparison, and startup cleanup
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
    - [ ] Repeatable reports from `tools/observability/rendering/font/font_sample_lcd_report.sh`
    - [ ] Snapshot history from `tools/observability/rendering/font/font_sample_lcd_snapshot.sh`
- [x] `FR-V-01` Smoke terminal mode and default run
- [x] `FR-V-02` Regression-check the font sample capture path
- [x] `FR-6-01` Add size-keyed terminal font/atlas lifecycle
  - Trigger: Android pinch zoom exposes visible thickness snap when the live
    scaled atlas swaps to the committed hinted atlas.
  - Required design:
    - key committed font state by font identity, rendering options, render
      scale, rounded raster pixel size, and text domain
    - reuse prepared `TerminalFont`/atlas instances instead of destroying all
      active font state on every committed zoom
    - keep HarfBuzz load flags and FreeType load flags aligned for every
      committed size
    - keep terminal cell metrics pixel-rounded and coherent with baseline and
      glyph placement
  - Do not do:
    - do not use glyph warmup as a substitute for size-keyed font ownership
    - do not claim perfectly continuous hinted-stem thickness unless the text
      path changes to a different preview technology such as SDF/vector text
  - Progress:
    - first committed-size cache cut landed for terminal fonts
    - committed terminal atlases are retained by render scale plus raster pixel
      size across settled zoom commits
    - current committed size now prepares a bounded neighbor set of twelve
      raster-pixel sizes below and twelve above
    - terminal live glyph visual scale remains continuous so live glyph
      geometry stays coupled to live cell geometry
    - active pinch now swaps to a prepared terminal committed raster font when
      the rounded raster-pixel size enters the prepared neighbor window,
      without rebuilding app/editor/icon font state in the gesture path
    - audit result: current prepared committed fonts are still shallow because
      glyphs are realized lazily on first lookup
    - first ownership split landed:
      CPU glyph raster preparation is now a distinct `TerminalFont` payload,
      and atlas upload/adoption is a separate step
    - renderer runtime now owns a dedicated terminal glyph-prep request/result
      state with generation tracking so worker results have a real adoption
      landing zone
    - renderer now exposes explicit queue/publish/take helpers for terminal
      glyph-prep requests/results instead of leaving future worker code to
      mutate raw state directly
    - next cut must stage visible terminal glyph preparation asynchronously on
      top of that seam
    - validated Android boundary, 2026-04-12:
      - producer/request churn and host gesture spam are no longer the main
        fast-pinch issue
      - this lane now has enough renderer-owned structure to stop as active
        polish for the current Android product target
- [x] `FR-6-02` Split terminal glyph preparation into async CPU prep plus render-thread adoption
  - Trigger: fast Android pinch still outruns the current size-keyed cache even
    after live geometry and prepared-font swap improvements.
  - Required design:
    - define a terminal-font preparation request keyed by terminal font
      identity, rendering options, render scale, committed raster size, and a
      visible terminal glyph-set plan
    - keep cache identity separate from readiness, following the useful kitty
      ownership pattern: "known glyph instance" is not the same thing as
      "uploaded/adopted for draw"
    - allow a worker to prepare CPU-owned font/glyph state only
    - keep all GPU atlas upload and live renderer adoption on the render thread
    - ensure stale worker results are discarded by generation/key mismatch
  - Progress:
    - visible terminal glyph demand can now be collected from the real
      direct/shaped terminal draw path as deduped
      `Renderer.TerminalGlyphPrepEntry` records
    - that collector mirrors current row/span visibility and shaping decisions
      instead of guessing from ASCII warmup or whole-font speculation
    - the terminal draw path now stages renderer-owned prep requests keyed by
      committed raster size, render scale, and the collected visible glyph set
    - renderer now runs a dedicated worker that consumes those requests and
      prepares CPU-only glyph rasters against a temporary committed-size font
      instance
    - worker output is published back into renderer-owned result state with
      generation checks so stale prep work can be discarded
    - the render thread now adopts ready glyph rasters into the live committed
      terminal atlas before draw lookup falls back to inline rasterization
  - Stop marker:
    - fast pinch can land on ready committed terminal glyph state without
      forcing inline glyph realization on the render thread
  - Do not do:
    - do not move GPU texture upload or backend-owned atlas mutation to a
      worker thread
    - do not hide render-thread stalls behind a larger prepared-size window
  - Validated result, 2026-04-12:
    - async visible-glyph prep is now part of the accepted renderer baseline
      for the Android terminal pinch path
    - committed-target promotion now follows prepared-result adoption instead
      of waiting solely on the settled rebuild path

- [x] `FR-6-03` Split `TerminalFont` CPU preparation from GPU atlas allocation
  - Trigger: Android burst pinch now proves the renderer needs current-target
    committed font recovery before gesture end, but async glyph rasters alone
    cannot provide that recovery authority.
  - Required design:
    - define a CPU-only prepared terminal-font state that can be built off the
      render thread
    - keep GPU atlas creation/upload/adoption render-thread-owned
    - allow a worker to prepare the current committed terminal target as a font
      instance/state, not only as detached glyph rasters
    - let the render thread swap to that prepared target immediately when ready
  - Concrete blocker:
    - `TerminalFont.initWithAtlasUploadHooks(...)` still assumes GPU-backed
      atlas allocation unless a backend hook replaces it
    - for Android/GLES that blocks worker-safe committed target preparation,
      because the fallback path still creates GL textures
  - Progress:
    - first code cut landed:
      `TerminalFont.initCpuPrepared(...)` now creates a backend-agnostic
      CPU-prepared font instance without GL texture allocation
    - the async terminal glyph-prep worker now uses that CPU-prepared init path
      instead of the old GL-backed fallback
    - prepared results now populate committed target cache entries and trigger
      committed-target promotion after adopt
  - Stop marker:
    - a prepared committed terminal target can be built without touching GL/GPU
      state and later adopted/swapped on the render thread
  - Do not do:
    - do not keep using settled full font-stack rebuild as the recovery
      authority for burst pinch
    - do not treat this as Android-only; it is shared terminal/font ownership

Startup cleanup note, 2026-03-20:

- renderer bootstrap now seeds initial font path, size, hinting/autohint, and
  text correction from loaded config before the first `initFonts(...)` pass
- `.zide.lua` is back on the quiet checked-in baseline after the Windows
  investigation

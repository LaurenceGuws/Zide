# Editor Stress And Reference Plan

## Purpose

Turn editor pressure testing and reference comparison into an explicit execution
lane with:

- clear scope
- concrete stress targets
- explicit reference repos
- documentation outputs that improve Zide's own architecture understanding

This queue exists so editor investigation work produces durable subsystem
clarity rather than a pile of one-off notes.

## Authority Split

This file owns:

- the active stress/reference queue
- comparison scope
- execution ordering
- expected documentation outputs

It does not own:

- durable editor subsystem design
- editor FFI contract
- theme contract details

Those live in:

- `app_architecture/editor/DESIGN.md`
- `app_architecture/editor/FFI_DESIGN.md`
- `app_architecture/editor/RESOLVED_THEME_EXPORT_CONTRACT.md`
- `app_architecture/editor/LSP_THEME_OVERLAY_BOUNDARY.md`

## Current Goal

The baseline editor/app behavior is now strong enough that deeper pressure
testing should measure the real editor subsystem instead of obvious missing UX.

The next lane is:

1. stress the editor core and render path end-to-end
2. compare Zide against strong editor/IDE references
3. capture the results in docs and diagrams that make Zide's own stack easier
   to reason about

## Constraints

1. Investigation must improve Zide's architecture docs.
   If a comparison does not sharpen our own boundary understanding, it is low
   value.

2. Reference repos are tools, not goals.
   We compare to learn design tradeoffs and quality bars, not to cargo-cult
   their structure.

3. Stress work should be end-to-end where possible.
   The useful questions are not just "is rope operation X fast" but "what
   actually happens from edit to highlight to render."

4. Diagrams must be explicit.
   No directionally ambiguous lines, and no avoidable crossing-heavy layouts.

## Reference Set

Current local references already in scope under `reference_repos/editors/`:

- `neovim`
- `helix`
- `kakoune`
- `lapce`
- `lite-xl`
- `xi-editor`
- `zed`

Use them by concern:

- text/edit semantics: `neovim`, `helix`, `kakoune`
- large-file/edit pipeline and responsiveness: `helix`, `zed`, `lapce`, `lite-xl`
- editor/IDE host and workspace layering: `zed`, `lapce`
- theming richness: `neovim`, `helix`

Add more references only when a concrete gap appears in this matrix.

## Stress Matrix

### Core text model

- large-file open cost
- repeated insert/delete near file start, middle, and end
- multi-line line operations
- undo/redo pressure under repeated edits

### Editor semantics

- cursor/selection correctness under long lines and Unicode text
- line operations under dirty state
- multi-caret and rectangular selection pressure
- search/replace churn while editing

### Syntax/highlight runtime

- query startup cost
- highlight invalidation after edits
- search/highlight coexistence
- grammar-missing and fallback behavior

### View/render path

- scroll smoothness on large buffers
- viewport updates after rapid edit bursts
- cache invalidation behavior
- render cost under selection/search/highlight overlays

### App/host routing

- mixed editor/terminal tab correctness
- repeated file open/close/save/cycle behavior
- prompt routing correctness during active edits

## Required Outputs

Every serious comparison/stress pass should produce at least one of:

- a durable architecture doc update
- a queue update with explicit next actions
- a focused comparison write-up under `docs/research/`
- a diagram that clarifies a real subsystem communication path

Do not leave the work only in commit history or chat context.

## Initial Worklist

- [ ] `ED-STRESS-01` Capture the end-to-end editor pipeline in docs
  - Expand the editor design docs with explicit communication flow from input
    through editor core, syntax/search runtime, widget/view code, renderer, and
    present sink.
  - Keep the diagrams directional and easy to trace.

- [x] `ED-STRESS-02` Define the first local stress harness matrix
  - The first repeatable ritual now lives in:
    - `docs/research/editor/EDITOR_STRESS_RITUAL_2026-03-18.md`
  - Exact first-pass workload authority:
    - use `zig build perf-editor-headless` for synthetic large-file headless
      metrics at `1 MiB`, `8 MiB`, and `32 MiB`
    - use `fixtures/editor/stress/large_highlight_sample.zig` as the first
      syntax-heavy real file workload
    - use `zig build -Dmode=editor -Doptimize=ReleaseFast` plus the same
      fixture for manual open/edit/scroll/search verification
  - Recording ritual is now explicit:
    - build mode
    - exact commands
    - fixed seed/query/frame parameters
    - result doc location
  - Current caution:
    - `tools/perf_editor_gate.sh` references older synthetic fixture names that
      are not currently the stress authority; refresh that gate only after the
      first manual/headless ritual is exercised and trusted

- [ ] `ED-STRESS-03` Map Zide against the current reference set by concern
  - Record which reference repos matter for which editor questions.
  - Avoid vague "compare to everything" framing.
  - Initial focused comparison set:
    - `helix`:
      - text-core/editor-core split
      - rope/transaction/edit semantics
      - indent/search/syntax core modules
    - `neovim`:
      - resolved theming richness
      - query/highlight behavior
      - editor/runtime authority separation
    - `zed`:
      - editor/IDE host layering
      - multi-buffer/workspace structure
      - render/perf instrumentation practices
    - `lapce`:
      - proxy/editor split and background work separation
      - rope-backed editor core in a GUI/editor host

- [ ] `ED-STRESS-04` Start with core text + render pipeline checks
  - Prefer the first end-to-end checks that exercise text model, editor state,
    highlight/runtime, and rendering together.
  - First concrete pass should follow the ritual in
    `docs/research/editor/EDITOR_STRESS_RITUAL_2026-03-18.md` before adding
    broader comparison noise.

- [ ] `ED-STRESS-05` Write findings back into architecture docs
  - If stress work reveals an unclear subsystem seam, capture the corrected
    understanding in `app_architecture/editor/`.

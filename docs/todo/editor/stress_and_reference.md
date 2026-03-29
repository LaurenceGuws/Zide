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

Current local references already in scope under `dev_references/editors/`:

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

## Current Architectural Finding

The first interactive Unicode startup probe exposed a boundary bug, not just a
slow code path:

- visible-cache warmup was routed through widget `lineData`
- widget `lineData` implicitly owned grapheme-cluster cache lifetime
- that made render-prep and widget hit-testing share expensive Unicode shaping
  through the wrong seam

Direction locked from this finding:

- durable display metrics such as line widths and grapheme-cluster offsets must
  be editor/render-owned state
- widget code should consume those metrics for hit-testing and drawing, but it
  should not own the cache lifetime
- future perf work in this area should deepen that editor/render display-metric
  lane instead of adding more startup deferral logic

The follow-up threading probe exposed the next boundary issue:

- repeated visible highlight rework was fixable with better cache/work
  ownership
- but even the corrected incremental path still produced highlight on the
  foreground frame lane
- the user-visible result was streaming highlight during startup/navigation
  convergence, which is not an acceptable final behavior

Direction locked from this finding:

- visible highlight generation must move out of widget/frame precompute
- the next lane is a dedicated editor-runtime highlight worker or equivalent
  editor-owned execution seam
- frame hooks should request work and consume completed results, not execute the
  expensive highlight query directly

The broader architecture review also confirmed that this is part of a larger
stack issue, not an isolated highlight bug:

- text/document ownership, view state, runtime work, display caches, widget
  input, app routing, and renderer publication are still not cleanly layered
- the next serious editor work needs to be planned as an end-to-end subsystem
  redesign from text engine through SDL/native presentation
- redesign planning authority now lives in:
  - `app_architecture/editor/EDITOR_STACK_REDESIGN_PLAN.md`
  - `app_architecture/editor/DOCUMENT_CORE_AND_VIEW_STATE_BOUNDARY.md`
  - `app_architecture/editor/EDITOR_RUNTIME_CONTRACT.md`
  - `app_architecture/editor/EDITOR_DISPLAY_SNAPSHOT_CONTRACT.md`
  - `app_architecture/RENDERER_SCENE_PUBLICATION_CONTRACT.md`
  - `app_architecture/editor/EDITOR_REDESIGN_EXECUTION_ROADMAP.md`

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
    - use `fixtures/editor/stress/unicode_longline_sample.txt` as the first
      long-line and Unicode real file workload
    - use `zig build -Dmode=editor -Doptimize=ReleaseFast` plus those same
      fixtures for manual open/edit/scroll/search verification
  - Recording ritual is now explicit:
    - build mode
    - exact commands
    - fixed seed/query/frame parameters
    - result doc location
  - Supporting local gate now aligned:
    - `tools/observability/perf/perf_editor_gate.sh`

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
  - Focused threading/runtime comparison now captured in:
    - `docs/research/editor/EDITOR_THREADING_COMPARISON_2026-03-19.md`

- [ ] `ED-STRESS-04` Start with core text + render pipeline checks
  - Prefer the first end-to-end checks that exercise text model, editor state,
    highlight/runtime, and rendering together.
  - First concrete pass should follow the ritual in
    `docs/research/editor/EDITOR_STRESS_RITUAL_2026-03-18.md` before adding
    broader comparison noise.
  - Headless first-pass results now live in:
    - `docs/research/editor/EDITOR_STRESS_RESULTS_2026-03-18.md`
  - Remaining gap for this item:
    - native interactive observations on the real widget/runtime/render path
  - Supporting local gate now aligned:
    - `tools/observability/perf/perf_editor_gate.sh`

- [ ] `ED-STRESS-05` Write findings back into architecture docs
  - If stress work reveals an unclear subsystem seam, capture the corrected
    understanding in `app_architecture/editor/`.

- [ ] `ED-STRESS-06` Replace foreground visible highlight warmup with editor-runtime work
  - Current authority from the comparison:
    - `docs/research/editor/EDITOR_THREADING_COMPARISON_2026-03-19.md`
  - Required outcome:
    - widget/frame precompute no longer calls expensive highlight generation
    - highlight work is owned by a persistent editor-runtime seam
    - UI thread only requests work, applies completed results, and redraws

- [ ] `ED-STRESS-07` Plan the full editor stack redesign
  - Current authority:
    - `app_architecture/editor/EDITOR_STACK_REDESIGN_PLAN.md`
  - Required outputs:
    - explicit layer split from text buffer to SDL/present
    - explicit execution lanes and publication seams
    - phased cut plan for core/runtime/display/widget/renderer boundaries

- [ ] `ED-STRESS-08` Split document truth from view state
  - Current authority:
    - `app_architecture/editor/DOCUMENT_CORE_AND_VIEW_STATE_BOUNDARY.md`
  - Required outcome:
    - `DocumentCore` owns document truth and file/runtime identity
    - `EditorViewState` owns viewport-local state
    - direct widget mutation of mixed document/view fields starts disappearing
  - Current progress:
    - `Editor` now has real `DocumentCore` / `EditorViewState` backing storage
    - file/dirty/document/runtime consumers were swept onto document-owned
      state across app/editor/widget call sites
    - scroll/preferred-column consumers were swept onto view-owned state across
      cursor/scroll/widget/navigation paths
    - `zig build test` is green after the storage move
    - `zig build -Dmode=editor -Doptimize=ReleaseFast` is green after the
      storage move
    - the first view-state API extraction is started:
      - preferred-visual-column clears now route through explicit editor
        methods in the main navigation/edit/selection paths
      - the first scroll writes now route through explicit editor setters in
        widget and view-scroll paths
      - the FFI bridge now routes its reset/edit entrypoints through
        document/view-aware editor surfaces instead of old mixed editor fields
    - the first document-state API extraction is started:
      - file/saved/modified/highlight-pending/highlight-epoch/change-tick now
        have explicit editor helpers
      - the highlight/search lane has started moving onto those helpers instead
        of raw `doc.*` writes
      - remaining raw document mutation is now concentrated mostly in the
        search worker/request/result seam
      - search result publication now routes through explicit editor helpers;
        the main remaining search-side raw seam is worker synchronization
        (mutex/condition/lifecycle)
    - remaining view-state work is now narrow edge cleanup rather than broad
      write-surface extraction
    - checkpoint decision:
      - freeze `Phase 1` here
      - treat search worker synchronization as the first explicit `Phase 2`
        extraction target

- [ ] `ED-STRESS-09` Define the editor runtime publication seam
  - Current authority:
    - `app_architecture/editor/EDITOR_RUNTIME_CONTRACT.md`
  - Required outcome:
    - search and highlight are owned by `EditorRuntime`
    - render cache stops owning highlight queue/progress state
    - runtime completion can wake/redraw without unrelated input
  - First implementation target:
    - extract the existing search worker synchronization seam into explicit
      runtime-owned state before tackling visible highlight runtime ownership
  - Current progress:
    - the first structural cut is in code:
      - search worker lifecycle/request/result/generation state is being moved
        under a named runtime-oriented sub-structure
      - lock/signal/request/result coordination is being routed through
        explicit helper verbs
      - pending search result application is now initiated from the frame hook
        instead of being hidden in display prepare
      - highlight scheduling ownership has moved off render cache and onto
        editor-owned state
      - visible highlight publication now also drives redraw from the frame
        hook when a batch publishes tokens
      - visible highlight scheduling now lives under a named editor-owned
        runtime block keyed by visible-range work state rather than a separate
        startup-only control flag
      - visible highlight now also has runtime request/result mailbox state,
        though execution is still synchronous
      - visible highlight cache publication now happens from the
        editor frame/runtime lane instead of widget precompute
      - visible highlight completion now uses the runtime result mailbox plus
        host wake instead of a separate frame-local redraw flag
      - visible highlight scheduling and execution are now separate phases in
        code, though execution is still synchronous
      - visible highlight execution is now called explicitly from the
        app/runtime precompute path
      - visible highlight execution logic is now editor-owned rather than
        widget-owned
      - visible highlight runtime now carries worker/lifecycle/sync state
        parallel to the search seam
      - visible highlight precompute now schedules worker execution instead of
        running highlight inline
      - visible highlight throttling is now derived from visible-range
        completion and in-flight runtime state rather than a standalone startup
        warmup flag
      - local Unicode repro now shows ordered worker progression through the
        visible range (`0-4`, `4-8`, ... `32-33`) with matching publish events
      - visible highlight request/result/compute-in-flight mailbox access is
        now guarded behind the runtime mutex, fixing the first real worker-path
        race/segfault in the local Unicode repro
      - visible cache precompute logging now distinguishes highlight-running
        frames from layout-only frames so worker/runtime cleanup can be judged
        against honest telemetry instead of mixed-path noise
      - current Unicode repro now shows tighter worker cadence: publication and
        next-batch scheduling chain together in the same frame for the main
        visible range, with only the final tail leaving one layout-only frame
        after the last publish
      - wrap-work completion now remembers completed visible ranges, removing
        the long `run_highlight=false` layout-only storm that used to continue
        after visible highlight work had effectively finished
      - frame-hook visible precompute now asks the render cache whether
        width/wrap work is still pending for the current visible range instead
        of treating highlight-worker `in_flight` as a layout signal; the local
        Unicode repro no longer shows the empty layout-only churn that used to
        continue while the worker computed `28-32`
      - draw preparation no longer fabricates heuristic large-file fallback
        tokens when the real highlighter is absent, so visible highlight output
        and logs now reflect actual runtime/highlighter truth instead of a
        tree-sitter limitation workaround in the render path
      - visible highlight startup no longer trickles through the viewport `4`
        lines at a time; with worker execution off the UI lane, the local
        Unicode repro now schedules the full visible range in one batch
        (`start_line=0 end_line=33`, `highlight_budget=64`)
      - visible precompute now follows a worker schedule contract instead of
        the old inline-publish contract
      - worker completion now has a real host wake path instead of relying on
        unrelated input or forced redraw churn:
        - search and visible-highlight workers request an explicit runtime wake
          after publishing results
        - the SDL host consumes that wake as a no-op event that only exists to
          break idle waiting
        - frame-hook editor runtime no longer keeps redraw forced just because
          visible highlight compute is still in flight
        - pending search result publication no longer keeps redraw hot either;
          the frame hook just applies the completed mailbox on the next
          wake-driven frame
      - next cleanup target is to keep deleting remaining startup-era control
        branches that still muddy the runtime signal
      - this is still behavior-preserving and does not yet claim full runtime
        ownership

- [ ] `ED-STRESS-10` Define immutable display publication
  - Current authority:
    - `app_architecture/editor/EDITOR_DISPLAY_SNAPSHOT_CONTRACT.md`
  - Required outcome:
    - draw consumes immutable published display state
    - `EditorFrameView` stops being a live backpointer façade
    - widget callback fetches for visible line/cluster truth start disappearing

- [ ] `ED-STRESS-11` Converge editor and terminal on one renderer publication model
  - Current authority:
    - `app_architecture/RENDERER_SCENE_PUBLICATION_CONTRACT.md`
  - Required outcome:
    - renderer scene target stays authoritative
    - editor and terminal publish render-facing state into one host draw model
    - renderer stops accreting long-term product-specific target APIs

- [ ] `ED-STRESS-12` Execute the redesign in phased cuts
  - Current authority:
    - `app_architecture/editor/EDITOR_REDESIGN_EXECUTION_ROADMAP.md`
  - Required outcome:
    - redesign proceeds through reviewable phases with explicit gates
    - replay/perf/manual validation stays attached to each phase
    - the first implementation cut is `DocumentCore` + `EditorViewState`
  - Current checkpoint:
    - `Phase 1` storage split is real
    - dominant document/view write surfaces are now API-driven
    - remaining raw document seam is search worker synchronization
    - remaining raw view work is narrow edge cleanup
    - next decision is whether search worker synchronization closes `Phase 1`
      or opens `Phase 2`

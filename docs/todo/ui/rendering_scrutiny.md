# Rendering Scrutiny

## Scope

Track the remaining SDL3/OpenGL renderer architecture work after the residue
purge.

This queue exists to answer one question:

- what still prevents `src/ui/renderer.zig` from reading like a serious
  renderer host over one scene/present truth?

This is not a general UI roadmap.
It is the execution queue for the remaining renderer-center campaign.

## Authority

Use these as the current authority set for this lane:

- `app_architecture/RENDERER_SCENE_PUBLICATION_CONTRACT.md`
- `app_architecture/ui/DEVELOPMENT_JOURNEY.md`
- `docs/research/SDL_GL_RENDERER_SCRUTINY_2026-04-02.md`
- `docs/review/SDL_GL_RENDERER_AUDIT_2026-04-02.md`

## Current State

The easy SDL/GL lies are mostly dead:

- startup probe shell removed
- input bring-up noise removed
- fake backend selector removed
- fake forwarding shells removed
- product-specific renderer target APIs removed from `renderer.zig`
- dead SDL input slab removed
- live SDL input polling now runs through an explicit `InputDomain` view
  instead of reaching across `Renderer` field-by-field

What remains is not residue. It is ownership concentration.

`src/ui/renderer.zig` is still too large and too semantically mixed.

Status note, 2026-04-02:

- after the owner moves and grouped-state cuts in this queue, the remaining
  renderer root now reads much closer to honest render-core state
- the loud fake-center pressure is materially lower than it was at the start of
  this scrutiny round
- host scene assembly now lives in `src/app/scene_assembly_runtime.zig`
  instead of sitting inline in `src/app/draw_frame_runtime.zig`
- host present-completion and subsystem feedback now live in
  `src/app/present_feedback_runtime.zig` instead of sitting inline in
  `src/app/draw_frame_runtime.zig`
- editor live-smoke capture arming now lives in
  `src/app/editor/live_smoke_runtime.zig` instead of sitting inline in
  `src/app/draw_frame_runtime.zig`
- editor pending-highlight redraw now lives in
  `src/app/editor/editor_draw_surface_runtime.zig` instead of sitting inline in
  `src/app/draw_frame_runtime.zig`
- the next move should be another re-rank before any more cuts, not automatic
  repacking

Status note, later on 2026-04-02:

- Terminal War 3 is now closed from the repo-wide rerank
- renderer / scene / publication convergence is again the default next
  architecture battlefield
- the next move here should come from the generic scene/publication contract,
  not from more local renderer field surgery
- the first convergence cut is now landed too:
  retained-target ownership no longer speaks in product-shaped editor/terminal
  surface verbs at the main API boundary
  - `src/ui/renderer/retained_targets_runtime.zig` now exposes one generic
    retained-surface contract
  - editor, terminal, and font-sample callers now use that generic retained
    surface API directly

## Target Read

The renderer center should read as:

- renderer-owned scene/present truth
- GL resource and target lifecycle
- draw/text execution entrypoints
- stable host-facing render contract

It should not read as:

- the owner of all input/runtime state
- the owner of window chrome policy
- the owner of presentation diagnostics/capture policy
- the owner of every font/zoom/UI-scale policy detail

## Remaining Issue Map

### RS-01 Renderer State Bag Is Still Too Broad

Current pressure:

- `src/ui/renderer.zig` still stores GL state, font state, retained targets,
  input state, clipboard state, window chrome state, and present trace/capture
  state in one type.

Primary references:

- `src/ui/renderer.zig:325`
- `src/ui/renderer.zig:471`

Done when:

- the renderer struct reads like one owned rendering center instead of a grab
  bag of unrelated runtime domains.

Progress note, 2026-04-02:

- clipboard buffering state now lives with
  `src/ui/renderer/clipboard.zig` instead of being declared ad hoc on the
  renderer root
- clipboard text copy now routes through that owner state instead of exposing
  one more loose root field
- terminal batch vertices/draw lists now live as one grouped state slab under
  `src/ui/renderer/draw_ops.zig` instead of two loose renderer-root fields
- terminal glyph-cache and shaping scratch state now live with
  `src/ui/renderer/text_runtime.zig` instead of staying as ad hoc renderer-root
  fields
- editor and terminal selection-overlay policy now live as one grouped state
  slab instead of two loose renderer-root fields
- terminal recent-input full-publication policy now lives as one grouped state
  slab instead of two loose renderer-root fields
- retained terminal/editor target state now lives as one grouped state slab
  under `src/ui/renderer/retained_targets_runtime.zig` instead of four loose
  renderer-root fields
- the forwarding shell `src/ui/renderer/retained_surface_api.zig` is gone; the
  retained-target owner now speaks the retained-surface vocabulary directly
- renderer full-pane-clear detection for editor retained surfaces now routes
  through `src/ui/renderer/scene_frame_runtime.zig` instead of peeking into
  retained-target state directly
- editor-surface trace state now lives with `PresentState` in
  `src/ui/renderer/scene_frame_runtime.zig` instead of inflating retained-target
  storage
- terminal retained-surface end now routes straight to
  `src/ui/renderer/scene_frame_runtime.zig` instead of through a duplicate
  one-hop bounce
- mouse scale state now lives with `InputRuntimeState` instead of as a loose
  renderer-root field
- terminal texture-shift and recent-input publication behavior now live as one
  grouped terminal render policy slab instead of split renderer-root policy
  fields
- close-request state now lives with `InputRuntimeState` instead of as a loose
  renderer-root flag
- text gamma/contrast, linear-correction, destination-linear state, and text
  background color now live as one grouped text render slab instead of loose
  renderer-root render-pass fields

### RS-02 Init/Deinit Still Mix Too Many Responsibilities

Current pressure:

- constructor/destructor still assemble and tear down:
  - SDL window/context
  - font path resolution and font state
  - scale/zoom defaults
  - window chrome owners
  - text input setup
  - render resources

Primary references:

- `src/ui/renderer.zig:528`
- `src/ui/renderer.zig:819`

Done when:

- setup/teardown read as renderer assembly over narrower sub-owners instead of
  one giant lifecycle slab.

Progress note, 2026-04-02:

- renderer init now assembles grouped scale state through
  `initScaleState(...)` instead of open-coding zoom/UI-scale setup inline
- renderer init now assembles grouped font/config state through
  `initFontConfigState(...)` instead of open-coding font-path/config setup
- renderer deinit now tears that grouped font/config state down through
  `deinitFontConfigState(...)` instead of open-coding the same cleanup slab
- text-input start/stop and input queue/composition teardown now run through
  `src/ui/renderer/input_state.zig` instead of living as raw lifecycle verbs
  in `renderer.zig`
- window-chrome teardown now runs through
  `src/ui/renderer/window_chrome_runtime.zig` instead of living as raw cleanup
  verbs in `renderer.zig`
- grouped scale-state initialization now lives with
  `src/ui/renderer/font_runtime.zig` instead of staying as a renderer-local
  lifecycle helper
- grouped font-config initialization and teardown now live with
  `src/ui/renderer/font_manager.zig` instead of staying as renderer-local
  lifecycle helpers
- the remaining work in this item is broader lifecycle shrink, not raw grouped
  state setup/teardown duplication

### RS-03 Input State Still Lives In Renderer

Current pressure:

- key/mouse queues, composition state, focus queue, resize flag, and wait-event
  staging still live directly on `Renderer`.

Primary references:

- `src/ui/renderer.zig:422`
- `src/ui/renderer.zig:456`
- `src/ui/renderer.zig:1257`
- `src/ui/renderer.zig:1731`

Done when:

- renderer input state has a narrower owner or a clearly justified renderer
  boundary.

Progress note, 2026-04-02:

- event polling now operates on `src/ui/renderer/input_state.zig:InputDomain`
- the live input path no longer reaches directly across `Renderer` just to
  feed SDL events into queue/composition state
- input query/pop helpers now ride the same domain instead of reading renderer
  queue/button/key state directly
- the main input consumer now talks through `Shell` instead of treating the
  renderer as direct input authority
- renderer input state is now grouped as one explicit slab instead of loose
  key/mouse/queue/composition/wake-event fields
- focus/resize/wake-event semantics now route through
  `src/ui/renderer/input_state.zig` instead of exposing raw grouped input
  storage shape
- `InputRuntimeState` now lives with `src/ui/renderer/input_state.zig`
  instead of being declared in the renderer root
- the remaining work in this item is ownership shrink, not event-loop plumbing

### RS-04 Window Chrome Still Lives In Renderer

Current pressure:

- Windows frame/snap/chrome state and hit-testing still live directly in the
  renderer center.

Primary references:

- `src/ui/renderer.zig:406`
- `src/ui/renderer.zig:410`
- `src/ui/renderer.zig:1347`
- `src/ui/renderer.zig:1453`

Done when:

- host window-chrome ownership is narrower and no longer inflates the renderer
  core.

Progress note, 2026-04-02:

- window-chrome application now runs through
  `src/ui/renderer/window_chrome_runtime.zig:WindowChromeDomain`
- frame-material policy, integrated-frame sync, snap-sink sync, and sink query
  helpers no longer live as direct renderer-local choreography
- renderer window chrome state is now grouped as one explicit state slab
  instead of five unrelated top-level fields
- `WindowChromeState` now lives with
  `src/ui/renderer/window_chrome_runtime.zig` instead of being declared in the
  renderer root
- the remaining work in this item is state-center shrink, not chrome policy
  plumbing

### RS-05 Present Capture And Trace Still Live In Renderer

Current pressure:

- present trace bookkeeping and screenshot capture arming still live directly
  on `Renderer`.

Primary references:

- `src/ui/renderer.zig:458`
- `src/ui/renderer.zig:470`
- `src/ui/renderer.zig:1007`
- `src/ui/renderer.zig:1176`

Done when:

- present diagnostics/capture either have a narrower owner or clearly justify
  their place in the renderer center.

Progress note, 2026-04-02:

- present sequencing/trace/capture is now grouped as one explicit renderer
  state slab instead of loose top-level fields
- live scene-frame and retained-target paths now read through that grouped
  state
- app-driven capture/trace control now routes through
  `src/ui/renderer/scene_frame_runtime.zig` plus `Shell` instead of through
  renderer-level convenience methods
- composition clip/full-pane-clear and editor surface trace bookkeeping now
  route through `src/ui/renderer/scene_frame_runtime.zig` too
- `PresentState` / `PresentTrace` / `FrameSubmission` now live with
  `src/ui/renderer/scene_frame_runtime.zig` instead of being declared in the
  renderer root
- the remaining work in this item is deciding whether the grouped present
  state still belongs in the renderer center or should narrow further

### RS-06 Font/Zoom/UI-Scale Policy Still Inflates Renderer

Current pressure:

- font config, font caches, ligature config, zoom state, and UI-scale policy
  still occupy a major part of the renderer center.

Primary references:

- `src/ui/renderer.zig:364`
- `src/ui/renderer.zig:400`
- `src/ui/renderer.zig:550`
- `src/ui/renderer.zig:663`
- `src/ui/renderer.zig:838`
- `src/ui/renderer.zig:980`

Done when:

- renderer-facing font/runtime surface is smaller and the remaining font/zoom
  ownership is deliberate instead of inherited.

Progress note, 2026-04-02:

- zoom/UI-scale runtime state is now grouped as one explicit renderer slab
  instead of loose top-level fields
- live renderer accessors, font runtime, font manager, and the main
  render-scale consumers now read through that grouped scale state
- broader font/config policy state is now grouped as one explicit slab and the
  live font/runtime consumers read through it
- `ScaleState` now lives with `src/ui/renderer/font_runtime.zig` and
  `FontConfigState` now lives with `src/ui/renderer/font_manager.zig` instead
  of being declared in the renderer root
- the remaining work in this item is broader font/config ownership, not raw
  scale-field sprawl

## Recommended Order

1. `RS-03` Input state
2. `RS-04` Window chrome
3. `RS-05` Present capture/trace
4. `RS-06` Font/zoom/UI-scale policy
5. `RS-02` Constructor/destructor simplification after the above owners shrink
6. `RS-01` Final renderer-center reassessment

## Rules For This Lane

- No extraction theater.
- No new fake helper files.
- No behavior changes unless explicitly re-scoped.
- Each cut should remove a real ownership lie through the full affected
  surface.
- Keep validating with `zig build test` and `zig build`.

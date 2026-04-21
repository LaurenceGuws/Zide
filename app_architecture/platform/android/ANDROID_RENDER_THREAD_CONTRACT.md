# Android Render-Thread Contract

Purpose: define what work is allowed to live on the Android shared-renderer
execution path, what is forbidden there, and which current code paths are the
first offenders.

This is architecture authority for Android render-thread discipline.

## Standard

Treat the Android render path like an OS-critical UI surface, not like a
general application worker.

Anything that executes in response to:

- `surfaceChanged`
- `surfaceRedrawNeeded`
- visible viewport updates that immediately trigger native redraw
- gesture-driven redraw / zoom
- direct native frame submission

must be able to defend its existence there.

If the same work can be staged earlier, deferred later, coalesced, cached, or
owned by a non-render thread, it does not belong on the render path.

## Allowed Work

Allowed categories:

- frame-state sync strictly required for the current draw
- GPU submission mechanics
- render-surface lifecycle mechanics
- draw planning and submission strictly required for the current frame
- cheap, bounded state changes already proven safe for per-frame use

The burden of proof is on the caller, not on reviewers.

## Forbidden Work

Forbidden categories on the render path:

- file IO
- product-path string rebuilding that is not required for the current frame
- debug/status formatting
- log-heavy observability work
- broad cache destruction and full reinitialization
- repeated expensive layout/reflow work when a staged commit model would do
- work whose only purpose is future convenience or compatibility

If a code path mixes one required render operation with one forbidden category,
the whole path is wrong until split.

## Android Ownership Rule

Android UI thread and Android render path are separate concerns, but both are
performance-critical. The Android product host must be thin enough that UI
thread cost does not contaminate render-thread diagnosis.

So:

- Android UI thread should only feed the renderer the minimum required state
- the renderer should not ask the UI thread to carry debug/product-irrelevant
  work
- render-thread cleanup is not optional just because some earlier overhead
  lived on the UI thread too
- gesture policy belongs in the Android host seam:
  - raw `ScaleGestureDetector` deltas are host noise, not renderer authority
  - the Android host should normalize gesture input into coarse product actions
    before handing work to native code
  - if pinch floods the renderer with tiny multiplicative updates, that is an
    Android host contract bug first, not a justification for render-thread
    churn

## Current Offenders

These are the first explicit offenders from current code truth.

## War Scope Map

This war is not "Android special-case cleanup." Android is the pressure source.
If the offending cost exists in shared renderer code or across supported
backends, it is in scope.

Current subcategories:

1. Android host/UI-thread contamination
2. Render-entry submission path
3. Live font/scale/atlas path
4. Terminal widget presentation invalidation path
5. Resize/grid-fit work in live draw paths
6. Backend frame begin/submit mechanics
7. Debug/observability contamination of product execution

Subcategory ownership rule:

- Android-only categories stay local only when the cost is truly host-owned
- shared renderer/backend categories are renderer-contract work even if Android
  surfaced them first

## Audit Order

Use this order unless stronger code truth reorders it:

1. live font/scale/atlas path
2. render-entry submission path
3. resize/grid-fit in draw flow
4. terminal widget presentation invalidation path
5. backend frame begin/submit mechanics
6. remaining Android host/UI-thread contamination
7. debug/observability contamination still touching product execution

Each subcategory must be fully audited and recorded before code cuts begin for
that subcategory.

### 1. Live font-scale rebuild path

`src/ui/renderer/font_manager.zig`

`applyFontScale(...)` currently:

- clears the dynamic font cache
- deinitializes app/editor/terminal/icon fonts
- reinitializes fonts from scratch

That is not a defensible live render-path cost for zoom or other interactive
scale changes.

Status:

- accepted temporarily for Android readiness baseline
- not acceptable as a product render-thread design

Required direction:

- separate cheap live scale response from expensive font/cache rebuild
- stage or amortize expensive rebuild work
- do not let every interactive zoom step destroy renderer font state

### Subcategory audit: live font/scale/atlas path

Scope:

- `src/ui/renderer/font_runtime.zig`
- `src/ui/renderer/font_manager.zig`
- renderer paths that trigger `applyFontScale(...)`

Findings:

- `applyPinchZoomScale(...)` in `font_runtime.zig` immediately calls
  `applyFontScale(...)`
- `applyPendingZoom(...)` also immediately calls `applyFontScale(...)`
- `refreshUiScaleFromDisplayMetrics(...)` immediately calls
  `applyFontScale(...)`
- `font_manager.applyFontScale(...)` destroys cached dynamic fonts, deinitializes
  app/editor/terminal/icon fonts, then reinitializes fonts from scratch

That means the current renderer treats a live scale change as a full font-stack
rebuild operation.

Why this is in war scope:

- it is shared renderer code
- it is on the hot interaction/render path
- Android exposed it first, but the design defect is not Android-local

What is allowed here:

- cheap scale state mutation
- bounded cache lookups
- staged requests for later rebuild work if the rebuild cannot be avoided

What is forbidden here:

- destroying the full font cache on every interactive zoom step
- deinitializing and rebuilding active font state in the live gesture path
- hiding rebuild cost behind "it only happens on pinch" reasoning

Current stop marker for this subcategory:

- one live scale step must no longer require full active-font teardown and
  cache reset by default

Initial fix queue:

1. split "live scale target changed" from "font assets fully rebuilt"
2. define which font data can be reused across nearby scale steps
3. stage expensive rebuild/atlas work behind a controlled commit point instead
   of the live interaction step
4. document whether Android pinch, generic user zoom, and display-metric scale
   refresh should share one rebuild policy or separate ones

Do not do:

- do not micro-tune thresholds while the full rebuild model remains
- do not treat Android pinch specially if the real defect is shared font-scale
  ownership
- do not add more debug timing noise on this path before the ownership split is
  clear

Current progress:

- first cut landed:
  - active Android pinch now applies a cheap live user-zoom scale update through
    shared renderer font state
  - that path updates logical font sizes and derived metrics without clearing
    the dynamic font cache or deinitializing active app/editor/terminal/icon
    fonts
  - existing glyph atlas output now carries a temporary live visual scale, so
    glyph size tracks cell size during the interaction instead of waiting for
    pinch end
  - Android product-fit grid resize now remains live during pinch, so terminal
    cell backgrounds continue fitting the Java-owned surface instead of
    shrinking inside a larger parent until gesture end
  - pinch end is no longer the only credible recovery path; prepared target
    promotion can now recover in the interaction path too
  - queued user zoom now uses the same cheap live scale path and commits the
    expensive font rebuild only after the zoom target settles
- remaining work:
  - display-metric and config font changes intentionally still use the full
    rebuild path until their ownership is audited separately
  - font-cache reuse across committed scale targets is still unresolved

Reference-backed finding, 2026-04-12:

- the remaining "text thickness snaps when pinch ends" behavior is not fixed by
  warming common glyphs
- FreeType hinting/grid-fitting is final-pixel-size dependent: glyph width,
  height, bearings, advances, and stem placement can change when the face is
  rasterized at a new pixel size
- our current live path scales an already rasterized atlas during the gesture,
  then swaps to a newly hinted/rasterized atlas at the settled size
- that means the preview glyphs and committed glyphs are not the same visual
  object; a weight/thickness change at commit is expected under hinted bitmap
  rendering
- HarfBuzz also treats the FreeType face size/load flags as part of the font
  contract, so shaping/rasterization must stay aligned per committed size

Reference direction:

- follow terminal references by treating font/cell metrics as pixel-rounded
  committed states, not continuously mutable hinted bitmap state
- keep live pinch cheap, but make committed font assets size-keyed and reusable
  instead of destroying/recreating active font state each time
- model the next cut as a shared renderer font-size/atlas lifecycle problem:
  cache prepared `TerminalFont` instances by domain, font identity, rendering
  options, render scale, and rounded raster pixel size; swap to a prepared
  committed size atomically
- if product ever requires perfectly continuous stroke weight during pinch, that
  is a different renderer design such as SDF/vector text preview, not a small
  FreeType atlas warmup

Current progress:

- first committed-size lifecycle cut landed:
  - `TerminalFont` now records the committed raster pixel size that produced
    its atlas
  - renderer font config now owns a committed terminal-font cache keyed by
    render scale plus committed raster pixel size
  - `applyFontScale(...)` no longer blindly destroys the old active terminal
    font on every committed zoom; it parks the committed atlas for reuse
  - terminal font rendering-option/path changes clear that committed cache
  - the cache now prepares a bounded neighbor set around the committed terminal
    raster size: twelve raster-pixel intervals smaller and twelve larger
  - terminal live glyph visual scale remains continuous, so live glyph
    geometry still tracks live cell geometry during pinch
  - active Android pinch can now swap the terminal font to a prepared committed
    raster-size neighbor during the gesture, so glyph thickness is no longer
    intentionally held until gesture release
  - the live swap is terminal-only; full app/editor/icon font rebuild remains
    owned by the settled `applyFontScale(...)` path
- accepted Android boundary, 2026-04-12:
  - host gesture cleanup plus renderer-core prep/adoption work now puts the
    release-build Android terminal pinch path in the accepted range for the
    current product target
  - do not keep Android pinch open as the active render-thread war front
  - any future extreme-burst refinement should reopen only on concrete product
    need
  - the useful enduring result is the shared ownership cleanup below, not more
    host-threshold tuning
  - the async terminal glyph-preparation lane with a strict CPU-prep vs
    GPU-upload ownership split is now part of the renderer baseline
  - kitty reference backs the ownership direction here:
    cache-key identity and readiness must be separate concepts, and GPU upload
    must remain distinct from CPU-side glyph-instance preparation
  - first shared seam now exists in code:
    terminal glyph raster preparation is separate from atlas upload/adoption,
    so the next async cut can move CPU prep off the render path without moving
    renderer-owned GPU mutation with it
  - renderer state now also owns a dedicated terminal glyph-prep
    request/result runtime with generation tracking, so async preparation can
    publish into renderer-owned state instead of inventing a side channel
  - queue/publish/take helpers now exist on the renderer side too, so the next
    worker cut can use one explicit ownership surface instead of mutating raw
    runtime fields ad hoc
  - the terminal widget draw authority can now collect a deduped visible
    glyph-set plan from the actual direct/shaped row-span decisions used for
    product rendering
  - that same draw authority now stages renderer-owned prep requests keyed by
    committed raster size, render scale, and visible glyph demand
  - renderer now also owns a dedicated worker that consumes those requests and
    prepares CPU-only glyph rasters against a temporary committed-size font
    instance; live atlas mutation still has not moved off the render thread
  - live atlas mutation now stays where it belongs:
    published worker rasters are adopted on the render thread into the live
    committed terminal atlas before draw lookup falls back to inline glyph
    realization
  - this is a lifecycle foundation, not a claim that first-time target sizes
    can avoid hinted-stem differences or that preparation has moved off-thread
    yet
  - deeper blocker now proved by device testing:
    async glyph rasters alone are not enough to make burst-pinch recovery
    scene-ready because the renderer still lacks a worker-safe committed
    terminal-font target state
  - `TerminalFont` creation is still coupled to GPU atlas allocation unless a
    backend hook replaces it; on Android/GLES the fallback still creates GL
    textures, so this is shared renderer/font immaturity, not an Android-only
    edge case

References:

- FreeType glyph conventions: grid-fitting modifies glyph metrics and advances
  at small pixel sizes.
- HarfBuzz `hb-ft` integration: FreeType face size and load flags are part of
  the HarfBuzz font contract.
- Local terminal references: kitty/wezterm notes prefer integer pixel metrics
  for cell/font rendering stability.

### 2. Direct interaction-to-frame submission path

`src/platform/android_runtime_bridge.zig`

`applyPinchZoom(...)` and related Android interaction paths currently
lead directly into:

- renderer mutation
- presentation invalidation
- `drawSharedRendererSurfaceFrame()`

That keeps interaction latency coupled to full native frame work.

Required direction:

- coalesce input to frame cadence
- keep direct interaction handlers thin
- avoid synchronous “gesture callback -> full renderer work -> submit” chains

### Subcategory audit: render-entry submission path

Scope:

- Android interaction/lifecycle entry points that call
  `drawSharedRendererSurfaceFrame()`
- render-entry state sync before `beginFrame()` / `submitFrame()`

Caller classification:

- lifecycle-critical direct submit:
  - `noteSurfaceAvailableFromJava(...)`
  - `noteSurfaceRedrawNeeded(...)`
- product-critical direct submit retained for latency until a better native
  pacing contract exists:
  - `tickProductShellFrame(...)`
- stageable through redraw intent/product frame loop:
  - `noteVisibleViewport(...)`
  - `applyPinchZoom(...)`
  - `setPinchActive(false)`
  - `refreshShellSurfaceAfterInput(...)`

Findings:

- first stageable cut landed:
  - viewport changes now mark redraw intent instead of synchronously drawing
  - active pinch changes now mutate scale/presentation state and mark redraw
    intent instead of synchronously drawing
  - pinch-end font rebuild now marks redraw intent instead of drawing inline
- second stageable cut landed:
  - successful shell input now polls terminal state immediately but only marks
    redraw intent; it no longer submits a frame inline on the direct input path
  - the paced product frame loop remains the one owner of ordinary product draw
    submission on Android
- direct-submit ownership cut landed:
  - the remaining lifecycle-critical direct-submit path now routes through one
    explicit Android bridge seam instead of hand-rolling the same
    flush-and-submit sequence at both surface-available and redraw-needed
    call sites
  - behavior is unchanged; this names the surviving direct-submit authority
    more honestly before any deeper pacing change
- redraw-needed callback contract tightened:
  - the Android surface-redraw callback must not re-enter itself through
    native draw submission or callback fan-out
  - the host/controller layer now guards that callback path so a single
    lifecycle-critical redraw pass can complete without recursive surface
    redraw reentry
- surface lifecycle/redraw-needed paths still submit immediately because they
  are the current acquisition/readiness authority
- direct input no longer owns a separate immediate-submit exception here; the
  remaining direct-submit authority is lifecycle/surface critical
- the render-entry seam is still responsible for too much policy, not just
  frame-critical submission

Initial fix queue:

1. list every current caller of `drawSharedRendererSurfaceFrame()` — done
2. classify each caller as lifecycle-critical, product-critical, or stageable
   — done
3. remove stageable callers from the direct submission path before deeper
   backend tuning

Do not do:

- do not debate frame pacing in the abstract before the caller list is closed

### 3. Grid resize in draw flow

`src/platform/android_runtime_bridge.zig`

`drawLiveTerminalWidgetFrame(...)` currently performs terminal-grid fit checks
and may trigger resize before draw.

That means layout/product-fit work is still coupled to live frame submission.

Required direction:

- prove which resize decisions are truly frame-critical
- move non-critical resize work out of the hot draw path
- make deferred/staged grid commit explicit where needed

### Subcategory audit: resize/grid-fit work in draw flow

Scope:

- `drawLiveTerminalWidgetFrame(...)`
- `ensureProductFitTerminalGrid(...)`
- any render-path terminal-grid recompute/resize calls

Findings:

- live draw still owns product-fit terminal-grid checks
- the draw path may still trigger terminal resize and presentation invalidation
- the current Android product-fit call computes:
  - rows/cols from visible viewport and renderer cell geometry
  - cell width/height in device pixels
- `android_shell_session.resizeToGrid(...)` treats any difference in
  rows/cols/cell width/cell height as the same resize event
- that crosses:
  - Android shell-session bookkeeping
  - terminal FFI `zide_terminal_resize(...)`
  - `host_api.resize(...)`
  - `session_runtime.resizeWithCellSize(...)`
  - `resize_reflow.resizeWithCellSize(...)`
  - `core.setCellMetrics(...)`
  - `core.resizeLocked(...)`
  - PTY `TIOCSWINSZ`
  - in-band resize report
  - publication/event sync
- row/column changes are real terminal resize events and may legitimately
  require reflow, grid allocation, PTY notification, and publication refresh
- cell-pixel changes are not the same thing:
  - they affect renderer geometry and PTY pixel-size metadata
  - they should not force terminal grid reflow when rows/cols are unchanged
- Android pinch exposed this because live font scale changes produce frequent
  cell-pixel changes before the viewport rows/cols meaningfully change

What this means:

- the lower path currently lacks a cell-metric-only resize contract
- rendering, PTY metadata, terminal model reflow, and publication invalidation
  are coupled too tightly
- the fix belongs in the shared terminal/runtime boundary, not in Java gesture
  throttling

Initial fix queue:

1. prove which grid-fit decisions are truly required before draw
2. split terminal resize into:
   - grid resize: rows/cols changed, may reflow and notify PTY
   - cell-metric update: rows/cols unchanged, update metrics and PTY pixel size
     without grid reflow
3. stage non-critical grid commits outside the hottest render path

Current progress:

- first shared resize split landed:
  - `updateCellSizeOnly(...)` now exists under terminal runtime/FFI
  - Android product-fit uses full resize only when rows or cols change
  - stable-grid cell width/height changes update terminal cell metrics and PTY
    pixel-size metadata without calling `core.resizeLocked(...)`
  - regression coverage proves stable rows/cols are preserved while in-band
    resize reporting reflects the new pixel dimensions
- second ownership cut landed:
  - product-fit grid sizing is now dirty-driven in the Android bridge instead
    of recomputing on every draw
  - visible viewport changes, live zoom changes, settled zoom changes, surface
    acquisition, and shell restarts mark product-fit dirty explicitly
  - the paced product frame loop now owns the normal product-fit grid commit
    path
- third ownership cut landed:
  - direct surface-available/redraw-needed callbacks now flush dirty product-fit
    grid state before frame submission
  - the first-frame path creates the renderer before flushing dirty grid-fit
    state
  - `drawLiveTerminalWidgetFrame(...)` no longer performs resize/layout
    fallback work
- fourth ownership cut landed:
  - Android bridge now names the pre-draw seam as “flush dirty product-fit
    grid before frame” instead of a vague prepare helper
  - surface-available, redraw-needed, and paced product frames all now read as
    the same ownership rule at the call site
- fifth ownership cut landed:
  - pre-draw product-fit flush no longer hides renderer/widget readiness and
    grid commit inside one helper blob
  - Android bridge now separates “commit inputs are ready” from “commit dirty
    product-fit grid state,” keeping the pre-draw seam closer to explicit
    frame-readiness plus one bounded grid commit
- font/atlas follow-up:
  - ASCII glyph warmup was rejected after device testing and reference audit:
    the visible defect is the hinted-raster-size swap, not lazy glyph
    population

Do not do:

- do not keep layout policy inside draw just because it is convenient for the
  current Android bridge
- do not hide this behind Android-only gesture preview if the shared terminal
  resize boundary is the real defect
- do not add glyph warmup as a substitute for a real size-keyed atlas/font
  lifecycle

### 4. Terminal widget presentation invalidation path

`src/ui/widgets/terminal_widget_presentation_runtime.zig`

The terminal widget currently rebuilds broad presentation policy inside the
live execution path because invalidation ownership is too coarse.

Required direction:

- preserve invalidation cause explicitly instead of collapsing all causes into
  one broad ready/not-ready state
- keep live presentation execution focused on bounded present/update work
- move non-execution policy reconstruction out of the hottest path where
  possible

### Subcategory audit: terminal widget presentation invalidation path

Scope:

- `src/ui/widgets/terminal_widget.zig`
- `src/ui/widgets/terminal_widget_surface_state.zig`
- `src/ui/widgets/terminal_widget_presentation_cache_state.zig`
- `src/ui/widgets/terminal_widget_presentation_runtime.zig`
- all current callers of `invalidatePresentationCache()`

Findings:

- `invalidatePresentationCache()` is currently a single-bit reset:
  `terminal_presentable_pipeline_ready = false`
- Android bridge paths already call that broad invalidation directly:
  - `applyPinchZoom(...)`
  - `ensureProductFitTerminalGrid(...)` after resize
- app/runtime paths also call it directly:
  - `post_preinput_hooks_runtime.zig`
  - `terminal_tab_navigation_runtime.zig`
- `buildTerminalPresentPlan(...)` mixes several different causes into one live
  present/reuse decision:
  - generation delta
  - clear-generation delta
  - cell metric delta
  - render-scale delta
  - cursor delta
  - hover/composition overlay delta
  - blink-driven partial invalidation
  - viewport shift state
- `runPresentation(...)` and its helpers currently perform all of these in one
  hot execution seam:
  - backdrop draw
  - reuse-vs-refresh-vs-direct execution choice
  - partial/full update planning
  - state advancement via `notePresentationUpdated(...)`
  - unavailable-surface logging
- `tryFastPresentExisting(...)` still advances the same broad presentation
  state after reuse, so cache-state ownership and present-intent ownership are
  not yet separated cleanly

What this means:

- presentation invalidation is currently too coarse as an ownership seam
- overlay-only changes, scale/metric changes, generation changes, and
  presentable availability all collapse into one state bucket
- the renderer must recompute policy in the live present path because invalid
  state does not preserve enough cause/ownership detail upstream

Why this is in war scope:

- this state machine lives in shared terminal widget/renderer code
- Android exposed the cost through pinch and live product interaction, but the
  coupling is not Android-specific
- any backend that uses the same widget presentation runtime inherits the same
  invalidation model

What is allowed here:

- cheap state comparison required to decide whether an already-built
  presentable can be reused
- precise invalidation markers that preserve cause without forcing a broad
  reset
- bounded state advancement after a successful update/present step

What is forbidden here:

- using one `terminal_presentable_pipeline_ready` bit as the only cache/invalidation
  authority for unrelated presentation causes
- mixing overlay invalidation, geometry invalidation, availability invalidation,
  and execution selection in one live path because upstream state is too weak
- logging and policy reconstruction in the same seam that is supposed to only
  decide and execute presentation work

Current stop marker for this subcategory:

- presentation invalidation must preserve enough cause/ownership detail that
  the live present path is not forced to rebuild broad reuse/update policy from
  scratch on every interaction-driven frame

Initial fix queue:

1. classify invalidation causes into explicit families:
   geometry, content generation, overlay/cursor, and target availability
2. replace the current broad ready-bit reset with cause-aware invalidation
   state
3. separate state invalidated from execution path selection for the current
   frame
4. move non-execution concerns such as unavailable-surface logging out of the
   hot present decision path where possible
5. document which callers are allowed to request which invalidation family

Current progress:

- first cause-aware invalidation cut landed:
  - shared terminal widget presentation state now records explicit invalidation
    families instead of relying only on one broad
    `terminal_presentable_pipeline_ready = false` reset
  - current explicit families are:
    geometry, content, overlay, and target availability
  - Android zoom/grid-fit callers now request geometry invalidation explicitly
  - tab navigation / close-active callers now request content invalidation
    explicitly
  - present-plan construction now reads explicit invalidation flags in addition
    to the existing generation/metric/cursor deltas
- second cause-aware invalidation cut landed:
  - backend target availability now has its own tracked state
  - target-unavailable invalidation no longer discards cached presentation
    content
  - geometry/content/overlay invalidation still marks the cached presentation
    stale
  - tests lock the distinction so target loss does not masquerade as content
    or geometry invalidation
- this is not the full invalidation redesign yet:
  - execution policy and cache-state advancement still share one runtime seam
  - but the state now preserves enough caller intent that the next cut can
    tighten reuse/update ownership without another blind broad reset
- first execution-seam cut landed:
  - terminal presentation execution update planning now happens once in
    `runPresentation(...)` instead of being rebuilt independently inside both
    direct-present and presentable-refresh execution hooks
  - behavior is unchanged; the cut narrows execution hooks toward consuming
    policy instead of recomputing it
- second execution-seam cut landed:
  - refresh-path outcome classification now routes through one explicit helper
    instead of recomputing cache-advance, target-availability, and followup
    policy inline at the refresh execution site
  - behavior is unchanged; this starts separating "what happened" from
    "what cache-state/followup policy should advance"
- third execution-seam cut landed:
  - direct-present outcome classification now routes through one explicit
    helper instead of open-coding result-policy assembly inside the direct
    execution hook
  - behavior is unchanged; both execution paths now classify result policy
    explicitly before the next cache-advancement split
- fourth execution-seam cut landed:
  - terminal present result assembly now routes through explicit helpers
    instead of open-coding result construction separately across reuse,
    refresh, and direct execution paths
  - behavior is unchanged; execution sites now hand off classified policy plus
    timing instead of rebuilding result objects themselves
- fifth execution-seam cut landed:
  - successful presentation paths now advance cached presentation state through
    one explicit helper instead of calling `notePresentationUpdated(...)`
    directly at multiple execution sites
  - behavior is unchanged; this starts separating cache-state advancement from
    the draw/refresh execution bodies themselves
- sixth execution-seam cut landed:
  - fast reuse no longer hard-codes a synthetic `.reused/advanced/available`
    present result beside its own availability/cache path
  - reuse now returns explicit reuse-outcome state and shares the same result
    assembly pattern as refresh/direct execution paths
  - behavior is unchanged; this narrows the remaining mixed ownership around
    execution outcome vs availability/cache policy
- seventh execution-seam cut landed:
  - refresh present-state classification no longer begins viewport clip as a
    hidden side effect
  - clip execution now happens at the refreshed-presentable caller after state
    classification, keeping the state helper declarative

Do not do:

- do not add more one-off `invalidatePresentationCache()` callers while the
  ownership model remains broad
- do not special-case pinch, IME, or Android resize if the same invalidation
  coarseness exists for all renderers
- do not optimize direct/reuse thresholds before invalidation ownership is
  split into explicit causes

### 5. Backend frame begin/submit mechanics

`src/ui/renderer/*_backend.zig`

Backend frame ownership must stay narrow: acquire/bind the current target,
prepare the frame-critical GPU state, and submit/present. Any extra policy or
cross-cutting work in this seam raises the floor cost for every frame.

Required direction:

- keep `beginFrame` and `submitFrame` bounded and backend-mechanical
- push non-frame-critical policy out of backend entry/exit where possible
- make any unavoidable replay/capture work explicit and reviewable

### Subcategory audit: backend frame begin/submit mechanics

Scope:

- `src/ui/renderer/renderer_frame_host.zig`
- `src/ui/renderer/android_gles_backend.zig`
- `src/ui/renderer/gl_backend.zig`
- `src/ui/renderer/metal_backend.zig`
- backend-owned frame replay/capture work reached from `submitFrame()`

Findings:

- `renderer_frame_host.beginFrameHost(...)` is relatively clean:
  per-frame state reset, display metrics sync, clip reset
- Android GLES `beginFrame(...)` still owns more than pure frame begin:
  - surface/context ensure + make-current
  - text render config sync
  - clear/setup
- OpenGL `beginFrame(...)` also owns target policy:
  - scene-target contract refresh
  - possible scene-target preparation/recreation
  - composition-target selection
  - clear/setup
- Metal `beginFrame(...)` similarly combines:
  - backend-context resize
  - frame acquisition/clear
  - composition-target selection
- `submitFrame(...)` is not a narrow "present only" seam on supported backends:
  - Android GLES flushes queued surface draws before swap
  - OpenGL replays recorded surface draws, may blit scene target, and may run
    capture
  - Metal replays recorded surface draws and presentable draws, captures
    terminal snapshot, may run frame readback/capture, then commits
- that means backend submit currently still owns meaningful render/replay
  policy, not just final present mechanics

What this means:

- backend frame seams are still part execution engine, part submission seam
- when performance is poor, backend begin/submit still contains enough work
  that "frame submission cost" is not a clean measurement yet
- Android exposed this pressure, but the structure is shared across supported
  backends

Why this is in war scope:

- these seams are the final mandatory path for every supported renderer
- if too much policy or replay work lives here, every product path inherits the
  cost floor
- this is renderer-contract work, not Android glue cleanup

What is allowed here:

- acquire/bind current backend target
- apply frame-critical clear/setup
- submit/present frame-critical recorded work that cannot be staged elsewhere
- bounded failure handling required to keep renderer state coherent

What is forbidden here:

- treating backend `submitFrame()` as a general execution bucket for unrelated
  replay/capture/policy work without explicit justification
- hiding lazy heavyweight initialization in ordinary steady-state frame begin
  without clearly separating warmup from steady-state cost
- using backend frame seams as the place where ownership ambiguities get
  resolved

Current stop marker for this subcategory:

- steady-state backend `beginFrame()` / `submitFrame()` must read as narrow
  backend mechanics, with replay/capture/policy work either staged elsewhere
  or explicitly justified as unavoidable frame-critical cost

Initial fix queue:

1. separate one-time warmup/init work from steady-state frame begin semantics
2. classify submit-time replay work into:
   unavoidable frame-critical, stageable, and debug/capture-only
3. isolate capture/readback paths so they do not pollute ordinary product
   submission semantics
4. document which backend begin/submit differences are true backend needs vs
   historical accumulation

Do not do:

- do not benchmark "swap cost" or "present cost" as if current submit seams
  were already pure
- do not special-case Android if the same overloaded begin/submit shape exists
  in GL or Metal
- do not move work around blindly; each moved item must justify its new
  ownership boundary

Current progress:

- first backend frame-entry cut landed on Android GLES:
  - `beginFrame(...)` no longer lazily initializes GL resources or fonts
  - Android bridge now calls an explicit preframe
    `prepareFrameResources(...)` seam before normal frame begin
  - steady-state frame entry is narrower and easier to measure honestly
- submit-time ownership classification landed across Android GLES, OpenGL, and
  Metal:
  - frame-critical queued surface replay is now named as replay-before-present
    work, not generic swap/submit mechanics
  - debug capture/readback setup is now named separately from ordinary product
    presentation
  - Metal's ordinary terminal snapshot-cache refresh is named separately from
    debug capture because it is product presentable state for
    `direct_snapshot_cache`, not a diagnostic readback
  - behavior is intentionally unchanged; this cut makes the remaining submit
    work auditable before any movement across backend boundaries
- remaining Android GLES frame-entry pressure is now:
  - surface/context ensure + make-current
  - clear/setup
- remaining backend work for this subcategory should now focus on:
  - whether surface/context acquire can be narrowed further without inventing
    fake EGL state
  - submit-time replay/capture classification across GL / Android GLES / Metal
- first submit-path classification cut landed:
  - OpenGL capture handling now lives behind an explicit helper instead of
    being inline in ordinary `submitFrame(...)`
  - Metal capture/readback completion now lives behind an explicit helper
    instead of dominating the ordinary submit flow
  - this is extraction-only; capture behavior is preserved, but ordinary
    product submission now reads as replay/encode/present first
- second frame-entry cut landed:
  - text-render uniform sync is now dirty-driven by `TextRenderState`
  - Android GLES no longer resends static text-render uniforms on every frame
  - OpenGL config sync uses the same dirty bit so config updates remain explicit
- third frame-entry cut landed:
  - Android GLES window-surface/context acquire now routes through one explicit
    helper shared by preframe warmup and steady-state `beginFrame(...)`
  - steady-state frame entry now reads more honestly as surface/context acquire,
    then clear/setup, instead of duplicating acquire mechanics across seams
- fourth frame-entry cut landed:
  - Android GLES steady-state target setup plus clear now routes through one
    explicit helper instead of remaining inline inside `beginFrame(...)`
  - behavior is unchanged; this keeps frame entry readable as acquire,
    readiness check, setup/clear, then ready
- fifth frame-entry cut landed:
  - Metal steady-state setup after frame acquisition now routes through one
    explicit helper instead of remaining inline inside `beginFrame(...)`
  - behavior is unchanged; Metal frame entry now reads more honestly as
    resize, acquire, setup/clear, then ready
- sixth frame-entry cut landed:
  - OpenGL steady-state bound-target clear/setup now routes through one
    explicit helper instead of remaining inline inside `beginFrame(...)`
  - behavior is unchanged; OpenGL frame entry now reads more honestly as
    target-policy selection, then bound-target clear/setup
- current checkpoint:
  - backend frame begin/submit mechanics are now narrow enough to stop forcing
    symmetry cuts without a new concrete offender
  - reopen this subcategory only if a real product bug or measurement still
    proves begin/submit owns unjustified policy beyond the now-explicit
    frame-entry/replay/capture seams
- second submit-path classification cut landed:
  - Metal ordinary pre-present replay now routes through one explicit helper
    instead of spelling surface replay, snapshot-cache refresh, and presentable
    replay inline inside `submitFrame(...)`
  - behavior is unchanged; this just keeps ordinary submit mechanics readable
    before any deeper replay movement
- third submit-path classification cut landed:
  - OpenGL ordinary pre-present replay/resolve now routes through one explicit
    helper instead of spelling surface replay plus offscreen-scene resolve
    inline inside `submitFrame(...)`
  - debug capture remains separate, so ordinary submit reads as
    replay/resolve/swap first

### 6. Debug/observability contamination of product execution

`src/ui/widgets/terminal_widget_presentation_runtime.zig`

Performance probing is dishonest if the product execution path still updates
debug samples, capture state, and observability policy as part of ordinary
draw/present work.

Required direction:

- keep debug and capture state off the ordinary product hot path unless the
  work is explicitly armed
- let product execution remain measurable without turning off half the app
- make observability costs opt-in and explicit

### Subcategory audit: debug/observability contamination of product execution

Scope:

- terminal presentation/debug capture paths
- present trace / capture state touched every frame
- logging that still executes in ordinary product render paths

Findings:

- terminal presentation runtime still updates debug capture state during
  ordinary product execution:
  - `notePresentSample(...)`
  - `last_terminal_presentation`
  - `last_metal_terminal_fallback`
  - `last_text_paint`
- `runPresentation(...)` / `directPresent(...)` / partial update paths all
  still write debug samples as part of normal flow
- `logUnavailable(...)` still lives directly in the present path
- backend submit paths still carry capture state and capture handling:
  - `capture_armed`
  - `capture_path`
  - readback / screenshot paths in GL and Metal
- `present_trace_runtime` still advances frame trace counters every frame by
  design; that may be acceptable, but it is still part of the measured hot path

What this means:

- even with debug UI mostly removed from Android product mode, shared renderer
  execution still performs some observability work by default
- performance measurements are cleaner than before, but not yet clean enough to
  treat the current path as product-only execution

Why this is in war scope:

- this contamination lives in shared widget/backend code
- Android only exposed it because we are using Android as the first strict
  product pressure lane

What is allowed here:

- minimal always-on frame counters that are already proven cheap and required
  for renderer correctness or operator-critical telemetry
- explicitly armed capture/readback paths
- failure logging on genuinely exceptional paths

What is forbidden here:

- unconditional debug sample updates in ordinary product rendering
- mixing product execution and optional observability because it is convenient
- treating capture/readback plumbing as harmless just because it is usually
  inactive

Current stop marker for this subcategory:

- ordinary product render/present must not update debug capture structures or
  run optional observability work unless that instrumentation is explicitly
  armed

Initial fix queue:

1. separate always-on correctness telemetry from optional debug capture state
2. gate debug sample writes behind explicit instrumentation state
3. isolate capture/readback plumbing so product submission reads as product
   submission first
4. review `present_trace_runtime` and decide which counters are correctness
   authority vs optional observability

Do not do:

- do not disable all telemetry blindly; some of it may still be real renderer
  correctness state
- do not keep debug writes in product flow just because they helped early validation
- do not claim backend/frame timings are pure until this contamination is
  narrowed

Current progress:

- first debug-sample ownership cut landed:
  - `DebugCaptureState` now has an explicit `samples_enabled` gate
  - terminal presentation/cursor-overlay/text-paint/Metal fallback diagnostic
    sample sinks are null in ordinary product rendering
  - product frames still draw and submit normally, but they no longer refresh
    those debug capture structs by default
  - future debug capture must explicitly arm sample collection instead of
    relying on stale always-on product-path writes
- present-trace ownership cut landed:
  - `FrameFamilySummary` remains always-on correctness state because terminal
    publication retirement depends on submitted/presented generation truth
  - optional `PresentTrace` counters now advance only when `renderer.present`
    logging is enabled through normal logging config
  - frame submission logging now returns before reading trace state when the
    `renderer.present` tag is disabled
  - this keeps correctness feedback hot, but moves observability behind config
    instead of treating it as product execution
- correctness naming cut landed:
  - frame-family/submission/execution state moved to
    `present_feedback_state.zig`
  - backend submit return types now name the correctness feedback module, not
    the trace module
  - `present_trace_runtime.zig` now carries optional trace counters/helpers
    plus the aggregate `PresentState`; correctness types are no longer defined
    there
- correctness update host cut landed:
  - frame-family and terminal-presentation updates now route through
    `present_feedback_host.zig`
  - `present_trace_runtime.zig` no longer owns the correctness mutation; it
    only mirrors optional counters when trace logging is enabled
  - call sites that retire/present terminal/editor/chrome/sample families now
    name feedback ownership rather than trace ownership
- stale trace artifact removed:
  - `editor_surface_solid_family` and its set/clear helpers had no active
    consumer
  - the hook is deleted instead of being gated because it was investigation
    residue, not operator telemetry or correctness state
- font-prep operator telemetry gated:
  - `renderer.font` glyph-prep/adopt logs are now guarded before formatting
  - disabled telemetry no longer formats large hot-path messages just for
    `logf(...)` to drop them later
- zoom-path operator telemetry gated:
  - pinch/UI-scale zoom logs now check tag enablement before formatting
  - disabled zoom diagnostics no longer add formatting work to gesture pressure
- terminal input/hover operator telemetry gated:
  - key-path and hover info logs now check tag enablement before formatting
  - disabled input diagnostics no longer add string-formatting work to ordinary
    product input frames
- remaining renderer-font info telemetry gated:
  - font init metrics and glyph-prep worker lifecycle logs now check tag
    enablement before formatting
  - exceptional warning logs remain available on failure paths
- logger boundary hardened:
  - `Logger.logf(...)` now returns before formatting when no sink can emit the
    requested tag/level
  - future disabled telemetry cannot silently reintroduce formatting cost just
    by calling `logf(...)`
- capture ownership naming cut landed:
  - present-capture arm/path/frame state now lives in an explicit capture state
    object instead of being flat fields beside correctness/trace state
  - shared GL and Metal capture helpers now name that ownership directly
- capture ownership host cut landed:
  - arm/reset/captured-path mutation now routes through
    `present_capture_host.zig`
  - shared renderer/backend call sites no longer reach into capture fields
    directly just to mutate capture ownership state

### 7. Remaining Android host/UI-thread contamination

`android/terminal-host/app/src/main/java/uk/laurencegouws/terminal/`

Android is only the pressure source, but the host still has to meet a strict
contract: feed the renderer the minimum required state and keep product input
and surface ownership thin and predictable.

Required direction:

- keep the main thread thin, boring, and deterministic
- keep product state sync separate from debug/operator state
- avoid UI-thread work that reconstructs product state every refresh tick

### Subcategory audit: remaining Android host/UI-thread contamination

Scope:

- `ZideActivity.java`
- `ShellSessionController.java`
- `ShellInputView.java`
- Java-side gesture, lifecycle, status, and product-state upkeep flows on the
  main thread

Findings:

- `ZideActivity` still owns the Android lifecycle entrypoint and the
  remaining wiring surface for lifecycle dispatch, sidebar controls, IME
  ownership, gesture intake, and JNI bridge calls
- viewport/inset authority now lives in `dev.zide.terminal.host.TerminalViewportController`
- debug/status presentation now lives in `dev.zide.terminal.debug.StatusController`
- a 150ms `shellRefreshRunnable` still exists and may re-enter:
  - `refreshShellState(false)`
  - `ShellSessionController.poll(...)`
  - status updates
- `ShellSessionController.poll(...)` still performs:
  - synchronous native poll
  - readiness-state reload from disk
- older transcript-era follow/refresh assumptions had to be removed before
  the current host shape behaved as product truth
- gesture/input paths still call into product refresh directly:
  - assist-bar actions call `refreshShellState(false)`
  - `ShellInputView` calls `host.refreshShellState()` in several input paths
- product gestures still cross JNI on the UI thread:
  - single tap -> IME/focus work
  - pinch -> choreographer-coalesced native zoom apply
  this is thinner than before, but still part of the UI-thread contract

What this means:

- the Java host is no longer the dominant performance mystery, but it is still
  not thin enough to clear the performance question by design
- some product behavior is still coupled to stale transcript/debug-era UI logic
  rather than a narrow host contract

Why this is in war scope:

- this category is Android-local in ownership, but it is still part of the
  low-level contract pressure we are using to expose shared renderer truth
- the renderer cannot be audited honestly if the host still rebuilds too much
  product state on the main thread

What is allowed here:

- lifecycle dispatch required by Android
- narrow JNI state handoff
- explicit IME/focus ownership
- thin gesture ownership and frame-coalesced scheduling

What is forbidden here:

- periodic reconstruction of product state on the UI thread when an event-driven
  or staged model can own it
- follow logic that overrides product scrolling semantics
- mixing debug/status text maintenance into ordinary product lifecycle/input
  flows

Current stop marker for this subcategory:

- the Android host main thread must stop acting as a periodic product-state
  coordinator; product scrolling and debug/status upkeep must have narrower
  ownership and no longer distort renderer performance diagnosis

Current stop reading after the latest host cuts:

- that stop marker is now materially met for the active Android terminal lane
- the remaining `ZideActivity` surface is still large, but most of it
  now reads as legitimate Android ownership:
  lifecycle dispatch, surface callbacks, IME/focus, gesture intake, sidebar
  controls, and JNI handoff, with debug/status presentation and
  viewport/inset authority split into their own controllers
- further Java extraction without a new concrete product bug would now risk
  cosmetic OO churn more than real contract tightening
- the next honest pressure returns to the shared renderer-thread queue unless a
  new Android host regression proves otherwise

Initial fix queue:

1. separate product shell state refresh from debug/operator refresh
2. remove or sharply narrow auto-follow behavior that currently snaps product
   scrolling back to bottom
3. reduce `ShellInputView` -> `refreshShellState()` coupling in ordinary input
   paths
4. remove obsolete product assumptions entirely now that shared renderer
   shell output is the only product path
5. split `ZideActivity` responsibilities further only after ownership
   boundaries are fixed, not as a cosmetic OO refactor

Do not do:

- do not treat Java file extraction by itself as a performance fix
- do not keep the 150ms poll/state-refresh model just because it was good
  enough for early baseline validation
- do not solve scroll snap-back with another local conditional while the host
  still owns the wrong follow policy

Current progress:

- first iteration cut landed here:
  - `ShellInputView` no longer asks the activity for broad shell refresh on
    ordinary input events
  - stale follow behavior no longer forces bottom-follow from IME-visible state
    or inset application alone
- second host ownership cut landed:
  - readiness-state reload and shell-session poll are now explicit separate
    operations in the activity/controller contract
  - the debug refresh loop now names itself as debug/operator upkeep instead of
    a generic product shell refresh entrypoint
- third host ownership cut landed:
  - ordinary status updates now use the activity's tracked readiness state
    instead of reloading readiness stamp state from disk on every call
  - hidden operator-state I/O is reduced in broad UI status/update paths
- fourth host ownership cut landed:
  - the 150ms debug shell refresh loop is removed
  - debug/operator upkeep now refreshes from explicit events instead of acting
    as a periodic main-thread coordinator
- fifth host ownership cut landed:
  - product readiness-blocker visibility no longer reevaluates the product
    frame loop as a hidden side effect
- Android scrollback/IME size-pressure found one shared geometry contract
  defect:
  - Java-reported surface and visible viewport sizes match on device during
    IME transitions, so the active issue is not a Java frame mismatch
  - terminal grid fitting floors rows/cols correctly, but shared terminal view
    geometry was centering the fitted grid inside the viewport
  - terminal grids are now anchored at the viewport origin; remainder pixels
    stay on the right/bottom like a normal terminal emulator
  - a height-only shrink helper was rejected as a workaround because it mutated
    history/grid/cursor outside the owning screen resize API
  - height-only shrink is now a shared terminal resize policy:
    - when the cursor would fall below the new bottom row, the resize
      transaction retires only the required top live rows into history
    - pinned scrollback offset is adjusted by that retired-row delta so the
      selected logical viewport does not move toward the new prompt
    - hosts remain responsible only for truthful size reporting
  - Android now treats `product_surface_container` as the single product
    terminal viewport authority for visible-viewport reporting and scroll
    gesture row math; broader content-frame dimensions are not terminal-size
    authority
  - htop CPU-meter scattering is not currently classified as viewport
    authority:
    - `nvim` lays out inside the same Android viewport
    - htop-style meter output exercises curses protocol features and terminal
      UI glyph rendering
    - shared terminal protocol now implements REP (`CSI Ps b`) so repeated bar
      glyphs/spaces are not dropped
    - Note10 release-build retest proved the htop CPU meter layout after this
      protocol fix
    - further htop defects should be audited as shared protocol or cell-glyph
      compatibility before reopening Android size reporting
  - product frame-loop reevaluation is now an explicit activity operation with
    product ownership in its name
- sixth host ownership cut landed:
  - debug status formatting no longer runs on ordinary product events while the
    debug view is hidden
  - debug-mode entry remains the explicit owner of when the status surface is
    refreshed
- seventh host ownership cut landed:
  - shell poll telemetry, product shell state upkeep, and debug status-surface
    refresh no longer live as one broad activity operation
  - `refreshDebugShellState(...)` now delegates those responsibilities through
    explicit helper seams
- eighth host ownership cut landed:
  - install-state transitions now route through one explicit activity seam for
    blocker visibility, product frame-loop reevaluation, and status upkeep
  - install failure handling no longer fans that ownership out manually across
    multiple UI calls
- ninth host ownership cut landed:
  - product/debug view-mode transitions now route through explicit activity
    owner methods instead of repeated open-coded toggle sequences
  - package-doctor/debug entry points now reuse the same view-mode ownership
    seam
- tenth host ownership cut landed:
  - shell restart now routes through one explicit activity seam for restart
    status logging, shell-state refresh, and status-surface upkeep
  - manual restart, debug shell-start, and install-success restart no longer
    hand-roll that sequence separately
- eleventh host ownership cut landed:
  - lifecycle and surface callbacks no longer hand-roll the same post-event
    product/debug aftermath sequence
  - callback-side shell refresh, product frame-loop reevaluation, and status
    upkeep now route through one explicit activity seam
- current checkpoint:
  - Java host cleanup is no longer the dominant performance or ownership
    mystery for Android terminal progress
  - reopen this subcategory only for a concrete host-side product blocker, not
    more generalized thinning
- that does not finish this category:
  - `ZideActivity` is still large, but the remaining breadth is not by
    itself proof of wrong ownership

## Current Non-Render Cleanup Already Landed

These items were previously contaminating performance diagnosis and are now
reduced:

- explicit `profile` and `release` Android deploy paths exist
- shared-renderer product mode no longer keeps the old Java shell poll loop
  alive by default
- file reads and debug/status churn are reduced when the shared renderer owns
  the product shell

Those cuts do not finish Android performance work. They only remove obvious
non-render noise so render-thread scrutiny can proceed honestly.

## Immediate Rule For New Work

Any new Android renderer or interaction change must answer:

1. Why must this execute on the render path?
2. What is the bounded cost?
3. Why can it not be staged or coalesced elsewhere?

If those answers are weak, the design is wrong.

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
- stale transcript-era string rebuilding on the product path
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

- accepted temporarily for Android bring-up
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
  - pinch end commits the expensive `applyFontScale(...)` rebuild once so
    raster font assets catch up to the final settled size
  - queued user zoom now uses the same cheap live scale path and commits the
    expensive font rebuild only after the zoom target settles
- remaining work:
  - display-metric and config font changes intentionally still use the full
    rebuild path until their ownership is audited separately
  - font-cache reuse across committed scale targets is still unresolved

### 2. Direct interaction-to-frame submission path

`src/platform/android_runtime_bridge.zig`

`applyTerminalPinchZoom(...)` and related Android interaction paths currently
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

Initial findings:

- `applyTerminalPinchZoom(...)` still performs renderer mutation plus immediate
  frame draw
- surface and viewport entry points can still trigger direct draw from the
  bridge layer
- the render-entry seam is still responsible for too much policy, not just
  frame-critical submission

Initial fix queue:

1. list every current caller of `drawSharedRendererSurfaceFrame()`
2. classify each caller as lifecycle-critical, product-critical, or stageable
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

Initial findings:

- live draw still owns product-fit terminal-grid checks
- the draw path may still trigger PTY resize and presentation invalidation
- pinch currently bypasses one part of this cost, but the design remains hot
  draw-path coupled

Initial fix queue:

1. prove which grid-fit decisions are truly required before draw
2. separate "viewport changed" from "must resize PTY right now"
3. stage non-critical grid commits outside the hottest render path

Do not do:

- do not keep layout policy inside draw just because it is convenient for the
  current Android bridge

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
- `src/ui/widgets/terminal_widget_presentation_state.zig`
- `src/ui/widgets/terminal_widget_presentation_runtime.zig`
- all current callers of `invalidatePresentationCache()`

Findings:

- `invalidatePresentationCache()` is currently a single-bit reset:
  `terminal_presentable_ready = false`
- Android bridge paths already call that broad invalidation directly:
  - `applyTerminalPinchZoom(...)`
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

- using one `terminal_presentable_ready` bit as the only cache/invalidation
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
  - lazy GL resource init
  - lazy font init
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
- do not keep debug writes in product flow just because they helped bring-up
- do not claim backend/frame timings are pure until this contamination is
  narrowed

### 7. Remaining Android host/UI-thread contamination

`android/terminal-host/app/src/main/java/dev/zide/terminal/`

Android is only the pressure source, but the host still has to meet a strict
contract: feed the renderer the minimum required state and keep product input
and surface ownership thin and predictable.

Required direction:

- keep the main thread thin, boring, and deterministic
- keep product state sync separate from debug/operator state
- avoid UI-thread work that reconstructs product state every refresh tick

### Subcategory audit: remaining Android host/UI-thread contamination

Scope:

- `ZideTerminalActivity.java`
- `ShellSessionController.java`
- `ShellInputView.java`
- Java-side gesture, lifecycle, status, and stale transcript-era flows on the
  main thread

Findings:

- `ZideTerminalActivity` still owns a broad main-thread orchestration surface:
  lifecycle, viewport/insets, status/debug text, sidebar, package/bootstrap
  actions, IME ownership, gesture ownership, and JNI bridge calls
- a 150ms `shellRefreshRunnable` still exists and may re-enter:
  - `refreshShellState(false)`
  - `ShellSessionController.poll(...)`
  - status updates
- `ShellSessionController.poll(...)` still performs:
  - synchronous native poll
  - bootstrap-state reload from disk
- product shell correctness was recently distorted by stale transcript-era
  follow/refresh assumptions even after the Java transcript surface was no
  longer product truth
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
- stale transcript-era follow logic that overrides product scrolling semantics
- mixing debug/status text maintenance into ordinary product lifecycle/input
  flows

Current stop marker for this subcategory:

- the Android host main thread must stop acting as a periodic product-state
  coordinator; product scrolling and debug/status upkeep must have narrower
  ownership and no longer distort renderer performance diagnosis

Initial fix queue:

1. separate product shell state refresh from debug/operator refresh
2. remove or sharply narrow auto-follow behavior that currently snaps product
   scrolling back to bottom
3. reduce `ShellInputView` -> `refreshShellState()` coupling in ordinary input
   paths
4. remove transcript-era product assumptions entirely now that shared renderer
   shell output is the only product path
5. split `ZideTerminalActivity` responsibilities further only after ownership
   boundaries are fixed, not as a cosmetic OO refactor

Do not do:

- do not treat Java file extraction by itself as a performance fix
- do not keep the 150ms poll/state-refresh model just because it was good
  enough for bring-up
- do not solve scroll snap-back with another local conditional while the host
  still owns the wrong follow policy

Current progress:

- first iteration cut landed here:
  - `ShellInputView` no longer asks the activity for broad shell refresh on
    ordinary input events
  - stale follow behavior no longer forces bottom-follow from IME-visible state
    or inset application alone
- that does not finish this category:
  - the 150ms poll model still exists
  - `ZideTerminalActivity` still owns too much product/debug orchestration

## Current Non-Render Cleanup Already Landed

These items were previously contaminating performance diagnosis and are now
reduced:

- explicit `profile` and `release` Android deploy paths exist
- shared-renderer product mode no longer keeps the old Java shell poll loop
  alive by default
- stale transcript-era file reads and debug status churn are reduced when the
  shared renderer owns the product shell

Those cuts do not finish Android performance work. They only remove obvious
non-render noise so render-thread scrutiny can proceed honestly.

## Immediate Rule For New Work

Any new Android renderer or interaction change must answer:

1. Why must this execute on the render path?
2. What is the bounded cost?
3. Why can it not be staged or coalesced elsewhere?

If those answers are weak, the design is wrong.

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
- transcript parsing / string rebuilding
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

### 3. Grid resize in draw flow

`src/platform/android_runtime_bridge.zig`

`drawLiveTerminalWidgetFrame(...)` currently performs terminal-grid fit checks
and may trigger resize before draw.

That means layout/product-fit work is still coupled to live frame submission.

Required direction:

- prove which resize decisions are truly frame-critical
- move non-critical resize work out of the hot draw path
- make deferred/staged grid commit explicit where needed

## Current Non-Render Cleanup Already Landed

These items were previously contaminating performance diagnosis and are now
reduced:

- explicit `profile` and `release` Android deploy paths exist
- shared-renderer product mode no longer keeps the 150ms Java transcript poll
  loop alive by default
- transcript file reads and debug status churn are reduced when the shared
  renderer owns the product shell

Those cuts do not finish Android performance work. They only remove obvious
non-render noise so render-thread scrutiny can proceed honestly.

## Immediate Rule For New Work

Any new Android renderer or interaction change must answer:

1. Why must this execute on the render path?
2. What is the bounded cost?
3. Why can it not be staged or coalesced elsewhere?

If those answers are weak, the design is wrong.

# Frame Begin Readiness Plan

Purpose: define the next narrow gate-5 cut under `RB-B3.b`.

This doc is intentionally small. It does not redesign broader frame ordering.
It only records the next pressure proved by `RB-B3.a`.

## Pressure Proven By Code

After `RB-B3.a`:

- shared frame finalization no longer consumes raw backend booleans
- OpenGL and Metal both report begin/submit/abandon through one small outcome
  surface

But one important asymmetry remains:

- `Renderer.beginFrame()` is still a `void` seam
- backend begin/acquire may fail during that call
- shared draw/runtime code still proceeds as if a backend frame is ready

Today that means Metal begin/acquire failure can still allow shared scene
assembly and widget draw work to continue even when no backend frame is live.

That is not yet broader frame-ordering design. It is a missing frame-entry
readiness contract.

## Scope

This plan covers:

- frame-entry readiness reporting
- ownership of “frame ready for draw” vs “frame not ready” truth
- shared draw/runtime behavior when backend begin fails before draw

This plan does not cover:

- broader frame ordering redesign
- renderer-wide transaction unification
- terminal-present transaction changes
- new backend capability surfaces

## Ownership Questions

### 1. Who decides whether draw should be attempted at all?

Shared app/runtime code decides.

Current evidence:

- `src/app/frame_render_idle_runtime.zig`

That logic already owns redraw need and pacing. `RB-B3.b` must not move that
decision into backend code.

### 2. Who decides whether a backend frame is ready for draw after attempt begins?

Backend code decides native readiness.
Shared code owns the product meaning of the reported readiness.

Current pressure:

- `src/ui/renderer.zig`
- `src/ui/renderer/gl_backend.zig`
- `src/ui/renderer/metal_backend.zig`

Required rule for `RB-B3.b`:

- backend begin/acquire reports one narrow readiness result
- shared code does not infer readiness from backend-specific state
- shared draw/runtime code can stop early when backend begin did not produce a
  drawable frame

### 3. Who owns draw-skip behavior after begin failure?

Shared draw/runtime code owns it.

Reason:

- skipping scene assembly or widget draw after begin failure is product/runtime
  behavior
- backend code should not decide which shared UI passes still run

Required rule for `RB-B3.b`:

- shared runtime gets enough truth from frame begin to skip draw honestly
- no backend-specific begin failure branches leak into app draw/runtime code

## First Code Pressure

The first code cut should stay narrow:

- define one small shared frame-begin readiness result
- thread it through `Renderer.beginFrame()` / `Shell.beginFrame()`
- let shared draw/runtime skip the draw body when the frame is not ready

Primary code pressure:

- `src/ui/renderer.zig`
- `src/ui/renderer/renderer_frame_host.zig`
- `src/ui/renderer/gl_backend.zig`
- `src/ui/renderer/metal_backend.zig`
- `src/app_shell.zig`
- `src/app/draw_frame_runtime.zig`

## Non-Goals

- no broad frame transaction object
- no new backend policy bucket
- no change to terminal-present result semantics
- no attempt to solve later frame/present ordering in this cut

## Stop Marker

`RB-B3.b` stops when:

- backend frame begin reports one small shared readiness result
- shared draw/runtime can skip draw work when frame begin is not ready
- OpenGL and Metal both use that surface without backend-shaped schema growth
- queue/docs state what later gate-5 work still remains

## Current Checkpoint

The first code cut now exists:

- `Renderer.beginFrame()` now returns shared frame-entry readiness instead of
  hiding it behind `void`
- shared draw/runtime now skips the draw body when frame begin is not ready
- Metal diagnostic/live-smoke paths now also gate capture and draw work on the
  same shared readiness truth
- this did not require a broader frame transaction object or a widened
  `FrameSubmission`

Immediate remaining pressure after this proof:

- keep frame-entry readiness narrow and product-level
- do not let later frame/present ordering pressure turn this into a generic
  frame transaction surface prematurely
- only define the next gate-5 cut where the code now proves a real ordering or
  ownership gap

That pressure tightened once more in the next follow-up:

- the smallest remaining ordering leak after `RB-B3.b` was that
  `Renderer.beginFrame()` still reset backend clip state before shared code knew
  whether a drawable frame existed
- that is now removed by gating the initial clip reset on shared frame-entry
  readiness

Current implication:

- shared frame prelude and backend begin do not yet need a larger unified host
  seam just to become honest
- the next gate-5 cut should wait for a stronger ordering/ownership pressure
  than one early backend clip reset

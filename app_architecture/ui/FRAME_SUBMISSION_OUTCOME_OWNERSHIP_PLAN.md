# Frame Submission Outcome Ownership Plan

Purpose: define the first gate-5 contract cut under `RB-B3.a`.

This doc is intentionally narrow. It answers only the four ownership questions
required to start the frame-lifecycle lane without rebuilding renderer
architecture in prose.

## Scope

This plan covers:

- frame-attempt decision ownership
- begin/acquire failure ownership
- submission outcome and finalization bookkeeping ownership
- frame abandonment ownership/reporting

This plan does not yet redesign broader frame ordering, cross-widget present
families, or renderer-wide lifecycle unification.

## Ownership Questions

### 1. Who decides a frame was worth attempting?

Shared code decides.

Reason:

- frame-attempt worthiness is product/runtime policy
- it depends on redraw need, capture state, and other shared UI truth
- it should not be inferred separately by OpenGL and Metal

Current pressure:

- `src/ui/renderer.zig`
- `src/ui/renderer/renderer_frame_host.zig`

Required rule for `RB-B3.a`:

- shared code may decide whether to attempt a frame
- backend code may only report whether begin/acquire/submit succeeded or failed

### 2. Who owns begin/acquire failure semantics?

Backend code owns the native failure mechanics.
Shared code owns the product meaning of the reported failure.

Reason:

- OpenGL and Metal fail frame begin/acquire differently
- shared code should not encode API-native failure branches
- shared code still needs one stable outcome surface for product bookkeeping

Required rule for `RB-B3.a`:

- backend begin/acquire paths report one narrow backend-execution outcome
- shared code interprets that outcome for shared frame bookkeeping
- no backend-specific failure policy should leak into `renderer_frame_host.zig`

### 3. Who owns submission outcome and finalization bookkeeping?

Split ownership:

- backend code owns native submit/present execution
- shared code owns final submission bookkeeping

Shared finalization currently includes:

- submission sequence advancement
- last-present timing publication
- trace rollover
- capture-arm reset
- shared “terminal presented” summary

Required rule for `RB-B3.a`:

- backend code returns a narrow submission outcome
- shared code performs final bookkeeping from that narrow outcome
- `renderer_frame_host.zig` must not become a hiding place for backend-specific
  submission interpretation

### 4. Who is allowed to abandon a frame, and how is that reported back?

Backend code may abandon a native frame it owns.
Shared code may abandon a product-level attempt before backend begin.

Reason:

- native frame handles/resources are backend-owned once acquired
- shared code still needs to know whether the frame attempt was never begun,
  began and was abandoned, or submitted

Required rule for `RB-B3.a`:

- backend abandonment must report one narrow shared outcome
- shared code must not guess whether a backend frame was abandoned
- abandonment reporting must be stable enough that OpenGL and Metal map onto
  the same product-level frame bookkeeping surface

## First Code Pressure

The first code cut should stay narrow:

- define one small shared frame-execution outcome surface
- route `renderer_frame_host.zig` finalization through that surface
- do not redesign broader frame ordering in the same step

Primary code pressure:

- `src/ui/renderer/renderer_frame_host.zig`
- `src/ui/renderer.zig`
- `src/ui/renderer/backend_dispatch.zig`
- `src/ui/renderer/gl_backend.zig`
- `src/ui/renderer/metal_backend.zig`

## Non-Goals

- no renderer-wide frame rewrite
- no terminal-present contract rewrite
- no cross-widget ordering family redesign
- no new generic policy bucket in `backend_dispatch.zig`

## Stop Marker

`RB-B3.a` stops when:

- one shared frame-execution outcome surface exists
- backend begin/submit/abandon paths report through it
- shared finalization bookkeeping consumes it
- queue/docs clearly state what still belongs to later gate-5 work

## Current Checkpoint

The first code cut now exists:

- shared frame execution uses one small outcome surface
  - `not_attempted`
  - `begin_failed`
  - `abandoned`
  - `submitted`
  - `submit_failed`
- shared frame host finalization now consumes that surface
- OpenGL and Metal both report through it without widening the schema for
  backend-specific mechanics

Immediate remaining pressure after this proof:

- keep `renderer_frame_host.zig` limited to shared finalization bookkeeping
- do not let later frame-ordering or widget-present policy drift into the new
  outcome surface
- restate later gate-5 work only where the code now shows real pressure:
  broader frame/present/order ownership, not more frame-outcome schema growth

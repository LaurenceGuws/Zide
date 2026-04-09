# Backend Runtime Ownership Plan

Purpose: define the next narrow gate-4 cut under `RB-B2`.

This plan is intentionally narrow. It does not redesign frame ordering,
presentable lifecycle, or backend capability shape. It only answers the
runtime-storage ownership question that is now blocking honest third-backend
adoption.

## Why This Is Next

Current code truth is now more specific than it used to be:

- shared code no longer meaningfully reads `renderer.backend.runtime` outside
  backend modules
- OpenGL and Metal now terminate most concrete runtime mutation behind their
  backend modules
- `Renderer.backend.runtime` no longer materializes both concrete backend
  states at once
- `Renderer.backend.runtime` no longer embeds selected concrete backend state
  inline either
- but `Renderer` still owns selected-runtime lifecycle and the opaque runtime
  handle through `backend_runtime_bundle.Bundle`

That means the remaining gate-4 pressure is no longer "shared code is poking
backend state everywhere."

It is this:

- `Renderer` is still the owner of selected-runtime lifecycle and storage
  handle plumbing
- adding a third backend would still pressure that renderer-owned runtime
  lifecycle story even though the concrete storage surface is no longer
  backend-tagged
  again

Android host work now makes that pressure immediate instead of theoretical.
The repo can now represent Android surface/lifecycle truth honestly, so the
next blocker before Android rendering is not host ambiguity. It is the fact
that a new backend would still require widening `Renderer.backend.runtime`.

## Scope

This plan covers:

- ownership of concrete backend runtime storage shape
- ownership of backend runtime init/deinit/mutation
- what shared renderer code may know about backend runtime
- the first narrow storage-ownership cut for OpenGL and Metal

This plan does not cover:

- frame ordering redesign
- presentable lifecycle redesign
- terminal-present transaction changes
- third-backend bootstrap

## Ownership Questions

### 1. Who owns the concrete backend runtime storage shape?

Backend code owns it.

Shared renderer code may own one backend host surface for the selected backend,
but it must not materialize one concrete storage bundle containing every
backend's runtime state at once.

Required rule for `RB-B2.a`:

- `Renderer` must stop materializing both OpenGL and Metal runtime structs in
  one widening bundle
- the selected backend may still be reachable through shared host seams, but
  its concrete storage shape must be backend-owned or opaque to shared code

### 2. Who owns runtime init, deinit, and mutation?

Shared code owns product-level lifecycle triggers.
Backend code owns concrete storage init, deinit, and mutation.

Reason:

- shared code still decides when renderer startup/shutdown happens
- backend code should remain the only place that knows how its runtime storage
  is created, destroyed, or mutated

Required rule for `RB-B2.a`:

- shared code may trigger backend runtime lifecycle
- backend code performs the concrete storage work
- shared code must not reopen direct mutation of backend-native runtime fields

### 3. What may shared code know about backend runtime?

Only backend-neutral host truth plus the selected backend contract surface.

Current code already proves most of this:

- shared code now calls backend ops instead of reading most backend storage
  directly
- the main remaining leak is the renderer-owned concrete bundle shape itself

Required rule for `RB-B2.a`:

- no new shared code should depend on OpenGL- or Metal-native runtime types
- the first cut should remove storage widening without inventing a larger
  generic backend object model than current pressure requires

### 4. What pressure proves this lane is active now?

Android host/bootstrap truth is now merged.

That means the repo can now honestly say:

- Android-native host work is no longer the blocking unknown
- Android rendering remains blocked by the shared renderer contract

The runtime-storage part of that blocker is now concrete:

- an Android renderer backend would currently require another widening branch
  in the renderer-owned selected-runtime storage story

That is enough evidence to open `RB-B2` now, even while gate 5 remains closed
to speculative redesign.

## First Code Pressure

The first code cut should stay narrow:

- remove the old widening `backend_runtime_bundle.Bundle` shape
- replace it with one selected-backend runtime surface
- keep GL and Metal behavior unchanged

Primary code pressure:

- `src/ui/renderer/renderer_backend_host.zig`
- `src/ui/renderer/backend_runtime_bundle.zig`
- `src/ui/renderer/backend_dispatch.zig`
- `src/ui/renderer/gl_backend.zig`
- `src/ui/renderer/metal_backend.zig`
- `src/ui/renderer.zig`

## Non-Goals

- no third-backend bootstrap
- no new frame transaction design
- no presentable transaction redesign
- no speculative fully-generic backend object framework

## Stop Marker

`RB-B2.a` stops when:

- `Renderer.backend` no longer materializes concrete OpenGL and Metal runtime
  storage side-by-side
- one selected-backend runtime storage surface replaces the widening bundle
- GL and Metal init/deinit/draw/present paths still work without behavior
  change
- queue/docs clearly state what later gate-4 pressure still remains

## Current Checkpoint

The first code cut now exists:

- `backend_runtime_bundle.Bundle` is now selected-backend storage instead of a
  widening GL+Metal struct
- `Renderer` no longer materializes both concrete runtime states at once
- `Renderer` no longer embeds selected concrete backend runtime inline either
- GL and Metal backend modules now reach runtime through selected-backend
  accessors with no intended behavior change
- Metal runtime optional/helper callers now return neutral results when the
  selected backend is not Metal, instead of tripping selected-runtime
  assertions from shared optional hook paths

Immediate remaining pressure after this proof:

- `Renderer` no longer owns a backend-tagged selected-runtime storage surface;
  selected runtime now lives behind one opaque storage handle plus backend kind
- `Renderer` no longer spells selected-runtime storage init/deinit directly;
  that now routes through backend runtime ops
- shared code no longer reaches into `renderer.backend.ops` or
  `renderer.backend.kind` directly; it now terminates at
  `renderer_backend_host.zig`
- `Renderer` no longer assembles backend dispatch plus runtime storage by hand
  in `Renderer.init()`; backend-host construction now lives in
  `renderer_backend_host.zig`
- the remaining blocker is the renderer-owned backend host itself, which still
  carries backend selection, dispatch, and runtime handle ownership even if
  shared callers now go through host methods
- the next gate-4 cut should only open when it can move that ownership
  boundary again, not merely reshuffle helper routing

## Reference Pressure: Ghostty

Ghostty is useful here as pressure, not as a template.

What it validates:

- higher-level code should terminate at one host/surface owner instead of
  reaching into backend machinery directly
- backend/device/runtime details should stay local to the backend owner
- platform/view truth can stay platform-native without weakening the renderer
  contract

What it does **not** justify:

- copying Ghostty's object model wholesale into Zide
- collapsing Zide's IDE renderer into a terminal-first surface model
- introducing a large new generic backend framework just because Ghostty keeps
  high-level code away from backend details

Practical consequence for the next gate-4 cut:

- the next move should target the renderer-owned backend host object itself
  only if that ownership can be reduced without turning `renderer_backend_host`
  into abstraction theater
- Ghostty pressure says "one sanctioned owner surface," which Zide now has
  (`renderer_backend_host.zig`)
- it does **not** by itself prove that the next step should be "hide
  everything behind another opaque object" unless local code pressure says that
  object will stay honest

## Current Stop Marker

The next superficially available move would be to heap-own or pointer-wrap the
backend host itself.

Current code pressure does **not** justify that:

- shared code is already off `renderer.backend.ops` / `renderer.backend.kind`
- backend-host construction is already centralized
- runtime storage is already opaque and backend-owned in practice

So a heap-owned backend host would currently be indirection theater unless it
also changes who owns backend selection/dispatch/runtime at the product level.

That means the next gate-4 move must answer a stronger question first:

- if `Renderer` should not own the backend host surface, what higher-level
  owner should, and why is that owner more honest than the current renderer
  field?

Latest narrowing cut:

- shared font init/text-config paths now route backend helper access through
  `renderer_font_backend_host.zig` instead of importing GL/Metal backend
  modules directly
- this does not move selected-runtime storage ownership yet, but it removes
  one more shared helper leak ahead of any later gate-4 ownership move
- shared text-runtime flush/fallback helper access now routes through
  `renderer_text_backend_host.zig` instead of importing GL/Metal backend
  modules directly from `text_runtime.zig`
- shared bootstrap backend selection now routes through `backend_dispatch.zig`
  instead of a separate GL/Metal switch in `bootstrap_runtime.zig`
- shared text/surface host boundary files now route GL flush helper access
  through `renderer_text_backend_host.zig` and
  `renderer_surface_backend_host.zig` instead of importing `gl_backend.zig`
  directly
- `draw_ops.zig` and `glyph_cache.zig` now route GL vertex-stream helper
  access through `renderer_vertex_stream_backend_host.zig`; the remaining
  OpenGL-specific code there is now explicit vertex-stream machinery rather
  than direct backend helper leakage

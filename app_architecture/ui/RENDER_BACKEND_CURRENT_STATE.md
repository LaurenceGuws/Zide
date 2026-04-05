# Renderer Backend Current State

Purpose: describe the renderer/backend contract Zide currently has, not the one
it wants.

This is the current-state companion to
`app_architecture/ui/RENDER_BACKEND_CONTRACT.md`.

## Executive Truth

Zide is in a much better place than before, but it does not yet have a
best-in-class backend abstraction.

OpenGL and Metal now both exist as real lanes, but the shared renderer still
knows too much about both implementations.

So the honest answer to "would Vulkan be easy to add?" is:

- easier than before
- not yet easy

## What Is Good

### Capability naming is better

`RendererCapabilities` in `src/ui/renderer.zig` describes real runtime behavior
such as:

- scene composition mode
- terminal presentation mode
- screenshot mode
- text rendering mode
- atlas storage mode
- raw image texture support

That is a meaningful improvement over backend-label theater.

### Metal is no longer hypothetical

The Metal lane now has real implementation coverage for:

- frame acquisition/submit
- atlas ownership
- raw image drawing
- terminal snapshot/presentable behavior
- live terminal interaction and partial-update paths

That makes OpenGL and Metal useful comparison pressure instead of paper plans.

## Where The Contract Still Fails

### 1. `Renderer` still stores concrete Metal runtime state

In `src/ui/renderer.zig`, the shared renderer still owns:

- `metal_backend_context`
- `metal_frame`
- `metal_surface_draws`

That means the renderer root is still partly the Metal implementation center,
not just the backend-neutral host/facade.

This is not just storage drift. It means shared renderer lifecycle, teardown,
and submission logic still depend on Metal-native state shape directly.

### 2. Shared frame lifecycle still branches backend-by-backend

`beginBackendFrame` and `submitBackendFrame` in `src/ui/renderer.zig` switch
directly on `.opengl` and `.metal`.

That is survivable for two backends, but it is not the shape that makes a
third backend feel routine.

This has improved slightly: the backend-native begin/submit bodies now live in:

- `src/ui/renderer/opengl_frame_runtime.zig`
- `src/ui/renderer/metal_frame_runtime.zig`
- dispatched via `src/ui/renderer/backend_frame_runtime.zig`

So the renderer root no longer spells out the whole OpenGL and Metal frame
loops inline.

But there is still not a final backend lifecycle seam yet:

- the dispatch point still lives in shared frame runtime code
- shared lifecycle helpers still expose backend-specific state on `Renderer`
- the backend frame runtimes still operate on a renderer object that carries
  concrete backend state directly

### 3. The shared draw queue is still Metal-native

The shared renderer currently stores and submits
`metal_backend.SurfaceDraw`, which expands into:

- `AtlasSampleDraw`
- `RawImageDraw`
- `SolidColorDraw`

Those types live in `src/ui/renderer/metal_backend.zig`.

This has improved slightly: the draw payload types now live in
`src/ui/renderer/surface_draw.zig` instead of `metal_backend.zig`.

But the submission flow is still not fully shared yet:

- Metal is still the only backend consuming that draw union directly
- shared renderer helpers still expose Metal-shaped public verbs
- OpenGL does not yet participate in the same backend-neutral submission path

This is the strongest current contradiction against a future Vulkan lane.

If Vulkan were added today, the easiest local move would be to add another
backend-native draw payload beside the Metal one. That is exactly the failure
mode this campaign is supposed to prevent.

### 4. Retained/presentable surfaces are still GL-shaped in shared runtime code

`src/ui/renderer/retained_targets_runtime.zig` still imports
`gl_backend.RenderTarget` as the retained surface type.

This has improved slightly: the presentable target type now lives in
`src/ui/renderer/presentable_target.zig` instead of being owned directly by the
GL backend.

The shared runtime surface has improved too:

- the main shared retained-target API now uses presentable-oriented names
- callers no longer have to speak in GL-era `ensureSurface` /
  `beginSurface` / `drawSurface` vocabulary

But the presentable surface story is still not backend-neutral at the shared
runtime layer:

- the moved type is still FBO/texture-shaped
- shared runtime behavior is still effectively the GL retained-surface model
- Metal still reaches presentable behavior through a separate direct/snapshot
  lane instead of the same contract

That is why OpenGL still reads like "the real retained implementation" while
Metal reads like "the special direct/snapshot implementation" instead of both
being implementations of one presentable contract.

### 5. The caller-facing renderer surface is better, but still not fully neutral

The renderer root no longer forces main callers through Metal-shaped public
verbs. The main submission entrypoints now use backend-neutral names.

That is a real improvement.

But the contract is still not finished because:

- those verbs still only succeed on the Metal path today
- backend submission still does not run through one neutral lifecycle surface
- OpenGL still does not consume the same draw/present contract

## Concrete Evidence Centers

The main contradiction centers today are:

- `src/ui/renderer.zig`
  - backend-owned state is stored directly on `Renderer`
  - frame begin/submit dispatch is inline
  - Metal-specific draw helpers are public renderer methods
- `src/ui/renderer/metal_backend.zig`
  - owns a useful implementation surface, but also currently owns the draw
    payload types carried by shared renderer state
- `src/ui/renderer/gl_backend.zig`
  - still defines the retained target type consumed by shared runtime code
- `src/ui/renderer/retained_targets_runtime.zig`
  - shared runtime logic still depends on GL-native presentable storage

## First Required Cut Order

The next structural cuts should happen in this order:

### Cut 1. Shared surface draw contract

Define one backend-neutral draw payload in shared renderer/runtime code for:

- solid rect
- atlas sample
- raw image
- presentable blit

Then make both OpenGL and Metal consume that same contract.

Status, 2026-04-05:

- the shared payload types now exist in `src/ui/renderer/surface_draw.zig`
- the next required step is to make backend submission consume that contract
  without Metal-specific renderer verbs remaining as the practical API

### Cut 2. Shared presentable contract

Replace direct dependence on `gl_backend.RenderTarget` in shared runtime code
with one backend-neutral presentable target surface:

- ensure
- begin/end update
- draw presentable
- scroll/shift
- availability/reuse truth

Status, 2026-04-05:

- the presentable target type now lives in `src/ui/renderer/presentable_target.zig`
- the shared runtime surface now exposes presentable-oriented API names
- the next required step is to move lifecycle behavior behind that ownership,
  not just the storage type

### Cut 3. Backend lifecycle dispatch seam

Move inline frame begin/submit logic out of `src/ui/renderer.zig` and behind a
backend-owned lifecycle surface so the renderer root stops being the place that
knows how each backend actually submits work.

Status, 2026-04-05:

- the inline begin/submit bodies now live in dedicated backend frame runtime
  modules
- the next required step is to reduce shared renderer ownership of the dispatch
  point and backend-native frame state itself

### Cut 4. Delete backend-specific public draw helpers from `Renderer`

Only after cuts 1 through 3 are real should the Metal-specific convenience
verbs disappear behind neutral renderer/backend contracts.

## Ranked Contradictions

### High

1. backend-native draw/state types still live in shared renderer state
2. retained/presentable surface contract is still GL-shaped in shared code
3. frame lifecycle dispatch still happens inline in the renderer root
4. caller-facing renderer verbs are now neutral in name, but not yet neutral in
   backend reach

### Medium

1. capability reporting still carries some implementation truth that should
   eventually fall out of stronger shared contracts
2. current docs and queues now point at the right campaign, but code still
   reflects the older "make Metal real first, contract later" execution order

### Low

1. doc language is improving, but some older renderer docs still describe
   modularization or platform progress rather than the stronger backend
   contract bar

## What Must Change Before Vulkan Feels Routine

1. move draw list ownership to backend-neutral types
2. move presentable/retained target ownership to backend-neutral types
3. move backend frame dispatch behind one backend-owned lifecycle seam
4. widen the neutral renderer verbs until both OpenGL and Metal can honestly
   sit behind the same submission surface
5. keep OpenGL and Metal as the proof pair while deleting shared-state leakage

## Current Proof Standard

The repo should treat OpenGL and Metal as the two reference implementations for
this work.

A renderer/backend change is only a real improvement if it makes both of them
look more like implementations of one contract, not more like special cases
hidden behind the same enum.

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

`RendererCapabilities` now lives in
`src/ui/renderer/capability_contract.zig` and describes real runtime behavior
such as:

- scene composition mode
- terminal presentation mode
- screenshot mode
- text rendering mode
- atlas storage mode
- raw image texture support

That is a meaningful improvement over backend-label theater.

That has improved slightly again: the capability enums/struct are no longer
owned by `renderer.zig`, and backend modules now report capability truth
through that shared contract instead of the renderer root hardcoding every
OpenGL/Metal capability combination itself.

### Metal is no longer hypothetical

The Metal lane now has real implementation coverage for:

- frame acquisition/submit
- atlas ownership
- raw image drawing
- terminal snapshot/presentable behavior
- live terminal interaction and partial-update paths

That makes OpenGL and Metal useful comparison pressure instead of paper plans.

## Where The Contract Still Fails

### 1. `Renderer` still stores concrete backend runtime state

In `src/ui/renderer.zig`, the shared renderer still owns one bundled Metal
runtime state:

- `metal_runtime.backend_context`
- `metal_runtime.frame`
- `metal_runtime.queued_surface_draws`
- `metal_runtime.preview_source`

It now also owns one bundled OpenGL runtime state:

- `opengl_runtime.context`
- `opengl_runtime.shader_program`
- `opengl_runtime.vao`
- `opengl_runtime.vbo`
- `opengl_runtime.white_texture`

That means the renderer root is still partly the backend implementation center,
not just the backend-neutral host/facade.

This has improved slightly because backend-native state is now bundled per
backend instead of being scattered as unrelated renderer peers.

But it is still not the end-state. Shared renderer lifecycle, teardown, and
submission logic still depend on backend-native state shape directly.

This has improved slightly again: backend teardown now runs through backend
modules instead of `Renderer.deinit()` spelling out both OpenGL and Metal
cleanup inline.

This has improved slightly once more: backend startup/init now also runs
through backend modules instead of `Renderer.init()` and
`runStartupBackendSmoke()` spelling out both OpenGL and Metal boot logic
inline.

This has improved slightly again: Metal-only maintenance helpers such as
queued-surface cleanup and diagnostic-font cleanup now live on the Metal
backend instead of `Renderer` carrying those backend-specific chores itself.

This has improved slightly again on the OpenGL side too: shared draw/text code
now goes through `gl_backend` helpers for white-brush access, batch pipeline
binding, VBO growth, texture-kind uniform updates, and text-render uniform
sync instead of reaching directly into `renderer.opengl_runtime` for each of
those actions.

This has improved slightly again on the Metal side too: shared Metal-facing
renderer code now goes through `metal_backend` helpers for runtime-context
lookup, queued-surface append, and queued-surface count instead of open-coding
those `renderer.metal_runtime` storage details at each call site.

That has improved slightly again: renderer/font call sites that only need
Metal atlas hooks, glyph-atlas readiness, or snapshot-presentable status now
also route through renderer-level `metal_backend` helpers instead of manually
unwrapping the backend context at each call site.

That has improved slightly again: the shared renderer root no longer passes the
Metal queued-surface list directly into the sampled-text builders for sampled
text runs and terminal cell runs. Those queue handoffs now route through
`metal_backend` helpers too.

That has improved slightly again in the Metal frame path: frame-slot access and
queued-surface replay now route through `metal_backend` helpers instead of
`metal_frame_runtime.zig` directly mutating and iterating the
`renderer.metal_runtime` storage fields itself.

That has improved slightly again at the renderer root: the Metal diagnostic
font cache/ensure path now lives behind `metal_backend` instead of the
renderer root carrying its own backend-specific diagnostic-font initializer and
cache management logic.

That has improved slightly again at the renderer root: Metal snapshot
presentable draw and raw-image enqueue paths now also route through
`metal_backend` helpers instead of the renderer root assembling those backend
draw requests inline.

That has improved slightly again at the renderer root: even the one-off Metal
smoke frame and the basic Metal `SurfaceDraw` variant packaging now route
through `metal_backend` helpers instead of `Renderer` spelling out those
backend-specific assembly details itself.

The presentable contract has improved slightly again too: the Metal terminal
snapshot-presentable path now participates in the shared presentable contract
through `metal_backend` entrypoints, instead of
`terminal_widget_presentation_target_runtime.zig` carrying a separate
Metal-only bypass branch for availability, ensure, draw, and scroll.

That has improved slightly again at the renderer boundary too: the remaining
macOS Metal host-prep, smoke, glyph-atlas readiness, and atlas-upload
diagnostic helpers now live under `metal_backend` and the shell routes those
diagnostics through the backend module instead of `Renderer` owning that
backend-specific helper surface directly.

That has improved slightly again inside the Metal state bundle too: atlas
preview/debug state now lives under `metal_runtime.preview_source` instead of
as a separate backend-specific field on the renderer root.

That has improved slightly again on the presentable-storage side too: the
OpenGL retained-presentable cache is no longer stored as a direct renderer-root
field. It now lives under `opengl_runtime.presentable_targets`, which is a
better fit for the truth that the richer retained-presentable lifecycle is
currently an OpenGL-owned implementation shape.

That has improved slightly again on the scene-composition side too: the
offscreen scene-target contract/state now lives in a dedicated
`scene_target_state` module and is stored under `opengl_runtime.scene_target`
instead of as a direct renderer-root field. That makes the current OpenGL-owned
offscreen scene-target model less obviously shared-state-by-default.

That has improved slightly again at the renderer root too: the remaining
window-refresh / zoom invalidation merges for the OpenGL scene target now
route through `gl_backend`, and Metal atlas-preview lookup now routes through
`metal_backend`, so `Renderer` no longer directly reaches into those backend
runtime storage slots for those paths.

That has improved slightly again on the Metal-only helper surface too: the
remaining terminal-snapshot availability and macOS Metal attachment/atlas
preview conveniences no longer live on `Renderer`; those callers now go
through `metal_backend` and `macos_host` directly instead of keeping more
Metal-only shims on the renderer root.

### 2. Shared frame lifecycle still branches backend-by-backend

The renderer root no longer spells out backend frame begin/submit bodies, but
shared frame runtime code still decides whether a frame is OpenGL or Metal.

That is survivable for two backends, but it is not the shape that makes a
third backend feel routine.

This has improved slightly: the top-level frame seam is now split across:

- `src/ui/renderer.zig`
- `src/ui/renderer/opengl_frame_runtime.zig`
- `src/ui/renderer/metal_frame_runtime.zig`

So the renderer root no longer spells out the whole OpenGL and Metal frame
loops inline, and even the older scene-runtime wrapper role has been split out.

But there is still not a final backend lifecycle seam yet:

- the dispatch point still lives in shared frame runtime code
- shared lifecycle helpers still expose backend-specific state on `Renderer`
- the backend frame runtimes still operate on a renderer object that carries
  concrete backend state directly

- backend startup ownership is better, but still depends on backend modules
  mutating renderer-carried backend state directly rather than owning that
  runtime state behind a narrower lifecycle seam

This has improved slightly again: OpenGL-only scene target refresh/prep no
longer happens in a shared frame wrapper; that branch now lives under
`opengl_frame_runtime.zig`, which is closer to the contract we actually want.

That has improved slightly again: the remaining OpenGL scene-target mechanics
no longer live in `present_trace_runtime.zig`'s predecessor either. Scene-target contract
refresh, offscreen begin/draw, and recreate handling now live under
`opengl_scene_target_runtime.zig`, leaving the shared scene runtime closer to
shared present-trace semantics instead of mixed shared/GL ownership.

This has improved slightly once more: the extra shared backend-frame dispatch
wrapper is gone. `Renderer.beginFrame()` / `Renderer.submitFrame()` now do the
small shared per-frame bookkeeping directly and route to backend-owned
`beginFrame` / `submitFrame` entrypoints on the OpenGL and Metal modules.

That has improved slightly again on the OpenGL submission path too: direct GL
submit and direct window screenshot-readback logic now live under the OpenGL
frame/backend modules instead of `present_trace_runtime.zig` carrying that
OpenGL-specific behavior inside a shared runtime file.

That has improved slightly again on the presentable lifecycle side too: the
terminal presentable end path no longer bypasses the shared presentable
contract just to call a shared scene-runtime restore helper. The restore logic
now lives under the OpenGL presentable implementation, and the widget-facing
terminal presenter ends presentables through the contract again.

That has improved slightly again on teardown ownership too: OpenGL presentable
and scene-target cleanup no longer runs from `Renderer.deinit()` before backend
shutdown. That teardown now lives under `gl_backend.deinitRuntime()`, which is
closer to the contract we want.

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

This is still one of the strongest contradictions against a future Vulkan
lane.

If Vulkan were added today, the easiest local move would still be to bolt a
third backend onto a shared renderer that already carries backend-native state
and lifecycle truth directly. That is exactly the failure mode this campaign is
supposed to prevent.

### 4. Retained/presentable surfaces are still GL-shaped in shared runtime code

The neutral presentable surface no longer lives in a separate shared runtime
wrapper. That small façade now lives directly on `Renderer`, which is an
improvement over carrying one more shared dispatch module.

This has improved slightly: the presentable target type now lives in
`src/ui/renderer/presentable_target.zig` instead of being owned directly by the
GL backend.

The shared runtime surface has improved too:

- the main shared retained-target API now uses presentable-oriented names
- callers no longer have to speak in GL-era `ensureSurface` /
  `beginSurface` / `drawSurface` vocabulary
- the shared presentable contract types now live in
  `src/ui/renderer/presentable_contract.zig`
- the OpenGL presentable mechanics now live in
  `src/ui/renderer/opengl_presentable_runtime.zig` instead of inside the
  shared presentable contract module
- the renderer-owned presentable facade now routes through backend-owned
  presentable entrypoints on the OpenGL and Metal modules

But the presentable surface story is still not backend-neutral at the shared
runtime layer:

- the moved type is still FBO/texture-shaped
- OpenGL still owns the richer retained-presentable lifecycle
- Metal currently participates through a narrower direct/snapshot terminal
  presentable implementation rather than a broader presentable model

That is why OpenGL still reads like "the real retained implementation" while
Metal still reads like "the narrower direct/snapshot implementation" instead
of both being equally mature implementations of one presentable contract.

### 5. The caller-facing renderer surface is better, but still not fully neutral

The renderer root no longer carries the earlier Metal-only public helper verbs
for sampled text, terminal cell runs, raw image draws, and terminal snapshot
draws. Live callers now route those operations through `metal_backend`
directly instead of treating `Renderer` as the backend convenience surface.

That is a real improvement.

But the contract is still not finished because:

- those backend-owned entrypoints still only succeed on the Metal path today
- backend submission still does not run through one neutral lifecycle surface
- OpenGL still does not consume the same draw/present contract

## Concrete Evidence Centers

The main contradiction centers today are:

- `src/ui/renderer.zig`
  - backend-owned state is still stored directly on `Renderer`
  - shared runtime still leans on renderer-carried backend state
- `src/ui/renderer/metal_backend.zig`
  - owns a useful implementation surface, but is still the only backend
    consuming the shared surface-draw queue directly
- `src/ui/renderer/gl_backend.zig`
  - now owns more of the OpenGL runtime lifecycle, but shared renderer code
    still carries the OpenGL runtime state directly
- `src/ui/renderer.zig`
  - now also owns the small neutral presentable facade directly, so renderer
    root dispatch still remains part of the presentable contract surface
- `src/ui/renderer/opengl_presentable_runtime.zig`
  - now owns the actual GL presentable mechanics that used to live in the
    shared presentable contract module
- `src/ui/renderer.zig`
  - now owns the small shared frame facade directly, but still exposes
    renderer-wide per-frame bookkeeping and backend dispatch from one root
- `src/ui/renderer/present_trace_runtime.zig`
  - now mostly trace/present bookkeeping, but is still part of the shared
    frame lifecycle surface
- `src/ui/renderer/opengl_scene_target_runtime.zig`
  - now owns the OpenGL scene-target mechanics that used to sit in the shared
    scene runtime, but still exposes that GL model through shared renderer
    state

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

1. backend-native state still lives in shared renderer state
2. retained/presentable surface contract is still GL-shaped in shared code
3. frame lifecycle dispatch still happens in shared runtime code
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

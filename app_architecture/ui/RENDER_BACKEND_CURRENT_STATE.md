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

**Vulkan fit audit (2026-04-06):** See `docs/research/VULKAN_FIT_AUDIT_2026-04-06.md`. Verdict:
a Vulkan backend is **not** yet “routine” against the **current** code—dual draw
submission semantics (GL immediate vs Metal replay), uneven presentable maturity,
and renderer-hosted backend bundles remain the dominant surgery risks. Android/mobile
pressure fails the same honesty test until those gaps close. This does not lower
the target contract bar; it names the remaining contradictions for backend-closure
continuation.

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
- editor presentable cache compatibility (macOS OpenGL retains a deliberate
  false here; widgets query capability instead of `renderer.backend`)

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

In `src/ui/renderer.zig`, the shared renderer now owns one
`backend_runtime` bundle containing:

- `backend_runtime.opengl`
- `backend_runtime.metal`

That is cleaner than carrying separate `opengl_runtime` and `metal_runtime`
peer fields on the renderer root, and it is a worthwhile host-shape
improvement.

But it is still backend-native runtime state living under shared renderer
ownership. The bundle still contains concrete OpenGL/Metal implementation
storage such as:

- `backend_runtime.opengl.context`
- `backend_runtime.opengl.shader_program`
- `backend_runtime.opengl.vao`
- `backend_runtime.opengl.vbo`
- `backend_runtime.opengl.white_texture`
- `backend_runtime.metal.backend_context`
- `backend_runtime.metal.frame`
- `backend_runtime.metal.queued_surface_draws`
- `backend_runtime.metal.preview_source`

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
the terminal presentation runtime carrying a separate Metal-only bypass branch
for availability, ensure, draw, and scroll.

That has improved slightly again on the widget-side contract too: the tiny
terminal-specific presentable wrapper is gone, and
`terminal_widget_presentation_runtime.zig` now talks to the renderer
presentable contract directly instead of bouncing through one more forwarding
module.

That has improved slightly again at the app boundary too: **Metal glyph-atlas
readiness, atlas preview source, atlas-upload diagnostics, and terminal font
Metal atlas hooks** are **`Renderer` methods** that delegate into
`metal_backend`, and **`app_shell` does not re-export or forward** those
concerns. macOS diagnostic/smoke runtimes and the Metal text diagnostic view
call `shell.rendererPtr()` (and `ui/font_sample_view.zig` asks the renderer for
hooks) instead of growing another Shell seam or importing `metal_backend` from
UI modules.

That has improved slightly again inside the Metal state bundle too: atlas
preview/debug state now lives under `metal_runtime.preview_source` instead of
as a separate backend-specific field on the renderer root.

That has improved slightly again on the presentable-storage side too: the
OpenGL retained-presentable cache is no longer stored as a direct renderer-root
field. It now lives under `opengl_runtime.presentable_targets`, which is a
better fit for the truth that the richer retained-presentable lifecycle is
currently an OpenGL-owned implementation shape.

That has improved slightly again inside the OpenGL presentable path too:
retained-target lookup now routes through small backend-owned slot helpers
instead of open-coding terminal/editor target storage access at each
presentable operation site.

That has improved slightly again at the shared facade boundary too: the
renderer-owned presentable facade methods now live in
`renderer_presentable_host.zig` instead of `renderer.zig` directly. This does
not make the presentable lifecycle fully backend-neutral yet, but it removes
another small renderer-root ownership seam from that surface.

That has improved slightly again on the caller-facing lifecycle edge too: the
renderer root no longer exports `beginPresentable(...)` / `endPresentable(...)`
as if those were stable product verbs. The widget/view callers that actually
perform retained-surface updates now route to
`renderer_presentable_host.zig` directly for that edge, which is more honest
than pretending the renderer root owns a backend-neutral begin/end lifecycle
when Metal still does not.

That has improved slightly again on the rest of the facade too: the renderer
root no longer exports the remaining presentable forwards
(`ensurePresentable`, `presentableAvailable`, `drawPresentable`,
`scrollPresentable`, `presentableInfo`). Widget/view/diagnostic callers now
route to `renderer_presentable_host.zig` directly for the shared presentable
contract surface, which makes the ownership boundary plainer: the renderer root
no longer claims to own a facade that already lives elsewhere.

That has improved slightly again on the draw/resource side too: persistent
image upload/draw/destruction and raw-image submission no longer live as public
methods on the renderer root. Those callers now route through
`renderer_draw_host.zig`, which is more honest than pretending `Renderer`
itself owns that caller-facing draw/resource facade when the grouped draw
contract was already the real owner.

That has improved slightly again at the tiny edge too: even the old
`clearToThemeBackground()` renderer-root forward is gone. The one remaining
caller (font sample) now talks to `renderer_draw_host.zig` directly instead of
asking the renderer root to proxy that draw-contract verb.

That has improved slightly again on the terminal draw side too: terminal rect
and glyph submission no longer live as public methods on `Renderer`. Terminal
text/grid/presentation code now routes through `renderer_terminal_draw_host.zig`
instead, which makes that contract read like one explicit host seam rather
than one more renderer-root facade over backend draw ops.

That has improved slightly again inside the backend dispatch contract too: the
old mixed `backend_ops.draw` bucket has now been split into smaller groups with
clearer meaning:

- `clip`
- `terminal_draw`
- `image_draw`
- `surface`

That is more honest than one draw grab bag mixing clip state, terminal cell
primitives, persistent/raw image operations, and generic surface submission.

That has improved slightly again on the leftovers too: the old backend
`clearThemeBackground` hook is gone. It only existed as a special-case clear
path for one caller, and plain `drawRect(...)` semantics were the more honest
contract path.

That has improved slightly again on the surface-submission side too: the
`surface` contract now terminates in dedicated backend modules
(`gl_surface_runtime.zig` / `metal_surface_runtime.zig`) instead of routing
back into the larger backend files. This does not erase the remaining
immediate-vs-queued semantic contradiction, but it makes that ownership seam
more explicit and therefore easier to cut honestly.

The remaining truth is now plain:

- OpenGL surface submission still means "interpret this draw now"
- Metal surface submission still means "append this draw now, replay it at
  frame submit"

That is the loudest remaining semantic contradiction in the backend contract.
It is no longer hidden by renderer-root facade noise or mixed backend dispatch
buckets, which means the next real cut must either:

- make that semantic split explicit as backend policy under one product-level
  record/submit contract
- or reduce the split directly without repeating the earlier broken "delay all
  GL surface draws" attempt

Any further structural cleanup that does not address that truth is secondary.

One important boundary is clearer now too: `SurfaceDraw` is no longer allowed
to quietly mean "generic draw anything." Recent terminal fixes proved that
terminal row backgrounds, cursor/composition cells, and other terminal-grid
semantics need their own dedicated seams when they depend on terminal batching
or per-cell ordering truth. The current contract should therefore be read as:

- `SurfaceDraw`: generic UI/image/presentable-style recorded draws
- terminal draw contracts: terminal-grid/cell batching truth
- presentable contract: retained/direct present lifecycle truth

If a caller needs tighter phase ordering than "preserved among recorded surface
draws inside the backend's surface phase," that caller is on the wrong seam.

That has improved slightly again on the terminal overlay side too: selection
fills, hover underlines, and rect-style cursor overlay pieces no longer use the
generic `drawRect(...)` / `drawRectF(...)` surface path. They now route through
the terminal rect path with an explicit overlay batch bracket, which is a
better fit for the truth that those draws are terminal-phase semantics, not
generic UI surface draws.

That has improved slightly again on the clip side too: clip dispatch now
terminates in dedicated backend runtimes (`gl_clip_runtime.zig` /
`metal_clip_runtime.zig`) instead of remaining one more inline backend-specific
 switch in the shared dispatch module. This is a small structural cleanup, but
 it helps isolate the real remaining backend contradiction: surface submission
 semantics still differ materially.

That has improved slightly again on backend ownership too: backend dispatch no
longer terminates presentable operations back into the large generic backend
files. Dedicated backend presentable modules now own that seam directly:

- `src/ui/renderer/gl_presentable_runtime.zig`
- `src/ui/renderer/metal_presentable_runtime.zig`

This is still not full presentable parity, but it is a more honest ownership
shape than keeping presentable lifecycle inline in `gl_backend.zig` and
`metal_backend.zig` as one more mixed concern.

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

That has improved slightly again on the Metal-only helper surface too: unused
`app_shell` forwards for macOS Metal host prep, smoke frames, and atlas
diagnostics were **removed**, and atlas preview/upload probe entrypoints live on
`Renderer` rather than as Shell methods. Remaining Metal-only mechanics still
live under `metal_backend` / `macos_host` where appropriate, without duplicating
that surface on `app_shell`.

That has improved slightly again on the primitive draw/clip boundary too: the
renderer root no longer owns private Metal queue-assembly helpers for solid
rects or atlas samples, and it no longer owns the OpenGL scissor
implementation directly either. Primitive solid-rect submission, terminal
glyph/rect submission, and backend clip application now route through
`gl_backend.zig` / `metal_backend.zig` instead of `renderer.zig` acting as the
implementation center for those backend-specific mechanics.

That has improved slightly again on frame host bookkeeping too: the shared
frame prelude/epilogue state reset and submission finalization now live in
`renderer_frame_host.zig` instead of being duplicated between
`Renderer.beginFrame()` and both backend frame runtimes. This is real lifecycle
cleanup, but it is still only host-shape progress; backend frame assembly and
submission ownership remain materially different between OpenGL and Metal.

That has improved slightly again at the backend dispatch boundary too: the
GL/Metal backend ops table and switchboard now live in
`backend_dispatch.zig` instead of `renderer.zig` carrying the full backend
routing block inline. This makes the renderer root less obviously the dispatch
center, even though backend lifecycle ownership is still not closed.

That has improved slightly again on contract shape too: the backend switchboard
now reads as grouped `runtime`, `frame`, `presentable`, and `draw`
subcontracts instead of one flat `backend_ops` blob. This is still the same
dispatch center, but it makes the remaining contradictions more honest and
reduces the renderer-root “single backend god object” surface.

That has improved slightly again on renderer-root state honesty too: the
renderer no longer stores a separate `backend` label field when the selected
backend contract/runtime already carries that truth. This is small, but it
removes one more dead “backend enum on the root” relic from the shared host.

That has improved slightly again on draw-payload neutrality too: shared raw
image draws no longer carry a `.opengl` / `.metal` texture union in
`surface_draw.zig`. The payload now carries one opaque `GpuImageRef`
(`handle + width + height`), while backend-specific interpretation and
clone/release logic terminate inside `gl_backend.zig` / `metal_backend.zig`.
This does not finish the whole draw-submission contradiction, but it removes
one direct “future `.vulkan` arm” pressure point from the shared payload.

That has improved slightly again on the caller-facing image surface too:
persistent image upload/draw APIs used by kitty images and shell icons no
longer expose `types.Texture` as a public renderer contract. Those callers now
use `GpuImageRef` plus `drawPersistentImage(...)`, so the shared surface no
longer teaches product code that a persisted image is “really a GL texture
struct.”

That has improved slightly again on root-surface sprawl too: the old public
`Renderer.drawTexture(...)` method is gone. Texture drawing remains an internal
font/glyph/atlas primitive, but product-level callers no longer get a generic
GL-shaped texture draw verb by default.

That has improved slightly again on frame lifecycle termination too:
backend frame begin/submit and screenshot entrypoints now live directly on
`gl_backend.zig` / `metal_backend.zig`, and the old
`opengl_frame_runtime.zig` / `metal_frame_runtime.zig` wrappers are gone.
This is a real ownership improvement because per-backend frame mechanics now
terminate in the backend modules themselves instead of one more intermediate
runtime layer.

That has improved slightly again on the Metal helper surface too: queue and
cell/text append helpers that are now only used internally by
`metal_backend.zig` are no longer exported as public backend surface. That
reduces one more fake API layer where implementation-detail queue mechanics
looked like supported contract.

That has improved slightly again on the Metal draw path too: backend-internal
solid/atlas/raw-image queue helpers now append to Metal queue storage directly
instead of bouncing back through the shared `backend_ops.surface.recordSurfaceDraw`
surface as if they were neutral product-level callers.

That has improved slightly again on the caller-facing shared renderer surface
too: `Renderer` no longer exports `recordSurfaceDraw(...)` as a public method.
That does not solve the deeper submission-semantics split yet, but it removes
one more fake-neutral verb from the root surface seen by product code.

That has improved slightly again on the shared surface edge too: the common
surface-record helper for logical solid fills now lives in
`renderer_surface_host.zig` instead of `renderer.zig`, and terminal
presentation and other direct renderer callers now use that host seam
directly instead of keeping dedicated `Renderer.drawRect(...)` /
`Renderer.drawRectF(...)` facades alive. That is a more honest ownership
shape than leaving that backend-facing seam as one more private root helper.
The same is now true for rect outlines: `Shell` and other callers use
`renderer_surface_host.zig` directly instead of keeping `Renderer.drawRectOutline(...)`
alive as another root solid-fill convenience surface.

That has improved slightly again on root-surface sprawl too: dead convenience
capability verbs with no live callers are being removed from `Renderer`
instead of left behind as speculative shared API.

That has improved slightly again on the OpenGL lifecycle side too: the
OpenGL scene-target and presentable runtimes no longer call GL-only
render-target helpers through `Renderer`. They now talk to `gl_backend`
directly for render-target begin/ensure/destroy, which removes another
pure-OpenGL helper surface from the renderer root.

That has improved slightly again on the OpenGL target-binding side too: the
OpenGL frame, scene-target, and presentable runtimes now bind the default
target through `gl_backend` directly instead of going through one more
OpenGL-only helper on `Renderer`.

That has improved slightly again on the shared/widget side too: terminal
presentation debug sampling no longer reaches into
`renderer.opengl_runtime.presentable_targets.terminal` directly. It now asks
the renderer presentable contract for backend-neutral presentable info instead
of peeking into OpenGL-owned storage from shared terminal code.

That has improved slightly again at the renderer root itself: the live
renderer instance now selects one explicit backend ops table at init time and
routes frame, presentable, screenshot, capability, clip, and primitive draw
behavior through that table instead of repeating backend switches across the
root for each of those operations.

That has improved slightly again on the bootstrap side too: startup window
binding, startup backend configuration, and startup smoke execution now route
through a small backend bootstrap ops table instead of `renderer.zig`
carrying a separate cluster of ad hoc backend startup switches.

That has improved slightly again on dead contract cleanup too: the unused
renderer-root `deinitPresentables()` seam and its matching backend ops entry
are gone. Presentable teardown now only exists where it is actually needed, in
backend-owned runtime cleanup.

That has improved slightly again on the widget-side contract too: Kitty image
handling no longer decides between persistent GL textures and direct Metal raw
image draws by branching on `renderer.backend`. The renderer capability model
now publishes an explicit Kitty image mode, and the terminal Kitty widget
follows that contract instead of backend labels.

That has improved slightly again on the immediate-draw boundary too: Kitty
direct raw-image placement, terminal Metal text fallbacks, `text_runtime`
Metal fallbacks, font-sample Metal preview, and the macOS Metal text diagnostic
no longer import `metal_backend.zig` just to enqueue those draws. They call
`Renderer` methods wired through `BackendOps` instead, and OpenGL implements
those ops as honest no-ops.

That has improved slightly again on the persistent image-texture side too: the
renderer root no longer exposes `createTextureFromRgb` /
`createTextureFromRgba` as GL-only helper surfaces. Persistent texture
creation and destruction now route through backend ops, so shell icons and the
Kitty persistent-texture path ask the backend contract for a linear persistent
image texture instead of depending on a raw OpenGL-only renderer helper.

That has improved slightly again on the font-atlas hook seam too: font
initialization no longer first checks `renderer.backend != .metal` before
asking for Metal atlas upload hooks. The Metal backend helper now answers the
real question directly.

That has improved slightly again on shared init policy too: the old
OpenGL-only swap-interval policy tweak no longer lives as a raw
`renderer.backend == .opengl` branch in `renderer.zig`. That runtime policy
now routes through backend ops as backend-owned behavior instead of leaving one
more backend-special case in shared initialization.

That has improved slightly again on the Metal frame side too: the shared
frame prelude no longer clears the Metal queued draw list before backend
dispatch. That queue reset now lives under `metal_frame_runtime.zig`, which is
closer to the rule that shared frame entry should not directly mutate
backend-native runtime state.

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
`gl_backend.zig`, leaving the shared scene runtime closer to shared
present-trace semantics instead of mixed shared/GL ownership.

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

That has improved slightly again at the renderer boundary too: the repeated
live-instance backend dispatch switches for frame/presentable/capability and
primitive operations are now gone from `renderer.zig`, replaced by one backend
ops table selected at renderer init. The remaining root-level backend
switching is now mostly ops-table selection and backend-profile gating rather
than per-call renderer behavior.

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
wrapper. The small caller-facing facade now lives in
`src/ui/renderer/renderer_presentable_host.zig` instead of being spread between
another wrapper layer and the renderer root.

This has improved slightly: the presentable target type now lives in
`src/ui/renderer/gl_presentable_target.zig` instead of being owned directly by the
GL backend, so the module name reflects GL-shaped retained storage.

The shared runtime surface has improved too:

- the main shared retained-target API now uses presentable-oriented names
- callers no longer have to speak in GL-era `ensureSurface` /
  `beginSurface` / `drawSurface` vocabulary
- the shared presentable contract types now live in
  `src/ui/renderer/presentable_contract.zig`
- the OpenGL presentable mechanics now live directly in
  `src/ui/renderer/gl_backend.zig` instead of inside the shared presentable
  contract module or another backend-local wrapper
- the renderer-owned presentable facade now routes through backend-owned
  presentable entrypoints on the OpenGL and Metal modules
- presentable trace/editor-surface bookkeeping now also routes through
  `src/ui/renderer/renderer_presentable_host.zig` instead of GL and Metal
  each deciding that lifecycle bookkeeping inline

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
- `src/ui/renderer/gl_backend.zig`
  - now also owns the actual GL presentable lifecycle directly instead of
    routing that behavior through a second backend-local wrapper module
- `src/ui/renderer/renderer_presentable_host.zig`
  - now owns the small neutral presentable facade, but presentable lifecycle
    truth is still not backend-neutral
- `src/ui/renderer/renderer_frame_host.zig`
  - now owns the small shared frame facade, but frame lifecycle ownership is
    still not fully backend-neutral
- `src/ui/renderer/backend_dispatch.zig`
  - now owns the backend switchboard, but backend lifecycle ownership is still
    not closed
- `src/ui/renderer/gl_backend.zig`
  - now owns OpenGL frame lifecycle directly, but the resulting lifecycle
    semantics are still not equivalent to Metal
- `src/ui/renderer/metal_backend.zig`
  - now owns Metal frame lifecycle directly, but the resulting lifecycle
    semantics are still not equivalent to OpenGL
- `src/ui/renderer/present_trace_runtime.zig`
  - now mostly trace/present bookkeeping, but is still part of the shared
    frame lifecycle surface
- `src/ui/renderer/gl_backend.zig`
  - now also owns the OpenGL scene-target mechanics directly instead of
    routing them through a second backend-local wrapper module

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

- the presentable target type now lives in `src/ui/renderer/gl_presentable_target.zig`
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

## Defect Class Note (2026-04-06)

One concrete class now confirmed by live behavior: stateful overlay
invalidation drift between backend present/reuse paths. The observed symptom was
stale terminal cursor presentation on Metal when fast snapshot-present reuse
skipped redraw even though cursor state changed. The structural fix now tracks
cursor/overlay state deltas in presentation cache/reuse decisions, but this
class should be treated as an explicit scrutiny target when comparing OpenGL
and Metal lifecycle equivalence after the current cut order is complete.

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

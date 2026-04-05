# Renderer Backend Abstraction Queue

## Scope

Turn OpenGL and Metal into the two reference implementations for a
best-in-class renderer backend abstraction.

This queue is no longer just renderer modularization maintenance. It is the
active execution lane for backend contract quality.

## Constraints

- OpenGL and Metal must converge toward one backend-neutral contract.
- Do not add a Vulkan story until the shared contract is strong enough that the
  implementation work is obvious.
- Keep OS/native-host concerns separate from pure backend contract work.
- Prefer reviewable backend-contract cuts over broad cleanup passes.

## Entry Points

- `app_architecture/ui/RENDER_BACKEND_CONTRACT.md`
- `app_architecture/ui/RENDER_BACKEND_CURRENT_STATE.md`
- `docs/research/RENDER_BACKEND_REFERENCE_SCAN_2026-04-05.md`
- `src/ui/renderer.zig`
- `src/ui/renderer/capability_contract.zig`
- `src/ui/renderer/gl_backend.zig`
- `src/ui/renderer/metal_backend.zig`
- `src/ui/renderer/present_trace_runtime.zig`

## Status

- [x] OpenGL and Metal both exist as real renderer lanes
- [x] Capability truth is materially better than backend-label theater
- [~] Shared draw contract has started moving out of Metal ownership
- [ ] Shared draw/present contracts are still not backend-neutral end-to-end
- [~] Shared presentable target type has started moving out of GL ownership
- [ ] Shared retained/presentable ownership is still not backend-neutral
- [ ] `Renderer` still carries backend-native implementation state

Status note, 2026-04-05:

- This is now the main renderer roadmap.
- The active standard is no longer "Metal works well enough."
- The active standard is "OpenGL and Metal prove one strong backend contract."

## Campaign Goal

```mermaid
flowchart LR
    Contract["Shared Backend Contract"] --> GL["OpenGL Reference Impl"]
    Contract --> Metal["Metal Reference Impl"]
    Contract --> Vulkan["Future Vulkan Impl"]

    Renderer["Renderer Host / Product Semantics"] --> Contract
    Widgets["Widgets / Scene Publishers"] --> Renderer
    Host["Native Host / Windowing"] --> Renderer
```

## Immediate Contradictions

- [ ] Remove backend-native draw payloads from shared renderer state.
- [ ] Replace GL-native retained target types in shared runtime code with a
  backend-neutral presentable contract.
- [ ] Move backend frame lifecycle dispatch behind a backend-owned seam instead
  of leaving dispatch in shared frame runtime code.
- [ ] Shrink backend-specific convenience APIs on `Renderer` once stronger
  neutral contracts exist.

## Execution Order

1. Define a shared surface draw contract outside `metal_backend.zig`, then make
   both GL and Metal consume it.
2. Define a shared presentable contract outside `gl_backend.zig`, then move
   retained/direct/snapshot behavior behind it.
3. Move backend frame begin/submit lifecycle into backend-owned dispatch
   surfaces instead of keeping those code paths inline in `Renderer`.
4. Delete backend-specific public renderer verbs after the neutral seams are
   real and callers no longer need backend-shaped requests.

Progress note, 2026-04-05:

- `src/ui/renderer/surface_draw.zig` now owns the shared draw payload types.
- Metal no longer owns the `SurfaceDraw` union definition.
- `src/ui/renderer/capability_contract.zig` now owns the capability enums and
  struct, and `gl_backend.zig` / `metal_backend.zig` now report backend
  capability truth through that shared contract instead of `Renderer`
  hardcoding every backend capability shape itself.
- The next step is to push real submission and caller flow through that shared
  contract instead of leaving Metal-specific renderer verbs as the practical
  API.
- `src/ui/renderer/presentable_target.zig` now owns the presentable target
  type, so shared runtime code no longer imports a GL-owned target type
  directly.
- `src/ui/renderer/presentable_contract.zig` now owns the shared presentable
  contract types instead of leaving them inside the shared runtime wrapper.
- the shared runtime API now uses presentable-oriented names instead of the old
  retained-surface verbs.
- the actual GL presentable mechanics now live directly under
  `src/ui/renderer/gl_backend.zig` instead of inside the shared presentable
  contract module.
- the neutral presentable facade no longer lives in a separate shared runtime
  wrapper; `Renderer` now owns that small dispatch surface directly and routes
  through backend-owned presentable entrypoints on the OpenGL and Metal
  modules.
- The next presentable step is lifecycle/behavior ownership, not just storage
  relocation.
- backend-specific frame begin/submit bodies now live in dedicated frame
  runtime modules instead of staying inline in `src/ui/renderer.zig`.
- the renderer-root wrapper methods are gone too; `Renderer.beginFrame()` /
  `Renderer.submitFrame()` now form the small top-level frame facade above the
  backend frame runtime modules.
- OpenGL-only scene target refresh/prep has moved out of the old shared frame
  wrapper shape and into `opengl_frame_runtime.zig`.
- The remaining OpenGL scene-target mechanics now also live directly under
  `src/ui/renderer/gl_backend.zig` instead of `src/ui/renderer/present_trace_runtime.zig`,
  which leaves the shared scene runtime closer to trace/present bookkeeping
  than GL composition ownership.
- Metal runtime storage on `Renderer` is now bundled under one
  `metal_runtime` state object instead of being scattered across separate peer
  fields.
- OpenGL runtime storage on `Renderer` is now bundled under one
  `opengl_runtime` state object instead of being scattered across separate peer
  fields.
- backend teardown now routes through `gl_backend.zig` and `metal_backend.zig`
  instead of `Renderer.deinit()` spelling out both cleanup paths inline.
- backend startup/init and startup-smoke probing now also route through
  `gl_backend.zig` and `metal_backend.zig` instead of `Renderer.init()` and
  `runStartupBackendSmoke()` spelling out both boot paths inline.
- the extra shared backend-frame dispatch wrapper is gone; the renderer facade
  now does the small shared bookkeeping directly and routes straight to
  backend-owned `beginFrame` / `submitFrame` entrypoints on the OpenGL and
  Metal modules.
- Metal-only queued-surface cleanup and diagnostic-font cleanup now route
  through `metal_backend.zig` instead of living as renderer-root helper
  methods.
- Shared draw/text code now routes several OpenGL-specific operations through
  `gl_backend.zig` helpers instead of directly reaching into
  `renderer.opengl_runtime` for white-brush access, batch binding, VBO growth,
  texture-kind uniform updates, and text-render uniform sync.
- Shared Metal-facing renderer code now routes runtime-context lookup,
  queued-surface append, and queued-surface count through `metal_backend.zig`
  helpers instead of open-coding those `renderer.metal_runtime` storage
  details.
- Renderer/font call sites that only need Metal atlas hooks, glyph-atlas
  readiness, or snapshot-presentable status now also route through
  `metal_backend.zig` helpers instead of manually unwrapping the backend
  context.
- Sampled-text and terminal-cell-run queue handoffs now also route through
  `metal_backend.zig` helpers instead of the renderer root passing the Metal
  queued-surface list directly into those builders.
- The Metal frame runtime now routes current-frame slot access and queued
  surface replay through `metal_backend.zig` helpers instead of directly
  mutating and iterating `renderer.metal_runtime` storage fields.
- The Metal diagnostic-font cache/ensure path now also routes through
  `metal_backend.zig` instead of living as renderer-root-owned backend logic.
- Metal snapshot-presentable draw and raw-image enqueue paths now also route
  through `metal_backend.zig` helpers instead of the renderer root assembling
  those backend draw requests inline.
- The one-off Metal smoke frame and basic Metal `SurfaceDraw` variant
  packaging now also route through `metal_backend.zig` helpers instead of
  `Renderer` spelling out those backend-specific assembly details itself.
- The Metal terminal snapshot-presentable path now participates in the shared
  presentable contract through `metal_backend.zig` entrypoints instead of the
  terminal presentation runtime carrying a separate Metal-only bypass branch
  for availability, ensure, draw, and scroll.
- The tiny terminal-specific presentable wrapper module is gone too:
  `terminal_widget_presentation_runtime.zig` now talks to the renderer
  presentable contract directly instead of bouncing through one more
  forwarding layer.
- Metal glyph-atlas readiness, atlas preview source, and atlas-upload
  diagnostics are **`Renderer` methods** that delegate to
  `metal_backend.zig`; **`Shell` does not re-export or forward** them, so
  diagnostics and smoke runtimes call `rendererPtr()` instead of growing
  another app-shell seam.
- The old Metal-only `Renderer` convenience verbs for sampled text,
  terminal-cell runs, raw image draws, and terminal snapshot draws are now
  gone from `src/ui/renderer.zig`; live callers route those operations
  through `metal_backend.zig` directly instead.
- Metal atlas preview/debug state now also lives inside
  `src/ui/renderer/metal_runtime_state.zig` as part of the bundled Metal
  runtime state instead of as a separate backend-specific field on
  `Renderer`.
- The OpenGL retained-presentable cache now also lives under
  `src/ui/renderer/opengl_runtime_state.zig` instead of as a direct
  `Renderer` field, which makes the GL-owned retained-presentable model less
  obviously rooted in shared renderer storage.
- The offscreen scene-target contract/state now also lives in
  `src/ui/renderer/scene_target_state.zig` and is stored under
  `opengl_runtime.scene_target` instead of as a direct `Renderer` field,
  which makes the current OpenGL-owned scene-target model less obviously
  shared-state-by-default.
- The remaining renderer-root scene-target invalidation merges and Metal atlas
  preview lookup now also route through `gl_backend.zig` / `metal_backend.zig`
  instead of `Renderer` directly reaching into those backend runtime storage
  slots.
- Unused Shell forwards for macOS Metal attachment prep, smoke frames, and
  atlas diagnostics were removed; the live atlas-preview/upload probe surface
  stays on **`Renderer`** with `metal_text_diagnostic_runtime.previewPlacement`
  taking **`UiGeometryContext`** so the helper does not import `renderer.zig`.
- The renderer root no longer owns private Metal queue-assembly helpers for
  solid rects / atlas samples or the OpenGL scissor implementation directly.
  Primitive solid-rect submission, terminal glyph/rect submission, theme
  background clear, and clip application now route through `gl_backend.zig` /
  `metal_backend.zig` instead of `renderer.zig` acting as the implementation
  center for those backend-specific mechanics.
- The OpenGL scene-target and presentable runtimes now also call
  `gl_backend.zig` directly for render-target begin/ensure/destroy instead of
  bouncing through GL-only helper methods on `Renderer`, which removes another
  pure-OpenGL helper surface from the renderer root.
- The shared frame prelude no longer clears the Metal queued draw list before
  backend dispatch; that queue reset now lives in
  `src/ui/renderer/metal_frame_runtime.zig` instead of shared renderer
  lifecycle code mutating Metal runtime state directly.
- The OpenGL frame, scene-target, and presentable runtimes now also bind the
  default target through `gl_backend.zig` directly instead of bouncing through
  another OpenGL-only helper on `Renderer`.
- Terminal presentation debug sampling now also uses renderer presentable
  contract info instead of reaching into
  `renderer.opengl_runtime.presentable_targets.terminal` from shared terminal
  code.
- The live renderer instance now selects one explicit backend ops table at
  init time and routes frame, presentable, screenshot, capability, clip, and
  primitive draw behavior through that table instead of repeating those
  backend switches across `src/ui/renderer.zig`.
- Startup window binding, backend configuration, and startup smoke execution
  now also route through a small backend bootstrap ops table instead of
  leaving one more cluster of backend startup switches in `src/ui/renderer.zig`.
- The unused renderer-root `deinitPresentables()` seam and its backend ops
  entry are gone too; presentable teardown now only exists in backend-owned
  runtime cleanup where it is actually used.
- Kitty image handling now uses an explicit renderer capability mode instead of
  branching on `renderer.backend` in the widget layer to decide between
  persistent textures and direct raw-image draws.
- Persistent image texture creation/destruction no longer exists as a GL-only
  helper surface on `Renderer`; that lifecycle now routes through backend ops,
  and the remaining live callers (Kitty persistent textures and terminal shell
  icons) now ask for backend-owned persistent textures instead of OpenGL-only
  root helpers.
- Font atlas upload hook selection no longer does a raw `renderer.backend`
  check before asking for Metal atlas hooks; the backend helper now answers
  that capability question directly.
- `ui/font_sample_view.zig` no longer imports `metal_backend` for
  `TerminalFont` atlas hooks; it uses
  `Renderer.terminalFontAtlasUploadHooksForRenderer()` like other UI callers
  that must stay backend-shaped without reaching into `metal_backend.zig`.
- `renderer/font_manager.zig` also uses that renderer facade for cached font
  init instead of importing `metal_backend` for the same hook query.
- `ui/glyph_cache.zig` no longer imports `gl_backend`; OpenGL batch bind and
  texture-kind uniform for the vertex-stream flush go through
  `draw_ops.bindBatchPipelineForVertexStream` /
  `draw_ops.setTextureKindForVertexStream` (shared with the terminal batch
  flush path in `draw_ops.zig`).
- The old OpenGL-only init-time swap-interval policy tweak now also routes
  through backend ops instead of living as one more raw backend branch in
  `renderer.zig`.
- Direct OpenGL frame submit and direct window screenshot-readback now also
  live under `src/ui/renderer/opengl_frame_runtime.zig` /
  `src/ui/renderer/gl_backend.zig` instead of
  `src/ui/renderer/present_trace_runtime.zig` carrying that OpenGL-specific
  behavior inside a shared runtime file.
- The terminal presentable end path now goes back through the shared
  presentable contract instead of bypassing it to call a scene-runtime restore
  helper directly, and the OpenGL composition-target restore logic now lives
  with the OpenGL presentable implementation instead of shared scene runtime.
- OpenGL presentable and scene-target teardown now also lives under
  `gl_backend.deinitRuntime()` instead of `Renderer.deinit()` explicitly
  orchestrating that cleanup first.
- The next lifecycle step is to reduce shared-runtime ownership of dispatch and
  backend-native frame state, not just move code blocks around.
- The macOS OpenGL editor retained-presentable bypass in
  `editor_widget_draw.zig` no longer keys off `renderer.backend` + OS tags;
  `capability_contract.RendererCapabilities` now exposes
  `editor_presentable_cache_compatible`, and OpenGL reports false on macOS
  full UI while Metal leaves it enabled so widget code stays capability-shaped.
- Metal-only immediate draw helpers (raw RGB/RGBA image enqueue, sampled text,
  terminal cell runs, atlas sample char) now live on the shared `BackendOps`
  table with OpenGL no-op stubs; `text_runtime`, Kitty placement, terminal
  metal fallbacks, font sample view, and macOS text diagnostic call
  `Renderer` methods instead of importing `metal_backend.zig` for those paths.

## Live Contradiction Centers

- `src/ui/renderer.zig`
  - still owns backend-native state
- `src/ui/renderer/metal_backend.zig`
  - still owns the only live consumer of the shared surface-draw queue
- `src/ui/renderer/present_trace_runtime.zig`
  - now mostly handles shared trace/present bookkeeping, but still
    participates in the shared frame lifecycle surface
- `src/ui/renderer/gl_backend.zig`
  - now owns the OpenGL scene-target mechanics directly instead of routing
    them through another backend-local wrapper module
- `src/ui/renderer.zig`
  - also owns the small neutral presentable facade directly, so renderer-root
    dispatch is still part of the presentable contract surface
- `src/ui/renderer/gl_backend.zig`
  - now owns the concrete GL presentable mechanics directly instead of routing
    through a backend-local wrapper module

## Remaining Work

- [ ] Write and maintain the target contract and current-state contract as the
  two active backend architecture references.
- [ ] Use OpenGL and Metal as the proof pair for every structural backend cut.
- [ ] Keep terminal/text execution work subordinate to the shared contract
  instead of letting it redefine the backend architecture by momentum.

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
- `src/ui/renderer/frame_runtime.zig`
- `src/ui/renderer/gl_backend.zig`
- `src/ui/renderer/metal_backend.zig`
- `src/ui/renderer/scene_frame_runtime.zig`
- `src/ui/renderer/presentable_targets_runtime.zig`
- `src/ui/renderer/opengl_presentable_runtime.zig`

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
- the actual GL presentable mechanics now live in
  `src/ui/renderer/opengl_presentable_runtime.zig` instead of inside the
  shared presentable contract module.
- the shared presentable runtime now routes through backend-owned presentable
  entrypoints on the OpenGL and Metal modules instead of importing the OpenGL
  implementation directly.
- The next presentable step is lifecycle/behavior ownership, not just storage
  relocation.
- backend-specific frame begin/submit bodies now live in dedicated frame
  runtime modules instead of staying inline in `src/ui/renderer.zig`.
- the renderer-root wrapper methods are gone too; `frame_runtime.zig`
  now owns the top-level shared frame lifecycle entrypoint above backend frame
  runtime modules.
- OpenGL-only scene target refresh/prep has moved out of `frame_runtime.zig`
  and into `opengl_frame_runtime.zig`.
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
- the extra shared backend-frame dispatch wrapper is gone; `frame_runtime.zig`
  now does shared bookkeeping and routes directly to backend-owned
  `beginFrame` / `submitFrame` entrypoints on the OpenGL and Metal modules.
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
  presentable contract through `metal_backend.zig` entrypoints instead of
  `terminal_widget_presentation_target_runtime.zig` carrying a separate
  Metal-only bypass branch for availability, ensure, draw, and scroll.
- The next lifecycle step is to reduce shared-runtime ownership of dispatch and
  backend-native frame state, not just move code blocks around.

## Live Contradiction Centers

- `src/ui/renderer.zig`
  - still owns backend-native state
- `src/ui/renderer/metal_backend.zig`
  - still owns the only live consumer of the shared surface-draw queue
- `src/ui/renderer/frame_runtime.zig`
  - still acts as the shared frame lifecycle entrypoint above backend dispatch
- `src/ui/renderer/scene_frame_runtime.zig`
  - still participates in the shared frame lifecycle surface
- `src/ui/renderer/presentable_targets_runtime.zig`
  - still routes only to the OpenGL presentable model
- `src/ui/renderer/opengl_presentable_runtime.zig`
  - now owns the concrete GL presentable mechanics that used to live under the
    shared contract module

## Remaining Work

- [ ] Write and maintain the target contract and current-state contract as the
  two active backend architecture references.
- [ ] Use OpenGL and Metal as the proof pair for every structural backend cut.
- [ ] Keep terminal/text execution work subordinate to the shared contract
  instead of letting it redefine the backend architecture by momentum.

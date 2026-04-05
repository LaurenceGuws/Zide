# Renderer Backend Contract

Purpose: define the renderer/backend abstraction Zide is actually trying to
build, using OpenGL and Metal as the two reference implementations.

This is current architecture authority for backend abstraction quality.

## Why This Exists

Zide no longer needs a vague "multiple backends someday" story.

It needs a contract strong enough that:

- OpenGL can remain the mature baseline
- Metal can become a first-class peer instead of a special side lane
- Vulkan can be added later without reopening the renderer root as the real
  backend implementation center

The standard is not "can two backends coexist."

The standard is:

- do two backends prove one clean contract

## Product Standard

The backend contract must make OpenGL and Metal read like two implementations
of the same rendering system.

That means:

- shared renderer code owns product semantics
- backend code owns GPU/frame/surface mechanics
- backend choice changes implementation, not architecture

The backend contract is only good enough when adding Vulkan would mainly mean:

- implement the same frame lifecycle
- implement the same surface draw contract
- implement the same presentable/retained target contract
- implement the same atlas/image upload contract

It must not require:

- adding new Vulkan-specific state to `Renderer`
- adding Vulkan-native draw queues to shared renderer state
- teaching widget/runtime code about Vulkan-only present rules
- reinterpreting capabilities because the shared draw contract was never real

## Contract Layers

The backend abstraction should be read in this order:

1. renderer-owned product semantics
2. backend-neutral draw/present contracts
3. backend-specific implementation details

### 1. Renderer-Owned Product Semantics

The shared renderer owns:

- composition planning
- clip ownership
- retained/presentable intent
- screenshot intent
- text/image/surface submission intent
- capability reporting

The shared renderer does not own:

- API-specific frame handles
- API-specific texture handles
- API-specific command encoders
- per-backend draw unions

### 2. Backend-Neutral Contracts

The shared backend contract must define at least these seams:

#### Frame lifecycle

- `prepareFrame`
- `beginFrame`
- `submitFrame`
- `abandonFrame`
- optional readback/capture hooks

#### Surface draw contract

One backend-neutral draw list that can express:

- solid rects
- atlas samples
- raw images
- presentable/snapshot blits

This list must not embed Metal-native or GL-native draw structs in shared
renderer state.

**Submission shape today:** the shared union lives in `surface_draw.zig`
(`SurfaceDraw`). `Renderer.enqueueSurfaceDraw` routes through `BackendOps`:
Metal appends to the end-of-frame replay queue; OpenGL currently interprets
`.solid` immediately via `gl_backend.submitSurfaceDrawImmediate` (raster-space
`dest_rect` converted back to logical coordinates to match how Metal enqueues
those draws). `.atlas` / `.raw_image` are not yet interpreted on the OpenGL
path through this entrypoint; growing parity there is deliberate follow-up, not
a second hidden queue.

#### Presentable contract

One backend-neutral presentable surface contract that can express:

- allocate/ensure
- begin/end update
- direct draw or cached snapshot present
- snapshot shift/scroll
- availability/reuse truth

Retained targets, direct snapshot caches, and future Vulkan surfaces should all
fit under this seam without shared code importing a backend-specific surface
type.

#### Atlas and image contract

One backend-neutral resource story for:

- glyph atlas ownership
- atlas sample submission
- raw image upload/draw
- screenshot/readback capture

### 3. Backend-Specific Implementation

Backends own:

- API devices/contexts
- API frame handles
- API texture/resource handles
- shader/pipeline/sampler objects
- platform/API attachment details

Those details should terminate inside backend modules or backend-owned runtime
helpers, not inside the renderer root.

## Required Design Rules

1. `Renderer` must not store backend-native draw arrays.
2. `Renderer` must not store more than one backend’s API frame object at a
   time as explicit peer fields.
3. Shared runtime modules must not depend on GL-native retained target types.
4. Capabilities must describe behavior, not substitute for missing contracts.
5. The "current implementation truth" may stay uneven, but the contract
   vocabulary must stay backend-neutral.

## Reference Pressure

The strongest current pressure for this contract is:

- Ghostty for "renderer host is not the backend implementation center"
- Zed/GPUI for "multiple backend implementations can satisfy one higher-level
  renderer contract"

Current reference scan:

- `docs/research/RENDER_BACKEND_REFERENCE_SCAN_2026-04-05.md`

## Immediate Consequence

The next renderer/backend work should be judged against one question:

- does this change make OpenGL and Metal look more like two reference
  implementations of one contract

If not, it is probably backend momentum, not backend architecture.

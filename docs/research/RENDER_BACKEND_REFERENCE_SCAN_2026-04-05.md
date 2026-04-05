# Renderer Backend Reference Scan

Date: 2026-04-05

## Purpose

Start a renderer-backend architecture campaign with explicit external pressure
instead of only repo-local intuition.

This writeup is not the architecture authority. It is the reference scan behind
the active backend-contract docs:

- `app_architecture/ui/RENDER_BACKEND_CONTRACT.md`
- `app_architecture/ui/RENDER_BACKEND_CURRENT_STATE.md`

## Reference Set

### Ghostty

Strong pressure for:

- renderer host not being the real backend center
- native-host UI/view ownership staying separate from backend ownership
- backend-specific machinery terminating in backend owners
- terminal surface composition living under a surface/view owner instead of a
  giant shared renderer root

Relevant repo path pressure:

- `dev_references/terminals/ghostty/macos/Sources/Helpers/MetalView.swift`
- `dev_references/terminals/ghostty/macos/Sources/Ghostty/Surface View/SurfaceView.swift`

Concrete takeaways from those files:

- SwiftUI/AppKit view composition and focus/lifecycle concerns stay in the
  surface/view layer.
- The Metal view is a small host wrapper, not the place where higher-level
  terminal composition vocabulary lives.
- Terminal surface concerns such as overlays, focus, unhealthy-state handling,
  and geometry ownership stay attached to the terminal surface owner instead of
  collapsing into one renderer root.

### Zed / GPUI

Strong pressure for:

- one higher-level renderer model with multiple backend implementations
- platform/backend-specific renderer implementations living under backend-owned
  crates rather than in one giant shared renderer root
- wgpu/Metal platform implementations satisfying one scene/batching model

Concrete files inspected:

- `dev_references/editors/zed/crates/gpui_wgpu/src/wgpu_renderer.rs`
- `dev_references/editors/zed/crates/gpui_macos/src/metal_renderer.rs`

Concrete takeaways from those files:

- GPUI keeps the higher-level scene/batch vocabulary above backend
  implementations.
- The wgpu and Metal renderers each terminate their own device/queue/layer/
  pipeline/atlas state locally.
- Backend renderers are large because GPU state really lives there, but the
  shared model they satisfy is still clearer than Zide's current renderer-root
  ownership.

## High-Confidence Lessons

### 1. Shared rendering vocabulary must sit above backend implementation

The useful reference pattern is not "everything becomes generic immediately."

It is:

- one higher-level scene/draw vocabulary
- separate backend implementations that satisfy it

Zed/GPUI does this more honestly than Zide currently does because backend-owned
renderers implement a common rendering role instead of the shared center
carrying backend-native draw structs.

### 2. Backend-owned GPU state should terminate inside the backend

In both Ghostty-style and GPUI-style pressure, API-native objects stay backend
local:

- devices
- queues/contexts
- pipelines
- textures
- frame/surface details

Zide still leaks some of those shapes into `src/ui/renderer.zig`, especially on
the Metal side.

Ghostty adds a useful nuance here: host/view ownership does not need to become
"generic" for the backend contract to be strong. What matters is that the
shared renderer contract stays above backend/device state, while view/surface
owners keep platform-specific lifecycle and presentation concerns local.

### 3. A mature backend abstraction is not just capability reporting

Capability reporting is useful, but the stronger reference pattern is:

- backend-neutral draw and frame contracts first
- capability description second

Zide has improved capability truth faster than it has improved the underlying
draw/present contract.

### 4. Platform-native implementations and backend-neutral contracts can coexist

Zed’s macOS Metal path is platform-specific where it should be, but it still
fits within a broader renderer framework.

That is the right pressure for Zide:

- native host/platform ownership where needed
- backend-neutral renderer contract above that

### 5. Shared runtime should not be the hidden backend center

Zed pressures us away from a renderer root that stores backend-native state.
Ghostty pressures us away from shared runtime code becoming the hidden place
where backend-specific presentation and lifecycle choices still happen.

That is directly relevant to Zide's current state:

- `src/ui/renderer/present_trace_runtime.zig` is slimmer than before, but
  still acts as a shared present/trace center that needs a tighter long-term
  role
- the neutral presentable facade is cleaner now that it lives on
  `src/ui/renderer.zig`, but the richer presentable lifecycle is still mostly
  defined by the OpenGL implementation

## Consequence For Zide

The next backend-architecture cuts should bias toward:

1. backend-neutral frame lifecycle
2. backend-neutral surface draw descriptions
3. backend-neutral presentable/retained target ownership
4. backend-local API details
5. shared runtime getting out of the business of being the secret backend owner

Not toward:

- more capability flags without stronger contracts
- more Metal-specific helper methods on `Renderer`
- more polishing work that leaves the shared contract weak

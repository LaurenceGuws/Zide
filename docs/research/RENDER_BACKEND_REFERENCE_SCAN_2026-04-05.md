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
- backend lifecycle discipline
- backend-specific machinery terminating in backend owners

Relevant repo path pressure:

- Ghostty renderer organization under its renderer/runtime centers
- Ghostty macOS Metal ownership as a serious native backend example

### Zed / GPUI

Strong pressure for:

- one higher-level renderer model with multiple backend implementations
- platform/backend-specific renderer implementations living under backend-owned
  crates rather than in one giant shared renderer root
- wgpu/Metal platform implementations satisfying one scene/batching model

Concrete files inspected:

- `dev_references/editors/zed/crates/gpui_wgpu/src/wgpu_renderer.rs`
- `dev_references/editors/zed/crates/gpui_macos/src/metal_renderer.rs`

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

## Consequence For Zide

The next backend-architecture cuts should bias toward:

1. backend-neutral frame lifecycle
2. backend-neutral surface draw descriptions
3. backend-neutral presentable/retained target ownership
4. backend-local API details

Not toward:

- more capability flags without stronger contracts
- more Metal-specific helper methods on `Renderer`
- more polishing work that leaves the shared contract weak

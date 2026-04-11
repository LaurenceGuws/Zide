# Android GLES Backend Plan

Purpose: define the first controlled Android GLES renderer-backend planning cut
after renderer gate #5 composition ownership was narrowed enough for Android to
move again.

This is not a broad backend sprint. It is the smallest step that lets Android
GLES enter the shared renderer backend contract without product-specific
bypasses.

## Current Authority

The Android terminal-host lane already proved:

- `ANativeWindow` lifecycle and identity are explicit
- `surfaceIdentityEpoch` distinguishes `acquired`, `unchanged`, `replaced`, and
  `retired`
- EGL display/config/context/window-surface binding works on the Note10
- EGL window surfaces can be recreated across replacement and retirement
- one context-owned GLES texture survives those transitions on the Note10
- texture resize pressure forces honest reallocation/upload without hidden
  context churn on the clean path

The renderer contract now says:

- gate #1 is met for shared surface submission
- gate #3 is met for backend runtime storage ownership
- gate #4 is met for `SurfaceDraw` payload opacity
- gate #5 is structurally met for scanned composition families
- gate #2 Metal live verification remains deferred until Mac access returns

So Android GLES may start as a controlled planning/first-slice lane. Android
Vulkan and desktop Vulkan remain out of scope.

## Goal

Introduce Android GLES as a real backend direction without making Android
special-case product rendering.

The first implementation slice must prove that the shared backend host can
select Android GLES and bind it to Android native-window truth, while doing the
least possible rendering.

## First Implementation Slice

Slice name:

- `AR-B4.a` Android GLES backend skeleton and frame binding

Allowed files:

- `src/ui/renderer.zig`
- `src/ui/renderer/backend_dispatch.zig`
- `src/ui/renderer/backend_runtime_bundle.zig`
- new `src/ui/renderer/android_gles_backend.zig`
- new `src/ui/renderer/android_gles_runtime_state.zig`
- narrow reuse/extraction from `src/platform/android_gles_probe.zig` only if it
  does not break the terminal-host probe
- Android build/link files only if required to resolve EGL/GLES symbols for the
  shared renderer build
- docs in this file, `docs/todo/android/implementation.md`, and
  `docs/todo/ui/renderer.md`

Required behavior:

- add a selectable Android GLES backend enum value only for Android builds
- allocate backend runtime storage through the existing backend host
- initialize EGL display/config/context through Android-owned runtime state
- create/destroy an EGL window surface from current Android native-window
  identity
- make the GLES context current during frame begin/submit
- clear one frame and swap buffers
- report capabilities honestly as minimal/unavailable where not implemented
- use `surfaceIdentityEpoch`/transition truth, not raw pointer equality, for
  surface replacement

Current status:

- the first shared-backend skeleton is now in:
  `renderer.zig`, `backend_dispatch.zig`, `backend_runtime_bundle.zig`,
  `android_gles_backend.zig`, and `android_gles_runtime_state.zig`
- Android GLES now has:
  - shared backend enum/runtime slot
  - backend dispatch wiring
  - honest minimal capabilities
  - backend runtime init/deinit now owns the shared EGL display/config/context
    state instead of leaving that owner probe-only
  - frame begin/submit now binds Android native-window identity through
    surface epoch truth, clears one frame, and swaps buffers through the shared
    frame host path
  - explicit unavailable behavior for presentables, screenshots, images, and
    surface draw replay
  - explicit bootstrap failure instead of a fake SDL bootstrap path
  - shared EGL/context/window-surface ownership extraction in
    `src/platform/android_gles_runtime.zig`; the probe now uses that owner
    instead of duplicating EGL lifetime logic locally
- this does **not** yet meet the full stop marker:
  - terminal-host does not instantiate `Renderer` yet
  - there is still no Android-side shared renderer bootstrap path that creates
    a live `Renderer` instance in terminal-host
  - visible clear/swap is implemented in the backend, but not yet claimed on
    device through terminal-host

Stopping point:

- the Android terminal-host can select the Android GLES backend and produce a
  visible clear/swap through the shared backend-host path
- no terminal grid/text/atlas/presentable rendering is claimed
- no product code branches on Android GLES
- unsupported backend ops fail explicitly or report unavailable capabilities
  instead of silently pretending parity

## Explicit Non-Goals

- no Android Vulkan
- no desktop Vulkan
- no terminal presentable implementation
- no terminal glyph atlas implementation
- no persistent/raw image implementation
- no screenshot implementation
- no editor/sample/product rendering adoption
- no Java-side product UI changes
- no compatibility shim that keeps both a probe-owned and backend-owned draw
  path alive as equal product paths

## Probe Migration Rule

`src/platform/android_gles_probe.zig` remains a terminal-host proof module until
`AR-B4.a` is validated.

After `AR-B4.a` is validated, the probe must either:

- become a thin diagnostic wrapper around the shared Android GLES runtime owner,
  or
- be deleted if the shared backend path supersedes every probe responsibility

It must not remain a parallel renderer by inertia.

## Validation

Local validation before commit:

- `zig build`
- `zig build test`
- Android terminal-host build command from `ops/android_terminal_host.py`

Device validation before claiming the slice:

- install terminal-host APK
- launch with Android GLES backend selected
- verify visible clear/swap
- rotate or recreate the surface once
- verify logs show surface recreation through epoch/transition ownership

## Next After `AR-B4.a`

If the skeleton/frame binding works, the next slices are:

1. `AR-B4.b` external-host renderer bootstrap for Android `backend_smoke`
2. `AR-B4.c` surface draw replay for `SurfaceDraw.solid`
3. `AR-B4.d` terminal glyph/rect minimal path, then probe-to-renderer product
   handoff

## `AR-B4.b` Next Cut

Purpose:

- let Android terminal-host create a real shared `Renderer` instance for
  `android_gles` without faking SDL window ownership

Why this is the blocker now:

- `android_gles_backend.zig` can now bind live Android native-window identity,
  clear, and swap through the shared backend path
- but `Renderer.init(...)` still hard-requires SDL bootstrap/window ownership
- terminal-host therefore still cannot prove the shared renderer on device even
  though the backend itself is no longer the loud blocker

Allowed files:

- `src/ui/renderer.zig`
- `src/ui/renderer/bootstrap_runtime.zig`
- `src/ui/renderer/lifecycle_runtime.zig`
- `src/ui/renderer/renderer_global_runtime.zig`
- `src/ui/renderer/input_state.zig`
- `src/ui/renderer/font_runtime.zig`
- narrow Android bridge/host files only if needed to carry external surface
  metrics into the new bootstrap path
- docs in this file, `docs/todo/android/implementation.md`, and
  `docs/AGENT_HANDOFF.md`

Required behavior:

- define a shared renderer bootstrap path for externally-owned host state
- keep it explicitly scoped to Android `backend_smoke`
- do not require an SDL window or SDL-owned render-surface attachment
- do not start SDL text input from that path
- do not claim full shared app-shell/runtime parity from that path yet
- allow the Android host to supply:
  - `PlatformAppHost`
  - `PlatformRenderHost`
  - initial display/surface metrics
- keep shutdown honest: no SDL window destroy / SDL quit from an external-host
  renderer instance

Current status:

- the shared renderer now has an external-host bootstrap seam for
  `runtime_profile = .backend_smoke`
- that seam:
  - bypasses SDL window bootstrap
  - skips global SDL text-input registration
  - synthesizes initial display metrics from `PlatformRenderHost.surface_metrics`
  - keeps SDL-owned shutdown limited to SDL-owned bootstrap instances
- the Android native bridge can now:
  - create a shared `Renderer` with `renderer_backend = .android_gles`
  - sync bridge host state into that renderer
  - execute one `beginFrame` / `submitFrame` cycle in tests
- this is still not the `AR-B4.b` stop marker:
  - terminal-host surface callbacks still do not call the new shared bootstrap
    path live
  - no device claim is made until Android terminal-host creates the renderer
    and proves visible clear/swap through it

Stop marker:

- terminal-host can create and destroy a shared `Renderer` instance with
  `renderer_backend = .android_gles` and `runtime_profile = .backend_smoke`
- that renderer can execute `beginFrame` / `submitFrame` against Android
  surface epoch truth without probe-owned drawing
- no shared input polling, window chrome, or full app-shell startup is claimed
  yet

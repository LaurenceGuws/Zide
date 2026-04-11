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

1. `AR-B4.b` surface draw replay for `SurfaceDraw.solid`
2. `AR-B4.c` terminal glyph/rect minimal path
3. `AR-B4.d` Android terminal product render handoff from probe texture to real
   renderer output

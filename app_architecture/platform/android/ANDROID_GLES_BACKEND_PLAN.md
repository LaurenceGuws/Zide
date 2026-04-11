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
- Android terminal-host native build truth is now explicit too:
  - `zig build android-terminal-host-bridge` is the owning native build target
  - that target uses an NDK-backed Android libc file plus explicit Android
    system `.so` paths
  - the Android bridge no longer links the SDL package as a compiled Android
    library just to satisfy shared renderer headers
  - the ops wrapper only resolves toolchain paths and copies the built `.so`
    into `android/terminal-host/app/src/main/jniLibs`

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
- `zig build android-terminal-host-bridge -Dtarget=aarch64-linux-android
  -Dmode=terminal --sysroot <ndk-sysroot>`
- `./ops/android_terminal_host.py apk`

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
  - route live surface-available / redraw callbacks through that shared
    renderer path instead of the old probe draw path
- device validation now confirms that:
  - terminal-host loads the shared bridge without unresolved SDL symbols
  - live surface callbacks execute shared `beginFrame` / `submitFrame`
  - shared Android GLES clear/swap now runs on-device through the renderer path
  - stale Java/native `probe` labels are renamed to `renderer` labels
- remaining caveat after `AR-B4.b`:
  - build/deploy confusion is no longer the blocker: Android terminal-host now
    has one repo-owned native build target and one operator wrapper instead of
    a manual native link script

Stop marker:

- terminal-host can create and destroy a shared `Renderer` instance with
  `renderer_backend = .android_gles` and `runtime_profile = .backend_smoke`
- that renderer can execute `beginFrame` / `submitFrame` against Android
  surface epoch truth without probe-owned drawing
- no shared input polling, window chrome, or full app-shell startup is claimed
  yet

Status:

- `AR-B4.b` is now structurally met.
- terminal-host product view now exposes the renderer surface as the real main
  content host instead of a hidden `1dp x 1dp` container.

## `AR-B4.c` Next Cut

Purpose:

- let the shared Android GLES backend replay the first backend-neutral
  `SurfaceDraw.solid`

Current status:

- Android GLES backend now accepts queued `SurfaceDraw.solid` payloads
- submit-time replay uses GLES scissor + clear for solid rect fills
- backend-smoke frame execution now records one shared solid rect through
  `renderer_surface_host.recordSolidSurfaceFromLogicalRect(...)`
- terminal-host product view now hosts the renderer surface at real size with
  the Java transcript overlaid temporarily for shell usability
- device validation now proves:
  - shared surface size is real on-device (`surface.changed ... size=2759x1230`
    in landscape and `1440x2632` in portrait)
  - visible product view is surface-backed instead of using the old hidden host
  - shared clear/swap still executes on the live path after the host layout cut
  - visible output now requires explicit host/runtime format alignment:
    terminal-host `SurfaceView` must not stay on the default `RGB_565` path;
    the host now requests `RGBA_8888`, and the shared EGL runtime also applies
    `EGL_NATIVE_VISUAL_ID` to the `ANativeWindow`
- local validation stays green:
  - `zig build`
  - `zig build test`
  - `./ops/android_terminal_host.py deploy`

Stop marker:

- Android GLES backend can accept and replay one shared `SurfaceDraw.solid`
  without a backend-private draw bypass
- product view is visibly backed by the shared renderer surface on-device

Status:

- `AR-B4.c` is now structurally met.
- The next active slice is `AR-B4.d`: minimal terminal rect/glyph rendering
  through the shared Android GLES backend.

## `AR-B4.d` Next Cut

Purpose:

- let the shared Android GLES backend accept the first dedicated terminal
  rect/glyph-rect draw ops instead of only generic `SurfaceDraw.solid`

Current status:

- Android GLES backend now maps:
  - `addTerminalRect(...)` to the shared queued solid replay path
  - `addTerminalGlyphRect(...)` to the shared queued solid replay path
- backend-smoke rendering now proves those terminal draw ops directly with
  explicit terminal-colored rects plus glyph-rect accents inside the shared
  Android surface
- device validation now proves:
  - visible shared clear color on-device
  - visible shared `SurfaceDraw.solid` preview band on-device
  - visible shared terminal rect colors on-device
  - visible shared terminal glyph-rect accents on-device
  - host surface format alignment is real in logs too:
    `surface.changed ... format=1` after the host `RGBA_8888` cut

Stop marker:

- the shared Android GLES backend can execute one minimal terminal
  rect/glyph-rect proof on-device without a backend-private immediate draw path
- this still does **not** claim live terminal-widget product ownership,
  glyph-atlas parity, or Java transcript retirement

Status:

- `AR-B4.d` is now structurally met.
- The next active slice is `AR-B4.e`: first live terminal-grid ownership
  through the shared Android GLES backend.

## `AR-B4.e` Next Cut

Purpose:

- move the visible shell product surface from the temporary Java transcript
  overlay onto the shared Android GLES renderer path

Required behavior:

- draw live terminal cell backgrounds and glyph fallback from real terminal
  state through the shared renderer path
- keep Java-side IME/input/overlay ownership, but stop using the Java
  transcript as the visible shell product surface
- keep the cut honest: no glyph-atlas parity, no presentable path, no editor
  claims

Stop marker:

- product view shows live shell content from the shared renderer path
- the Java transcript overlay is no longer the product-owned shell display

Current status:

- terminal-host now stages the repo-owned font assets it needs into the app
  files sandbox instead of pretending Android can open repo-relative desktop
  font paths directly
- Android GLES font initialization now waits until the first live frame after
  `makeCurrent`; it no longer tries to allocate atlas textures during backend
  bootstrap before a current Android surface exists
- the Android bridge now reuses the existing live shell session handle to
  create a shared `TerminalWidget` against the real shell runtime
- product view now hides the Java transcript when that shared shell renderer is
  active, so product shell ownership is no longer Java-owned
- Android GLES now binds the shared atlas vertex-stream pipeline instead of a
  glyph-block fallback:
  - backend-owned GL shader/VBO/VAO resources now live under
    `android_gles_runtime_state`
  - `renderer_vertex_stream_backend_host.zig` now dispatches Android GLES
    through the shared vertex-stream seam instead of forcing desktop GL
  - live terminal rects/glyphs now replay through shared atlas textures and
    shared glyph-cache flushes on Android GLES
- device validation now proves:
  - `native.surfaceAvailable ... gles=drawn` on the live shell path
  - the process stays alive after first frame
  - product view hierarchy no longer contains the Java transcript scroll/text
    nodes while the shared shell renderer is active
  - screenshot capture now shows readable live shell text and prompt content
    through the shared Android GLES renderer path

`AR-B4.e` is now met.

The next active slice is `AR-B4.f`: first product-fit live grid sizing.

## `AR-B4.f` Next Cut

Purpose:

- make the shared-renderer shell use product-fit terminal bounds instead of the
  current undersized live grid island

Required behavior:

- keep the shared Android GLES renderer as the only product-owned shell surface
- size the live terminal grid from real product surface bounds instead of a
  visibly undersized bootstrap-era layout
- keep Java ownership limited to lifecycle/input/IME/debug overlays

Stop marker:

- product view shell content uses readable live glyphs at product-fit bounds
- the remaining Java transcript path is no longer part of active product shell
  refresh ownership

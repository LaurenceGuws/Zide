# Android Native Host Queue

This is the active execution queue for Android-native host work that is allowed
before Android renderer backend bootstrap.

Use this queue for:

- `Activity` lifecycle truth
- `Surface` / `ANativeWindow` lifecycle truth
- focus, IME, redraw-needed, resize, and surface-loss ownership

Do not use this queue for:

- GLES backend bootstrap
- Vulkan backend bootstrap
- renderer contract work that is not forced by Android host pressure

## Owner Docs

- `app_architecture/platform/NATIVE_HOST_CONTRACT.md`
- `app_architecture/platform/android/RENDER_BACKEND.md`
- `app_architecture/platform/android/BOOTSTRAP_BRIDGE_PLAN.md`
- `app_architecture/platform/android/SURFACE_IDENTITY_POLICY.md`
- `docs/research/terminal/ANDROID_HOST_PTY_SCAN_2026-04-08.md`
- `docs/todo/ui/renderer.md` (for the pre-Android rendering gate)

## Current Rule

Android host work is allowed now.

Android rendering backend work is still blocked until the renderer queue says
the pre-Android rendering gate is met.

## Active Tickets

### `AH-A1` Shared Native Host Surface Truth

Purpose:

- make `src/platform/native_host.zig` capable of representing Android-style
  surface presence/absence, geometry, density, redraw-needed, and
  `ANativeWindow` identity without starting GLES work

Acceptance:

- `PlatformRenderHost` can express surface available vs unavailable
- `PlatformRenderHost` carries logical and drawable size
- `PlatformRenderHost` carries scale/density truth
- `PlatformRenderHost` can track redraw-needed state
- `PlatformRenderHost` has a slot for Android native window identity
- no GLES or Vulkan backend code lands in `src/`

Status:

- in progress
- first shared-host contract cut landed in `src/platform/native_host.zig`
- first shared SDL event-mapping cut now updates app-host lifecycle/focus and
  render-host surface/redraw truth
- `PlatformRenderHost` no longer carries an SDL window pointer
- SDL-only host capture now lives in `src/platform/sdl_native_host.zig`
- Android-specific lifecycle/event mapping is still not implemented
- Note10 harness validation now confirms that Android window focus and IME
  focus must remain separate signals

Next likely follow-ups:

1. define Android app-host state transitions and focus/text-input signals
2. define the first Android-specific host mapper against `PlatformAppHost` and
   `PlatformRenderHost`
3. only then decide what real renderer/backend pressure Android exposes

### `AH-A2` First Android Host Mapper

Purpose:

- make Android-shaped lifecycle/surface semantics live in a platform-owned
  module instead of remaining implicit in shared SDL input handling

Acceptance:

- `src/platform/android_host.zig` exists
- foreground/background and redraw/surface refresh helpers route through it
- shared input/runtime code can delegate Android-shaped host meaning there
- no GLES or Vulkan backend work lands

Status:

- in progress
- first mapper module exists and shared input/runtime now delegates Android
  semantics there where applicable
- `android_host.noteSurfaceFocus(...)` no longer treats Android window focus as
  implicit text-input focus
- Android SDL refresh capture now lives in `src/platform/sdl_android_host.zig`
- `android_host.zig` is now freestanding enough for the runtime bootstrap
  bridge to route through shared host semantics
- actual Android event-source wiring is still pending

### `AH-A3` Android Host Harness Bootstrap

Purpose:

- create a repo-owned Android app that can validate lifecycle, `Surface`,
  redraw-needed, focus, and IME behavior on device before native backend work

Acceptance:

- `android/host-harness/` exists as an Android app project
- the app can log `Activity` lifecycle transitions
- the app can log `SurfaceView` create/change/destroy/redraw callbacks
- the app can probe IME and window focus behavior
- no NDK, SDL, GLES, or Vulkan bootstrap is introduced in this cut

Status:

- in progress
- initial Java-only host harness scaffold exists
- `zig build` and `zig build test` still pass after the scaffold
- first local `:app:assembleDebug` attempt hit transient Google Maven artifact
  fetch trouble (`Tag mismatch` on `com.android.tools.build:builder:8.7.3`)
- a writable user-local SDK clone plus API 35 packages resolved the local
  environment pressure
- `:app:assembleDebug` now succeeds with:
  - `ANDROID_HOME=$HOME/.local/share/zide-android-sdk`
  - `ANDROID_SDK_ROOT=$HOME/.local/share/zide-android-sdk`
- the debug APK was installed on the Note10 and launched successfully
- first log sequence confirms:
  - `activity.onCreate`
  - `activity.onStart`
  - `activity.onResume`
  - `surface.created`
  - `surface.changed`
  - `surface.redrawNeeded`
  - `activity.onWindowFocusChanged focus=true`
- Note10 smoke checks also confirmed:
  - IME show/hide causes `surface.changed` + `surface.redrawNeeded`
  - backgrounding causes `onPause -> windowFocus(false) -> surface.destroyed -> onStop`
- next step is tightening the host mapping against that observed ordering

### `AH-A4` Android Bootstrap Bridge

Purpose:

- create the first repo-owned Android bootstrap path for the real Zig runtime,
  so Android progress can move from host probing into native entry/bridge work

Acceptance:

- the repo contains an Android app/bootstrap project for the real runtime lane
- the app loads a repo-built native Zig library
- launch + pause/resume + surface-available/lost callbacks reach repo-owned
  native bridge code
- build/install/run instructions are recorded in the owning docs

Status:

- in progress
- the host harness proved the Android callback ordering we needed first
- `build_system/platform_capabilities.zig` and the current app build graph are
  still desktop-only, so bootstrap/native-entry is now the real next blocker
- `android/bootstrap-bridge/` now exists as the first runtime-lane Android app
- `ops/android_build_bootstrap_bridge.sh` builds the Zig bridge through a Zig
  object + NDK clang link path
- that bridge link now pulls in `libandroid` and rejects unresolved native
  symbols at build time
- the Note10 now loads the repo-built Zig library successfully
- first launch-path native callback acknowledgements are live:
  - `native.onCreate seq=1`
  - `native.onStart seq=2`
  - `native.onResume seq=3`
  - `native.surfaceAvailable seq=4`
  - `native.onWindowFocus seq=6`
- the bootstrap bridge now surfaces real `ANativeWindow` identity into shared
  host state:
  - repeated `surface.changed` callbacks kept one stable non-zero token on the
    Note10
  - shared `surfaceIdentityEpoch` stayed at `1` across those same-window
    updates
  - `surface.destroyed` cleared that token back to `0x0` and advanced
    `surfaceIdentityEpoch` to `2`
- the bootstrap bridge now routes lifecycle/focus/surface callbacks through
  shared Android host semantics instead of the earlier freestanding sequence
  stub
- HOME/background smoke now confirms:
  - `native.onPause seq=7`
  - `native.surfaceAvailable seq=8`
  - `native.surfaceAvailable seq=9`
  - `native.onWindowFocus seq=10`
  - `native.surfaceDestroyed seq=11`
  - `native.onStop seq=12`
- the next blocker is no longer native entry; it is deeper Android host/runtime
  ownership, with native-window/render-host truth now clearly ahead of PTY
  lifetime for rendering-oriented work

Do not do:

- no GLES or Vulkan backend bootstrap
- no Android PTY/service design yet
- no pretending Android is already a first-class build target across the whole
  repo

Next likely follow-ups:

1. execute `AH-A5` from
   `app_architecture/platform/android/SURFACE_IDENTITY_POLICY.md`
2. only after that, decide whether PTY/runtime lifetime has become the stronger
   remaining Android blocker
3. do not jump to GLES from native-load success plus one bootstrap pass

## Current Research Read

- Android host truth is clearly native-window lifecycle truth, not persistent
  desktop-window truth.
- Native PTY subprocesses are viable on Android (`/dev/ptmx` + JNI subprocess
  launch is established practice).
- The real PTY risk is Android background/process policy, especially on Android
  12+, not basic PTY availability.

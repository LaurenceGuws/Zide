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

## Current Research Read

- Android host truth is clearly native-window lifecycle truth, not persistent
  desktop-window truth.
- Native PTY subprocesses are viable on Android (`/dev/ptmx` + JNI subprocess
  launch is established practice).
- The real PTY risk is Android background/process policy, especially on Android
  12+, not basic PTY availability.

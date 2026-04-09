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
- `app_architecture/platform/android/ANDROID_GLES_BINDING_PLAN.md`
- `app_architecture/platform/android/SURFACE_IDENTITY_POLICY.md`
- `app_architecture/platform/android/ANDROID_PTY_LIFETIME_PLAN.md`
- `app_architecture/platform/android/ANDROID_PTY_SERVICE_SURVIVAL_PLAN.md`
- `docs/research/terminal/ANDROID_HOST_PTY_SCAN_2026-04-08.md`
- `docs/todo/ui/renderer.md` (for the pre-Android rendering gate)

## Current Rule

Android host work is allowed now.

Android rendering backend work is still blocked until the renderer queue says
the pre-Android rendering gate is met.

Current boundary:

- the Android-native host/bootstrap lane is structurally complete enough for
  future renderer binding
- disposable app-process-owned PTY lifetime is the current Android terminal
  baseline
- service-owned PTY survival is now a validated separate Android product lane,
  but it has not displaced the disposable baseline as the default answer
- Android rendering backend work is still blocked by the renderer queue
- the first honest Android rendering-adjacent move is now authority for a
  bootstrap-owned EGL/GLES binding cut, not shared renderer integration

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

- met
- `src/platform/native_host.zig` now carries:
  - surface available vs unavailable
  - logical and drawable size
  - scale and density truth
  - redraw-requested state
  - Android native-window identity
  - surface identity epoch and transition
- shared and Android-specific host paths both now consume that contract

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

- met
- `src/platform/android_host.zig` exists as the Android-owned host semantics
  module
- shared input/runtime delegates Android-specific host meaning there
- the runtime bootstrap bridge now routes actual Android lifecycle/focus/
  surface callbacks through it
- Android SDL refresh capture lives in `src/platform/sdl_android_host.zig`

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

- met
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
- the observed Note10 ordering is now part of the owning Android authority

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

- met
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
- the bridge now classifies surface identity transitions explicitly:
  - first live surface callback was `acquired`
  - repeated geometry churn, forced rotation, and pause-side `surface.changed`
    stayed `unchanged`
  - `surface.destroyed` was `retired`
  - later foreground return becomes a fresh `acquired`, even when the raw
    native-window token value can recur
  - explicit in-activity `SurfaceView` recreation produced a true
    `replaced` transition without a prior `retired`
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
- bootstrap/native-entry is no longer the blocker for Android-native progress
- this lane now feeds future renderer work by providing real native lifecycle,
  surface identity, and replacement truth

Do not do:

- no GLES or Vulkan backend bootstrap
- no Android PTY/service design yet
- no pretending Android is already a first-class build target across the whole
  repo

Next likely follow-ups:

1. keep disposable app-process-owned PTY lifetime as the current Android
   terminal baseline unless a separate product lane explicitly asks for
   service-owned survival
2. if Android renderer binding resumes later, treat both `replaced` and
   `retired` then later `acquired` as required host replacement stories
3. do not jump to GLES from native-load success plus one bootstrap pass

### `AP-A1` Android PTY Lifetime Ownership

Purpose:

- define the Android PTY/process lifetime baseline under pause/stop/background
  pressure before any real Android terminal integration

Status:

- structurally met
- first execution probe now exists in `android/bootstrap-bridge/`
- Note10 result so far:
  - app-process-owned PTY probe started successfully
  - PTY heartbeat survived `HOME` / pause / stop / surface retirement
  - PTY heartbeat stopped after `am force-stop`
  - direct PID check confirmed the PTY child was dead after force-stop
- current honest baseline:
  - PTY/process lifetime can outlive visible surface lifetime briefly
  - PTY/process lifetime does not outlive app-process death
  - disposable app-process-owned PTY lifetime is the current Android terminal
    baseline
- `android/bootstrap-bridge/` now also owns the live disposable-baseline
  observability surface:
  - on-device PTY status panel
  - manual start / stop / restart controls
  - heartbeat count / last heartbeat line readout without adb-only inspection
- hardened Note10 observation now confirms:
  - restarted probe stayed alive across `onPause` and `onStop`
  - the same pid was still alive on `onStart` / `onResume` before surface
    reacquire completed
  - surface retirement/reacquire still happened independently of PTY lifetime
- no further PTY/service architecture work is open in this queue unless a
  separate product lane explicitly asks for service-owned survival

Do not do:

- no Android terminal product integration yet
- no foreground-service architecture leap from one probe
- no renderer binding work from PTY confidence

### `AP-A2` Android PTY Service Survival Probe

Purpose:

- define and execute the narrowest honest foreground-service-owned PTY probe
  without implying terminal product approval

Status:

- met as a probe lane
- authority now exists in
  `app_architecture/platform/android/ANDROID_PTY_SERVICE_SURVIVAL_PLAN.md`
- bootstrap foreground-service probe now exists and has device validation on
  the Note10
- current result:
  - service-owned PTY survival is technically viable
  - it did not yet prove a materially better default survival story than the
    disposable app-process baseline

Acceptance:

- `android/bootstrap-bridge/` can start a foreground service that owns the
  existing native PTY heartbeat probe
- the service can be started and stopped explicitly
- the service path is validated on-device
- docs record whether foreground-service ownership changes the observed
  survival story enough to justify a future product lane

Do not do:

- no renderer work
- no terminal UI/service integration
- no wake-lock policy expansion unless the narrow probe proves it necessary
- no product claim that foreground-service PTY survival is now the default

### `AH-A5` Android GLES Binding Authority

Purpose:

- define the first Android EGL/GLES binding cut precisely enough that it can
  be implemented next without drifting into a fake Android renderer backend

Status:

- structurally met
- authority now exists in
  `app_architecture/platform/android/ANDROID_GLES_BINDING_PLAN.md`
- first executable bootstrap-owned EGL/GLES clear/swap proof now exists in the
  Android bootstrap bridge and validated on the Note10
- bootstrap-owned EGL lifecycle hardening is now also structurally met on the
  Note10:
  - true in-process `transition=replaced` recreated the EGL window surface
  - `transition=retired` cleared live surface binding state
  - later fresh `transition=acquired` recreated the EGL window surface cleanly
  - `glesBoundEpoch` and `glesSurfaceCreates` now make those transitions
    directly observable in the bootstrap app logs/UI
  - `glesContextCreates` stayed at `1` across those transitions, so current
    bootstrap policy reuses one EGL context while recreating only the window
    surface on this device

Acceptance:

- the first Android rendering proof is explicitly scoped to
  `android/bootstrap-bridge/` and the native bridge
- the first executable cut is defined as EGL display/config/context creation
  plus EGL window-surface bind / clear / swap against the current
  `ANativeWindow`
- Note10 device proof now shows:
  - `native.surfaceAvailable ... gles=drawn`
  - `native.surfaceRedrawNeeded ... gles=drawn`
- Note10 lifecycle hardening now also shows:
  - `transition=replaced ... glesBoundEpoch=2 glesSurfaceCreates=2`
  - `transition=retired ... gles=surface-destroyed glesBoundEpoch=0`
  - later `transition=acquired ... glesBoundEpoch=4 glesSurfaceCreates=3`
  - all of those still reported `glesContextCreates=1`
- docs explicitly require surface replacement to follow
  `surfaceIdentityEpoch` / transition truth, not raw pointer comparison
- docs explicitly forbid new shared renderer/backend work in `src/ui/renderer/`
  in this cut

Do not do:

- no shared Android renderer backend
- no new `RendererBackend` variant
- no terminal/text rendering integration
- no bypass of `replaced` / `retired` surface truth

## Current Research Read

- Android host truth is clearly native-window lifecycle truth, not persistent
  desktop-window truth.
- Native PTY subprocesses are viable on Android (`/dev/ptmx` + JNI subprocess
  launch is established practice).
- The real PTY risk is Android background/process policy, especially on Android
  12+, not basic PTY availability.

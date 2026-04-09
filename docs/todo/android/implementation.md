# Android Terminal Queue

This is the active execution queue for Android terminal work.

Use this queue for:

- Android host/bootstrap/runtime work
- Android PTY/runtime lifetime work
- Android renderer-unblocking work when Android is the forcing function
- Android terminal product decisions and sequencing

Do not use this queue for:

- generic renderer cleanup with no Android leverage
- desktop-only work with no Android leverage
- speculative backend work that bypasses the queue's current blocker notes

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

Android terminal excellence is the active repo goal until further notice.

Current boundary:

- the Android-native host/bootstrap lane is structurally complete enough to
  stop being the main unknown
- disposable app-process-owned PTY lifetime is the current Android terminal
  baseline
- service-owned PTY survival is now a validated separate Android product lane,
  but it has not displaced the disposable baseline as the default answer
- bootstrap-owned EGL/GLES proof is now strong enough that it is no longer the
  main unknown either
- first-class Android rendering/backend work in `src/ui/renderer/` is still
  blocked by renderer gate #5
- renderer work is only in scope here when it is the next highest-leverage
  Android blocker

## Priority Rule

When choosing what to do next, rank work like this:

1. the highest-leverage blocker to a first-class Android terminal
2. if that blocker is Android-owned, execute it from this queue
3. if that blocker is a renderer gate, execute the exact renderer ticket that
   unblocks Android and then return here

Do not drift back into renderer cleanup just because renderer docs are more
developed.

## Current Biggest Blocker

Right now the biggest shared blocker to first-class Android renderer adoption
is renderer gate #5:

- presentable/frame routine is still not neutral enough for a new backend to
  feel routine, even though shared frame-family feedback now covers terminal,
  chrome band, editor row-band, and sample section

That means:

- gate #2 is treated as closed for active work until Metal validation is
  explicitly reopened
- gate #4 is met
- Android bootstrap proof should only continue if it answers a stronger
  Android-specific runtime question than gate #5 does
- otherwise the next honest move is the next gate-5 cut done explicitly in
  service of Android terminal progress

Current next renderer-unblock ticket:

- `AR-B2` / `RB-B3.d`
- remove the remaining product-significant
  `usesDirectTerminalPresentation(...)` decisions from terminal widget runtime
  so Android does not inherit direct-vs-retained path checks in shared code

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
  - `glesTextureCreates` also stayed at `1` with `glesTextureAlive=true`, so a
    minimal context-owned GLES resource survived those transitions too

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
  - all of those also still reported
    `glesTextureCreates=1 glesTextureAlive=true`
- docs explicitly require surface replacement to follow
  `surfaceIdentityEpoch` / transition truth, not raw pointer comparison
- docs explicitly forbid new shared renderer/backend work in `src/ui/renderer/`
  in this cut

Do not do:

- no shared Android renderer backend
- no new `RendererBackend` variant
- no terminal/text rendering integration
- no bypass of `replaced` / `retired` surface truth

### `AR-B1` Android Renderer Adoption Unblock

Purpose:

- execute only the next renderer cut that materially unblocks first-class
  Android renderer adoption

Owner docs:

- `docs/todo/ui/renderer.md`
- `app_architecture/ui/RENDER_BACKEND_CONTRACT.md`
- `app_architecture/ui/RENDER_BACKEND_CURRENT_STATE.md`

Current target:

- renderer gate #5 via `RB-B3.c`

Current branch goal:

- `renderer/ar-b1-nonterminal-frame-family`
- adopters now landed:
  - `chrome_band`
  - `editor_row_band`
  - `sample_section`

Current evidence:

- shared frame finalization now emits one family summary surface on
  `FrameSubmission` for `terminal`, `chrome_band`, `editor_row_band`, and
  `sample_section`
- `chrome_band` reports touch participation through that summary via
  `renderer_chrome_band_host`
- `editor_row_band` now also reports touch participation through shared
  row-band flush/direct paths
- `sample_section` now reports touch participation through
  `font_sample_section_host`
- present feedback now reports terminal/chrome-band/editor-row-band/
  sample-section frame-family submission truth without inferring non-terminal
  participation from trace-only counters
- terminal presentation retirement feedback now also consumes the shared
  terminal family state directly instead of separate terminal-only
  `FrameSubmission` compatibility fields

Acceptance:

- the next renderer cut is explicit about what Android backend adoption would
  stop having to special-case afterward
- Android queue and renderer queue both point at the same blocker
- Android work returns here after that renderer cut lands

Do not do:

- no reopening gate #2 for active work unless Mac validation is explicitly
  reopened
- no generic renderer cleanup with no Android leverage
- no pretending bootstrap EGL proof by itself is equivalent to shared Android
  renderer readiness

Current follow-up:

- `AR-B1` is structurally complete
- the next Android renderer adoption unblock is `AR-B2`:
  move the remaining direct-vs-retained terminal-present path decisions behind
  the shared present contract instead of leaving them in widget runtime

## Current Research Read

- Android host truth is clearly native-window lifecycle truth, not persistent
  desktop-window truth.
- Native PTY subprocesses are viable on Android (`/dev/ptmx` + JNI subprocess
  launch is established practice).
- The real PTY risk is Android background/process policy, especially on Android
  12+, not basic PTY availability.

# Android Render Backend

Purpose: define how Android satisfies Zide's native host contract with native
Android lifecycle and native window ownership on the path to a first-class
Android terminal.

This doc is architecture authority for Android-native render-host shape.

Supporting research:

- `docs/research/terminal/ANDROID_HOST_PTY_SCAN_2026-04-08.md`
- `app_architecture/platform/android/ANDROID_TERMINAL_HOST_PLAN.md`
- `app_architecture/platform/android/ANDROID_GLES_BACKEND_PLAN.md`
- `app_architecture/platform/android/ANDROID_GLES_BINDING_PLAN.md`
- `app_architecture/platform/android/SURFACE_IDENTITY_POLICY.md`
- `app_architecture/platform/android/ANDROID_PTY_LIFETIME_PLAN.md`
- `app_architecture/platform/android/ANDROID_PTY_SERVICE_SURVIVAL_PLAN.md`

## Target Stack

This doc is subordinate to the current mobile product sequence:

- mobile terminal first
- reusable mobile-native fundamentals alongside it
- mobile editor second
- integrated IDE mode later

So Android render/backend work here must support that sequence rather than
trying to decide full mobile product packaging or full IDE composition early.

- app host: Android `Activity`
- render host: `Surface` / `ANativeWindow`
- backend: GLES first, with any future Vulkan decision requiring separate
  authority

SDL may remain a bridge for:

- Android terminal host setup
- JNI glue
- event routing
- packaging integration

But SDL is not the final owner of:

- Activity lifecycle truth
- surface availability/loss/replacement
- redraw-needed semantics
- pause/resume/stop/destroy sequencing

The same rule applies above SDL:

- Zig should own terminal/runtime/core rendering primitives
- Android platform code should own Android-native lifecycle/input/insets and
  any mobile-native overlays needed for a first-class UX
- do not force all mobile product behavior through the terminal texture path
  just to keep Java/Kotlin thin

## Why Android Is Different

Android is the clearest pressure against desktop-biased host design.

Official and SDL pressure in local refs says:

- the application lifecycle is Activity-owned
- `ANativeWindow` is the native render surface
- the surface can appear, disappear, resize, or be replaced
- redraw-needed is an explicit host concern
- pause/resume/stop/destroy are not edge cases; they are core runtime truth

So Android must not be modeled as:

- "a desktop window with more callbacks"
- "the SDL host plus GLES later"

## Render Host Object Model

The Android host must expose these centers:

- activity lifecycle state
- current native surface presence/absence
- current `ANativeWindow`
- current drawable pixel size
- focus and text-input state

The key rule is that the render surface is not permanent.

## Required Android Host Guarantees

The Android implementation must provide:

- started / resumed / paused / stopped / destroyed transitions
- native window created
- native window resized
- native window redraw-needed
- native window destroyed / invalidated
- focus gained / lost
- text-input ownership points

The backend must be able to react to any of those without assuming process
restart.

## `ANativeWindow` Contract

From the local official docs:

- `ANativeWindow` is the producer end of an image queue
- it is the C counterpart of Java `Surface`
- width and height are explicit
- it has explicit reference ownership

That means backend resources bound to the native window must be recreated or
revalidated whenever the host says the surface changed or was destroyed.

## Activity Lifecycle Boundary

Android lifecycle is not optional outer glue. It is part of the platform host
contract.

The host must treat these as first-class:

- start
- resume
- pause
- stop
- destroy

And the backend must never assume:

- pause implies surface still exists
- surface destruction implies app destruction
- stop implies no later resume

## Redraw-Needed And Resize

The local official `android_native_app_glue` reference makes two important
rules explicit:

- redraw-needed is a host command
- resize is a host command

So Android rendering must support:

- draw because the host explicitly requested redraw
- draw because content changed
- resize without pretending this is just a desktop-style window resize

## SDL Role On Android

SDL is allowed to remain the practical integration bridge.

SDL is still useful for:

- Java shim and JNI glue
- packaging/project generation
- some event transport
- cross-platform app entry compatibility

SDL must not erase Android truths:

- Activity lifecycle still exists
- `ANativeWindow` lifecycle still exists
- redraw-needed and window-terminated are still real platform events

## Backend Direction

The first Android-native backend direction remains GLES, because it is the
least speculative path for broad Android support.

But even GLES is downstream of the host contract. The real first requirement is
that the backend bind cleanly to a replaceable native window and survive
lifecycle transitions honestly.

## Migration Shape

The correct migration order is:

1. define shared native-host contract
2. define Android host seam in Activity + `ANativeWindow` terms
3. make surface creation/loss/replacement explicit in the host contract
4. bind the first backend to that contract
5. validate pause/resume/resize/redraw-needed truth

## Current Code Checkpoint

The shared host seam now carries full Android truth:

- `src/platform/native_host.zig` carries surface availability, size, density,
  redraw-requested, and Android native-window identity with epoch-based
  transition tracking
- `src/platform/host_lifecycle_runtime.zig` owns shared lifecycle/surface
  runtime semantics for Android and desktop host paths; shared code delegates
  there instead of embedding Android logic in SDL paths
- `android/terminal-host/` is the active Android host app for native runtime,
  shell, surface, and product work

Historical note:

- `android/host-harness/` proved the first Java-only lifecycle/surface/focus/IME
  callback ordering and has since been retired from the live tree

## Current Android Boundary

This repo is now explicitly optimizing for Android terminal excellence, not for
renderer/backend cleanup as an end in itself.

That does not mean Android is a throwaway host shell around a Zig-only
product. The current intended shape is:

- strong shared Zig core
- Android-native mobile interaction surfaces where the hardware and OS call
  for them
- no premature commitment yet on whether terminal/editor later ship as one APK
  or multiple products sharing the same core

The Android-native terminal-host lane has now answered its next two honest
Android-specific questions:

- surface identity/replacement truth is explicit enough for future renderer
  work
- PTY lifetime baseline is explicit enough for future Android terminal work
- terminal-host-owned EGL binding is explicit enough to prove real
  `ANativeWindow` + EGL surface lifecycle behavior on-device

The current EGL proof is now stronger than a one-frame clear/swap demo:

- `transition=replaced` recreates the EGL window surface in-process
- `transition=retired` clears the bound surface state
- later fresh `transition=acquired` recreates the EGL window surface cleanly
- the terminal host app now exposes `glesBoundEpoch` and
  `glesSurfaceCreates` so replacement/reacquire behavior can be audited
  directly on-device
- the current Note10 path also keeps `glesContextCreates=1` across those
  transitions, so terminal-host EGL context reuse is honest there today
- the current Note10 path also keeps one terminal-host-owned GLES texture alive
  with `glesTextureCreates=1`, so minimal context-owned resource lifetime is
  honest there today

That means there is no new Android-specific execution lane that should be
opened by default right now.

The next Android move is now `AR-B4`: the first controlled Android GLES backend
planning cut.

That does not mean a broad backend sprint is open. It means the terminal-host
EGL/GLES proof and the renderer gate-5 composition cuts are strong enough to
define the smallest shared-backend entry point.

Service-owned PTY survival may still move only through its own explicit
product lane, not through renderer or generic host drift.

Current priority rule:

- if Android has a stronger Android-owned blocker, do that first
- if Android's strongest blocker is a renderer gate, execute only that exact
  renderer cut and return to the Android queue
- do not let legacy renderer-campaign framing hide the actual Android product
  goal

What is now allowed:

- terminal-host-owned EGL/GLES binding and proof work in `android/terminal-host/`
- `AR-B4.a` Android GLES backend skeleton/frame-binding planning and then the
  first controlled implementation slice named by that plan

What is still not allowed:

- broad Android renderer implementation before `AR-B4.a` names the exact files,
  ownership boundary, validation, and stopping point
- Android Vulkan
- product-specific renderer bypasses

Current Android-native state (see owning plan docs for full evidence):

- `AH-A4` terminal-host bridge: met — `android/terminal-host/` loads the repo
  Zig library, lifecycle/surface callbacks route through
  `host_lifecycle_runtime.zig` and shared host state, surface identity
  transitions (`acquired`, `unchanged`, `replaced`, `retired`) are real on the
  Note10
- `AP-A1` PTY lifetime: met — disposable app-process-owned PTY lifetime is the
  Android terminal baseline; the live shell path in `android/terminal-host/`
  has replaced the earlier probe UI
- `AP-A2` service PTY probe: met — service-owned PTY survival is technically
  viable but has not displaced the disposable baseline as the default answer
- `AH-A5`–`AH-A7` EGL binding + texture probes: met — terminal-host-owned
  EGL/GLES clear/swap and texture upload/update/resize are proved on the Note10;
  one EGL context survives surface replacement; resize forces honest reallocation

## Explicit Anti-Goals

Do not:

- design Android as a deferred backend footnote under the macOS plan
- treat surface loss as incidental cleanup
- assume a persistent top-level window
- force desktop-style host abstractions onto Android

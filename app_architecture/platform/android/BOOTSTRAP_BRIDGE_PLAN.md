# Android Bootstrap Bridge Plan

Purpose: define the first repo-owned Android bootstrap lane for the real Zig
runtime, after host-truth probing and before Android renderer backend work.

This doc is architecture authority for the next Android execution cut after the
host harness.

Owner docs:

- `app_architecture/platform/NATIVE_HOST_CONTRACT.md`
- `app_architecture/platform/android/RENDER_BACKEND.md`
- `app_architecture/platform/android/SURFACE_IDENTITY_POLICY.md`
- `docs/todo/android/implementation.md`

## Why This Is Next

The current tree now has:

- a shared native-host contract that can represent Android lifecycle, focus,
  surface metrics, redraw-needed, and native-window identity
- a first Android-owned host mapper in `src/platform/android_host.zig`
- a repo-owned host harness app that proved real Note10 callback ordering

The current tree still does not have:

- any Android bootstrap path for the actual Zig app/runtime
- Android support in `build_system/platform_capabilities.zig`
- Android support in the current app/executable build graph

So the next blocker is not GLES design. It is bootstrap and native entry.

## Decision

The next Android lane is:

- a repo-owned Android app/bootstrap bridge for the real Zig runtime

It is not:

- Android renderer backend bootstrap
- Android PTY/runtime design
- another host-harness-only improvement pass

## Target Shape

The bootstrap bridge should prove these four things:

1. the repo can build an Android app project for the real runtime lane
2. that app can load a repo-built native Zig library
3. Android lifecycle and surface callbacks can cross the Java/native bridge
4. after native loading is proven, those callbacks can be moved into
   `src/platform/android_host.zig` / `src/platform/native_host.zig` truth
   rather than being trapped in Java glue or a freestanding bridge stub

## Preferred Bridge Direction

Use the practical bridge with the least speculation:

- Android app project in-tree
- Java/Kotlin activity glue as needed
- native Zig library loaded by the app

SDL may still be used later for Android packaging/bootstrap if it reduces
repeated glue, but the bootstrap lane should not wait on a final SDL-vs-native
purity answer before proving the bridge.

The real requirement is:

- repo-owned Android app bootstrap
- native Zig library entry
- lifecycle/surface signal path

## `AH-A4` Scope

Scope:

- create the first repo-owned Android bootstrap path for the Zig runtime
- define the minimal native entry surface the app loads
- prove lifecycle/surface callbacks can reach a native bridge layer
- keep renderer/backend work out of scope

Acceptance:

- the repo contains an Android app/bootstrap project for the real runtime lane
- the app loads a native Zig library built from this repo
- the app can surface at least launch + pause/resume + surface-available/lost
  callbacks into native bridge code
- the owning Android docs explain how to build/install/run that bootstrap path

Current checkpoint:

- `android/bootstrap-bridge/` now exists as the first repo-owned runtime-lane
  Android app
- `ops/android_build_bootstrap_bridge.sh` now builds the Zig bridge through a
  Zig object + NDK clang link path
- the bridge link path now links `libandroid` and rejects unresolved native
  symbols at build time, because `ANativeWindow_fromSurface(...)` and
  `ANativeWindow_release(...)` are part of the real bootstrap surface now
- the Note10 now loads the repo-built Zig library successfully
- first observed native callback acknowledgements are:
  - `native.onCreate seq=1`
  - `native.onStart seq=2`
  - `native.onResume seq=3`
  - `native.surfaceAvailable seq=4`
  - `native.onWindowFocus seq=6`
- the bootstrap bridge now surfaces real `ANativeWindow` identity into
  `PlatformRenderHost`, with the Note10 showing:
  - stable non-zero token across repeated `surface.changed` callbacks
  - stable `surfaceIdentityEpoch=1` across those same-window updates
  - explicit `acquired`, `unchanged`, and `retired` transition labels from the
    shared host seam
  - a later foreground return after `retired` becomes a fresh `acquired`, even
    when the raw token value can recur
  - `token=0x0` and `surfaceIdentityEpoch=2` after `surface.destroyed`
- the bootstrap bridge now routes lifecycle/focus/surface callbacks through
  `src/platform/android_host.zig` and shared host state instead of the earlier
  freestanding sequence stub
- a HOME/background smoke pass on the Note10 now confirms:
  - `native.onPause seq=7`
  - `native.surfaceAvailable seq=8`
  - `native.surfaceAvailable seq=9`
  - `native.onWindowFocus seq=10`
  - `native.surfaceDestroyed seq=11`
  - `native.onStop seq=12`
- enabling shared-host cleanup also landed:
  - `PlatformRenderHost` no longer carries an SDL window pointer
  - SDL-only host capture moved to `src/platform/sdl_native_host.zig`
  - Android SDL refresh capture moved to `src/platform/sdl_android_host.zig`

Do not do:

- no GLES or Vulkan backend bootstrap
- no terminal PTY/service design
- no attempt to make Android a supported production target in the whole build
  graph yet
- no fake renderer integration just to "show pixels"

## Stop Marker

Stop `AH-A4` when:

- the repo can build and install the bootstrap app
- the native library loads successfully on device
- native bridge logging proves lifecycle and surface signals are crossing into
  repo-owned native code
- the next blocker is honestly Android host capability depth beyond native
  entry, not "we still do not have Android entry"

## Next Honest Follow-Up

The next `AH-A4` sub-cut should be:

- tighten Android surface replacement / destruction policy around the now
  explicit native-window token + `surfaceIdentityEpoch` path
- determine whether an in-process `replaced` transition is real on this
  Android path, or whether replacement effectively means `retired` followed by
  later `acquired`
- keep Android PTY/runtime lifetime as a parallel concern, but not the next
  blocker for rendering-oriented host work

The bootstrap-entry problem is now solved well enough that those are the real
next questions.

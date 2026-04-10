# Android Bootstrap Bridge Plan

Purpose: define the first repo-owned Android bootstrap lane for the real Zig
runtime, after host-truth probing and before Android renderer backend work.

This doc is retained as completed architecture authority for `AH-A4`.
`android/terminal-host/` is now the active Android terminal host, not a
future bootstrap proposal.

Owner docs:

- `app_architecture/platform/NATIVE_HOST_CONTRACT.md`
- `app_architecture/platform/android/RENDER_BACKEND.md`
- `app_architecture/platform/android/SURFACE_IDENTITY_POLICY.md`
- `docs/todo/android/implementation.md`

## Decision

The completed lane created:

- a repo-owned Android app/bootstrap bridge for the real Zig runtime

It is not:

- Android renderer backend bootstrap
- Android PTY/runtime design
- a continuation of the retired Java-only host-harness probe

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

- `android/terminal-host/` is the first repo-owned Android runtime app
- `ops/android_bootstrap_bridge.py native` builds the native Zig bridge through
  the NDK toolchain; this should become a named `zig build` step once the
  native artifact shape stabilizes
- the Note10 loads the repo-built native library and routes lifecycle/focus/
  surface callbacks into repo-owned native code
- bootstrap/native entry now carries real shared host truth:
  - `ANativeWindow` identity
  - `surfaceIdentityEpoch`
  - `acquired` / `unchanged` / `replaced` / `retired`
- lifecycle and surface callbacks now terminate through shared Android host
  semantics instead of a private bridge-only model

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

## Current Follow-Up

Bootstrap entry is complete. Active Android work now belongs in:

- `docs/todo/android/implementation.md`
- `app_architecture/platform/android/ANDROID_SHELL_BRINGUP_PLAN.md`

Native bridge production currently lives behind
`ops/android_bootstrap_bridge.py native`. Once the Android native artifact shape
is stable, that build should move behind a named `zig build` step while
deploy/install/logcat stay in ops.

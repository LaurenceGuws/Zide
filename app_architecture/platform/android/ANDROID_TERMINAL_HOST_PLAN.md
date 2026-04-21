# Android Terminal Host Plan

Purpose: define the first repo-owned Android terminal-host lane for the real Zig
runtime, after host-truth probing and before Android renderer backend work.

This doc is retained as completed architecture authority for `AH-A4`.
`android/terminal-host/` is now the active Android terminal host, not a
future host proposal.

Owner docs:

- `app_architecture/platform/NATIVE_HOST_CONTRACT.md`
- `app_architecture/platform/android/RENDER_BACKEND.md`
- `app_architecture/platform/android/SURFACE_IDENTITY_POLICY.md`
- `docs/todo/android/implementation.md`

## Decision

The completed lane created:

- a repo-owned Android terminal host app for the real Zig runtime

It is not:

- Android renderer backend bringup
- Android PTY/runtime design
- a continuation of the retired Java-only host-harness probe

## Target Shape

The terminal host lane should prove these four things:

1. the repo can build an Android app project for the real runtime lane
2. that app can load a repo-built native Zig library
3. Android lifecycle and surface callbacks can cross the Java/native bridge
4. after native loading is proven, those callbacks can be moved into
   `src/platform/host_lifecycle_runtime.zig` / `src/platform/native_host.zig` truth
   rather than being trapped in Java glue or a freestanding bridge stub

## Preferred Bridge Direction

Use the practical bridge with the least speculation:

- Android app project in-tree
- Java/Kotlin activity glue as needed
- native Zig library loaded by the app

SDL may still be used later for Android packaging/bringup if it reduces
repeated glue, but the terminal-host lane should not wait on a final SDL-vs-native
purity answer before proving the bridge.

The real requirement is:

- repo-owned Android terminal host app
- native Zig library entry
- lifecycle/surface signal path

## `AH-A4` Scope

Scope:

- create the first repo-owned Android terminal-host path for the Zig runtime
- define the minimal native entry surface the app loads
- prove lifecycle/surface callbacks can reach a native bridge layer
- keep renderer/backend work out of scope

Acceptance:

- the repo contains an Android app project for the real runtime lane
- the app loads a native Zig library built from this repo
- the app can surface at least launch + pause/resume + surface-available/lost
  callbacks into native bridge code
- the owning Android docs explain how to build/install/run that terminal-host path

Current checkpoint:

- `android/terminal-host/` is the first repo-owned Android runtime app
- the native Zig bridge is now a named build target:
  `zig build android-terminal-host-bridge -Dtarget=aarch64-linux-android
  -Dmode=terminal --sysroot <ndk-sysroot>`
- that build target owns:
  - the Android bridge shared library compile
  - explicit NDK-backed libc configuration
  - explicit Android system `.so` linkage for `android` / `EGL` / `GLESv2`
  - SDL header-only access where shared renderer contracts still mention SDL
- `ops/android_terminal_host.py native` is now only the operator wrapper:
  it resolves SDK/NDK paths, invokes the named Zig target, and copies the
  built `.so` into `jniLibs`
- the Note10 loads the repo-built native library and routes lifecycle/focus/
  surface callbacks into repo-owned native code
- terminal-host/native entry now carries real shared host truth:
  - `ANativeWindow` identity
  - `surfaceIdentityEpoch`
  - `acquired` / `unchanged` / `replaced` / `retired`
- lifecycle and surface callbacks now terminate through shared Android host
  semantics instead of a private bridge-only model
- product gesture policy is now also an explicit Android-host seam:
  - `ProductGestureController` owns touch/pinch detection for the product surface
  - raw Android detector noise is normalized into a small host contract
    (`singleTap`, `pinchBegin`, quantized `pinchZoom`, `pinchEnd`)
  - this keeps product-touch policy local to Android while preventing raw gesture
    churn from leaking directly into shared renderer work
  - current gesture contract extension is explicit too:
    - sidebar swipe is owned by the dedicated edge-hotspot view
    - product-surface vertical drag is the Android-owned scrollback gesture
    - product-surface tap is available for product selection/deselection policy;
      IME ownership lives on the assist bar
    - product-surface long press is reserved for Android-native text
      interaction owned by
      `app_architecture/platform/android/ANDROID_TEXT_INTERACTION_PLAN.md`

Do not do:

- no GLES or Vulkan backend bringup
- no terminal PTY/service design
- no attempt to make Android a supported production target in the whole build
  graph yet
- no fake renderer integration just to "show pixels"

## Stop Marker

Stop `AH-A4` when:

- the repo can build and install the terminal host app
- the native library loads successfully on device
- native bridge logging proves lifecycle and surface signals are crossing into
  repo-owned native code
- the next blocker is honestly Android host capability depth beyond native
  entry, not "we still do not have Android entry"

## Current Follow-Up

Terminal-host entry is complete. Active Android work now belongs in:

- `docs/todo/android/implementation.md`
- `app_architecture/platform/android/ANDROID_SHELL_BRINGUP_PLAN.md`

Native bridge production currently lives behind
`zig build android-terminal-host-bridge`. `ops/android_terminal_host.py`
remains the operator entrypoint for deploy/install/logcat and for copying the
built bridge into the Android app project.

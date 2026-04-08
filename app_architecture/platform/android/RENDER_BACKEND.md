# Android Render Backend

Purpose: define how Android satisfies Zide's native host contract with native
Android lifecycle and native window ownership.

This doc is architecture authority for Android-native render-host shape.

Supporting research:

- `docs/research/terminal/ANDROID_HOST_PTY_SCAN_2026-04-08.md`
- `app_architecture/platform/android/BOOTSTRAP_BRIDGE_PLAN.md`
- `app_architecture/platform/android/SURFACE_IDENTITY_POLICY.md`

## Target Stack

- app host: Android `Activity`
- render host: `Surface` / `ANativeWindow`
- backend: GLES first, with any future Vulkan decision requiring separate
  authority

SDL may remain a bridge for:

- Android bootstrap
- JNI glue
- event routing
- packaging integration

But SDL is not the final owner of:

- Activity lifecycle truth
- surface availability/loss/replacement
- redraw-needed semantics
- pause/resume/stop/destroy sequencing

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

SDL is allowed to remain the practical bootstrap and integration bridge.

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

The first executable Android-host cut is now active in the shared host seam:

- `src/platform/native_host.zig` can now carry:
  - surface available vs unavailable
  - logical and drawable size
  - display scale and pixel density
  - redraw-requested truth
  - Android native window identity slot

This is intentionally not GLES work.

What is still missing:

- Android `Activity` lifecycle mapping into `PlatformAppHost`
- Android `Surface` / `ANativeWindow` event mapping into `PlatformRenderHost`
- focus and IME ownership points
- real redraw-needed / resize / surface-loss event wiring
- Android PTY/runtime lifetime policy against pause/stop/background pressure

Current event-mapping checkpoint:

- the shared SDL input/event path now updates:
  - `PlatformAppHost` lifecycle transitions for foreground/background
  - `PlatformAppHost` surface-focus and text-input-active truth separately
  - `PlatformRenderHost` surface metrics and redraw-requested truth on refresh
    events

This is still shared host plumbing, not Android-specific event ingestion yet.

The first Android-owned mapper seam now exists too:

- `src/platform/android_host.zig` owns the first Android-shaped lifecycle and
  surface helper functions against `PlatformAppHost` and `PlatformRenderHost`
- shared input/runtime code can delegate Android semantics there instead of
  embedding them in renderer-owned logic

The first repo-owned Android bootstrap surface now exists outside `src/`:

- `android/host-harness/` is a plain Android host harness app
- it is for lifecycle/surface/focus/IME validation only
- it is intentionally not SDL, NDK, GLES, or Vulkan bootstrap yet
- first APK build pressure was local environment/tooling state, not a proven
  host-architecture problem

Current validation checkpoint:

- local APK build now succeeds against a writable user-local SDK root with API
  35 packages
- the harness installs and launches on the Note10
- the first observed device log sequence already confirms real lifecycle +
  surface callback ordering before any renderer backend work
- Note10 callback ordering observed so far:
  - first launch:
    - `activity.onCreate`
    - `activity.onStart`
    - `activity.onResume`
    - `surface.created`
    - `surface.changed`
    - `surface.redrawNeeded`
    - `activity.onWindowFocusChanged focus=true`
  - IME show/hide:
    - IME focus is distinct from window focus
    - showing the IME triggers `surface.changed` with a much smaller surface
      height and then `surface.redrawNeeded`
    - hiding the IME restores the larger surface size and redraw request
  - backgrounding:
    - `activity.onPause`
    - `activity.onWindowFocusChanged focus=false`
    - `surface.destroyed`
    - `activity.onStop`

Practical consequences from that Note10 run:

- Android window/surface focus must not be treated as text-input focus.
- IME visibility is geometry and redraw pressure, not lifecycle pressure.
- surface destruction can follow pause during backgrounding, but must still be
  modeled as explicit surface truth rather than inferred from lifecycle alone.

## Next Active Android Lane

The next honest Android step is now:

- `AH-A4` Android bootstrap bridge

Reason:

- the host harness has already proved platform callback ordering on device
- the shared host seam is now ready to receive Android truth
- the repo still has no Android bootstrap path for the actual Zig runtime

So Android progress should now move through app/bootstrap and native-entry
work, not through more host-harness polish and not through premature renderer
backend work.

Current `AH-A4` checkpoint:

- `android/bootstrap-bridge/` now builds and installs on the Note10
- the bootstrap app now loads a repo-built Zig native library successfully
- the bridge build now links `libandroid`, so native-window symbol resolution
  fails at build time instead of later during `System.loadLibrary(...)`
- launch-path native callback acknowledgements are live on device:
  - `native.onCreate seq=1`
  - `native.onStart seq=2`
  - `native.onResume seq=3`
  - `native.surfaceAvailable seq=4`
  - `native.onWindowFocus seq=6`
- the bootstrap bridge now surfaces real native-window identity into
  `PlatformRenderHost`
- the Note10 currently shows one stable non-zero native-window token across
  repeated `surface.changed` callbacks, then `token=0x0` after
  `surface.destroyed`
- the shared host seam now also carries a `surfaceIdentityEpoch` that stayed at
  `1` across those same-window updates and advanced to `2` on
  `surface.destroyed`
- the bridge now routes those callbacks through `android_host.zig` and shared
  host state instead of a private lifecycle stub
- a HOME/background pass now also confirms:
  - `native.onPause seq=7`
  - `native.surfaceAvailable seq=8`
  - `native.surfaceAvailable seq=9`
  - `native.onWindowFocus seq=10`
  - `native.surfaceDestroyed seq=11`
  - `native.onStop seq=12`
- the first shared-host cleanup forced by this lane is also done:
  - `PlatformRenderHost` no longer carries an SDL window pointer
  - SDL-only surface capture moved out of `native_host.zig`
  - Android SDL refresh capture moved out of `android_host.zig`

The next Android-native follow-up is now narrower:

- tighten Android surface replacement / destruction policy around the now
  explicit native-window token + `surfaceIdentityEpoch` path
- keep PTY lifetime pressure as a real Android concern, but not the stronger
  blocker for rendering-oriented host work yet
- do not jump to GLES from native-load success alone

## Explicit Anti-Goals

Do not:

- design Android as a deferred backend footnote under the macOS plan
- treat surface loss as incidental cleanup
- assume a persistent top-level window
- force desktop-style host abstractions onto Android

# Native Host Reference Crosscheck

Purpose: reconcile Zide's current SDL/OpenGL build truth with the native host
and render-surface rules described by the strongest local references and
official platform docs.

This is architecture authority for the current cross-platform native-host
pressure. It is not a platform-specific todo list.

## Why This Exists

The repo already has a working SDL/OpenGL lane on Linux and a compiling
SDL/OpenGL lane on macOS. That is useful build truth, but it is not enough to
define a first-class native-platform architecture.

The current risk is obvious:

- treat the live GL lane as if it already defines the durable host contract
- carve macOS-specific or Android-specific exceptions around that shape
- accidentally make SDL or OpenGL the architecture center instead of the
  platform's native lifecycle and surface rules

This doc names the opposite standard:

- one strict native-host contract across platforms
- explicit per-platform implementations of that contract
- no fake portability
- no platform-specific special-case pile where a shared host contract would do

## Current Live Dependency Truth

Current package/build truth:

- `build.zig.zon` pins SDL as the only cross-platform window/input/native-bridge
  dependency in the app graph
- `build_system/platform_capabilities.zig` still carries the current runtime
  graphics path, but platform authority must now read those values alongside
  host-contract truth instead of reducing each OS to a backend label
- `src/platform/sdl_api.zig` currently creates windows with
  `SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE`
- `src/ui/renderer/window_init.zig` only knows how to configure GL attributes
  and create a GL context

That means the current build/runtime center is still:

- SDL window lifecycle
- GL context lifecycle
- renderer host assumptions that are implicitly GL-shaped

This is acceptable as current implementation truth, but not as the target
native-host architecture.

## Reference Pressure

Strongest local references now available in the workspace:

- SDL backend/native platform docs:
  - `dev_references/backends/sdl/docs/README-macos.md`
  - `dev_references/backends/sdl/docs/README-android.md`
  - `dev_references/backends/sdl/include/SDL3/SDL_metal.h`
- Ghostty macOS reference slice:
  - `dev_references/terminals/ghostty/macos/`
- Zed macOS-native renderer surface:
  - `dev_references/editors/zed/crates/gpui_macos/`
- WezTerm macOS window host:
  - `dev_references/terminals/wezterm/window/src/os/macos`
- Official platform docs mirrored locally:
  - `dev_references/official/apple_metal/`
  - `dev_references/official/android_native/`

## What SDL Actually Gives Us

SDL remains useful and valid, but its role has to be stated honestly.

SDL currently gives Zide:

- cross-platform window creation
- input/event routing
- platform handle/property access
- optional Metal view glue on Apple platforms
- Android activity/JNI integration path

SDL does not remove native ownership pressure where the platform itself has a
real lifecycle or surface model.

Relevant SDL pressure:

- `README-macos.md` explicitly says that if user code registers its own
  `NSApplicationDelegate`, SDL stops owning that delegate path and user code
  must preserve quit/open-file behavior deliberately
- `README-android.md` explicitly says SDL's Android port is built around a Java
  `Activity` shim and JNI-owned lifecycle glue
- `SDL_metal.h` explicitly says SDL can create a CAMetalLayer-backed view, but
  on macOS it does not assign the `MTLDevice`; user code must do that

That means SDL is a bridge, not the architecture center.

## Official macOS Pressure

The Apple Metal docs make the macOS render-surface rules explicit.

From `MTKView.md` and `CAMetalLayer.md`:

- `MTKView` is a Metal-aware view that wraps `CAMetalLayer`
- Metal rendering requires a real `MTLDevice`
- drawable acquisition and presentation are explicit
- drawables must be acquired late and released quickly
- `CAMetalLayer` owns a drawable pool
- drawable starvation is a real failure mode if drawables are retained too long
- AppKit views can host a `CAMetalLayer` directly

Architectural consequence:

- the real macOS render host is view/layer/device/drawable based
- not window + backend-toggle based
- not GL-context based

So a first-class macOS path must be able to express:

- native view ownership
- layer ownership
- drawable-size truth in pixels
- present scheduling through command buffers
- drawable lifetime discipline

## Official Android Pressure

The Android native docs make the Android host rules equally explicit.

From the mirrored Android docs:

- Android app truth is `Activity` lifecycle truth
- `ANativeWindow` is the producer end of an image queue and the C counterpart
  of Java `Surface`
- `ANativeWindow` has explicit width/height and reference ownership
- `android_native_app_glue` exposes start/resume/pause/stop/destroy plus
  init-window/term-window/resize/redraw-needed commands

Architectural consequence:

- the real Android render host is Activity + Surface/ANativeWindow based
- surface availability and surface loss are first-class runtime events
- backgrounding and resume are not optional polish; they are core host truth

So a first-class Android path must be able to express:

- app start/resume/pause/stop/destroy
- native window availability/loss/replacement
- focus and redraw-needed transitions
- pixel-size truth from the native window
- explicit reacquire/recreate behavior

## Cross-Platform Conclusions

The official and reference docs line up on one important point:

- the host contract must be strict on invariants
- but it must not assume one platform's mechanics are universal

Strict invariants that the shared contract must own:

- app lifecycle state transitions
- surface availability / surface loss / surface replacement
- logical size vs drawable pixel size
- scale / density changes
- focus and activation state
- text input / IME ownership points
- present scheduling and completion semantics
- external intent delivery:
  - quit
  - file open
  - URL / deep link
  - permissions / resume paths where applicable

Things the shared contract must not bias:

- AppKit delegate shape
- Android Activity callback shape
- GL context lifetime
- desktop-only window assumptions
- mobile-only suspension assumptions
- one fixed render backend per all platforms

## Why The Current GL Lane Is Not Enough

The live GL dependency path is still valuable, but it currently encourages the
wrong mental model if left unqualified:

- window creation is still hardwired to `SDL_WINDOW_OPENGL`
- platform capability reporting still risks being read as backend truth unless
  paired with explicit native-host wording
- the renderer/window host seam is still defined by GL bring-up needs

That shape is fine for the current build, but it is too narrow for:

- macOS Metal + AppKit
- Android native lifecycle + `ANativeWindow`
- future native Windows/Linux refinements that should not inherit GL-first
  host assumptions

## Required Path Carving

The next durable path is not:

- "macOS special cases around the SDL/OpenGL host"
- "Android later gets its own exceptions"

The next durable path is:

1. define the shared native-host contract
2. define per-platform capability surfaces against that contract
3. then migrate macOS and Android into first-class native implementations
   without inventing platform-specific architecture in isolation

## Immediate Implications For Zide Docs

This crosscheck changes how platform planning should be framed:

- the macOS queue should become one execution lane inside a broader native-host
  architecture campaign
- Android should be planned against the same contract from the start
- `app_architecture/ui/DEVELOPMENT_JOURNEY.md` should stop treating macOS and
  Android primarily as backend phases
- dependency docs should state clearly that SDL is the bridge layer today, not
  the final owner of every native lifecycle and render-surface concern

## Current Decision

Zide should carve a shared native-host path with these properties:

- SDL remains allowed as a portability bridge where it helps
- native platform lifecycle and surface truths remain first-class
- backend selection is downstream of native host ownership, not upstream of it
- platform-specific implementations are expected
- platform-specific architecture drift is not

That is the standard future macOS and Android work must now satisfy.

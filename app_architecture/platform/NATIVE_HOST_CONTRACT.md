# Native Host Contract

Purpose: define the strict shared contract that every first-class native Zide
 platform must satisfy, without forcing one platform's mechanics onto another.

This doc is architecture authority for native app lifecycle, native surface
ownership, render-host state transitions, and platform capability boundaries.

## Why This Exists

Zide now has enough evidence that "renderer backend choice" is not the top
level platform architecture question.

The stronger question is:

- what must the app know and rely on across all native platforms?
- what must remain platform-specific?
- where is SDL allowed to help?
- where must native lifecycle and native surface truth remain explicit?

This contract answers that.

## Design Standard

The contract must be:

- strict on product invariants
- neutral on platform mechanics
- explicit about ownership
- hostile to fake portability

The contract must not:

- encode desktop-only assumptions into mobile hosts
- encode mobile-only suspension behavior into desktop hosts
- assume GL-style context lifetime
- assume Cocoa delegate shape
- assume Android callback shape
- assume SDL owns every native concern

## Ownership Model

Zide native platform architecture is split into these layers:

1. `PlatformAppHost`
2. `PlatformRenderHost`
3. `RendererBackend`
4. `AppRuntime`

### `PlatformAppHost`

Owns:

- native application lifecycle
- foreground/background/activation truth
- platform intent delivery
- focus and text-input entry/exit coordination
- platform-driven shutdown semantics

Examples:

- macOS: `NSApplication` / delegate / app activation / open-file events
- Android: `Activity` lifecycle / intent delivery / pause-resume-stop-destroy

### `PlatformRenderHost`

Owns:

- native render surface availability
- native view/window/surface handle identity
- drawable pixel size truth
- scale/density propagation
- surface loss / replacement events

Examples:

- macOS: `NSWindow` + `NSView` + `CAMetalLayer` or `MTKView`
- Android: `Surface` / `ANativeWindow`

### `RendererBackend`

Owns:

- GPU device/context/queue objects
- backend-specific render target setup
- present registration and completion tracking
- backend resource recreation after host-surface changes

Examples:

- macOS: Metal device / command queue / drawable presentation
- Android: GLES or Vulkan objects bound to the native window

### `AppRuntime`

Owns:

- product logic
- scene submission
- editor/terminal runtime behavior
- shared UI policy

`AppRuntime` must consume normalized host events instead of platform-specific
callback shape.

## Required Shared Invariants

Every first-class native platform must provide these truths to the app.

### Lifecycle

The app must be able to observe:

- started
- resumed / foreground interactive
- paused / losing interactive state
- stopped / background not visible
- terminating / final shutdown

Platforms may map these differently, but they may not omit them.

### Surface Lifecycle

The app must be able to observe:

- no render surface available
- render surface created
- render surface resized
- render surface scale/density changed
- render surface redraw requested
- render surface destroyed / invalidated / replaced

The app must not assume the surface is permanent.

### Geometry

The app must receive:

- logical size if the platform has one
- drawable pixel size
- density / scale data where applicable

Drawable size is the rendering authority. Logical size alone is insufficient.

### Focus / Activation

The app must receive:

- app activation / deactivation
- window or surface focus gained / lost
- text-input focus gained / lost

These are distinct signals and must not be collapsed.

### Text Input / IME

The host must support:

- begin text input
- update text input geometry / candidate anchor
- text composition update
- committed text delivery
- end text input

IME is host-owned interaction, not just keyboard input.

### Present Contract

The contract must support:

- request to draw
- encode against the current render target
- register present against the current platform drawable/surface
- acknowledge that present was submitted

The app must never need to guess whether it still has a valid present target.

### External Intents

The host must normalize delivery of:

- quit request
- open-file / open-document
- URL / deep link
- permission result or resumed-operation result where the platform uses them

Not every platform supports every intent, but unsupported capability must be
explicit.

## Capability Model

The shared contract is not a lowest-common-denominator API. It is a strict base
plus explicit capability declarations.

Capabilities should include at least:

- multiple top-level windows
- menu bar ownership
- app-wide file-open intent
- deep links / URLs
- IME composition
- explicit redraw-needed callbacks
- suspend / resume
- surface replacement without process restart
- platform-owned caption/chrome affordances

If a platform lacks a capability, the contract must expose that honestly.

Use `app_architecture/platform/PLATFORM_CAPABILITY_MODEL.md` for the naming and
reporting rules that distinguish host-contract truth from the current runtime
graphics path.

## SDL Policy

SDL is allowed as a bridge where it improves portability and reduces repeated
host glue.

SDL is not allowed to silently become the architecture center when the platform
has stronger native lifecycle or stronger native surface truth.

That means:

- SDL window/input/events may remain part of the implementation
- SDL property access and helper APIs may remain useful
- SDL may not justify hiding required native lifecycle seams
- SDL may not justify pretending `SDL_WINDOW_OPENGL` defines the durable host
  shape for macOS or Android

## macOS implementation pointers (current tree)

These modules are the live macOS-side expression of the shared contract today.
SDL still bridges window creation and event transport; native handles and
AppKit delegate behavior are explicit rather than implied:

- `src/platform/native_host.zig` — `PlatformAppHost`, `PlatformRenderHost`
- `src/platform/sdl_api.zig` — Cocoa window/view pointers via SDL window properties
- `src/platform/macos_host.zig` — macOS-owned helpers on top of `PlatformAppHost`
- `src/platform/macos_metal_host.zig` — Metal view/layer preparation from the render host
- `src/platform/macos_app_delegate.zig` — `NSApplicationDelegate` proxy feeding lifecycle into `PlatformAppHost`

macOS rendering authority and migration narrative:
`app_architecture/platform/macos/RENDER_BACKEND.md`.

## What This Contract Intentionally Does Not Standardize

The contract does not require:

- one shared delegate/callback shape
- one shared surface object type
- one shared GPU backend
- one shared install or package model
- one shared frame-scheduling mechanism

Those belong to platform implementations.

## Initial Mapping Pressure

The current strongest native-host pressure is:

- macOS:
  - AppKit app lifecycle
  - view/layer/drawable Metal surface
- Android:
  - Activity lifecycle
  - `ANativeWindow` surface lifecycle

These two platforms are deliberately useful tension:

- macOS stresses desktop-native lifecycle and drawable ownership
- Android stresses mobile-native lifecycle and surface loss/replacement

If a shared seam cannot satisfy both cleanly, it is probably not the right
shared seam.

## Current Validation Priority

Linux desktop and Android are the active validation pressure for the current
core cleanup pass. A connected Android device (`RF8M74JDWEK`) is available for
compile/deploy/start/logcat smoke checks when shared terminal presentation or
host attachment paths are touched.

Windows and macOS are catch-up validation platforms for this phase. They should
not block Linux/Android correctness work unless the change directly edits their
platform-owned code or intentionally changes a cross-platform contract they
consume.

## Immediate Consequences For Zide

Future platform work must now follow this order:

1. define or refine the shared native-host contract
2. define the platform-specific backend doc against that contract
3. implement the platform seam
4. only then widen backend/runtime use

The current SDL/OpenGL lane is implementation truth, not contract truth.

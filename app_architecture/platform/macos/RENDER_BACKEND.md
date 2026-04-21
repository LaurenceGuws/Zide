# macOS Render Backend

Purpose: define how macOS satisfies Zide's native host contract with AppKit and
Metal.

This doc is architecture authority for the macOS-native render host and its
relationship to the shared native-host contract.

Implementation companion:

- `app_architecture/platform/macos/METAL_BACKEND_IMPLEMENTATION.md`

Use that doc for the live Metal backend code map, current implementation truth,
and contributor workflow.

## Target Stack

- app host: `NSApplication`
- top-level window host: `NSWindow`
- render host: `NSView` backed by `CAMetalLayer`, or `MTKView` where its higher
  level behavior is useful
- backend: Metal

SDL may remain a bridge for:

- window creation bootstrap
- input/event transport
- Cocoa handle/property access
- optional `SDL_Metal_CreateView` glue

But SDL is not the final owner of:

- app delegate behavior
- file-open / quit integration
- Metal device assignment
- drawable lifetime
- present semantics

## Why Metal Is Non-Negotiable

Reference pressure:

- Ghostty uses Metal on macOS
- Zed uses Metal on macOS
- Apple's current native graphics path is Metal-first

Official pressure from local docs:

- `MTKView` is the standard Metal-aware view and wraps `CAMetalLayer`
- `CAMetalLayer` owns drawable pools and explicit drawable presentation
- Metal requires explicit `MTLDevice` ownership

So the destination macOS renderer is:

- Metal device / queue owned by the backend
- AppKit view/layer owned by the host seam
- present registered per drawable

## Render Host Object Model

The macOS host must expose these concrete centers:

- application object
- window object
- view object
- layer object
- drawable pixel size

The critical rule is that the render surface is view/layer based, not window
based. The window contains the view, but the actual render contract is with the
layer-backed view and its drawables.

## `MTKView` Versus Direct `CAMetalLayer`

Both are acceptable in principle, but they imply different ownership profiles.

### `MTKView`

Pros:

- already wraps `CAMetalLayer`
- already provides `currentRenderPassDescriptor`
- already provides `currentDrawable`
- already has drawable-size and draw-timing support
- easier first honest bring-up

Cons:

- higher-level behavior than Zide may eventually want
- can hide some layer-level choices behind MetalKit defaults

### Direct `CAMetalLayer`

Pros:

- most explicit ownership
- no framework-level draw-loop assumptions
- clearer long-term if Zide wants a fully explicit render host

Cons:

- more bring-up code immediately
- more resize/drawable plumbing to own from the first cut

## Initial Decision

The first macOS-native bring-up may use `MTKView` if and only if:

- the shared host contract still stays explicit
- no important ownership is hidden
- the render host still reads as AppKit view + drawable based

The long-term authority remains:

- AppKit view/layer/drawable ownership is the center
- not "MetalKit made it easy"

## First Honest Native-Host Target Note

This is the concrete macOS-side target for the shared native-host contract.

### Destination Statement

Zide on macOS is targeting:

- `PlatformAppHost`: AppKit-native application lifecycle ownership
- `PlatformRenderHost`: Cocoa window/view render host with explicit drawable
  pixel-size truth
- `RendererBackend`: Metal

The durable surface is:

- `NSApplication`
- `NSWindow`
- `NSView` backed by `CAMetalLayer`, or an `MTKView` used as a thin host-owned
  convenience wrapper

The durable present contract is:

- backend acquires a drawable from the current layer-backed view
- backend encodes against that drawable's render target
- backend registers present on the command buffer
- host/backend discard drawable references immediately after commit

### Ownership Split

Shared native-host seams own:

- normalized lifecycle states
- normalized focus and text-input entry/exit
- normalized surface created/resized/destroyed/replaced signals
- logical size, drawable size, and scale propagation
- normalized external intents such as quit and open-file

SDL bridge seams may own:

- bootstrap window creation while the host seam is still transitioning
- event transport where it remains useful
- Cocoa handle/property access
- optional Metal-view helper glue

macOS AppKit/Metal seams must own:

- final `NSApplication`/delegate behavior when native lifecycle authority is
  required
- final `NSWindow` and Cocoa view truth
- layer assignment and view-backed drawable authority
- Metal device and command queue ownership
- drawable acquire/present/release discipline

### Anti-Fiction Rule

The macOS implementation is allowed to use SDL during migration.

It is not allowed to describe:

- `SDL_WINDOW_OPENGL` as the durable render-host model
- a GL context as the durable macOS presentation contract
- SDL's delegate defaults as the durable app lifecycle story

## Required macOS Host Guarantees

The macOS implementation must provide:

- application activation/deactivation truth
- file-open and quit intent routing
- window focus truth
- text input / IME geometry updates
- drawable pixel size truth
- display scale / Retina change truth
- redraw scheduling consistent with the chosen view model

## Drawable Contract

From the Apple docs, Zide must obey:

- acquire drawables late
- retain drawables only briefly
- register presentation on the command buffer
- release references promptly after commit

That means the render loop must be shaped around drawable lifetime, not around
long-lived "current frame target" assumptions.

## Resize And Scale

The macOS host must treat these as separate but related:

- logical view size
- drawable pixel size
- backing scale / Retina scale

The backend must render to drawable pixels. View-space layout may be logical,
but drawable-size changes are the render truth.

## App Lifecycle Boundary

macOS is not just a render problem. The native host must define what happens
when Zide owns or supplements app delegate behavior.

Important SDL pressure:

- if user code owns `NSApplicationDelegate`, SDL no longer owns quit/open-file
  behavior automatically

Therefore the macOS host boundary must explicitly preserve:

- quit requests
- file-open requests
- activation behavior

This is not optional polish.

## SDL Role On macOS

SDL is still useful for:

- initial window bootstrap
- input event transport
- Cocoa handle/property access
- potentially `SDL_Metal_CreateView`

SDL must not define:

- the final view/layer ownership model
- the app delegate contract
- the Metal device and drawable contract

## Migration Shape

The correct migration order is:

1. define shared native-host contract
2. define macOS host seam in AppKit terms
3. expose or create the Cocoa view/window handles deliberately
4. attach the Metal render host
5. bring up clear/present with honest drawable ownership
6. only then widen renderer feature work

## Authority Split

Use this file for:

- AppKit/window/view/layer/drawable architecture
- native-host boundary decisions
- destination render-host ownership

Use `METAL_BACKEND_IMPLEMENTATION.md` for:

- live Metal backend structure
- frame/draw/text/present implementation truth
- debugging and contributor guidance

## Ranked Contradiction Audit Versus The Live SDL/OpenGL Lane

This is the current ranked blocker list between Zide's live macOS build truth
and the desired first-class macOS host shape.

### 1. Window creation is still hardwired to a GL host contract

Current code:

- `src/platform/sdl_api.zig` creates windows with
  `SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE`

Why this is a blocker:

- it defines the live window contract around GL context creation
- it prevents the render host from being described honestly as a Cocoa
  view/layer surface
- it keeps the host seam backend-first instead of surface-first

Classification:

- shared native-host contradiction
- not macOS-only

Because:

- Android will also need a surface-first host seam instead of a backend-first
  window contract

### 2. Renderer bring-up only knows GL attribute and context ownership

Current code:

- `src/ui/renderer/window_init.zig`

Why this is a blocker:

- initialization is expressed as `configureGlAttributes` plus
  `createGlContext`
- there is no render-host seam for native view/layer attachment
- there is no neutral place for drawable-backed render-surface ownership

Classification:

- shared native-host contradiction
- not macOS-only

Because:

- the same seam must later support `ANativeWindow` on Android without routing
  through GL-centric assumptions

### 3. App lifecycle ownership is still implicit in SDL bootstrap

Current pressure:

- `window_init.zig` handles SDL init and app naming hints
- there is not yet an explicit `PlatformAppHost` boundary in code

Why this is a blocker:

- AppKit delegate ownership, activation, quit, and open-file delivery do not
  yet have a first-class home
- the repo can currently compile on macOS without answering who owns the real
  native lifecycle

Classification:

- shared native-host contradiction with strong macOS-specific pressure

Because:

- macOS forces the question early through `NSApplicationDelegate`
- Android will force the same question later through Activity lifecycle truth

### 4. Build metadata still reflects implementation truth more strongly than host truth

Current code:

- `build_system/platform_capabilities.zig`

Why this was a blocker:

- platform description was previously backend-first
- that encouraged treating the live GL lane as the platform architecture

Current status:

- architecture wording is now corrected to distinguish host contract from the
  current runtime graphics path
- implementation remains GL-first, so this contradiction is reduced but not
  eliminated

Classification:

- shared architecture contradiction

### 5. The current live lane has no drawable-lifetime discipline

Current reality:

- the GL path presents through SDL/GL swap semantics
- the code does not yet express drawable acquisition, drawable loss, or
  drawable release as first-class behavior

Why this is a blocker:

- Metal correctness on macOS depends on drawable lifetime discipline
- surface replacement and reacquire semantics matter on Android too, even
  though the concrete objects differ

Classification:

- shared native-host contradiction with different platform mechanics

## Immediate Consequences

The first code cuts should not be "make a Metal renderer under the existing GL
host seam."

They should be:

1. define a neutral host-facing app lifecycle seam
2. define a neutral host-facing render-surface seam
3. let macOS satisfy those seams with AppKit/Cocoa view truth
4. then bind Metal to that surface contract

## First Code-Groundwork Checkpoint

The first seam cut in code is now in place:

- SDL window creation no longer hardcodes OpenGL as the only possible window
  graphics binding
- renderer bring-up explicitly requests `.opengl` instead of inheriting that
  choice from a hidden SDL helper default
- SDL wrapper accessors now expose Cocoa window and view pointers for the next
  AppKit-boundary cut
- shared platform-owned host structs now exist for:
  - `PlatformAppHost`
  - `PlatformRenderHost`
  - `RenderSurfaceBinding`
- `PlatformAppHost` now tracks live lifecycle state transitions on the current
  runtime path for focus gain, focus loss, and termination requests
- `PlatformAppHost` now carries the first explicit external-intent shape:
  quit, activation, and open-file request payload ownership
- existing Windows-native chrome consumers now resolve native window handles
  through `PlatformRenderHost` instead of querying SDL properties directly
- macOS now has a platform-owned Metal attachment target helper above the
  shared render host contract
- macOS now has a platform-owned Metal host preparation shim that accepts the
  attachment target without exposing SDL details
- renderer initialization now has an explicit render-surface attachment phase
  before backend context creation
- OpenGL attribute and context creation now live under the OpenGL backend
  module, not under generic window initialization
- macOS now performs a real Metal-backed view/layer attachment through SDL's
  Metal bridge
- a minimal Metal backend context module now exists beside the GL backend
- Metal host lifetime is now owned by the stored render-surface attachment and
  cleaned up during renderer teardown
- Metal backend context creation now allocates a real `MTLDevice` and configures
  the attached `CAMetalLayer`

Current repo locations:

- `src/platform/native_host.zig`
- `src/platform/macos_host.zig`
- `src/platform/macos_metal_host.zig`
- `src/platform/sdl_api.zig`
- `src/platform/windows_frame_material.zig`
- `src/platform/windows_integrated_frame.zig`
- `src/platform/windows_snap_layout_sink.zig`
- `src/ui/renderer/window_init.zig`
- `src/ui/renderer.zig`

What this does and does not mean:

- this is a real host-seam improvement because window creation is no longer
  synonymous with GL
- this is a real ownership improvement because renderer state now carries a
  shared platform host snapshot instead of only raw SDL window plus GL context
- this is a real lifecycle improvement because shared host state is now updated
  by the live event path instead of waiting for future AppKit-only wiring
- this is a real intent-boundary improvement because future AppKit delegate
  work now has an owning contract for quit/open-file/activation delivery
- this is a real cross-platform proof point because the seam is already serving
  existing Windows-native platform code, not only future macOS work
- this is a real macOS preparation cut because Metal attachment now has a
  platform-owned target API based on Cocoa window/view handles
- this is a real macOS host-preparation cut because the first Metal host object
  can now be prepared without inventing SDL-shaped APIs
- this is a real bring-up-order correction because surface attachment is now a
  first-class step before backend context setup
- this is a real ownership correction because backend-specific context creation
  is no longer mixed into generic window/bootstrap code
- this is a real native surface step because the macOS Metal host now owns a
  real SDL-created Metal view and backing layer
- this is a real backend-shape step because Metal now has an explicit backend
  module instead of living only as future intent in docs
- this is a real lifetime correction because the Metal host is no longer
  recreated on each preparation call and its SDL view now has teardown
  ownership
- this is a real backend-configuration step because the Metal path now sets
  layer device, pixel format, framebuffer-only mode, and drawable size
- this is a real queue/present groundwork step because the Metal backend now
  creates a command queue and defines an explicit drawable acquire/present
  skeleton around `nextDrawable`, command-buffer creation, `presentDrawable:`,
  and `commit`
- this is a real render-pass step because the Metal backend can now encode a
  minimal clear pass against the acquired drawable before presentation
- this is a real smoke-path step because renderer/shell code can now drive a
  one-frame Metal clear/present probe against the attached macOS host surface
- this is a real startup-seam step because renderer bring-up now chooses its
  requested backend explicitly before window creation and surface attachment,
  instead of assuming that startup means OpenGL
- this is a real honesty step because full `Renderer.init` now rejects the
  Metal path with an explicit runtime-not-ready error instead of pretending the
  GL-driven renderer core is already backend-neutral
- this is a real startup-proof step because the dedicated Metal startup smoke
  path uses the same window -> host capture -> surface attachment -> backend
  context order as the future live runtime
- this is a real frame-ownership step because `beginFrame` and `submitFrame`
  now route through explicit renderer-backend hooks instead of making
  `SDL_GL_SwapWindow` the structural definition of presentation
- this is a real contract step because the GL lane remains the live
  implementation, while non-GL runtime submission is still explicitly refused
  instead of being half-implemented behind generic frame code
- this is a real lifecycle-source step because `PlatformAppHost` now receives
  open-file intents from `SDL_EVENT_DROP_FILE` and macOS app
  foreground/background/terminate signals from a real SDL event watch instead
  of only from helper calls and window-focus inference
- this is a real AppKit-boundary step because macOS now installs a proxy
  `NSApplicationDelegate` that updates `PlatformAppHost` for activation,
  resign-active, terminate, and open-file while forwarding those selectors to
  the previous delegate instead of blindly replacing SDL-owned behavior
- this is a real live-Metal-runtime step because `Renderer.init` can now create
  a live `.metal` renderer instance under a minimal backend-smoke profile,
  owning a Metal backend context and clear/present frame submission on the real
  window surface
- this is now runtime-validated on the current macOS host through the
  live smoke entry: a live `.metal` backend-smoke shell presented frames
  successfully with sequence advancement through both the env gate and the
  explicit `--macos-metal-live-smoke` startup switch
- this is a real honesty step because GL scene targets, fonts, and the full UI
  path still stay behind the OpenGL/full-ui profile instead of pretending they
  already run on Metal
- this is a real composition-seam step because retained targets are now an
  explicit capability instead of a structural assumption, and the editor path
  can fall back to direct composition when retained targets are unavailable
- this is a real composition-ownership step because the renderer now tracks an
  explicit main-composition target mode instead of treating "scene frame
  active" as shorthand for offscreen GL composition; direct-to-window and
  backend-surface composition are now first-class states
- this is a real scene-target capability step because scene-target
  invalidation, readiness, and teardown now respect whether scene targets are a
  live renderer capability instead of queuing GL-shaped offscreen work on
  unsupported paths
- this is a real scene-composition planning step because the renderer now has
  an explicit scene-composition mode (`direct_main_target` versus
  `offscreen_scene_target`) and frame bring-up consults that plan instead of
  inferring composition behavior from whether a GL scene target happens to
  exist
- this is a real capability-model step because scene composition, retained
  targets, and screenshot semantics now flow through a shared renderer
  capability surface instead of being scattered as unrelated per-feature
  backend checks
- this is a real text-path seam step because text rendering now has an
  explicit capability mode; the current full-ui path declares GL texture-atlas
  text explicitly, and unsupported paths no longer pretend that text rendering
  is universally available
- this is a real destination-truth step because the renderer capability
  snapshot now carries both the live text mode and the planned destination
  mode; the macOS Metal smoke reports that gap directly as
  `text=unavailable planned_text=metal_texture_atlas`
- this is a real diagnostic-text step because the existing font-sample view no
  longer silently bypasses capability truth; on unsupported runtime paths it
  now reports the live/planned text mode gap instead of pretending GL atlas
  text is available everywhere
- this is a real glyph-atlas ownership step because `TerminalFont` no longer
  exposes raw atlas textures as if every backend owned the same storage model;
  atlas storage is now an explicit seam with live/planned capability truth
  (`opengl_textures` today on the GL full-ui path, `metal_textures` as the
  Metal destination), and the macOS Metal smoke reports that gap directly as
  `atlas=metal_textures planned_atlas=metal_textures`
- this is a real Metal atlas-resource step because the Metal backend now owns a
  concrete glyph-atlas object with backend-owned coverage/color textures and
  live upload entry points; the macOS Metal smoke now reports
  `atlas_ready=1`, which means the Metal atlas center is initialized and has
  accepted diagnostic upload data even though the live text path is still
  correctly reported as unavailable
- this is a real shared atlas-upload step because font rasterization and
  special-glyph sprite creation no longer issue direct GL atlas writes from
  their own logic; they now write through `TerminalFont`'s atlas-upload seam,
  which preserves current GL behavior while making atlas upload ownership an
  explicit contract instead of a hidden OpenGL side effect
- the current diagnostic truth is now materially stronger: the macOS Metal
  smoke attempts a real uploaded-glyph atlas probe via a temporary
  `TerminalFont` with Metal atlas-upload hooks, and the current host now
  reports `atlas_upload_probe=1 atlas_preview_source=uploaded_coverage_glyph`,
  which means the visible preview is sourced from a real uploaded glyph rect
  rather than seeded atlas content
- the atlas-backed sample path is now backend-owned rather than embedded in
  smoke-only renderer glue: the renderer stores a
  `metal_backend.AtlasSampleDraw` description, and the Metal backend owns the
  actual sampled-atlas blit helper used during submit before present
- the first dedicated Metal text diagnostic view now exists as its own UI seam
  rather than being embedded directly in the smoke runtime: activation goes
  through `ui/metal_text_diagnostic_view.zig`, which calls
  `Renderer.runMetalAtlasUploadDiagnostic` on `shell.rendererPtr()`; preview
  placement is computed from `UiGeometryContext` in
  `renderer/metal_text_diagnostic_runtime.zig` (no `renderer.zig` import there),
  while backend sampling/blit ownership remains in `metal_backend`
- the diagnostic view does not compute placement against a Shell API: the
  margin-to-inset mapping is shared helper logic keyed only on geometry, and the
  upload probe itself is a **`Renderer`** verb (not an `app_shell` forward)
- one real diagnostic caller now reuses that seam instead of remaining
  structurally GL-only: the existing `font_sample` view activates the Metal
  text diagnostic view when live text is unavailable and the planned text mode
  is `metal_texture_atlas`, which keeps the path honest without pretending the
  generic text renderer has already migrated
- there is now a dedicated startup/runtime lane for the Metal text diagnostic
  seam itself: `--macos-metal-text-diagnostic` brings up the backend-smoke
  renderer, activates the Metal text diagnostic view, and validates present
  sequencing plus optional present-capture screenshots without depending on the
  broader live-smoke runtime
- the first actual narrow text draw path now exists on the Metal side: the
  renderer can upload and place a tiny ASCII sampled-text run through the
  Metal atlas contract, and the dedicated text-diagnostic lane now reports
  `sample_text_draw=1` on the current macOS host
- the tiny sampled-text run is no longer just renderer-local logic: it now has
  a dedicated runtime builder in `renderer/metal_text_sample_runtime.zig`,
  which is the right contract direction for growing from ad hoc sampled draws
  toward a real Metal text lane
- that builder now has an explicit `SampleTextRequest` contract, so callers can
  describe sampled-text placement without staying coupled to the renderer’s
  convenience overloads
- that sampled-text contract now carries explicit tint and layout policy, so
  the Metal diagnostic lane is no longer limited to white-only copied atlas
  pixels or to implicit glyph-advance stepping
- that same sampled-text contract now carries explicit clip ownership, so the
  narrow Metal text lane can obey widget/view bounds instead of only drawing
  unconstrained diagnostics
- the first terminal-facing fallback now exists on top of that contract: when
  live text is unavailable but the planned mode is `metal_texture_atlas`, the
  terminal cell path can route narrow ASCII cells through the sampled Metal
  lane with per-cell bounds and tint instead of dropping straight to empty text
- that terminal-facing fallback is no longer forced through the generic
  sampled-text request shape: there is now a dedicated terminal-cell-run
  request and builder for tiny terminal-style rows, and the live macOS Metal
  text diagnostic reports `terminal_cell_run_draw=1` on the current host
- clip ownership is now more renderer-native instead of purely caller-threaded:
  the renderer keeps clip state from `beginClip`/`endClip`, and the narrow
  Metal sampled-text and terminal-cell-run lanes inherit that active clip when
  callers do not override it explicitly
- that inherited clip state is now exercised in the live terminal-row proof
  itself rather than only existing as an optional helper: the macOS Metal text
  diagnostic enters a renderer clip and draws the terminal row without an
  explicit row clip rectangle, which is the right direction for real widget
  flows
- more real renderer flows can now hit the terminal-shaped Metal lane instead
  of only bespoke diagnostics: monospace text fallback paths route through the
  narrow terminal-cell-run contract when live text is unavailable and planned
  text is `metal_texture_atlas`
- that same fallback coverage now reaches the terminal grapheme entry points
  too: when live text is unavailable, base-codepoint grapheme cells degrade to
  the narrow ASCII/base-cell Metal lane instead of dropping straight to empty
  text whenever the base codepoint is representable by the current fallback
- the terminal-row contract now has a real terminal-grid foothold too: when a
  shaped span collapses to fallback under the Metal-planned/unavailable-text
  path, contiguous ASCII single-cell runs are emitted through the row-shaped
  Metal lane instead of only degrading one cell at a time
- the terminal composing-text overlay can now use that same row-shaped Metal
  lane when the runtime is in the Metal-planned/unavailable-text state and the
  active composition string is ASCII, which gives the lane another real
  terminal-facing caller outside the diagnostic runtime
- the terminal debug capture surface now records Metal row-run fallback usage
  too, split between grid-driven row runs and overlay-driven row runs, so this
  lane has direct terminal-widget proof instead of only indirect architecture
  claims
- those same counts now flow into the live terminal frame-metrics surface, so
  Metal row-run fallback activity is queryable without relying only on the
  visible-view debug dump path
- there is now a dedicated `--macos-metal-terminal-diagnostic` runtime as
  well: it seeds a deterministic external-transport terminal session, draws a
  real `TerminalWidget` through the Metal backend-smoke path, and logs the
  row-run fallback counts from both widget debug state and live frame metrics
- that terminal-facing proof is now more honest about presentation ownership
  too: when retained targets are unavailable on the Metal backend-smoke path,
  terminal surface presentation can fall back to direct main-target
  composition instead of dying at
  `terminal_surface_unavailable_for_present`
- current truth from the short deterministic runtime is now stronger without
  pretending the broader terminal lane is finished: terminal-grid row fallback
  is observed on the current macOS host (`grid_runs=10/224` in the 4-frame
  run), and the composing-text overlay row path is observed in that same run
  too (`overlay_runs=1/5`)
- that overlay proof matters because the direct main-target terminal fallback
  now preserves the normal overlay phase instead of short-circuiting before
  IME/composition drawing, which is the correct layering for a non-retained
  Metal terminal path
- the Metal terminal/text diagnostic lane is now less structurally noisy too:
  sampled Metal text requests reuse a renderer-owned diagnostic `TerminalFont`
  instead of reinitializing a fresh font stack on every sampled draw call,
  which keeps runtime proof honest enough to profile backend behavior rather
  than repeated font bootstrap work
- direct main-target terminal presentation is also less feature-incomplete
  now: the same Kitty image below-text and above-text ordering used by the
  retained path is applied on the non-retained Metal terminal path too, so the
  presentation contract is less "text-only" even though a dedicated Kitty
  proof runtime still had not been added yet
- that dedicated Kitty-facing proof now exists inside the terminal Metal
  diagnostic runtime itself: it seeds deterministic below-text and above-text
  Kitty placements on the current host and proves the next real boundary
  honestly
- Kitty images now have a real Metal-native raw-image lane on the terminal
  backend-smoke path instead of only a cleanly-gated unsupported boundary:
  the renderer owns ordered `SurfaceDraw` submission for both atlas text and
  frame-scoped raw image textures, so below-text Kitty, sampled text, and
  above-text Kitty can share the same live Metal present order
- the terminal presentation shape is now explicit in the shared capability
  surface too: the current macOS Metal terminal lane reports
  `terminal_present=direct_snapshot_cache`, which is better than inferring
  terminal behavior indirectly from `retained_targets=0` and better matches
  the real lane contract than the older `direct_main_target` label
- that direct-main-target lane now also owns a backend-native presentable
  reuse story instead of behaving like a permanently one-shot path:
  after the first successful Metal terminal frame, the backend captures a
  persistent drawable-sized snapshot texture and the terminal presentable seam
  can reuse that snapshot on later fast-present frames without pretending the
  lane has already become a retained-surface path
- capability truth now names that lane honestly as a direct present path with
  snapshot cache support, while per-frame presentation samples continue to
  distinguish the initial full draw (`direct_main_target`) from steady-state
  snapshot reuse (`direct_snapshot_presentable`)
- that presentation mode is now also published through terminal frame metrics
  and the terminal diagnostic lane, so the live contract is visible both at
  startup capability time and per-frame widget evidence time
- terminal debug capture is now aligned with that contract too: terminal
  presentation samples are mode-aware instead of being implicitly
  "retained-surface or invalid", so the live direct-main-target Metal lane can
  leave first-class presentation evidence in widget debug state
- terminal widget surface state is less GL-shaped now too: readiness is tracked
  as `presentable_ready` instead of `texture_ready`, which matches the current
  contract where Metal can present directly without a retained texture-backed
  surface
- the terminal planning helper surface is less GL-shaped too: viewport-shift
  and update-plan decisions are now named in terms of presentation rather than
  texture ownership, which better matches both retained and direct-main-target
  terminal modes
- the same cleanup now reaches terminal presenter/state internals too:
  update deltas, geometry, update plans, execution results, and present-state
  helpers are named around presentation instead of retained surfaces, which
  makes the current direct-main-target Metal lane less architecturally
  second-class inside the widget implementation
- terminal debug geometry now matches that same contract too: the debug sample
  type/field are named around terminal presentation rather than retained
  surfaces, so the debug model no longer treats direct-main-target Metal as a
  special case wearing retained terminology
- direct terminal presentation now updates readiness truth honestly too: after
  the first successful direct-main-target Metal frame, widget handoff logs
  report `presentable_ready=1` instead of staying stuck at a retained-only
  readiness value
- the Metal terminal diagnostic now proves that snapshot-backed presentable
  reuse explicitly too: it starts with `snapshot_available=0` at capability
  time and reports `snapshot_available=1` from frame 0 onward, which confirms
  the live Metal terminal lane now has a reusable presentable cache under the
  `direct_snapshot_cache` contract
- the reuse path is now actually exercised on the current host instead of only
  existing as latent cache state: frame 0 still reports
  `metric_present_sample=direct_main_target`, while later steady-state frames
  report `metric_present_sample=direct_snapshot_presentable` with zero
  grid/overlay/Kitty presentation work, which proves the direct Metal lane can
  fast-present the cached snapshot when generation and clear-generation remain
  unchanged
- that steady-state present-sample mode is now published through the general
  terminal draw-latency surface as well, so non-diagnostic terminal runs can
  distinguish a full direct draw from snapshot fast-present reuse without
  depending on the dedicated Metal terminal diagnostic runtime
- the snapshot-cache availability check is stricter now too: the Metal lane
  only treats the cache as presentable when the cached snapshot still matches
  the live drawable size, which prevents resize-time reuse of a stale snapshot
  just because terminal generation state happened not to change
- the submission/retirement contract is now honest for this lane too:
  direct full draws and direct snapshot fast-presents both mark the submitted
  terminal generation in the frame trace, so publication retirement no longer
  depends on retained-surface-only evidence and the handoff logs now advance
  from `presented=0` to the live generation after the first successful Metal
  terminal frame
- that contract is now named honestly too: the frame-submission and present
  trace surfaces use terminal-presentation terminology instead of
  `terminal_surface_*`, which matters because the active Metal lane is no
  longer "a surface blit when retained, otherwise an exception" but one
  terminal presentation contract with multiple concrete shapes
- the terminal-owned presentation-target seam now owns Metal snapshot
  preparation as well as availability/draw: presentable allocation for the
  live Metal lane no longer exists only as an implicit side effect of submit-
  time capture
- the Metal snapshot-presentable draw contract is more correct now too:
  snapshot presents use explicit raster-space source and destination regions
  instead of implicitly sampling the whole drawable texture, which is required
  for terminals that do not fill the entire window
- the direct Metal terminal lane now has a partial-update seam too, not only
  full direct redraw and steady-state snapshot fast-present: when the runtime
  can produce an honest partial plan without Kitty image participation, the
  renderer can seed the current frame from the cached snapshot and redraw only
  the dirty terminal rows on top
- that new direct partial path is intentionally scoped honestly: Kitty-bearing
  frames still stay on the full direct redraw path for now, because the Metal
  lane does not yet have a separate image-delta update contract that would let
  partially redrawn frames reuse cached Kitty content without ambiguity
- view-cache publication now avoids two footguns that prevented honest partial
  planning on the live path: the poll tail no longer republishes the same
  generation immediately after `publishParsedOutput` when bytes were processed
  (transport + PTY), which used to run row-hash refinement twice and could
  strip partial damage before the widget snapshot copy; `assignDirtyRows` /
  `assignDirtySpans` now copy the grid partial row and span maps whenever
  `view.dirty == partial` even when `visible_history_changed` is true, instead
  of expanding to every row at full width from that flag alone (which pushed
  `decideFullFrameFastPath` over the full-frame threshold)
- two more presentation-plan bugs blocked `direct_snapshot_update` even when
  the published cache was honestly `partial` with tight `damage`: the
  full-frame fast-path heuristic now prefers the published damage bounding box
  when texture scroll rows are not actually applied and blink is not forcing
  row-wide partial work, instead of treating conservatively dense `dirty_rows`
  as proof the union covers ~85% of the grid; the direct Metal path now calls
  `notePresentationUpdated` (including after snapshot fast-present) so
  `presentationUpdateDelta` no longer reports perpetual `cell_metrics_changed`
  from stale zeroed cell-metric baselines the first time `planUpdate` runs
- the Metal terminal diagnostic runtime disables the default recent-input
  force-full publication policy, drops the old fake IME/composing input stub,
  and when `ZIDE_MACOS_METAL_TERMINAL_DIAGNOSTIC_PARTIAL_UPDATE_FRAME` is set
  it also disables terminal texture-shift planning for that run and can enqueue a single-cell mutation on the
  chosen frame; pair with `ZIDE_MACOS_METAL_TERMINAL_DIAGNOSTIC_DISABLE_KITTY`
  for a no-Kitty partial attempt
- runtime proof: with `ZIDE_MACOS_METAL_TERMINAL_DIAGNOSTIC_DISABLE_KITTY=1` and
  `ZIDE_MACOS_METAL_TERMINAL_DIAGNOSTIC_PARTIAL_UPDATE_FRAME` pointing at a
  single-cell mutation frame, the diagnostic reports
  `metric_present_sample=direct_snapshot_update` and tight grid fallback counts
  (for example `grid_runs=1/1` for one ASCII cell) on the partial frame
- that same recent-input policy can no longer force real interactive Metal
  terminal sessions back onto the expensive full direct-present path: on a
  live `nvim -u NONE -N` cursor-move probe, the direct Metal lane now stays on
  `direct_snapshot_update` for Up-arrow frames instead of regressing to
  `direct_main_target`; the measured active move frame on the current host
  dropped from the earlier ~15-28 ms full-redraw range to about `draw_ms=2.196`
  with `term_draw_present_ms=1.809`
- Metal snapshot scrolling now exists under the presentable target seam too:
  the terminal target runtime can shift the drawable-sized Metal snapshot cache
  through a backend-owned scratch texture instead of hard-failing every
  `scrollPresentable` attempt
- runtime proof for that scroll lane now exists too: with
  `ZIDE_MACOS_METAL_TERMINAL_DIAGNOSTIC_DISABLE_KITTY=1`,
  `ZIDE_MACOS_METAL_TERMINAL_DIAGNOSTIC_SCROLL_FRAME=1`, and
  `ZIDE_MACOS_METAL_TERMINAL_DIAGNOSTIC_SCROLL_OFFSET=1`, the diagnostic now
  reports `cache_dirty=partial` and
  `metric_present_sample=direct_snapshot_shift_update` with tight exposed-row
  redraw counts (currently `grid_runs=1/28`) instead of a full direct redraw
- the Metal terminal diagnostic can now also run a special-glyph stress
  fixture directly (`ZIDE_MACOS_METAL_TERMINAL_DIAGNOSTIC_SPECIAL_GLYPHS=1`),
  which exercises powerline, shades, box-drawing, and braille rows under the
  live Metal terminal lane instead of only ASCII dashboard rows
- that fixture exposed and fixed a real routing contradiction on the Metal
  lane: the `text=unavailable` terminal fallback path had been swallowing
  special glyph cells before the normal special-glyph pipeline could run,
  which meant `btop`-class rows were quietly bypassing the sprite/analytic
  path even though the code already existed
- current runtime proof on that fixture is now materially better: the first
  Metal terminal frame reports `special_sprite_glyphs=37` and
  `shaped_special_glyphs=37`, and the log shows real sprite creation for the
  powerline separator set (`U+E0B0..U+E0B7`) on the current host
- that runtime proof is also now classed enough to guide the next execution
  slice instead of only proving “some special glyphs happened”: the current
  fixture originally exposed a classification bug where filled powerline
  separators were still riding the `.box` lane; that is now fixed, so the same
  proof reports `powerline=10 shade=3 braille=7 box=17 other_special=0`
- that tighter split is the current best runtime statement of where the next
  `btop`-class pressure lives: powerline is now materially more honest, and
  the remaining gap is the broader box/block continuity quality itself rather
  than hidden ownership ambiguity inside the special-glyph router
- there is now also a denser `btop`-ish Metal terminal fixture under the same
  diagnostic runtime (`ZIDE_MACOS_METAL_TERMINAL_DIAGNOSTIC_DASHBOARD=1`),
  with mixed box borders, shades, braille spark blocks, and powerline status
  bars instead of the smaller isolated glyph rows
- that denser proof makes the next priority explicit: on the current host the
  first dashboard frame reports `shaped_special_glyphs=226`, split as
  `powerline=12 shade=18 braille=10 box=186 other_special=0`, which means the
  Metal terminal lane is now visibly dominated by box/block continuity work
  rather than powerline ownership bugs
- the first box-continuity execution slice is now in too: the common
  double-line box set (`U+2550`, `U+2551`, `U+2554`, `U+2557`, `U+255A`,
  `U+255D`, `U+2560`, `U+2563`, `U+2566`, `U+2569`, `U+256C`) now has
  analytic/special coverage instead of falling back to normal font rendering
- the dashboard fixture was updated to exercise that double-line set directly,
  so the Metal terminal lane now has a live runtime probe for those shapes
  instead of only a code claim
- the next box/block slice is in as well: the common lower, upper, and
  left/right block elements (`U+2581..U+258F`, plus `U+2594` and `U+2595`)
  now ride the analytic/special path instead of normal font fallback
- that moves more `btop`-style bar content onto the live Metal special-glyph
  lane on the same dashboard proof: the current first frame now reports
  `shaped_special_glyphs=179`, split as
  `powerline=12 shade=18 braille=10 box=139 other_special=0`
- the dashboard fixture itself now pressures that new block ladder too rather
  than leaving it as compile-only coverage: it seeds side-fill glyphs
  (`▏▎▍▌▋▊▉█`), top/right-edge blocks (`▔▕`), and the lower block ladder
  (`▁▂▃▄▅▆▇█`) on the live Metal terminal lane
- with that richer mixed dashboard content, the current first-frame proof is
  now `shaped_special_glyphs=185`, split as
  `powerline=10 shade=6 braille=10 box=159 other_special=0`, which is a
  more representative `btop`-style bar/box pressure mix than the earlier
- the mixed double/single box family is now on the same analytic path too:
  `U+2552..U+256B` no longer fall back to normal font rendering, and the
  dashboard proof now seeds those joins directly; on the current host that
  pushes the first-frame dashboard split to
  `powerline=10 shade=6 braille=3 box=174 other_special=0`, which confirms
  the live Metal lane is carrying more of the mixed border language that
  `btop`-class dashboards rely on
- the heavy/mixed light-heavy junction family is on that path now too:
  `U+250F`, `U+2513`, `U+2517`, `U+251B`, `U+2520`, `U+2523`, `U+2528`,
  `U+252B`, `U+2530`, `U+2533`, `U+2538`, `U+253B`, `U+2542`, and `U+254B`
  now render analytically instead of falling back to normal font output
- the dashboard proof now seeds those heavy joins directly, and on the current
  host the first-frame split moves again to
  `powerline=6 shade=6 braille=3 box=181 other_special=0`, which is a better
  statement of the remaining gap: less missing box language, more continuity
  and stroke-quality cleanup
- the common indicator/editor marker set is now on the same analytic lane too:
  arrows (`←↑→↓↵`), triangles (`▶◀`), circles (`●○`), diamonds/squares
  (`◆□`), and check/x marks (`✓✗`) no longer depend on normal font fallback
  on the Metal terminal path
- the dashboard proof now seeds that indicator row directly, and on the
  current host the first-frame split moves to
  `powerline=6 shade=6 braille=3 box=189 other_special=0`, which means even
  more of the dense TUI/editor symbol language is definitely on the Metal
  special path now
- the next indicator refinement is quality, not ownership: left/right triangles
  and arrowheads now use directional analytic shapes instead of the earlier
  “diamond/rect stub” approximations, so the symbol lane is closer to the GL
  read even though the runtime class counts stay the same
- the live `btop` capture also exposed one last tiny status-marker class that
  matters in practice: superscript counters (`¹²³⁴`) and the degree sign (`°`)
  are now on the analytic Metal path instead of relying on font fallback
- the dashboard proof now seeds that exact status-marker set in the title row;
  on the current host the first-frame split is
  `powerline=6 shade=6 braille=3 box=186 other_special=0`, which is slightly
  lower than the prior indicator-heavy proof because the row content changed,
  not because the lane regressed
  dashboard row set
- a real live-lane contradiction is fixed now too: the Metal terminal row
  fallback had still been truncating fallback cells to `u8` and the backend
  helper only iterated raw bytes, which meant non-ASCII fallback cells could
  silently disappear even though the atlas path itself could upload them
- the current Metal fallback seam now carries UTF-8 terminal row data through
  `metal_text_sample_runtime` and `terminal_widget_draw_grid`, so single-cell
  non-ASCII fallback runs no longer structurally collapse to ASCII-only
  rendering on the live Metal path
- a second live `btop` contradiction is fixed now too: the Metal terminal
  present lane had still been capping queued surface draws at `128`, which
  meant large dashboard-class frames could silently stop queuing later row
  draws after the early text landed
- the Metal terminal frame draw queue is now growable rather than fixed-size,
  so `btop`-class frames no longer fail by silently truncating the back half
  of the present list
- a third live contradiction is fixed on top of that: once UTF-8 fallback was
  widened, the generic Metal row fallback could consume entire rows before the
  analytic special-glyph path ever ran, which flattened box/block/braille
  rows back into generic text fallback
- the live Metal row fallback now explicitly excludes analytic/special glyph
  classes, so the real special-glyph lane regains ownership of `btop` border,
  block, shade, braille, and powerline cells instead of losing them to the
  generic row path
- the GL-only terminal glyph helper seam is corrected for Metal too:
  analytic box rects and coverage-sprite quads now enqueue real Metal surface
  draws instead of disappearing into the OpenGL glyph cache path
- on a real live Metal `btop` repro this moves the failure mode forward
  materially: normal terminal text is broadly present again and the box/block
  lane is visibly participating, so the remaining gap is now continuity and
  fidelity quality rather than “most of the frame never rendered”
- a small live `btop` indicator slice is covered analytically now too:
  `■`, `▲`, and `▼` are on the Metal special-glyph lane instead of relying on
  font fallback, which makes queue/status markers materially cleaner on the
  live dashboard workload
- the narrow Metal sampled-text lane is no longer structurally ASCII-primary
  either: glyph selection now falls through `pickFontForCodepoint(...)`
  instead of only using `directFastGlyphForCodepoint(...)`, so PUA / Nerd
  Font icon cells can resolve through the same fallback font ownership that
  the broader terminal font stack already uses
- on the live Metal terminal path that fixes the “normal text renders but
  `nvim`-style icons disappear” contradiction: the sampled row path can now
  pick and upload non-primary symbol glyphs instead of silently returning no
  draw for those cells
- the unavailable-text Metal terminal lane is wider now too: shaped spans
  that fall out of the narrow single-cell fast paths can route through
  per-cell Metal atlas fallback instead of relying on ASCII-only fallback
  helpers or the GL text path
- on the live Metal terminal path that moves emoji/emote rendering forward
  materially: wide emoji cells and simple grapheme cases now render on the
  fallback lane instead of vanishing whenever they miss the single-cell row
  fast path
- that same dashboard lane is now runtime-proven under churn too instead of
  only on the first full frame: a dashboard mutation frame now stays on
  `metric_present_sample=direct_snapshot_update` with
  `cache_dirty=partial` and tight redraw work (`grid_runs=9/72`) while still
  carrying dense special-glyph traffic
- a tiny dashboard-local update is proven as well: a partial dashboard frame
  can stay on `direct_snapshot_update` with `grid_runs=0/0`, redrawing only
  the changed cells while the frame still reports live special-glyph work
  (`shaped_special_glyphs=6` split as `shade=2 braille=3 box=1`)
- the dashboard scroll lane is now proven against real dashboard history too:
  with a one-row scroll offset the diagnostic reports
  `metric_present_sample=direct_snapshot_shift_update`,
  `cache_dirty=partial`, and tight redraw counts (`grid_runs=3/34`) on the
  dense mixed dashboard fixture instead of only on the older ASCII scroll
  proof
- that preparation contract is now aligned with capture truth as well:
  the target runtime prepares drawable-sized Metal snapshot presentables
  instead of using terminal-surface geometry while submit-time capture
  silently reallocates something larger later
- the underlying storage contract is less retained-first now too: the terminal
  widget state container and partial-plan type are named around presentation
  rather than retained state, which reduces one more place where the direct
  Metal lane had to live inside retained terminology
- dead retained-era sync fast-present helper layers are gone too: the terminal
  presenter no longer preserves an unused parallel helper path around the live
  presentation flow, which keeps the contract centered on the actual
  `updateAndPresent` logic instead of stale helper duplicates
- the frame-timing contract matches that same presentation language now too:
  terminal presenter results, terminal draw metrics, pacing logs, and the
  Metal terminal diagnostic report `presentation_*` timing instead of
  `texture_*`, which keeps the current direct-main-target lane from wearing
  retained-surface timing terminology
- terminal invalidation is less retained-shaped now too: tab-close and
  tab-navigation callers invalidate presentation cache readiness through the
  widget/state seam instead of referring to a texture cache even though the
  active Metal terminal lane presents directly
- the terminal presenter internals are less retained-first now too: helper
  names and temporary state use presentation-language (`surface_w`,
  `presentation_delta`, `presentation_ready`, presentation draw-pass helpers)
  instead of describing the live direct/retained split as a retained lane plus
  exceptions
- terminal debug truth is less retained-texture-biased now too: presentation
  samples and debug capture report `presentable_px` instead of `texture_px`,
  which matches the fact that the active Metal terminal lane is a direct
  presentable path rather than a retained texture-backed present path
- the same correction now reaches the storage module/file center too: terminal
  presentation state now lives in
  `terminal_widget_presentation_cache_state.zig` instead of a retained-state file,
  so the direct Metal lane no longer depends on a retained-era module name for
  its primary widget presentation cache
- the renderer-facing terminal policy seam is less texture-era now too:
  terminal presenter/config callers use presentation-language
  (`setTerminalPresentationShiftEnabled`,
  `terminalPresentationShiftEnabled`,
  `forceFullTerminalPresentationRecentInputWindow`) instead of naming the live
  contract around texture publication even though the active Metal lane
  presents directly
- the terminal planning helper file center matches that contract now too:
  `terminal_widget_draw_plan.zig` replaces the old texture-named
  helper module, which is more honest because the file mostly owns
  presentation update/shift policy rather than texture-specific behavior
- the terminal presenter also depends on a terminal-owned presentation-target
  wrapper now instead of importing the generic retained-target runtime
  directly, which reduces one more place where the live Metal terminal lane
  had to sit inside retained-target module ownership
- terminal presentable lifecycle bookkeeping is less inline now too:
  present-state refresh, viewport clip entry, and unavailable logging now live
  in `terminal_widget_presentation_runtime.zig` instead of being carried as
  ad hoc presenter-local lifecycle logic
- the same runtime now owns the retained-presentable draw step too: the
  presenter no longer inlines the "note sample + draw presentable" helper for
  the terminal lane, which tightens the terminal-owned presentation seam one
  step further
- the runtime now owns presentable setup/planning too: geometry calculation,
  ensure/shift/update-plan selection, and partial-plan assembly moved out of
  the presenter into `terminal_widget_presentation_runtime.zig`, so the
  terminal lane no longer splits setup ownership between presenter-local logic
  and runtime helpers
- with that move, the terminal presenter is now mostly a coordinator over a
  terminal-owned presentation seam rather than a parallel owner of setup,
  lifecycle, and presentable draw mechanics
- the retained-presentable sync/fast path is behind that same runtime now too:
  the presenter no longer owns the ready-presentable short-circuit branch
  directly, which tightens the terminal-owned presentation contract further
- the same terminal-owned runtime now owns the direct-main-target terminal
  present path too: background clear, grid background pass, glyph pass, Kitty
  below-text pass, Kitty above-text pass, and direct-present debug sampling
  are no longer presenter-local logic
- that matters because the terminal lane now has one owning runtime seam for
  both active presentation shapes on macOS:
  - `retained_surface` on the mature OpenGL/full-ui lane
  - `direct_snapshot_cache` on the live Metal terminal lane
- with this move, `terminal_widget_surface_presenter.zig` is closer to its
  intended role as orchestration over terminal-owned presentation/runtime
  contracts instead of being the real owner of one presentation mode and a
  helper caller for the other
- terminal presentation debug sampling moved behind that same seam too:
  sample clearing and retained-versus-direct presentation sample emission now
  live in `terminal_widget_presentation_runtime.zig` instead of the presenter
- the presenter-local pass-through helpers for present-state refresh,
  unavailable logging, present draw, and plan selection are gone too:
  `updateAndPresent` now talks to the terminal presentation runtime directly
  for those operations instead of bouncing through local wrappers
- the terminal-owned target seam is slightly more complete now too:
  retained-presentable end/restore is routed through the renderer presentable
  contract instead of leaving target shutdown as presenter-local knowledge
- the retained-presentable update execution moved behind the same terminal
  runtime seam too: the background pass, glyph pass, Kitty below/above-text
  ordering, and partial/full row-span iteration for the retained terminal
  path now live in `terminal_widget_presentation_runtime.zig`
- the retained terminal present cycle itself is there now too: begin-target,
  end-clip, retained update execution, and end-target restore now run through
  one terminal runtime entrypoint instead of being split between presenter
  orchestration and runtime helpers
- the remaining retained-path post-update orchestration moved there too:
  refresh-present-state, fallback background fill, unavailable logging, and
  retained present submission now run through one terminal runtime operation
  instead of being assembled inline in the presenter
- the top-level terminal presentation operation is now there too:
  direct-main-target presentation, retained fast-present, retained plan/cycle,
  and retained present submission are all selected and executed through one
  runtime entrypoint, leaving the presenter mostly with timing and policy
  input instead of backend-shaped control flow
- even the recent-input presentation policy check now lives there:
  the presenter no longer computes the force-full recent-input window logic
  itself and instead passes through a terminal-owned runtime policy call
- the dedicated terminal presenter file is gone now:
  `terminal_widget_presentation_runtime.zig` is the public entrypoint for
  terminal presentation, while `terminal_widget_draw.zig` calls it directly
  instead of routing through a thin presenter wrapper
- that contract is intentionally backend-native rather than fake portability:
  the old cached GL `Texture` path is still OpenGL-only, while Metal Kitty
  images are created as frame-scoped native Metal textures and released after
  submission
- the terminal Metal diagnostic now reports `raw_image_textures=1` on the
  current host, seeded Kitty placements still drive non-zero `kitty_ms`, and
  the previous `kitty upload unsupported backend=metal` boundary is gone for
  RGB/RGBA images on this lane
- screenshot truth exists too: the Kitty-seeded Metal terminal diagnostic has
  produced a real `1280x720` PPM capture on the current host through the
  present-capture path, which means the raw-image lane is now runtime-proven
  instead of only inferred from timing metrics
- this is still intentionally narrow and honest: it is now a tiny sampled
  multiline ASCII run with an explicit monospace-cell option rather than a
  claim that the generic string/text renderer has already migrated
- the existing font-sample fallback now consumes that same narrow path as an
  actual UI caller: when live text is unavailable but the planned mode is
  `metal_texture_atlas`, it frames and requests a tiny sampled `"METAL"` run
  rather than remaining purely a passive status surface
- the visible atlas-backed preview path is no longer a copy-only blit: the
  Metal backend now owns a tiny textured-quad pipeline with sampler/tint
  semantics for sampled atlas draws, and the submit-time screenshot path has
  captured a real `1280x720` PPM artifact for that path on the current macOS
  host
- this is a real lifecycle-policy step because the AppKit delegate proxy now
  routes activation, quit, and open-file through macOS-owned host policy
  helpers first, with forwarding to the previous delegate reduced to fallback
  behavior instead of acting as the default owner
- this is now runtime-validated on the current macOS host through a real
  present-capture readback path: the Metal smoke can arm capture on the final
  frame, blit the drawable texture into a Metal buffer during submit, wait for
  completion, and write a workspace-local PPM artifact without touching GL
- current limit: direct `dumpWindowScreenshotPpm` semantics are still
  GL-shaped; the honest Metal path today is submit-time present capture rather
  than fake synchronous framebuffer readback
- this is a real screenshot-capability step because the shell/renderer surface
  now exposes direct-readback versus present-capture semantics explicitly,
  instead of making callers assume every backend can satisfy synchronous GL
  screenshot requests
- this is now reflected in caller-facing app flows as well: screenshot callers
  outside renderer internals use the capability-aware shell surface instead of
  reaching for direct GL-shaped screenshot helpers
- this is a real lifetime-discipline step because drawable and command-buffer
  references are now released explicitly after commit
- this is not yet full native macOS lifecycle ownership
- this is not yet a Metal render host
- this is not yet the normal full-ui renderer frame loop on Metal
- this is groundwork for `MAC-04` and `MAC-05`, not completion of them

## Full-UI Metal opt-in (macOS, development)

The default full UI still selects OpenGL at renderer init. On macOS only, set
`ZIDE_RENDERER_BACKEND=metal` to request Metal for the normal app shell
(`runtime_profile == .full_ui`). `ZIDE_RENDERER_BACKEND=opengl` forces OpenGL
explicitly. Invalid values are ignored (default OpenGL).

When Metal is active, font atlases use the Metal atlas upload hooks
(`terminalFontAtlasUploadHooks`) so glyph caches are not GL-backed.

The `font-sample` mode is now also honest on this path: standalone sample fonts
use the same Metal atlas upload hooks instead of crashing through GL-only font
atlas allocation, and the diagnostic/status copy uses the Metal monospace
fallback path when live text mode is still reported as unavailable.

This is an execution checkpoint toward `MAC-07`, not a claim that every
full-ui draw path is Metal-complete; capability and editor/terminal breadth still
follow `capabilities()` and ongoing milestone work.

## Explicit Anti-Goals

Do not:

- keep the GL-shaped host seam and just swap APIs underneath it
- hide app delegate ownership under "SDL handles macOS"
- call macOS "done" because a Metal view exists
- create a macOS-only abstraction that Android will later need to route around

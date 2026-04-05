# macOS First-Class Implementation Journey

This queue is now a derived execution lane under the broader native-host
architecture direction in
`app_architecture/platform/NATIVE_HOST_CONTRACT.md`,
`app_architecture/platform/NATIVE_HOST_REFERENCE_CROSSCHECK.md`, and
`app_architecture/platform/PLATFORM_CAPABILITY_MODEL.md`, and
`app_architecture/platform/macos/RENDER_BACKEND.md`.

## Scope

Track the work required to make macOS a first-class native platform while
carving shared native-host seams that Android and other native targets can
reuse without inheriting macOS-specific mechanics.

This queue owns:

- the macOS side of the shared native-host contract carving
- macOS-native app/window/runtime bring-up sequencing
- the macOS render-host migration needed for a serious native product
- macOS-specific validation, polish, and install-surface follow-up once the
  native runtime path is real

This queue does not own:

- the default repo-wide VT priority lane in `docs/AGENT_HANDOFF.md`
- the shared native-host contract itself
- general UI modularization that is not macOS-specific
- speculative backend work that bypasses the shared native-host carve

## Why This Queue Exists

The repo currently has some shared macOS-aware details such as config paths and
target metadata, but its live host/runtime truth is still SDL/OpenGL-shaped.
Without an explicit execution queue, macOS work will drift into opportunistic
patches and platform-specific seams instead of contributing to a durable
cross-platform native-host architecture.

This file is the coordination point for reopening macOS as a deliberate product
lane.

## Product Direction

1. Treat macOS as a first-class desktop target, not as a tolerated side build.
2. Use Ghostty's macOS implementation as the strongest terminal reference
   pressure for native platform quality.
3. Target Metal + AppKit/Cocoa as the destination state for macOS rendering and
   window integration.
4. Carve shared native-host seams that Android and later native platforms can
   satisfy with their own lifecycle and surface mechanics.
5. Do not treat SDL3 + OpenGL on macOS as the end-state architecture.
6. Keep progress explicit: every meaningful macOS milestone should be tracked
   here before code starts to sprawl.

## Non-Negotiable Constraints

- Metal is the destination backend for macOS.
- AppKit/Cocoa ownership must be explicit where native behavior requires it.
- OpenGL may remain part of current code truth during migration, but it is not
  the macOS target story and must not define the durable host contract.
- Reference pressure should come from:
  - `dev_references/terminals/ghostty/macos/`
  - `dev_references/sdlwiki_md/SDL3/README-macos.md`
  - `dev_references/backends/sdl/`
  - `dev_references/official/apple_metal/`
  - `dev_references/official/android_native/`
- Keep work reviewable. Do not start by scattering macOS special cases through
  unrelated subsystems when a shared native-host seam should exist instead.

## Current State

- Shared config/runtime code already knows about macOS config-path semantics.
- Build metadata already recognizes macOS as a supported target.
- Current live renderer/runtime truth is still SDL3 + OpenGL oriented.
- Current live host seam is still GL-shaped:
  - `src/platform/sdl_api.zig` creates `SDL_WINDOW_OPENGL` windows
  - `src/ui/renderer/window_init.zig` only knows GL attribute/context setup
  - `build_system/platform_capabilities.zig` still carries a GL-first runtime
    description because the implementation is still on that path today
- No dedicated macOS-first-class implementation queue existed before this file.
- Current native macOS build truth is green on the active arm64 host.
- `ziglua` is back on the pinned package path.
- `zlua-portable` is back on a published pinned package path after the
  `v0.1.0-beta.2` package fix.

## Entry Points

- `app_architecture/ui/DEVELOPMENT_JOURNEY.md`
- `build_system/platform_capabilities.zig`
- `src/platform/sdl_api.zig`
- `src/ui/renderer.zig`
- `src/ui/renderer/window_init.zig`
- `app_architecture/platform/NATIVE_HOST_REFERENCE_CROSSCHECK.md`
- `app_architecture/platform/NATIVE_HOST_CONTRACT.md`
- `app_architecture/platform/PLATFORM_CAPABILITY_MODEL.md`
- `app_architecture/platform/macos/RENDER_BACKEND.md`
- `dev_references/terminals/ghostty/macos/`
- `dev_references/backends/sdl/`
- `dev_references/official/apple_metal/`
- `dev_references/official/android_native/`

## Milestones

- [x] `MAC-00` Create a dedicated macOS feature branch from current `main`
  - Branch: `macos-implementation`

- [x] `MAC-01` Seed the workspace-local reference surface needed for the first
  macOS pass
  - Current synced references:
    - `dev_references/terminals/ghostty/macos/Sources/Helpers/MetalView.swift`
    - `dev_references/terminals/ghostty/macos/Sources/Ghostty/Surface View/SurfaceView.swift`
    - `dev_references/terminals/ghostty/macos/Sources/App/macOS/AppDelegate.swift`
    - `dev_references/terminals/ghostty/macos/Sources/App/macOS/AppDelegate+Ghostty.swift`
    - `dev_references/terminals/ghostty/macos/Sources/Helpers/HostingWindow.swift`
    - `dev_references/sdlwiki_md/SDL3/README-macos.md`
    - `dev_references/sdlwiki_md/SDL3/README/macos.md`
    - `dev_references/sdlwiki_md/SDL3/SDL_PROP_WINDOW_COCOA_WINDOW_POINTER.md`
    - `dev_references/sdlwiki_md/SDL3/SDL_PROP_WINDOW_CREATE_COCOA_WINDOW_POINTER.md`
    - `dev_references/sdlwiki_md/SDL3/SDL_PROP_WINDOW_CREATE_COCOA_VIEW_POINTER.md`

- [x] `MAC-02` Contribute the macOS side of the first honest native-host target note
  - Required output:
    - explicit statement of destination backend and native host surfaces
    - ownership split between shared native-host seams, SDL bridge seams, and
      macOS AppKit/Metal seams
  - Output now lives in:
    - `app_architecture/platform/macos/RENDER_BACKEND.md`
      - `First Honest Native-Host Target Note`

- [x] `MAC-03` Audit the current renderer/window/app stack against the macOS
  destination
  - Required output:
    - concrete contradiction list between current SDL/OpenGL truth and the
      desired macOS-first-class shape
    - explicit notes on which contradictions are really shared native-host
      contradictions rather than macOS-only problems
    - ranked blockers, not a grab bag of ideas
  - Output now lives in:
    - `app_architecture/platform/macos/RENDER_BACKEND.md`
      - `Ranked Contradiction Audit Versus The Live SDL/OpenGL Lane`

- [ ] `MAC-04` Define the native window/app lifecycle seam
  - Focus:
    - `NSApplication`/delegate ownership
    - menu/file-open/app-activation lifecycle
    - SDL window to Cocoa handle access strategy
    - exact line between shared host contract and macOS-native implementation
  - 2026-04-05 groundwork checkpoint:
    - `src/platform/sdl_api.zig` now exposes Cocoa window and view pointers via
      SDL window properties
    - `src/platform/native_host.zig` now defines shared `PlatformAppHost` and
      `PlatformRenderHost` structs under `src/platform/` instead of burying
      that seam inside renderer-local code
    - `PlatformAppHost` lifecycle state is now updated by the live SDL event
      path for focus and termination transitions
    - `PlatformAppHost` now carries the first explicit external-intent shape:
      `quit_requested`, `activation_requested`, and buffered
      `open_file_requested`
    - `src/platform/macos_host.zig` now exposes platform-owned request helpers
      for activation, quit, and open-file flows on top of `PlatformAppHost`
    - existing Windows-native chrome helpers now consume the shared render-host
      seam, which confirms the seam is not macOS-specific architecture
    - the next cut can define the AppKit boundary against explicit native
      handles instead of extending GL-only helpers

- [ ] `MAC-05` Define the Metal renderer migration plan
  - Focus:
    - render-host seam shape
    - drawable/layer ownership
    - present contract and resize/scale handling
    - minimum migration cuts that keep diffs reviewable
    - no macOS-only abstraction that Android or other native targets would have
      to route around later
  - 2026-04-05 groundwork checkpoint:
    - SDL window creation no longer hardcodes `SDL_WINDOW_OPENGL`
    - `src/ui/renderer.zig` now requests `.opengl` explicitly at renderer
      bring-up
    - renderer state now captures a shared `PlatformRenderHost` snapshot for
      the live window instead of treating raw SDL window + GL context as the
      only host truth
    - `src/platform/macos_host.zig` now exposes a platform-owned
      `MetalAttachmentTarget` derived from `PlatformRenderHost.cocoaWindow()`
      and `PlatformRenderHost.cocoaView()`
    - `src/platform/macos_metal_host.zig` now prepares the first platform-owned
      Metal host shim from that attachment target
    - renderer bring-up now has an explicit render-surface attachment phase
      before backend context creation
    - OpenGL window-attribute and context setup now live in
      `src/ui/renderer/gl_backend.zig`, not in generic window-init code
    - `src/platform/macos_metal_host.zig` now creates a real SDL Metal view and
      resolves its backing layer during host preparation
    - `src/ui/renderer/metal_backend.zig` now exists as the first explicit
      Metal backend context surface
    - the stored render-surface attachment now owns Metal-host lifetime and
      renderer teardown destroys the SDL Metal view explicitly
    - `src/ui/renderer/metal_backend.zig` now creates a real Metal device and
      configures the attached layer's device, pixel format, framebuffer-only
      flag, and drawable size
    - `src/ui/renderer/metal_backend.zig` now creates a real Metal command
      queue and defines the first drawable acquire/present skeleton around
      `nextDrawable`, command-buffer creation, `presentDrawable:`, and `commit`
    - `src/ui/renderer/metal_backend.zig` can now encode a minimal clear pass
      against the acquired drawable before presentation
    - `src/ui/renderer.zig` and `src/app_shell.zig` now expose a one-frame
      macOS Metal smoke helper so the host-attached Metal path can be probed
      without pretending the full renderer has switched backends yet
    - renderer startup now chooses a requested backend explicitly before window
      creation and surface attachment, instead of treating OpenGL startup as an
      implicit default
    - full `Renderer.init` now rejects `.metal` with an explicit
      runtime-not-ready error, while a dedicated startup smoke path exercises
      the Metal bring-up order honestly without claiming the full renderer is
      already backend-neutral
    - frame begin/submit now route through explicit renderer-backend hooks, so
      GL swap no longer defines presentation structurally for every backend
    - only the GL lane is live for normal runtime submission today; non-GL
      runtime submission still stays explicitly blocked instead of being faked
    - `src/ui/renderer/input_runtime.zig` now delivers open-file requests into
      `PlatformAppHost` from `SDL_EVENT_DROP_FILE`
    - `src/ui/renderer.zig` now installs a real SDL event watch on macOS so
      app foreground/background/terminate lifecycle events update
      `PlatformAppHost` from a real lifecycle source instead of only from
      focus and helper-triggered state
    - `src/platform/macos_app_delegate.zig` now installs a proxy
      `NSApplicationDelegate` that updates `PlatformAppHost` for activation,
      resign-active, terminate, and open-file while forwarding those delegate
      selectors to the previously-installed delegate
    - `src/ui/renderer.zig` now supports a minimal live `.metal` renderer
      instance via a backend-smoke runtime profile, with a real Metal backend
      context and live clear/present frame ownership on the attached window
      surface
    - GL scene targets, fonts, and the normal full UI renderer path still stay
      under the OpenGL/full-ui profile instead of being misreported as Metal
      ready
    - `src/app/macos_metal_live_smoke_runtime.zig` now provides an env-gated
      live macOS Metal smoke entry through normal app startup, and
      `src/app/bootstrap.zig` / `src/app/app_entry_runtime.zig` now expose it
      as `--macos-metal-live-smoke`
    - validated on 2026-04-05:
      `ZIDE_MACOS_METAL_LIVE_SMOKE=1 ZIDE_MACOS_METAL_LIVE_SMOKE_FRAMES=12 zig build run`
      presented 12 successful Metal frames on the native macOS host
    - validated on 2026-04-05:
      `zig build run -- --macos-metal-live-smoke`
      presented 90 successful Metal frames on the native macOS host
    - validated on 2026-04-05:
      `ZIDE_MACOS_METAL_LIVE_SMOKE_SCREENSHOT=releases/macos-metal-live-smoke.ppm zig build run -- --macos-metal-live-smoke`
      produced a real `1280x720` PPM artifact through Metal submit-time
      present capture, with no GL framebuffer fallback
    - direct `dumpWindowScreenshotPpm` semantics are still GL-shaped today;
      the honest Metal readback path currently lives on submit-time present
      capture instead of fake synchronous framebuffer reads
    - shell/renderer screenshot semantics are now explicit capability truth:
      direct readback for GL paths, present-capture for the current Metal path,
      instead of every caller assuming synchronous framebuffer screenshot
      support
    - caller-facing app flows now use that capability-aware screenshot surface;
      remaining direct screenshot helpers are confined to renderer/backend
      implementation paths
    - retained targets are now an explicit renderer capability instead of a
      structural assumption, and the editor draw path can fall back to direct
      composition when retained targets are unavailable
    - the renderer now tracks an explicit main-composition target mode instead
      of using a GL-shaped `scene_frame_active` flag; direct-to-window,
      offscreen-scene-target, and backend-surface composition are now
      differentiated explicitly
    - scene-target invalidation and readiness now respect capability truth, so
      non-scene-target paths do not keep queuing GL-shaped offscreen target
      work just because window metrics changed
    - scene composition is now an explicit renderer plan (`direct_main_target`
      versus `offscreen_scene_target`) rather than an inference from whether a
      GL scene target happens to exist at frame start
    - renderer feature decisions now flow through a shared capability surface
      for scene composition, retained targets, and screenshot semantics,
      instead of being scattered as unrelated backend checks
    - text rendering now has an explicit capability mode; the current full-ui
      path declares GL texture-atlas text explicitly, and unsupported paths no
      longer imply that text rendering is universally available
    - renderer capability snapshots now carry both the live text mode and the
      planned destination mode, and the macOS Metal smoke reports that gap
      directly as `text=unavailable planned_text=metal_texture_atlas`
    - the existing font-sample diagnostic path now respects text capability
      truth; unsupported runtime paths report the live/planned text gap
      instead of silently using a hidden GL-atlas text bypass
    - `TerminalFont` now exposes atlas ownership through an explicit storage
      seam instead of raw texture fields, so glyph-atlas storage is no longer
      implied to be structurally OpenGL-shaped everywhere
    - renderer capability snapshots now carry both the live atlas-storage mode
      and the planned destination mode, and the macOS Metal smoke reports that
      truth directly as
      `atlas=metal_textures planned_atlas=metal_textures`
    - `src/ui/renderer/metal_backend.zig` now owns a concrete Metal glyph-atlas
      object with backend-owned coverage/color textures plus live upload entry
      points; the macOS Metal smoke now reports `atlas_ready=1`, which confirms
      the Metal atlas center is initialized and has accepted diagnostic upload
      data without falsely claiming live text rendering support yet
    - font rasterization and special-glyph sprite creation now route atlas
      writes through `TerminalFont`'s shared atlas-upload seam instead of
      issuing direct GL atlas updates from their own logic, which preserves the
      current GL behavior while making atlas upload ownership explicit for the
      next Metal text slice
    - the macOS Metal smoke now attempts a real uploaded-glyph atlas probe via
      a temporary `TerminalFont` with Metal atlas-upload hooks, and the current
      host now reports
      `atlas_upload_probe=1 atlas_preview_source=uploaded_coverage_glyph`, so
      the visible preview is sourced from a real uploaded glyph rect rather
      than seeded atlas content
    - the visible atlas sample path is no longer wired as ad hoc smoke-only
      renderer glue; the renderer now carries a backend-owned
      `metal_backend.AtlasSampleDraw` description and the Metal backend owns
      the actual sampled-atlas blit helper used during submit
    - the first dedicated Metal text diagnostic view now exists as a separate
      UI seam in `ui/metal_text_diagnostic_view.zig`, so preview placement and
      activation are no longer embedded directly in the live smoke runtime
    - that diagnostic view no longer chooses placement by itself; placement is
      now produced by a renderer-owned helper in
      `renderer/metal_text_diagnostic_runtime.zig`
    - the existing `font_sample` diagnostic surface now reuses that Metal text
      diagnostic seam when live text is unavailable and the planned text mode
      is `metal_texture_atlas`, so this narrow text-diagnostic route no longer
      remains structurally GL-only
    - a dedicated `--macos-metal-text-diagnostic` startup/runtime lane now
      exists for this sampled-glyph path, so the Metal text diagnostic seam is
      validated independently of the broader live-smoke runtime
    - the first actual narrow Metal text draw path now exists: the renderer
      can upload and place a tiny sampled ASCII text run through the Metal
      atlas contract, and the dedicated text-diagnostic runtime now reports
      `sample_text_draw=1` on the current macOS host
    - that tiny sampled-text run now has a dedicated runtime builder in
      `renderer/metal_text_sample_runtime.zig`, so it is no longer entirely
      ad hoc renderer-local logic
    - the sampled Metal text lane now also has an explicit
      `SampleTextRequest` contract for callers instead of only raw convenience
      parameters
    - that sampled-text contract now carries explicit tint and layout policy,
      so the Metal diagnostic lane no longer depends on white-only copied
      atlas pixels or on implicit glyph-advance stepping
    - that same sampled-text contract now also carries explicit clip
      ownership, so the narrow Metal text lane can obey widget/view bounds
      instead of only drawing unconstrained diagnostics
    - the first terminal-facing fallback now exists on top of that contract:
      narrow ASCII terminal cells can route through the sampled Metal lane
      with per-cell bounds and tint when live text is unavailable
    - that terminal-facing fallback now has its own request/builder seam for
      tiny terminal-style rows, and the live macOS Metal text diagnostic now
      reports `terminal_cell_run_draw=1` on the current host
    - clip ownership is now more renderer-native instead of purely
      caller-threaded: `beginClip`/`endClip` state is stored by the renderer
      and inherited by the narrow Metal sampled-text and terminal-cell-run
      paths when callers do not override clip explicitly
    - that inherited clip state is now exercised by the live terminal-row
      proof itself: the macOS Metal text diagnostic enters a renderer clip and
      draws the terminal row without an explicit row clip rectangle
    - more real renderer flows can now hit the terminal-shaped Metal lane
      instead of only bespoke diagnostics: monospace text fallback paths now
      route through the narrow terminal-cell-run contract when live text is
      unavailable and planned text is `metal_texture_atlas`
    - terminal grapheme entry points now degrade to the same narrow
      ASCII/base-cell Metal lane when live text is unavailable, instead of
      falling straight through to empty text whenever the grapheme base can be
      represented by the current fallback
    - the terminal grid now has its first row-level Metal integration too:
      contiguous ASCII single-cell fallback spans can route through the
      terminal-row Metal contract instead of only degrading one cell at a time
    - the terminal composing-text overlay can now also route through that
      terminal-row Metal contract when the runtime is Metal-planned,
      live-text-unavailable, and the active composition string is ASCII
    - the terminal debug capture surface now records Metal row-run fallback
      usage separately for grid and overlay callers, so these terminal-facing
      integrations have direct debug proof instead of only architecture notes
    - those same grid/overlay Metal row-run counts now flow into the live
      terminal frame-metrics surface, so fallback activity is queryable
      without relying only on the visible-view debug dump path
    - a dedicated `--macos-metal-terminal-diagnostic` runtime now exists: it
      seeds a deterministic external-transport terminal session, draws a real
      terminal widget through the Metal backend-smoke path, and logs fallback
      counts from both widget debug state and live frame metrics
    - terminal presentation on the Metal backend-smoke path is now more
      honest too: when retained targets are unavailable, the terminal widget
      can fall back to direct main-target composition instead of failing at
      `terminal_surface_unavailable_for_present`
    - current truth from the short deterministic terminal diagnostic is now:
      grid row fallback is observed on the current host (`10/224` in the
      4-frame run), and overlay row fallback is observed in that same run
      too (`1/5`)
    - the direct main-target terminal fallback now preserves the normal
      overlay phase, so IME/composition drawing still runs on the non-retained
      Metal terminal path instead of being dropped by the fallback itself
    - the Metal diagnostic/sample lane now reuses a renderer-owned diagnostic
      terminal font instead of rebuilding a fresh font stack on every sampled
      draw call, which removes misleading per-frame font churn from the
      terminal Metal proof runtime
    - the direct main-target terminal fallback now preserves Kitty image
      composition ordering too: below-text and above-text Kitty passes run on
      the non-retained Metal path instead of that path behaving as text-only
    - the macOS Metal terminal diagnostic now seeds deterministic below-text
      and above-text Kitty placements too, so the next Kitty boundary is
      proven by runtime instead of only by code shape
    - Kitty images now have a live Metal-native raw-image path on the direct
      terminal diagnostic lane, using frame-scoped Metal textures instead of
      forcing the GL `Texture` abstraction across backends
    - terminal presentation truth is now explicit in renderer capabilities:
      the current Metal terminal lane now reports
      `terminal_present=direct_snapshot_cache` instead of making callers infer
      terminal behavior from retained-target absence or forcing the lane under
      the older `direct_main_target` label
    - terminal frame metrics now publish that same presentation mode too, so
      the terminal diagnostic can confirm
      `metric_terminal_present=direct_snapshot_cache` per frame instead of
      only in startup capability logs
    - terminal widget debug capture is now mode-aware too, so the live direct
      Metal path records a real terminal presentation sample instead of
      leaving debug state shaped around retained surfaces only
    - terminal widget surface readiness is now named `presentable_ready`
      instead of `texture_ready`, which better matches the current contract
      where Metal can present directly without a retained texture surface
    - the direct-main-target Metal lane now also has a reusable presentable
      cache: after the first successful terminal frame, the Metal backend
      captures a persistent snapshot texture and the terminal presentable seam
      can reuse that snapshot on later fast-present frames without pretending
      the lane has already become a retained-surface path
    - capability truth now matches that contract directly: the live Metal
      lane is reported as `direct_snapshot_cache`, while the sample path still
      distinguishes frame-0 `direct_main_target` from steady-state
      `direct_snapshot_presentable`
    - the terminal planning helper surface is now presentation-shaped too:
      viewport shift and update-plan helpers are named around presentation
      instead of texture ownership, which better matches both retained and
      direct terminal modes
    - terminal presenter/state internals are now presentation-shaped too:
      update deltas, geometry, plan, and present-state helpers are named
      around presentation instead of retained surfaces, which makes the live
      direct Metal lane less architecturally second-class inside the widget
    - terminal debug geometry is now presentation-shaped too: the debug sample
      type/field are named around terminal presentation instead of retained
      surfaces, so the direct Metal lane no longer sits inside a retained-only
      debug model
    - direct terminal presentation now updates readiness truth honestly too:
      after the first successful direct-main-target Metal frame, widget
      handoff logs report `presentable_ready=1` instead of staying stuck at a
      retained-only readiness value
    - the terminal Metal diagnostic now proves that snapshot-backed reuse
      explicitly too: capability logs start at `snapshot_available=0`, then
      frame logs report `snapshot_available=1` from the first submitted frame
      onward while the active presentation mode is reported as
      `terminal_present=direct_snapshot_cache`
    - that reuse path is now exercised on the current host too: frame 0 still
      reports `metric_present_sample=direct_main_target`, while later
      steady-state frames report
      `metric_present_sample=direct_snapshot_presentable`, with grid/overlay
      row fallback counts and Kitty presentation work collapsing to zero on
      those reused frames
    - that present-sample mode now also flows through the ordinary terminal
      draw-latency surface, so non-diagnostic terminal runs can distinguish a
      full direct draw from snapshot fast-present reuse without relying only
      on the dedicated Metal terminal diagnostic runtime
    - snapshot-cache availability is now drawable-size-aware too, so a window
      resize cannot reuse a stale cached Metal snapshot just because terminal
      generation state remained unchanged
    - direct full draws and direct snapshot fast-presents now both mark the
      submitted terminal generation in the frame trace, so terminal
      publication retirement no longer depends on retained-surface-only
      evidence on this lane
    - the submission/trace contract is now named around terminal presentation
      instead of `terminal_surface_*`, which better matches the live Metal
      lane where direct draw and snapshot fast-present are both valid shapes
    - the terminal presentation-target seam now owns Metal snapshot
      preparation too, so the live Metal terminal presentable is no longer
      allocated only as an implicit submit-time side effect
    - the Metal snapshot-presentable draw now uses explicit raster-space
      source and destination regions, so non-full-window terminals do not
      rely on an accidental full-texture blit assumption
    - the underlying terminal widget storage contract is less retained-first
      now too: the state container and partial-plan type are named around
      presentation instead of retained state, which reduces another place
      where the direct Metal lane had to live inside retained terminology
    - dead retained-era sync fast-present helpers are gone too, so the
      terminal presenter no longer preserves an unused parallel helper layer
      around the live `updateAndPresent` flow
    - terminal timing/reporting is presentation-shaped now too: presenter
      results, frame metrics, pacing logs, and the Metal terminal diagnostic
      use `presentation_*` timing instead of `texture_*`
    - tab-close and tab-navigation invalidation now runs through an
      `invalidatePresentationCache()` seam instead of a retained-era texture
      cache name, which better matches the current direct-main-target Metal
      lane
    - terminal presenter internals are less retained-first now too: helper
      names and temporary state use presentation language (`surface_w`,
      `presentation_delta`, `presentation_ready`, presentation draw-pass
      helpers) instead of describing the live direct/retained split as a
      retained lane plus exceptions
    - terminal debug capture is less retained-texture-biased now too:
      presentation samples report `presentable_px` instead of `texture_px`,
      which better matches the active direct-main-target Metal lane
    - the storage module/file center matches that contract now too:
      terminal presentation state lives in
      `terminal_widget_presentation_state.zig` instead of a retained-state
      file name
    - the renderer-facing terminal policy seam is less texture-era now too:
      config/presenter callers use presentation-language for terminal shift
      and recent-input full-present policy instead of texture-publication
      names
    - the terminal planning helper file center matches that contract now too:
      `terminal_widget_draw_presentation.zig` replaces the old texture-named
      helper module because it now primarily owns presentation update/shift
      policy
    - terminal presentation now goes through a terminal-owned
      presentation-target wrapper instead of importing the generic
      retained-target runtime directly from the presenter
    - terminal presentable lifecycle bookkeeping is less inline now too:
      present-state refresh, viewport clip entry, and unavailable logging now
      live in `terminal_widget_presentation_runtime.zig`
    - that runtime now owns the retained-presentable draw step too, so the
      presenter no longer inlines the "note sample + draw presentable" helper
    - that same runtime now owns presentable setup/planning too: geometry
      calculation, ensure/shift/update-plan selection, and partial-plan
      assembly moved out of the presenter
    - that leaves the terminal presenter much closer to a coordinator over a
      terminal-owned presentation seam instead of a parallel owner of setup,
      lifecycle, and draw mechanics
    - the retained-presentable sync/fast path is behind that same runtime now
      too, so the presenter no longer owns the ready-presentable short-circuit
      branch directly
    - the terminal Metal diagnostic now reports `raw_image_textures=1`, keeps
      non-zero `kitty_ms`, and no longer relies on the previous unsupported
      backend gate for RGB/RGBA Kitty images
    - the Kitty-seeded Metal terminal diagnostic also produced a real
      `1280x720` PPM present-capture artifact on the current host, so this is
      runtime-validated image presentation rather than only timing/log truth
    - this is still a proof/runtime checkpoint, not a claim that retained
      terminal surfaces or full terminal-on-Metal presentation are finished
    - the narrow Metal text lane now covers a tiny multiline ASCII run, not
      just a single flat row
    - the diagnostic/runtime callers now use the explicit monospace-cell
      layout mode, which is a better terminal-facing contract than ad hoc
      glyph-advance stepping
    - the existing `font_sample` fallback now consumes that same narrow path as
      a real UI caller: when live text is unavailable but the planned mode is
      `metal_texture_atlas`, it frames and requests a tiny sampled `"METAL"`
      run
    - the Metal backend now owns a real tiny textured-quad atlas sampling path
      with sampler/tint semantics instead of only copying atlas pixels into the
      drawable, and the submit-time screenshot path captured a real
      `1280x720` PPM artifact for that visible Metal text lane on the current
      macOS host
    - the AppKit delegate proxy now routes activation, quit, and open-file
      through macOS-owned host-policy helpers first, with previous-delegate
      forwarding reduced to fallback behavior instead of being the default
      owner
    - the Metal backend now releases drawable and command-buffer references
      explicitly after commit, but the live renderer still does not use Metal
      as its normal frame loop yet
    - this is the first code step toward making surface binding an explicit
      decision instead of a hidden default

- [ ] `MAC-06` Land the first code groundwork for native macOS surfaces
  - Example candidates:
    - SDL Cocoa window/view handle access
    - framework linkage cleanup for AppKit/QuartzCore/Metal
    - native host shim boundaries that fit the shared contract
  - 2026-04-05 checkpoint:
    - local native package-path bring-up is now in place for the current
      macOS host:
      - the package-side `zlua-portable` fix is now published as
        `v0.1.0-beta.2`
      - `build.zig.zon` now points `zlua_portable` back at the published pin
      - `zlua-portable` no longer forces `lua5.4` pkg-config resolution during
        ordinary dependency graph evaluation
      - `zlua-portable` now reuses `ziglua`'s generated C module instead of
        doing its own standalone Lua header import
      - `src/terminal/io/pty_unix.zig` now uses macOS-appropriate PTY headers
        (`util.h`) and no longer unconditionally imports Linux-only
        `sys/prctl.h`

- [ ] `MAC-07` Bring up the first Metal-backed render path
  - Exit criteria:
    - window creation
    - clear/present loop
    - resize handling
    - host seam still reads as shared-contract + macOS implementation, not as a
      one-off special case
    - no fake "supported" claim before manual smoke truth exists

- [ ] `MAC-08` Re-establish normal macOS validation truth
  - Required checks:
    - build
    - launch
    - text input
    - resize/scale
    - terminal/editor basic interaction
  - 2026-04-05 build checkpoint:
    - `zig build` passed on native macOS arm64
    - `zig build -Dmode=editor` passed on native macOS arm64
    - `zig build -Dmode=terminal` passed on native macOS arm64
    - this is compile/build truth only; GUI launch/manual interaction truth is
      still pending
  - 2026-04-05 CLI/bootstrap smoke checkpoint:
    - ran the smoke from the published dependency graph using a workspace-local
      macOS-style `HOME`
    - validated:
      - `--write-default-config`
      - rerun-without-`--force` preserve behavior
      - `--force`
      - `--write-default-config=<path>`
      - `--write-default-config --stdout`
      - `--config-scope=editor --stdout`
      - `--config-scope=terminal --stdout`
      - `--write-default-config --with-lua-meta`
      - `--install-user-lua-meta`
    - verified written files under:
      - `~/Library/Application Support/Zide/init.lua`
      - `~/Library/Application Support/Zide/lua/zide-meta.lua`
      - `~/Library/Application Support/Zide/.luarc.json`

- [ ] `MAC-09` Prepare a macOS-only SDL/OpenGL checkpoint release before Metal
  - Current intent:
    - publish a macOS-native prerelease on the current GL path
    - treat it as a checkpoint release, not as the long-term macOS renderer
      story
  - Required before signoff:
    - define the macOS stage-release artifact shape in the release docs
    - run manual native validation for launch, shell startup, resize/scale, and
      basic editor/terminal interaction
    - draft the matching release notes once a version/tag is chosen

## Progress Ledger

- 2026-04-05:
  - created `macos-implementation` from current `main`
  - confirmed there was no pre-existing dedicated macOS queue
  - pulled a narrow Ghostty macOS reference slice plus SDL macOS reference docs
    into the workspace-local `dev_references/` tree
  - decided the lane should target Metal/AppKit first-class work, not a narrow
    macOS file-dialog patch
  - reopened the lane under a stricter cross-platform rule:
    - macOS work must now carve shared native-host seams where possible instead
      of accumulating macOS-only architecture
    - SDL is treated as today's bridge layer, not as the final owner of native
      lifecycle and render-surface truth
  - wrote the missing platform architecture authority:
    - `app_architecture/platform/NATIVE_HOST_CONTRACT.md`
    - `app_architecture/platform/NATIVE_HOST_REFERENCE_CROSSCHECK.md`
    - `app_architecture/platform/PLATFORM_CAPABILITY_MODEL.md`
    - `app_architecture/platform/macos/RENDER_BACKEND.md`
    - `app_architecture/platform/android/RENDER_BACKEND.md`
  - completed the first two macOS execution outputs against that authority:
    - `MAC-02`: concrete macOS native-host target note
    - `MAC-03`: ranked contradiction audit versus the live SDL/OpenGL lane
  - landed the first host-surface groundwork cut in code:
    - `src/platform/sdl_api.zig` now treats window graphics binding as an
      explicit choice instead of hardwiring `SDL_WINDOW_OPENGL`
    - Cocoa window/view accessors now exist for the upcoming AppKit seam cut
    - `src/ui/renderer.zig` explicitly asks for the current `.opengl` path
      instead of inheriting GL through the window helper implicitly
    - shared host-contract groundwork now exists in `src/platform/native_host.zig`
      so future macOS and Android work can hang off one platform-owned seam
    - Windows-native chrome modules now resolve native HWND ownership through
      `PlatformRenderHost`, proving the shared seam is immediately useful
    - the live SDL runtime now updates `PlatformAppHost.lifecycle_state` for
      resume, pause, and terminate transitions, so app-host state is no longer
      passive bookkeeping
    - macOS platform helpers now exist above the shared host contract so future
      AppKit/Metal work can target `src/platform/macos_host.zig` instead of
      SDL internals directly
    - the renderer and shell now expose macOS helper entry points for pending
      intents and Metal host preparation without surfacing SDL property lookups
    - the current GL runtime now follows: window creation -> host capture ->
      render-surface attachment -> GL context creation, which corrects the
      renderer bring-up order without changing the live backend yet
    - backend-specific setup ownership is now cleaner: `window_init` handles
      bootstrap/window/surface attachment, while `gl_backend` owns GL-specific
      attributes and context creation
    - the macOS Metal path now has a real native view/layer attachment step and
      a minimal backend context module, even though device/queue/render work is
      still pending
    - Metal backend preparation now reuses the stored attached host instead of
      creating fresh SDL Metal views ad hoc, so lifetime and cleanup ownership
      are explicit
    - the Metal backend now has real layer-configuration truth, not just host
      pointer packaging
  - landed the first native package/build fixes needed to make the current
    SDL/OpenGL lane compile on native macOS:
    - `zlua-portable` is now self-contained against packaged `ziglua`
    - `zlua-portable` no longer depends on forced `lua5.4` pkg-config lookup
      for normal package consumption
    - published `zlua-portable` package fix as `v0.1.0-beta.2`
    - repinned `build.zig.zon` back to the published package graph
    - `ziglua` returned to the pinned package path
    - macOS PTY header split in `src/terminal/io/pty_unix.zig`
    - macOS default interactive shell startup now execs the shell directly as a
      login shell instead of misusing `/usr/bin/login`
  - native build truth is now green for:
    - `zig build`
    - `zig build -Dmode=editor`
    - `zig build -Dmode=terminal`
  - native CLI/bootstrap smoke truth is now also green for the config-export
    and Lua-meta flows from the published dependency graph
  - package validation is also green for:
    - `zig build test` in `../zlua-portable`
  - manual GUI/runtime validation is still open
  - the terminal presentation seam is now more honestly terminal-owned:
    - `terminal_widget_presentation_runtime.zig` owns retained fast-present,
      presentable draw, presentable planning, present-state refresh, and now
      the direct-main-target terminal present path too
    - terminal presentation sample/debug bookkeeping moved into that same
      runtime seam, so the presenter no longer owns direct-versus-retained
      presentation sample emission
    - `updateAndPresent` now calls the terminal presentation runtime directly
      for plan selection, present-state refresh, unavailable logging, and
      present draw instead of bouncing through presenter-local wrapper helpers
    - retained-presentable end/restore now routes through the terminal-owned
      presentation target runtime instead of remaining presenter-local target
      shutdown logic
    - retained terminal update execution now lives in the terminal
      presentation runtime too, including row-span iteration, background pass,
      glyph pass, and Kitty below/above-text ordering for the retained path
    - the retained terminal present cycle now routes through one terminal
      runtime entrypoint for begin-target, end-clip, retained update
      execution, and end-target restore
    - retained-path refresh-present-state, fallback background fill,
      unavailable logging, and retained present submission now route through
      the terminal runtime too instead of being assembled inline in the
      presenter
    - the top-level direct-vs-retained terminal presentation operation now
      routes through one runtime entrypoint too, leaving the presenter mostly
      with timing and recent-input policy input instead of backend-shaped
      presentation control flow
    - the recent-input force-full presentation policy check now routes through
      the terminal runtime too, so the presenter no longer computes that
      policy branch itself
    - the dedicated terminal presentation wrapper file is now deleted;
      `terminal_widget_draw.zig` calls the terminal presentation runtime
      directly as the public entrypoint for terminal presentation
    - the direct Metal terminal lane still validates on the same runtime truth:
      `terminal_present=direct_snapshot_cache`, `presentable_ready=1` after the
      first successful frame, `snapshot_available=1` after frame 0,
      frame-0 `metric_present_sample=direct_main_target`, steady-state
      `metric_present_sample=direct_snapshot_presentable`, non-zero frame-0
      `kitty_ms`, and `presented=2` in handoff logs after the first submitted
      frame
    - this reduces one more retained-first contradiction before a second
      Metal terminal presentation shape is introduced

## Immediate Next Pass

1. Replace backend-first platform wording in the architecture docs with shared
   native-host wording and an explicit capability model.
2. Keep build/report vocabulary honest about the difference between host truth
   and the current runtime graphics path.
3. Then return to `MAC-02` / `MAC-03` with the new shared contract as the
   pressure source.

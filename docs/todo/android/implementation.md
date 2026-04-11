# Android Terminal Queue

This is the active execution queue for Android terminal work.

Use this queue for:

- Android host/runtime work
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
- `app_architecture/platform/android/ANDROID_TERMINAL_HOST_PLAN.md`
- `app_architecture/platform/android/ANDROID_GLES_BACKEND_PLAN.md`
- `app_architecture/platform/android/ANDROID_GLES_BINDING_PLAN.md`
- `app_architecture/platform/android/SURFACE_IDENTITY_POLICY.md`
- `app_architecture/platform/android/ANDROID_PTY_LIFETIME_PLAN.md`
- `app_architecture/platform/android/ANDROID_PTY_SERVICE_SURVIVAL_PLAN.md`
- `app_architecture/platform/android/ANDROID_SHELL_BRINGUP_PLAN.md`
- `docs/research/terminal/ANDROID_HOST_PTY_SCAN_2026-04-08.md`
- `docs/todo/ui/renderer.md` (for the pre-Android rendering gate)

## Current Rule

Android terminal excellence is the active repo goal until further notice.

Current boundary:

- the Android-native terminal-host lane is structurally complete enough to
  stop being the main unknown
- disposable app-process-owned PTY lifetime is the current Android terminal
  baseline
- service-owned PTY survival is now a validated separate Android product lane,
  but it has not displaced the disposable baseline as the default answer
- terminal-host-owned EGL/GLES proof is now strong enough that it is no longer the
  main unknown either
- first-class Android rendering/backend work in `src/ui/renderer/` is still
  blocked by renderer gate #5
- renderer work is only in scope here when it is the next highest-leverage
  Android blocker
- product sequencing is explicit:
  - mobile terminal first
  - extract reusable mobile-native fundamentals while building it
  - mobile editor second
  - integrated IDE mode only after both products are mature enough to compose
- packaging is intentionally undecided:
  - do not assume one all-in-one APK is correct yet
  - do not assume split products are correct yet
  - keep terminal/editor/mobile fundamentals loosely coupled enough to support
    either decision later
- platform-native mobile UX is in scope:
  - do not force all product behavior into Zig or into the GPU texture path
  - keep terminal truth and shared runtime semantics in Zig
  - let Android own Android-native overlays, insets, gestures, and similar
    interaction surfaces where that is the better product fit

## Priority Rule

When choosing what to do next, rank work like this:

1. the highest-leverage blocker to a first-class Android terminal
2. if that blocker is Android-owned, execute it from this queue
3. if that blocker is a renderer gate, execute the exact renderer ticket that
   unblocks Android and then return here

Product sequencing rule:

1. finish mobile terminal to a strong standalone product
2. extract reusable mobile fundamentals while doing that
3. only then open the mobile editor product lane
4. only after both are mature, open integrated mobile IDE work

Do not drift back into renderer cleanup just because renderer docs are more
developed.

## Current Biggest Blocker

The renderer gate-5 composition cleanup is no longer the biggest Android
blocker.

Current blocker:

- define the first controlled Android GLES backend planning cut against the
  now-narrower renderer contract
- do not start a broad backend sprint or add product-specific renderer bypasses

That means:

- gate #2 is treated as closed for active work until Metal validation is
  explicitly reopened
- gate #4 is met
- gate #5 is structurally met for scanned composition families
- Android terminal-host proof should continue only if it feeds the first GLES
  backend planning cut

## Current Priority

**`AR-B4` Android GLES Backend Cut** — this is the active ticket.

Land the smallest Android GLES backend implementation steps that map existing
Android EGL/GLES host truth onto the shared renderer contracts without adding
product-specific bypasses.

Owner docs:

- `app_architecture/platform/android/ANDROID_GLES_BACKEND_PLAN.md`
- `app_architecture/platform/android/ANDROID_GLES_BINDING_PLAN.md`
- `app_architecture/ui/RENDER_BACKEND_CONTRACT.md`
- `docs/todo/ui/renderer.md`

Guardrails:

- do not drift back into Android host/tooling cleanup
- do not reopen `AS-A3` polish
- do not widen into a broad backend sprint before the current slice reaches its
  explicit stop marker

Current checkpoint:

- `AR-B4.a` is now in progress:
  Android GLES backend skeleton and frame binding
- allowed first files:
  `renderer.zig`, `backend_dispatch.zig`, `backend_runtime_bundle.zig`, new
  `android_gles_backend.zig`, new `android_gles_runtime_state.zig`, narrow
  Android build/link changes, and probe extraction only if the terminal-host
  probe remains honest
- current landed code truth:
  - shared renderer backend enum now includes `android_gles`
  - backend runtime storage has an Android GLES slot
  - backend dispatch wiring exists for Android GLES
  - capabilities are minimal and unsupported operations report unavailable
  - backend runtime init/deinit now owns the shared EGL display/config/context
    state through `src/platform/android_gles_runtime.zig`
  - frame begin/submit now bind live Android native-window identity through
    surface epoch truth, clear one frame, and swap buffers through the shared
    frame host path
  - bootstrap selection fails explicitly instead of pretending an SDL bootstrap
    path exists
  - EGL/context/window-surface lifetime ownership is now extracted into
    `src/platform/android_gles_runtime.zig`; `android_gles_probe.zig` uses that
    shared owner instead of carrying a second EGL lifetime implementation
- `AR-B4.a` is met:
  shared Android GLES backend/runtime/frame binding exists and now drives the
  shared terminal-host renderer path on-device
- `AR-B4.b` is now met:
  external-host renderer bootstrap for Android `backend_smoke`
- current `AR-B4.b` code truth:
  - shared renderer now exposes an external-host bootstrap seam for
    `runtime_profile = .backend_smoke`
  - that seam skips SDL window bootstrap and global SDL text-input
    registration
  - shutdown now distinguishes SDL-owned bootstrap from external-host bootstrap
  - external-host metrics seed from `PlatformRenderHost.surface_metrics`
  - Android native bridge can now create, sync, draw, and destroy a shared
    `android_gles` renderer in tests
  - live surface-available and redraw callbacks now route through that shared
    renderer path in native code instead of the old probe draw path
  - Android terminal-host native build is now a real repo build target:
    `zig build android-terminal-host-bridge`
  - that target uses:
    - explicit NDK-backed Android libc configuration
    - explicit Android system `.so` linkage
    - SDL headers only where shared renderer contracts still mention SDL
  - `ops/android_terminal_host.py native` is now just the operator wrapper:
    resolve SDK/NDK, invoke the Zig target, copy the built `.so` into `jniLibs`
- device validation now proves:
  - terminal-host loads the shared bridge on-device without unresolved SDL
    symbols
  - live surface callbacks route through the shared renderer path
  - shared Android GLES clear/swap executes on-device
  - Java/native diagnostics no longer expose stale `probe` naming for the live
    renderer path
- `AR-B4.c` is now met:
  first `SurfaceDraw.solid` replay through Android GLES
- current `AR-B4.c` code truth:
  - Android GLES backend now accepts queued `SurfaceDraw.solid`
  - submit-time replay uses GLES scissor + clear for solid fills
  - backend-smoke frame execution now records one shared solid rect through
    `renderer_surface_host.recordSolidSurfaceFromLogicalRect(...)`
- terminal-host product view now exposes the renderer surface as the main
  content host instead of the old hidden `1dp x 1dp` container
- device validation now proves real product-view surface sizing too:
  - `surface.changed ... size=2759x1230` in landscape
  - `surface.changed ... size=1440x2632` in portrait
- `AR-B4.d` is now met:
  minimal terminal rect/glyph rendering through the shared Android GLES backend
- current `AR-B4.d` code truth:
  - Android GLES backend now accepts terminal rect and terminal glyph-rect ops
    through the same queued solid replay path used for `SurfaceDraw.solid`
  - backend-smoke rendering now proves that path with explicit terminal-colored
    rects and glyph-rect accents inside the shared Android product surface
  - terminal-host now requests `RGBA_8888` for its `SurfaceView`, and the
    shared EGL runtime also applies `EGL_NATIVE_VISUAL_ID` to the native window
  - that format alignment was the blocker for visible output:
    before the cut the host reported `surface.changed ... format=4`
    (`RGB_565`) and swaps only revealed the Java background; after the cut the
    host reports `surface.changed ... format=1` and screenshot pixels match the
    shared clear/rect colors
- current stopping point now met:
  Android terminal-host can select Android GLES and produce visible
  clear/swap, shared solid replay, and minimal terminal rect/glyph-rect replay
  through the shared backend-host path, with no terminal grid, glyph atlas,
  image, screenshot, or presentable claims
- next concrete cut is `AR-B4.e`:
  first live terminal-grid ownership through the shared Android GLES backend
- `AR-B4.e` stop marker:
  product view shows live shell content from the shared renderer path and the
  temporary Java transcript overlay is no longer the product-owned shell
  display
- `AR-B4.e` first cut is now in:
  - terminal-host stages required repo font assets into the app files sandbox
  - Android GLES defers font init until the first live `beginFrame` after
    `makeCurrent`
  - the bridge now reuses the existing live shell session to create a shared
    `TerminalWidget`
  - product view hides the Java transcript when the shared shell renderer is
    active
  - current glyphs are visible only as occupancy blocks from live glyph quads,
    not readable textured atlas text yet
- device truth now proves:
  - `native.surfaceAvailable ... gles=drawn` on the live shell path
  - the process stays alive after first frame
  - product view hierarchy no longer contains the Java transcript nodes while
    the shared shell renderer is active
  - screenshot sampling shows bright live glyph-occupancy blocks in the shared
    surface instead of a blank dark view
- remaining blocker inside `AR-B4.e`:
  readable textured glyph replay on Android GLES; do not pretend occupancy
  blocks are the endpoint
- `RB-B3.e` materially narrowed terminal-presentable lifecycle pressure:
  - shared widget/runtime no longer owns the direct-vs-retained execution split
  - active dispatch no longer treats refresh as retained-only
  - Metal now satisfies the shared refresh seam structurally
- that means the stronger remaining Android-forcing renderer blocker is no
  longer generic terminal-presentable parity cleanup
- the next stronger shared blocker is text/surface phase-boundary pressure:
  fills and their dependent text/icon work still do not share one
  backend-neutral ordering seam
- first `RB-B3.f` slice is now in:
  side-nav badge text no longer bypasses the chrome-band seam through
  immediate sized text drawing
- second `RB-B3.f` slice is now in:
  status-bar mode chip text, active field text, selection/caret rects, error
  text, and file-path text now route through the chrome-band seam instead of
  mixing band fills with immediate text/surface paths
- third `RB-B3.f` slice is now in:
  shared top-bar menu shadow and truncated tab titles now route through the
  chrome-band seam; tab title replay also stays inside the tab-strip clip
- fourth `RB-B3.f` slice is now in:
  integrated terminal tab-bar background and shared window caption button
  backgrounds/glyph strokes now route through the chrome-band seam
- chrome-band composition is no longer the loudest scanned gate-5 pressure;
  the next move should pick one remaining family explicitly:
  terminal overlay/modal visuals, terminal progress/scrollbar/content-edge
  visuals, or editor row/overlay composition
- `RB-B3.g` terminal overlay/progress composition is now in:
  close-confirm modal, active-tab progress bar, terminal scrollbar thumb, and
  terminal separator route through a terminal-owned composition seam
- `RB-B3.h` editor row/overlay composition is now in:
  segment-paint immediate helpers, text-decoration rects, composing underline,
  and editor surface-flush handoffs route through the editor overlay/row-band
  owner instead of importing renderer surface/text hosts directly
- generic tooltip overlay composition now routes through
  `renderer_tooltip_host.zig`; widget common code no longer owns tooltip
  fill/outline/text ordering directly
- next renderer move is `RB-B3.i`:
  sample/diagnostic section composition check, then an Android GLES readiness
  re-rank; do not continue broad renderer cleanup unless this check finds a
  real Android-blocking ownership leak
- `RB-B3.i` sample/diagnostic check is now in:
  `font_sample_view.zig` routes its full-view background and unavailable-mode
  status/swatch through `font_sample_section_host.Section`
- Android GLES readiness re-rank result:
  the next move is `AR-B4`, now executing as a controlled backend-skeleton lane

## Parked (not blocking)

**`AS-A3`** — Android direct shell input, modifier-latch assist bar.

The current input path works for real shell use. The latch-model assist bar is
the right long-term direction but is not being polished now. Keep the ticket
open; do not block renderer work on it.

## Completed Tickets

### `AH-A1` Shared Native Host Surface Truth — met

`native_host.zig` carries surface availability, size, density, redraw, and
Android native-window identity with epoch-based transition tracking.

### `AH-A2` First Android Host Mapper — met

`android_host.zig` owns Android lifecycle/surface semantics. Shared code
delegates there instead of embedding Android logic in SDL input paths.

### `AH-A3` Android Host Harness — met, superseded

Java-only host harness proved Note10 callback ordering. Now superseded by
`android/terminal-host/` for all active work.

### `AS-A1` Android First Shell Bring-Up — met

`android_shell_session.zig` runs `/system/bin/sh` through the real terminal
engine. Note10 proved repeatable shell I/O via terminal FFI.

### `AS-A2` Android Live-Shell Product View — met

Product view is shell-first: transcript area, slim assist bar, restart/debug in
a left drawer. IME uses window insets; tap transcript opens IME. Auto-follow
with manual scroll detach.

### `AS-A3` Android Direct Shell Input

Purpose:

- own the full Android terminal input surface — not a Termux clone, but a
  mobile-first model that treats modifier state, key sequences, and the assist
  bar as first-class UX rather than bolted-on workarounds

Acceptance:

- the modifier-latch assist bar replaces the current hardcoded per-combo Ctrl
  path: each modifier (Ctrl, Alt, Esc, Tab) is a toggle that latches down,
  next IME key tap sends the modified input, modifier releases
- no per-combo special casing for common sequences — the latch model covers
  them all without explicit buttons for each
- the assist bar visually reflects modifier state (latched vs idle)
- the live `InputConnection` path stays the single active input surface

Status:

- active — device-validated
- owner doc: `app_architecture/platform/android/ANDROID_SHELL_BRINGUP_PLAN.md`
- direct JNI → Zig → PTY input path now exists:
  - `android_shell_session.zig` exposes direct send helpers
  - `android_bridge_exports.zig` exports `nativeSendShellCodepointBridge`
  - `ZideTerminalActivity` now owns a real `InputConnection` surface
- device validation on the Note10 now proves:
  - character input reaches the shell immediately
  - Enter and Backspace work directly
  - Samsung text-editing arrows now work through the editor model
- stale file-based input indirection has been removed from the active path

Current result:

- product input is no longer limited to “type a whole line then send”
- input latency is now JNI call overhead instead of 150ms poll interval
- the Android input path is now based on a minimal editor model rather than a
  fragile `TextWatcher`
- Java ownership is now split into Android-owned components instead of one
  activity blob:
  - `ShellInputView`
  - `ShellTranscriptController`
  - `ShellSessionController`
  - `AndroidDebugFormatter`
- the product shell now also follows a more honest mobile layout:
  - main terminal area keeps the screen
  - IME opens from transcript tap (ScrollView + `shell_output_text`) instead of
    a permanent toggle
  - a slim bottom assist bar provides phone keyboard helpers
  - restart/debug live in a hidden left drawer instead of the main bar
- local Java tooling is now explicitly supported for this Android app module:
  - JDTLS/Buildship imports should target `android/terminal-host/`, not repo
    root
  - `app/build.gradle` now declares Eclipse/Buildship source and library
    entries for:
    - `src/main/java`
    - Android SDK `android.jar`
    - generated debug `R.jar`
  - that keeps Neovim/JDTLS Android Java resolution honest without tracked
    `.classpath` / `.project` files

Remaining for this ticket:

- replace the current hardcoded Ctrl+A..Z path with a proper modifier-latch
  model on the assist bar:
  - Ctrl, Alt, Esc (and Tab) as stateful toggle buttons, not per-combo helpers
  - latched modifier + any IME key tap → send modified byte → unlatch
  - assist bar reflects latch state visually
- the current hardcoded Ctrl+A..Z bytes stay in place until the latch model
  supersedes them on device
- stop here: do not extend special-key coverage further until the latch model
  is device-validated and the next real gap is clear

### `AH-A4` Android Terminal Host Bridge

Purpose:

- create the first repo-owned Android terminal-host path for the real Zig runtime,
  so Android progress can move from host probing into native entry/bridge work

Acceptance:

- the repo contains an Android app project for the real runtime lane
- the app loads a repo-built native Zig library
- launch + pause/resume + surface-available/lost callbacks reach repo-owned
  native bridge code
- build/install/run instructions are recorded in the owning docs

Status:

- met
- `android/terminal-host/` is the active Android runtime lane app
- the Note10 loads the repo-built Zig library and routes lifecycle/focus/
  surface callbacks into repo-owned native code
- surface identity now has stable authority:
  - `acquired`
  - `unchanged`
  - `replaced`
  - `retired`
- terminal-host/native entry is no longer the Android blocker

### `AP-A1` Android PTY Lifetime Ownership

Purpose:

- define the Android PTY/process lifetime baseline under pause/stop/background
  pressure before any real Android terminal integration

Status:

- met
- Note10 proved the disposable baseline:
  - PTY can outlive visible surface lifetime briefly
  - PTY does not outlive app-process death
- disposable app-process-owned PTY lifetime remains the default Android
  terminal baseline
- the earlier legacy PTY probe implementation is retired from the live app;
  this result remains as architecture evidence only

### `AP-A2` Android PTY Service Survival Probe

Purpose:

- define and execute the narrowest honest foreground-service-owned PTY probe
  without implying terminal product approval

Status:

- met as a separate probe lane
- foreground-service PTY survival is technically viable
- it did not displace the disposable baseline as the default answer
- the earlier legacy service probe implementation is retired from the live
  app; this result remains as architecture evidence only

### `AH-A5` Android GLES Binding Authority

Purpose:

- define the first Android EGL/GLES binding cut precisely enough that it can
  be implemented next without drifting into a fake Android renderer backend

Status:

- met as terminal-host-owned authority
- the terminal host app proves EGL/GLES clear/swap against the live
  `ANativeWindow`
- Note10 proof includes both replacement stories:
  - `replaced`
  - `retired -> acquired`
- current device policy reuses one EGL context while recreating the window
  surface

### `AH-A6` Android GLES Upload/Update Probe

Purpose:

- prove whether one terminal-host-owned GLES texture can survive the already-proved
  surface transitions while also accepting repeated content upload/update

Status:

- met
- terminal-host GLES proof now tracks upload/update separately
- Note10 proved one texture survives redraw and surface replacement while
  accepting repeated content updates

### `AH-A7` Android GLES Texture-Resize Pressure

Purpose:

- prove whether the current terminal-host GLES policy can stay honest when content
  size changes materially, not just when the surface is recreated or the same
  texture receives repeated updates

Status:

- met as terminal-host runtime evidence
- holder-driven size pressure advances texture upload/resize counts without
  hidden context churn on the Note10
- this remains runtime evidence, not product resize authority

### `AR-B1` Android Renderer Adoption Unblock

Purpose:

- execute only the next renderer cut that materially unblocks first-class
  Android renderer adoption

Owner docs:

- `docs/todo/ui/renderer.md`
- `app_architecture/ui/RENDER_BACKEND_CONTRACT.md`
- `app_architecture/ui/RENDER_BACKEND_CURRENT_STATE.md`

Status:

- met
- renderer gate #5 family-summary work landed:
  - `chrome_band`
  - `editor_row_band`
  - `sample_section`
- Android renderer adoption is no longer blocked by terminal-only frame family
  reporting
- present feedback now consumes shared frame-family truth instead of
  terminal-only submission meaning

Acceptance:

- the next renderer cut is explicit about what Android backend adoption would
  stop having to special-case afterward
- Android queue and renderer queue both point at the same blocker
- Android work returns here after that renderer cut lands

Do not do:

- no reopening gate #2 for active work unless Mac validation is explicitly
  reopened
- no generic renderer cleanup with no Android leverage
- no pretending terminal-host EGL proof by itself is equivalent to shared Android
  renderer readiness

Current follow-up:

- `AR-B1` is structurally complete
- `AR-B2` is also structurally complete:
  widget/runtime no longer carries direct-vs-retained terminal-present path
  decisions
- the next Android renderer adoption unblock is `AR-B3`:
  presentable lifecycle parity behind neutral types

## Current Research Read

- Android host truth is clearly native-window lifecycle truth, not persistent
  desktop-window truth.
- Native PTY subprocesses are viable on Android (`/dev/ptmx` + JNI subprocess
  launch is established practice).
- The real PTY risk is Android background/process policy, especially on Android
  12+, not basic PTY availability.

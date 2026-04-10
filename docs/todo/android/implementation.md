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

Right now the biggest shared blocker to first-class Android renderer adoption
is renderer gate #5:

- presentable/frame routine is still not neutral enough for a new backend to
  feel routine, even though shared frame-family feedback now covers terminal,
  chrome band, editor row-band, and sample section

That means:

- gate #2 is treated as closed for active work until Metal validation is
  explicitly reopened
- gate #4 is met
- Android terminal-host proof should only continue if it answers a stronger
  Android-specific runtime question than gate #5 does
- otherwise the next honest move is the next gate-5 cut done explicitly in
  service of Android terminal progress

## Current Priority

**`AR-B3` / `RB-B3.e`** — this is the active ticket.

Make presentable lifecycle parity more honest behind neutral types so Android
does not inherit "OpenGL retained target is the real model, Metal is the
fallback model" as shared renderer truth.

Owner docs:

- `app_architecture/ui/PRESENTABLE_LIFECYCLE_PARITY_PLAN.md`
- `docs/todo/ui/renderer.md`

Guardrails:

- do not drift back into Android host/tooling cleanup
- do not reopen `AS-A3` polish
- do not start Android GLES backend code from this ticket

Current checkpoint:

- the first `AR-B3` code cut is in:
  shared renderer code now speaks in terminal-presentable refresh terms rather
  than retained-target update terms
- the active widget/runtime refresh flow now also uses that neutral language
  end-to-end instead of retained-path naming
- shared widget/runtime no longer owns the direct-versus-retained execution
  branch for terminal presentation; that choice now terminates in
  `renderer_presentable_host.zig`
- the parallel `TerminalPresentPath` classifier is also gone from the active
  presentable dispatch/host surface; presentable-host decisions now resolve
  from declared `TerminalPresentationMode` capability truth instead
- this does not claim parity is solved yet
- it makes the remaining blocker narrower and more honest before deeper
  presentable work

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

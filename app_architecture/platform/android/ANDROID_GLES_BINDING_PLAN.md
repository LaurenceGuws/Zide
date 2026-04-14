# Android GLES Binding Plan

Purpose: define the first honest Android rendering-binding cut after Android
terminal-host truth, without reopening blocked shared-renderer work.

This doc is authority for the first Android GLES/EGL binding step.

Owner docs:

- `app_architecture/platform/android/RENDER_BACKEND.md`
- `app_architecture/platform/android/ANDROID_TERMINAL_HOST_PLAN.md`
- `app_architecture/platform/android/SURFACE_IDENTITY_POLICY.md`
- `app_architecture/ui/RENDER_BACKEND_CONTRACT.md`
- `docs/todo/android/implementation.md`
- `docs/todo/ui/renderer.md`

Reference pressure:

- `dev_references/platform/android/ndk-samples/native-activity/`
- `dev_references/platform/android/ndk-samples/endless-tunnel/`
- `dev_references/platform/android/ndk-samples/native-codec/`

## Why This Is Separate

The Android-native terminal-host lane already proved:

- lifecycle truth
- replaceable `ANativeWindow` truth
- explicit `acquired` / `unchanged` / `replaced` / `retired` surface identity
- Note10 callback ordering for pause / stop / destroy / reacquire

That is enough to define the first Android rendering-binding cut precisely.

That proof was originally not enough to start a real Android renderer backend
because renderer gate #5 was still open.

That has changed.

Current renderer authority now says:

- gate #5 is structurally met for scanned composition families
- gate #2 live Metal verification remains deferred until Mac access returns
- Android GLES may start as a controlled planning/first-slice lane

So this doc is now historical/probe authority. The new backend-planning
authority is:

- `app_architecture/platform/android/ANDROID_GLES_BACKEND_PLAN.md`

## Decision

The first Android rendering-binding cut should be:

- terminal-host-owned
- EGL + GLES based
- surface-identity-aware
- behaviorally tiny

It should not be:

- a new `RendererBackend` in `src/`
- a partial Android port of the real renderer
- a fake-generic mobile abstraction

## What The References Actually Say

The local Android refs converge on the same practical shape:

- `native-activity` shows lifecycle and draw pacing as native-window-owned
  runtime truth
- `native-codec` shows Java `Surface` to `ANativeWindow` bridging with
  explicit native-window reference ownership
- `endless-tunnel` shows EGL context/surface lifecycle living with the Android
  runtime owner instead of leaking into higher-level product code

Useful pressure from those refs:

- EGL state should be owned by the Android runtime binding layer
- `ANativeWindow` replacement/destruction must directly drive EGL surface
  replacement
- focus/pause/stop/window loss are real runtime events, not rare cleanup

What not to copy:

- native-activity as the product app entry model
- sample-owned game loops or scene models
- any larger C++ object model just because the samples use one

## Required Questions

This lane must answer:

1. Where does Android EGL state live before a real shared Android backend
   exists?
2. How does `surfaceIdentityEpoch` drive EGL surface retirement/recreation?
3. What is the smallest visible rendering proof that exercises real Android
   surface replacement truth without smuggling renderer architecture?
4. What exact boundary keeps this as terminal-host-owned binding work instead of
   premature backend implementation?

## Binding Boundary

The first cut must keep ownership here:

- Java activity / `SurfaceView` callbacks
- `android_runtime_bridge.zig`
- one Android-only native rendering binding module under `src/platform/`
  or a clearly Android-terminal-host-owned native file

It must not cross into:

- `src/ui/renderer/`
- `RendererBackend` variants
- shared draw payloads
- shared frame/presentable contracts

Reason:

- the current renderer queue still blocks a real Android backend
- this binding cut exists to prove Android window + EGL mechanics, not to
  pretend the backend contract is already routine

## `AH-A5` Scope

Purpose:

- define and execute the smallest Android EGL binding proof that is still
  honest about `ANativeWindow` lifecycle and replacement

Acceptance:

- one authority doc defines the first Android EGL/GLES binding cut
- the cut is explicitly scoped to `android/terminal-host/` and the native
  bridge, not `src/ui/renderer/`
- the first executable binding step is defined as:
  - acquire EGL display
  - choose config
  - create GLES context
  - create/destroy EGL window surface from the current `ANativeWindow`
  - draw one trivial frame
  - swap buffers
  - recreate the EGL window surface when surface identity changes
- docs record that this is a terminal-host-owned proof, not a real backend launch

Do not do:

- no `RendererBackend.opengl_es`
- no shared renderer integration
- no text, terminal, atlas, or retained-presentable work
- no surface-loss shortcuts that ignore `replaced` or `retired`

## First Executable Cut

The first executable GLES/EGL proof should be exactly:

- keep the existing terminal-host activity and native bridge
- add one Android-only EGL binding owner behind that bridge
- on surface available:
  - ensure EGL display/config/context exist
  - create one EGL window surface for the current `ANativeWindow`
- on draw request:
  - clear the surface to one visible color
  - `eglSwapBuffers`
- on `replaced` or `retired`:
  - destroy the old EGL window surface
  - do not trust raw native-window pointer equality by itself
- on later `acquired`:
  - create the next EGL window surface against the new identity epoch

That cut is enough to prove:

- Android window binding mechanics are real in this repo
- future Android renderer work can inherit the replacement truth already proven
- the bridge/build path supports real GPU presentation before shared backend
  integration starts

## Stop Marker

Stop `AH-A5` when:

- the first Android EGL binding cut is written down clearly enough to execute
- the scope boundary against `src/ui/renderer/` is explicit
- the queue/docs say what the first Android rendering proof is, and what it is
  not

## Current Probe Result

The first executable GLES cut is implemented in the terminal host app.

Current Note10 truth:

- EGL display/context/window-surface binding works against the live
  `ANativeWindow`
- the probe follows `surfaceIdentityEpoch` and transition truth instead of raw
  pointer equality
- both replacement stories are proved:
  - `replaced`
  - `retired -> acquired`
- current terminal-host policy reuses one EGL context across those surface
  transitions
- one minimal GLES texture survives redraw and surface replacement on the
  current device path

It still does not prove:

- a shared Android renderer backend exists
- presentable/frame routines are ready for Android in `src/ui/renderer/`
- terminal/text/product rendering belongs in this lane yet
- that every Android device should keep the EGL context alive across the same
  transitions without stronger device pressure
- that full renderer resource graphs should adopt this policy without later
  shared-backend authority

## Upload/Update Probe Result

The next honest Android-owned GLES question was:

- can one terminal-host-owned GLES texture survive the proven surface transitions
  while also accepting repeated content upload/update, not just continued
  object existence checks

Observed on the Note10 (2026-04-09):

- the terminal-host GLES probe now tracks:
  - `glesTextureUploads`
  - `glesTextureUpdates`
- texture creation performs one explicit `glTexImage2D` upload
- later redraw/surface passes perform `glTexSubImage2D` updates against the
  same texture when the context still owns it
- the terminal host app/status UI surfaces those counters alongside:
  - `glesTextureCreates`
  - `glesTextureAlive`
- the first acquire showed:
  - `glesTextureUploads=1`
  - `glesTextureUpdates=0`
- the first redraw advanced to:
  - `glesTextureUploads=1`
  - `glesTextureUpdates=1`
- a true in-process `replaced` transition then showed:
  - `glesTextureUploads=1`
  - `glesTextureUpdates=4`
  - `glesContextCreates=1`
  - `glesSurfaceCreates=2`
  - `glesTextureCreates=1`
  - `glesTextureAlive=true`
- later background-side retirement showed:
  - `glesTextureUploads=1`
  - `glesTextureUpdates=11`
  - `glesContextCreates=1`
  - `glesTextureCreates=1`
  - `glesTextureAlive=true`
- later fresh `acquired` after retirement showed:
  - `glesTextureUploads=1`
  - `glesTextureUpdates=12`
  - `glesContextCreates=1`
  - `glesSurfaceCreates=3`
  - `glesTextureCreates=1`
  - `glesTextureAlive=true`

This proves:

- one terminal-host-owned GLES texture can survive the proven surface transitions
  while also accepting repeated content updates on the Note10
- the current terminal-host policy still performs one initial upload, then keeps
  updating the surviving texture rather than recreating or reuploading it
- `replaced` and `retired -> acquired` do not currently force hidden context
  or texture recreation on this device path

## Texture-Resize Pressure Checkpoint

The first `AH-A7` runtime-pressure pass is now implemented and observed.

Current probe additions:

- `glesTextureResizes`
- `glesTextureSize`
- a terminal-host debug path that forces one synthetic `SurfaceView` size change

Observed on the Note10 (2026-04-09):

- the cleaner holder-driven resize path now produces an explicit sane
  `surface.changed` callback:
  - `size=1356x552`
  - later restore back to `size=1356x1104`
- those callbacks advanced the probe state like this:
  - shrink:
    - `glesTextureUploads=2`
    - `glesTextureUpdates=2`
    - `glesTextureResizes=1`
    - `glesTextureSize=1356x552`
  - restore:
    - `glesTextureUploads=3`
    - `glesTextureUpdates=4`
    - `glesTextureResizes=2`
    - `glesTextureSize=1356x1104`
  - throughout:
    - `glesContextCreates=1`
    - `glesSurfaceCreates=1`
    - `glesTextureCreates=1`
- that means size pressure can force a texture reallocation/upload while still
  keeping the same EGL context, EGL surface, and texture object identity on
  this path

Important caveat:

- after the clean shrink/restore sequence, Android still later emitted an
  extra odd callback:
  - `surface.changed ... size=2675x0`
- the probe clamps non-positive dimensions before `glTexImage2D`, so this
  became `glesTextureSize=2675x2` instead of a literal zero-height upload
- that late callback does not invalidate the cleaner earlier result, but it
  means the current debug resize path is still not perfect enough to serve as
  final product resize authority

## Decision From Probe

The first Android EGL binding cut is now structurally met.

Terminal-host EGL lifecycle hardening is now structurally met too.

Current honest answer:

- terminal-host-owned Android EGL/GLES binding is viable in this repo
- that reduces Android uncertainty materially
- surface replacement and retirement/reacquire now both have device proof on
  the Note10
- current terminal-host policy can keep one EGL context alive while recreating only
  the window surface across those transitions on the Note10
- one minimal context-owned GLES resource also survives those transitions on
  the Note10
- it still remains terminal-host-owned proof work, not shared renderer adoption

After that:

- keep this lane below `src/ui/renderer/`
- do not claim a shared Android backend exists yet
- let later Android backend work inherit this replacement truth instead of
  rediscovering it
- the next Android-owned GLES question is now:
  - texture-size/resize pressure
  - specifically, whether materially different content dimensions force honest
    texture reallocation/upload behavior while context and surface policy stay
    legible
- the current answer is partial:
  - yes, size pressure can force honest reallocation/upload without hidden
    context churn on the Note10
  - but the debug resize path still needs one more tightening pass because
    Android later emits an extra pathological callback after the clean
    shrink/restore sequence
  - IME is not that tightening pass on this device/configuration, because the
    cleaned-up product-view IME probe now behaves as an overlay and does not
    materially interact with surface geometry

## Backend Handoff

`AH-A5` through `AH-A7` are now probe-complete for the purpose of opening the
first controlled backend planning cut.

Handoff rule:

- do not keep hardening `android_gles_surface_status.zig` by default
- use its EGL/context/surface/texture evidence to inform `AR-B4.a`
- once `AR-B4.a` validates, either collapse the probe behind the shared Android
  GLES runtime owner or delete it if fully superseded

Next authority:

- `app_architecture/platform/android/ANDROID_GLES_BACKEND_PLAN.md`

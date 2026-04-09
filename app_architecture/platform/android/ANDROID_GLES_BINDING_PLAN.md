# Android GLES Binding Plan

Purpose: define the first honest Android rendering-binding cut after Android
host/bootstrap truth, without reopening blocked shared-renderer work.

This doc is authority for the first Android GLES/EGL binding step.

Owner docs:

- `app_architecture/platform/android/RENDER_BACKEND.md`
- `app_architecture/platform/android/BOOTSTRAP_BRIDGE_PLAN.md`
- `app_architecture/platform/android/SURFACE_IDENTITY_POLICY.md`
- `app_architecture/ui/RENDER_BACKEND_CONTRACT.md`
- `docs/todo/android/implementation.md`
- `docs/todo/ui/renderer.md`

Reference pressure:

- `dev_references/platform/android/ndk-samples/native-activity/`
- `dev_references/platform/android/ndk-samples/endless-tunnel/`
- `dev_references/platform/android/ndk-samples/native-codec/`

## Why This Is Separate

The Android-native host/bootstrap lane already proved:

- lifecycle truth
- replaceable `ANativeWindow` truth
- explicit `acquired` / `unchanged` / `replaced` / `retired` surface identity
- Note10 callback ordering for pause / stop / destroy / reacquire

That is enough to define the first Android rendering-binding cut precisely.

It is not enough to start a real Android renderer backend in `src/`.

The renderer queue still says:

- gate #2 remains deferred on live Metal verification
- gate #5 is not yet routine enough for a new backend to feel boring

So the next Android rendering step must stay below that line:

- prove Android EGL + `ANativeWindow` binding shape
- do not claim a real shared Android backend exists yet

## Decision

The first Android rendering-binding cut should be:

- bootstrap-bridge-owned
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
4. What exact boundary keeps this as bootstrap-owned binding work instead of
   premature backend implementation?

## Binding Boundary

The first cut must keep ownership here:

- Java activity / `SurfaceView` callbacks
- `android_runtime_bridge.zig`
- one Android-only native rendering binding module under `src/platform/`
  or a clearly Android-bootstrap-owned native file

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
- the cut is explicitly scoped to `android/bootstrap-bridge/` and the native
  bridge, not `src/ui/renderer/`
- the first executable binding step is defined as:
  - acquire EGL display
  - choose config
  - create GLES context
  - create/destroy EGL window surface from the current `ANativeWindow`
  - draw one trivial frame
  - swap buffers
  - recreate the EGL window surface when surface identity changes
- docs record that this is a bootstrap-owned proof, not a real backend launch

Do not do:

- no `RendererBackend.opengl_es`
- no shared renderer integration
- no text, terminal, atlas, or retained-presentable work
- no surface-loss shortcuts that ignore `replaced` or `retired`

## First Executable Cut

The first executable GLES/EGL proof should be exactly:

- keep the existing bootstrap activity and native bridge
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

The first executable cut is now implemented through the bootstrap bridge:

- `src/platform/android_gles_probe.zig` owns one Android-only EGL display /
  context / window-surface probe
- `android_runtime_bridge.zig` routes current surface identity epoch and
  transition truth into that probe
- the bootstrap activity logs native EGL probe state as `gles=...`

Observed on the Note10:

- first surface acquire now produces:
  - `native.surfaceAvailable seq=4 ... epoch=1 transition=acquired gles=drawn`
- redraw-needed now also produces:
  - `native.surfaceRedrawNeeded seq=5 gles=drawn`
- later same-surface geometry churn stays:
  - `transition=unchanged gles=drawn`
- redraw-needed continues to succeed under those same-window updates

This proves:

- the repo can create an EGL display/context/window-surface against the current
  `ANativeWindow`
- one visible GLES clear/swap path is real on-device
- the probe already follows the Android surface identity contract rather than
  trusting raw pointer equality alone

It still does not prove:

- a shared Android renderer backend exists
- presentable/frame routines are ready for Android in `src/ui/renderer/`
- terminal/text/product rendering belongs in this lane yet

## Decision From Probe

The first Android EGL binding cut is now structurally met.

Current honest answer:

- bootstrap-owned Android EGL/GLES binding is viable in this repo
- that reduces Android uncertainty materially
- it still remains bootstrap-owned proof work, not shared renderer adoption

After that:

- either execute the bootstrap-owned EGL clear/swap proof on device
- or stop if stronger renderer authority says Android rendering must wait again

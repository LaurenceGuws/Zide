# Android Surface Identity Policy

Purpose: define the product-level host truth for Android surface metrics
updates, surface identity changes, and render-host invalidation pressure after
the bootstrap bridge proved real `ANativeWindow` identity on device.

Owner docs:

- `app_architecture/platform/NATIVE_HOST_CONTRACT.md`
- `app_architecture/platform/android/RENDER_BACKEND.md`
- `app_architecture/platform/android/BOOTSTRAP_BRIDGE_PLAN.md`
- `docs/todo/android/implementation.md`

## Why This Is Next

The bootstrap bridge now proves three different Android surface behaviors on
the Note10:

1. repeated `surface.changed` callbacks can happen against one stable native
   window identity
2. those same-window updates can change drawable geometry substantially
3. `surface.destroyed` still happens later and clears native-window identity

That means Android host truth is no longer "do we have a native window?".
It is now:

- when did the current native window identity stay the same?
- when did it change?
- what should future renderer/backend work do in each case?

## Current Proven Device Truth

Observed through `android/bootstrap-bridge/` on the Note10:

- cold launch:
  - `native.surfaceAvailable seq=4 token=0x... epoch=1`
  - `native.surfaceAvailable seq=5 token=0x... epoch=1`
- forced rotation via system settings:
  - `native.surfaceAvailable seq=7 token=0x... epoch=1`
  - `native.surfaceAvailable seq=8 token=0x... epoch=1`
  - `native.surfaceAvailable seq=9 token=0x... epoch=1`
- backgrounding:
  - `native.surfaceDestroyed seq=11 token=0x0 epoch=2`

The important result is:

- large geometry changes can still be same-surface updates
- identity change is not implied by resize, redraw, pause, or rotation alone
- identity change is explicit when `surfaceIdentityEpoch` advances

## Decision

Android host/render truth must use two different signals:

- geometry signal:
  - drawable/logical size, density, redraw-needed
- identity signal:
  - `surfaceIdentityEpoch`

Rule:

- same `surfaceIdentityEpoch` means the native window identity is unchanged
- advanced `surfaceIdentityEpoch` means the native window identity changed
  enough that window-bound backend resources must be treated as stale

This keeps shared renderer/backend code from inferring replacement by comparing
raw Android pointers or overreacting to every resize.

## Required Policy

Same-epoch surface updates mean:

- keep treating the render host as the same surface identity
- update geometry and redraw pressure
- do not treat the window-bound backend state as replaced just because size
  changed

Epoch-advance updates mean:

- the previous native window identity is no longer current
- any future backend bound to that window must revalidate or recreate
  window-bound resources
- shared code should not need to guess whether a new surface identity exists

Unavailable surface means:

- no drawable surface is available
- the current native-window token is null
- the latest `surfaceIdentityEpoch` still records that the prior identity was
  retired

## What This Does Not Decide

This policy does not decide:

- GLES backend bootstrap
- Vulkan backend bootstrap
- Android PTY/service lifetime policy
- renderer frame/present sequencing beyond surface identity truth

## `AH-A5` Scope

Purpose:

- tighten Android surface replacement / destruction policy around the now
  explicit token + `surfaceIdentityEpoch` path

Acceptance:

- the owner docs explicitly distinguish same-surface geometry change from
  surface identity change
- the shared host seam is documented as the identity authority for future
  Android renderer work
- the next Android rendering-adjacent blocker is surface replacement policy,
  not bootstrap uncertainty

Do not do:

- no GLES or Vulkan work
- no PTY/runtime lifetime design
- no fake renderer integration just to prove the policy

# Android Render Backend

Purpose: define how Android satisfies Zide's native host contract with native
Android lifecycle and native window ownership.

This doc is architecture authority for Android-native render-host shape.

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

## Explicit Anti-Goals

Do not:

- design Android as a deferred backend footnote under the macOS plan
- treat surface loss as incidental cleanup
- assume a persistent top-level window
- force desktop-style host abstractions onto Android

# CZH-1241 Android-to-Core Seam Map

Sprint: `CZH-S75`  
Batch: `CZH-B80`  
Gate: `CZH-GATE-134`

## Purpose

Name concrete Android-specialized seams that should be owned by shared core contracts, then define exact executable cuts.

## Target Classification

1. `src/ui/renderer/input_runtime.zig`  
Classification: shared contract seam with Android-specialized callsites.  
Evidence: input runtime directly imported Android-specific helper modules and dispatched lifecycle/focus/refresh behavior through Android-specific functions.

2. `src/platform/android_runtime_bridge.zig`  
Classification: Android-owned bridge using shared lifecycle semantics.  
Evidence: bridge lifecycle/surface transitions duplicated lifecycle/focus/surface side-effects already needed by shared host contracts.

3. `src/platform/android_host.zig` + `src/platform/sdl_android_host.zig`  
Classification: Android helper wrappers that held logic now better owned by one shared runtime seam.

## Executable Follow-Ups

### `CZH-1242` First consolidation cut (shared lifecycle seam extraction)

- New shared owner: `src/platform/host_lifecycle_runtime.zig`
- Functions extracted as shared contract behavior:
  - app lifecycle transitions (`will/did foreground`, `will/did background`)
  - surface focus policy for window-driven focus changes
  - surface metrics/surface destroyed transitions
- Callsite migration:
  - `src/ui/renderer/input_runtime.zig`
  - `src/platform/android_runtime_bridge.zig`

### `CZH-1243` Second consolidation cut (callsite + ownership cleanup)

- Remaining Android-specialized callsite path removed:
  - SDL window refresh path now routes through shared lifecycle seam (`noteSdlWindowRefresh`) instead of Android-specific dispatch in input runtime.
- Wrapper alignment:
  - `src/platform/android_host.zig`
  - `src/platform/sdl_android_host.zig`
  - both now delegate to shared seam ownership instead of carrying duplicate behavior logic.

## Non-Goals

- No behavior or ABI changes.
- No broad renderer/backend refactor.
- No Android feature expansion.

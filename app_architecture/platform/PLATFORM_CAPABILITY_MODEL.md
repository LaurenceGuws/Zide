# Platform Capability Model

Purpose: define how Zide describes platform capability truth without reducing a
platform to a renderer label or forcing one platform's mechanics onto another.

This doc is architecture authority for capability naming under the shared
native-host contract.

## Why This Exists

The repo already has platform metadata in `build_system/platform_capabilities.zig`.
That metadata is useful, but it still over-describes platforms in backend-first
terms such as "OpenGL via SDL3/system GL."

That is too weak for a first-class native product.

Platform capability truth must describe:

- native host shape
- lifecycle ownership pressure
- render-host shape
- install/runtime requirements
- platform-specific optional features

Not just:

- which graphics API happens to be live today

## Design Standard

The capability model must be:

- honest about current implementation truth
- explicit about target host truth
- strict about product invariants
- neutral about platform mechanics

The capability model must not:

- pretend the current backend is the full platform story
- hide native lifecycle pressure behind SDL
- treat mobile and desktop as the same host with more callbacks
- bake one platform's affordances into the base contract

## Capability Layers

Platform capability descriptions should be read in this order:

1. host contract truth
2. current implementation truth
3. optional platform features
4. platform/runtime linkage requirements

### Host Contract Truth

This describes the native centers the platform implementation must satisfy.

Required fields:

- `host_contract`
- `app_host_shape`
- `render_host_shape`

### Current Implementation Truth

This describes the live implementation surface, not the target architecture.

Required field:

- `current_runtime_graphics_path`

### Optional Platform Features

These are capabilities the product may use when present, but which are not the
base contract itself.

Examples:

- multi-window support
- app-wide file-open intent
- deep-link support
- menu-bar ownership
- IME composition
- surface replacement without process restart
- packaged shell integration
- bundled terminal install surface

These should be modeled as explicit booleans or explicit documented support,
not inferred from OS names.

### Platform Runtime Requirements

These remain practical build/runtime requirements and may stay in
`build_system/platform_capabilities.zig`.

Examples:

- required system libraries/frameworks
- required system headers or include paths
- subsystem flags
- packaging-specific resource handling

These are real capability facts, but they are not a substitute for host
contract truth.

## Required Naming Rules

Platform metadata and reports should prefer names like:

- `host_contract`
- `app_host_shape`
- `render_host_shape`
- `current_runtime_graphics_path`

Avoid names that imply the platform is defined by one backend, such as:

- `graphics_backend`

unless the field is explicitly scoped to the current runtime implementation.

## Current Application To Zide

Current repo direction should read like this:

- Linux:
  - current runtime path: SDL3 + OpenGL
  - host contract pressure: SDL-managed host today, but still accountable to
    the shared native-host contract where platform truth matters
- macOS:
  - current runtime path: SDL3 + OpenGL build lane
  - target host shape: AppKit + Cocoa view host + Metal
- Windows:
  - current runtime path: SDL3 + OpenGL
  - host contract pressure: native shell/install surfaces matter beyond the GL
    path
- Android:
  - target host shape: Activity + Surface/ANativeWindow + GLES-first backend

## Relationship To Other Docs

- `app_architecture/platform/NATIVE_HOST_CONTRACT.md` defines invariant truth.
- `app_architecture/platform/NATIVE_HOST_REFERENCE_CROSSCHECK.md` explains why
  this capability model is necessary.
- `app_architecture/platform/macos/RENDER_BACKEND.md` and
  `app_architecture/platform/android/RENDER_BACKEND.md` define concrete
  platform satisfaction of the shared contract.

## Immediate Consequence

Platform wording in build metadata, build reports, and planning docs should now
distinguish:

- current runtime graphics path
- native host shape
- optional platform capabilities

That is the minimum honest vocabulary required to keep the macOS and Android
paths cohesive without platform-specific architecture drift.

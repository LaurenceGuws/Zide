# Android Zig Bridge Naming Contract

Purpose: define one naming grammar and glossary for Android-facing Zig bridge
code so APIs stay short, current, and ownership-led.

Scope:

- `src/android_bridge_exports/*.zig`
- `src/platform/android_runtime_bridge.zig`
- Android-owned bridge/runtime adapters such as
  `src/platform/host_lifecycle_runtime.zig` and
  `src/platform/android_gles_surface_status.zig`

This is naming authority only. It complements Android architecture/ownership
docs and reuses the same product glossary used in Java cleanup.

## Naming Strategy

- prefer package/module context over long prefixes
- keep bridge API names event-first and short
- keep JNI export symbols stable; improve internal helper names freely
- keep mechanical naming cuts separate from behavior changes

## Shared Glossary (Aligned With Java)

- `Readiness`: current product-operable state for Android userland
- `Provisioning`: filesystem/prefix materialization and artifact staging
- `BaselinePackages`: required package set needed for first-class use
- `PackageManager`: user-facing package CLI integration (`zide-pm`)

- `Controller`: owns behavior/state transitions for one concern
- `Assembly`: wires a construction graph and returns immutable assembled result
- `Factory`: creates related objects without owning runtime policy
- `Bridge`: adapts one interface boundary to another
- `Callbacks`: typed callback contract passed into an owner
- `Native`: JNI/NDK boundary only

## Bridge API Grammar

- lifecycle/surface events: `on*`
  - examples: `onCreate`, `onResume`, `onSurfaceAvailable`
- current-state queries: noun or `current*`
  - examples: `currentSurfaceEpoch`, `rendererActive`, `visibleRows`
- mutating commands: imperative verb
  - examples: `restartSession`, `setScrollbackOffset`, `followLiveBottom`

## Conventions

- do not keep `Shell` prefixes when module scope is already shell-session
- avoid `note*` for event entrypoints; use `on*`
- avoid stacked concept chains in one identifier
- use camelCase for local Zig names exposed through bridge helpers
- keep old terminology out of comments/log labels unless documenting historical
  behavior explicitly

## Rename-Cut Rules

- one mechanical slice at a time
- validate at minimum with:
  - `zig build android-terminal-host-bridge -Dtarget=aarch64-linux-android -Dmode=terminal -Doptimize=Debug --sysroot /home/home/.local/share/zide-android-sdk/ndk/27.1.12297006/toolchains/llvm/prebuilt/linux-x86_64/sysroot`
  - `./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac`
- when naming boundaries move, update this contract and
  `docs/todo/android/implementation.md` in the same cut

## Approved Term Map

- `note*` event entrypoints -> `on*` event entrypoints
- `ProbeStatus` / `ProbeState` -> `RendererStatus` / `RendererState`
- `android_gles_probe.zig` -> `android_gles_surface_status.zig`
- `terminal_session_bootstrap.zig` -> `terminal_session_runtime_factory.zig`
- `restartShellSession` / `currentShell*` -> concise runtime names
  (`restartSession`, `visibleRows`, `selectionRect*`, etc.)

## Forbidden Terms Checklist

Do not introduce these in new Android Zig bridge/product-path code unless a
doc explicitly marks historical context:

- `note*` event entrypoint names on Android-owned seams
- `ProbeStatus` / `ProbeState` type names for product runtime status
- `android_gles_probe` module naming in active bridge/runtime paths
- `terminal_session_bootstrap` module naming in runtime factory paths
- long bridge helper chains like `restartShellSession` / `currentShell*` when
  concise runtime names exist

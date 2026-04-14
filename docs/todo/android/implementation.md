# Android Terminal Queue

Active Android plan/todo/workflow. This is the only live queue document for
Android terminal work.

## Document Roles

- This file: active `focus`, `todo`, and `workflow`.
- `ANDROID_JAVA_HOST_STRUCTURE.md`: Java ownership and structure contract.
- `ANDROID_JAVA_NAMING_CONTRACT.md`: Java naming glossary and grammar.
- `ANDROID_ZIG_BRIDGE_NAMING_CONTRACT.md`: Zig bridge naming grammar aligned
  to the Java glossary.
- `ANDROID_SHELL_BRINGUP_PLAN.md`: closed shell-readiness baseline record and decisions.
- `ANDROID_TERMINAL_HOST_PLAN.md`: long-lived architecture constraints.

Do not duplicate active queue content into owner docs.

## Scope

In scope:

- Android-owned terminal behavior and host/runtime integration
- product interaction behavior required for daily terminal use
- Android pressure that exposes shared renderer/runtime blockers

Out of scope:

- speculative backend work without a current Android blocker
- generic hygiene that does not unblock current Android work
- rewriting closed shell-readiness baseline history as active tasks

## Current Focus

`AN-A1` Interactive Neovim terminal baseline quality.

Focus goals:

- keep interactive terminal behavior stable under real usage
- keep `ZideTerminalActivity` as wiring, not policy
- keep Android-native interaction ownership clear (gesture/chrome/selection)

## Active TODO

1. Continue activity thinning only where methods still own policy.
2. Keep Java ownership boundaries aligned with
   `ANDROID_JAVA_HOST_STRUCTURE.md`.
3. Stabilize selection/scroll interaction behavior under manual device usage.
4. Keep debug/profiling instrumentation behind explicit flags and remove stale
   probes after fixes land.

## Workflow

Use this exact loop for every Android task:

1. Pick one smallest actionable cut from `Active TODO`.
2. Implement only that cut.
3. Validate:
   - Java compile: `./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac`
   - Deploy when runtime behavior changed:
     `./ops/android_terminal_host.py --variant release deploy`
   - Manual device check for the exact behavior touched
4. Update docs that own the changed contract.
5. Commit a small cohesive change.

## Done Criteria for a Cut

A cut is done only if all are true:

- behavior is correct on device for the targeted scenario
- ownership is clearer than before (not just moved code)
- docs match the new ownership/behavior
- validation commands pass for touched layers

## Guardrails

- Work on `main` unless the user explicitly asks for a branch.
- Do not create parallel authorities for the same decision.
- Do not leave temporary debug pathways active without a flag.
- Do not move terminal truth from Zig into Java.

## Current Status Snapshot

- interactive shell + Neovim baseline is usable on-device
- `ZideTerminalActivity` is now wiring/lifecycle/orchestration-oriented
  (current size: `581` lines; JNI moved out to `TerminalNativeBridge`)
- host callback seams are adapter-backed (`*HostCallbacks` /
  `*HostLifecycleCallbacks`) instead of activity-owned anonymous blocks
- assist modifier latch presentation now lives in chrome host wiring instead of
  the activity
- product runtime, chrome, surface, session, selection, gesture, input, and UI
  construction now terminate in dedicated `host/*Factory` classes
- chrome bridge/callback construction now lives in
  `host/ui/ChromeFactory`
- selection/gesture controller construction now lives in
  `host/interaction/InteractionFactory`
- hardware-keyboard and IME-focus-recovery controller construction now lives in
  `host/input/InputFactory`
- surface host bridge/callback construction now lives in
  `host/surface/SurfaceFactory`
- product-runtime/frame-loop construction now lives in
  `host/runtime/RuntimeFactory`
- shell-session and userland-session host bridge construction now lives in
  `host/session/SessionFactory`
- UI host construction now lives in `host/ui/UiFactory`
- session/runtime activity wiring now composes through
  `host/session/SessionAssembly` + `SessionAssemblyCallbacks`
- initial status/view activity wiring now composes through
  `host/status/StatusViewAssembly` + `StatusViewCallbacks`
- interaction activity wiring now composes through
  `host/interaction/InteractionAssembly` + `InteractionCallbacks`
- widget/chrome/view-mode/surface activity wiring now composes through
  `host/ui/WidgetAssembly` + `WidgetCallbacks`
- userland runtime-assets/workflow startup activity wiring now composes through
  `host/userland/WorkflowAssembly` + `WorkflowAssemblyCallbacks`
- product-runtime controller startup activity wiring now composes through
  `host/runtime/ProductRuntimeAssembly` + `ProductRuntimeAssemblyCallbacks`
- activity lifecycle native/status/session/surface wiring now composes through
  `host/lifecycle/LifecycleController` + `LifecycleCallbacks`
- input-view install and input controller activity wiring now composes through
  `host/input/InputAssembly` + `InputCallbacks`
- surface/widget activity wiring now composes through
  `host/surface/SurfaceWidgetAssembly` +
  `SurfaceWidgetAssemblyCallbacks`
- post-construction UI bind/start activity wiring now composes through
  `host/ui/UiStartupAssembly` + `UiStartupCallbacks`
- terminal surface widget seam is established in
  `host/surface/SurfaceWidgetController` for future tabbed hosting
- debug surface snapshot composition moved to
  `debug/TerminalSurfaceStateSnapshotReader`
- JNI bridge exports now use only current `uk.laurencegouws.terminal` symbol
  ownership
- readiness evaluation now uses only `.zide-userland-readiness.json`
- Zig bridge surface/event API names now use concise current lifecycle wording
  (`onCreate/onStart/onResume/...`, `onSurface*`, `currentSurface*`) and
  internal Android runtime alias naming no longer uses bootstrap terminology
- JNI export surface is now split into ownership files:
  `src/android_bridge_exports/lifecycle_surface_exports.zig`,
  `src/android_bridge_exports/renderer_state_exports.zig`,
  `src/android_bridge_exports/shell_session_exports.zig`, and
  `src/android_bridge_exports/shell_selection_exports.zig`
- Android Zig bridge API names in `android_runtime_bridge.zig` now use concise
  session/selection terminology (`restartSession`, `pollSession`,
  `selectionRect*`, `selectionTextAlloc`, `rendererActive`) rather than
  long shell-prefixed helper names
- Android host/probe adapters now use event grammar (`on*`) instead of
  `note*` entrypoint names (`android_host.zig`,
  `android_gles_surface_status.zig`)
- terminal session helper filename now uses runtime/factory ownership naming:
  `src/app/terminal/terminal_session_runtime_factory.zig`
- Zig naming migration retired terms checkpoint:
  `note*` Android host/probe entrypoint names, `ProbeStatus/ProbeState`,
  `android_gles_probe` filename, `terminal_session_bootstrap` filename, and long `currentShell*` /
  `restartShellSession`-style bridge helper names
- selection controller remains monolithic by design until a real split seam
  exists
- queue remains Android-product-first, not shell-readiness-baseline-first

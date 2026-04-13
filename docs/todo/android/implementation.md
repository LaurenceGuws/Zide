# Android Terminal Queue

Active Android plan/todo/workflow. This is the only live queue document for
Android terminal work.

## Document Roles

- This file: active `focus`, `todo`, and `workflow`.
- `ANDROID_JAVA_HOST_STRUCTURE.md`: Java ownership and structure contract.
- `ANDROID_SHELL_BRINGUP_PLAN.md`: closed bring-up record and decisions.
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
- rewriting closed bring-up history as active tasks

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
  (current size: `725` lines; JNI moved out to `TerminalNativeBridge`)
- host callback seams are adapter-backed (`*HostCallbacks` /
  `*HostLifecycleCallbacks`) instead of activity-owned anonymous blocks
- assist modifier latch presentation now lives in chrome host wiring instead of
  the activity
- product runtime, chrome, surface, session, selection, and gesture assembly
  now terminate in `host/` controllers and `TerminalHostAssembler` helpers
- chrome bridge/callback construction now lives in
  `host/TerminalChromeHostFactory` to keep `TerminalHostAssembler` focused
- selection/gesture controller construction now lives in
  `host/TerminalInteractionHostFactory` to keep `TerminalHostAssembler`
  focused on shared/runtime/surface/session/input seams
- hardware-keyboard and IME-focus-recovery controller construction now lives in
  `TerminalHostAssembler` helpers instead of activity-local callback assembly
- terminal surface widget seam is established in
  `host/TerminalSurfaceWidgetController` for future tabbed hosting
- debug surface snapshot composition moved to
  `debug/TerminalSurfaceStateSnapshotReader`
- selection controller remains monolithic by design until a real split seam
  exists
- queue remains Android-product-first, not bring-up-first

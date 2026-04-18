# Android Refocus Case Study

Source: `refocus_android.txt`

This is architecture authority for the Android refocus campaign.

## Bigger Picture

Zide on Android is not "temporary glue". It is a first-class product surface.
To keep velocity without compounding debt, Java must cleanly split into two
subsystems:

1. `Android Harness`
2. `Terminal Widget`

The harness exists to own Android ceremony and app-shell behavior. The widget
exists to own terminal interaction/runtime behavior as a portable consumer.

## Target Shape

### Subsystem A: Android Harness

Why:

- Android UX must feel native and stable.

What it owns:

- activity/app lifecycle and platform ceremony
- app-shell layout/styling/theming propagation
- left slide-out navigation and view-level state ownership
- userland orchestration (`zide-pm` usage, readiness/install flows) with
  minimal ceremony

Hard boundary:

- harness does not own terminal widget policy internals

### Subsystem B: Terminal Widget

Why:

- terminal must remain portable and reusable across hosting shells/modes

What it owns:

- input/selection/gesture quirks for terminal UX
- GLES init/deinit and native handoff
- FFI lifecycle and user-input passthrough
- terminal runtime-facing state seams (tab/persistent session ready)

Hard boundary:

- widget does not own app-shell navigation/theming/userland orchestration

## Current State And Progress (High Level)

- two-subsystem direction is now explicit in queue and handoff authority
- debug view UI path has been deleted; diagnostics are log/script based
- dead debug-mode plumbing was removed from runtime/surface/session seams
- userland workflow callbacks are being reshaped to semantic harness actions
- **APX-B18 (2026-04-18):** refocus closure proof is complete on device. The
  current PM release stages with the app-owned `.z` bridge, shipped in-prefix
  `zide-pm` lists and installs `zide-android-catalog-smoke`, and the installed
  executable is verified under the staged prefix. Harness/widget split and
  tab-state milestones remain accepted; Android refocus is ready for formal
  closure and focus shift to Zig-layer hygiene work.

This case-study intentionally stays high-level. For implementation detail and
iteration-level decisions, read code and commit history.

## Refocus Risks

- callback contracts drift back to status-string choreography
- harness starts carrying widget policy "for convenience"
- widget starts assuming app-shell/userland ownership
- task logs regrow into noise and obscure active gates

## Milestone Narrative

Execution details and gate checklists live in:

- `docs/todo/android/implementation.md`

Campaign sequence:

1. `RF-M0` doc reset and archive
2. `RF-M1` harness boundary lock
3. `RF-M2` widget boundary lock
4. `RF-M3` userland mobility lock
5. `RF-M4` app-shell navigation/state backbone lock
6. `RF-M5` stabilization matrix and review gate

## Non-Negotiables

- no compatibility path kept only to make migration easier
- no reintroduction of debug-view UI paths
- no mixed ownership without explicit milestone scope
- each seam cut remains compileable and runtime-smoke validated

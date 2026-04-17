# Handoff

Session entrypoint only. Keep this file short and current.

## Active Focus

- Product lane: Android terminal excellence
- Campaign: **Android harness/widget portability hardening** (`AHW`) — turns the refocus vision into enforceable code shape: Android Harness is the platform/app-shell canvas, Terminal Widget is the portable terminal consumer, and userland stays movable for future IDE/editor modes.
- Completed macro batch (engineer): `AHW-B4` — terminal widget composition seam; **architect review pending** at super-gate (`docs/todo/android/implementation.md`).
- Prior closed/escalated: `AHW-B3` accepted; `AHW-B2` accepted; `AHW-B1` accepted; `ASF-M3` escalated remaining IME/assist and touch-gesture matrix rows to operator evidence; `ASF-M2`; `ASF-M1`; `AX-M5`; `AX-M4`
- Active queue authority: `docs/todo/android/implementation.md`
- Engineer entrypoint (dual mode): `docs/todo/android/ENGINEER_ENTRYPOINT.md`

## Dual Session Startup (Copy/Paste)

Architect session seed:

- Read `docs/todo/android/implementation.md` first.
- Confirm the macro batch marked `in_progress`.
- Review the Engineer's completed batch only when they report the super-gate or a hard blocker.
- After review acceptance, immediately refocus the queue, handoff, and engineer entrypoint to the next macro batch.

Engineer session seed:

- Read `docs/todo/android/ENGINEER_ENTRYPOINT.md`, then
  `docs/todo/android/implementation.md`, then this handoff file.
- After Architect accepts `AHW-B4`, read the queue for the next `in_progress` macro batch only.
- Engineer stops at `AHW-B4` super-gate until Architect refocuses the queue.

## First Read Order

1. `docs/todo/android/ENGINEER_ENTRYPOINT.md`
2. `docs/todo/android/implementation.md`
3. `app_architecture/platform/android/ANDROID_REFOCUS_CASE_STUDY.md`
4. `app_architecture/platform/android/ANDROID_JAVA_HOST_STRUCTURE.md`
5. `app_architecture/platform/android/ANDROID_JAVA_NAMING_CONTRACT.md`
6. `app_architecture/platform/android/USERLAND_HOST_CONTRACT.md`
7. `docs/todo/android/RF_M5_STABILIZATION_MATRIX.md` only if touching stabilization evidence or operator rows

## Execution Contract

- Follow only the active macro batch and `Queue line (exact)` entries from the Android queue.
- Keep cuts scoped and commit small validated checkpoints; this batch is architect-approved for autonomous engineer commits after local validation.
- Compile every code cut; run deploy + `AndroidRuntime:E` smoke at seam boundaries.
- Compile gate is strict: `:app:compileDebugJavaWithJavac` and
  `:app:compileReleaseJavaWithJavac` both must stay green under warnings-as-errors.
- Update docs in the same wave.
- Architect updates use: `Blocked by humain review needed: true|false`.
- Engineer updates use: `Blocked by Archtect review needed: true|false`.

## AHW-B4 Review Findings From AHW-B3

- `AHW-B3` is accepted: status telemetry now lives under status ownership and the current terminal widget instance is explicit.
- `ProductHostStartupBundle` remains accepted as startup-order aggregation; do not collapse it without a concrete owner win.
- `WidgetAssembly.Result` should not be stretched into a terminal-instance factory by itself. The next seam should be a harness-owned composition layer that can assemble interaction + widget pieces and return a `TerminalWidgetInstance` without making `ZideActivity` do that composition.
- Do not implement tabs. Build the composition seam that would make tabs possible later.

## Operator Evidence Escalation

ASF did not prove IME/assist or touch gestures because no operator packets were delivered. Those rows remain parked in `docs/todo/android/RF_M5_STABILIZATION_MATRIX.md` with owner `operator`; they do not block `AHW-B4` unless new evidence reports a regression inside the active code scope.

## Historical Notes

Pre-refocus Android task logs were archived to:

- `docs/review/ANDROID_LANE_HISTORY_2026-04-17.md`

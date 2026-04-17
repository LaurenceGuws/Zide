# Handoff

Session entrypoint only. Keep this file short and current.

## Active Focus

- Product lane: Android terminal excellence
- Campaign: **Android harness/widget portability hardening** (`AHW`) — turns the refocus vision into enforceable code shape: Android Harness is the platform/app-shell canvas, Terminal Widget is the portable terminal consumer, and userland stays movable for future IDE/editor modes.
- Active macro batch: `AHW-B6` — slot-scoped host API foundation with single-slot behavior preserved.
- Prior closed/escalated: `AHW-B5` accepted; `AHW-B4` accepted; `AHW-B3` accepted; `AHW-B2` accepted; `AHW-B1` accepted; `ASF-M3` escalated remaining IME/assist and touch-gesture matrix rows to operator evidence; `ASF-M2`; `ASF-M1`; `AX-M5`; `AX-M4`
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
- Execute only the macro batch marked `in_progress`: `AHW-B6`.
- Stop at the `AHW-B6` super-gate and report the review packet.

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

## AHW-B6 review findings from AHW-B5

- `AHW-B5` is accepted.
- `TerminalWidgetCompositionAssembly.compose` returning `TerminalWidgetInstance` only is the correct ownership shape.
- Reading shell/chrome/view-mode from `WidgetAssembly.Result` in `ZideActivity` next to `compose` is acceptable and should remain unless a cleaner owner seam appears.
- Duplicate `ActivityViewBindings.from(...)` lookup in startup flow is non-blocking but should be removed in this batch.
- This batch should make slot identity compile-visible in host APIs without implementing tabs or multi-instance product behavior.

## Operator Evidence Escalation

ASF did not prove IME/assist or touch gestures because no operator packets were delivered. Those rows remain parked in `docs/todo/android/RF_M5_STABILIZATION_MATRIX.md` with owner `operator`; they do not block `AHW-B6` unless new evidence reports a regression inside the active code scope.

## Historical Notes

Pre-refocus Android task logs were archived to:

- `docs/review/ANDROID_LANE_HISTORY_2026-04-17.md`

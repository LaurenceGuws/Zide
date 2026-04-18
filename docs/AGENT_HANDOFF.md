# Handoff

Session entrypoint only. Keep this file short and current.

## Active Focus

- Product lane: Android terminal excellence
- Campaign: **Android harness/widget portability hardening** (`AHW`) — turns the refocus vision into enforceable code shape: Android Harness is the platform/app-shell canvas, Terminal Widget is the portable terminal consumer, and userland stays movable for future IDE/editor modes.
- Engineer-complete macro batch (Architect verdict pending): `AHW-B13` — app-shell sidebar mutation policy narrowing, behavior-neutral.
- Prior closed/escalated: `AHW-B12` accepted; `AHW-B11` accepted; `AHW-B10` accepted; `AHW-B9` accepted; `AHW-B8` accepted; `AHW-B7` accepted; `AHW-B6` accepted; `AHW-B5` accepted; `AHW-B4` accepted; `AHW-B3` accepted; `AHW-B2` accepted; `AHW-B1` accepted; `ASF-M3` escalated remaining IME/assist and touch-gesture matrix rows to operator evidence; `ASF-M2`; `ASF-M1`; `AX-M5`; `AX-M4`
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
- If a macro batch is `in_progress`, execute only that batch. `AHW-B13` engineer
  work is complete; next engineer session starts from Architect refocus.
- Architect: review the `AHW-B13` super-gate packet in `docs/todo/android/implementation.md` and refocus the queue.

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
- Treat Android lane ownership as single-path in-repo code only: no external fork compatibility framing.
- Architect updates use: `Blocked by humain review needed: true|false`.
- Engineer updates use: `Blocked by Archtect review needed: true|false`.

## AHW-B13 baseline from AHW-B12 review

- `AHW-B12` is accepted.
- Keep no public arbitrary shell-view setter until multi-view policy is explicitly scoped.
- Keep null-reject semantics as the harness boundary for shell-view ids.
- Keep `AppShellNavigation.forProductTerminalSlot` / `applyProductTerminalShellViewActive` split as app-shell contract baseline.
- Keep `ProductTerminalSlotShellMapping` as canonical host/ui slot→shell-view seam.
- Keep `checkActiveProductTerminalSlot` as active-slot choke point until second-slot policy is explicitly scoped.
- Keep chrome slot-agnostic unless per-slot chrome behavior is explicitly opened as a scoped batch.

## Operator Evidence Escalation

ASF did not prove IME/assist or touch gestures because no operator packets were delivered. Those rows remain parked in `docs/todo/android/RF_M5_STABILIZATION_MATRIX.md` with owner `operator`; they do not block `AHW-B13` unless new evidence reports a regression inside the active code scope.

## Historical Notes

Pre-refocus Android task logs were archived to:

- `docs/review/ANDROID_LANE_HISTORY_2026-04-17.md`

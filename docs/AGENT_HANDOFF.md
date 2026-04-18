# Handoff

Session entrypoint only. Keep this file short and current.

## Active Focus

- Product lane: Android terminal excellence
- Campaign: **Android harness/widget portability hardening** (`AHW`) — turns the refocus vision into enforceable code shape: Android Harness is the platform/app-shell canvas, Terminal Widget is the portable terminal consumer, and userland stays movable for future IDE/editor modes.
- Active macro batch (`awaiting_architect_review`): `AHW-B24` — app-shell terminal-view activation centralized on `AppShellTerminalViewPolicy` (single-terminal behavior preserved); engineer stopped at super-gate for architect verdict.
- Prior closed/escalated: `AHW-B1` through `AHW-B23` accepted; `ASF-M3` escalated IME/assist/touch rows to operator evidence; `RF-M0` through `RF-M5` and `AX-M1` through `AX-M5` completed.
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
- Execute only the macro batch marked `in_progress` in
  `docs/todo/android/implementation.md` (`AHW-B24`).
- Stop at the `AHW-B24` super-gate and return the review packet for Architect verdict.

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

## AHW-B24 Baseline

- `AHW-B20` is accepted and already keeps the test device awake by default.
- Additional keep-screen-on seam work is frozen by product direction.
- `AHW-B21` is accepted: harness vs surface split (`harnessHost` + `surfaceJoin`) is now the baseline.
- `AHW-B22` is accepted: startup callback assembly moved into named host/ui owners without behavior change.
- `AHW-B23` is accepted: onCreate startup choreography is owned by `ProductHostOnCreateStartupCoordinator` + `ProductHostOnCreateStartupSteps`.
- `AHW-B24` scope is non keep-screen-on: explicit app-shell terminal-view activation policy is owned by `AppShellTerminalViewPolicy` (wraps `AppShellNavigation`); future tab shell policy extends that owner without tab UI in this batch.
- Keep `ProductHostKeepScreenOnPolicy` as the long-term owner of terminal keep-screen-on default policy.
- Keep `HostImeStateAccess` as the long-term host callback IME seam (backed by `ProductHostImeState`).
- Keep `ProductHostImeState` as the long-term activity IME carrier.
- Keep `SurfaceWidgetHostImeVisibility` and required `chromeImePolicyInput()` on WidgetAssembly.Host as long-term widget-host IME seams.
- Keep `ChromeImePolicyInput` as the long-term chrome assembly input seam.
- Keep `chromeImeVisibility*` + `applyChromeImeVisibility*` naming as the long-term chrome host seam.
- Keep chrome drawer sidebar policy naming (`chromeDrawerSidebar*` + `apply*`) as the long-term seam.
- Keep no public arbitrary shell-view setter until multi-view policy is explicitly scoped.
- Keep null-reject semantics as the harness boundary for shell-view ids.
- Keep `AppShellNavigation.forProductTerminalSlot` / `applyProductTerminalShellViewActive` as navigation truth; harness terminal-view activation goes through `AppShellTerminalViewPolicy.applyActiveProductTerminalShellView` (delegates to `applyProductTerminalShellViewActive`).
- Keep `ProductTerminalSlotShellMapping` as canonical host/ui slot→shell-view seam.
- Keep `checkActiveProductTerminalSlot` as active-slot choke point until second-slot policy is explicitly scoped.
- Keep chrome slot-agnostic unless per-slot chrome behavior is explicitly opened as a scoped batch.

## Operator Evidence Escalation

ASF did not prove IME/assist or touch gestures because no operator packets were delivered. Those rows remain parked in `docs/todo/android/RF_M5_STABILIZATION_MATRIX.md` with owner `operator`; they do not block `AHW-B24` unless new evidence reports a regression inside the active code scope.

## Historical Notes

Pre-refocus Android task logs were archived to:

- `docs/review/ANDROID_LANE_HISTORY_2026-04-17.md`

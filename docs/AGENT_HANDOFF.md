# Handoff

Session entrypoint only. Keep this file short and current.

## Active Focus

- Product lane: Android terminal excellence
- Campaign: **Android product expansion** (`APX`) — build product capability on top of the closed harness/widget ownership shape.
- Active macro batch (`in_progress`): `APX-B9` — tab-state expansion slice 2 + zide-pm test-binary pull maturity; feature-first long engineer batch.
- Parallel foundation lane (separate repo): `../zide-mobile-pm` may run in parallel for Android test-binary pull/install contract groundwork; Android APX remains primary until APX objectives are stable.
- Prior closed/escalated: `AHW-B1` through `AHW-B26` accepted and `AHW` closed; `ASF-M3` escalated IME/assist/touch rows to operator evidence; `RF-M0` through `RF-M5` and `AX-M1` through `AX-M5` completed.
- Active queue authority: `docs/todo/android/implementation.md`
- Engineer entrypoint (dual mode): `docs/todo/android/ENGINEER_ENTRYPOINT.md`

## Dual Session Startup (Copy/Paste)

Architect session seed:

- Read `docs/todo/android/implementation.md` first.
- Confirm the macro batch marked `in_progress`.
- Review the Engineer's completed batch only when they report the super-gate or a hard blocker.
- Expect longer engineer runs: default target is **5–10 validated commits** per
  macro batch before architect review.
- After review acceptance, immediately refocus the queue, handoff, and engineer entrypoint to the next macro batch.
- If parallel `zide-mobile-pm` work is active, keep it contract-aligned with APX and treat conflicts as architect blockers.

Engineer session seed:

- Read `docs/todo/android/ENGINEER_ENTRYPOINT.md`, then
  `docs/todo/android/implementation.md`, then this handoff file.
- When a batch is `in_progress`, execute only that macro batch in
  `docs/todo/android/implementation.md`. When the active batch is `architect_review_pending`,
  stop engineering work and return the review packet for Architect verdict.

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
- Engineer batching target: **5–10 commits per macro batch** before super-gate,
  unless a real hard stop condition is hit.
- Compile every code cut; run deploy + `AndroidRuntime:E` smoke at seam boundaries.
- Compile gate is strict: `:app:compileDebugJavaWithJavac` and
  `:app:compileReleaseJavaWithJavac` both must stay green under warnings-as-errors.
- Update docs in the same wave.
- Treat Android lane ownership as single-path in-repo code only: no external fork compatibility framing.
- Architect updates use: `Blocked by humain review needed: true|false`.
- Engineer updates use: `Blocked by Archtect review needed: true|false`.

## APX-B9 Baseline

- `AHW-B20` is accepted and already keeps the test device awake by default.
- Additional keep-screen-on seam work is frozen by product direction.
- `AHW-B21` is accepted: harness vs surface split (`harnessHost` + `surfaceJoin`) is now the baseline.
- `AHW-B22` is accepted: startup callback assembly moved into named host/ui owners without behavior change.
- `AHW-B23` is accepted: onCreate startup choreography is owned by `ProductHostOnCreateStartupCoordinator` + `ProductHostOnCreateStartupSteps`.
- `AHW-B24` is accepted: explicit app-shell terminal-view activation policy is owned by `AppShellTerminalViewPolicy` (wraps `AppShellNavigation`).
- `AHW-B25` is accepted: `AppShellTerminalViewPolicy` owns drawer sidebar policy forwarding and terminal-view activation; consumers do not take raw `AppShellNavigation` through the policy surface.
- `AHW-B26` is accepted: landing-gate audit passed and AHW is closed.
- `APX-B1` is accepted: selection (`AppShellTerminalSelectionPolicy`) and activation (`AppShellTerminalViewPolicy`) are split, and default single-terminal behavior is preserved.
- `APX-B2` is accepted: `DeclaredTerminalWidgetSlotCatalog` holds PRIMARY-only declared slots; `AppShellTerminalSelectionPolicy` enforces catalog + active-slot checks; no multi-slot runtime.
- `APX-B3` is accepted: one `AppShellTerminalHostSelectionContext` per startup is the selected seam; host/context slot equality stays fail-fast.
- `APX-B4` is accepted: explicit `ProductHostDeclaredTerminalWidgetSlot` source now feeds `AppShellTerminalHostSelectionContext.forProductHostStartup`.
- `APX-B5` is accepted: immutable `ProductHostDeclaredTerminalWidgetSlot` value type now owns declared-slot source semantics at startup boundary.
- `APX-B6` is accepted: declared-slot value is propagated across interaction/widget/composition startup seams.
- `APX-B7` is accepted: enum conversion is centralized at `terminalWidgetSlotForProductHarness()` with Host adapter enum boundaries preserved.
- `APX-B8` is accepted: tab-state slice 1 (two-tab chrome strip and harness tab index state) and `ZIDE_PM_HOST_PLATFORM=android` export are in place.
- `APX-B9` scope is feature-first: move from chrome-only selection to behavior-bearing tab-session flow and mature Android-side zide-pm test-binary pull/install path.
- Cleanup-only changes are out of scope unless they directly unblock APX-B9 feature delivery.
- APX remains primary until these are stable: harness/widget split stability, clean tab-state expansion, and zide-pm real Android test-binary pull maturity.
- After those three are stable, primary architect focus transitions to Zig-layer hygiene cleanup.
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

ASF did not prove IME/assist or touch gestures because no operator packets were delivered. Those rows remain parked in `docs/todo/android/RF_M5_STABILIZATION_MATRIX.md` with owner `operator`; they do not block `APX-B9` unless new evidence reports a regression inside the active code scope.

## Historical Notes

Pre-refocus Android task logs were archived to:

- `docs/review/ANDROID_LANE_HISTORY_2026-04-17.md`

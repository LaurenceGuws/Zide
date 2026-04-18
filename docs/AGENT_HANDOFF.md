# Handoff

Session entrypoint only. Keep this file short and current.

## Active Focus

- Product lane: Android terminal excellence
- Campaign: **Android product expansion** (`APX`) — build product capability on top of the closed harness/widget ownership shape.
- Active macro batch (`blocked_cross_repo`): `APX-B18` — **hard stop**: current released dev prefix + on-device `zide-pm list-available` (`ZIDE_PM_HOST_PLATFORM=android`) show **no** `zide-android-*` catalog row (only `dev-baseline` observed). Unblock requires `../zide-mobile-pm` to ship Android-mode catalog ids; this repo documents the blocker in `docs/todo/android/implementation.md` (APX-B18 hard blocker packet).
- Parallel foundation lane (separate repo): `../zide-mobile-pm` must publish `zide-android-*` list-available rows before APX-B18 M2+ can resume; Android lane stays doc-synced until then.
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
- Human-readable progress labels are required in every architect/engineer update (`LABELS` block).
- Architect updates use: `Blocked by humain review needed: true|false`.
- Engineer updates use: `Blocked by Archtect review needed: true|false`.

## APX-B18 Baseline

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
- `APX-B8` is accepted: tab-state slice 1 (two-tab session selection + harness tab index state; sidebar placement finalized in APX-B11) and `ZIDE_PM_HOST_PLATFORM=android` export are in place.
- `APX-B9` is accepted: distinct tab selection now restarts native shell + userland refresh; Packages flow proves Android-side `zide-pm install` path.
- `APX-B10` is accepted: doctor is read-only and install mutation is explicit lifecycle-owned (`UserlandAndroidTestBinaryInstallLifecycle`) with dedicated sidebar trigger.
- `APX-B11` is accepted: terminal session/tab controls are now AppShell sidebar navigation; assist row stays input-only; APX-B10 doctor/install split unchanged.
- `APX-B12` is reviewed with changes requested: addressed by `APX-B13` (edge install no longer lexicographs non-`zide-android-*` rows).
- `APX-B13` is accepted: edge install candidates match `zide-android-*`; explicit `packages.edge_install.selected` and reasoned no-candidate (`empty_catalog` / `no_android_edge`) are in place.
- `APX-B14` is accepted: tab index is saved/restored through `ZideActivity` and seeded into `AppShellNavigation` on recreate with no synthetic selection restart side effects.
- `APX-B15` is accepted: `AppShellTerminalViewPolicy` exposes `productTerminalTabDescriptors`; `WidgetAssembly` builds defaults via `ProductTerminalTabDescriptors`; chrome binds sidebar tabs from policy; APX-B14 index restore and APX-B9 user-select restart semantics preserved.
- `APX-B16` is accepted: `ZideActivity` saves `selectedProductTerminalTabStableId`; restore resolves via default descriptor list then seeds navigation; legacy raw-index bundle key is still read for migration; APX-B14 seed path and APX-B9 distinct-user-select restart unchanged.
- `APX-B17` is accepted: readiness stamp records `runtime_support_links`; `UserlandRuntimeSupportLinks` applies install fragment and re-applies from stamp before first native session restart; `zide.embed` sibling paths are allowed; APX-B16 tab persistence and APX-B10/B11/B13 flows unchanged.
- `APX-B18` is the Android refocus closure proof: real released zide-pm Android test-binary candidate selection/install/verification on device, then closure recommendation.
- Cleanup-only changes are out of scope unless they directly unblock APX-B18 evidence.
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

ASF did not prove IME/assist or touch gestures because no operator packets were delivered. Those rows remain parked in `docs/todo/android/RF_M5_STABILIZATION_MATRIX.md` with owner `operator`; they do not block `APX-B18` unless new evidence reports a regression inside the active code scope.

## Historical Notes

Pre-refocus Android task logs were archived to:

- `docs/review/ANDROID_LANE_HISTORY_2026-04-17.md`

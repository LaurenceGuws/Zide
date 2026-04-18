# Android Refocus Queue

Active Android execution queue. This file is intentionally lean.

## Mission

Stabilize Android around two clean Java subsystems:

1. `Android Harness`
2. `Terminal Widget`

Goal: keep Android first-class while keeping widget/runtime ownership portable
and decoupled.

## Authority Set

- Strategy + rationale + target architecture:
  `app_architecture/platform/android/ANDROID_REFOCUS_CASE_STUDY.md`
- Java ownership contract:
  `app_architecture/platform/android/ANDROID_JAVA_HOST_STRUCTURE.md`
- Java naming contract:
  `app_architecture/platform/android/ANDROID_JAVA_NAMING_CONTRACT.md`
- Historical archive (not active queue):
  `docs/review/ANDROID_LANE_HISTORY_2026-04-17.md`

## Current State (High Level)

- Two-subsystem direction is locked in docs and code.
- Debug view UI path is removed; diagnostics are log/script based.
- Dead debug-mode coupling has been removed from major runtime/surface/session
  seams.
- Userland workflow callback shape is being converted to semantic harness
  actions.
- Refocus campaign milestones `RF-M0` through `RF-M5` are complete.
- AX hardening milestones `AX-M1` through `AX-M4` and declaration `AX-M5` are
  complete.
- **Escalated campaign:** **Android stabilization follow-through** (`ASF`) —
  IME/assist and touch-gesture rows are parked on operator evidence in
  `RF_M5_STABILIZATION_MATRIX.md`; they no longer block engineering work unless
  new evidence reports a regression inside the active scope.
- **Active campaign:** **Android product expansion** (`APX`) — ship product-facing
  capability on the closed `AHW` harness/widget shape (see Post-AHW Campaign below).
- **Prior closed campaign:** **Android harness/widget portability hardening** (`AHW`) —
  ownership boundaries are enforced; formal closure via `AHW-B26`.
- **APX completion objectives (feature-first):**
  1. planned harness/widget split implemented and stable
  2. planned tab-state expansion implemented cleanly on Android
  3. zide-pm mature enough to pull real Android test binaries beyond `nvim`/`htop`

Iteration detail is intentionally not tracked here. Read code + git history for
step-level implementation history.

## Workflow Contract

- One scoped cut at a time.
- Compile every cut.
- Run deploy + `AndroidRuntime:E` smoke at seam boundaries.
- Keep docs updated in the same wave.
- Delete obsolete path as soon as replacement is validated.

Required progress fields:

- `Milestone: <id> <status>`
- `Queue line (exact): <line from this file>`
- `Scope contract: <one-line scope confirmation>`
- `Progress delta: <outcome-focused>`
- `Validation: <exact commands + pass/fail>`
- Architect updates: `Blocked by humain review needed: true|false`
- Engineer updates: `Blocked by Archtect review needed: true|false`

Milestone boundary line:

`Milestone reached per docs, architect review required.`

New dual-session handover contract:

- After each accepted gate, Architect must immediately set the next active milestone here.
- Engineer session start prompt must reference only:
  - `docs/todo/android/implementation.md`
  - `docs/AGENT_HANDOFF.md`
  - `docs/todo/android/ENGINEER_ENTRYPOINT.md`
- No milestone or macro batch is considered active unless it is marked
  `in_progress` in this file.
- Macro batches are allowed to contain multiple internal milestones. In that
  case the batch, not each internal milestone, is the architect review boundary.
- Engineer-side iteration length target per macro batch: **5–10 validated commits**
  before super-gate review, unless a real hard stop is hit.
- Architect should avoid re-gating every 1–2 commits when the active batch still
  has clear in-scope runway.

Validation commands:

- `./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac`
- `./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac`
- `python3 ops/android_terminal_host.py deploy`
- `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E`

## Milestone Plan (Sequential, Gated)

Dual-mode batching override (architect directive):

- Use macro review chunks instead of per-milestone pauses.
- `RF-M0` through `RF-M5` completed; refocus baseline is locked.
- `AX-M1` through `AX-M5` completed.
- `ASF-M3` escalated stabilization follow-through to operator evidence.
- `AHW-B1` through `AHW-B26` accepted by architect.
- Keep-screen-on seam work beyond `AHW-B20` is frozen by product direction.
- `APX-B1` accepted by architect.
- `APX-B2` accepted by architect.
- `APX-B3` accepted by architect.
- `APX-B4` accepted by architect.
- `APX-B5` accepted by architect.
- `APX-B6` accepted by architect.
- `APX-B7` accepted by architect.
- `APX-B8` is `in_progress`.

## Campaign Landing Gate (Refocus Shape)

`AHW` is considered landed only when all of these are true in code and docs:

- Android Harness is the platform/app-shell/userland canvas and does not own terminal widget internals.
- Terminal Widget is a portable harness consumer and does not own app-shell navigation/theming/userland orchestration.
- Userland remains movable for future IDE/editor modes and stays free of widget/surface/controller ownership.
- `ZideActivity` is an entrypoint/wiring edge, not the hidden product backbone.
- Remaining Android work is product expansion (for example tabs/view policy), not ownership rescue.

When this gate is met, architect closes `AHW` and opens the next campaign as product expansion, not further seam cleanup.

## Historical Flattening

The active queue intentionally stays lean. Detailed milestone-by-milestone history is flattened out of this iteration loop:

- Historical source vision: `refocus_android.txt`
- Campaign authority: `app_architecture/platform/android/ANDROID_REFOCUS_CASE_STUDY.md`
- Historical archive: `docs/review/ANDROID_LANE_HISTORY_2026-04-17.md`
- Execution history beyond active batches: use `git log` and prior accepted batch commits

Completed campaign summary:

- Refocus campaign (`RF-M0` to `RF-M5`) completed.
- AX hardening campaign (`AX-M1` to `AX-M5`) completed.
- ASF stabilization follow-through escalated to operator evidence (`ASF-M3`).
- AHW macro batches `AHW-B1` through `AHW-B26` accepted by architect.
- Keep-screen-on follow-up beyond `AHW-B20` frozen by product direction.

Last accepted architect gate:

- `Review chunk: AHW-B26`
- `Verdict: accepted`
- `Commits reviewed: 8ef4a4a1`
- `Architect validation: compileDebug/compileRelease/deploy/cold-start/AndroidRuntime:E (pass)`

`Milestone reached per docs, architect review required.`

---

### `AHW-B23` Refocus-Shape Landing Prep: OnCreate Sequence Ownership (`completed`)

Batch queue line (exact):

- reduce ZideActivity startup-sequence method pressure by extracting a named onCreate startup coordinator while preserving behavior and startup order

Batch purpose:

- move startup sequence choreography off activity-local method blocks so harness ownership is explicit
- keep the `refocus_android.txt` shape visible in code: harness canvas, portable widget consumer, movable userland
- prepare final closure against the campaign landing gate above

Batch scope:

- Java Android terminal host only, plus authority docs needed to keep contract truth current
- primary code root:
  `android/terminal-host/app/src/main/java/uk/laurencegouws/terminal/**`
- allowed docs:
  `docs/todo/android/implementation.md`,
  `docs/todo/android/ENGINEER_ENTRYPOINT.md`,
  `docs/AGENT_HANDOFF.md`,
  `app_architecture/platform/android/ANDROID_JAVA_HOST_STRUCTURE.md`,
  `app_architecture/platform/android/ANDROID_JAVA_NAMING_CONTRACT.md`,
  `app_architecture/platform/android/USERLAND_HOST_CONTRACT.md`

Batch non-goals:

- no terminal tabs UI/product behavior
- no tab persistence/session switching
- no terminal-core or shared-renderer changes
- no app-shell UI redesign
- no keep-screen-on follow-up implementation unless explicitly re-opened
- no debug-view UI resurrection
- no broad rename sweep
- no ASF operator-evidence churn unless new evidence arrives

Batch super-gate:

- `ZideActivity` delegates onCreate startup sequence orchestration to a named host/ui coordinator
- startup order is unchanged:
  `initializeStatusAndViewControllers -> InteractionAssembly.assemble -> assembleUserlandWorkflowControllers -> assembleSessionControllers -> applyTerminalWidgetComposition -> assembleRuntimeController -> assembleActivityLifecycleController -> loadInitialReadinessState -> installInputControllers -> bindAndStartUiControllers -> terminalActivityLifecycleController.onCreate`
- no behavior change and no seam ownership regression
- B14-B22 IME/slot/chrome/widget/startup-wiring contracts remain unchanged
- docs reflect final ownership/naming shape
- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass at final seam boundary

Internal milestone cadence:

- Engineer executes `AHW23-M1` through `AHW23-M6` sequentially.
- Do not stop for architect review between internal milestones.
- Mark each internal milestone complete in this file as it lands.
- Stop only if the hard stop conditions in `ENGINEER_ENTRYPOINT.md` are hit or
  the `AHW-B23` super-gate is reached.

### `AHW23-M1` OnCreate sequence pressure audit (`complete`)

Queue line (exact):

- audit runOnCreateStartupSequence dependencies and define coordinator extraction boundaries

Acceptance:

- enumerate which step calls are pure sequence choreography vs ownership-bearing logic
- define coordinator inputs/outputs and state handoff boundaries
- record invariants with explicit ordered call list and out-of-scope seams

**M1 audit (authoritative for B23 extraction):**

- **Pure sequence choreography (moves to coordinator):** the fixed call order and passing `InteractionAssembly.Result` from `assembleInteraction` into `applyTerminalWidgetComposition` only. No new branches, no reordering, no widening of activity fields.
- **Ownership-bearing logic (stays on `ZideActivity` private methods / existing hosts):** `initializeStatusAndViewControllers`, `assembleUserlandWorkflowControllers`, `assembleSessionControllers`, `applyTerminalWidgetComposition`, `assembleRuntimeController`, `assembleActivityLifecycleController`, `loadInitialReadinessState`, `installInputControllers`, `bindAndStartUiControllers`, and `terminalActivityLifecycleController.onCreate()` — each remains the same body as before; only the *caller* of the ordered list changes to `ProductHostOnCreateStartupCoordinator`.
- **Coordinator inputs/outputs:** input is a `ProductHostOnCreateStartupSteps` implementation (typed step surface: harness-owned assembly phases wired from the activity). Output is side effects only (field assignments on the activity and controller `onCreate`), identical to the pre-extraction call chain.
- **State handoff boundaries:** `InteractionAssembly.Result` flows `assembleInteraction` → `applyTerminalWidgetComposition` inside the coordinator’s single ordered block (same as today). `ProductHostStartupBundle`, `ProductHostActivityStartupWiring`, `ProductTerminalWidgetAssemblyHost`, `ProductTerminalLifecycleHost`, IME/slot/chrome seams unchanged.
- **Invariants (ordered call list, frozen):** `initializeStatusAndViewControllers` → `InteractionAssembly.assemble` (exposed as `assembleInteraction` on the step interface) → `assembleUserlandWorkflowControllers` → `assembleSessionControllers` → `applyTerminalWidgetComposition` → `assembleRuntimeController` → `assembleActivityLifecycleController` → `loadInitialReadinessState` → `installInputControllers` → `bindAndStartUiControllers` → `terminalActivityLifecycleController.onCreate()`.
- **Out of scope for this batch:** keep-screen-on (`applyDefaultTerminalKeepScreenOnPolicy` stays directly under `onCreate` before the coordinator, as today), post-`onCreate` lifecycle overrides, terminal tabs/multi-instance product behavior, any change to B14–B22 callback or assembly contracts.

### `AHW23-M2` Coordinator seam introduction (`complete`)

Queue line (exact):

- introduce a named host/ui startup coordinator seam for onCreate sequence execution

Acceptance:

- add coordinator type(s) with explicit ownership naming under `host/ui`
- represent required mutable state via typed inputs rather than widening activity globals
- compile debug + release Java after code changes

### `AHW23-M3` Activity delegation rewiring (`complete`)

Queue line (exact):

- delegate runOnCreate startup sequence from ZideActivity to the extracted coordinator without order changes

Acceptance:

- activity no longer owns step-order choreography details
- startup order and side-effect timing remain unchanged
- compile debug + release Java after code changes

### `AHW23-M4` Contract docs lock (`complete`)

Queue line (exact):

- lock authority docs to coordinator-owned onCreate sequence orchestration shape

Acceptance:

- host structure and naming contract match code shape
- userland contract remains unchanged unless ownership text requires update

### `AHW23-M5` Queue/handoff/entrypoint sync (`complete`)

Queue line (exact):

- keep queue, handoff, and engineer entrypoint aligned to AHW-B23 execution and super-gate stop

Acceptance:

- queue, handoff, and engineer entrypoint stay coherent through B23 super-gate
- super-gate stop condition and review packet contract are explicit

### `AHW23-M6` Batch validation + review packet (`complete`)

Queue line (exact):

- validate AHW-B23 end-to-end and publish the architect review packet

Acceptance:

- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass, or exact device-blocker output is recorded
- cold start smoke pass when a device is available
- engineer reports the full super-gate packet and stops for Architect review

**AHW-B23 engineer validation record (M6):**

- `./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac` — pass
- `./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac` — pass
- `python3 ops/android_terminal_host.py deploy` — pass (streamed install, activity start)
- `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E` — pass (no `AndroidRuntime:E` lines; benign duplicate-top warning when activity already foreground)
- `adb shell am force-stop uk.laurencegouws.zide && adb shell am start -W -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity` — pass (`LaunchState: COLD`, `Status: ok`)

`Milestone reached per docs, architect review required.`

Architect review verdict:

- `Review chunk: AHW-B23`
- `Verdict: accepted`
- `Commits reviewed: 14861cbd, 366d05e3, b0d8fb5d`
- `Architect validation spot-check: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass)`
- `Architect runtime validation spot-check: python3 ops/android_terminal_host.py deploy (pass); adb cold start (pass, LaunchState: COLD); adb logcat -d -s AndroidRuntime:E (pass, empty)`
- `Engineer device validation accepted: deploy + AndroidRuntime:E smoke + cold start pass`
- `Review answers: extraction accepted as behavior-preserving and ownership-improving. Keep onTerminalLifecycleControllerCreate naming for now to preserve explicit terminal-host lifecycle boundary; consider naming-only alignment later only if clarity gains are concrete.`
- `Findings carried forward: no blocking regressions. Campaign is now clear to shift from ownership rescue into app-shell terminal-view policy expansion seams.`

---

### `AHW-B24` App-shell Terminal-View Policy Foundation (`completed`)

Batch queue line (exact):

- establish explicit app-shell terminal-view policy seams for future tabs while preserving single-terminal product behavior

Batch purpose:

- centralize terminal-view activation policy behind explicit app-shell owner seams
- preserve the refocus shape: harness is canvas, widget is portable consumer, userland remains movable
- prepare expansion groundwork without adding tab UI/product behavior

Batch scope:

- Java Android terminal host only, plus authority docs needed to keep contract truth current
- primary code root:
  `android/terminal-host/app/src/main/java/uk/laurencegouws/terminal/**`
- allowed docs:
  `docs/todo/android/implementation.md`,
  `docs/todo/android/ENGINEER_ENTRYPOINT.md`,
  `docs/AGENT_HANDOFF.md`,
  `app_architecture/platform/android/ANDROID_JAVA_HOST_STRUCTURE.md`,
  `app_architecture/platform/android/ANDROID_JAVA_NAMING_CONTRACT.md`,
  `app_architecture/platform/android/USERLAND_HOST_CONTRACT.md`

Batch non-goals:

- no terminal tabs UI/product behavior
- no tab persistence/session switching
- no terminal-core or shared-renderer changes
- no app-shell UI redesign
- no keep-screen-on follow-up implementation unless explicitly re-opened
- no debug-view UI resurrection
- no broad rename sweep
- no ASF operator-evidence churn unless new evidence arrives

Batch super-gate:

- terminal-view activation policy is explicit and centralized on app-shell seam owner(s)
- single-terminal runtime behavior remains unchanged
- no seam ownership regression against B14-B23 contracts
- docs reflect final ownership/naming shape
- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass at final seam boundary

Internal milestone cadence:

- Engineer executes `AHW24-M1` through `AHW24-M6` sequentially.
- Do not stop for architect review between internal milestones.
- Mark each internal milestone complete in this file as it lands.
- Stop only if the hard stop conditions in `ENGINEER_ENTRYPOINT.md` are hit or
  the `AHW-B24` super-gate is reached.

### `AHW24-M1` Terminal-view policy seam audit (`complete`)

Queue line (exact):

- audit app-shell terminal-view activation callsites and define explicit policy seam boundaries

Acceptance:

- enumerate current terminal-view activation mutation entry points
- define policy owner vs adapter-only surfaces
- record invariants and out-of-scope seams

**M1 audit (authoritative for B24):**

- **Activation mutation entry points:** (1) `AppShellNavigation` private constructor seeds `activeShellView` via `replaceActiveShellView(productTerminalShellViewId)` after `forProductTerminalSlot` → `ProductTerminalSlotShellMapping.shellViewIdForTerminalSlot`. (2) Steady-state re-assert: `ViewModeController.applyCurrentViewMode` (only callsite of terminal shell view activation besides ctor seeding) must invoke the product-terminal active view without re-running slot mapping.
- **Policy owner vs adapter-only:** `AppShellNavigation` remains the owner of active `ShellViewId`, drawer sidebar flags, and `applyProductTerminalShellViewActive`. Chrome/input bridges are adapter-only over that navigation state. **New:** `AppShellTerminalViewPolicy` is the explicit harness **terminal-view activation policy** seam (delegates to `applyProductTerminalShellViewActive`); view-mode and `WidgetHarnessHostControllers` use it so future tab/shell policy extends one type.
- **Invariants:** slot→`ShellViewId` resolution still exactly once per `AppShellNavigation.forProductTerminalSlot` in `WidgetAssembly.assemble`; chrome is wired through `AppShellTerminalViewPolicy` (B25 removed public `appShellNavigation()` on policy). No new `ShellViewId` literals outside `ProductTerminalSlotShellMapping` for product routing.
- **Out of scope:** tab UI, multi-instance product behavior, slot on `InteractionAssembly.Result`, per-slot chrome threading, keep-screen-on, startup order, B14–B23 IME/widget contracts.

### `AHW24-M2` Policy seam introduction (`complete`)

Queue line (exact):

- introduce explicit app-shell terminal-view policy seam(s) with ownership-first naming

Acceptance:

- add/refine policy owner type(s) under `host/ui`
- avoid widening activity globals or adding fallback compatibility paths
- compile debug + release Java after code changes

### `AHW24-M3` Consumer rewiring (`complete`)

Queue line (exact):

- rewire consumers to the explicit terminal-view policy seam while preserving behavior

Acceptance:

- consumers use policy seam rather than ad hoc activation mutations
- single-terminal runtime behavior remains unchanged
- compile debug + release Java after code changes

### `AHW24-M4` Contract docs lock (`complete`)

Queue line (exact):

- lock authority docs to app-shell terminal-view policy ownership

Acceptance:

- host structure and naming contract match code shape
- userland contract remains unchanged unless ownership text requires update

### `AHW24-M5` Queue/handoff/entrypoint sync (`complete`)

Queue line (exact):

- keep queue, handoff, and engineer entrypoint aligned to AHW-B24 execution and super-gate stop

Acceptance:

- queue, handoff, and engineer entrypoint stay coherent through B24 super-gate
- super-gate stop condition and review packet contract are explicit

### `AHW24-M6` Batch validation + review packet (`complete`)

Queue line (exact):

- validate AHW-B24 end-to-end and publish the architect review packet

Acceptance:

- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass, or exact device-blocker output is recorded
- cold start smoke pass when a device is available
- engineer reports the full super-gate packet and stops for Architect review

**AHW-B24 engineer validation record (M6):**

- `./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac` — pass
- `./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac` — pass
- `python3 ops/android_terminal_host.py deploy` — pass (streamed install, activity start)
- `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E` — pass (no `AndroidRuntime:E` lines; benign duplicate-top warning when activity already foreground)
- `adb shell am force-stop uk.laurencegouws.zide && adb shell am start -W -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity` — pass (`LaunchState: COLD`, `Status: ok`)

`Milestone reached per docs, architect review required.`

Architect review verdict:

- `Review chunk: AHW-B24`
- `Verdict: accepted`
- `Commits reviewed: 023a3d86, 8def5013`
- `Architect validation spot-check: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass)`
- `Architect runtime validation spot-check: python3 ops/android_terminal_host.py deploy (pass); adb cold start (pass, LaunchState: COLD); adb logcat -d -s AndroidRuntime:E (pass, empty)`
- `Engineer device validation accepted: deploy + AndroidRuntime:E smoke + cold start pass`
- `Review answers: yes, close AHW-B24 and advance queue. Future tab shell selection should extend AppShellTerminalViewPolicy with explicit methods first; split further only if policy responsibilities become materially divergent.`
- `Findings carried forward: B24 is behavior-preserving and correctly centralizes activation path. Remaining pressure is raw navigation exposure through AppShellTerminalViewPolicy.appShellNavigation(); next batch should narrow that surface without changing behavior.`

---

### `AHW-B25` App-shell Policy Surface Narrowing (`completed`)

Batch queue line (exact):

- narrow app-shell terminal-view policy surface so consumers no longer depend on raw AppShellNavigation exposure while preserving single-terminal behavior

Batch purpose:

- keep AppShellTerminalViewPolicy as the explicit harness policy owner
- reduce raw AppShellNavigation leakage from widget harness bundles
- preserve refocus shape and current runtime behavior while preparing clean tab-policy extension seams

Batch scope:

- Java Android terminal host only, plus authority docs needed to keep contract truth current
- primary code root:
  `android/terminal-host/app/src/main/java/uk/laurencegouws/terminal/**`
- allowed docs:
  `docs/todo/android/implementation.md`,
  `docs/todo/android/ENGINEER_ENTRYPOINT.md`,
  `docs/AGENT_HANDOFF.md`,
  `app_architecture/platform/android/ANDROID_JAVA_HOST_STRUCTURE.md`,
  `app_architecture/platform/android/ANDROID_JAVA_NAMING_CONTRACT.md`,
  `app_architecture/platform/android/USERLAND_HOST_CONTRACT.md`

Batch non-goals:

- no terminal tabs UI/product behavior
- no tab persistence/session switching
- no terminal-core or shared-renderer changes
- no app-shell UI redesign
- no keep-screen-on follow-up implementation unless explicitly re-opened
- no debug-view UI resurrection
- no broad rename sweep
- no ASF operator-evidence churn unless new evidence arrives

Batch super-gate:

- raw AppShellNavigation exposure is reduced behind explicit policy methods where practical
- single-terminal runtime behavior remains unchanged
- no seam ownership regression against B14-B24 contracts
- docs reflect final ownership/naming shape
- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass at final seam boundary

Internal milestone cadence:

- Engineer executes `AHW25-M1` through `AHW25-M6` sequentially.
- Do not stop for architect review between internal milestones.
- Mark each internal milestone complete in this file as it lands.
- Stop only if the hard stop conditions in `ENGINEER_ENTRYPOINT.md` are hit or
  the `AHW-B25` super-gate is reached.

### `AHW25-M1` Raw navigation exposure audit (`complete`)

Queue line (exact):

- audit AppShellTerminalViewPolicy.appShellNavigation() callsites and classify required reads/writes vs avoidable leakage

Acceptance:

- enumerate all consumers reaching raw navigation through policy
- define minimal explicit policy methods needed for current behavior
- record out-of-scope seams

**M1 audit (authoritative for B25):**

- **Consumers of `appShellNavigation()` (B24):** none outside `AppShellTerminalViewPolicy` itself; javadoc on `WidgetHarnessHostControllers` only referenced the accessor. **Avoidable leakage:** public `appShellNavigation()` invited harness consumers to depend on raw `AppShellNavigation`.
- **Chrome path:** `ChromeBridge` held `AppShellNavigation` only for `chromeDrawerSidebarOpen` / `applyChromeDrawerSidebarOpen` / `applyChromeDrawerSidebarClosed` — three forwards, replaceable with explicit methods on `AppShellTerminalViewPolicy`.
- **Minimal explicit methods:** terminal activation (existing `applyActiveProductTerminalShellView`) plus the three drawer sidebar methods mirroring `AppShellNavigation` names.
- **Out of scope:** `AppShellNavigation` construction in `WidgetAssembly` (still `forProductTerminalSlot` once), `AppShellViewState` / `activeViewState()` (no harness consumer outside navigation internals), slot/chrome threading, IME seams, startup order.

### `AHW25-M2` Policy API expansion (`complete`)

Queue line (exact):

- add explicit policy methods to cover current consumer needs without exposing raw navigation by default

Acceptance:

- introduce ownership-first policy method names
- keep behavior unchanged and avoid compatibility fallback paths
- compile debug + release Java after code changes

### `AHW25-M3` Consumer rewiring (`complete`)

Queue line (exact):

- rewire consumers to the new AppShellTerminalViewPolicy methods and narrow raw navigation access

Acceptance:

- consumers stop depending on raw navigation where replacement methods exist
- single-terminal runtime behavior remains unchanged
- compile debug + release Java after code changes

### `AHW25-M4` Contract docs lock (`complete`)

Queue line (exact):

- lock authority docs to narrowed app-shell policy surface

Acceptance:

- host structure and naming contract match code shape
- userland contract remains unchanged unless ownership text requires update

### `AHW25-M5` Queue/handoff/entrypoint sync (`complete`)

Queue line (exact):

- keep queue, handoff, and engineer entrypoint aligned to AHW-B25 execution and super-gate stop

Acceptance:

- queue, handoff, and engineer entrypoint stay coherent through B25 super-gate
- super-gate stop condition and review packet contract are explicit

### `AHW25-M6` Batch validation + review packet (`complete`)

Queue line (exact):

- validate AHW-B25 end-to-end and publish the architect review packet

Acceptance:

- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass, or exact device-blocker output is recorded
- cold start smoke pass when a device is available
- engineer reports the full super-gate packet and stops for Architect review

**AHW-B25 engineer validation record (M6):**

- `./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac` — pass
- `./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac` — pass
- `python3 ops/android_terminal_host.py deploy` — pass (streamed install, activity start)
- `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E` — pass (no `AndroidRuntime:E` lines; benign duplicate-top warning when activity already foreground)
- `adb shell am force-stop uk.laurencegouws.zide && adb shell am start -W -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity` — pass (`LaunchState: COLD`, `Status: ok`)

`Milestone reached per docs, architect review required.`

Architect review verdict:

- `Review chunk: AHW-B25`
- `Verdict: accepted`
- `Commits reviewed: 203d976d, c8d560ee`
- `Architect validation spot-check: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass)`
- `Architect runtime validation spot-check: python3 ops/android_terminal_host.py deploy (pass); adb cold start (pass, LaunchState: COLD); adb logcat -d -s AndroidRuntime:E (pass, empty)`
- `Engineer device validation accepted: deploy + AndroidRuntime:E smoke + cold start pass`
- `Review answers: yes, close AHW-B25. No immediate follow-up is required to expose activeViewState through policy; add only when a concrete non-chrome harness reader exists in scope.`
- `Findings carried forward: behavior preserved and policy leakage reduced as intended. Next batch should perform campaign landing-gate closure audit and resolve only concrete remaining ownership gaps.`

---

### `AHW-B26` Refocus-Shape Landing Gate Closure (`completed`)

Batch queue line (exact):

- perform landing-gate closure audit and resolve only concrete remaining harness/widget/userland ownership gaps needed to close AHW

Batch purpose:

- validate `refocus_android.txt` shape directly against current Android host code
- close any real remaining ownership leaks with minimal behavior-preserving cuts
- prepare explicit AHW campaign closure if landing gate is satisfied

Batch scope:

- Java Android terminal host only, plus authority docs needed to keep contract truth current
- primary code root:
  `android/terminal-host/app/src/main/java/uk/laurencegouws/terminal/**`
- allowed docs:
  `docs/todo/android/implementation.md`,
  `docs/todo/android/ENGINEER_ENTRYPOINT.md`,
  `docs/AGENT_HANDOFF.md`,
  `app_architecture/platform/android/ANDROID_JAVA_HOST_STRUCTURE.md`,
  `app_architecture/platform/android/ANDROID_JAVA_NAMING_CONTRACT.md`,
  `app_architecture/platform/android/USERLAND_HOST_CONTRACT.md`

Batch non-goals:

- no terminal tabs UI/product behavior
- no tab persistence/session switching
- no terminal-core or shared-renderer changes
- no app-shell UI redesign
- no keep-screen-on follow-up implementation unless explicitly re-opened
- no debug-view UI resurrection
- no broad rename sweep
- no ASF operator-evidence churn unless new evidence arrives

Batch super-gate:

- campaign landing-gate checklist is audited against current code and docs
- any identified remaining ownership leaks in active scope are fixed with behavior-preserving cuts
- if no leaks remain, AHW closure recommendation is explicit and documented
- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass at final seam boundary

Internal milestone cadence:

- Engineer executes `AHW26-M1` through `AHW26-M6` sequentially.
- Do not stop for architect review between internal milestones.
- Mark each internal milestone complete in this file as it lands.
- Stop only if the hard stop conditions in `ENGINEER_ENTRYPOINT.md` are hit or
  the `AHW-B26` super-gate is reached.

### `AHW26-M1` Landing-gate audit (`complete`)

Queue line (exact):

- audit the five refocus landing-gate criteria against current code ownership and callsites

Acceptance:

- checklist each landing criterion as pass/gap with concrete file evidence
- identify only real gaps, not speculative future design wishes
- record out-of-scope items explicitly

**M1 audit (authoritative for B26):**

| Criterion | Verdict | Evidence |
| --- | --- | --- |
| (1) Harness is canvas; does not own terminal widget internals | **Pass** | Terminal interaction/surface code lives in `selection/`, `input/`, `gesture/`, `host/surface/`; harness composes via `WidgetAssembly`, `TerminalWidgetCompositionAssembly`, `TerminalWidgetInstance` — `ZideActivity` does not construct widget holder directly (see `ANDROID_JAVA_HOST_STRUCTURE.md` harness-held instance section). |
| (2) Terminal widget is portable consumer; no app-shell/userland orchestration | **Pass** | No `selection/` or `gesture/` imports of `host.ui` chrome/app-shell orchestration; chrome/view-mode stay in `host/ui`. |
| (3) Userland movable; free of widget/surface/controller ownership | **Pass** | `userland/` sources do not import `host.ui`, `host.surface`, `selection`, or `gesture` types; integration uses harness `ShellPresentationHostInputs` and callbacks per `USERLAND_HOST_CONTRACT.md`. `ShellStatePresenter.Host` exposes Android `SurfaceView`/`View` as presentation seams only — not widget controller types. |
| (4) `ZideActivity` is wiring edge, not backbone | **Pass** | OnCreate choreography: `ProductHostOnCreateStartupCoordinator` + `ProductHostOnCreateStartupSteps`; wiring hosts: `ProductHostActivityStartupWiring`, `ProductTerminalWidgetAssemblyHost`, `ProductTerminalLifecycleHost`. |
| (5) Remaining work is product expansion, not ownership rescue | **Pass** (doc stance) | No concrete ownership leak identified in M1 requiring a further AHW batch; next Android work is explicitly scoped features (tabs/view policy), not structural rescue. |

**Gaps requiring Java changes in this batch:** none identified.

**Doc hygiene:** `USERLAND_HOST_CONTRACT.md` still described shell policy primarily through raw `AppShellNavigation`; updated in M4 to include `AppShellTerminalViewPolicy` (B24–B25 reality).

**Out of scope:** terminal tabs UI, `InteractionAssembly.Result` slot threading, per-slot chrome, keep-screen-on beyond B20, ASF operator-evidence rows.

### `AHW26-M2` Remaining-gap plan lock (`complete`)

Queue line (exact):

- convert M1 gaps into minimal behavior-preserving cuts or explicitly mark no-code-needed closure path

Acceptance:

- each gap has a bounded code/doc action or explicit closure note
- no compatibility fallback paths added
- compile debug + release Java after any code changes

**M2 outcome:** no M1 code gaps → **no-code closure path** for Java; authority doc updates only (M4).

### `AHW26-M3` Gap resolution cuts (`complete`)

Queue line (exact):

- implement only the minimal ownership fixes required by the audited landing-gate gaps

Acceptance:

- ownership leaks identified in M1 are resolved or explicitly deferred with rationale
- runtime behavior remains unchanged
- compile debug + release Java after code changes

**M3 outcome:** no ownership-fix commits (no leaks).

### `AHW26-M4` Authority lock (`complete`)

Queue line (exact):

- lock authority docs to post-gap ownership reality and landing-gate status

Acceptance:

- host structure and naming contract match code shape
- userland contract remains unchanged unless ownership text requires update

### `AHW26-M5` Queue/handoff/entrypoint sync (`complete`)

Queue line (exact):

- keep queue, handoff, and engineer entrypoint aligned to AHW-B26 execution and super-gate stop

Acceptance:

- queue, handoff, and engineer entrypoint stay coherent through B26 super-gate
- super-gate stop condition and review packet contract are explicit

### `AHW26-M6` Batch validation + review packet (`complete`)

Queue line (exact):

- validate AHW-B26 end-to-end and publish the architect review packet with closure recommendation

Acceptance:

- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass, or exact device-blocker output is recorded
- cold start smoke pass when a device is available
- engineer reports full super-gate packet and explicit recommendation: `AHW close` or `one final gap batch`

**Engineer closure recommendation:** **`AHW close`** — landing-gate checklist satisfied; remaining Android lane work should be scheduled as **product expansion** (queue already describes post-`AHW` posture in campaign landing gate).

**AHW-B26 engineer validation record (M6):**

- `./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac` — pass
- `./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac` — pass
- `python3 ops/android_terminal_host.py deploy` — pass (streamed install, activity start)
- `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E` — pass (no `AndroidRuntime:E` lines; benign duplicate-top warning when activity already foreground)
- `adb shell am force-stop uk.laurencegouws.zide && adb shell am start -W -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity` — pass (`LaunchState: COLD`, `Status: ok`)

`Milestone reached per docs, architect review required.`

Architect review verdict:

- `Review chunk: AHW-B26`
- `Verdict: accepted`
- `Commits reviewed: 8ef4a4a1`
- `Architect validation spot-check: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass)`
- `Architect runtime validation spot-check: python3 ops/android_terminal_host.py deploy (pass); adb cold start (pass, LaunchState: COLD); adb logcat -d -s AndroidRuntime:E (pass, empty)`
- `Engineer device validation accepted: deploy + AndroidRuntime:E smoke + cold start pass`
- `Review answers: yes, AHW is formally closed. No dissent on criterion (5): remaining work is product expansion under explicit scoped batches.`
- `Findings carried forward: AHW ownership rescue is complete. New lane is product expansion on top of stable harness/widget contracts.`

---

## Post-AHW Campaign

Campaign: `APX` (Android Product Expansion)

- Goal: ship product-facing terminal expansion capability on top of closed AHW ownership boundaries.
- Rules: do not reopen ownership rescue unless a concrete regression appears.

### `APX-B1` Multi-terminal app-shell policy foundation (`accepted`)

Batch queue line (exact):

- define and implement explicit multi-terminal app-shell policy seams (selection and activation only) without shipping tabs UI

Batch purpose:

- begin product expansion by shaping policy seams for multi-terminal selection
- preserve current single-terminal behavior by default
- keep harness/widget/userland ownership boundaries unchanged from AHW closure

Batch scope:

- Java Android terminal host only, plus authority docs needed to keep contract truth current
- primary code root:
  `android/terminal-host/app/src/main/java/uk/laurencegouws/terminal/**`
- allowed docs:
  `docs/todo/android/implementation.md`,
  `docs/todo/android/ENGINEER_ENTRYPOINT.md`,
  `docs/AGENT_HANDOFF.md`,
  `app_architecture/platform/android/ANDROID_JAVA_HOST_STRUCTURE.md`,
  `app_architecture/platform/android/ANDROID_JAVA_NAMING_CONTRACT.md`,
  `app_architecture/platform/android/USERLAND_HOST_CONTRACT.md`

Batch non-goals:

- no tabs UI rendering
- no tab persistence/session switching
- no terminal-core or shared-renderer changes
- no app-shell visual redesign
- no keep-screen-on follow-up implementation unless explicitly re-opened
- no debug-view UI resurrection
- no broad rename sweep

Batch super-gate:

- multi-terminal selection policy seam(s) exist with explicit ownership and no ad hoc `ShellViewId` mutations
- default behavior remains current single-terminal product path
- no seam ownership regression against AHW closure baseline
- docs reflect final ownership/naming shape
- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass at final seam boundary

Internal milestone cadence:

- Engineer executes `APX1-M1` through `APX1-M6` sequentially.
- Do not stop for architect review between internal milestones.
- Mark each internal milestone complete in this file as it lands.
- Stop only if the hard stop conditions in `ENGINEER_ENTRYPOINT.md` are hit or
  the `APX-B1` super-gate is reached.

### `APX1-M1` Expansion policy audit (`complete`)

Queue line (exact):

- audit current app-shell terminal selection/activation callsites and define bounded multi-terminal policy seam targets

Acceptance:

- enumerate current activation/selection mutation points
- specify minimal policy interfaces for expansion without behavior change
- record out-of-scope items explicitly

**M1 audit (authoritative for APX-B1):**

- **Selection (which slot is routed for app-shell / shell view mapping):** previously implicit via `TerminalWidgetSlotId.PRIMARY` literals and `host.terminalWidgetSlot()` feeding `AppShellNavigation.forProductTerminalSlot` directly. **Target seam:** `AppShellTerminalSelectionPolicy` (`singleTerminalProduct`, `forDeclaredHostSlot`, `selectedProductTerminalSlotForAppShell`).
- **Activation (visible shell view + drawer chrome):** already `AppShellTerminalViewPolicy` on `WidgetHarnessHostControllers`; clarified as **activation** in type Javadoc (distinct from selection).
- **Mutation points:** `ShellViewId` changes remain inside `AppShellNavigation` private state; no new ad hoc `ShellViewId` setters. View-mode re-assert still `applyActiveProductTerminalShellView`.
- **Out of scope:** tabs UI, tab persistence, second active slot, chrome factory slot threading, IME/startup contract changes, terminal-core.

### `APX1-M2` Policy seam introduction (`complete`)

Queue line (exact):

- introduce explicit multi-terminal app-shell policy seam(s) with ownership-first naming

Acceptance:

- add policy owner surfaces under `host/ui`
- no fallback compatibility paths
- compile debug + release Java after code changes

### `APX1-M3` Consumer rewiring (`complete`)

Queue line (exact):

- rewire current single-terminal consumers through expansion policy seam defaults

Acceptance:

- current behavior unchanged
- no direct ad hoc shell-view mutations in rewired consumers
- compile debug + release Java after code changes

### `APX1-M4` Contract docs lock (`complete`)

Queue line (exact):

- lock authority docs to APX-B1 policy seam ownership

Acceptance:

- host structure and naming contract match code shape
- userland contract remains unchanged unless ownership text requires update

### `APX1-M5` Queue/handoff/entrypoint sync (`complete`)

Queue line (exact):

- keep queue, handoff, and engineer entrypoint aligned to APX-B1 execution and super-gate stop

Acceptance:

- queue, handoff, and engineer entrypoint stay coherent through APX-B1 super-gate
- super-gate stop condition and review packet contract are explicit

### `APX1-M6` Batch validation + review packet (`complete`)

Queue line (exact):

- validate APX-B1 end-to-end and publish the architect review packet

Acceptance:

- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass, or exact device-blocker output is recorded
- cold start smoke pass when a device is available
- engineer reports full super-gate packet and explicit residual-risk note

**APX-B1 engineer validation record (M6):**

- `./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac` — pass
- `./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac` — pass
- `python3 ops/android_terminal_host.py deploy` — pass (streamed install, activity start)
- `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E` — pass (no `AndroidRuntime:E` lines; benign duplicate-top warning when activity already foreground)
- `adb shell am force-stop uk.laurencegouws.zide && adb shell am start -W -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity` — pass (`LaunchState: COLD`, `Status: ok`)

**Residual risk:** Low — selection always `PRIMARY`; future multi-slot work extends `AppShellTerminalSelectionPolicy` and relaxes `checkActiveProductTerminalSlot` in a scoped batch.

`Milestone reached per docs, architect review required.`

Architect review verdict:

- `Review chunk: APX-B1`
- `Verdict: accepted`
- `Commits reviewed: 61cf040c, 15d6e5cb`
- `Architect validation spot-check: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass)`
- `Architect runtime validation spot-check: python3 ops/android_terminal_host.py deploy (pass); adb cold start (pass, LaunchState: COLD); adb logcat -d -s AndroidRuntime:E (pass, empty)`
- `Engineer device validation accepted: deploy + AndroidRuntime:E smoke + cold start pass`
- `Review answers: APX-B1 accepted; selection vs activation split is correct. Next batch should add declared-slot catalog seams only (PRIMARY default), still no tabs UI/product behavior.`
- `Findings carried forward: no blocking behavior regressions; startup order and single-slot runtime behavior unchanged.`

### `APX-B2` Declared slot catalog foundation (`accepted`)

Batch queue line (exact):

- introduce declared terminal-slot catalog seams and route selection policy through them without enabling multi-slot runtime behavior

Batch purpose:

- make slot declaration explicit for future expansion while preserving today’s single-slot behavior
- keep selection (`AppShellTerminalSelectionPolicy`) and activation (`AppShellTerminalViewPolicy`) ownership split from APX-B1
- avoid re-opening AHW ownership rescue work

Batch scope:

- Java Android terminal host only, plus authority docs needed to keep contract truth current
- primary code root:
  `android/terminal-host/app/src/main/java/uk/laurencegouws/terminal/**`
- allowed docs:
  `docs/todo/android/implementation.md`,
  `docs/todo/android/ENGINEER_ENTRYPOINT.md`,
  `docs/AGENT_HANDOFF.md`,
  `app_architecture/platform/android/ANDROID_JAVA_HOST_STRUCTURE.md`,
  `app_architecture/platform/android/ANDROID_JAVA_NAMING_CONTRACT.md`,
  `app_architecture/platform/android/USERLAND_HOST_CONTRACT.md`

Batch non-goals:

- no tabs UI rendering
- no second active terminal slot behavior
- no tab persistence/session switching
- no terminal-core or shared-renderer changes
- no keep-screen-on follow-up implementation unless explicitly re-opened
- no startup-order changes

Batch super-gate:

- declared slot catalog seam exists with PRIMARY-only default and explicit owner naming
- selection policy consumes declared-slot seam instead of ad hoc literals
- activation policy wiring remains unchanged in behavior
- docs reflect final ownership/naming shape
- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass at final seam boundary

Internal milestone cadence:

- Engineer executes `APX2-M1` through `APX2-M6` sequentially.
- Do not stop for architect review between internal milestones.
- Mark each internal milestone complete in this file as it lands.
- Stop only if the hard stop conditions in `ENGINEER_ENTRYPOINT.md` are hit or
  the `APX-B2` super-gate is reached.

### `APX2-M1` Declared-slot seam audit (`complete`)

Queue line (exact):

- audit declared-slot vs selected-slot callsites and define the bounded catalog seam target

Acceptance:

- enumerate slot declaration callsites in activity, widget host, and selection policy wiring
- define one catalog owner type under `host/ui`
- record explicit out-of-scope items (tabs UI, second-slot runtime)

**M1 audit:**

- **Declared vs selected:** `TerminalWidgetSlotId` enum is the identity; **declared catalog** answers “which slots the harness product declares”; **selection policy** answers “which slot is selected for app-shell routing” (today same as sole declared + active). **Active** remains `checkActiveProductTerminalSlot` only.
- **Callsites:** `ZideActivity` / `WidgetAssembly` already routed through `AppShellTerminalSelectionPolicy`; **target** is `DeclaredTerminalWidgetSlotCatalog` as catalog owner, consumed inside selection policy and `forDeclaredHostSlot`.
- **Out of scope:** tabs UI, second active slot, new enum values, chrome slot threading.

### `APX2-M2` Catalog seam introduction (`complete`)

Queue line (exact):

- introduce the declared terminal-slot catalog seam with PRIMARY default and ownership-first naming

Acceptance:

- add catalog owner surface under `host/ui`
- no compatibility/fallback paths
- compile debug + release Java after code changes

### `APX2-M3` Consumer rewiring (`complete`)

Queue line (exact):

- rewire selection policy and current wiring consumers through the declared-slot catalog seam defaults

Acceptance:

- current behavior unchanged
- no ad hoc slot literals in rewired selection callsites
- compile debug + release Java after code changes

### `APX2-M4` Contract docs lock (`complete`)

Queue line (exact):

- lock authority docs to APX-B2 declared-slot ownership shape

Acceptance:

- host structure and naming contract match code shape
- userland contract updated only if ownership text requires it

### `APX2-M5` Queue/handoff/entrypoint sync (`complete`)

Queue line (exact):

- keep queue, handoff, and engineer entrypoint aligned to APX-B2 execution and super-gate stop

Acceptance:

- queue, handoff, and engineer entrypoint stay coherent through APX-B2 super-gate
- super-gate stop condition and review packet contract are explicit

### `APX2-M6` Batch validation + review packet (`complete`)

Queue line (exact):

- validate APX-B2 end-to-end and publish the architect review packet

Acceptance:

- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass, or exact device-blocker output is recorded
- cold start smoke pass when a device is available
- engineer reports full super-gate packet and explicit residual-risk note

**APX-B2 engineer validation record (M6):**

- `./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac` — pass
- `./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac` — pass
- `python3 ops/android_terminal_host.py deploy` — pass (streamed install, activity start)
- `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E` — pass (no `AndroidRuntime:E` lines; benign duplicate-top warning when activity already foreground)
- `adb shell am force-stop uk.laurencegouws.zide && adb shell am start -W -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity` — pass (`LaunchState: COLD`, `Status: ok`)

**Residual risk:** Low — catalog is PRIMARY-only; `checkActiveProductTerminalSlot` unchanged; activation path untouched.

`Milestone reached per docs, architect review required.`

Architect review verdict:

- `Review chunk: APX-B2`
- `Verdict: accepted`
- `Commits reviewed: a7534d68, bdbe18b0`
- `Architect validation spot-check: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac :app:compileReleaseJavaWithJavac (pass)`
- `Architect runtime validation spot-check: python3 ops/android_terminal_host.py deploy (pass); adb warm start + AndroidRuntime:E (pass, empty); adb cold start (pass, LaunchState: COLD)`
- `Engineer device validation accepted: compile + deploy + AndroidRuntime:E smoke + cold start pass`
- `Review answers: APX-B2 accepted; declared-slot catalog seam is the right owner and wiring remains behavior-preserving.`
- `Findings carried forward: no blocking regressions; single-slot runtime unchanged while declared-slot ownership is now explicit.`

### `APX-B3` Slot selection context consolidation (`accepted`)

Batch queue line (exact):

- consolidate declared-slot and selected-slot resolution into one host selection context seam and consume it once per startup path

Batch purpose:

- remove repeated per-call selection lookups in activity wiring
- make declared-slot + selected-slot relationship explicit as one startup-owned context
- preserve APX-B1/APX-B2 behavior and ownership boundaries

Batch scope:

- Java Android terminal host only, plus authority docs needed to keep contract truth current
- primary code root:
  `android/terminal-host/app/src/main/java/uk/laurencegouws/terminal/**`
- allowed docs:
  `docs/todo/android/implementation.md`,
  `docs/todo/android/ENGINEER_ENTRYPOINT.md`,
  `docs/AGENT_HANDOFF.md`,
  `app_architecture/platform/android/ANDROID_JAVA_HOST_STRUCTURE.md`,
  `app_architecture/platform/android/ANDROID_JAVA_NAMING_CONTRACT.md`,
  `app_architecture/platform/android/USERLAND_HOST_CONTRACT.md`

Batch non-goals:

- no tabs UI rendering
- no second active terminal slot behavior
- no new `TerminalWidgetSlotId` enum values
- no terminal-core or shared-renderer changes
- no keep-screen-on follow-up implementation unless explicitly re-opened
- no startup-order changes

Batch super-gate:

- one explicit startup selection context seam owns declared-slot + selected-slot values
- `ZideActivity` consumes that context once (no repeated ad hoc selection reads)
- existing selection/activation behavior remains unchanged
- docs reflect final ownership/naming shape
- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass at final seam boundary

Internal milestone cadence:

- Engineer executes `APX3-M1` through `APX3-M6` sequentially.
- Do not stop for architect review between internal milestones.
- Mark each internal milestone complete in this file as it lands.
- Stop only if the hard stop conditions in `ENGINEER_ENTRYPOINT.md` are hit or
  the `APX-B3` super-gate is reached.

### `APX3-M1` Selection context audit (`complete`)

Queue line (exact):

- audit declared-slot and selected-slot reads and define one bounded selection-context seam target

Acceptance:

- enumerate current reads in `ZideActivity`, `WidgetAssembly`, and selection policy callers
- define one owner type under `host/ui` for startup selection context
- record explicit out-of-scope items (tabs UI, second active slot behavior)

**M1 audit (authoritative for B3):**

- **Reads before B3:** `ZideActivity` held `AppShellTerminalSelectionPolicy.singleTerminalProduct()` and called `selectedProductTerminalSlotForAppShell()` three times (interaction wiring, `TerminalWidgetCompositionAssembly.compose`, `WidgetHostAssemblyContext` slot). `WidgetAssembly.assemble` called `AppShellTerminalSelectionPolicy.forDeclaredHostSlot(host.terminalWidgetSlot())` then `selectedProductTerminalSlotForAppShell()` for `AppShellNavigation` — duplicate policy resolution vs activity.
- **Target seam:** `AppShellTerminalHostSelectionContext` under `host/ui`: `forProductHostStartup` resolves catalog + policy once; exposes `declaredSlotCatalog()`, `selectedProductTerminalSlotForAppShell()`, `appShellTerminalSelectionPolicy()`. (APX-B4 adds `ProductHostDeclaredTerminalWidgetSlot` as the explicit host-declared-slot source feeding `forProductHostStartup`.)
- **Out of scope:** tabs UI, second active slot runtime, startup order change, chrome/IME threading.

### `APX3-M2` Selection context seam introduction (`complete`)

Queue line (exact):

- introduce a startup selection-context owner that carries declared-slot and selected-slot values

Acceptance:

- add selection-context owner surface under `host/ui`
- no compatibility/fallback paths
- compile debug + release Java after code changes

### `APX3-M3` Consumer rewiring (`complete`)

Queue line (exact):

- rewire activity and assembly startup callsites to consume the selection context once per startup path

Acceptance:

- current behavior unchanged
- no repeated ad hoc selected-slot reads in rewired startup callsites
- compile debug + release Java after code changes

### `APX3-M4` Contract docs lock (`complete`)

Queue line (exact):

- lock authority docs to APX-B3 selection-context ownership shape

Acceptance:

- host structure and naming contract match code shape
- userland contract updated only if ownership text requires it

### `APX3-M5` Queue/handoff/entrypoint sync (`complete`)

Queue line (exact):

- keep queue, handoff, and engineer entrypoint aligned to APX-B3 execution and super-gate stop

Acceptance:

- queue, handoff, and engineer entrypoint stay coherent through APX-B3 super-gate
- super-gate stop condition and review packet contract are explicit

### `APX3-M6` Batch validation + review packet (`complete`)

Queue line (exact):

- validate APX-B3 end-to-end and publish the architect review packet

Acceptance:

- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass, or exact device-blocker output is recorded
- cold start smoke pass when a device is available
- engineer reports full super-gate packet and explicit residual-risk note

**APX-B3 engineer validation record (M6):**

- `./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac` — pass
- `./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac` — pass
- `python3 ops/android_terminal_host.py deploy` — pass (streamed install, activity start)
- `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E` — pass (no `AndroidRuntime:E` lines; benign duplicate-top warning when activity already foreground)
- `adb shell am force-stop uk.laurencegouws.zide && adb shell am start -W -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity` — pass (`LaunchState: COLD`, `Status: ok`)

**Residual risk:** Low — single PRIMARY path unchanged; `WidgetAssembly` asserts host slot matches context selected slot (wiring invariant).

`Milestone reached per docs, architect review required.`

Architect review verdict:

- `Review chunk: APX-B3`
- `Verdict: accepted`
- `Commits reviewed: e19f09d8, d733f28a`
- `Architect validation spot-check: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass)`
- `Architect runtime validation spot-check: python3 ops/android_terminal_host.py deploy (pass); adb warm start + AndroidRuntime:E (pass, empty); adb cold start (pass, LaunchState: COLD)`
- `Engineer device validation accepted: compile + deploy + AndroidRuntime:E smoke + cold start pass`
- `Review answers: one AppShellTerminalHostSelectionContext per activity startup is accepted as the intended seam; host/context slot equality check is accepted as a harness invariant and should remain fail-fast.`
- `Findings carried forward: no blocking regressions; startup order and single-slot behavior unchanged.`

### `APX-B4` Host declared-slot source seam (`accepted`)

Batch queue line (exact):

- introduce one explicit host-declared-slot source seam and build startup selection context from it (no behavior change)

Batch purpose:

- make declared slot source explicit at activity startup instead of relying on catalog default helper
- keep APX-B3 single-context-per-startup and fail-fast slot invariant
- preserve current PRIMARY-only runtime behavior

Batch scope:

- Java Android terminal host only, plus authority docs needed to keep contract truth current
- primary code root:
  `android/terminal-host/app/src/main/java/uk/laurencegouws/terminal/**`
- allowed docs:
  `docs/todo/android/implementation.md`,
  `docs/todo/android/ENGINEER_ENTRYPOINT.md`,
  `docs/AGENT_HANDOFF.md`,
  `app_architecture/platform/android/ANDROID_JAVA_HOST_STRUCTURE.md`,
  `app_architecture/platform/android/ANDROID_JAVA_NAMING_CONTRACT.md`,
  `app_architecture/platform/android/USERLAND_HOST_CONTRACT.md`

Batch non-goals:

- no tabs UI rendering
- no second active terminal slot behavior
- no new `TerminalWidgetSlotId` enum values
- no terminal-core or shared-renderer changes
- no keep-screen-on follow-up implementation unless explicitly re-opened
- no startup-order changes

Batch super-gate:

- one explicit host-declared-slot source seam exists in startup wiring
- `AppShellTerminalHostSelectionContext` is built from that seam via `forProductHostStartup`
- current behavior unchanged (`PRIMARY` only) and invariant checks remain fail-fast
- docs reflect final ownership/naming shape
- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass at final seam boundary

Internal milestone cadence:

- Engineer executes `APX4-M1` through `APX4-M6` sequentially.
- Do not stop for architect review between internal milestones.
- Mark each internal milestone complete in this file as it lands.
- Stop only if the hard stop conditions in `ENGINEER_ENTRYPOINT.md` are hit or
  the `APX-B4` super-gate is reached.

### `APX4-M1` Declared-slot source audit (`complete`)

Queue line (exact):

- audit declared-slot source callsites and define one bounded host-declared-slot owner seam

Acceptance:

- enumerate declared-slot reads in activity startup + widget host wiring
- define one owner type/field under `host/ui` or activity wiring edge
- record explicit out-of-scope items (tabs UI, second active slot behavior)

**M1 audit (authoritative for B4):**

- **Before B4:** `AppShellTerminalHostSelectionContext.forSingleTerminalProductHarnessStartup()` inlined `DeclaredTerminalWidgetSlotCatalog.currentProductHarness().defaultSelectedTerminalSlotForAppShell()` inside the context type; `ZideActivity` threaded `selectedProductTerminalSlotForAppShell()` from context into interaction / compose / `WidgetHostAssemblyContext` — correct but no named host-declared-slot owner.
- **Target seam:** `ProductHostDeclaredTerminalWidgetSlot.forCurrentProductHarness()` under `host/ui`; `ZideActivity` holds `productHostDeclaredTerminalWidgetSlot` then `forProductHostStartup(productHostDeclaredTerminalWidgetSlot)`; startup consumers use the field for host-aligned slot identity; `forSingleTerminalProductHarnessStartup` removed (single path).
- **Out of scope:** tabs UI, second active slot, startup order change.

### `APX4-M2` Declared-slot source seam introduction (`complete`)

Queue line (exact):

- introduce explicit host-declared-slot source seam and route startup context construction through it

Acceptance:

- `AppShellTerminalHostSelectionContext.forProductHostStartup(...)` is the startup path
- no compatibility/fallback paths
- compile debug + release Java after code changes

### `APX4-M3` Consumer rewiring (`complete`)

Queue line (exact):

- rewire startup consumers to use the explicit declared-slot source without changing behavior

Acceptance:

- current behavior unchanged
- no ad hoc declared-slot literals in rewired startup callsites
- compile debug + release Java after code changes

### `APX4-M4` Contract docs lock (`complete`)

Queue line (exact):

- lock authority docs to APX-B4 declared-slot source ownership shape

Acceptance:

- host structure and naming contract match code shape
- userland contract updated only if ownership text requires it

### `APX4-M5` Queue/handoff/entrypoint sync (`complete`)

Queue line (exact):

- keep queue, handoff, and engineer entrypoint aligned to APX-B4 execution and super-gate stop

Acceptance:

- queue, handoff, and engineer entrypoint stay coherent through APX-B4 super-gate
- super-gate stop condition and review packet contract are explicit

### `APX4-M6` Batch validation + review packet (`complete`)

Queue line (exact):

- validate APX-B4 end-to-end and publish the architect review packet

Acceptance:

- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass, or exact device-blocker output is recorded
- cold start smoke pass when a device is available
- engineer reports full super-gate packet and explicit residual-risk note

**APX-B4 engineer validation record (M6):**

- `./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac` — pass
- `./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac` — pass
- `python3 ops/android_terminal_host.py deploy` — pass (streamed install, activity start)
- `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E` — pass (no `AndroidRuntime:E` lines; benign duplicate-top warning when activity already foreground)
- `adb shell am force-stop uk.laurencegouws.zide && adb shell am start -W -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity` — pass (`LaunchState: COLD`, `Status: ok`)

**Residual risk:** Low — PRIMARY-only; host/context equality invariant unchanged.

`Milestone reached per docs, architect review required.`

Architect review verdict:

- `Review chunk: APX-B4`
- `Verdict: accepted`
- `Commits reviewed: 06e6dfff, 762eda03`
- `Architect validation spot-check: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass)`
- `Architect runtime validation spot-check: python3 ops/android_terminal_host.py deploy (pass); adb warm start + AndroidRuntime:E (pass, empty); adb cold start (pass, LaunchState: COLD)`
- `Engineer device validation accepted: compile + deploy + AndroidRuntime:E smoke + cold start pass`
- `Review answers: explicit host-declared slot source is accepted; removing `forSingleTerminalProductHarnessStartup` keeps single-path ownership clear.`
- `Findings carried forward: no blocking regressions; startup behavior and invariants unchanged.`

### `APX-B5` Declared-slot type hardening (`accepted`)

Batch queue line (exact):

- harden host-declared-slot source to a named value type and route startup context through that type (no behavior change)

Batch purpose:

- reduce raw `TerminalWidgetSlotId` fan-out for declared-slot ownership
- keep declared-slot source seam explicit while preserving APX-B4 startup flow
- preserve PRIMARY-only runtime behavior and fail-fast invariants
- run this as a longer engineer iteration: target **5–10 commits** before
  architect super-gate review

Batch scope:

- Java Android terminal host only, plus authority docs needed to keep contract truth current
- primary code root:
  `android/terminal-host/app/src/main/java/uk/laurencegouws/terminal/**`
- allowed docs:
  `docs/todo/android/implementation.md`,
  `docs/todo/android/ENGINEER_ENTRYPOINT.md`,
  `docs/AGENT_HANDOFF.md`,
  `app_architecture/platform/android/ANDROID_JAVA_HOST_STRUCTURE.md`,
  `app_architecture/platform/android/ANDROID_JAVA_NAMING_CONTRACT.md`,
  `app_architecture/platform/android/USERLAND_HOST_CONTRACT.md`

Batch non-goals:

- no tabs UI rendering
- no second active terminal slot behavior
- no new `TerminalWidgetSlotId` enum values
- no terminal-core or shared-renderer changes
- no keep-screen-on follow-up implementation unless explicitly re-opened
- no startup-order changes

Batch super-gate:

- host-declared-slot seam uses one named value type instead of raw slot primitives at startup boundary
- `AppShellTerminalHostSelectionContext` consumes declared-slot value type (or explicit accessor from it) in startup path
- behavior unchanged (`PRIMARY` only) and fail-fast invariants remain
- docs reflect final ownership/naming shape
- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass at final seam boundary

Internal milestone cadence:

- Engineer executes `APX5-M1` through `APX5-M6` sequentially.
- Engineer should keep cutting coherent validated commits across those milestones
  and target **5–10 commits total** before stopping at `APX-B5` super-gate.
- Do not stop for architect review between internal milestones.
- Mark each internal milestone complete in this file as it lands.
- Stop only if the hard stop conditions in `ENGINEER_ENTRYPOINT.md` are hit or
  the `APX-B5` super-gate is reached.

### `APX5-M1` Declared-slot type audit (`complete`)

Queue line (exact):

- audit raw declared-slot primitive flow and define bounded value-type seam target

Acceptance:

- enumerate raw `TerminalWidgetSlotId` flow from declared-slot source through startup callsites
- define one named declared-slot value type owner under `host/ui`
- record explicit out-of-scope items (tabs UI, second active slot behavior)

**M1 audit (authoritative for B5):**

- **Before B5:** `ProductHostDeclaredTerminalWidgetSlot` was a static namespace returning raw `TerminalWidgetSlotId`; `ZideActivity` field was `TerminalWidgetSlotId`; `forProductHostStartup` took raw enum.
- **Target:** `ProductHostDeclaredTerminalWidgetSlot` immutable value (`terminalWidgetSlot()`, `equals`/`hashCode`/`toString`); `forProductHostStartup(ProductHostDeclaredTerminalWidgetSlot)` only; context stores `hostDeclaredTerminalWidgetSlot()`; enum only at API boundaries (interaction wiring, `WidgetHostAssemblyContext`, composition).
- **Out of scope:** tabs UI, second active slot, startup order change.

### `APX5-M2` Value-type seam introduction (`complete`)

Queue line (exact):

- introduce declared-slot value type and route source seam through it

Acceptance:

- declared-slot source no longer exposes only raw slot primitive at startup boundary
- no compatibility/fallback paths
- compile debug + release Java after code changes

### `APX5-M3` Consumer rewiring (`complete`)

Queue line (exact):

- rewire startup context construction and consumers through declared-slot value type without behavior change

Acceptance:

- current behavior unchanged
- no ad hoc raw declared-slot primitive reads in rewired startup boundary
- compile debug + release Java after code changes

### `APX5-M4` Contract docs lock (`complete`)

Queue line (exact):

- lock authority docs to APX-B5 declared-slot value-type ownership shape

Acceptance:

- host structure and naming contract match code shape
- userland contract updated only if ownership text requires it

### `APX5-M5` Queue/handoff/entrypoint sync (`complete`)

Queue line (exact):

- keep queue, handoff, and engineer entrypoint aligned to APX-B5 execution and super-gate stop

Acceptance:

- queue, handoff, and engineer entrypoint stay coherent through APX-B5 super-gate
- super-gate stop condition and review packet contract are explicit

### `APX5-M6` Batch validation + review packet (`complete`)

Queue line (exact):

- validate APX-B5 end-to-end and publish the architect review packet

Acceptance:

- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass, or exact device-blocker output is recorded
- cold start smoke pass when a device is available
- engineer reports full super-gate packet and explicit residual-risk note

**Engineer commit cadence (this batch):** 7 commits — (1) core value type + context + ZideActivity + WidgetAssembly invariants; (2) catalog/harness/assembly javadoc; (3) selection policy `@see`; (4) authority docs trio; (5) implementation queue; (6) engineer entrypoint + handoff; (7) queue count fix.

**APX-B5 engineer validation record (M6):**

- `./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac` — pass (each code cut)
- `./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac` — pass
- `python3 ops/android_terminal_host.py deploy` — pass (streamed install, activity start)
- `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E` — pass (no `AndroidRuntime:E` lines; benign duplicate-top warning when activity already foreground)
- `adb shell am force-stop uk.laurencegouws.zide && adb shell am start -W -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity` — pass (`LaunchState: COLD`, `Status: ok`)

**Residual risk:** Low — PRIMARY-only; dual fail-fast check in `WidgetAssembly` (host vs declared value, host vs selected).

`Milestone reached per docs, architect review required.`

Architect review verdict:

- `Review chunk: APX-B5`
- `Verdict: accepted`
- `Commits reviewed: 29d28c4c, 5d7e3ce1, c516ab24, 7b1dbbf7, 41d265d1, 41f024f4, 53dd8f5e`
- `Architect validation spot-check: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass)`
- `Architect runtime validation spot-check: python3 ops/android_terminal_host.py deploy (pass); adb warm start + AndroidRuntime:E (pass, empty); adb cold start (pass, LaunchState: COLD)`
- `Engineer device validation accepted: compile + deploy + AndroidRuntime:E smoke + cold start pass`
- `Review answers: immutable ProductHostDeclaredTerminalWidgetSlot seam is accepted; dual WidgetAssembly fail-fast checks are acceptable and should remain.`
- `Findings carried forward: no blocking regressions; startup behavior and PRIMARY-only runtime unchanged.`

### `APX-B6` Startup slot boundary object propagation (`accepted`)

Batch queue line (exact):

- propagate ProductHostDeclaredTerminalWidgetSlot across startup boundary APIs and reduce raw slot enum fan-out without behavior change

Batch purpose:

- extend declared-slot value-type ownership through startup-facing seams
- keep APX-B5 immutable value seam and fail-fast invariants
- preserve PRIMARY-only runtime behavior
- run this as a longer engineer iteration: target **5–10 commits** before architect super-gate review

Batch scope:

- Java Android terminal host only, plus authority docs needed to keep contract truth current
- primary code root:
  `android/terminal-host/app/src/main/java/uk/laurencegouws/terminal/**`
- allowed docs:
  `docs/todo/android/implementation.md`,
  `docs/todo/android/ENGINEER_ENTRYPOINT.md`,
  `docs/AGENT_HANDOFF.md`,
  `app_architecture/platform/android/ANDROID_JAVA_HOST_STRUCTURE.md`,
  `app_architecture/platform/android/ANDROID_JAVA_NAMING_CONTRACT.md`,
  `app_architecture/platform/android/USERLAND_HOST_CONTRACT.md`

Batch non-goals:

- no tabs UI rendering
- no second active terminal slot behavior
- no new `TerminalWidgetSlotId` enum values
- no terminal-core or shared-renderer changes
- no keep-screen-on follow-up implementation unless explicitly re-opened
- no startup-order changes

Batch super-gate:

- startup boundary APIs consume `ProductHostDeclaredTerminalWidgetSlot` where ownership is declared-slot specific
- raw `TerminalWidgetSlotId` remains only at true enum-owner boundaries
- behavior unchanged (`PRIMARY` only) and fail-fast invariants remain
- docs reflect final ownership/naming shape
- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass at final seam boundary

Internal milestone cadence:

- Engineer executes `APX6-M1` through `APX6-M6` sequentially.
- Engineer should keep cutting coherent validated commits across those milestones
  and target **5–10 commits total** before stopping at `APX-B6` super-gate.
- Do not stop for architect review between internal milestones.
- Mark each internal milestone complete in this file as it lands.
- Stop only if the hard stop conditions in `ENGINEER_ENTRYPOINT.md` are hit or
  the `APX-B6` super-gate is reached.

### `APX6-M1` Startup boundary audit (`complete`)

Queue line (exact):

- audit startup boundary APIs for declared-slot value-type propagation targets

Acceptance:

- enumerate startup-facing APIs still taking raw `TerminalWidgetSlotId`
- define bounded conversion boundaries where enum remains the right owner
- record explicit out-of-scope items (tabs UI, second active slot behavior)

**M1 audit (authoritative for B6):**

- **Targets:** `ProductHostActivityStartupWiring.interaction`, `WidgetHostAssemblyContext` (was `TerminalWidgetSlotId slot`), `TerminalWidgetCompositionAssembly.compose` first parameter; `ZideActivity` callsites peeled enum before B6.
- **Enum stays:** `InteractionAssembly.Host` / `WidgetAssembly.Host` `terminalWidgetSlot()`, `AppShellTerminalSelectionPolicy.forDeclaredHostSlot`, `ProductTerminalSlotShellMapping`, `checkActiveProductTerminalSlot`, `AppShellNavigation.forProductTerminalSlot`.
- **Out of scope:** tabs UI, chrome slot threading, `InteractionAssembly.Result` slot field.

### `APX6-M2` API seam introduction (`complete`)

Queue line (exact):

- introduce ProductHostDeclaredTerminalWidgetSlot startup boundary API changes with ownership-first naming

Acceptance:

- declared-slot startup seams expose value type where ownership applies
- no compatibility/fallback paths
- compile debug + release Java after code changes

### `APX6-M3` Consumer rewiring (`complete`)

Queue line (exact):

- rewire startup consumers through updated declared-slot value-type APIs without behavior change

Acceptance:

- current behavior unchanged
- reduced raw enum fan-out in startup boundary callsites
- compile debug + release Java after code changes

### `APX6-M4` Contract docs lock (`complete`)

Queue line (exact):

- lock authority docs to APX-B6 startup slot boundary ownership shape

Acceptance:

- host structure and naming contract match code shape
- userland contract updated only if ownership text requires it

### `APX6-M5` Queue/handoff/entrypoint sync (`complete`)

Queue line (exact):

- keep queue, handoff, and engineer entrypoint aligned to APX-B6 execution and super-gate stop

Acceptance:

- queue, handoff, and engineer entrypoint stay coherent through APX-B6 super-gate
- super-gate stop condition and review packet contract are explicit

### `APX6-M6` Batch validation + review packet (`complete`)

Queue line (exact):

- validate APX-B6 end-to-end and publish the architect review packet

Acceptance:

- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass, or exact device-blocker output is recorded
- cold start smoke pass when a device is available
- engineer reports full super-gate packet and explicit residual-risk note

**Engineer commit cadence (this batch):** 7 commits — (1) interaction wiring + `InteractionCallbacks`; (2) `WidgetHostAssemblyContext` + widget host + activity; (3) `TerminalWidgetCompositionAssembly.compose` + activity; (4) javadoc on interaction/widget seams; (5) authority docs (`ANDROID_JAVA_HOST_STRUCTURE`, `ANDROID_JAVA_NAMING_CONTRACT`, `USERLAND_HOST_CONTRACT`); (6) implementation queue + engineer entrypoint + agent handoff; (7) `compose` `requireNonNull` + widget host javadoc alignment + cadence text fix in queue.

**APX-B6 engineer validation record (M6):**

- `./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac` — pass (each code cut)
- `./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac` — pass
- `python3 ops/android_terminal_host.py deploy` — pass (streamed install, activity start)
- `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E` — pass (no `AndroidRuntime:E` lines; benign duplicate-top warning when activity already foreground)
- `adb shell am force-stop uk.laurencegouws.zide && adb shell am start -W -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity` — pass (`LaunchState: COLD`, `Status: ok`)

**Residual risk:** Low — PRIMARY-only; `WidgetAssembly` dual invariant unchanged; enum-only surfaces documented in naming contract.

`Milestone reached per docs, architect review required.`

Architect review verdict:

- `Review chunk: APX-B6`
- `Verdict: accepted`
- `Commits reviewed: 97656216, 3afacf99, 287b9e29, 69a1c0e0, 3afb9fb7, fb66a397, abf0c292, 4c1e0538`
- `Architect validation spot-check: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass)`
- `Architect runtime validation spot-check: python3 ops/android_terminal_host.py deploy (pass); adb warm start + AndroidRuntime:E (pass, empty); adb cold start (pass, LaunchState: COLD)`
- `Engineer device validation accepted: compile + deploy + AndroidRuntime:E smoke + cold start pass`
- `Review answers: declared-slot value propagation across interaction/widget/composition startup seams is accepted; enum-owner boundaries remaining in assembly/navigation contracts are acceptable for now.`
- `Findings carried forward: no blocking regressions; startup behavior and PRIMARY-only runtime unchanged.`

### `APX-B7` Slot enum-conversion choke point (`accepted`)

Batch queue line (exact):

- centralize startup declared-slot enum conversion through one value-type choke point and reduce direct `.terminalWidgetSlot()` fan-out without behavior change

Batch purpose:

- keep APX-B6 value propagation while reducing scattered enum unwraps
- make declared-slot value type the single conversion owner for startup seams
- preserve PRIMARY-only runtime behavior and fail-fast invariants
- run this as a longer engineer iteration: target **5–10 commits** before architect super-gate review

Batch scope:

- Java Android terminal host only, plus authority docs needed to keep contract truth current
- primary code root:
  `android/terminal-host/app/src/main/java/uk/laurencegouws/terminal/**`
- allowed docs:
  `docs/todo/android/implementation.md`,
  `docs/todo/android/ENGINEER_ENTRYPOINT.md`,
  `docs/AGENT_HANDOFF.md`,
  `app_architecture/platform/android/ANDROID_JAVA_HOST_STRUCTURE.md`,
  `app_architecture/platform/android/ANDROID_JAVA_NAMING_CONTRACT.md`,
  `app_architecture/platform/android/USERLAND_HOST_CONTRACT.md`

Batch non-goals:

- no tabs UI rendering
- no second active terminal slot behavior
- no new `TerminalWidgetSlotId` enum values
- no terminal-core or shared-renderer changes
- no keep-screen-on follow-up implementation unless explicitly re-opened
- no startup-order changes

Batch super-gate:

- one explicit enum-conversion choke point exists on the declared-slot value seam for startup APIs
- direct startup `.terminalWidgetSlot()` call-site fan-out is reduced
- behavior unchanged (`PRIMARY` only) and fail-fast invariants remain
- docs reflect final ownership/naming shape
- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass at final seam boundary

Internal milestone cadence:

- Engineer executes `APX7-M1` through `APX7-M6` sequentially.
- Engineer should keep cutting coherent validated commits across those milestones
  and target **5–10 commits total** before stopping at `APX-B7` super-gate.
- Do not stop for architect review between internal milestones.
- Mark each internal milestone complete in this file as it lands.
- Stop only if the hard stop conditions in `ENGINEER_ENTRYPOINT.md` are hit or
  the `APX-B7` super-gate is reached.

### `APX7-M1` Conversion audit (`completed`)

Queue line (exact):

- audit startup `.terminalWidgetSlot()` conversions and define one bounded choke-point target on declared-slot value seam

Acceptance:

- enumerate startup conversion callsites where raw enum unwrap still happens
- define one owner method/type boundary for conversion
- record explicit out-of-scope items (tabs UI, second active slot behavior)

Outcome:

- prior fan-out on `ProductHostDeclaredTerminalWidgetSlot` was direct enum exposure; choke target is `terminalWidgetSlotForProductHarness()` on that value type only
- startup consumers identified: `AppShellTerminalHostSelectionContext.forProductHostStartup`, `InteractionCallbacks`, `ProductTerminalWidgetAssemblyHost`, `TerminalWidgetCompositionAssembly.compose`, `WidgetAssembly.assemble` invariants
- out-of-scope unchanged: no tabs UI, no second active slot, no new enum values

### `APX7-M2` Choke-point seam introduction (`completed`)

Queue line (exact):

- introduce declared-slot value choke-point conversion API with ownership-first naming

Acceptance:

- conversion seam exists on declared-slot value path
- no compatibility/fallback paths
- compile debug + release Java after code changes

Outcome:

- `ProductHostDeclaredTerminalWidgetSlot#terminalWidgetSlotForProductHarness()` is the sole public conversion to `TerminalWidgetSlotId` from the declared-slot value seam

### `APX7-M3` Consumer rewiring (`completed`)

Queue line (exact):

- rewire startup consumers through choke-point conversion API without behavior change

Acceptance:

- current behavior unchanged
- reduced direct `.terminalWidgetSlot()` fan-out in startup callsites
- compile debug + release Java after code changes

Outcome:

- startup paths call `terminalWidgetSlotForProductHarness()`; `InteractionAssembly.Host` / `WidgetAssembly.Host` still expose `terminalWidgetSlot()` implemented via that choke point

### `APX7-M4` Contract docs lock (`completed`)

Queue line (exact):

- lock authority docs to APX-B7 conversion choke-point ownership shape

Acceptance:

- host structure and naming contract match code shape
- userland contract updated only if ownership text requires it

Outcome:

- `ANDROID_JAVA_HOST_STRUCTURE.md` and `ANDROID_JAVA_NAMING_CONTRACT.md` updated for `terminalWidgetSlotForProductHarness()` ownership; userland contract had no slot-conversion text to change

### `APX7-M5` Queue/handoff/entrypoint sync (`completed`)

Queue line (exact):

- keep queue, handoff, and engineer entrypoint aligned to APX-B7 execution and super-gate stop

Acceptance:

- queue, handoff, and engineer entrypoint stay coherent through APX-B7 super-gate
- super-gate stop condition and review packet contract are explicit

Outcome:

- summary line, this batch header, and handoff/entrypoint files aligned to super-gate packet

### `APX7-M6` Batch validation + review packet (`completed`)

Queue line (exact):

- validate APX-B7 end-to-end and publish the architect review packet

Acceptance:

- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass, or exact device-blocker output is recorded
- cold start smoke pass when a device is available
- engineer reports full super-gate packet and explicit residual-risk note

Engineer validation (this batch):

- `./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac` — pass
- `./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac` — pass
- `python3 ops/android_terminal_host.py deploy` — pass
- `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E` — pass (no `E` lines)
- `adb shell am force-stop uk.laurencegouws.zide && adb shell am start -W -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity` — pass (`LaunchState: COLD`, `Status: ok`)

**Residual risk:** Low — PRIMARY-only; `WidgetAssembly` host vs context invariants unchanged; `Host#terminalWidgetSlot()` remains the adapter surface over the value-type choke.

**Review chunk:** `APX-B7`

**Commits (oldest → newest):** `c59a8a70`, `42b79b52`, `0c861bb2`, `1852ab84`, `dffe78c3`, `486ce1db`, `ed4cbf57`

`Milestone reached per docs, architect review required.`

Architect review verdict:

- `Review chunk: APX-B7`
- `Verdict: accepted`
- `Commits reviewed: c59a8a70, 42b79b52, 0c861bb2, 1852ab84, dffe78c3, 486ce1db, ed4cbf57`
- `Architect validation spot-check: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass)`
- `Architect runtime validation spot-check: python3 ops/android_terminal_host.py deploy (pass); adb warm start + AndroidRuntime:E (pass, empty); adb cold start (pass, LaunchState: COLD)`
- `Engineer device validation accepted: compile + deploy + AndroidRuntime:E smoke + cold start pass`
- `Review answers: yes, split is right long-term boundary — value type choke (`terminalWidgetSlotForProductHarness`) + Host adapter enum surface is acceptable. No mandatory rename before acceptance.`
- `Findings carried forward: no blocking regressions; startup behavior and PRIMARY-only runtime unchanged.`

### `APX-B8` Tab-State Expansion Vertical Slice 1 (`in_progress`)

Batch queue line (exact):

- implement first real Android tab-state expansion slice through app-shell policy/state seams (feature-first), using cleanup only when directly required by feature delivery

Batch purpose:

- move from seam prediction to real product pressure for tab-state expansion
- deliver concrete multi-tab state behavior on Android harness path
- surface real-world seam needs before further cleanup-only shaping
- run this as a longer engineer iteration: target **5–10 commits** before architect super-gate review

Batch scope:

- Java Android terminal host plus minimal zide-pm integration touches needed for Android test-binary pull path
- primary code roots:
  `android/terminal-host/app/src/main/java/uk/laurencegouws/terminal/**`
  `ops/**` (only if required for Android test-binary pull flow)
- allowed docs:
  `docs/todo/android/implementation.md`,
  `docs/todo/android/ENGINEER_ENTRYPOINT.md`,
  `docs/AGENT_HANDOFF.md`,
  `app_architecture/platform/android/ANDROID_JAVA_HOST_STRUCTURE.md`,
  `app_architecture/platform/android/ANDROID_JAVA_NAMING_CONTRACT.md`,
  `app_architecture/platform/android/USERLAND_HOST_CONTRACT.md`

Batch non-goals:

- no broad cleanup-only refactor that is not required by tab-state feature flow
- no terminal-core/shared-renderer refactor
- no startup-order changes unless directly required by feature and explicitly documented

Batch super-gate:

- first tab-state expansion slice is working on Android app-shell seams (state + selection/activation path)
- behavior is validated on device with no Android runtime errors
- any cleanup done in this batch is directly tied to feature-blocker removal
- docs reflect the implemented feature seam shape and residual risk
- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass at final seam boundary

Internal milestone cadence:

- Engineer executes `APX8-M1` through `APX8-M6` sequentially.
- Engineer should keep cutting coherent validated commits across those milestones
  and target **5–10 commits total** before stopping at `APX-B8` super-gate.
- Do not stop for architect review between internal milestones.
- Mark each internal milestone complete in this file as it lands.
- Stop only if the hard stop conditions in `ENGINEER_ENTRYPOINT.md` are hit or
  the `APX-B8` super-gate is reached.

### `APX8-M1` Feature-slice audit (`completed`)

Queue line (exact):

- audit current app-shell tab-related state/selection seams and define the minimum working vertical slice for tab-state expansion

Acceptance:

- define concrete feature behavior for slice 1 (create/select/close semantics or explicit subset)
- enumerate required seam changes vs optional cleanup
- record cleanup items that are blocker-only for this slice

Outcome:

- **Seams audited:** `AppShellNavigation` (active shell view + drawer), `AppShellTerminalViewPolicy` (activation + drawer forwarding), `AppShellViewState` (per-view row shape), `ProductTerminalSlotShellMapping` + `TerminalWidgetSlotId.checkActiveProductTerminalSlot` (still single active widget slot = `PRIMARY`), `WidgetAssembly` chrome construction, `ChromeBridge` / `ChromeController` (assist bar + sidebar), `ShellViewId` (single `TERMINAL` today).
- **Slice 1 behavior (minimum vertical):** harness-owned **product terminal tab strip** with **two selectable tabs**; selection state lives in `AppShellNavigation` (indices `0..tabCount-1`); taps update selection + chrome styling + telemetry; **no second terminal widget instance** and **no new `TerminalWidgetSlotId` values** in this slice — multi-session hosting remains future work.
- **Required code:** extend `AppShellNavigation` + policy for tab indices; add tab strip to `activity_main.xml`; wire `ChromeController` + `WidgetAssembly.Host` / `ActivityViewBindings` for buttons.
- **Blocker-only cleanup:** none identified beyond wiring required for the strip.
- **zide-pm slice:** signal Android host platform to `zide-pm` via process environment from `UserlandCommandRunner` so catalog/list paths can target Android test binaries without a second CLI surface.

### `APX8-M2` Tab-state model + policy cut (`completed`)

Queue line (exact):

- implement minimum tab-state model/policy changes for slice 1 in app-shell seams

Acceptance:

- feature-bearing code landed (not docs-only seam prep)
- compile debug + release Java after code changes

Outcome:

- `AppShellNavigation`: fixed `PRODUCT_TERMINAL_TAB_COUNT`, `selectedProductTerminalTabIndex`, `applySelectProductTerminalTab`
- `AppShellTerminalViewPolicy`: forwards tab count / selection / apply

### `APX8-M3` Consumer wiring + device behavior (`completed`)

Queue line (exact):

- wire tab-state slice through startup/interaction/chrome-app-shell consumers and verify behavior on device

Acceptance:

- expected slice behavior observable on device
- no `AndroidRuntime:E` regressions
- compile debug + release Java after code changes

Outcome:

- `activity_main.xml`: product terminal tab strip (`Session 1` / `Session 2`) above assist bar
- `ChromeController` + `ChromeBridge`: bind taps → `AppShellTerminalViewPolicy#applySelectProductTerminalTab`, selection styling + `app_shell.product_terminal_tab.select` telemetry

### `APX8-M4` zide-pm Android test-binary path cut (`completed`)

Queue line (exact):

- land the minimum zide-pm Android-side path needed to start pulling real test binaries beyond nvim/htop (scope-limited to this slice)

Acceptance:

- concrete, runnable Android test-binary pull path improvement landed
- scoped to feature need; no unrelated tooling cleanup

Outcome:

- `UserlandCommandRunner.runZidePm`: sets `ZIDE_PM_HOST_PLATFORM=android` for every `zide-pm` process so catalog/list/install logic inside `zide-pm` can target Android test binaries without changing the Java call shape (`doctor` / `list-available` unchanged).

### `APX8-M5` Docs + handoff sync (`pending`)

Queue line (exact):

- update authority/queue/handoff/entrypoint to match implemented feature slice and residual blockers

Acceptance:

- queue, handoff, and engineer entrypoint coherent through APX-B8 super-gate
- authority docs reflect real implemented feature shape

### `APX8-M6` Batch validation + review packet (`pending`)

Queue line (exact):

- validate APX-B8 end-to-end and publish architect review packet with feature outcomes and remaining blockers

Acceptance:

- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass, or exact device-blocker output is recorded
- cold start smoke pass when a device is available
- engineer reports full super-gate packet and explicit feature status vs APX completion objectives

## Guardrails

- No CI/pipeline/lint ceremony additions.
- No reintroduction of debug-view UI pathways.
- No compatibility shim kept only for migration convenience.
- Do not keep dual ownership if one side is clearly obsolete.

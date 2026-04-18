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
- `APX-B3` is `in_progress`.

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

### `APX-B3` Slot selection context consolidation (`in_progress`)

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

### `APX3-M1` Selection context audit (`pending`)

Queue line (exact):

- audit declared-slot and selected-slot reads and define one bounded selection-context seam target

Acceptance:

- enumerate current reads in `ZideActivity`, `WidgetAssembly`, and selection policy callers
- define one owner type under `host/ui` for startup selection context
- record explicit out-of-scope items (tabs UI, second active slot behavior)

### `APX3-M2` Selection context seam introduction (`pending`)

Queue line (exact):

- introduce a startup selection-context owner that carries declared-slot and selected-slot values

Acceptance:

- add selection-context owner surface under `host/ui`
- no compatibility/fallback paths
- compile debug + release Java after code changes

### `APX3-M3` Consumer rewiring (`pending`)

Queue line (exact):

- rewire activity and assembly startup callsites to consume the selection context once per startup path

Acceptance:

- current behavior unchanged
- no repeated ad hoc selected-slot reads in rewired startup callsites
- compile debug + release Java after code changes

### `APX3-M4` Contract docs lock (`pending`)

Queue line (exact):

- lock authority docs to APX-B3 selection-context ownership shape

Acceptance:

- host structure and naming contract match code shape
- userland contract updated only if ownership text requires it

### `APX3-M5` Queue/handoff/entrypoint sync (`pending`)

Queue line (exact):

- keep queue, handoff, and engineer entrypoint aligned to APX-B3 execution and super-gate stop

Acceptance:

- queue, handoff, and engineer entrypoint stay coherent through APX-B3 super-gate
- super-gate stop condition and review packet contract are explicit

### `APX3-M6` Batch validation + review packet (`pending`)

Queue line (exact):

- validate APX-B3 end-to-end and publish the architect review packet

Acceptance:

- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass, or exact device-blocker output is recorded
- cold start smoke pass when a device is available
- engineer reports full super-gate packet and explicit residual-risk note

## Guardrails

- No CI/pipeline/lint ceremony additions.
- No reintroduction of debug-view UI pathways.
- No compatibility shim kept only for migration convenience.
- Do not keep dual ownership if one side is clearly obsolete.

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
- **Active campaign:** **Android harness/widget portability hardening** (`AHW`)
  — make the refocus vision enforceable in code: Android Harness owns
  platform/app-shell/userland ceremony, Terminal Widget owns portable terminal
  interaction/runtime seams, and future IDE/editor modes are not trapped behind
  Activity-backed coupling.

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
- `AHW-B1` through `AHW-B22` accepted by architect.
- Keep-screen-on seam work beyond `AHW-B20` is frozen by product direction.
- `AHW-B23` is `in_progress`.

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
- AHW macro batches `AHW-B1` through `AHW-B22` accepted by architect.
- Keep-screen-on follow-up beyond `AHW-B20` frozen by product direction.

Last accepted architect gate:

- `Review chunk: AHW-B22`
- `Verdict: accepted`
- `Commits reviewed: 311e0c41, 81f23781, 8eef1568, 70b42312`
- `Architect validation: compileDebug/compileRelease/deploy/cold-start/AndroidRuntime:E (pass)`

`Milestone reached per docs, architect review required.`

---

### `AHW-B23` Refocus-Shape Landing Prep: OnCreate Sequence Ownership (`in_progress`)

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

### `AHW23-M1` OnCreate sequence pressure audit (`pending`)

Queue line (exact):

- audit runOnCreateStartupSequence dependencies and define coordinator extraction boundaries

Acceptance:

- enumerate which step calls are pure sequence choreography vs ownership-bearing logic
- define coordinator inputs/outputs and state handoff boundaries
- record invariants with explicit ordered call list and out-of-scope seams

### `AHW23-M2` Coordinator seam introduction (`pending`)

Queue line (exact):

- introduce a named host/ui startup coordinator seam for onCreate sequence execution

Acceptance:

- add coordinator type(s) with explicit ownership naming under `host/ui`
- represent required mutable state via typed inputs rather than widening activity globals
- compile debug + release Java after code changes

### `AHW23-M3` Activity delegation rewiring (`pending`)

Queue line (exact):

- delegate runOnCreate startup sequence from ZideActivity to the extracted coordinator without order changes

Acceptance:

- activity no longer owns step-order choreography details
- startup order and side-effect timing remain unchanged
- compile debug + release Java after code changes

### `AHW23-M4` Contract docs lock (`pending`)

Queue line (exact):

- lock authority docs to coordinator-owned onCreate sequence orchestration shape

Acceptance:

- host structure and naming contract match code shape
- userland contract remains unchanged unless ownership text requires update

### `AHW23-M5` Queue/handoff/entrypoint sync (`pending`)

Queue line (exact):

- keep queue, handoff, and engineer entrypoint aligned to AHW-B23 execution and super-gate stop

Acceptance:

- queue, handoff, and engineer entrypoint stay coherent through B23 super-gate
- super-gate stop condition and review packet contract are explicit

### `AHW23-M6` Batch validation + review packet (`pending`)

Queue line (exact):

- validate AHW-B23 end-to-end and publish the architect review packet

Acceptance:

- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass, or exact device-blocker output is recorded
- cold start smoke pass when a device is available
- engineer reports the full super-gate packet and stops for Architect review

## Guardrails

- No CI/pipeline/lint ceremony additions.
- No reintroduction of debug-view UI pathways.
- No compatibility shim kept only for migration convenience.
- Do not keep dual ownership if one side is clearly obsolete.

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
- Completed batch: `RF-M3` + `RF-M4` (macro gate: `RF-M4` architect review).
- Completed campaign close gate: `RF-M5`.
- Completed batch: `AX-M1` + `AX-M2` (architect review at `AX-M2` super-gate).
- Completed milestone: `AX-M3` (stabilization matrix refresh; manual validation + docs only).
- Completed milestone: `AX-M4` (manual interactive matrix completion).
- Completed milestone: `AX-M5` (next campaign declaration; docs published).
- Escalated campaign: **Android stabilization follow-through** (`ASF`).
- Completed milestone: `ASF-M1` (operator matrix closure — IME + gesture rows).
- Completed milestone: `ASF-M2` (operator evidence ingest + matrix verdict closure).
- Completed milestone: `ASF-M3` (campaign escalated to operator evidence; engineering lane refocused).
- Active campaign: **Android harness/widget portability hardening** (`AHW`).
- Completed macro batch: `AHW-B1` (accepted by Architect; follow-up seams queued in `AHW-B2`).
- Completed macro batch: `AHW-B2` (accepted by Architect; package/status and widget-instance follow-ups queued in `AHW-B3`).
- Completed macro batch: `AHW-B3` (accepted by Architect; composition seam follow-up queued in `AHW-B4`).
- Completed macro batch: `AHW-B4` (accepted by Architect; host API slimming follow-up queued in `AHW-B5`).
- Completed macro batch: `AHW-B5` (accepted by Architect; slot-scoped host API follow-up queued in `AHW-B6`).
- Completed macro batch: `AHW-B6` (accepted by Architect; slot single-source and status-result slimming follow-up queued in `AHW-B7`).
- Completed macro batch: `AHW-B7` (accepted by Architect; slot seam contract hardening follow-up queued in `AHW-B8`).
- Completed macro batch: `AHW-B8` (accepted by Architect; slot/app-shell contract alignment follow-up queued in `AHW-B9`).
- Engineer delivery complete; Architect verdict pending: `AHW-B9` (slot-aware app-shell contract alignment, no tab behavior). No macro batch is `in_progress` until Architect refocuses the queue.

### `RF-M0` Doc Reset (`completed`)

Queue line (exact):

- archive stale Android task logs and rebuild active docs around refocus case study

Exit gate:

- active docs lean and aligned to one strategy

---

### `RF-M0.5` Dual-Mode Preflight Baseline (`completed`)

Queue line (exact):

- classify mixed tree into clean buckets and create a dual-mode start baseline

Scope:

- preflight only; no new behavior work

Current triage buckets:

1. `orchestrator/docs`

- `AGENTS.md`
- `docs/WORKFLOW.md`
- `docs/AGENT_HANDOFF.md`
- `docs/todo/android/implementation.md`
- `app_architecture/platform/android/ANDROID_REFOCUS_CASE_STUDY.md`
- `app_architecture/platform/android/ANDROID_JAVA_HOST_STRUCTURE.md`
- `app_architecture/platform/android/ANDROID_JAVA_NAMING_CONTRACT.md`
- `docs/review/ANDROID_LANE_HISTORY_2026-04-17.md`

2. `android realign code`

- `android/terminal-host/app/src/main/java/uk/laurencegouws/terminal/**`
- `android/terminal-host/app/src/main/res/layout/activity_main.xml`
- `android/terminal-host/app/src/main/res/values/strings.xml`

3. `everything else`

- `refocus_android.txt` (source artifact; keep out of day-ticket execution)

Exact checkpoint commit sequence:

1. docs-only checkpoint commit (`orchestrator/docs` bucket only)
2. compile + deploy + `AndroidRuntime:E` smoke on current realign code bucket
3. code checkpoint commit (`android realign code` bucket)
4. leave source artifact uncommitted or move to historical location by explicit decision
5. mark handoff milestone to `RF-M1` only after both checkpoints are green

Gate:

- two clean checkpoints exist (docs + code), each reviewable
- queue ownership is unambiguous for dual-mode day tickets
- baseline ready for engineer execution loop (`#DONE/#OUTSTANDING/COMMITS`)

Checkpoint notes:

- docs checkpoint committed
- Android realign code checkpoint committed
- compile + deploy + runtime smoke validated

Stop marker:

`Milestone reached per docs, architect review required.`

---

### `RF-M1` Harness Boundary Lock (`completed`)

Queue line (exact):

- finish harness-side contract hardening so activity/app-shell/userland orchestration owns platform ceremony only

Scope:

- harness contracts and seams only
- no widget behavior expansion

Tasks:

- [x] finalize harness callback surfaces to semantic actions (no status-label choreography)
- [x] remove remaining harness glue that leaks widget/runtime policy language
- [x] ensure package-doctor/install orchestration reports through harness telemetry seam

Gate:

- harness seams express intent as typed semantic actions
- compile + deploy + runtime smoke clean

Progress checkpoint:

- `Milestone: RF-M1 review_required`
- `Queue line (exact): finish harness-side contract hardening so activity/app-shell/userland orchestration owns platform ceremony only`
- `Scope contract: harness contract seams only; widget/runtime behavior unchanged`
- `Progress delta: workflow/runtime/widget/session callback seams now encode semantic harness actions, removed status-label choreography relays, and package-doctor/install outcomes are emitted via harness telemetry seam without debug-view coupling`
- `Validation: ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass); python3 ops/android_terminal_host.py deploy (pass); adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E (pass)`
- `Blocked by Archtect review needed: false`

`Milestone reached per docs, architect review required.`

---

### `RF-M2` Widget Boundary Lock (`completed`)

Queue line (exact):

- ensure terminal widget owns input/selection/gesture/surface lifecycle without app-shell/userland assumptions

Scope:

- widget/runtimesurface input seams only
- no harness navigation/theming changes

Tasks:

- [x] verify widget-facing contracts do not include harness navigation/userland state semantics
- [x] remove residual app-shell language from widget callback interfaces
- [x] confirm widget can be hosted by harness contract without hidden globals

Gate:

- widget contracts are harness-consumer-only
- compile + deploy + runtime smoke clean

Progress checkpoint:

- `Milestone: RF-M2 review_required`
- `Queue line (exact): ensure terminal widget owns input/selection/gesture/surface lifecycle without app-shell/userland assumptions`
- `Scope contract: widget assembly + surface widget seams only; behavior-neutral contract renames and intent-only shell-state callbacks`
- `Progress delta: surface shell-state callbacks no longer carry status-label payloads; WidgetAssembly.Host uses drawerSidebar/session install+readiness/requestPackageDiagnostics naming; removed unused refreshUserlandSession from widget host; assembly consumes only Host (no static widget globals)`
- `Validation: ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass); python3 ops/android_terminal_host.py deploy (pass); adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E (pass)`
- `Blocked by Archtect review needed: false`

`Milestone reached per docs, architect review required.`

---

### `RF-M3` Userland Mobility Lock (`completed_in_batch`)

Queue line (exact):

- make userland orchestration movable and widget-agnostic

Scope:

- `host/userland` + `userland/*` seams only

Tasks:

- [x] isolate package-doctor/install/restart orchestration behind harness-owned entrypoints
- [x] remove any userland dependency on widget-specific runtime symbols
- [x] document stable userland contract for future IDE/editor modes

Gate:

- userland orchestration has no widget-only ownership assumptions
- compile + deploy + runtime smoke clean

Progress checkpoint:

- `Milestone: RF-M3 completed_in_batch`
- `Queue line (exact): make userland orchestration movable and widget-agnostic`
- `Scope contract: host.userland + userland packages; readiness-blocker wiring moved to ReadinessBlockerStartup; UserlandReadinessBlockerController.Host uses harness entrypoints only (no workflow/session coordinator types on userland Host)`
- `Progress delta: USERLAND_HOST_CONTRACT.md added; WorkflowBridge documents harness contract; install/session orchestration for readiness retry bound via host.userland startup; userland Host no longer exposes UserlandWorkflowController/UserlandSessionCoordinator to UserlandReadinessBlockerController`
- `Validation: ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass); python3 ops/android_terminal_host.py deploy (pass); adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E (pass)`
- `Blocked by Archtect review needed: false`
- `Batching note: RF-M3 is complete but review is deferred to RF-M4 macro gate.`

---

### `RF-M4` AppShell Navigation + State Backbone (`review_required`)

Queue line (exact):

- harden app-shell left sidebar/navigation/view-state ownership for multi-view and future terminal tabs

Scope:

- harness app-shell only

Tasks:

- [x] define explicit app-shell view navigation state owner
- [x] define per-view state owner seam (tab-ready shape)
- [x] enforce theming propagation contract across app shell

Gate:

- app-shell navigation/state ownership explicit and centralized
- compile + deploy + runtime clean

Progress checkpoint:

- `Milestone: RF-M4 completed`
- `Queue line (exact): harden app-shell left sidebar/navigation/view-state ownership for multi-view and future terminal tabs`
- `Scope contract: harness app-shell only; navigation + per-view seam + resource-level theming`
- `Progress delta: AppShellNavigation owns drawer + active ShellViewId; AppShellViewState + ShellViewId provide tab-ready seam; ViewModeController records PRODUCT_TERMINAL on apply; app-shell colors centralized in values/colors.xml and referenced from activity_main`
- `Validation: (see engineer VALIDATION block)`
- `Blocked by Archtect review needed: false` (macro gate approved; RF-M5 executed)

`Milestone reached per docs, architect review required.`

---

### `RF-M5` Stabilization Matrix (`completed`)

Queue line (exact):

- execute stability matrix and close refocus campaign with review gate

Scope:

- manual validation only, no opportunistic refactors

Tasks:

- [x] lifecycle matrix: create/start/resume/pause/stop/new-intent (recorded; pause/stop/new-intent marked not run — spot-check)
- [x] input matrix: IME + hardware keyboard + selection gestures (recorded; device-interactive rows not run)
- [x] userland matrix: readiness/install/update/package-doctor/restart (recorded; smoke + manual follow-ups noted)
- [x] surface matrix: surface create/change/destroy/redraw/viewport updates (recorded; smoke + manual follow-ups noted)

Gate:

- matrix recorded with pass/fail and follow-up deltas — see `docs/todo/android/RF_M5_STABILIZATION_MATRIX.md`
- milestone marked `completed`

Progress checkpoint:

- `Milestone: RF-M5 completed`
- `Queue line (exact): execute stability matrix and close refocus campaign with review gate`
- `Scope contract: manual validation + documentation; first commit: app_shell_hotspot_bg theming fix`
- `Progress delta: transparent edge hotspot uses @color/app_shell_hotspot_bg; matrix tables + smoke commands recorded in RF_M5_STABILIZATION_MATRIX.md`
- `Validation: ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass); python3 ops/android_terminal_host.py deploy (pass); adb logcat smoke + cold start (pass)`
- `Blocked by Archtect review needed: false` (campaign close complete; AX-M1+AX-M2 batch later recorded below)

`Milestone reached per docs, architect review required.`

---

### `AX-M1` Input Path Correctness + Perf Hardening (`completed`)

Queue line (exact):

- harden Android input path correctness under strict compile gates without adding compatibility seams

Scope:

- `input/*`, `host/input/*`, `host/ui/ViewModeController`, `host/ui/WidgetAssembly`,
  and directly connected activity wiring only
- no userland/install orchestration expansion

Tasks:

- [x] validate and tighten IME commit/delete/composition/cursor flow behavior in `ShellInputView` seam
- [x] validate hardware keyboard path and modifier handling against current runtime contracts
- [x] remove input-lane warning debt surfaced by strict `javac -Xlint:all -Werror`

Gate:

- no input-lane warning regressions under strict compile
- debug + release compile, deploy, runtime smoke, and cold start clean

Progress checkpoint:

- `Milestone: AX-M1 completed`
- `Queue line (exact): harden Android input path correctness under strict compile gates without adding compatibility seams`
- `Scope contract: ShellInputView + ViewModeController product-view path; no userland expansion`
- `Progress delta: ExtractedText now fills partial offsets + flags for IME contract; hardware path handles legacy ACTION_MULTIPLE batched characters (deprecation suppressed locally); ViewModeController coalesces product-view viewport notify + scroll-overlay refresh into one Handler post (perf, behavior-neutral order)`
- `Validation: (see engineer VALIDATION block)`
- `Blocked by Archtect review needed: false` (macro gate at AX-M2)

---

### `AX-M2` Surface/Render Correctness + Perf Hardening (`completed`)

Queue line (exact):

- harden surface/render handoff correctness and remove avoidable redraw/viewport churn in Android host seams

Scope:

- `host/surface/*`, `host/ui/Viewport*`, `host/runtime/FrameLoop*`, and wiring points only
- no terminal-core behavior migration

Tasks:

- [x] verify surface lifecycle transitions (create/change/destroy/resume/pause) for correctness invariants
- [x] reduce avoidable redraw/viewport churn in host-side handoff where measurable
- [x] keep contracts harness-owned with no compatibility relays

Gate:

- compile + deploy + runtime smoke + cold start clean
- batch summary includes before/after measurable signal for churn reduction
- architect review required at this gate (macro batch super-gate)

Progress checkpoint:

- `Milestone: AX-M2 completed`
- `Queue line (exact): harden surface/render handoff correctness and remove avoidable redraw/viewport churn in Android host seams`
- `Scope contract: SurfaceController viewport notify path; no new compatibility relays`
- `Progress delta: notifyVisibleViewport skips redundant bridge writes + native/scroll work when width/height/IME match last notified (dedupe was already native-side; now avoids redundant setVisibleViewportSize before the triple-match early return)`
- `Validation: (see engineer VALIDATION block)`
- `Blocked by Archtect review needed: false` (super-gate: architect review required per batch policy)

`Milestone reached per docs, architect review required.`

---

### `AX-M3` Post-Hardening Stabilization Matrix Refresh (`completed`)

Queue line (exact):

- rerun stabilization matrix for input/surface lifecycle after AX hardening batch

Scope:

- manual validation + docs refresh only

Tasks:

- [x] refresh `docs/todo/android/RF_M5_STABILIZATION_MATRIX.md` with AX batch outcomes
- [x] record any remaining manual interactive gaps as explicit follow-up rows

Gate:

- matrix refreshed with dated results and follow-up deltas

Progress checkpoint:

- `Milestone: AX-M3 completed`
- `Queue line (exact): rerun stabilization matrix for input/surface lifecycle after AX hardening batch`
- `Scope contract: docs-only matrix refresh; smoke commands recorded in RF_M5_STABILIZATION_MATRIX.md`
- `Progress delta: added AX-M3 smoke baseline + AX code deltas per lane; interactive matrix rows explicitly still not run (device/operator follow-ups unchanged)`
- `Validation: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass); python3 ops/android_terminal_host.py deploy (pass); adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E (pass); adb shell am force-stop uk.laurencegouws.zide && adb shell am start -W -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity (pass)`
- `Blocked by Archtect review needed: true`

`Milestone reached per docs, architect review required.`

---

### `AX-M4` Manual Interactive Matrix Completion (`completed`)

Queue line (exact):

- execute remaining device-interactive lifecycle/input/surface matrix rows and record exact outcomes

Scope:

- manual validation + docs only
- no opportunistic code changes unless a verified regression is found

Tasks:

- [x] lifecycle rows: `onPause/onStop/onNewIntent` device checks
- [x] input rows: IME show/hide, hardware keyboard, selection/gesture checks
- [x] surface rows: resize/viewport and destroy/teardown checks
- [x] update `docs/todo/android/RF_M5_STABILIZATION_MATRIX.md` with exact pass/fail outcomes and dated notes

Gate:

- previously `not run` interactive rows are either executed or explicitly marked with blocker reason and owner
- queue checkpoint includes exact device/command evidence
- architect review required at gate

Progress checkpoint:

- `Milestone: AX-M4 completed`
- `Queue line (exact): execute remaining device-interactive lifecycle/input/surface matrix rows and record exact outcomes`
- `Scope contract: manual validation + docs only; no code changes (none required; no regression observed)`
- `Progress delta: RF_M5_STABILIZATION_MATRIX.md updated with AX-M4 smoke baseline (exact stdout fragments), adb-backed lifecycle/surface rows, adb hardware key spot-check; IME assist + touch gesture rows marked not run with blocker owner operator`
- `Validation: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass); python3 ops/android_terminal_host.py deploy (pass); adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E (pass); adb shell am force-stop uk.laurencegouws.zide && adb shell am start -W -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity (pass)`
- `Blocked by Archtect review needed: true`

`Milestone reached per docs, architect review required.`

---

### `AX-M5` Next Campaign Declaration (`completed`)

Queue line (exact):

- define and publish the next Android campaign after AX matrix completion

Scope:

- docs only (`docs/AGENT_HANDOFF.md` + `docs/todo/android/implementation.md` + any new owning authority doc)

Tasks:

- [x] declare next campaign name, goal, and first milestone
- [x] provide engineer entrypoint prompt for first batch of next campaign

Gate:

- handoff and queue both point to the same next campaign + active milestone

Progress checkpoint:

- `Milestone: AX-M5 completed`
- `Queue line (exact): define and publish the next Android campaign after AX matrix completion`
- `Scope contract: docs-only declaration; no code changes`
- `Progress delta: published campaign Android stabilization follow-through (ASF); first milestone ASF-M1; ENGINEER_ENTRYPOINT.md carries ASF-M1 dual-mode prompt; handoff + queue aligned`
- `Validation: N/A (docs-only milestone)`
- `Blocked by Archtect review needed: true`

`Milestone reached per docs, architect review required.`

---

### `ASF-M1` Operator matrix closure — IME + gesture rows (`completed`)

Queue line (exact):

- publish operator runbook steps and dated matrix outcomes for IME/assist and touch gesture blocker rows, or record cannot-verify with reason

Scope:

- docs + matrix updates only unless a verified regression forces a minimal code fix
- owning doc for procedures: `docs/todo/android/RF_M5_STABILIZATION_MATRIX.md` (extend with operator section) unless architect splits a dedicated file later

Tasks:

- [x] author reproducible on-device steps for IME show/hide + assist row (aligned with `ZideActivity` / chrome seams)
- [x] author reproducible on-device steps for selection overlay + at least one gesture path (e.g. scroll overlay / pinch) at operator discretion
- [x] update `docs/todo/android/RF_M5_STABILIZATION_MATRIX.md` with dated pass/fail or blocked-with-reason rows
- [x] run standard Android smoke validation when any host Java changes occur (otherwise document smoke N/A for docs-only cuts)

Gate:

- matrix rows no longer list `not run — blocker` for IME and gesture without an explicit dated outcome or cannot-verify note
- architect review at `ASF-M1` gate

Progress checkpoint:

- `Milestone: ASF-M1 completed`
- `Queue line (exact): publish operator runbook steps and dated matrix outcomes for IME/assist and touch gesture blocker rows, or record cannot-verify with reason`
- `Scope contract: docs + RF_M5_STABILIZATION_MATRIX.md only; no code changes`
- `Progress delta: added ASF-M1 operator runbook §A/§B; input matrix rows set to cannot-verify (2026-04-17) with owner operator + ASF-M1 smoke baseline; gate satisfied (no remaining not-run blocker rows for IME/gesture)`
- `Validation: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass); python3 ops/android_terminal_host.py deploy (pass); adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E (pass); adb shell am force-stop uk.laurencegouws.zide && adb shell am start -W -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity (pass)`
- `Blocked by Archtect review needed: true`

`Milestone reached per docs, architect review required.`

---

### `ASF-M2` Operator evidence ingest + matrix verdict closure (`completed`)

Queue line (exact):

- ingest operator-run results from ASF-M1 runbook and close IME/gesture matrix rows with explicit verdicts

Scope:

- docs + matrix updates only
- no Java changes unless a verified product regression is reported with reproduction

Tasks:

- [x] attempt operator evidence ingest for runbook §A and §B and record received/not-received status with date/owner
- [x] replace `cannot-verify` placeholders in IME/assist and gesture rows with explicit verdicts or blocked-with-reason + owner/date
- [x] add short verdict summary in `docs/todo/android/implementation.md` checkpoint (what is now closed vs still blocked)

Gate:

- IME/assist and gesture rows are no longer unresolved placeholders
- matrix records owner/date/verdict for each formerly cannot-verify row
- architect review required at gate

Progress checkpoint:

- `Milestone: ASF-M2 completed`
- `Queue line (exact): ingest operator-run results from ASF-M1 runbook and close IME/gesture matrix rows with explicit verdicts`
- `Scope contract: docs + matrix only; no code`
- `Verdict summary: No §A/§B operator packets ingested this session — IME/assist and gesture rows set to explicit blocked (2026-04-17), owner operator, reason documented in RF_M5_STABILIZATION_MATRIX.md ingest log. Hardware keyboard row remains pass-smoke (adb). Unblocked pass/fail awaits future operator evidence append.`
- `Validation: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass); python3 ops/android_terminal_host.py deploy (pass); adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E (pass); adb shell am force-stop uk.laurencegouws.zide && adb shell am start -W -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity (pass)`
- `Blocked by Archtect review needed: true`

`Milestone reached per docs, architect review required.`

---

### `ASF-M3` Campaign closeout or escalation (`completed`)

Queue line (exact):

- decide ASF campaign closeout status and publish next campaign entrypoint

Scope:

- docs only (`docs/AGENT_HANDOFF.md`, `docs/todo/android/implementation.md`, and optional new authority doc)

Tasks:

- [x] evaluate whether ASF-M2 closes all critical rows (it does not; operator-owned blockers remain)
- [x] if unresolved blockers remain, publish escalation milestone with owner and acceptance bar

Gate:

- handoff and queue explicitly agree on closed/ongoing status and next active milestone

Execution note:

- ASF is escalated, not product-complete: IME/assist and touch-gesture rows
  remain parked on operator evidence in `RF_M5_STABILIZATION_MATRIX.md`.
- Owner: operator.
- Acceptance bar: dated operator packet with device model, Android version,
  runbook §A/§B pass/fail notes, and any `AndroidRuntime:E` lines if present.
- Engineering lane is refocused to `AHW-B1`; do not spend more engineering
  cycles on ASF paperwork unless operator evidence arrives or a regression is
  reported inside active code scope.

Progress checkpoint:

- `Milestone: ASF-M3 completed`
- `Queue line (exact): decide ASF campaign closeout status and publish next campaign entrypoint`
- `Scope contract: architect-owned docs refocus only; no Android code`
- `Progress delta: ASF escalated remaining IME/assist + gesture evidence to operator owner; active engineering campaign refocused to AHW-B1 with macro review cadence`
- `Validation: N/A (docs-only architect refocus)`
- `Blocked by humain review needed: false`

`Milestone reached per docs, architect review required.`

---

## Active Campaign: `AHW` Android Harness/Widget Portability Hardening

Campaign purpose:

- turn `refocus_android.txt` and
  `app_architecture/platform/android/ANDROID_REFOCUS_CASE_STUDY.md` into
  enforceable code shape
- keep Android Harness as the platform/app-shell/userland canvas
- keep Terminal Widget portable and reusable outside the current Activity shell
- keep userland movable for future IDE/editor Zig modes

Architect intent:

- this is a large autonomous engineer stretch, not a per-milestone pause loop
- expected review size: 30-50 coherent commits if code reality supports that
- each commit should be small enough to review but the architect review happens
  at the macro-batch super-gate
- if a cut cannot be split without a broken tree or compatibility shim, land it
  as one atomic validated commit

### `AHW-B1` Harness backbone + widget portability macro batch (`completed`)

Batch queue line (exact):

- remove remaining Android Activity/backbone pressure from terminal widget and userland seams while preserving runtime behavior

Batch scope:

- Java Android terminal host only, plus docs needed to keep authority current
- primary code root:
  `android/terminal-host/app/src/main/java/uk/laurencegouws/terminal/**`
- allowed resource roots when needed:
  `android/terminal-host/app/src/main/res/layout/activity_main.xml`,
  `android/terminal-host/app/src/main/res/values/colors.xml`,
  `android/terminal-host/app/src/main/res/values/strings.xml`
- allowed docs:
  `docs/todo/android/implementation.md`,
  `docs/todo/android/ENGINEER_ENTRYPOINT.md`,
  `docs/AGENT_HANDOFF.md`,
  `app_architecture/platform/android/ANDROID_JAVA_HOST_STRUCTURE.md`,
  `app_architecture/platform/android/ANDROID_JAVA_NAMING_CONTRACT.md`,
  `app_architecture/platform/android/USERLAND_HOST_CONTRACT.md`

Batch non-goals:

- no terminal-core behavior changes
- no shared renderer/backend refactor unless an Android seam cannot be made
  honest without escalating to Architect
- no debug-view UI resurrection
- no CI/pipeline/lint ceremony
- no broad mechanical rename sweep outside a named internal milestone
- no ASF operator-evidence churn unless new evidence arrives

Batch super-gate:

- `ZideActivity` is materially closer to Android entrypoint/wiring only
- harness-owned app-shell/userland contracts no longer leak widget/runtime
  policy names for convenience
- widget-owned surface/input/interaction contracts no longer depend on
  app-shell/userland/navigation assumptions
- userland package remains free of widget/surface/controller dependencies
- `ANDROID_JAVA_HOST_STRUCTURE.md` and naming contract reflect the final shape
- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass at final seam boundary
- engineer reports review packet using the exact response contract

Internal milestone cadence:

- Engineer executes `AHW-M1` through `AHW-M5` sequentially.
- Do not stop for architect review between internal milestones.
- Mark each internal milestone complete in this file as it lands.
- Stop only if the hard stop conditions in `ENGINEER_ENTRYPOINT.md` are hit or
  the `AHW-B1` super-gate is reached.

### `AHW-M1` Activity backbone pressure audit + first extractions (`completed_in_batch`)

Queue line (exact):

- reduce `ZideActivity` to entrypoint and wiring by moving remaining behavior into existing owner seams

Scope:

- `ZideActivity.java`
- existing `host/**` assemblies, factories, controllers, and callback adapters
- docs updates to Java host structure only when ownership actually changes

Tasks:

- [x] audit `ZideActivity` methods for remaining behavior/policy ownership
- [x] move behavior into the current owning controller/assembly without adding
  pass-through compatibility wrappers
- [x] keep lifecycle overrides and direct Android entry callbacks delegation-only
- [x] update `ANDROID_JAVA_HOST_STRUCTURE.md` pressure notes with completed cuts

Progress checkpoint:

- `Milestone: AHW-M1 completed_in_batch`
- `Queue line (exact): reduce ZideActivity to entrypoint and wiring by moving remaining behavior into existing owner seams`
- `Scope contract: ZideActivity + host assemblies; null-safe startup forwards extracted to ProductHostDeferredActions`
- `Progress delta: ProductHostDeferredActions owns prior *IfReady forwards; lifecycle/session/workflow/widget wiring delegates through it; ZideActivity line count reduced`
- `Validation: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass); python3 ops/android_terminal_host.py deploy (pass); adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E (pass, empty); adb shell am force-stop uk.laurencegouws.zide && adb shell am start -W -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity (pass)`
- `Blocked by Archtect review needed: false`

Acceptance:

- `ZideActivity` reads as Android entrypoint + construction/wiring surface
- no moved method changes behavior
- no new duplicate controller state machine is introduced
- debug + release Java compile pass after each coherent cut

Drift:

- adding new product policy to `ZideActivity`
- creating relay classes that only rename the same coupling
- fixing unrelated widget bugs while extracting Activity behavior

### `AHW-M2` Harness app-shell + userland ownership closure (`completed_in_batch`)

Queue line (exact):

- harden Android Harness ownership of app-shell navigation, theming, view state, and userland orchestration without widget assumptions

Scope:

- `host/ui/*` app-shell/navigation/chrome/view-state seams
- `host/userland/*`
- `userland/*`
- directly connected layout/resource files

Tasks:

- [x] ensure app-shell navigation/state names stay view-oriented, not terminal-instance-oriented
- [x] keep theming propagation in harness/resource seams
- [x] ensure userland readiness/install/package-doctor flows expose semantic
  harness actions only
- [x] remove widget/surface/controller references from userland packages if any
  remain
- [x] update `USERLAND_HOST_CONTRACT.md` if entry surfaces move

Progress checkpoint:

- `Milestone: AHW-M2 completed_in_batch`
- `Queue line (exact): harden Android Harness ownership of app-shell navigation, theming, view state, and userland orchestration without widget assumptions`
- `Scope contract: verified existing harness/userland seams; no new coupling found in userland Java packages this wave`
- `Progress delta: userland packages remain free of Activity/widget/surface/controller imports; USERLAND_HOST_CONTRACT entry surfaces unchanged`
- `Validation: same compile/deploy/smoke commands as AHW-M1 checkpoint (pass)`
- `Blocked by Archtect review needed: false`

Acceptance:

- userland remains movable to future IDE/editor harnesses
- harness can host terminal as a view without becoming terminal policy owner
- `zide-pm` remains tool-like with minimal Java ceremony
- debug + release Java compile pass

Drift:

- moving terminal interaction behavior into app-shell/chrome for convenience
- adding Java package-management policy that belongs to `zide-pm`
- using terminal widget state as app-shell navigation truth

### `AHW-M3` Terminal Widget host contract shrink (`completed_in_batch`)

Queue line (exact):

- make terminal widget seams consume harness services without depending on app-shell/userland internals

Scope:

- `host/ui/WidgetAssembly.java`
- `host/surface/*`
- `host/input/*`
- `host/interaction/*`
- `input/*`, `gesture/*`, `selection/*`, `scroll/*` when directly connected

Tasks:

- [x] audit widget-facing host contracts for app-shell/userland/navigation terms
- [x] shrink callback surfaces to widget needs: surface, input, selection,
  gestures, redraw, and FFI handoff
- [x] keep IME/assist ownership explicit: chrome may trigger IME, widget owns
  terminal input behavior
- [x] keep selection and gesture ownership Android-native but terminal-truth
  backed

Progress checkpoint:

- `Milestone: AHW-M3 completed_in_batch`
- `Queue line (exact): make terminal widget seams consume harness services without depending on app-shell/userland internals`
- `Scope contract: WidgetAssembly + interaction + input assembly Host seams`
- `Progress delta: WidgetAssembly.Host, InteractionAssembly.Host, and InputAssembly.Host now use harnessContext() (Context) instead of Activity where factories already accepted Context; chrome path unchanged`
- `Validation: same compile/deploy/smoke commands as AHW-M1 checkpoint (pass)`
- `Blocked by Archtect review needed: false`

Acceptance:

- widget contracts are reusable by another harness without importing current
  app-shell/userland concepts
- no Java-side duplicate terminal text/selection model is introduced
- behavior remains stable under compile/deploy/runtime smoke

Drift:

- pulling app-shell navigation into widget code
- treating the current Activity as the widget backbone
- changing terminal selection/input semantics without a scoped ticket

### `AHW-M4` Naming and structure contract enforcement slice (`completed_in_batch`)

Queue line (exact):

- normalize only the names and structure notes required by AHW-M1 through AHW-M3

Scope:

- files already touched by `AHW-M1` through `AHW-M3`
- `ANDROID_JAVA_HOST_STRUCTURE.md`
- `ANDROID_JAVA_NAMING_CONTRACT.md`

Tasks:

- [x] remove stale names introduced by old debug/status/widget coupling
- [x] update file audit rows and pressure notes for changed ownership
- [x] keep naming changes mechanical and adjacent to already-touched seams
- [x] do not run a repo-wide rename campaign

Progress checkpoint:

- `Milestone: AHW-M4 completed_in_batch`
- `Queue line (exact): normalize only the names and structure notes required by AHW-M1 through AHW-M3`
- `Scope contract: harnessContext vocabulary + assembly Host Javadoc harness wording + structure/naming authority docs`
- `Progress delta: ANDROID_JAVA_HOST_STRUCTURE documents ProductHostDeferredActions and updated ZideActivity pressure; ANDROID_JAVA_NAMING_CONTRACT records harnessContext() rule; host assembly interface comments say Harness callbacks`
- `Validation: same compile/deploy/smoke commands as AHW-M1 checkpoint (pass)`
- `Blocked by Archtect review needed: false`

Acceptance:

- docs and code use one vocabulary for Harness, Widget, userland, and callback roles
- naming contract records any new rule that prevents future drift
- debug + release Java compile pass

Drift:

- broad rename sweeps
- behavior changes hidden inside naming commits
- introducing stacked synonyms such as redundant `Host` + `Bridge` + `Callbacks`

### `AHW-M5` Batch validation + handoff packet (`completed_in_batch`)

Queue line (exact):

- validate AHW-B1 end-to-end and publish the architect review packet

Scope:

- docs-only final checkpoint plus validation commands
- no new behavior cuts after validation starts unless fixing validation failure

Tasks:

- [x] run required validation commands
- [x] update this queue with completed internal milestone checkpoints
- [x] update handoff only if the batch is ready for Architect review or a hard
  blocker requires refocus
- [x] report final review packet with changed files, commits, validation, risks,
  and exact review questions

Progress checkpoint:

- `Milestone: AHW-M5 completed_in_batch`
- `Queue line (exact): validate AHW-B1 end-to-end and publish the architect review packet`
- `Scope contract: validation + queue checkpoint + engineer review packet (Architect receives super-gate)`
- `Progress delta: internal milestones AHW-M1 through AHW-M5 marked complete_in_batch; AHW-B1 super-gate reached for Architect review`
- `Validation: see engineer VALIDATION block in final session response`
- `Blocked by Archtect review needed: true` (super-gate)

Acceptance:

- debug compile pass
- release compile pass
- deploy pass
- `AndroidRuntime:E` smoke pass
- cold start smoke pass when device is available
- `Blocked by Archtect review needed: true` only at super-gate or real blocker

Architect review verdict:

- `Review chunk: AHW-B1`
- `Verdict: accepted`
- `Commits reviewed: 59f9c20c, bc1f4b2c, 43fd6f1b, ab9e31bf`
- `Validation spot-check: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass)`
- `Findings carried forward: InputCallbacks hides a ShellInputView.Host dependency behind a Context cast; WidgetAssembly.Host still imports userland state values for shell-state presentation; ProductHostDeferredActions is an acceptable temporary startup-forwarding seam but too broad for long-term ownership.`
- `Gate decision: AHW-B1 satisfies the first backbone-pressure cut because behavior stayed stable and ZideActivity shed direct null-guard forwarding, but the next batch must convert the remaining cosmetic portability into real portable contracts.`

`Milestone reached per docs, architect review accepted.`

---

### `AHW-B2` Portable widget contract closure + deferred-action split (`completed`)

Batch queue line (exact):

- finish the portable widget contract by removing hidden Activity/userland assumptions and splitting broad deferred forwards into owned startup seams

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

- no terminal-core or shared-renderer changes
- no behavior changes during extraction-only cuts
- no app-shell UI redesign
- no debug-view UI resurrection
- no broad rename sweep
- no ASF operator-evidence churn unless new evidence arrives

Batch super-gate:

- `InputCallbacks` does not cast `Context` to `ShellInputView.Host`; input host ownership is explicit
- `WidgetAssembly.Host` no longer imports `UserlandReadinessState` or
  `UserlandInstallState` directly unless Architect explicitly accepts a better
  documented exception
- `ProductHostStartupBundle` aggregates owner-aligned `*StartupForwards` (or
  equivalent) as startup-order glue only, not a second activity backbone
- `ZideActivity` remains wiring/entrypoint only after the split
- docs reflect the final ownership shape
- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass at final seam boundary

Internal milestone cadence:

- Engineer executes `AHW2-M1` through `AHW2-M5` sequentially.
- Do not stop for architect review between internal milestones.
- Mark each internal milestone complete in this file as it lands.
- Stop only if the hard stop conditions in `ENGINEER_ENTRYPOINT.md` are hit or
  the `AHW-B2` super-gate is reached.

### `AHW2-M1` Explicit input host contract (`completed_in_batch`)

Queue line (exact):

- remove hidden ShellInputView.Host casts from input assembly callbacks

Scope:

- `host/input/InputCallbacks.java`
- `host/input/InputAssembly.java`
- `ZideActivity.java`
- directly connected docs

Tasks:

- [x] pass `ShellInputView.Host` as an explicit constructor dependency instead of deriving it from `Context`
- [x] keep `Context` limited to Android view construction/service access
- [x] correct misleading comments that imply application context is valid where a shell input host is also required
- [x] compile debug + release after the cut

Progress checkpoint:

- `Milestone: AHW2-M1 completed_in_batch`
- `Validation: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass)`
- `Blocked by Archtect review needed: false`

Acceptance:

- no `(ShellInputView.Host) harnessContext` cast remains
- another harness can provide context and shell-input host independently
- behavior is unchanged for current `ZideActivity`

Drift:

- moving input behavior into `ZideActivity`
- changing IME/keyboard semantics while fixing the contract shape

### `AHW2-M2` Shell-state presentation snapshot boundary (`completed_in_batch`)

Queue line (exact):

- replace widget assembly userland value imports with a harness-owned shell-state snapshot seam

Scope:

- `host/ui/WidgetAssembly.java`
- `host/userland/ShellStateBridge.java`
- `host/userland/ShellStateCallbacks.java`
- `userland/ShellStatePresenter.java` only if needed for the snapshot boundary
- `USERLAND_HOST_CONTRACT.md`

Tasks:

- [x] define a small harness-owned snapshot/adapter type for shell-state presentation, or document why the existing userland values are the correct product state boundary
- [x] remove direct `UserlandReadinessState` / `UserlandInstallState` imports from `WidgetAssembly.Host` if the snapshot path is viable
- [x] keep userland package free of widget/surface/controller dependencies
- [x] compile debug + release after the cut

Progress checkpoint:

- `Milestone: AHW2-M2 completed_in_batch`
- `Progress delta: ShellPresentationHostInputs in host.userland bundles suppliers; WidgetAssembly.Host exposes shellPresentationHostInputs(); USERLAND_HOST_CONTRACT.md updated`
- `Validation: same compile gates as AHW2-M1 (pass)`
- `Blocked by Archtect review needed: false`

Acceptance:

- widget assembly no longer requires userland package types for presentation-only shell state, unless an explicit documented exception is accepted in the same wave
- shell-state behavior and readiness blocker presentation remain unchanged

Drift:

- inventing duplicate readiness/install truth
- moving userland install policy into widget/chrome code

### `AHW2-M3` Deferred action ownership split (`completed_in_batch`)

Queue line (exact):

- split ProductHostDeferredActions into owner-aligned startup-forwarding seams or narrow its documented contract

Scope:

- `host/ui/ProductHostStartupBundle.java` (replaces `ProductHostDeferredActions.java`)
- `ZideActivity.java`
- affected `host/runtime`, `host/surface`, `host/session`, `host/input`, and
  `host/userland` assembly callback construction
- `ANDROID_JAVA_HOST_STRUCTURE.md`

Tasks:

- [x] classify each deferred forward by owner domain: runtime, frame loop, surface, session/userland, input, chrome/status
- [x] split into smaller owner-aligned seams where the split reduces coupling without adding pass-through noise
- [x] if a forward must remain centralized for startup-order reasons, document why it is startup-order glue rather than product policy
- [x] compile debug + release after each coherent split

Progress checkpoint:

- `Milestone: AHW2-M3 completed_in_batch`
- `Progress delta: RuntimeStartupForwards, FrameLoopStartupForwards, SurfaceStartupForwards, UserlandSessionStartupForwards, InputChromeStartupForwards, StatusTelemetryStartupForwards, WorkflowInstallStartupGlue; ProductHostStartupBundle aggregates; ProductHostDeferredActions removed`
- `Validation: same compile gates as AHW2-M1 (pass)`
- `Blocked by Archtect review needed: false`

Acceptance:

- no single broad helper becomes the new Activity backbone
- startup null-guard behavior remains stable
- docs identify the remaining seam owner and next pressure, if any

Drift:

- reintroducing null-guard methods directly on `ZideActivity`
- creating one-method relay classes with no ownership gain
- changing startup order unless explicitly required and validated

### `AHW2-M4` Harness/widget naming cleanup for B2 seams (`completed_in_batch`)

Queue line (exact):

- normalize only naming and docs touched by AHW2-M1 through AHW2-M3

Scope:

- files touched by `AHW2-M1` through `AHW2-M3`
- `ANDROID_JAVA_HOST_STRUCTURE.md`
- `ANDROID_JAVA_NAMING_CONTRACT.md`

Tasks:

- [x] remove misleading `Activity or application context` wording where a narrower contract is required
- [x] keep `harnessContext` reserved for context-only dependencies
- [x] update file audit pressure rows for changed seams
- [x] avoid broad mechanical renames outside touched paths

Progress checkpoint:

- `Milestone: AHW2-M4 completed_in_batch`
- `Progress delta: structure + naming contracts updated for B2 seams; ENGINEER_ENTRYPOINT required-fixes section points to AHW-B2 resolution`
- `Validation: docs-only slice; compile unchanged from M3 (pass)`
- `Blocked by Archtect review needed: false`

Acceptance:

- code and docs use the same vocabulary for context, shell input host, shell-state snapshot, and deferred startup forwarding
- no behavior changes are hidden in naming/doc commits

### `AHW2-M5` Batch validation + review packet (`completed_in_batch`)

Queue line (exact):

- validate AHW-B2 end-to-end and publish the architect review packet

Scope:

- final docs checkpoint plus validation commands
- no new behavior cuts after validation starts unless fixing validation failure

Tasks:

- [x] run required validation commands
- [x] update this queue with completed internal milestone checkpoints
- [x] update handoff only if the batch is ready for Architect review or a hard blocker requires refocus
- [x] report final review packet with changed files, commits, validation, risks, and exact review questions

Progress checkpoint:

- `Milestone: AHW2-M5 completed_in_batch`
- `Progress delta: AHW-B2 super-gate; engineer review packet in session response`
- `Validation: see VALIDATION block in engineer response`
- `Blocked by Archtect review needed: true` (super-gate)

Acceptance:

- debug compile pass
- release compile pass
- deploy pass when device is available
- `AndroidRuntime:E` smoke pass when device is available
- cold start smoke pass when device is available
- `Blocked by Archtect review needed: true` only at super-gate or real blocker

Architect review verdict:

- `Review chunk: AHW-B2`
- `Verdict: accepted`
- `Commits reviewed: 99d3c5f2, 4ec8c59e, af938a01`
- `Validation spot-check: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass)`
- `Engineer validation accepted: deploy, cold start, and AndroidRuntime:E smoke passed on device RF8M74JDWEK`
- `Findings carried forward: StatusTelemetryStartupForwards should move under status ownership if the next batch touches status/package placement; ProductHostStartupBundle is acceptable as startup-only aggregation and should not be collapsed further without a concrete ownership gain; InteractionCallbacks context naming can wait until a real multi-host/terminal-widget instance cut makes it material.`
- `Gate decision: AHW-B2 closes the three AHW-B1 corrective contracts: explicit ShellInputView.Host, shell presentation input seam, and owner-aligned startup forwarders.`

`Milestone reached per docs, architect review accepted.`

---

### `AHW-B3` Terminal widget instance boundary + host package hygiene (`completed`)

Batch queue line (exact):

- make one terminal widget instance explicit in harness wiring and clean remaining host package ownership drift without changing terminal behavior

Batch purpose:

- continue the refocus vision from “Activity is no longer the backbone” toward
  “the harness can host one or more terminal widget instances”
- prepare future terminal tabs by making the current single widget instance
  explicit and reviewable
- clean status/package placement exposed by `AHW-B2` without starting a broad
  rename campaign

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
- no terminal-core or shared-renderer changes
- no selection/IME/gesture behavior changes except compile-preserving seam rewiring
- no app-shell UI redesign
- no debug-view UI resurrection
- no broad rename sweep
- no ASF operator-evidence churn unless new evidence arrives

Batch super-gate:

- current single terminal widget instance has an explicit harness-owned instance/slot/result boundary, not a loose set of Activity fields
- `WidgetAssembly.Result` / related startup wiring are easier to compose for future multiple terminal views
- status/package placement is consistent (`StatusTelemetryStartupForwards` belongs to status ownership or has an explicitly accepted exception)
- `ZideActivity` remains entrypoint/wiring only
- no behavior changes are introduced during extraction-only cuts
- docs reflect the final ownership shape
- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass at final seam boundary

Internal milestone cadence:

- Engineer executes `AHW3-M1` through `AHW3-M6` sequentially.
- Do not stop for architect review between internal milestones.
- Mark each internal milestone complete in this file as it lands.
- Stop only if the hard stop conditions in `ENGINEER_ENTRYPOINT.md` are hit or
  the `AHW-B3` super-gate is reached.

### `AHW3-M1` Status telemetry package ownership cleanup (`completed_in_batch`)

Queue line (exact):

- move package-doctor/status startup telemetry forwarding under status ownership

Progress checkpoint:

- `Milestone: AHW3-M1 completed_in_batch`
- `Progress delta: StatusTelemetryStartupForwards moved from host.debug to host.status; ProductHostStartupBundle import updated`
- `Validation: compile debug + release (pass)`
- `Blocked by Archtect review needed: false`

### `AHW3-M2` Terminal widget instance shape audit (`completed_in_batch`)

Queue line (exact):

- audit current single terminal widget fields and define the minimal instance boundary for future tabs

Progress checkpoint:

- `Milestone: AHW3-M2 completed_in_batch`
- `Instance boundary: selection + gesture (InteractionAssembly.Result) + surface bridge/controller + SurfaceWidgetController = one TerminalWidgetInstance; app-shell chrome, viewport, runtime, userland, input hardware path outside`
- `Authority: ANDROID_JAVA_HOST_STRUCTURE.md § Harness-held terminal widget instance`
- `Blocked by Archtect review needed: false`

### `AHW3-M3` Single terminal widget instance extraction (`completed_in_batch`)

Queue line (exact):

- group current terminal widget controllers/state into one harness-owned instance holder without behavior changes

Progress checkpoint:

- `Milestone: AHW3-M3 completed_in_batch`
- `Progress delta: host/ui/TerminalWidgetInstance.java; ZideActivity holds interactionAssembly + terminalWidget; hostStartup surface suppliers use terminalWidget.surfaceController`
- `Validation: compile debug + release (pass)`
- `Blocked by Archtect review needed: false`

### `AHW3-M4` Interaction context naming symmetry only where material (`completed_in_batch`)

Queue line (exact):

- normalize interaction context naming only if the widget instance extraction makes the current naming misleading

Progress checkpoint:

- `Milestone: AHW3-M4 completed_in_batch`
- `Progress delta: no code change; InteractionAssembly.Host already exposes harnessContext(); widget-instance extraction did not make Activity-shaped naming materially misleading`
- `Blocked by Archtect review needed: false`

### `AHW3-M5` B3 structure/naming authority update (`completed_in_batch`)

Queue line (exact):

- update Android structure and naming authority for the widget instance and status package seams

Progress checkpoint:

- `Milestone: AHW3-M5 completed_in_batch`
- `Progress delta: ANDROID_JAVA_HOST_STRUCTURE.md + ANDROID_JAVA_NAMING_CONTRACT.md updated for TerminalWidgetInstance and status telemetry package`
- `Blocked by Archtect review needed: false`

### `AHW3-M6` Batch validation + review packet (`completed_in_batch`)

Queue line (exact):

- validate AHW-B3 end-to-end and publish the architect review packet

Progress checkpoint:

- `Milestone: AHW3-M6 completed_in_batch`
- `Progress delta: engineer review packet in session response`
- `Validation: see engineer VALIDATION block`
- `Blocked by Archtect review needed: true` (super-gate)

Architect review verdict:

- `Review chunk: AHW-B3`
- `Verdict: accepted`
- `Commits reviewed: 921c034e, a38494d0`
- `Validation spot-check: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass)`
- `Engineer validation accepted: deploy, cold start, and AndroidRuntime:E smoke passed on connected device`
- `Findings carried forward: ProductHostStartupBundle remains accepted as startup-only aggregation; WidgetAssembly.Result should not become a terminal-instance factory alone; the next seam should compose interaction + widget assembly outside ZideActivity so tabs can be added later without Activity field scatter.`
- `Gate decision: AHW-B3 satisfies the status package and single-instance boundary bar. The next batch moves composition out of ZideActivity without implementing tabs.`

`Milestone reached per docs, architect review accepted.`

---

### `AHW-B4` Terminal widget composition assembly (`completed`)

Batch queue line (exact):

- move terminal widget instance composition out of ZideActivity into a harness-owned assembly seam without implementing tabs

Batch purpose:

- keep the `TerminalWidgetInstance` seam from becoming another Activity-local holder
- make the current single terminal widget instance composable by the Android Harness
- prepare future terminal tabs through composition boundaries, not product behavior

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
- no terminal-core or shared-renderer changes
- no selection/IME/gesture behavior changes except compile-preserving seam rewiring
- no app-shell UI redesign
- no debug-view UI resurrection
- no broad rename sweep
- no ASF operator-evidence churn unless new evidence arrives

Batch super-gate:

- `ZideActivity` calls a harness-owned terminal widget composition seam instead of manually stitching `InteractionAssembly`, `WidgetAssembly`, and `TerminalWidgetInstance`
- current single terminal behavior is unchanged
- composition seam returns/owns `TerminalWidgetInstance` clearly enough for future additional instances
- `WidgetAssembly.Result` is not overloaded into a broad factory without explicit ownership docs
- docs reflect the final ownership shape
- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass at final seam boundary

Internal milestone cadence:

- Engineer executes `AHW4-M1` through `AHW4-M6` sequentially.
- Do not stop for architect review between internal milestones.
- Mark each internal milestone complete in this file as it lands.
- Stop only if the hard stop conditions in `ENGINEER_ENTRYPOINT.md` are hit or
  the `AHW-B4` super-gate is reached.

### `AHW4-M1` Composition boundary audit (`completed_in_batch`)

Queue line (exact):

- define the minimal harness composition boundary that owns interaction assembly plus widget assembly for one terminal instance

Progress checkpoint:

- `Milestone: AHW4-M1 completed_in_batch`
- `Boundary: inputs to InteractionAssembly.Host are viewport/status/runtime forwards + surface container; WidgetAssembly.Host adds app-shell views, chrome, shell presentation, and consumes InteractionAssembly.Result for selection/gesture during surface assembly; per-terminal join is InteractionAssembly.Result + WidgetAssembly.Result → TerminalWidgetInstance; global harness fields stay on ZideActivity`
- `Composition owner: host/ui/TerminalWidgetCompositionAssembly`
- `Validation: N/A (audit-only slice before code landed in same batch)`
- `Blocked by Archtect review needed: false`

### `AHW4-M2` Terminal widget composition assembly introduction (`completed_in_batch`)

Queue line (exact):

- introduce a harness-owned assembly seam that composes interaction and widget assembly for the current single terminal instance

Progress checkpoint:

- `Milestone: AHW4-M2 completed_in_batch`
- `Progress delta: TerminalWidgetCompositionAssembly.compose(interaction, widget) returns Result with TerminalWidgetInstance + shell/chrome/view-mode harness fields`
- `Validation: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass)`
- `Blocked by Archtect review needed: false`

### `AHW4-M3` ZideActivity widget composition shrink (`completed_in_batch`)

Queue line (exact):

- move manual interaction/widget/instance stitching out of ZideActivity in behavior-preserving cuts

Progress checkpoint:

- `Milestone: AHW4-M3 completed_in_batch`
- `Progress delta: ZideActivity applies InteractionAssembly → Userland/Session → WidgetAssembly(createWidgetHost(interaction)) → TerminalWidgetCompositionAssembly.compose; removed InteractionAssembly.Result field; createWidgetHost closes over InteractionAssembly.Result`
- `Validation: same compile gates as AHW4-M2 (pass)`
- `Blocked by Archtect review needed: false`

### `AHW4-M4` WidgetAssembly result/host pressure cleanup only where enabled by composition (`completed_in_batch`)

Queue line (exact):

- simplify WidgetAssembly result or host surface only when the new composition seam makes ownership clearer

Progress checkpoint:

- `Milestone: AHW4-M4 completed_in_batch`
- `Progress delta: WidgetAssembly.Result Javadoc documents that TerminalWidgetCompositionAssembly performs instance join; no Result shape change`
- `Validation: same compile gates (pass)`
- `Blocked by Archtect review needed: false`

### `AHW4-M5` B4 structure/naming authority update (`completed_in_batch`)

Queue line (exact):

- update Android structure and naming authority for the terminal widget composition seam

Progress checkpoint:

- `Milestone: AHW4-M5 completed_in_batch`
- `Progress delta: ANDROID_JAVA_HOST_STRUCTURE.md + ANDROID_JAVA_NAMING_CONTRACT.md + handoff/entrypoint aligned to composition seam`
- `Validation: docs-only slice; compile unchanged (pass)`
- `Blocked by Archtect review needed: false`

### `AHW4-M6` Batch validation + review packet (`completed_in_batch`)

Queue line (exact):

- validate AHW-B4 end-to-end and publish the architect review packet

Progress checkpoint:

- `Milestone: AHW4-M6 completed_in_batch`
- `Progress delta: engineer review packet in session response`
- `Validation: see engineer VALIDATION block`
- `Blocked by Archtect review needed: true` (super-gate)

Architect review verdict:

- `Review chunk: AHW-B4`
- `Verdict: accepted`
- `Commits reviewed: 8330e9e9, 47ae0a0e`
- `Architect validation spot-check: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass)`
- `Engineer device validation accepted: deploy + AndroidRuntime:E smoke + cold start pass on RF8M74JDWEK`
- `Findings carried forward: TerminalWidgetCompositionAssembly.Result is acceptable as current co-hosted harness surface; do not expand it casually. applyTerminalWidgetComposition can stay assignment-only on ZideActivity. Next batch should slim WidgetAssembly/Composition host-result surfaces and document the tab-ready API without implementing tabs.`

`Milestone reached per docs, architect review required.`

---

### `AHW-B5` Terminal widget host API slimming + tab-ready contract (`completed`)

Batch queue line (exact):

- slim terminal widget host/result surfaces and document the tab-ready host API without implementing tabs

Batch purpose:

- keep the new composition seam lean after `AHW-B4`
- reduce broad host/result surfaces only where ownership becomes clearer
- define future multi-terminal hosting vocabulary before product tabs exist
- preserve current single-terminal runtime behavior

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
- no selection/IME/gesture behavior changes except compile-preserving seam rewiring
- no app-shell UI redesign
- no debug-view UI resurrection
- no broad rename sweep
- no ASF operator-evidence churn unless new evidence arrives

Batch super-gate:

- `WidgetAssembly.Host`, `WidgetAssembly.Result`, and `TerminalWidgetCompositionAssembly` join surface are audited against the composition boundary
- host/result slimming is behavior-preserving and owner-motivated
- tab-ready vocabulary is documented as host API contract only; no tab product behavior is implemented
- `ZideActivity` remains Android entrypoint/wiring only
- docs reflect the final ownership shape
- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass at final seam boundary

Internal milestone cadence:

- Engineer executes `AHW5-M1` through `AHW5-M6` sequentially.
- Do not stop for architect review between internal milestones.
- Mark each internal milestone complete in this file as it lands.
- Stop only if the hard stop conditions in `ENGINEER_ENTRYPOINT.md` are hit or
  the `AHW-B5` super-gate is reached.

### `AHW5-M1` Host/result surface audit (`completed_in_batch`)

Queue line (exact):

- audit WidgetAssembly and TerminalWidgetCompositionAssembly host/result surfaces against the current composition boundary

Progress checkpoint:

- `Milestone: AHW5-M1 completed_in_batch`
- `Findings: WidgetAssembly.Result owns widget/chrome/surface outputs; TerminalWidgetCompositionAssembly only joins portable instance; duplicate forwarding of shell/chrome through a second Result type added no ownership — removed in M2. WidgetAssembly.Host remains the wide harness callback surface; view accessors map to app-shell layout (grouped via ActivityViewBindings on ZideActivity in M3).`
- `Validation: N/A (audit-first; code follows in M2–M3)`
- `Blocked by Archtect review needed: false`

### `AHW5-M2` Composition result slimming where ownership improves (`completed_in_batch`)

Queue line (exact):

- slim TerminalWidgetCompositionAssembly.Result only where the audit shows a clearer owner boundary

Progress checkpoint:

- `Milestone: AHW5-M2 completed_in_batch`
- `Progress delta: TerminalWidgetCompositionAssembly.compose returns TerminalWidgetInstance only; ZideActivity assigns shell/chrome/view-mode from WidgetAssembly.Result alongside compose (single owner per concern)`
- `Validation: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass)`
- `Blocked by Archtect review needed: false`

### `AHW5-M3` Widget host input grouping where behavior-neutral (`completed_in_batch`)

Queue line (exact):

- group WidgetAssembly.Host inputs only where it reduces Activity pressure without hiding owner boundaries

Progress checkpoint:

- `Milestone: AHW5-M3 completed_in_batch`
- `Progress delta: ZideActivity holds ActivityViewBindings for app-shell view refs; WidgetAssembly.Host anonymous class delegates views from bindings; StatusViewAssembly.Result no longer unpacks duplicate view fields into Activity`
- `Validation: same compile gates as AHW5-M2 (pass)`
- `Blocked by Archtect review needed: false`

### `AHW5-M4` Tab-ready host API contract docs (`completed_in_batch`)

Queue line (exact):

- document the future multi-terminal host API contract without implementing tabs

Progress checkpoint:

- `Milestone: AHW5-M4 completed_in_batch`
- `Progress delta: ANDROID_JAVA_HOST_STRUCTURE.md § Future multi-terminal host API; USERLAND_HOST_CONTRACT.md § Multi-terminal hosting (future)`
- `Validation: N/A (docs-only)`
- `Blocked by Archtect review needed: false`

### `AHW5-M5` B5 structure/naming authority update (`completed_in_batch`)

Queue line (exact):

- update Android structure and naming authority for any host API slimming or tab-ready vocabulary

Progress checkpoint:

- `Milestone: AHW5-M5 completed_in_batch`
- `Progress delta: ANDROID_JAVA_HOST_STRUCTURE + ANDROID_JAVA_NAMING_CONTRACT updated; TerminalWidgetCompositionAssembly file audit row corrected`
- `Validation: docs-only; compile unchanged from M3 (pass)`
- `Blocked by Archtect review needed: false`

### `AHW5-M6` Batch validation + review packet (`completed_in_batch`)

Queue line (exact):

- validate AHW-B5 end-to-end and publish the architect review packet

Progress checkpoint:

- `Milestone: AHW5-M6 completed_in_batch`
- `Progress delta: engineer review packet in session response`
- `Validation: see engineer VALIDATION block`
- `Blocked by Archtect review needed: true` (super-gate)

Architect review verdict:

- `Review chunk: AHW-B5`
- `Verdict: accepted`
- `Commits reviewed: 55234e05, bf783573`
- `Architect validation spot-check: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass)`
- `Engineer device validation accepted: deploy + AndroidRuntime:E smoke + cold start pass`
- `Findings carried forward: TerminalWidgetCompositionAssembly.compose returning TerminalWidgetInstance only is the correct ownership cut. ZideActivity reading shell/chrome/view-mode from WidgetAssembly.Result at the compose callsite is acceptable long-term. ActivityViewBindings duplicate lookup through StatusViewAssembly is non-blocking and should be cleaned up in B6 as wiring hygiene.`

`Milestone reached per docs, architect review required.`

---

### `AHW-B6` Slot-scoped host API foundation (`completed`)

Batch queue line (exact):

- introduce slot-scoped host API seams for terminal widget composition while preserving single-slot runtime behavior

Batch purpose:

- convert tab-ready vocabulary from docs into compile-enforced host APIs
- keep ownership clean: harness owns slot orchestration, widget owns per-slot terminal seams
- reduce startup wiring duplication where it does not change behavior
- preserve current single-terminal product behavior

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
- no selection/IME/gesture behavior changes except compile-preserving seam rewiring
- no app-shell UI redesign
- no debug-view UI resurrection
- no broad rename sweep
- no ASF operator-evidence churn unless new evidence arrives

Batch super-gate:

- slot identity is expressed in host-side API seams where future multi-terminal hosting needs it
- single-slot runtime behavior stays unchanged
- no duplicate owner fields are introduced for shell/chrome/view-mode/widget seams
- `StatusViewAssembly` and `ZideActivity` avoid redundant view-binding lookup if ownership stays clear
- docs reflect the final ownership and naming shape
- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass at final seam boundary

Internal milestone cadence:

- Engineer executes `AHW6-M1` through `AHW6-M6` sequentially.
- Do not stop for architect review between internal milestones.
- Mark each internal milestone complete in this file as it lands.
- Stop only if the hard stop conditions in `ENGINEER_ENTRYPOINT.md` are hit or
  the `AHW-B6` super-gate is reached.

### `AHW6-M1` Slot seam audit in code (`completed_in_batch`)

Queue line (exact):

- map current single-slot assumptions across composition, widget host assembly, and activity wiring seams

Progress checkpoint:

- `Milestone: AHW6-M1 completed_in_batch`
- `Findings: slot identity belongs at InteractionAssembly.Host, WidgetAssembly.Host, and TerminalWidgetCompositionAssembly.compose; global harness (session, runtime, userland) stays outside TerminalWidgetInstance; ActivityViewBindings duplicate capture was StatusViewAssembly + ZideActivity`
- `Validation: N/A (audit-first)`
- `Blocked by Archtect review needed: false`

### `AHW6-M2` Binding lookup dedupe (`completed_in_batch`)

Queue line (exact):

- remove duplicate ActivityViewBindings lookup while keeping StatusViewAssembly ownership clean

Progress checkpoint:

- `Milestone: AHW6-M2 completed_in_batch`
- `Progress delta: StatusViewAssembly.Result.activityViewBindings; ZideActivity assigns from result (no second ActivityViewBindings.from)`
- `Validation: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass)`
- `Blocked by Archtect review needed: false`

### `AHW6-M3` Slot-scoped type introduction (`completed_in_batch`)

Queue line (exact):

- introduce a harness-owned slot identity type for terminal widget host APIs (single slot only for now)

Progress checkpoint:

- `Milestone: AHW6-M3 completed_in_batch`
- `Progress delta: host/ui/TerminalWidgetSlotId enum (PRIMARY only)`
- `Validation: same compile gates as AHW6-M2 (pass)`
- `Blocked by Archtect review needed: false`

### `AHW6-M4` Apply slot identity to composition/wiring seams (`completed_in_batch`)

Queue line (exact):

- thread slot identity through composition and relevant host wiring seams without changing runtime behavior

Progress checkpoint:

- `Milestone: AHW6-M4 completed_in_batch`
- `Progress delta: InteractionAssembly.Host + WidgetAssembly.Host + InteractionCallbacks + compose(TerminalWidgetSlotId, …); ZideActivity uses PRIMARY throughout`
- `Validation: same compile gates (pass)`
- `Blocked by Archtect review needed: false`

### `AHW6-M5` Authority docs refresh (`completed_in_batch`)

Queue line (exact):

- update structure, naming, and userland host authority for slot-scoped host APIs

Progress checkpoint:

- `Milestone: AHW6-M5 completed_in_batch`
- `Progress delta: ANDROID_JAVA_HOST_STRUCTURE + ANDROID_JAVA_NAMING_CONTRACT + USERLAND_HOST_CONTRACT`
- `Validation: docs-only; compile unchanged (pass)`
- `Blocked by Archtect review needed: false`

### `AHW6-M6` Batch validation + review packet (`completed_in_batch`)

Queue line (exact):

- validate AHW-B6 end-to-end and publish the architect review packet

Progress checkpoint:

- `Milestone: AHW6-M6 completed_in_batch`
- `Progress delta: engineer review packet in session response`
- `Validation: see engineer VALIDATION block`
- `Blocked by Archtect review needed: true` (super-gate)

Architect review verdict:

- `Review chunk: AHW-B6`
- `Verdict: accepted`
- `Commits reviewed: 10a9d8d3, bc811c5a`
- `Architect validation spot-check: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass)`
- `Engineer device validation accepted: deploy + AndroidRuntime:E smoke + cold start pass`
- `Findings carried forward: slot identity is now compile-visible but still fanned out through repeated PRIMARY literals across activity wiring seams; next batch should make slot selection single-source. StatusViewAssembly.Result now provides activityViewBindings and duplicated per-view fields; next batch should complete bindings-first slimming where behavior-neutral.`

`Milestone reached per docs, architect review required.`

---

### `AHW-B7` Slot single-source + status result slimming (`completed`)

Batch queue line (exact):

- make slot identity single-source in activity wiring and slim StatusViewAssembly.Result to a bindings-first shape without behavior change

Batch purpose:

- remove slot fan-out pressure from repeated `PRIMARY` literals in activity wiring
- keep slot identity explicit at host seams with one authoritative source
- finish `StatusViewAssembly.Result` shaping now that bindings are authoritative
- preserve current single-terminal runtime behavior

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
- no selection/IME/gesture behavior changes except compile-preserving seam rewiring
- no app-shell UI redesign
- no debug-view UI resurrection
- no broad rename sweep
- no ASF operator-evidence churn unless new evidence arrives

Batch super-gate:

- slot identity is sourced once in harness wiring and threaded consistently to interaction/widget/composition seams
- single-slot runtime behavior remains unchanged
- `StatusViewAssembly.Result` is bindings-first and no longer duplicates per-view fields unless a proven consumer still requires them
- docs reflect final ownership and naming shape
- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass at final seam boundary

Internal milestone cadence:

- Engineer executes `AHW7-M1` through `AHW7-M6` sequentially.
- Do not stop for architect review between internal milestones.
- Mark each internal milestone complete in this file as it lands.
- Stop only if the hard stop conditions in `ENGINEER_ENTRYPOINT.md` are hit or
  the `AHW-B7` super-gate is reached.

### `AHW7-M1` Slot fan-out audit (`completed_in_batch`)

Queue line (exact):

- audit all slot identity callsites and choose one authoritative source in activity wiring

Progress checkpoint:

- `Milestone: AHW7-M1 completed_in_batch`
- `Findings: three PRIMARY literals in ZideActivity (InteractionCallbacks, compose, WidgetAssembly.Host); single static field is the fix`
- `Validation: N/A (audit-first)`
- `Blocked by Archtect review needed: false`

### `AHW7-M2` Slot single-source wiring (`completed_in_batch`)

Queue line (exact):

- implement single-source slot wiring across interaction callbacks, widget host callbacks, and composition callsites

Progress checkpoint:

- `Milestone: AHW7-M2 completed_in_batch`
- `Progress delta: ZideActivity.ACTIVE_PRODUCT_TERMINAL_SLOT feeds InteractionCallbacks, compose, and terminalWidgetSlot()`
- `Validation: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass)`
- `Blocked by Archtect review needed: false`

### `AHW7-M3` StatusViewAssembly.Result slimming (`completed_in_batch`)

Queue line (exact):

- reduce StatusViewAssembly.Result to bindings-first output and remove duplicated view fields where no consumer requires them

Progress checkpoint:

- `Milestone: AHW7-M3 completed_in_batch`
- `Progress delta: Result holds activityViewBindings + SurfaceStateSnapshotReader + StatusController + ViewportController; removed duplicate per-view fields and public terminalStatusHost`
- `Validation: same compile gates as AHW7-M2 (pass)`
- `Blocked by Archtect review needed: false`

### `AHW7-M4` Slot/doc contract alignment (`completed_in_batch`)

Queue line (exact):

- align structure and naming contracts to single-source slot wiring and bindings-first status result shape

Progress checkpoint:

- `Milestone: AHW7-M4 completed_in_batch`
- `Progress delta: ANDROID_JAVA_HOST_STRUCTURE + ANDROID_JAVA_NAMING_CONTRACT`
- `Validation: docs-only; compile unchanged (pass)`
- `Blocked by Archtect review needed: false`

### `AHW7-M5` Queue/handoff/entrypoint sync (`completed_in_batch`)

Queue line (exact):

- keep queue, handoff, and engineer entrypoint aligned to AHW-B7 execution and super-gate stop

Progress checkpoint:

- `Milestone: AHW7-M5 completed_in_batch`
- `Progress delta: ENGINEER_ENTRYPOINT + AGENT_HANDOFF at B7 super-gate`
- `Validation: N/A`
- `Blocked by Archtect review needed: false`

### `AHW7-M6` Batch validation + review packet (`completed_in_batch`)

Queue line (exact):

- validate AHW-B7 end-to-end and publish the architect review packet

Progress checkpoint:

- `Milestone: AHW7-M6 completed_in_batch`
- `Progress delta: engineer review packet in session response`
- `Validation: see engineer VALIDATION block`
- `Blocked by Archtect review needed: true` (super-gate)

Architect review verdict:

- `Review chunk: AHW-B7`
- `Verdict: accepted`
- `Commits reviewed: 30476493, 29715827`
- `Architect validation spot-check: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass)`
- `Engineer device validation accepted: deploy + AndroidRuntime:E smoke + cold start pass`
- `Findings carried forward: ACTIVE_PRODUCT_TERMINAL_SLOT is the correct single source for current single-slot wiring; do not replace with a wider context type until a second slot has concrete behavior. StatusViewAssembly.Result bindings-first shape is correct; keep StatusController.Host assembly-internal unless a concrete test seam requires exposure.`

`Milestone reached per docs, architect review required.`

---

### `AHW-B8` Slot seam contract hardening + chrome freeze (`completed`)

Batch queue line (exact):

- harden slot seam contracts with explicit invariants and keep chrome slot-agnostic until real per-slot policy exists

Batch purpose:

- make slot seams explicit about reserved-vs-active usage today
- eliminate no-op slot plumbing ambiguity by enforcing invariants where seams declare slot identity
- preserve current single-terminal runtime behavior
- keep chrome seam intentionally slot-agnostic until product policy requires otherwise

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
- no selection/IME/gesture behavior changes except compile-preserving seam rewiring
- no app-shell UI redesign
- no debug-view UI resurrection
- no broad rename sweep
- no ASF operator-evidence churn unless new evidence arrives

Batch super-gate:

- slot seams declare and enforce non-null, consistent slot identity where declared
- reserved slot-aware seams are clearly documented as reserved (not behavior-driving yet)
- chrome construction remains slot-agnostic by explicit decision
- single-slot runtime behavior remains unchanged
- docs reflect final ownership and naming shape
- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass at final seam boundary

Internal milestone cadence:

- Engineer executes `AHW8-M1` through `AHW8-M6` sequentially.
- Do not stop for architect review between internal milestones.
- Mark each internal milestone complete in this file as it lands.
- Stop only if the hard stop conditions in `ENGINEER_ENTRYPOINT.md` are hit or
  the `AHW-B8` super-gate is reached.

### `AHW8-M1` Slot seam invariant audit (`completed`)

Queue line (exact):

- audit slot-typed seams for non-null and consistency guarantees across activity, interaction, widget, and composition wiring

Acceptance:

- enumerate every slot seam and classify active usage vs reserved seam
- identify missing invariant checks and ownership ambiguity
- no behavior change required in this audit slice

Progress delta:

- Classified: `ZideActivity.ACTIVE_PRODUCT_TERMINAL_SLOT` → interaction/widget hosts →
  `TerminalWidgetCompositionAssembly.compose`; chrome has no slot seam; slot not on
  `InteractionAssembly.Result`.

### `AHW8-M2` Slot invariant enforcement (`completed`)

Queue line (exact):

- add explicit slot invariants where slot-typed seams are declared

Acceptance:

- enforce non-null slot on relevant assembly/composition entrypoints
- ensure slot consistency at wiring join points where multiple slot seams meet
- compile debug + release Java after code changes

Progress delta:

- `TerminalWidgetSlotId.checkActiveProductTerminalSlot` at `InteractionAssembly.assemble`,
  `WidgetAssembly.assemble`, and `TerminalWidgetCompositionAssembly.compose`.

### `AHW8-M3` Reserved seam labeling (`completed`)

Queue line (exact):

- label reserved slot seams clearly where slot is not yet behavior-driving

Acceptance:

- Javadocs/callback contracts distinguish active slot usage from reserved future usage
- avoid silent no-op slot parameters that appear behavior-driving
- compile debug + release Java after code changes

Progress delta:

- Host Javadocs + `TerminalWidgetSlotId` enum document active = `PRIMARY` vs reserved
  enum values.

### `AHW8-M4` Chrome slot freeze decision lock (`completed`)

Queue line (exact):

- lock the decision that chrome remains slot-agnostic until per-slot chrome policy is scoped

Acceptance:

- no slot argument added to chrome construction in this batch
- docs explicitly record when to reopen this decision

Progress delta:

- `ChromeFactory` / `ChromeController` class Javadocs; structure doc “Chrome and terminal
  slot policy (freeze)” section.

### `AHW8-M5` Authority + workflow sync (`completed`)

Queue line (exact):

- update structure/naming/userland authority and queue/handoff/entrypoint for B8 outcomes

Acceptance:

- structure/naming/userland docs match final code reality
- queue, handoff, and engineer entrypoint remain aligned to active macro batch

Progress delta:

- `ANDROID_JAVA_HOST_STRUCTURE.md`, `ANDROID_JAVA_NAMING_CONTRACT.md`,
  `USERLAND_HOST_CONTRACT.md`, and queue/handoff/entrypoint updated for B8.

### `AHW8-M6` Batch validation + review packet (`completed`)

Queue line (exact):

- validate AHW-B8 end-to-end and publish the architect review packet

Acceptance:

- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass, or exact device-blocker output is recorded
- cold start smoke pass when a device is available
- engineer reports the full super-gate packet and stops for Architect review

Progress delta:

- Debug/release compile, deploy, cold start, and `AndroidRuntime:E` filter: no lines (pass).

Super-gate engineer packet:

- `Milestone: AHW-B8 verdict_pending`
- `Queue line (exact): harden slot seam contracts with explicit invariants and keep chrome slot-agnostic until real per-slot policy exists`
- `Scope contract: Java terminal host + allowed authority docs; no tabs/multi-instance product behavior`
- `Progress delta: active slot enforced at assembly/composition; chrome freeze documented; authority synced`
- `Validation: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass); python3 ops/android_terminal_host.py deploy (pass); adb cold start + AndroidRuntime:E (pass, empty)`
- `Engineer updates: Blocked by Archtect review needed: true`

Remaining risks:

- External code that constructed hosts with a non-`PRIMARY` slot would now fail fast at
  assembly (intended).

Review questions for Architect:

- Confirm `checkActiveProductTerminalSlot` stays the single product choke point until a
  second slot is policy-defined.
- Confirm next macro batch scope after verdict.

Architect review verdict:

- `Review chunk: AHW-B8`
- `Verdict: accepted`
- `Commits reviewed: 5f3d1403, e045f819, d5363366`
- `Architect validation spot-check: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass)`
- `Engineer device validation accepted: deploy + AndroidRuntime:E smoke + cold start pass`
- `Findings carried forward: checkActiveProductTerminalSlot is the correct single choke point until second-slot product policy exists. Chrome remains intentionally slot-agnostic; do not thread slot into chrome construction before per-slot policy is scoped.`

`Milestone reached per docs, architect review required.`

---

### `AHW-B9` Slot-aware app-shell contract alignment (`verdict_pending`)

Batch queue line (exact):

- align app-shell contract vocabulary with terminal slot seams without implementing tab behavior

Batch purpose:

- connect slot seam vocabulary (`TerminalWidgetSlotId`) and app-shell vocabulary (`ShellViewId`/navigation) at contract level
- keep slot-aware seams explicit while preserving single-slot behavior
- avoid premature product behavior changes (tabs/switching/chrome policy)

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
- no selection/IME/gesture behavior changes except compile-preserving seam rewiring
- no app-shell UI redesign
- no debug-view UI resurrection
- no broad rename sweep
- no ASF operator-evidence churn unless new evidence arrives

Batch super-gate:

- slot/app-shell relationship is explicit in host contracts (active now vs reserved future)
- no duplicate or conflicting slot-to-view vocabulary remains in wiring contracts
- chrome construction remains slot-agnostic by explicit decision
- single-slot runtime behavior remains unchanged
- docs reflect final ownership and naming shape
- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass at final seam boundary

Internal milestone cadence:

- Engineer executes `AHW9-M1` through `AHW9-M6` sequentially.
- Do not stop for architect review between internal milestones.
- Mark each internal milestone complete in this file as it lands.
- Stop only if the hard stop conditions in `ENGINEER_ENTRYPOINT.md` are hit or
  the `AHW-B9` super-gate is reached.

### `AHW9-M1` Slot/app-shell contract audit (`completed`)

Queue line (exact):

- audit slot and app-shell navigation vocabulary across host seams and document active vs reserved mappings

Acceptance:

- enumerate every slot-typed and shell-view-typed seam in active wiring
- identify mismatches and redundant mapping points
- no behavior change required in this audit slice

Progress delta (audit notes):

- **Slot-typed seams (active wiring):** `ZideActivity.ACTIVE_PRODUCT_TERMINAL_SLOT` →
  `InteractionAssembly.Host` / `WidgetAssembly.Host` `terminalWidgetSlot()`;
  `InteractionAssembly.assemble` / `WidgetAssembly.assemble` /
  `TerminalWidgetCompositionAssembly.compose` enforce
  `checkActiveProductTerminalSlot`; `InteractionCallbacks` carries
  `TerminalWidgetSlotId` for gesture/selection policy.
- **Shell-view / app-shell navigation seams:** `ShellViewId` (only `TERMINAL` today);
  `AppShellNavigation` default `activeShellView = TERMINAL`; `ViewModeController.applyCurrentViewMode`
  sets `ShellViewId.TERMINAL` literally; `AppShellViewState.productTerminalDefault` duplicates
  `TERMINAL` literal; `AppShellNavigation.activeViewState()` derives from `activeShellView`.
- **Mismatch / redundancy:** contract alignment between `TerminalWidgetSlotId` and
  `ShellViewId` exists only in Javadoc on `TerminalWidgetSlotId`, not in one code seam;
  multiple `ShellViewId.TERMINAL` literals without a single mapping choke point.
- **Reserved:** additional `ShellViewId` / `TerminalWidgetSlotId` enum values remain
  non–behavior-driving until policy scopes them (no tab behavior).

### `AHW9-M2` Mapping seam introduction (`completed`)

Queue line (exact):

- introduce one explicit mapping seam for active product slot to app-shell view identity

Acceptance:

- single authoritative mapping seam for `ACTIVE_PRODUCT_TERMINAL_SLOT` to current shell view contract
- no tabs/switching behavior introduced
- compile debug + release Java after code changes

Progress delta:

- Added `ProductTerminalSlotShellMapping.shellViewIdForTerminalSlot`; `PRIMARY` →
  `ShellViewId.TERMINAL` with `checkActiveProductTerminalSlot`. Linked from
  `TerminalWidgetSlotId` and `ShellViewId` Javadoc.

### `AHW9-M3` Wiring contract cleanup (`completed`)

Queue line (exact):

- clean wiring contracts to consume the mapping seam and remove redundant slot/view assumptions

Acceptance:

- wiring contracts use the canonical slot/view mapping seam where applicable
- no behavior drift in startup order, runtime, surface, input, or session flow
- compile debug + release Java after code changes

Progress delta:

- `WidgetAssembly` constructs `AppShellNavigation` from mapped `ShellViewId`;
  `AppShellNavigation` requires explicit initial view. `ViewModeController` takes
  `TerminalWidgetSlotId` and applies active shell view via mapping.
  `AppShellViewState.productTerminalDefault(TerminalWidgetSlotId)` uses mapping.

### `AHW9-M4` Freeze/guardrail lock (`completed`)

Queue line (exact):

- lock slot-aware app-shell guardrails and chrome slot freeze in authority docs

Acceptance:

- docs explicitly state what is active today and what remains reserved
- chrome slot freeze remains explicit and unchanged

Progress delta:

- Structure “slot → app-shell view mapping” + naming + userland; `ZideActivity`
  javadoc ties `ACTIVE_PRODUCT_TERMINAL_SLOT` to `ProductTerminalSlotShellMapping`.

### `AHW9-M5` Queue/handoff/entrypoint sync (`completed`)

Queue line (exact):

- keep queue, handoff, and engineer entrypoint aligned to AHW-B9 execution and super-gate stop

Acceptance:

- queue, handoff, and engineer entrypoint stay coherent through B9 super-gate
- super-gate stop condition and review packet contract are explicit

Progress delta:

- This file, `ENGINEER_ENTRYPOINT.md`, and `AGENT_HANDOFF.md` updated for
  `verdict_pending` and Architect refocus at B9 super-gate.

### `AHW9-M6` Batch validation + review packet (`completed`)

Queue line (exact):

- validate AHW-B9 end-to-end and publish the architect review packet

Acceptance:

- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass, or exact device-blocker output is recorded
- cold start smoke pass when a device is available
- engineer reports the full super-gate packet and stops for Architect review

Progress delta:

- Debug/release compile pass; deploy + cold start + `AndroidRuntime:E` filter (empty).

Super-gate engineer packet:

- `Milestone: AHW-B9 verdict_pending`
- `Queue line (exact): align app-shell contract vocabulary with terminal slot seams without implementing tab behavior`
- `Scope contract: Java terminal host + allowed authority docs; no tabs/multi-instance product behavior`
- `Progress delta: ProductTerminalSlotShellMapping canonical slot→ShellViewId; wiring consumes seam; guardrails documented`
- `Validation: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass); python3 ops/android_terminal_host.py deploy (pass); adb cold start + AndroidRuntime:E (pass, empty)`
- `Engineer updates: Blocked by Archtect review needed: true`

Remaining risks:

- `ProductTerminalSlotShellMapping.shellViewIdForTerminalSlot` may be invoked multiple
  times per activation path (idempotent checks); acceptable until second-slot policy
  scopes deduplication.

Review questions for Architect:

- Confirm mapping class name and package placement for the long-term multi-`ShellViewId` story.
- Confirm next macro batch after verdict.

`Milestone reached per docs, architect review required.`

---

## Guardrails

- No CI/pipeline/lint ceremony additions.
- No reintroduction of debug-view UI pathways.
- No compatibility shim kept only for migration convenience.
- Do not keep dual ownership if one side is clearly obsolete.

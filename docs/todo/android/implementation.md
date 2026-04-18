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
- Completed macro batch: `AHW-B9` (accepted by Architect; app-shell state contract cleanup follow-up queued in `AHW-B10`).
- Completed macro batch: `AHW-B10` (accepted by Architect; app-shell state surface hardening follow-up queued in `AHW-B11`).
- Completed macro batch: `AHW-B11` (accepted by Architect; app-shell mutation-ownership narrowing follow-up queued in `AHW-B12`).
- Completed macro batch: `AHW-B12` (accepted by Architect; app-shell sidebar policy narrowing follow-up queued in `AHW-B13`).
- Completed macro batch: `AHW-B13` (accepted by Architect; chrome IME visibility policy narrowing follow-up queued in `AHW-B14`).
- Completed macro batch: `AHW-B14` (accepted by Architect; chrome IME policy input ownership follow-up queued in `AHW-B15`).
- Completed macro batch: `AHW-B15` (accepted by Architect; widget-host IME primitive seam narrowing follow-up queued in `AHW-B16`).
- Completed macro batch: `AHW-B16` (accepted by Architect; activity IME state carrier seam follow-up queued in `AHW-B17`).
- Completed macro batch: `AHW-B17` (accepted by Architect; host IME callback seam unification follow-up queued in `AHW-B18`).
- Engineer delivery complete; Architect verdict pending: `AHW-B18` (host IME callback seam unification, behavior-neutral). No macro batch is `in_progress` until Architect refocuses the queue.

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

### `AHW-B9` Slot-aware app-shell contract alignment (`completed`)

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

Architect review verdict:

- `Review chunk: AHW-B9`
- `Verdict: accepted`
- `Commits reviewed: d11388a1, 2b27dd5d, 184a8f46, 3ca594d7, 3846d285, 241dddc0`
- `Architect validation spot-check: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass)`
- `Engineer device validation accepted: deploy + AndroidRuntime:E smoke + cold start pass`
- `Findings carried forward: ProductTerminalSlotShellMapping is the correct long-term host/ui seam for slot→shell-view mapping. Repeated mapping/check calls are acceptable now; next batch should clean app-shell state contract shape so mapping is consumed consistently without behavior change.`

`Milestone reached per docs, architect review required.`

---

### `AHW-B10` App-shell state contract cleanup (`completed`)

Batch queue line (exact):

- clean app-shell state contract seams to consume slot→shell-view mapping consistently without behavior change

Batch purpose:

- reduce redundant mapping/check callsites across app-shell state owners
- make app-shell state contract explicit and minimal (`AppShellNavigation`, `AppShellViewState`, `ViewModeController`)
- preserve single-slot runtime behavior and slot/chrome freezes

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

- app-shell state seams consume canonical slot→shell mapping without redundant contract surfaces
- `AppShellNavigation` / `AppShellViewState` / `ViewModeController` roles are explicit and non-overlapping
- slot choke point and chrome slot freeze remain unchanged
- single-slot runtime behavior remains unchanged
- docs reflect final ownership and naming shape
- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass at final seam boundary

Internal milestone cadence:

- Engineer executes `AHW10-M1` through `AHW10-M6` sequentially.
- Do not stop for architect review between internal milestones.
- Mark each internal milestone complete in this file as it lands.
- Stop only if the hard stop conditions in `ENGINEER_ENTRYPOINT.md` are hit or
  the `AHW-B10` super-gate is reached.

### `AHW10-M1` App-shell state seam audit (`completed`)

Queue line (exact):

- audit app-shell state owners and mapping callsites for redundant or unused contract surfaces

Acceptance:

- list every mapping callsite and state owner (`AppShellNavigation`, `AppShellViewState`, `ViewModeController`)
- identify dead/unused helpers and duplicated state projections
- no behavior change required in this audit slice

Progress delta (audit snapshot before consolidation):

- **Mapping callsites:** `WidgetAssembly.assemble` →
  `ProductTerminalSlotShellMapping.shellViewIdForTerminalSlot` for `AppShellNavigation`
  construction; `ViewModeController.applyCurrentViewMode` → same mapping again (redundant
  `checkActiveProductTerminalSlot`); `AppShellViewState.productTerminalDefault(TerminalWidgetSlotId)`
  invoked mapping but had **no callers** (dead surface).
- **Owners:** `AppShellNavigation` holds `activeShellView` + `activeViewState()`;
  `ViewModeController` re-derived shell view from slot on every apply; roles overlapped with
  navigation owner.

### `AHW10-M2` Mapping consumption consolidation (`completed`)

Queue line (exact):

- consolidate mapping consumption so app-shell state owners use one consistent resolved shell-view contract path

Acceptance:

- reduce redundant mapping/check calls where possible without changing behavior
- keep slot policy enforcement semantics unchanged
- compile debug + release Java after code changes

Progress delta:

- `AppShellNavigation.forProductTerminalSlot` resolves mapping once and stores
  `productTerminalShellViewId`; `applyProductTerminalShellViewActive` reasserts without
  re-running `checkActiveProductTerminalSlot`. `ViewModeController` delegates to
  `applyProductTerminalShellViewActive`. `ProductTerminalSlotShellMapping` Javadoc updated.

### `AHW10-M3` AppShellViewState contract trim (`completed`)

Queue line (exact):

- trim or reshape AppShellViewState helpers to match actual consumers and remove dead slot/view indirection

Acceptance:

- remove or refactor unused helper surfaces where no consumer exists
- keep state semantics stable (selected/contentReady defaults unchanged)
- compile debug + release Java after code changes

Progress delta:

- Removed unused `AppShellViewState.productTerminalDefault(TerminalWidgetSlotId)`.

### `AHW10-M4` Doc and guardrail lock (`completed`)

Queue line (exact):

- update structure/naming/userland docs for final app-shell state contract shape while preserving slot/chrome freezes

Acceptance:

- docs clearly separate active behavior from reserved future slot behavior
- chrome slot freeze and slot choke-point guidance remain intact

Progress delta:

- `ANDROID_JAVA_HOST_STRUCTURE.md`, `ANDROID_JAVA_NAMING_CONTRACT.md`,
  `USERLAND_HOST_CONTRACT.md` updated for navigation-owned resolved shell view and
  steady-state reassert path.

### `AHW10-M5` Queue/handoff/entrypoint sync (`completed`)

Queue line (exact):

- keep queue, handoff, and engineer entrypoint aligned to AHW-B10 execution and super-gate stop

Acceptance:

- queue, handoff, and engineer entrypoint stay coherent through B10 super-gate
- super-gate stop condition and review packet contract are explicit

Progress delta:

- This file, `ENGINEER_ENTRYPOINT.md`, and `AGENT_HANDOFF.md` updated for
  `verdict_pending` and Architect refocus.

### `AHW10-M6` Batch validation + review packet (`completed`)

Queue line (exact):

- validate AHW-B10 end-to-end and publish the architect review packet

Acceptance:

- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass, or exact device-blocker output is recorded
- cold start smoke pass when a device is available
- engineer reports the full super-gate packet and stops for Architect review

Progress delta:

- Debug/release compile pass; deploy + cold start + `AndroidRuntime:E` filter (empty).

Super-gate engineer packet:

- `Milestone: AHW-B10 verdict_pending`
- `Queue line (exact): clean app-shell state contract seams to consume slot→shell-view mapping consistently without behavior change`
- `Scope contract: Java terminal host + allowed authority docs; slot/chrome freezes; no tabs`
- `Progress delta: AppShellNavigation owns resolved shell view; ViewModeController avoids duplicate mapping; dead helper removed`
- `Validation: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass); python3 ops/android_terminal_host.py deploy (pass); adb cold start + AndroidRuntime:E (pass, empty)`
- `Engineer updates: Blocked by Archtect review needed: true`

Remaining risks:

- None beyond prior note: mapping still runs per `AppShellNavigation` construction (one per widget assembly), as intended.

Review questions for Architect:

- Confirm `AppShellNavigation.forProductTerminalSlot` / `applyProductTerminalShellViewActive` split as the long-term app-shell contract.
- Confirm next macro batch after verdict.

Architect review verdict:

- `Review chunk: AHW-B10`
- `Verdict: accepted`
- `Commits reviewed: 35ac65b9, d6bb1078, 832e9095, 5a271cb3`
- `Architect validation spot-check: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass)`
- `Engineer device validation accepted: deploy + AndroidRuntime:E smoke + cold start pass`
- `Findings carried forward: AppShellNavigation.forProductTerminalSlot / applyProductTerminalShellViewActive split is the correct long-term contract while single-slot behavior remains. Next cleanup should tighten app-shell state APIs and invariants without opening tab behavior or chrome slot policy.`

`Milestone reached per docs, architect review required.`

---

### `AHW-B11` App-shell state surface hardening (`completed`)

Batch queue line (exact):

- harden app-shell state surfaces and invariants while preserving slot mapping and chrome freeze behavior

Batch purpose:

- tighten app-shell state API contracts (`AppShellNavigation`, `AppShellViewState`) with explicit invariants
- remove or constrain remaining weakly-defined state mutation surfaces
- preserve single-slot runtime behavior and existing slot/chrome guardrails

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

- app-shell state APIs expose explicit invariant-safe mutation paths only
- null/invalid state updates are prevented at app-shell state owners
- slot choke point and chrome slot freeze remain unchanged
- single-slot runtime behavior remains unchanged
- docs reflect final ownership and naming shape
- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass at final seam boundary

Internal milestone cadence:

- Engineer executes `AHW11-M1` through `AHW11-M6` sequentially.
- Do not stop for architect review between internal milestones.
- Mark each internal milestone complete in this file as it lands.
- Stop only if the hard stop conditions in `ENGINEER_ENTRYPOINT.md` are hit or
  the `AHW-B11` super-gate is reached.

### `AHW11-M1` App-shell state API audit (`completed`)

Queue line (exact):

- audit AppShellNavigation/AppShellViewState mutation surfaces and invariant gaps

Acceptance:

- list all mutation entry points and current guard coverage
- identify weak or implicit invariants that should be made explicit
- no behavior change required in this audit slice

Progress delta (audit snapshot):

- **AppShellNavigation mutation:** `forProductTerminalSlot` → private ctor (guarded by
  mapping); `setSidebarOpen(boolean)`; `setActiveShellView(ShellViewId)` **public, no
  null check** (only caller today is `applyProductTerminalShellViewActive`); `applyProductTerminalShellViewActive`;
  `activeShellView()` read; `activeViewState()` builds `AppShellViewState` from current
  active id.
- **AppShellViewState:** public ctor takes three fields; **no null check on `ShellViewId id`**;
  only constructed from `AppShellNavigation.activeViewState()` in product wiring.
- **Consumers:** `ChromeBridge` uses sidebar only; `ViewModeController` uses
  `applyProductTerminalShellViewActive` only. No external `setActiveShellView` callsites yet.
- **Gaps:** null `ShellViewId` could corrupt `activeShellView` / `AppShellViewState.id` if
  `setActiveShellView` were misused; implicit invariant “active view is non-null” should be
  enforced at owner boundary.

### `AHW11-M2` Navigation invariant hardening (`completed`)

Queue line (exact):

- harden AppShellNavigation mutation invariants and null-safety without behavior change

Acceptance:

- prevent null/invalid active-shell transitions at owner boundary
- keep current startup/order behavior unchanged
- compile debug + release Java after code changes

Progress delta:

- Class-level invariant Javadoc; `setActiveShellView` uses `Objects.requireNonNull`;
  `activeViewState()` Javadoc for default row semantics.

### `AHW11-M3` View state contract tightening (`completed`)

Queue line (exact):

- tighten AppShellViewState construction/usage contracts to match real consumers

Acceptance:

- enforce explicit invariants on view-state construction paths
- avoid introducing new state responsibilities
- compile debug + release Java after code changes

Progress delta:

- `AppShellViewState` requires non-null `id`; invariant Javadoc and pointer to
  `AppShellNavigation.activeViewState()`.

### `AHW11-M4` Mapping/guardrail consistency lock (`completed`)

Queue line (exact):

- lock consistency between app-shell state invariants and existing slot/chrome guardrails

Acceptance:

- slot mapping seam and slot choke point remain unchanged
- chrome slot-freeze guidance remains explicit and unchanged

Progress delta:

- Structure “App-shell state invariants” subsection; naming + userland bullets; table
  rows updated. No changes to `ProductTerminalSlotShellMapping` or chrome factory slot policy.

### `AHW11-M5` Queue/handoff/entrypoint sync (`completed_in_batch`)

Queue line (exact):

- keep queue, handoff, and engineer entrypoint aligned to AHW-B11 execution and super-gate stop

Acceptance:

- queue, handoff, and engineer entrypoint stay coherent through B11 super-gate
- super-gate stop condition and review packet contract are explicit

Progress delta:

- This file, `ENGINEER_ENTRYPOINT.md`, and `AGENT_HANDOFF.md` updated for
  `verdict_pending` and Architect refocus.

### `AHW11-M6` Batch validation + review packet (`completed_in_batch`)

Queue line (exact):

- validate AHW-B11 end-to-end and publish the architect review packet

Acceptance:

- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass, or exact device-blocker output is recorded
- cold start smoke pass when a device is available
- engineer reports the full super-gate packet and stops for Architect review

Progress delta:

- Debug/release compile pass; deploy + cold start + `AndroidRuntime:E` filter (empty).

Super-gate engineer packet:

- `Milestone: AHW-B11 verdict_pending`
- `Queue line (exact): harden app-shell state surfaces and invariants while preserving slot mapping and chrome freeze behavior`
- `Scope contract: Java terminal host + allowed authority docs; behavior-neutral; no tabs`
- `Progress delta: null guards on AppShellNavigation/AppShellViewState; docs lock invariants with slot/chrome guardrails`
- `Validation: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass); python3 ops/android_terminal_host.py deploy (pass); adb cold start + AndroidRuntime:E (pass, empty)`
- `Engineer updates: Blocked by Archtect review needed: true`

Remaining risks:

- None material; null rejects surface as fail-fast if future callsites misuse public setters.

Architect review verdict:

- `Review chunk: AHW-B11`
- `Verdict: accepted`
- `Commits reviewed: aaf5d916, 067ffc14, 8e5949c9, 086f3054, b56fec84`
- `Architect validation spot-check: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass)`
- `Engineer device validation accepted: deploy + AndroidRuntime:E smoke + cold start pass`
- `Findings carried forward: keep null-reject semantics (`Objects.requireNonNull`) as the long-term harness boundary for shell-view ids. Next batch should narrow mutation entry points so app-shell state changes happen through explicit policy methods, not broad public setters.`

`Milestone reached per docs, architect review required.`

---

### `AHW-B12` App-shell mutation ownership narrowing (`completed`)

Batch queue line (exact):

- narrow app-shell mutation APIs to explicit policy methods while preserving single-slot behavior

Batch purpose:

- reduce broad mutation surfaces on app-shell state owners without changing behavior
- keep slot mapping choke points and chrome slot freeze unchanged
- make mutation ownership explicit for future multi-view work

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

- `AppShellNavigation` exposes explicit policy mutation methods only
- no ad-hoc public active-view mutation path remains in product wiring
- slot mapping seam, slot choke point, and chrome slot freeze remain unchanged
- single-slot runtime behavior remains unchanged
- docs reflect final ownership and naming shape
- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass at final seam boundary

Internal milestone cadence:

- Engineer executes `AHW12-M1` through `AHW12-M6` sequentially.
- Do not stop for architect review between internal milestones.
- Mark each internal milestone complete in this file as it lands.
- Stop only if the hard stop conditions in `ENGINEER_ENTRYPOINT.md` are hit or
  the `AHW-B12` super-gate is reached.

### `AHW12-M1` Mutation owner/callsite audit (`completed`)

Queue line (exact):

- audit AppShellNavigation mutation callsites and classify policy-owned vs ad-hoc paths

Acceptance:

- enumerate all app-shell mutation entry points and current callsites
- classify each mutation as policy-owned or ad-hoc
- identify the minimum behavior-neutral API narrowing cut

Progress delta:

- **Mutation entry points:** `setSidebarOpen(boolean)` — policy (chrome drawer); `setActiveShellView(ShellViewId)` — **public ad-hoc** active-view setter (only called from `applyProductTerminalShellViewActive` in-tree); `applyProductTerminalShellViewActive()` — **explicit product policy**; constructor seeds `activeShellView` from resolved mapping.
- **Callsites:** no external Java callsites for `setActiveShellView`; `ViewModeController` uses `applyProductTerminalShellViewActive` only.
- **Narrowing cut:** remove public `setActiveShellView`; route through private `replaceActiveShellView` + public `applyProductTerminalShellViewActive` only for product reassert.

### `AHW12-M2` Navigation mutation API narrowing (`completed`)

Queue line (exact):

- narrow AppShellNavigation active-view mutation to explicit policy methods

Acceptance:

- replace broad active-view setter exposure with explicit policy API
- keep `Objects.requireNonNull` invariants at owner boundaries
- compile debug + release Java after code changes

Progress delta:

- Removed public `setActiveShellView`; added private `replaceActiveShellView`; class
  Javadoc documents policy-only active-view mutation.

### `AHW12-M3` Consumer rewiring to policy API (`completed`)

Queue line (exact):

- rewire app-shell consumers to narrowed navigation policy API without behavior change

Acceptance:

- all in-tree consumers use explicit policy methods
- no direct ad-hoc active-view mutation remains
- compile debug + release Java after code changes

Progress delta:

- No code rewiring required: `ViewModeController` already called
  `applyProductTerminalShellViewActive` only; no `setActiveShellView` callsites.

### `AHW12-M4` Contract docs lock (`completed`)

Queue line (exact):

- lock naming/structure/userland docs to narrowed mutation ownership contract

Acceptance:

- host structure, naming contract, and userland contract match code shape
- slot mapping/chrome freeze guidance remains explicit and unchanged

Progress delta:

- Structure, naming, userland updated for policy-only active shell view mutation.

### `AHW12-M5` Queue/handoff/entrypoint sync (`completed_in_batch`)

Queue line (exact):

- keep queue, handoff, and engineer entrypoint aligned to AHW-B12 execution and super-gate stop

Acceptance:

- queue, handoff, and engineer entrypoint stay coherent through B12 super-gate
- super-gate stop condition and review packet contract are explicit

Progress delta:

- This file, `ENGINEER_ENTRYPOINT.md`, and `AGENT_HANDOFF.md` updated for
  `verdict_pending` and Architect refocus.

### `AHW12-M6` Batch validation + review packet (`completed_in_batch`)

Queue line (exact):

- validate AHW-B12 end-to-end and publish the architect review packet

Acceptance:

- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass, or exact device-blocker output is recorded
- cold start smoke pass when a device is available
- engineer reports the full super-gate packet and stops for Architect review

Progress delta:

- Debug/release compile pass; deploy + cold start + `AndroidRuntime:E` filter (empty).

Super-gate engineer packet:

- `Milestone: AHW-B12 verdict_pending`
- `Queue line (exact): narrow app-shell mutation APIs to explicit policy methods while preserving single-slot behavior`
- `Scope contract: behavior-neutral mutation ownership; slot mapping + chrome freeze unchanged; no tabs`
- `Progress delta: public setActiveShellView removed; private replaceActiveShellView; docs aligned`
- `Validation: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass); python3 ops/android_terminal_host.py deploy (pass); adb cold start + AndroidRuntime:E (pass, empty)`
- `Engineer updates: Blocked by Archtect review needed: true`

Remaining risks:

- None material in repo scope.

Architect review verdict:

- `Review chunk: AHW-B12`
- `Verdict: accepted`
- `Commits reviewed: 17c4becf, 15e2f3c7, 0cf8ef3b, e1f9770d`
- `Architect validation spot-check: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass)`
- `Engineer device validation accepted: deploy + AndroidRuntime:E smoke + cold start pass`
- `Findings carried forward: keep no public arbitrary shell-view setter until multi-view policy explicitly defines public methods. Next batch narrows sidebar mutation to explicit policy methods for symmetry with active-view ownership.`

`Milestone reached per docs, architect review required.`

---

### `AHW-B13` App-shell sidebar mutation policy narrowing (`completed`)

Batch queue line (exact):

- narrow app-shell sidebar mutation APIs to explicit policy methods while preserving behavior

Batch purpose:

- remove broad boolean sidebar mutation surfaces on app-shell state owner
- keep active-view ownership narrowing from B12 unchanged
- preserve slot mapping/chrome freeze contracts and runtime behavior

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

- `AppShellNavigation` exposes explicit sidebar policy methods (no broad boolean setter in product wiring)
- in-tree chrome/sidebar consumers use explicit policy methods only
- active-view mutation ownership from B12 remains unchanged
- slot mapping seam, slot choke point, and chrome slot freeze remain unchanged
- single-slot runtime behavior remains unchanged
- docs reflect final ownership and naming shape
- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass at final seam boundary

Internal milestone cadence:

- Engineer executes `AHW13-M1` through `AHW13-M6` sequentially.
- Do not stop for architect review between internal milestones.
- Mark each internal milestone complete in this file as it lands.
- Stop only if the hard stop conditions in `ENGINEER_ENTRYPOINT.md` are hit or
  the `AHW-B13` super-gate is reached.

### `AHW13-M1` Sidebar mutation owner/callsite audit (`completed`)

Queue line (exact):

- audit sidebar mutation entry points and classify policy-owned vs ad-hoc paths

Acceptance:

- enumerate sidebar mutation entry points and callsites
- classify each mutation as policy-owned or ad-hoc
- define minimum behavior-neutral API narrowing cut

Progress delta:

- **Owner:** `AppShellNavigation` holds `sidebarOpen`; **mutation** is `setSidebarOpen(boolean)` (generic boolean setter).
- **Callsites:** `ChromeBridge.setSidebarOpen` → `AppShellNavigation.setSidebarOpen` only; `ChromeController` calls `host.setSidebarOpen(true|false)` from `openSidebar` / `closeSidebar`; reads via `host.sidebarOpen()`.
- **Narrowing cut:** replace boolean setter with explicit `applyChromeDrawerSidebarOpen` / `applyChromeDrawerSidebarClosed`; align `ChromeController.Host` + `ChromeBridge`; query as `chromeDrawerSidebarOpen()` on `AppShellNavigation` and host.

### `AHW13-M2` Sidebar policy API narrowing (`completed`)

Queue line (exact):

- replace broad sidebar boolean setter with explicit policy methods

Acceptance:

- `AppShellNavigation` exposes explicit sidebar policy methods instead of generic boolean setter
- owner invariants remain explicit and behavior-neutral
- compile debug + release Java after code changes

Progress delta:

- `applyChromeDrawerSidebarOpen` / `applyChromeDrawerSidebarClosed`; query `chromeDrawerSidebarOpen()`; field renamed to `chromeDrawerSidebarOpen`.

### `AHW13-M3` Consumer rewiring to sidebar policy API (`completed`)

Queue line (exact):

- rewire chrome/sidebar consumers to explicit sidebar policy APIs without behavior change

Acceptance:

- all in-tree sidebar consumers use explicit policy methods
- no direct generic sidebar mutation remains
- compile debug + release Java after code changes

Progress delta:

- `ChromeController.Host`, `ChromeController`, `ChromeBridge` rewired to policy methods.

### `AHW13-M4` Contract docs lock (`completed`)

Queue line (exact):

- lock naming/structure/userland docs to sidebar policy mutation ownership contract

Acceptance:

- host structure, naming contract, and userland contract match code shape
- active-view ownership, slot mapping, and chrome freeze guidance remain unchanged

Progress delta:

- Structure app-shell invariants + table rows; naming contract bullet. USERLAND unchanged (no sidebar seam there).

### `AHW13-M5` Queue/handoff/entrypoint sync (`completed_in_batch`)

Queue line (exact):

- keep queue, handoff, and engineer entrypoint aligned to AHW-B13 execution and super-gate stop

Acceptance:

- queue, handoff, and engineer entrypoint stay coherent through B13 super-gate
- super-gate stop condition and review packet contract are explicit

Progress delta:

- This file, `ENGINEER_ENTRYPOINT.md`, and `AGENT_HANDOFF.md` updated for `verdict_pending`.

### `AHW13-M6` Batch validation + review packet (`completed_in_batch`)

Queue line (exact):

- validate AHW-B13 end-to-end and publish the architect review packet

Acceptance:

- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass, or exact device-blocker output is recorded
- cold start smoke pass when a device is available
- engineer reports the full super-gate packet and stops for Architect review

Progress delta:

- Debug/release compile pass; deploy + cold start + `AndroidRuntime:E` filter (empty).

Super-gate engineer packet:

- `Milestone: AHW-B13 verdict_pending`
- `Queue line (exact): narrow app-shell sidebar mutation APIs to explicit policy methods while preserving behavior`
- `Scope contract: behavior-neutral sidebar policy narrowing; B12 active-view ownership preserved; slot mapping + chrome freeze unchanged; no tabs`
- `Progress delta: chrome drawer sidebar apply open/closed; ChromeController.Host + bridge aligned; authority docs`
- `Validation: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass); python3 ops/android_terminal_host.py deploy (pass); adb cold start + AndroidRuntime:E (pass, empty)`
- `Engineer updates: Blocked by Archtect review needed: true`

Architect review verdict:

- `Review chunk: AHW-B13`
- `Verdict: accepted`
- `Commits reviewed: 83a29e7c, 4097fc95, cca93059, 76f8a02f`
- `Architect validation spot-check: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass)`
- `Engineer device validation accepted: deploy + AndroidRuntime:E smoke + activity start pass`
- `Findings carried forward: chrome drawer sidebar naming and policy seams are correct long-term for current single-slot chrome ownership. Next batch narrows IME visibility mutation to explicit policy methods for symmetry with active-view and sidebar ownership.`

`Milestone reached per docs, architect review required.`

---

### `AHW-B14` Chrome IME visibility mutation policy narrowing (`completed`)

Batch queue line (exact):

- narrow chrome IME visibility mutation APIs to explicit policy methods while preserving behavior

Batch purpose:

- remove broad boolean IME visibility mutation surfaces on chrome host seams
- preserve active-view and sidebar policy narrowing from B12/B13
- keep slot mapping/chrome freeze contracts unchanged

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

- chrome host seams expose explicit IME visibility policy methods (no broad boolean setter in product wiring)
- in-tree chrome/IME consumers use explicit policy methods only
- active-view ownership (B12) and sidebar ownership (B13) remain unchanged
- slot mapping seam, slot choke point, and chrome slot freeze remain unchanged
- single-slot runtime behavior remains unchanged
- docs reflect final ownership and naming shape
- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass at final seam boundary

Internal milestone cadence:

- Engineer executes `AHW14-M1` through `AHW14-M6` sequentially.
- Do not stop for architect review between internal milestones.
- Mark each internal milestone complete in this file as it lands.
- Stop only if the hard stop conditions in `ENGINEER_ENTRYPOINT.md` are hit or
  the `AHW-B14` super-gate is reached.

### `AHW14-M1` IME visibility mutation owner/callsite audit (`completed`)

Queue line (exact):

- audit IME visibility mutation entry points and classify policy-owned vs ad-hoc paths

Acceptance:

- enumerate IME visibility mutation entry points and callsites
- classify each mutation as policy-owned or ad-hoc
- define minimum behavior-neutral API narrowing cut

Progress delta:

- **Chrome seam (in scope):** `ChromeController.Host` exposes `currentImeVisible()` and
  `setImeVisible(boolean)` — generic boolean mutation. `ChromeController` calls
  `setImeVisible(shown || hasFocus)` on open, `setImeVisible(false)` on close, reads
  `currentImeVisible()` in toggle. `ChromeBridge` / `ChromeFactory` callbacks mirror this.
- **Out of scope (unchanged this batch):** activity `ZideActivity` field + `setImeVisible`,
  `WidgetAssembly.Host` `imeVisible`/`setImeVisible`, input/surface/viewport stacks — not
  chrome host `ChromeController.Host` narrowing targets.
- **Narrowing cut:** replace `setImeVisible(boolean)` / `currentImeVisible()` on
  `ChromeController.Host` with `chromeImeVisibilityPresent()`,
  `applyChromeImeVisibilityHidden()`, and `applyChromeImeVisibilityFromOpenAttempt(shown, hasFocus)`.

### `AHW14-M2` IME visibility policy API narrowing (`completed`)

Queue line (exact):

- replace broad IME visibility boolean setter with explicit policy methods

Acceptance:

- chrome host seam exposes explicit IME policy methods instead of generic boolean setter
- owner invariants remain explicit and behavior-neutral
- compile debug + release Java after code changes

Progress delta:

- `ChromeController.Host`: `chromeImeVisibilityPresent`, `applyChromeImeVisibilityHidden`,
  `applyChromeImeVisibilityFromOpenAttempt`; class Javadoc updated.

### `AHW14-M3` Consumer rewiring to IME policy API (`completed`)

Queue line (exact):

- rewire chrome/IME consumers to explicit IME policy APIs without behavior change

Acceptance:

- all in-tree IME visibility consumers use explicit policy methods
- no direct generic IME visibility mutation remains
- compile debug + release Java after code changes

Progress delta:

- `ChromeController`, `ChromeBridge` + `Callbacks`, `ChromeFactory` anonymous callbacks
  rewired; `ChromeFactory` still closes over activity `BooleanSupplier`/`Consumer` internally.

### `AHW14-M4` Contract docs lock (`completed`)

Queue line (exact):

- lock naming/structure/userland docs to IME visibility policy mutation ownership contract

Acceptance:

- host structure, naming contract, and userland contract match code shape
- active-view/sidebar ownership, slot mapping, and chrome freeze guidance remain unchanged

Progress delta:

- Structure app-shell invariants + table rows; naming contract bullet. USERLAND unchanged.

### `AHW14-M5` Queue/handoff/entrypoint sync (`completed_in_batch`)

Queue line (exact):

- keep queue, handoff, and engineer entrypoint aligned to AHW-B14 execution and super-gate stop

Acceptance:

- queue, handoff, and engineer entrypoint stay coherent through B14 super-gate
- super-gate stop condition and review packet contract are explicit

Progress delta:

- This file, `ENGINEER_ENTRYPOINT.md`, and `AGENT_HANDOFF.md` updated for `verdict_pending`.

### `AHW14-M6` Batch validation + review packet (`completed_in_batch`)

Queue line (exact):

- validate AHW-B14 end-to-end and publish the architect review packet

Acceptance:

- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass, or exact device-blocker output is recorded
- cold start smoke pass when a device is available
- engineer reports the full super-gate packet and stops for Architect review

Progress delta:

- Debug/release compile pass; deploy + activity start + `AndroidRuntime:E` filter (empty);
  cold start via `am force-stop` + `am start -W` (LaunchState `COLD`, ok).

Super-gate engineer packet:

- `Milestone: AHW-B14 verdict_pending`
- `Queue line (exact): narrow chrome IME visibility mutation APIs to explicit policy methods while preserving behavior`
- `Scope contract: ChromeController.Host IME seam only; B12/B13 unchanged; slot/chrome freeze unchanged; no tabs`
- `Progress delta: explicit chromeImeVisibility* + apply* on Host; bridge/factory aligned`
- `Validation: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass); python3 ops/android_terminal_host.py deploy (pass); adb activity start + AndroidRuntime:E (pass, empty); adb cold start (pass)`
- `Engineer updates: Blocked by Archtect review needed: true`

Architect review verdict:

- `Review chunk: AHW-B14`
- `Verdict: accepted`
- `Commits reviewed: fc520a93, e42fdc0b, 52c30a69, 182d236d, 47fdcbf2`
- `Architect validation spot-check: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass)`
- `Engineer device validation accepted: deploy + AndroidRuntime:E smoke + cold start pass`
- `Findings carried forward: keep chrome IME seam naming (`chromeImeVisibility*` + `applyChromeImeVisibility*`) as the long-term chrome host contract. Next batch should remove raw BooleanSupplier/Consumer closure pressure from ChromeFactory by introducing an explicit harness-owned IME policy input seam.`

`Milestone reached per docs, architect review required.`

---

### `AHW-B15` Chrome IME policy input ownership narrowing (`completed`)

Batch queue line (exact):

- narrow chrome IME policy inputs to explicit harness-owned seams while preserving behavior

Batch purpose:

- remove raw `BooleanSupplier` / `Consumer<Boolean>` closure pressure from `ChromeFactory`
- preserve B14 chrome IME host policy method surface unchanged
- keep active-view/sidebar ownership, slot mapping, and chrome freeze contracts unchanged

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

- `ChromeFactory` no longer wires IME policy via raw boolean suppliers/consumers
- chrome IME policy input seam is explicit and harness-owned
- `ChromeController.Host` IME policy methods from B14 remain unchanged
- active-view/sidebar ownership, slot mapping seam, slot choke point, and chrome slot freeze remain unchanged
- single-slot runtime behavior remains unchanged
- docs reflect final ownership and naming shape
- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass at final seam boundary

Internal milestone cadence:

- Engineer executes `AHW15-M1` through `AHW15-M6` sequentially.
- Do not stop for architect review between internal milestones.
- Mark each internal milestone complete in this file as it lands.
- Stop only if the hard stop conditions in `ENGINEER_ENTRYPOINT.md` are hit or
  the `AHW-B15` super-gate is reached.

### `AHW15-M1` Chrome IME input seam audit (`completed`)

Queue line (exact):

- audit ChromeFactory IME policy input wiring and define explicit seam shape

Acceptance:

- enumerate current IME policy inputs/callsites in chrome assembly path
- identify minimum behavior-neutral explicit seam to replace raw closures
- document owner boundaries for the new seam

Progress delta:

- **Callsites:** `ChromeFactory.createChromeHostCallbacks` is the only constructor;
  single consumer `WidgetAssembly.createChromeController`, passing
  `host::imeVisible` and `host::setImeVisible` into anonymous `ChromeBridge.Callbacks`.
- **Surface path:** `SurfaceWidgetAssemblyCallbacks` still uses `host::imeVisible` on
  `WidgetAssembly.Host` — unchanged this batch (B15 is chrome factory input only).
- **Explicit seam:** introduce `ChromeImePolicyInput` in `host/ui` with the same three
  operations as the chrome host IME policy slice; `WidgetAssembly.Host` exposes
  `chromeImePolicyInput()` (default maps `imeVisible` / `setImeVisible`); `ChromeFactory`
  takes `ChromeImePolicyInput` instead of `BooleanSupplier` + `Consumer<Boolean>`.
- **Owner:** harness (`WidgetAssembly.Host`); `ChromeController.Host` / `ChromeBridge.Callbacks`
  method names stay as in B14.

### `AHW15-M2` Explicit IME policy input seam introduction (`completed`)

Queue line (exact):

- introduce explicit harness-owned chrome IME policy input seam in host/ui

Acceptance:

- add explicit seam type(s) used by ChromeFactory for IME policy input
- remove raw boolean supplier/consumer wiring from the new path
- compile debug + release Java after code changes

Progress delta:

- Added `ChromeImePolicyInput`; `WidgetAssembly.Host.chromeImePolicyInput()` default
  bridges `imeVisible` / `setImeVisible` to B14-named policy methods.

### `AHW15-M3` Chrome assembly rewiring to explicit seam (`completed`)

Queue line (exact):

- rewire ChromeFactory/Bridge assembly path to the explicit IME policy input seam

Acceptance:

- in-tree chrome assembly uses explicit IME policy input seam only
- `ChromeController.Host` IME policy methods remain unchanged
- compile debug + release Java after code changes

Progress delta:

- `ChromeFactory.createChromeHostCallbacks` takes `ChromeImePolicyInput`; anonymous
  callbacks delegate IME to it. `createChromeController` passes `host.chromeImePolicyInput()`.

### `AHW15-M4` Contract docs lock (`completed`)

Queue line (exact):

- lock naming/structure/userland docs to explicit chrome IME policy input ownership

Acceptance:

- host structure, naming contract, and userland contract match code shape
- B12/B13/B14 ownership boundaries and chrome freeze guidance remain unchanged

Progress delta:

- Structure invariants + `ChromeFactory` / `ChromeBridge` table rows; naming contract
  bullet. `USERLAND_HOST_CONTRACT` unchanged.

### `AHW15-M5` Queue/handoff/entrypoint sync (`completed_in_batch`)

Queue line (exact):

- keep queue, handoff, and engineer entrypoint aligned to AHW-B15 execution and super-gate stop

Acceptance:

- queue, handoff, and engineer entrypoint stay coherent through B15 super-gate
- super-gate stop condition and review packet contract are explicit

Progress delta:

- This file, `ENGINEER_ENTRYPOINT.md`, and `AGENT_HANDOFF.md` updated for `verdict_pending`.

### `AHW15-M6` Batch validation + review packet (`completed_in_batch`)

Queue line (exact):

- validate AHW-B15 end-to-end and publish the architect review packet

Acceptance:

- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass, or exact device-blocker output is recorded
- cold start smoke pass when a device is available
- engineer reports the full super-gate packet and stops for Architect review

Progress delta:

- Debug/release compile pass; deploy + activity start + `AndroidRuntime:E` (empty);
  cold start `force-stop` + `am start -W` (LaunchState `COLD`, ok).

Super-gate engineer packet:

- `Milestone: AHW-B15 verdict_pending`
- `Queue line (exact): narrow chrome IME policy inputs to explicit harness-owned seams while preserving behavior`
- `Scope contract: ChromeImePolicyInput + Host default; B14 chrome host method names unchanged; B12/B13/slot/chrome freeze unchanged`
- `Progress delta: ChromeFactory takes ChromeImePolicyInput; WidgetAssembly passes host.chromeImePolicyInput()`
- `Validation: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass); python3 ops/android_terminal_host.py deploy (pass); adb activity start + AndroidRuntime:E (pass, empty); adb cold start (pass)`
- `Engineer updates: Blocked by Archtect review needed: true`

Architect review verdict:

- `Review chunk: AHW-B15`
- `Verdict: accepted`
- `Commits reviewed: 7249ea31, a56286a1, e9738687, bd79d0b2`
- `Architect validation spot-check: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass)`
- `Architect runtime validation spot-check: python3 ops/android_terminal_host.py deploy (pass); adb cold start (pass); adb logcat -d -s AndroidRuntime:E (pass, empty)`
- `Engineer device validation accepted: deploy + AndroidRuntime:E smoke + cold start pass`
- `Findings carried forward: accept ChromeImePolicyInput as the long-term chrome assembly input seam. Next batch should remove primitive imeVisible/setImeVisible from WidgetAssembly.Host by introducing explicit non-chrome IME seams for remaining consumers.`

`Milestone reached per docs, architect review required.`

---

### `AHW-B16` Widget-host IME primitive seam narrowing (`completed`)

Batch queue line (exact):

- narrow WidgetAssembly.Host IME primitives to explicit non-chrome seams while preserving behavior

Batch purpose:

- remove primitive `imeVisible()` / `setImeVisible(boolean)` from `WidgetAssembly.Host`
- keep B14 chrome host IME seam and B15 `ChromeImePolicyInput` unchanged
- preserve existing behavior for surface/viewport/other non-chrome IME consumers

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

- `WidgetAssembly.Host` no longer exposes primitive `imeVisible`/`setImeVisible`
- remaining non-chrome IME consumers use explicit harness-owned seam(s)
- B14 `ChromeController.Host` and B15 `ChromeImePolicyInput` seams remain unchanged
- active-view/sidebar ownership, slot mapping seam, slot choke point, and chrome slot freeze remain unchanged
- single-slot runtime behavior remains unchanged
- docs reflect final ownership and naming shape
- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass at final seam boundary

Internal milestone cadence:

- Engineer executes `AHW16-M1` through `AHW16-M6` sequentially.
- Do not stop for architect review between internal milestones.
- Mark each internal milestone complete in this file as it lands.
- Stop only if the hard stop conditions in `ENGINEER_ENTRYPOINT.md` are hit or
  the `AHW-B16` super-gate is reached.

### `AHW16-M1` Widget-host IME primitive audit (`completed`)

Queue line (exact):

- audit WidgetAssembly.Host IME primitive callsites and define explicit replacement seams

Acceptance:

- enumerate all `WidgetAssembly.Host` IME primitive callsites
- classify chrome vs non-chrome ownership paths
- define minimum behavior-neutral explicit seam(s) for non-chrome paths

Progress delta:

- **Primitives on `WidgetAssembly.Host`:** `imeVisible()` / `setImeVisible(boolean)`; default
  `chromeImePolicyInput()` delegates to them.
- **Callsite — chrome:** `ChromeFactory.createChromeHostCallbacks` via `host.chromeImePolicyInput()` —
  keep **B15 `ChromeImePolicyInput`**; remove default and implement on activity host.
- **Callsite — surface:** `SurfaceWidgetAssemblyCallbacks` took `BooleanSupplier` from
  `host::imeVisible`; **SurfaceWidgetAssembly.Host** already names `currentImeVisible()`.
  Replace with explicit **`SurfaceWidgetHostImeVisibility`** (`currentImeVisible()` read-only).
- **Out of scope (unchanged):** `StatusViewAssembly.Host`, `InputAssembly.Host`, `ViewportController`
  (status/viewport wiring), `InputCallbacks` — not `WidgetAssembly.Host`.

### `AHW16-M2` Explicit non-chrome IME seam introduction (`completed`)

Queue line (exact):

- introduce explicit non-chrome IME seam(s) on WidgetAssembly.Host

Acceptance:

- add explicit seam type(s)/methods replacing primitive host IME pair
- keep chrome IME seams unchanged
- compile debug + release Java after code changes

Progress delta:

- **`SurfaceWidgetHostImeVisibility`** (`currentImeVisible()` read-only) on `Host`.
- **`chromeImePolicyInput()`** required on `Host` (default removed); B15/B14 types and names unchanged.

### `AHW16-M3` Widget assembly rewiring off primitives (`completed`)

Queue line (exact):

- rewire widget assembly non-chrome IME consumers to explicit seam(s)

Acceptance:

- no `WidgetAssembly.Host` primitive IME pair remains
- surface/viewport related behavior remains unchanged
- compile debug + release Java after code changes

Progress delta:

- **`SurfaceWidgetAssemblyCallbacks`** takes `SurfaceWidgetHostImeVisibility`; **`ZideActivity`**
  widget host implements both seams from activity `imeVisible` / `setImeVisible` (private).

### `AHW16-M4` Contract docs lock (`completed`)

Queue line (exact):

- lock naming/structure/userland docs to widget-host IME explicit seam ownership

Acceptance:

- host structure, naming contract, and userland contract match code shape
- B12-B15 ownership boundaries and chrome freeze guidance remain unchanged

Progress delta:

- `ANDROID_JAVA_HOST_STRUCTURE.md` app-shell invariants + table rows; `ANDROID_JAVA_NAMING_CONTRACT.md`
  bullet. `USERLAND_HOST_CONTRACT` unchanged.

### `AHW16-M5` Queue/handoff/entrypoint sync (`completed_in_batch`)

Queue line (exact):

- keep queue, handoff, and engineer entrypoint aligned to AHW-B16 execution and super-gate stop

Acceptance:

- queue, handoff, and engineer entrypoint stay coherent through B16 super-gate
- super-gate stop condition and review packet contract are explicit

Progress delta:

- This file, `ENGINEER_ENTRYPOINT.md`, and `AGENT_HANDOFF.md` updated for `verdict_pending`.

### `AHW16-M6` Batch validation + review packet (`completed_in_batch`)

Queue line (exact):

- validate AHW-B16 end-to-end and publish the architect review packet

Acceptance:

- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass, or exact device-blocker output is recorded
- cold start smoke pass when a device is available
- engineer reports the full super-gate packet and stops for Architect review

Progress delta:

- Debug/release compile pass; deploy + activity start + `AndroidRuntime:E` (empty);
  cold start `force-stop` + `am start -W` (LaunchState `COLD`, ok).

Super-gate engineer packet:

- `Milestone: AHW-B16 verdict_pending`
- `Queue line (exact): narrow WidgetAssembly.Host IME primitives to explicit non-chrome seams while preserving behavior`
- `Scope contract: SurfaceWidgetHostImeVisibility + explicit chromeImePolicyInput on Host; B14/B15 chrome types unchanged; slot/chrome freeze unchanged`
- `Progress delta: primitives removed from WidgetAssembly.Host; surface callbacks take named seam; ZideActivity implements both seams from private IME state`
- `Validation: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass); python3 ops/android_terminal_host.py deploy (pass); adb activity start + AndroidRuntime:E (pass, empty); adb cold start (pass)`
- `Engineer updates: Blocked by Archtect review needed: true`

Architect review verdict:

- `Review chunk: AHW-B16`
- `Verdict: accepted`
- `Commits reviewed: 7c300113, ff35ab2b, ba4a02e3, 89fa3ea3`
- `Architect validation spot-check: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass)`
- `Architect runtime validation spot-check: python3 ops/android_terminal_host.py deploy (pass); adb cold start (pass); adb logcat -d -s AndroidRuntime:E (pass, empty)`
- `Engineer device validation accepted: deploy + AndroidRuntime:E smoke + cold start pass`
- `Findings carried forward: accept SurfaceWidgetHostImeVisibility plus required chromeImePolicyInput() on WidgetAssembly.Host as the long-term widget-host IME shape. Next batch should consolidate activity IME state into an explicit carrier seam so host wiring stops repeating raw boolean/sink closures across non-widget owners.`

`Milestone reached per docs, architect review required.`

---

### `AHW-B17` Activity IME state carrier seam consolidation (`completed`)

Batch queue line (exact):

- consolidate activity IME state into an explicit harness carrier seam while preserving behavior

Batch purpose:

- replace repeated raw boolean/sink closure wiring from `ZideActivity` with one explicit IME state carrier seam
- keep B14 chrome host IME seam, B15 ChromeImePolicyInput, and B16 SurfaceWidgetHostImeVisibility unchanged
- preserve existing behavior for input/status/viewport/surface callers

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

- explicit activity-owned IME state carrier seam exists and is used by host wiring
- repeated raw `() -> imeVisible` / `this::setImeVisible` closure fan-out is removed where the seam applies
- B14/B15/B16 IME seam contracts remain unchanged
- active-view/sidebar ownership, slot mapping seam, slot choke point, and chrome slot freeze remain unchanged
- single-slot runtime behavior remains unchanged
- docs reflect final ownership and naming shape
- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass at final seam boundary

Internal milestone cadence:

- Engineer executes `AHW17-M1` through `AHW17-M6` sequentially.
- Do not stop for architect review between internal milestones.
- Mark each internal milestone complete in this file as it lands.
- Stop only if the hard stop conditions in `ENGINEER_ENTRYPOINT.md` are hit or
  the `AHW-B17` super-gate is reached.

### `AHW17-M1` Activity IME wiring audit (`completed`)

Queue line (exact):

- audit activity IME state reads/writes and define explicit carrier seam shape

Acceptance:

- enumerate current `imeVisible` reads/writes and closure pass-through callsites
- classify which callsites should consume one shared carrier seam
- define minimal behavior-neutral carrier API

Progress delta:

- **Field + sink:** `ZideActivity` holds `private boolean imeVisible` and `private void setImeVisible`
  (assign-only).
- **Callsites (same carrier):** `createStatusViewCallbacks` (`() -> imeVisible`, `this::setImeVisible`);
  `createInputCallbacks` (same); `WidgetAssembly.Host` (`() -> imeVisible`, anonymous
  `ChromeImePolicyInput` calling `ZideActivity.this.setImeVisible`).
- **Carrier shape:** `ProductHostImeState` in `host/ui` — holds boolean, `imeVisible()` /
  `setImeVisible`, implements `SurfaceWidgetHostImeVisibility`, exposes `chromeImePolicyInput()`;
  activity keeps one `final` instance and passes `productHostImeState::…` into status/input and
  host methods.

### `AHW17-M2` IME state carrier seam introduction (`completed`)

Queue line (exact):

- introduce explicit activity-owned IME state carrier seam in host/ui

Acceptance:

- add named seam type(s) for IME presence read + policy write
- wire seam creation in activity without behavior change
- compile debug + release Java after code changes

Progress delta:

- **`ProductHostImeState`** (`host/ui`): boolean + `imeVisible`/`setImeVisible`, implements
  `SurfaceWidgetHostImeVisibility`, **`chromeImePolicyInput()`** for chrome factory.

### `AHW17-M3` Host rewiring to carrier seam (`completed`)

Queue line (exact):

- rewire host assembly callsites to use the IME state carrier seam

Acceptance:

- target callsites consume the carrier seam instead of duplicated raw closures
- B14/B15/B16 seam interfaces and names remain unchanged
- compile debug + release Java after code changes

Progress delta:

- **`ZideActivity`:** one `final ProductHostImeState`; status/input callbacks and widget host
  delegate to **`productHostImeState::…`**; removed activity field + **`setImeVisible`** helper.

### `AHW17-M4` Contract docs lock (`completed`)

Queue line (exact):

- lock naming/structure/userland docs to activity IME carrier ownership

Acceptance:

- host structure, naming contract, and userland contract match code shape
- B12-B16 ownership boundaries and chrome freeze guidance remain unchanged

Progress delta:

- App-shell invariants + `ZideActivity` / `ProductHostImeState` table row; naming contract bullet.
  `USERLAND_HOST_CONTRACT` unchanged.

### `AHW17-M5` Queue/handoff/entrypoint sync (`completed_in_batch`)

Queue line (exact):

- keep queue, handoff, and engineer entrypoint aligned to AHW-B17 execution and super-gate stop

Acceptance:

- queue, handoff, and engineer entrypoint stay coherent through B17 super-gate
- super-gate stop condition and review packet contract are explicit

Progress delta:

- This file, `ENGINEER_ENTRYPOINT.md`, and `AGENT_HANDOFF.md` updated for `verdict_pending`.

### `AHW17-M6` Batch validation + review packet (`completed_in_batch`)

Queue line (exact):

- validate AHW-B17 end-to-end and publish the architect review packet

Acceptance:

- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass, or exact device-blocker output is recorded
- cold start smoke pass when a device is available
- engineer reports the full super-gate packet and stops for Architect review

Progress delta:

- Debug/release compile pass; deploy + activity start + `AndroidRuntime:E` (empty);
  cold start `force-stop` + `am start -W` (LaunchState `COLD`, ok).

Super-gate engineer packet:

- `Milestone: AHW-B17 verdict_pending`
- `Queue line (exact): consolidate activity IME state into an explicit harness carrier seam while preserving behavior`
- `Scope contract: ProductHostImeState; B14/B15/B16 unchanged; slot/chrome freeze unchanged`
- `Progress delta: one carrier; status/input/widget use productHostImeState::…; anonymous chrome policy moved into carrier`
- `Validation: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass); python3 ops/android_terminal_host.py deploy (pass); adb activity start + AndroidRuntime:E (pass, empty); adb cold start (pass)`
- `Engineer updates: Blocked by Archtect review needed: true`

Architect review verdict:

- `Review chunk: AHW-B17`
- `Verdict: accepted`
- `Commits reviewed: b88b0649, 07756083, 748d5132, 49c594aa`
- `Architect validation spot-check: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass)`
- `Architect runtime validation spot-check: python3 ops/android_terminal_host.py deploy (pass); adb cold start (pass); adb logcat -d -s AndroidRuntime:E (pass, empty)`
- `Engineer device validation accepted: deploy + AndroidRuntime:E smoke + cold start pass`
- `Findings carried forward: accept ProductHostImeState as the long-term activity IME carrier. Next batch should unify remaining host callback surfaces to consume an explicit IME state access seam instead of repeated BooleanSupplier/Consumer pairs.`

`Milestone reached per docs, architect review required.`

---

### `AHW-B18` Host IME callback seam unification (`verdict_pending`)

Batch queue line (exact):

- unify host callback IME wiring to explicit carrier-backed seams while preserving behavior

Batch purpose:

- reduce remaining raw BooleanSupplier/Consumer IME callback fan-out in host assemblies
- keep B14/B15/B16/B17 IME seams and naming unchanged
- preserve existing behavior for input/status/viewport/surface callers

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

- targeted host callback surfaces consume explicit IME state access seam(s), not repeated raw pairs
- B14/B15/B16/B17 seams remain unchanged in name/behavior
- active-view/sidebar ownership, slot mapping seam, slot choke point, and chrome slot freeze remain unchanged
- single-slot runtime behavior remains unchanged
- docs reflect final ownership and naming shape
- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass at final seam boundary

Internal milestone cadence:

- Engineer executes `AHW18-M1` through `AHW18-M6` sequentially.
- Do not stop for architect review between internal milestones.
- Mark each internal milestone complete in this file as it lands.
- Stop only if the hard stop conditions in `ENGINEER_ENTRYPOINT.md` are hit or
  the `AHW-B18` super-gate is reached.

### `AHW18-M1` Host IME callback fan-out audit (`completed`)

Queue line (exact):

- audit remaining host callback IME pairs and define explicit access seam target list

Acceptance:

- enumerate remaining raw IME read/write callback pair callsites in host assembly paths
- identify minimum explicit seam(s) to replace duplicated pairs
- document owner boundaries and out-of-scope paths

Progress delta:

- **Raw pairs:** `StatusViewCallbacks` (`BooleanSupplier` + `Consumer<Boolean>`); `ViewportCallbacks`
  (same); `InputCallbacks` + `InputAssembly.Host` (`currentImeVisible` / `setImeVisible` suppliers);
  `InputFactory` → `HardwareKeyboardHostCallbacks` / `ImeFocusRecoveryHostCallbacks` (BooleanSupplier paths).
- **Seam:** `HostImeStateAccess` (`imeVisible` / `setImeVisible`) implemented by `ProductHostImeState`;
  status/input/viewport adapters and `InputFactory` take one reference; `StatusViewAssembly.Host`
  exposes `hostImeStateAccess()` instead of primitive IME pair.
- **Out of scope:** `SurfaceWidgetHostImeVisibility`, `ChromeImePolicyInput`, `ChromeController.Host` (unchanged).

### `AHW18-M2` Explicit IME state access seam introduction (`completed`)

Queue line (exact):

- introduce explicit IME state access seam type(s) for host callback wiring

Acceptance:

- add seam type(s) that represent IME presence read + visibility write where required
- wire seam creation from ProductHostImeState without behavior changes
- compile debug + release Java after code changes

Progress delta:

- **`HostImeStateAccess`** in `host/ui`; **`ProductHostImeState`** implements it.

### `AHW18-M3` Host callback rewiring to explicit seam(s) (`completed`)

Queue line (exact):

- rewire targeted host callback constructors to consume explicit IME seam(s)

Acceptance:

- targeted callback paths no longer pass duplicated raw IME pairs
- B14/B15/B16/B17 seam interfaces and names remain unchanged
- compile debug + release Java after code changes

Progress delta:

- **`StatusViewAssembly.Host`:** `hostImeStateAccess()` replaces primitive IME pair; **`StatusViewCallbacks`**,
  **`ViewportCallbacks`** take **`HostImeStateAccess`**.
- **`InputAssembly.Host`:** `hostImeStateAccess()`; **`InputCallbacks`**, **`InputFactory`**,
  **`HardwareKeyboardHostCallbacks`**, **`ImeFocusRecoveryHostCallbacks`** unified.

### `AHW18-M4` Contract docs lock (`completed`)

Queue line (exact):

- lock naming/structure/userland docs to unified host IME callback seam ownership

Acceptance:

- host structure, naming contract, and userland contract match code shape
- B12-B17 ownership boundaries and chrome freeze guidance remain unchanged

Progress delta:

- App-shell invariants + table rows; naming contract bullet. `USERLAND_HOST_CONTRACT` unchanged.

### `AHW18-M5` Queue/handoff/entrypoint sync (`completed`)

Queue line (exact):

- keep queue, handoff, and engineer entrypoint aligned to AHW-B18 execution and super-gate stop

Acceptance:

- queue, handoff, and engineer entrypoint stay coherent through B18 super-gate
- super-gate stop condition and review packet contract are explicit

Progress delta:

- This file, `ENGINEER_ENTRYPOINT.md`, and `AGENT_HANDOFF.md` updated for `verdict_pending`.

### `AHW18-M6` Batch validation + review packet (`completed`)

Queue line (exact):

- validate AHW-B18 end-to-end and publish the architect review packet

Acceptance:

- debug and release Java compile pass
- deploy + `AndroidRuntime:E` smoke pass, or exact device-blocker output is recorded
- cold start smoke pass when a device is available
- engineer reports the full super-gate packet and stops for Architect review

Progress delta:

- Debug/release compile pass; deploy + activity start + `AndroidRuntime:E` (empty);
  cold start `force-stop` + `am start -W` (LaunchState `COLD`, ok).

Super-gate engineer packet:

- `Milestone: AHW-B18 verdict_pending`
- `Queue line (exact): unify host callback IME wiring to explicit carrier-backed seams while preserving behavior`
- `Scope contract: HostImeStateAccess; B14–B17 names unchanged; slot/chrome freeze unchanged`
- `Progress delta: StatusViewAssembly.Host + ViewportCallbacks + InputAssembly/InputFactory/input host callbacks`
- `Validation: ./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac (pass); ./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac (pass); python3 ops/android_terminal_host.py deploy (pass); adb activity start + AndroidRuntime:E (pass, empty); adb cold start (pass)`
- `Engineer updates: Blocked by Archtect review needed: true`

Review questions for Architect:

- Confirm `HostImeStateAccess` as the long-term host callback IME access seam (backed by `ProductHostImeState`).
- Confirm next macro batch after verdict.

`Milestone reached per docs, architect review required.`

## Guardrails

- No CI/pipeline/lint ceremony additions.
- No reintroduction of debug-view UI pathways.
- No compatibility shim kept only for migration convenience.
- Do not keep dual ownership if one side is clearly obsolete.

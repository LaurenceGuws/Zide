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
- Active macro batch: `AHW-B1` (`review_required`; architect review at batch super-gate).
- Internal milestones `AHW-M1` through `AHW-M5`: `completed_in_batch` (engineer wave landed; Architect owns gate).

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

### `AHW-B1` Harness backbone + widget portability macro batch (`review_required`)

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

## Guardrails

- No CI/pipeline/lint ceremony additions.
- No reintroduction of debug-view UI pathways.
- No compatibility shim kept only for migration convenience.
- Do not keep dual ownership if one side is clearly obsolete.

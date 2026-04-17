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
- **Active campaign:** **Android stabilization follow-through** (`ASF`) — close
  remaining operator-blocked RF_M5 matrix rows (IME/assist, touch gestures) with
  reproducible on-device evidence, without breaking harness/widget ownership
  boundaries. **`ASF-M1` runbook published;** operator pass/fill for
  cannot-verify rows remains optional follow-up matrix edits.

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
- Active campaign: **Android stabilization follow-through** (`ASF`).
- Completed milestone: `ASF-M1` (operator matrix closure — IME + gesture rows).
- Active milestone: *none — next milestone pending architect queue update.*

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

## Guardrails

- No CI/pipeline/lint ceremony additions.
- No reintroduction of debug-view UI pathways.
- No compatibility shim kept only for migration convenience.
- Do not keep dual ownership if one side is clearly obsolete.

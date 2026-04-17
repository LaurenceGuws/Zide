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
- `Blocked by review needed: true|false`

Milestone boundary line:

`Milestone reached per docs, architect review required.`

Validation commands:

- `./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac`
- `python3 ops/android_terminal_host.py deploy`
- `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E`

## Milestone Plan (Sequential, Gated)

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

### `RF-M1` Harness Boundary Lock (`review_required`)

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
- `Blocked by review needed: false`

`Milestone reached per docs, architect review required.`

---

### `RF-M2` Widget Boundary Lock (`review_required`)

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
- `Blocked by review needed: false`

`Milestone reached per docs, architect review required.`

---

### `RF-M3` Userland Mobility Lock (`pending`)

Queue line (exact):

- make userland orchestration movable and widget-agnostic

Scope:

- `host/userland` + `userland/*` seams only

Tasks:

- [ ] isolate package-doctor/install/restart orchestration behind harness-owned entrypoints
- [ ] remove any userland dependency on widget-specific runtime symbols
- [ ] document stable userland contract for future IDE/editor modes

Gate:

- userland orchestration has no widget-only ownership assumptions
- compile + deploy + runtime smoke clean

---

### `RF-M4` AppShell Navigation + State Backbone (`pending`)

Queue line (exact):

- harden app-shell left sidebar/navigation/view-state ownership for multi-view and future terminal tabs

Scope:

- harness app-shell only

Tasks:

- [ ] define explicit app-shell view navigation state owner
- [ ] define per-view state owner seam (tab-ready shape)
- [ ] enforce theming propagation contract across app shell

Gate:

- app-shell navigation/state ownership explicit and centralized
- compile + deploy + runtime smoke clean

---

### `RF-M5` Stabilization Matrix (`pending`)

Queue line (exact):

- execute stability matrix and close refocus campaign with review gate

Scope:

- manual validation only, no opportunistic refactors

Tasks:

- [ ] lifecycle matrix: create/start/resume/pause/stop/new-intent
- [ ] input matrix: IME + hardware keyboard + selection gestures
- [ ] userland matrix: readiness/install/update/package-doctor/restart
- [ ] surface matrix: surface create/change/destroy/redraw/viewport updates

Gate:

- matrix recorded with pass/fail and follow-up deltas
- milestone marked `review_required`

## Guardrails

- No CI/pipeline/lint ceremony additions.
- No reintroduction of debug-view UI pathways.
- No compatibility shim kept only for migration convenience.
- Do not keep dual ownership if one side is clearly obsolete.

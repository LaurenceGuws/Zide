# Android Engineer Entrypoint (Dual Mode)

Execution-only brief for the engineer session.

## Mode + Roles

- Mode: `dual`
- Engineer: execution only
- Architect: scope, gating, review, and responsibility for the batch definition
- User: messenger/product direction; do not make the user restate workflow rules

Do not redefine scope or reorder tickets. Execute the active macro batch from
`docs/todo/android/implementation.md`.

## Vision + Authority

Vision source:

- `refocus_android.txt` (read-only scratchpad context; do not commit it)

Execution authority, in order:

1. `docs/todo/android/implementation.md`
2. `docs/AGENT_HANDOFF.md`
3. `app_architecture/platform/android/ANDROID_REFOCUS_CASE_STUDY.md`
4. `app_architecture/platform/android/ANDROID_JAVA_HOST_STRUCTURE.md`
5. `app_architecture/platform/android/ANDROID_JAVA_NAMING_CONTRACT.md`
6. `app_architecture/platform/android/USERLAND_HOST_CONTRACT.md`
7. `AGENTS.md`
8. `docs/WORKFLOW.md`

If these disagree on active work, `docs/todo/android/implementation.md` wins and
you must report the mismatch.

## Current Target

`AHW-B6` is `in_progress`: slot-scoped host API foundation while preserving
single-slot runtime behavior.

Batch queue line (exact):

- introduce slot-scoped host API seams for terminal widget composition while preserving single-slot runtime behavior

## Core Boundary Rule

The batch exists to make slot identity compile-visible in host seams while
keeping current single-slot behavior unchanged.

- Android Harness owns platform ceremony, app-shell layout/styling/theming,
  navigation/view state, userland orchestration, and widget instance hosting.
- Terminal Widget owns portable terminal surface/input/selection/gesture/FFI/GLES
  seams.
- Userland stays movable for future IDE/editor modes and must not depend on
  widget/surface/controller internals.
- `TerminalWidgetCompositionAssembly` remains the join owner for
  `InteractionAssembly.Result` + `WidgetAssembly.Result` into
  `TerminalWidgetInstance`.
- `WidgetAssembly.Result` remains widget/chrome assembly output; it is not the
  terminal-instance factory by itself.

## Required Direction From Architect Review (AHW-B6 baseline)

- `AHW-B5` is accepted.
- `TerminalWidgetCompositionAssembly.compose` remains `TerminalWidgetInstance`
  only; shell/chrome/view-mode outputs stay on `WidgetAssembly.Result`.
- `ZideActivity` reading widget shell/chrome/view-mode next to `compose` is
  acceptable; do not introduce a second owner bundle without a clear win.
- Remove duplicate `ActivityViewBindings.from(...)` lookup if ownership remains
  clean.
- Make slot identity explicit in host APIs where future multi-terminal hosting
  needs it, but do not implement tab product behavior.

## Internal Milestones

Execute in order and mark progress in `docs/todo/android/implementation.md`.

- `AHW6-M1`: audit single-slot assumptions across composition, widget host, and
  activity wiring seams.
- `AHW6-M2`: remove duplicate `ActivityViewBindings` lookup while keeping
  ownership clean.
- `AHW6-M3`: introduce a harness-owned slot identity type for host APIs
  (single slot only for now).
- `AHW6-M4`: thread slot identity through composition/wiring seams where needed.
- `AHW6-M5`: update structure/naming/userland host authority docs.
- `AHW6-M6`: run validation and publish the super-gate review packet.

## Allowed Work

Allowed code roots:

- `android/terminal-host/app/src/main/java/uk/laurencegouws/terminal/**`

Allowed docs:

- `docs/todo/android/implementation.md`
- `docs/todo/android/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`
- `app_architecture/platform/android/ANDROID_JAVA_HOST_STRUCTURE.md`
- `app_architecture/platform/android/ANDROID_JAVA_NAMING_CONTRACT.md`
- `app_architecture/platform/android/USERLAND_HOST_CONTRACT.md`

If a required change falls outside these paths, stop and report a blocker.

## Non-Goals

- No terminal tabs UI/product behavior.
- No tab persistence/session switching.
- No terminal-core behavior changes.
- No shared renderer/backend refactor.
- No app-shell UI redesign.
- No selection/IME/gesture behavior changes except compile-preserving seam rewiring.
- No debug-view UI resurrection.
- No CI/pipeline/lint additions.
- No broad rename campaign.
- No ASF operator-evidence churn unless new evidence is provided.
- No compatibility shim kept only to avoid a clean cut.
- No behavior changes inside extraction-only commits.

## Execution Loop

For each coherent cut:

1. Name the internal milestone and queue line you are executing.
2. Read the directly relevant classes before editing.
3. Make the smallest behavior-preserving change that removes ownership pressure.
4. Run at least the Java compile gate after code cuts.
5. Commit the validated cut with a precise message.
6. Update queue/docs when a milestone checkpoint or ownership contract changes.
7. Continue to the next cut without waiting for architect review unless a hard
   stop condition is hit.

Compile every code cut with at least:

- `./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac`
- `./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac`

Run seam-boundary/device validation at meaningful boundaries and at the final
super-gate:

- `python3 ops/android_terminal_host.py deploy`
- `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E`
- `adb shell am force-stop uk.laurencegouws.zide && adb shell am start -W -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity`

If no Android device is available, continue through compile-validated cuts and
record device validation as blocked with exact command/output. Do not invent a
pass.

## Commit Rules

This batch is architect-approved for autonomous Engineer commits after local
validation.

- Commit small, coherent checkpoints.
- Do not amend or squash unless the Architect explicitly requests it later.
- Keep doc-only updates separate from code when practical.
- Each code commit must leave Java debug + release compile green.
- Never commit `refocus_android.txt`.

## Hard Stop Conditions

Stop immediately and report:

`Blocked by Archtect review needed: true`

when:

- a required change needs files outside the allowed paths
- architecture docs conflict with code reality in a way that changes scope
- validation fails and cannot be fixed inside the active internal milestone
- a behavior change is required where the queue only allows extraction
- terminal-core/shared-renderer work appears necessary
- implementing terminal tabs/product behavior becomes necessary to proceed
- the `AHW-B6` super-gate is reached

Otherwise continue autonomously with:

`Blocked by Archtect review needed: false`

## Super-Gate Review Packet

At `AHW-B6` super-gate, report:

- review chunk name: `AHW-B6`
- internal milestones completed
- commit list, oldest to newest
- files changed grouped by Harness / Widget / Userland / Docs
- validation commands and pass/fail
- remaining risks
- exact review questions for Architect

## Response Contract (Every Response)

Use exact headers:

- `#DONE`
- `#OUTSTANDING`
- `COMMITS`
- `VALIDATION`
- `Blocked by Archtect review needed: true|false`

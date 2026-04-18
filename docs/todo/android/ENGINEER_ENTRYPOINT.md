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

`AHW-B23` is at **super-gate** (engineer execution complete; awaiting architect verdict on the review packet below). Do not start the next macro batch until the Architect accepts the gate and refocuses `docs/todo/android/implementation.md`.

Active batch queue line (exact):

- reduce ZideActivity startup-sequence method pressure by extracting a named onCreate startup coordinator while preserving behavior and startup order

## Core Boundary Rule

This batch exists to reduce ZideActivity startup-sequence method pressure while
preserving existing IME/slot/chrome/widget/startup-wiring contracts and behavior.

- Android Harness owns platform ceremony, app-shell layout/styling/theming,
  navigation/view state, userland orchestration, and widget instance hosting.
- Terminal Widget owns portable terminal surface/input/selection/gesture/FFI/GLES
  seams.
- Userland stays movable for future IDE/editor modes and must not depend on
  widget/surface/controller internals.
- `TerminalWidgetCompositionAssembly` remains the join owner for
  `InteractionAssembly.Result` + `WidgetSurfaceHostJoin` into
  `TerminalWidgetInstance`.
- `WidgetAssembly.Result` remains widget assembly output (`harnessHost` +
  `surfaceJoin`); it is not the terminal-instance factory by itself.

## Required Direction From Architect Review (post-AHW-B22)

- `AHW-B22` is accepted.
- Keep harness vs surface split (`WidgetAssembly.Result.harnessHost` + `surfaceJoin`) as the baseline.
- Freeze additional keep-screen-on seam work beyond B20 unless explicitly re-opened by product direction.
- Execute `AHW-B23` as a non keep-screen-on batch.
- Keep `ProductHostActivityStartupWiring`, `ProductTerminalLifecycleHost`, and `ProductTerminalWidgetAssemblyHost` ownership from B22 unchanged.
- Keep `ProductHostKeepScreenOnPolicy` as the long-term owner of terminal keep-screen-on default policy.
- Keep `HostImeStateAccess` as the long-term host callback IME seam backed by `ProductHostImeState`.
- Keep `ProductHostImeState` as the long-term activity IME carrier.
- Keep `SurfaceWidgetHostImeVisibility` + required `chromeImePolicyInput()` as the long-term widget-host IME shape.
- Keep `ChromeImePolicyInput` as the long-term chrome assembly input seam.
- Keep `chromeImeVisibility*` + `applyChromeImeVisibility*` naming as the long-term chrome host seam.
- Keep chrome drawer sidebar policy naming (`chromeDrawerSidebar*` + `apply*`) as the long-term seam.
- Keep no public arbitrary shell-view setter until multi-view policy is explicitly scoped.
- Keep null-reject semantics as the harness boundary for shell-view ids.
- Keep `AppShellNavigation.forProductTerminalSlot` / `applyProductTerminalShellViewActive`
  split as app-shell contract baseline.
- Keep `ProductTerminalSlotShellMapping` as canonical slot→shell-view seam.
- Keep `checkActiveProductTerminalSlot` as active-slot choke point until
  second-slot policy is explicitly scoped.
- Keep slot identity on host seams + compose argument; do not add slot to
  `InteractionAssembly.Result` yet.
- Keep chrome slot-agnostic in this batch; do not thread slot into chrome
  construction until per-slot chrome policy is scoped.
- No tab/multi-instance product behavior unless a new batch scopes it.

## Internal Milestones

Execute `AHW23-M1` through `AHW23-M6` sequentially; do not stop before the
`AHW-B23` super-gate unless a hard stop condition is hit.

Execute in order and mark progress in `docs/todo/android/implementation.md`.

- `AHW23-M1`: audit runOnCreateStartupSequence dependencies and define coordinator extraction boundaries.
- `AHW23-M2`: introduce a named host/ui startup coordinator seam for onCreate sequence execution.
- `AHW23-M3`: delegate runOnCreate startup sequence from ZideActivity to the extracted coordinator without order changes.
- `AHW23-M4`: lock authority docs to coordinator-owned onCreate sequence orchestration shape.
- `AHW23-M5`: keep queue/handoff/entrypoint aligned to B23 super-gate.
- `AHW23-M6`: run validation and publish super-gate review packet.

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
- No keep-screen-on follow-up implementation unless explicitly re-opened by product direction.
- No terminal tabs product behavior; this is host API shaping only.
- No startup order change.
- No debug-view UI resurrection.
- No CI/pipeline/lint additions.
- No broad rename campaign.
- No ASF operator-evidence churn unless new evidence is provided.
- No compatibility shim kept only to avoid a clean cut.
- No external-fork compatibility work or framing; keep one clean in-repo path only.
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
- the `AHW-B23` super-gate is reached

Otherwise continue autonomously with:

`Blocked by Archtect review needed: false`

## Super-Gate Review Packet

At `AHW-B23` super-gate, report:

- review chunk name: `AHW-B23`
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

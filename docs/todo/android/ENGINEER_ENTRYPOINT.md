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

`APX-B18` is `blocked_cross_repo` in `docs/todo/android/implementation.md`.
PM release `android-dev-2026.04.18.162659` exposes `zide-android-catalog-smoke`,
but staging fails because `runtime_support_links` requires creating
`/data/data/zide.embed`, which the app sandbox cannot create.

Active batch queue line (exact):

- prove the released zide-pm Android test-binary candidate can be selected, installed, and verified on-device through the explicit Android install lifecycle, then publish the Android refocus closure recommendation

Parallel-lane note:

- `../zide-mobile-pm` may progress in parallel under a separate engineer session; this Android engineer session stays focused on APX-B18 only.

## Core Boundary Rule

This batch exists to start product expansion on top of closed AHW ownership
boundaries while preserving current single-terminal behavior.

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

## Required Direction From Architect Review (post-AHW-B26)

- `APX-B1` is accepted: `AppShellTerminalSelectionPolicy` (selection) and `AppShellTerminalViewPolicy` (activation) are split; default remains single `PRIMARY` terminal path.
- `APX-B2` adds `DeclaredTerminalWidgetSlotCatalog` (PRIMARY-only declared set); `AppShellTerminalSelectionPolicy` requires catalog membership before `checkActiveProductTerminalSlot`; no multi-slot runtime.
- `APX-B3` is accepted: one `AppShellTerminalHostSelectionContext` per startup path with fail-fast host/context slot invariant.
- `APX-B4` introduces explicit host-declared-slot source ownership and routes startup context construction through `forProductHostStartup`.
- `APX-B4` is accepted: `ProductHostDeclaredTerminalWidgetSlot` is now the explicit source feeding startup context construction.
- `APX-B5` is accepted: immutable declared-slot value type now owns startup source semantics.
- `APX-B6` is accepted: declared-slot value is propagated across interaction/widget/composition startup seams.
- `APX-B7` is accepted: enum conversion choke point is centralized on declared-slot value seam.
- `APX-B8` is accepted: tab-state slice 1 (harness tab index state; session controls live in app-shell sidebar after APX-B11) and `ZIDE_PM_HOST_PLATFORM=android` export are in place.
- `APX-B9` is accepted: tab selection now drives native restart + userland refresh, and Packages flow proved Android-side `zide-pm install`.
- `APX-B10` is accepted: doctor path is read-only and test-binary install mutation is explicit lifecycle-owned with dedicated sidebar trigger.
- `APX-B11` is accepted: session/tab controls are AppShell sidebar navigation (not inline above assist); assist strip stays input-only; APX-B10 contracts preserved.
- `APX-B12` is reviewed with changes requested: hardcoded package-id coupling removed, but candidate narrowing is incomplete because list-available output can include non-edge ids.
- `APX-B13` is accepted: edge install candidate narrowing (`zide-android-*`) and explicit selected/no-candidate status are in place.
- `APX-B14` is accepted: selected terminal tab index now persists across activity recreation via seeded navigation state.
- `APX-B15` is accepted: tab metadata is policy-owned through `ProductTerminalTabDescriptor`/`AppShellTerminalViewPolicy` and chrome consumes descriptors.
- `APX-B16` is accepted: selected tab persists by stable descriptor id and restores to seed index via descriptor lookup.
- `APX-B17` is accepted: Android consumes `runtime_support_links` metadata from staged prefix manifests and materializes declared links before runtime activation.
- `APX-B18` is blocked: current `../zide-mobile-pm` release `android-dev-2026.04.18.162659` includes `zide-android-catalog-smoke`, but its runtime support link bridge is not materializable by the Android app sandbox. Android remains pinned to the last stageable dev prefix until PM republishes a compatible release.
- `zide-mobile-pm` foundation work is allowed in parallel, but APX-B18 remains the primary in-repo execution lane here.
- `AHW-B26` is accepted and `AHW` is closed.
- Keep harness vs surface split (`WidgetAssembly.Result.harnessHost` + `surfaceJoin`) as the baseline.
- Freeze additional keep-screen-on seam work beyond B20 unless explicitly re-opened by product direction.
- Execute `APX-B18` as a non keep-screen-on batch.
- Keep `ProductHostActivityStartupWiring`, `ProductTerminalLifecycleHost`, and `ProductTerminalWidgetAssemblyHost` ownership from B22 unchanged.
- Keep `ProductHostOnCreateStartupCoordinator` + `ProductHostOnCreateStartupSteps` as the startup choreography seam from B23.
- Keep `AppShellTerminalViewPolicy` as explicit app-shell terminal-view policy seam; no public `appShellNavigation()` accessor on that type.
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
- `APX-B18` must preserve APX-B17 runtime_support_links materialization, APX-B11 sidebar session-navigation, APX-B10 doctor/install split, APX-B13 edge-install list parsing, and APX-B16 stable-id persistence while proving the released Android test-binary install path.

## Internal Milestones

Execute `APX18-M1` through `APX18-M6` sequentially; do not stop before the
`APX-B18` super-gate unless a hard stop condition is hit.

Commit cadence expectation for this macro batch:

- target **5–10 coherent validated commits** before super-gate handoff
- do not stop after 1–2 commits if the active batch still has clear in-scope work

Execute in order and mark progress in `docs/todo/android/implementation.md`.

- `APX18-M1`: audit the current zide-pm released manifest, Android list-available parsing, install lifecycle telemetry, and device-verification surfaces for a real test-binary install proof.
- `APX18-M2`: add or tighten the minimal Android-side install verification/status surface needed for the real test-binary proof.
- `APX18-M3`: run the explicit Android install lifecycle on device against the current released zide-pm dev manifest and verify the installed test binary.
- `APX18-M4`: verify APX-B17 runtime_support_links materialization still applies after the real test-binary install path.
- `APX18-M5`: update authority docs, queue, handoff, and this entrypoint with Android refocus closure recommendation and remaining non-blocking follow-up list.
- `APX18-M6`: validation ladder + architect review packet with closure recommendation.

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

- No dual-PTY/session-persistence implementation in this batch.
- No terminal-core behavior changes.
- No shared renderer/backend refactor.
- No app-shell UI redesign.
- No keep-screen-on follow-up implementation unless explicitly re-opened by product direction.
- No startup order change.
- No debug-view UI resurrection.
- No CI/pipeline/lint additions.
- No broad rename campaign.
- No ASF operator-evidence churn unless new evidence is provided.
- No compatibility shim kept only to avoid a clean cut.
- No external-fork compatibility work or framing; keep one clean in-repo path only.
- No behavior changes inside extraction-only commits.
- No edits in `../zide-mobile-pm` from this session. Resume only after PM publishes a release whose `runtime_support_links` can be materialized by `run-as uk.laurencegouws.zide`.

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
- Target 5–10 validated commits per macro batch before architect super-gate
  unless blocked by a hard stop condition.
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
- the `APX-B18` super-gate is reached

Otherwise continue autonomously with:

`Blocked by Archtect review needed: false`

## Super-Gate Review Packet

At `APX-B18` super-gate, report:

- review chunk name: `APX-B18`
- internal milestones completed
- commit list, oldest to newest
- files changed grouped by Harness / Widget / Userland / Docs
- validation commands and pass/fail
- device proof for selected `zide-android-*` package id, installed file path, and executable mode
- Android refocus closure recommendation
- remaining risks
- exact review questions for Architect

## Response Contract (Every Response)

Use exact headers:

- `LABELS`
- `#DONE`
- `#OUTSTANDING`
- `COMMITS`
- `VALIDATION`
- `Blocked by Archtect review needed: true|false`

`LABELS` must include:

- `Lane: android_apx`
- `Batch: APX-Bxx`
- `Gate: in_progress|super_gate`
- `Focus: <one-line>`
- `Blockers: none|<summary>`

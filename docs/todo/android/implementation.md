# Android Terminal Queue

Active Android plan/todo/workflow. This is the only live queue document for
Android terminal work.

## Document Roles

- This file: active `focus`, `todo`, and `workflow`.
- `ANDROID_JAVA_HOST_STRUCTURE.md`: Java ownership and structure contract.
- `ANDROID_JAVA_NAMING_CONTRACT.md`: Java naming glossary and grammar.
- `ANDROID_ZIG_BRIDGE_NAMING_CONTRACT.md`: Zig bridge naming grammar aligned
  to the Java glossary.
- `ANDROID_SHELL_BRINGUP_PLAN.md`: closed shell-readiness baseline record and decisions.
- `ANDROID_TERMINAL_HOST_PLAN.md`: long-lived architecture constraints.

Do not duplicate active queue content into owner docs.

## Scope

In scope:

- Android-owned terminal behavior and host/runtime integration
- product interaction behavior required for daily terminal use
- Android pressure that exposes shared renderer/runtime blockers

Out of scope:

- speculative backend work without a current Android blocker
- generic hygiene that does not unblock current Android work
- rewriting closed shell-readiness baseline history as active tasks

## Current Focus

`AN-A1` Interactive Neovim terminal baseline quality.

Focus goals:

- prioritize cleanup, refactor, and standardization over expansion
- keep interactive terminal behavior stable under real usage
- keep `ZideTerminalActivity` as wiring, not policy
- keep Android-native interaction ownership clear (gesture/chrome/selection)

## Cleanup Campaign Charter (Authority)

This section is the single source of truth for the active Android cleanup campaign.

Goal:

- aggressively reduce Android host complexity while preserving behavior
- thin `ZideTerminalActivity` toward composition-root ownership
- reduce callback-surface pressure without wrapper inflation

Issue class execution order (strict):

1. ownership seams (`ZideTerminalActivity` -> existing owners)
2. callback pressure reduction (constructor/callback surface)
3. naming continuation (Readiness/event vocabulary consistency)
4. dead abstraction cleanup (delete relay-only indirection)
5. lightweight doc checkpoints (every 5-10 refactor commits)

Hard rules:

- no new pass-through wrappers unless owner dependency count drops measurably
- each commit must remain compileable and deployable
- no lint/process-ceremony additions
- no unrelated-lane changes
- do not add new `ChromeController` / `SurfaceController` single-use accessor
  seams; accept a helper only if it eliminates duplicated policy logic or
  removes cross-domain coupling
- the next ten commits that touch `ChromeController` or `SurfaceController`
  must be net simplification: fewer methods, fields, or dependencies in the
  touched class than before the change (merge duplicate policy, delete redundant
  indirection), not rename-only ceremony
- queue updates under this campaign describe outcomes (what got simpler or
  what coupling dropped), not inventories of new helper or method names

Commit and validation rules:

- one logical cut per commit, refactor-only unless explicitly scoped
- default commit size: small (roughly 20-120 LOC), atomic larger for rename sweeps
- commit prefixes: `refactor(android):` and `docs(android):`
- validate every commit with:
  `./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac`
- run deploy + launch + `AndroidRuntime:E` smoke every 5-10 commits or seam boundary cut
- campaign doc checkpoints: add or extend queue notes every 3-5 refactor commits
  (one `docs(android):` batch per mini-wave), not after every refactor commit, unless
  the `Next:` line intentionally advances

Success metrics:

- materially reduce `ZideTerminalActivity` size and direct responsibilities
- reduce callback surface in at least two callback-heavy classes
- keep compile/deploy green through the campaign
- keep docs progress-based (no intent-only checkpoints)

## Charter Direction (Interpretation Rule)

This removes ambiguity between campaign guidance and queue execution.

- The charter defines direction and quality constraints.
- `Active TODO` defines execution order.
- The explicit `Next:` line under the active TODO item is binding for the next
  code cut.
- Do not substitute a "charter direction" interpretation for the explicit
  `Next:` line.
- If the current work does not match the explicit `Next:` line, stop and
  report a mismatch before code edits.

Agent reporting contract (mandatory for cleanup campaign updates):

- `Commit:` `<hash> <subject>`
- `Queue line (exact):` quote exact `Next:` line used for the cut
- `Completed cut:` one concrete outcome (behavior preserved and what
  simplified—for example fewer methods on the touched class or duplicated
  policy merged), not a list of new helper names
- `Files touched:` concrete paths
- `Validation:` exact command list + pass/fail
- `Next work:` exact current `Next:` line after progress update

## Active TODO

1. Continue cleanup/refactor cuts only where methods still own policy.
   - Completed: callback wiring hygiene pass in `ZideTerminalActivity` now uses
     named setter/getter/host helpers and removes non-trivial inline callback
     lambdas in assembly factories.
   - Completed: helper ordering is grouped by role
     (`host accessors`, `state snapshots`, `state setters`, `runtime actions`)
     so assembly-readability improvements remain scan-friendly.
   - Completed: high-signal callback supplier extractions are complete; remaining
     callback suppliers are intentionally trivial one-liners.
   - Completed: lifecycle/dispatch/startup policy extractions landed in
     `ZideTerminalActivity` (`onResume` debug intent flags, dispatch-key guard,
     and initial readiness-state load now use named helpers).
   - Completed: direct-input override routing cleanup landed
     (`sendDirectText` now routes through a named codepoint iteration helper).
   - Completed: direct-input native-ready guard is now shared via
     `canSendDirectInput()` across direct-input overrides.
   - Completed: activity lifecycle/input overrides now route through named
     helper seams; remaining inline logic is intentionally trivial or contract
     owned by downstream controllers.
   - Next: primary cleanup for Java host ownership continues under item 2
     below (`ZideTerminalActivity` `create*Callbacks()` net simplification).
2. Keep Java ownership boundaries aligned with
   `ANDROID_JAVA_HOST_STRUCTURE.md`.
   - Completed: chrome/surface ownership cleanup wave is stabilized and frozen;
     future changes there require an explicit queue re-open.
   - Completed: activity wiring cleanup waves reduced
     `ZideTerminalActivity.java` from ~778 to ~618 lines while keeping policy in
     owning controllers and preserving runtime behavior.
   - Completed: callback/assembly contract cleanup removed broad `nativeLoaded`
     pass-through fan-out and reduced constructor pressure across interaction,
     input, session, status, workflow, runtime, and widget seams.
   - Completed: callback-type normalization moved stable callback inputs to
     concrete references while preserving lazy suppliers for dynamic/lifecycle
     state; one unsafe eager-capture attempt was reverted after runtime NPE and
     validated clean.
   - Completed: current adapter lane keeps net deletions and runtime validation
     discipline (compile every refactor, deploy + `AndroidRuntime:E` cadence).
  - Completed: hotspot reassessment wave continued with behavior-preserving
    constructor/callback pressure reduction across startup/status/widget seams:
    `UiStartup` dropped a dedicated debug-view callback seam in favor of
    `ViewModeController` ownership, `StatusView` now sources surface snapshots
    from assembly-owned reader state (single source), and
    `WidgetAssembly`/`WidgetCallbacks` removed duplicate surface-bridge callback
    fan-out by deriving product-shell surface view from the assembled
    surface-widget bridge.
  - Completed: latest mini-wave net deletion trend is restored
    (`+16/-56` across three refactor commits) while preserving compile/deploy
    safety checks (compile each commit; deploy + clean `AndroidRuntime:E` smoke
    after the second commit in this wave).
  - Completed: planning-only `TerminalSelectionController` seam audit
    established the next extraction queue without behavior changes:
    (a) selection-drag/autoscroll loop, (b) selection-handle geometry/sync,
    and (c) action-mode + clipboard flow. Audit conclusion remains
    contract-aligned: keep selection monolithic until one of those sub-seams is
    lifted in a behavior-preserving cut with replay/validation authority.
   - Next: hotspot reassessment execution order is now:
     1) net-simplify `WidgetCallbacks` / `WidgetAssembly` constructor and field
        pressure (one-source dedupe, no new wrappers),
     2) normalize remaining stable-vs-lazy callback contracts in
        `ProductRuntimeHostCallbacks`, `UiStartupCallbacks`, and
        `StatusViewCallbacks` (behavior-preserving),
     3) once adapter pressure stabilizes, perform a planning-only
        `TerminalSelectionController` seam audit (no behavior split yet).
     `ChromeController` / `SurfaceController` remain frozen until this `Next:`
     line is intentionally advanced.
3. Stabilize selection/scroll interaction behavior under manual device usage.
4. Keep debug/profiling instrumentation behind explicit flags and remove stale
   probes after fixes land.

## Workflow

Use this exact loop for every Android task:

1. Pick one smallest actionable cut from `Active TODO`.
2. Confirm the cut against owner docs before editing:
   - ownership: `ANDROID_JAVA_HOST_STRUCTURE.md`
   - naming: `ANDROID_JAVA_NAMING_CONTRACT.md` and
     `ANDROID_ZIG_BRIDGE_NAMING_CONTRACT.md`
   - architecture boundaries: `ANDROID_TERMINAL_HOST_PLAN.md`
3. Implement only that cut.
4. Validate:
   - Java compile: `./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac`
   - Deploy when runtime behavior changed:
     `./ops/android_terminal_host.py --variant release deploy`
   - Manual device check for the exact behavior touched
5. Update docs that own the changed contract.
6. Commit a small cohesive change.

Execution guard:

- do not add lint/process/precommit ceremony in this lane unless explicitly
  requested by the user

## Done Criteria for a Cut

A cut is done only if all are true:

- behavior is correct on device for the targeted scenario
- ownership is clearer than before (not just moved code)
- docs match the new ownership/behavior
- validation commands pass for touched layers

## Guardrails

- Work on `main` unless the user explicitly asks for a branch.
- Do not create parallel authorities for the same decision.
- Do not leave temporary debug pathways active without a flag.
- Do not move terminal truth from Zig into Java.

## Current Status Snapshot

- interactive shell + Neovim baseline is usable on-device
- `ZideTerminalActivity` is now wiring/lifecycle/orchestration-oriented
  (current size: `618` lines; JNI moved out to `TerminalNativeBridge`)
- current Java hotspot ranking for hygiene focus:
  - `selection/TerminalSelectionController.java` (~946 lines, monolithic by design)
  - `ZideTerminalActivity.java` (~618 lines, orchestration pressure)
  - `host/ui/WidgetCallbacks.java` (~349 lines, constructor/callback pressure)
  - `userland/UserlandInstaller.java` (~425 lines, large but cohesive)
- activity callback factory wiring now consistently favors named callback
  references over inline state-assignment or non-trivial lifecycle lambdas
- host callback seams are adapter-backed (`*HostCallbacks` /
  `*HostLifecycleCallbacks`) instead of activity-owned anonymous blocks
- assist modifier latch presentation now lives in chrome host wiring instead of
  the activity
- product runtime, chrome, surface, session, selection, gesture, input, and UI
  construction now terminate in dedicated `host/*Factory` classes
- chrome bridge/callback construction now lives in
  `host/ui/ChromeFactory`
- selection/gesture controller construction now lives in
  `host/interaction/InteractionFactory`
- hardware-keyboard and IME-focus-recovery controller construction now lives in
  `host/input/InputFactory`
- surface host bridge/callback construction now lives in
  `host/surface/SurfaceFactory`
- product-runtime/frame-loop construction now lives in
  `host/runtime/RuntimeFactory`
- shell-session and userland-session host bridge construction now lives in
  `host/session/SessionFactory`
- UI host construction now lives in `host/ui/UiFactory`
- session/runtime activity wiring now composes through
  `host/session/SessionAssembly` + `SessionAssemblyCallbacks`
- initial status/view activity wiring now composes through
  `host/status/StatusViewAssembly` + `StatusViewCallbacks`
- interaction activity wiring now composes through
  `host/interaction/InteractionAssembly` + `InteractionCallbacks`
- widget/chrome/view-mode/surface activity wiring now composes through
  `host/ui/WidgetAssembly` + `WidgetCallbacks`
- userland runtime-assets/workflow startup activity wiring now composes through
  `host/userland/WorkflowAssembly` + `WorkflowAssemblyCallbacks`
- product-runtime controller startup activity wiring now composes through
  `host/runtime/ProductRuntimeAssembly` + `ProductRuntimeAssemblyCallbacks`
- activity lifecycle native/status/session/surface wiring now composes through
  `host/lifecycle/LifecycleController` + `LifecycleCallbacks`
- input-view install and input controller activity wiring now composes through
  `host/input/InputAssembly` + `InputCallbacks`
- surface/widget activity wiring now composes through
  `host/surface/SurfaceWidgetAssembly` +
  `SurfaceWidgetAssemblyCallbacks`
- post-construction UI bind/start activity wiring now composes through
  `host/ui/UiStartupAssembly` + `UiStartupCallbacks`
- terminal surface widget seam is established in
  `host/surface/SurfaceWidgetController` for future tabbed hosting
- debug surface snapshot composition moved to
  `debug/TerminalSurfaceStateSnapshotReader`
- JNI bridge exports now use only current `uk.laurencegouws.terminal` symbol
  ownership
- readiness evaluation now uses only `.zide-userland-readiness.json`
- Zig bridge surface/event API names now use concise current lifecycle wording
  (`onCreate/onStart/onResume/...`, `onSurface*`, `currentSurface*`) and
  internal Android runtime alias naming no longer uses bootstrap terminology
- JNI export surface is now split into ownership files:
  `src/android_bridge_exports/lifecycle_surface_exports.zig`,
  `src/android_bridge_exports/renderer_state_exports.zig`,
  `src/android_bridge_exports/shell_session_exports.zig`, and
  `src/android_bridge_exports/shell_selection_exports.zig`
- Android Zig bridge API names in `android_runtime_bridge.zig` now use concise
  session/selection terminology (`restartSession`, `pollSession`,
  `selectionRect*`, `selectionTextAlloc`, `rendererActive`) rather than
  long shell-prefixed helper names
- Android host/probe adapters now use event grammar (`on*`) instead of
  `note*` entrypoint names (`android_host.zig`,
  `android_gles_surface_status.zig`)
- terminal session helper filename now uses runtime/factory ownership naming:
  `src/app/terminal/terminal_session_runtime_factory.zig`
- Zig naming migration retired terms checkpoint:
  `note*` Android host/probe entrypoint names, `ProbeStatus/ProbeState`,
  `android_gles_probe` filename, `terminal_session_bootstrap` filename, and long `currentShell*` /
  `restartShellSession`-style bridge helper names
- Zig bridge naming authority now includes an explicit forbidden-terms checklist
  to block regressions in active Android runtime paths
- Java naming contract now includes event suffix key contract and explicit
  `native*Shell*Bridge` forbidden-symbol rule for `TerminalNativeBridge.java`
- selection controller remains monolithic by design until a real split seam
  exists
- queue remains Android-product-first, not shell-readiness-baseline-first

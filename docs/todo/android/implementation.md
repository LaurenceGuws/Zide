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
- keep `ZideActivity` as wiring, not policy
- keep Android-native interaction ownership clear (gesture/chrome/selection)

## Cleanup Campaign Charter (Authority)

This section is the single source of truth for the active Android cleanup campaign.

Goal:

- aggressively reduce Android host complexity while preserving behavior
- thin `ZideActivity` toward composition-root ownership
- reduce callback-surface pressure without wrapper inflation

Issue class execution order (strict):

1. ownership seams (`ZideActivity` -> existing owners)
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

- materially reduce `ZideActivity` size and direct responsibilities
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
- `Blocked by review needed:` `true` or `false` (set `true` only when milestone
  exit criteria are satisfied, queue mismatch is found, or runtime uncertainty
  requires architect decision)

Milestone gate contract (mandatory when manager/architect lane is active):

- work only inside the current milestone scope listed under `Milestone Queue`
- do not start the next milestone until the current one is marked `review_required`
  and the architect advances the queue
- progress updates must include:
  - `Milestone:` `<id> <status>`
  - `Scope contract:` one line confirming the work stayed in milestone scope
  - `Progress delta:` concrete simplification/result delta
  - `Validation:` exact commands + pass/fail
  - `Blocked by review needed:` `true` or `false`
- when a milestone endpoint is reached, report this exact line:
  `Milestone reached per docs, architect review required.`

## Active TODO

1. Continue cleanup/refactor cuts only where methods still own policy.
   - Completed: callback wiring hygiene pass in `ZideActivity` now uses
     named setter/getter/host helpers and removes non-trivial inline callback
     lambdas in assembly factories.
   - Completed: helper ordering is grouped by role
     (`host accessors`, `state snapshots`, `state setters`, `runtime actions`)
     so assembly-readability improvements remain scan-friendly.
   - Completed: high-signal callback supplier extractions are complete; remaining
     callback suppliers are intentionally trivial one-liners.
   - Completed: lifecycle/dispatch/startup policy extractions landed in
     `ZideActivity` (`onResume` debug intent flags, dispatch-key guard,
     and initial readiness-state load now use named helpers).
   - Completed: direct-input override routing cleanup landed
     (`sendDirectText` now routes through a named codepoint iteration helper).
   - Completed: direct-input native-ready guard is now shared via
     `canSendDirectInput()` across direct-input overrides.
   - Completed: activity lifecycle/input overrides now route through named
     helper seams; remaining inline logic is intentionally trivial or contract
     owned by downstream controllers.
   - Next: primary cleanup for Java host ownership continues under item 2
     below (`ZideActivity` `create*Callbacks()` net simplification).
2. Keep Java ownership boundaries aligned with
   `ANDROID_JAVA_HOST_STRUCTURE.md`.
   - Completed: chrome/surface ownership cleanup wave is stabilized and frozen;
     future changes there require an explicit queue re-open.
   - Completed: activity wiring cleanup waves reduced
     `ZideActivity.java` from ~778 to ~618 lines while keeping policy in
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
  - Completed: planning-only `SelectionController` seam audit
    established the next extraction queue without behavior changes:
    (a) selection-drag/autoscroll loop, (b) selection-handle geometry/sync,
    and (c) action-mode + clipboard flow. Audit conclusion remains
    contract-aligned: keep selection monolithic until one of those sub-seams is
    lifted in a behavior-preserving cut with replay/validation authority.
  - Completed: `ZideActivity` callback-constructor pressure reduced for
    widget assembly by extracting the largest inline `new WidgetCallbacks(...)`
    block into a dedicated `createWidgetCallbacks()` seam (behavior preserved).
  - Completed: runtime assembly callback-constructor pressure in
    `ZideActivity` reduced by extracting inline
    `new RuntimeAssemblyCallbacks(...)` wiring into
    `createRuntimeAssemblyCallbacks()` (behavior preserved).
  - Completed: session assembly callback-constructor pressure in
    `ZideActivity` reduced by extracting inline
    `new SessionAssemblyCallbacks(...)` wiring into
    `createSessionAssemblyCallbacks()` (behavior preserved).
  - Completed: workflow assembly callback-constructor pressure in
    `ZideActivity` reduced by extracting inline
    `new WorkflowAssemblyCallbacks(...)` wiring into
    `createWorkflowAssemblyCallbacks()` (behavior preserved).
  - Completed: UI startup callback-constructor pressure in
    `ZideActivity` reduced by extracting inline
    `new UiStartupCallbacks(...)` wiring into
    `createUiStartupCallbacks()` (behavior preserved).
  - Completed: input assembly callback-constructor pressure in
    `ZideActivity` reduced by extracting inline
    `new InputCallbacks(...)` wiring into `createInputCallbacks()`
    (behavior preserved).
  - Completed: interaction assembly callback-constructor pressure in
    `ZideActivity` reduced by extracting inline
    `new InteractionCallbacks(...)` wiring into
    `createInteractionCallbacks()` (behavior preserved).
  - Completed: status/view assembly callback-constructor pressure in
    `ZideActivity` reduced by extracting inline
    `new StatusViewCallbacks(...)` wiring into
    `createStatusViewCallbacks()` (behavior preserved).
  - Completed: lifecycle callback-constructor pressure in
    `ZideActivity` reduced by extracting inline
    `new LifecycleCallbacks(...)` wiring into
    `createLifecycleCallbacks()` (behavior preserved).
  - Completed: callback-surface noise in
    `ZideActivity` session/workflow callback factories reduced by
    replacing inline readiness/install state assignment lambdas with named
    setters (`setCurrentReadinessState`, `setCurrentInstallState`) while
    preserving behavior.
  - Completed: remaining inline activity-state assignment lambdas in
    extracted callback factories (`debugViewEnabled`, `imeVisible`,
    runtime install state) now route through named setters, further reducing
    relay-only callback noise without changing ownership or behavior.
  - Completed: lifecycle callback wiring in `ZideActivity` is now
    fully named end-to-end; `LifecycleCallbacks.LifecycleHostCallbacks.of(...)`
    no longer appears inline inside `createLifecycleCallbacks()`.
  - Completed: UI startup assembly invocation in `ZideActivity` now
    routes through a named `startUiStartupAssembly()` helper so composition-root
    startup no longer inlines the assembly start call.
  - Completed: product runtime assembly invocation in
    `ZideActivity` now routes through a named
    `assembleRuntimeController()` helper so startup sequencing no longer
    inlines that assembly call.
  - Completed: session assembly invocation in `ZideActivity` now routes
    through a named `assembleSessionControllerResult()` helper so controller
    assembly no longer inlines the `SessionAssembly.assemble(...)` call.
  - Completed: four more composition-root assembly invocations in
    `ZideActivity` are now named instead of inline:
    `assembleStatusViewResult()`, `assembleInteractionControllerResult()`,
    `assembleInputControllerResult()`, and
    `assembleWidgetHostControllerResult()` (behavior preserved).
  - Completed: `ZideActivity` callback/relay cleanup wave removed relay-only
    passthrough methods (`appendEvent`/`updateStatus`/native call wrappers,
    lifecycle forwarders, and several `*IfReady` adapters) by wiring
    callback constructors directly to owner methods or inline null-guarded
    lambdas; ownership remained with existing controllers and behavior was
    preserved.
  - Completed: widget host callback-constructor pressure dropped further by
    removing `host/ui/WidgetCallbacks.java`; `WidgetAssembly.Host` is now built
    directly from `ZideActivity` without an extra relay adapter class.
  - Completed: `WidgetAssembly` callback fan-out readability improved by
    extracting repeated null-guarded callback branches into named local helpers
    (`showViewIfReady`, `showDebugViewIfReady`,
    `createSurfaceWidgetAssemblyCallbacks`,
    `addSurfaceHolderCallbackIfPresent`) while preserving behavior and ownership.
  - Completed: `ZideActivity` callback-constructor lambdas now reuse named
    guarded actions for runtime/session/surface flows
    (`refreshShellStateIfReady`, `refreshDebugStatusSurfaceIfReady`,
    `handleShellStateEventIfReady`, `applyInstallStateIfReady`,
    `restartSessionIfReady`, `showDebugViewIfReady`,
    `notifyVisibleViewportIfReady`, `refreshUserlandSessionIfReady`,
    `stopFrameLoopIfReady`, `pauseSurfaceIfReady`, `resumeSurfaceIfReady`) to
    reduce duplicated null-guard branches without changing ownership.
  - Completed: `WidgetAssembly` now uses typed controller refs instead of
    one-element arrays for staged controller wiring (`ViewModeControllerRef`,
    `SurfaceWidgetControllerRef`), reducing callback plumbing indirection while
    preserving assembly behavior.
  - Completed: `SelectionController` action-mode/clipboard naming-noise pass
    removed remaining redundant ownership-heavy identifiers (`terminal*`
    action-mode state, long constant prefixes, and finish-sync typo
    `shouldfinishSelectionActionMode` -> `shouldFinishSelectionActionMode`)
    without semantic changes.
  - Completed: `SelectionController` action-mode lifecycle flow reduced one-hop
    helper churn by inlining single-call wrappers for floating action-mode
    start, create callback menu setup, invalidate path, and explicit finish
    detach while preserving behavior.
  - Completed: `SelectionController` action-mode destroy/sync path removed
    additional one-hop helpers by collapsing destroy-time detach/clear/reset into
    one method and simplifying sync visibility checks to direct state predicates
    (`selectionActionMode` + toolbar/selection visibility) with no behavior
    change.
    - Next: resume primary Java cleanup under Active TODO item 1 by executing a
      behavior-preserving `selection/SelectionController.java` pressure-reduction
      wave focused on action-mode lifecycle internals (reduce tiny one-hop
      helper churn and keep attach/show/invalidate/finish/destroy flow explicit
      with fewer method hops).
      For this wave, do not add naming-only wrappers; each cut must reduce
      callback or constructor pressure with measurable net simplification.
      Naming pressure rule for this wave: when a touched method/class name can be
      made package-led without losing meaning, prefer dropping redundant
      `Terminal`/`Product` prefixes; keep those terms only where they disambiguate
      real product-vs-debug or terminal-vs-nonterminal behavior.
      `ChromeController` / `SurfaceController` remain frozen until the binding
      `Next:` line is intentionally advanced.

### Milestone Queue (Manager/Architect Control)

Use this queue to keep the engineer on larger reviewable scopes while preserving
the existing per-commit validation rules.

1. `AN-A1-M2A` selection geometry/sync closure (`completed`)
   - Scope:
     - `SelectionController` internal seam only
     - complete geometry/sync extraction boundaries:
       endpoint-rect read, handle geometry, handle position mutation
     - no action-mode/clipboard edits
   - Outcome:
     - handle half-extent unified: anchors, endpoint layout, and sync now share
       `selectionHandleRadiusPx` (square handles); Y offset and viewport clamp
       split into dedicated internal helpers for drag vs endpoint sync paths
     - milestone-boundary validation: compile on each change; deploy +
       `AndroidRuntime:E` smoke clean at closure
   - Exit criteria:
     - no remaining duplicated handle-placement math branches in this seam
     - compile pass per commit and at least one deploy + `AndroidRuntime:E`
       smoke at seam boundary
     - queue notes updated with outcome-based progress
2. `AN-A1-M2B` docs checkpoint and queue advance (`completed`)
   - Scope:
     - docs-only checkpoint of completed seam outcomes
     - refresh hotspot size markers to current code reality
     - advance explicit `Next:` line only if M2A is complete and validated
   - Outcome:
     - hotspot line counts refreshed in queue snapshot, handoff, and structure
       authority; binding `Next:` advanced to `AN-A1-M2C` action-mode/clipboard
3. `AN-A1-M2C` selection action-mode/clipboard wave (`completed`)
   - Scope:
     - action-mode lifecycle + clipboard flow simplification only
     - preserve behavior and monolithic ownership
   - Outcome:
      - floating toolbar lifecycle is now branch-separated: attach/show, refresh,
        and explicit finish/destroy are handled by distinct paths
      - action-mode invalidation is centralized with explicit geometry-only vs
        full invalidation intent
      - copy menu handling resolves copy action id and completion in one place
        (single handled path)
      - clipboard flow is explicit and linear: selection bytes read -> UTF-8
        decode -> clipboard apply -> success/blocked telemetry
      - content-rect sourcing is centralized (bridge bounds first, bounded
        fallback to view extents)
      - bridge bounds degeneracy checks are shared across aggregate and endpoint
        selection rect paths to keep geometry behavior consistent
      - M2C closure: removed redundant one-hop sync and attach/register helpers;
        show vs refresh vs new action mode is explicit in one method; clipboard
        read and `ClipboardManager` resolve no longer delegate through pass-through
        wrappers
   - Exit criteria:
     - compile pass per commit; deploy + `AndroidRuntime:E` smoke at seam
       boundary
     - queue update records concrete simplification outcomes
4. Stabilize selection/scroll interaction behavior under manual device usage.
   (`completed`)
   - Scope:
     - selection + scrollback/overlay gesture arbitration only
     - preserve monolithic selection ownership; no `ChromeController` /
       `SurfaceController` edits unless queue re-opens those lanes
   - Outcome:
     - scroll-overlay thumb / follow-live requests now cancel in-flight
       scrollback fling before applying the requested offset so overlay control
       cannot race momentum scrolling
     - new product-surface touch (`ACTION_DOWN`) cancels scrollback fling so
       tap/scroll/selection cannot race a running fling from the prior gesture
     - closure: device pass 2026-04-16 on attached `SM_N975F` (1440x3040) using
       `adb` gesture replay between activity starts; four scenarios each cleared
       `logcat -s AndroidRuntime:E` after gestures: (1) fast vertical swipe then
       center tap, (2) fast swipe then second vertical drag, (3) fast swipe then
       long stationary touch (650ms), (4) overlapping fling with right-edge
       overlay thumb drag — all four produced no `AndroidRuntime:E` lines
   - Exit criteria:
     - compile per commit; deploy + clean `AndroidRuntime:E` at meaningful cuts
     - manual device pass on selection vs scroll + overlay (documented in queue
       notes when satisfied) — satisfied via recorded pass above
5. Keep debug/profiling instrumentation behind explicit flags and remove stale
   probes after fixes land. (`completed`)
   - Scope:
     - Android terminal host debug/profiling/probe paths only
     - classify each touched signal as correctness contract, operator telemetry,
       or probe/debug capture
     - no behavior expansion; no unrelated cleanup
    - Outcome:
     - **Removed from hot paths (debug overlay off):** unconditional event-line
       formatting, ring-buffer append, `Log.i` per event, and `TextView` updates
       in `StatusController.appendEvent` — classified as **operator
       telemetry** and now gated on `Host.debugViewEnabled()` (near-zero cost
       when disabled).
     - **Retained when overlay on:** full timestamped in-app log + `Log.i` (same
       operator-visible contract as before).
      - **Correctness contract unchanged:** native bridge load failure logging in
        `NativeBridge` left as product error signal (not event-log
        telemetry).
      - milestone closure: debug event telemetry now has near-zero disabled-path
        cost in `StatusController.appendEvent` while preserving full
        operator logging when debug overlay is enabled.
   - Exit criteria:
     - stale probe-only paths removed from product hot paths
     - retained telemetry is explicitly gated/configurable with low disabled cost
     - queue notes record what was removed vs retained and why

## Workflow

Use this exact loop for every Android task:

1. Pick one smallest actionable cut from `Active TODO`.
   - When `Milestone Queue` is present, execute contiguous cuts inside the
     current milestone until its exit criteria are met, then stop at that
     boundary and request architect review.
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
- `ZideActivity` is now wiring/lifecycle/orchestration-oriented
  (current size: `615` lines; JNI moved out to `NativeBridge`)
- current Java hotspot ranking for hygiene focus:
  - `selection/SelectionController.java` (~1163 lines, monolithic by design)
  - `ZideActivity.java` (~615 lines, orchestration pressure)
  - `host/ui/WidgetAssembly.java` (~250 lines, callback fan-out pressure)
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
  `host/ui/WidgetAssembly` + `WidgetAssembly.Host`
- userland runtime-assets/workflow startup activity wiring now composes through
  `host/userland/WorkflowAssembly` + `WorkflowAssemblyCallbacks`
- product-runtime controller startup activity wiring now composes through
  `host/runtime/RuntimeAssembly` + `RuntimeAssemblyCallbacks`
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
  `debug/SurfaceStateSnapshotReader`
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
  `native*Shell*Bridge` forbidden-symbol rule for `NativeBridge.java`
- selection controller remains monolithic by design until a real split seam
  exists
- queue remains Android-product-first, not shell-readiness-baseline-first

# Android Java Host Structure

Purpose: define Java ownership for `android/terminal-host/` and audit whether
file contents match class-level responsibility contracts.

This document is structure authority only. It is not the active todo queue.

Naming authority for Java terms and class/package grammar lives in
`app_architecture/platform/android/ANDROID_JAVA_NAMING_CONTRACT.md`.

## Boundaries

Java code exists to integrate Android-native lifecycle, input, surfaces,
overlays, and app-private userland operations with the Zig terminal runtime.

Rules:

- every Java file must have a class-level Javadoc responsibility contract
- the contract must name the owner boundary, not just restate the class name
- a file should own one Android/product concern
- data classes should stay data-shaped
- controllers should not duplicate another controller's state machine
- `ZideActivity` should stay Android entrypoint and wiring surface
- terminal truth, shell semantics, and renderer truth stay in Zig

## How To Use This Doc

Use this document to answer only structure questions:

- who owns this behavior?
- does this class shape still match its contract?
- where should new Android logic live?

For active priorities/workflow, use
`docs/todo/android/implementation.md`.

## Package Map

- `debug`: runtime status/snapshot formatting and log telemetry (no in-app
  debug view ownership)
- `gesture`: raw Android gesture detection and product gesture normalization
- `host`: Android host infrastructure such as surface, viewport, chrome,
  runtime assets, and product frame-loop scheduling
- `input`: Android IME and hardware-key input surface
- `scroll`: Android-native scrollback affordance
- `selection`: Android-native selection interaction over terminal truth
- `session`: shell session polling and auto-start eligibility
- `userland`: app-private prefix state, install/update, package commands, and
  userland blocker presentation

## Subsystem Boundary Contract

Java authority is split into two clean subsystems.

- Android Harness
  - owns Android app/activity ceremony, lifecycle wiring, app-shell layout,
    theming propagation, slide-out/navigation/state, and userland orchestration
  - should remain loosely coupled from Zig and from widget internals
- Terminal Widget
  - owns terminal surface/input interaction seams, ffi/gles lifecycle
    init/deinit handoff, and widget-level UX quirks
  - should be a harness consumer, not a harness backbone

Boundary rules:

- Harness does not own terminal interaction policy internals.
- Widget does not own app-shell navigation/theming/userland orchestration.
- Userland remains movable independent of widget ownership.
- `zide-pm` integration stays tool-like with minimal Java ceremony.

## AHW campaign landing gate (closure reference)

`docs/todo/android/implementation.md` records when the **Android harness/widget
portability hardening** (`AHW`) campaign is considered landed. The five criteria are:

1. **Harness canvas** — Harness owns platform/app-shell/userland orchestration; terminal mechanics stay in `selection`, `input`, `scroll`, `gesture`, and `host/surface`, composed through `host/ui` (`TerminalWidgetInstance`, `WidgetAssembly`, `TerminalWidgetCompositionAssembly`), not inlined as hidden product logic in the activity.
2. **Portable widget consumer** — Those domains do not own app-shell navigation, chrome, or userland orchestration; those stay under `host/ui`, `host/userland`, and activity wiring.
3. **Movable userland** — `uk.laurencegouws.terminal.userland` stays free of widget/surface/controller implementation types; see `USERLAND_HOST_CONTRACT.md`.
4. **`ZideActivity` wiring edge** — Startup order is `ProductHostOnCreateStartupCoordinator`; callback assembly uses `ProductHostActivityStartupWiring` and named hosts; the activity assigns composed controllers rather than owning terminal policy.
5. **Product expansion next** — Remaining Android roadmap work is scoped product features (for example multi-terminal view policy), not ownership rescue of the harness/widget split.

Architect acceptance of `AHW-B26` in the queue closes `AHW`; subsequent work is **product expansion** unless a regression reopens seam ownership.

## Harness-held terminal widget instance

Today the product hosts **one** terminal widget instance. Harness wiring groups
its portable seams in `host/ui/TerminalWidgetInstance`: `SelectionController`,
`GestureStateController`, `SurfaceBridge`, `SurfaceController`, and
`SurfaceWidgetController`. `host/ui/TerminalWidgetCompositionAssembly`
produces that holder from `InteractionAssembly.Result` + `WidgetSurfaceHostJoin`;
shell/chrome/view-mode controller refs remain on `WidgetAssembly.Result#harnessHost`
and the activity assigns them next to `compose(slot, …)` — `ZideActivity` does not
construct the holder directly.
`TerminalWidgetSlotId` makes the slot explicit at composition and host seams
(today only `TerminalWidgetSlotId.PRIMARY`). `TerminalWidgetSlotId.checkActiveProductTerminalSlot`
runs at interaction assembly, widget assembly, and composition entry points so
active-slot wiring cannot silently diverge. `ProductTerminalSlotShellMapping`
is the single code seam mapping an active product terminal slot to
`ShellViewId` (today `PRIMARY` → `ShellViewId.TERMINAL`). Construct
`AppShellNavigation` via `AppShellNavigation.forProductTerminalSlot` so mapping
and `checkActiveProductTerminalSlot` run once; `ViewModeController` reasserts the
resolved view through `AppShellTerminalViewPolicy.applyActiveProductTerminalShellView`
without re-invoking the mapping. Do not scatter ad hoc `ShellViewId` literals for
product shell routing.
App-shell chrome, viewport, runtime orchestration, and userland coordination stay
**outside** that holder. Future multi-instance hosting should compose additional
`TerminalWidgetInstance` values without moving app-shell state into the widget
holder.

### Future multi-terminal host API (contract only; no tab product behavior)

When multiple terminal surfaces are hosted (e.g. terminal tabs), the harness is
expected to repeat the **same assembly pattern per slot**, not fork
`ZideActivity` logic:

1. One `InteractionAssembly.Result` per terminal instance (selection + gesture
   scoped to that instance’s surface container and viewport inputs).
2. One `WidgetAssembly.assemble(WidgetAssembly.Host)` per instance; each
   `Host` closes over the correct `InteractionAssembly.Result`, reports
   `terminalWidgetSlot()` for that slot, and supplies **slot views** (surface
   container, scroll overlay, chrome targets for that slot).
3. One `TerminalWidgetCompositionAssembly.compose(ProductHostDeclaredTerminalWidgetSlot, interaction, surfaceJoin)` per
   instance → `TerminalWidgetInstance` (converts via `ProductHostDeclaredTerminalWidgetSlot#terminalWidgetSlotForProductHarness` for `checkActiveProductTerminalSlot`).

**Global harness** (single app-shell drawer, one `UserlandSessionCoordinator`,
global runtime/frame loop policy as today) stays outside
`TerminalWidgetInstance`. **Per-instance** state is the portable widget bundle
plus interaction controllers — not userland install/readiness truth, which
remains harness-orchestrated. This section does not implement tabs, tab UI, or
session switching.

### Chrome and terminal slot policy (freeze)

`ChromeFactory` / `ChromeController` construction stays **slot-agnostic** until
per-slot chrome policy is explicitly scoped. Do not add `TerminalWidgetSlotId` to
chrome factory methods preemptively; terminal slot identity remains on
interaction/widget hosts (via `ProductHostDeclaredTerminalWidgetSlot` at startup wiring) and `TerminalWidgetCompositionAssembly`.

### Slot → app-shell view mapping (active vs reserved)

`ProductTerminalSlotShellMapping` owns the contract from `TerminalWidgetSlotId`
to `ShellViewId` for **product** wiring. `AppShellNavigation` stores the resolved
`ShellViewId` for the widget assembly instance. Reserved enum values on either
side do not imply tab or multi-instance behavior until a scoped batch defines policy.

### App-shell state invariants (harness)

`AppShellNavigation` does not expose a public arbitrary active-shell-view setter;
product wiring uses `applyProductTerminalShellViewActive` and internal
`replaceActiveShellView` (non-null). `AppShellViewState` requires a non-null `id`.
Chrome drawer sidebar open/close is recorded with `applyChromeDrawerSidebarOpen` /
`applyChromeDrawerSidebarClosed` (no generic boolean sidebar setter). `ChromeBridge`
forwards those policy methods through `AppShellTerminalViewPolicy` (which delegates to
`AppShellNavigation`) for `ChromeController`.
On `ChromeController.Host`, IME visibility uses `chromeImeVisibilityPresent`,
`applyChromeImeVisibilityHidden`, and `applyChromeImeVisibilityFromOpenAttempt` — no
generic boolean `setImeVisible` on the chrome host seam.
**Product terminal session selection (APX-B8 state slice, APX-B9 session hook, APX-B11 UX):** `AppShellNavigation` owns a fixed
`PRODUCT_TERMINAL_TAB_COUNT` and `selectedProductTerminalTabIndex` with
`applySelectProductTerminalTab` (returns whether index changed); `AppShellTerminalViewPolicy` forwards tab APIs;
`ChromeController` / `ChromeBridge` bind the session buttons in the **app-shell drawer sidebar** (navigation), not inline above the terminal content’s assist/input helper row — the assist strip stays **input-only**.
On **distinct user-driven** tab change (`applySelectProductTerminalTab` reports the index changed),
`RuntimeController.restartShellSessionForProductTab` restarts the native shell and
refreshes userland (single PTY — no second `TerminalWidgetSlotId` or `TerminalWidgetInstance`).
**APX-B14:** activity recreate restores the selected tab index by seeding `AppShellNavigation.forProductTerminalSlot(slot, index)` from `ZideActivity` `savedInstanceState` (clamped) so chrome matches without replaying `applySelectProductTerminalTab` (no synthetic startup restart).
**APX-B15:** `AppShellTerminalViewPolicy` owns ordered `ProductTerminalTabDescriptor` rows (stable id + display label + tab index); `WidgetAssembly` supplies defaults through `ProductTerminalTabDescriptors.defaultsForProductHarness(Resources)`; `ChromeController` / `ChromeBridge` bind sidebar session tabs from `productTerminalTabDescriptors()` and `productTerminalTabButton(index)` — no parallel hardcoded label/source-of-truth outside policy assembly.
**APX-B16:** `ZideActivity` instance state persists `selectedProductTerminalTabStableId` (via policy); restore resolves stable id → seed index through `ProductTerminalTabDescriptors.tabIndexForStableIdOrDefault` on the default descriptor list before navigation construction (seed-only; no synthetic restart). Legacy bundles may still carry the APX-B14 raw index key for one-way migration.
**APX-B17:** Readiness stamp carries `runtime_support_links` from the install-time manifest snapshot; `UserlandRuntimeSupportLinks` applies the same fragment during install and re-applies from the stamp before first native session `restart()` (embed `zide.embed` paths allowed alongside the host package dir).
`ChromeFactory` takes harness `ChromeImePolicyInput` from `WidgetAssembly.Host` (not raw
`BooleanSupplier` / `Consumer<Boolean>`) for that policy slice.
`WidgetAssembly.Host` does not expose primitive `imeVisible` / `setImeVisible`; surface
assembly reads IME through `SurfaceWidgetHostImeVisibility` (`currentImeVisible`), and
chrome assembly uses `ChromeImePolicyInput` as above.
Activity-level IME scratch for status/input/widget wiring is owned by `ProductHostImeState`
(one instance on `ZideActivity`), implementing `HostImeStateAccess` for status/viewport/input
callback adapters (`StatusViewAssembly.Host`, `ViewportCallbacks`, `InputAssembly.Host`) without
duplicated `BooleanSupplier` / `Consumer<Boolean>` pairs.
Default keep-screen-on for the terminal host activity is applied through `ProductHostKeepScreenOnPolicy`
via `HostWindowFlagAccess` (typically `getWindow()::addFlags`), not ad-hoc `Window` flag mutations in
`ZideActivity` startup and not a raw `Window` parameter on the policy API.
These are harness contract checks only — they do not add tab or multi-instance
product behavior.

## File Audit

Current shape markers (for hygiene tracking, not hard limits):

- `selection/SelectionController.java`: `1066` lines (monolithic by design for now)
- `ZideActivity.java`: `441` lines
- `input/ShellInputView.java`: `587` lines
- `userland/UserlandInstaller.java`: `425` lines
- `host/ui/WidgetAssembly.java`: `283` lines
- `host/surface/SurfaceBridge.java`: `272` lines
- `host/surface/SurfaceController.java`: `262` lines
- `host/ui/ChromeController.java`: `213` lines
- `host/runtime/RuntimeHostCallbacks.java`: `170` lines
- `host/ui/UiStartupCallbacks.java`: `168` lines
- `host/status/StatusViewAssembly.java`: `133` lines

| File | Contract Fit | Size/Shape | Next Pressure |
| --- | --- | --- | --- |
| `ZideActivity.java` | Good | Wiring-oriented Android entrypoint (wiring edge, not choreography owner). JNI declarations remain out; startup null-guards are aggregated in `ProductHostStartupBundle`; `ActivityViewBindings` comes from `StatusViewAssembly.Result.activityViewBindings` (single `findViewById` capture); one `ProductHostDeclaredTerminalWidgetSlot` + `AppShellTerminalHostSelectionContext` for declared/selection startup; that value feeds `ProductHostActivityStartupWiring.interaction`, `WidgetHostAssemblyContext`, and `TerminalWidgetCompositionAssembly.compose` without raw enum fan-out at callsites; IME visibility scratch is `ProductHostImeState` (status/input/widget); keep-screen-on default is `ProductHostKeepScreenOnPolicy`; terminal instance is composed after `InteractionAssembly` + `WidgetAssembly` (order: interaction → userland/session → widget → compose + assign chrome from `widgetResult.harnessHost`). Fixed onCreate startup order is owned by `ProductHostOnCreateStartupCoordinator` against `ProductHostOnCreateStartupSteps` (activity implements the step surface; assembly bodies stay private on the activity). Callback assembly for status/interaction/input/session/workflow/runtime/UI startup is delegated to `ProductHostActivityStartupWiring`; `WidgetAssembly.Host` is `ProductTerminalWidgetAssemblyHost`; `LifecycleController.Host` is `ProductTerminalLifecycleHost`. Instance state persists product-terminal tab **stable id** (APX-B16) with legacy raw-index read for migration. | Keep activity wiring-oriented; route new behavior into the owning host/controller seam instead of adding policy here. |
| `NativeBridge.java` | Good | Owns JNI library load state and native bridge declarations for the terminal host. | Keep this focused on JNI surface only; do not move Android policy or lifecycle behavior into it. |
| `debug/AndroidDebugFormatter.java` | Good | Pure formatter plus snapshot values. Large constructor surface is acceptable for debug-only snapshots. | Split snapshot values only if formatter starts owning state or capture policy. |
| `debug/NativeStatusLabels.java` | Good | Owns native status-enum label mapping for debug/operator text. | Keep as pure mapping; avoid embedding behavior/policy. |
| `debug/SurfaceStateSnapshotReader.java` | Good | Owns native-backed surface snapshot composition for debug status rendering. | Keep it snapshot-only; avoid adding logging policy or UI behavior. |
| `debug/SurfaceStateSnapshotHostCallbacks.java` | Good | Functional callback adapter from activity-native access into `SurfaceStateSnapshotReader`. | Keep adapter-only; snapshot composition stays in `SurfaceStateSnapshotReader`. |
| `debug/StatusController.java` | Good | Owns runtime event/status logging and surface-state telemetry formatting for operator diagnostics. | Keep this log-focused; do not reintroduce in-app debug view ownership here. |
| `gesture/ProductGestureController.java` | Good | Larger than a trivial detector, but justified by gesture arbitration and pinch quantization. | Do not add selection/scrollback mutation here; keep it as gesture resolution only. |
| `gesture/GestureStateController.java` | Good | Owns pinch and scrollback budget/state that used to live in the activity. | Keep gesture detection in `ProductGestureController`; keep terminal truth in the native bridge. |
| `gesture/GestureStateControllerFactory.java` | Good | Builds one gesture-state controller from widget-scoped host callbacks. | Keep as construction-only glue; no runtime policy in factory. |
| `host/runtime/FrameLoopController.java` | Good | Small host scheduler; moved out of `userland` because it is not prefix policy. | Keep frame execution in native/product runnable, not in this controller. |
| `host/lifecycle/LifecycleController.java` | Good | Owns activity lifecycle wiring to native/status/session/surface hooks so lifecycle overrides stay delegation-only in the activity. | Keep this wiring-only; do not move product behavior or controller policy into it. |
| `host/lifecycle/LifecycleCallbacks.java` | Removed | Relay adapter was collapsed; `ZideActivity` supplies `LifecycleController.Host` via `ProductTerminalLifecycleHost`. | Keep lifecycle policy in `LifecycleController`; avoid reintroducing pass-through lifecycle adapter classes without measurable coupling reduction. |
| `host/runtime/FrameLoopCallbacks.java` | Good | Functional callback adapter from activity state/native access into `host/runtime/FrameLoopBridge`. | Keep adapter-only; frame-loop policy stays in `host/runtime/FrameLoopController`. |
| `host/runtime/FrameLoopBridge.java` | Good | Owns frame-loop host callback adaptation from activity into `host/runtime/FrameLoopController`. | Keep as callback adapter only; scheduling logic stays in `host/runtime/FrameLoopController`. |
| `host/interaction/GestureStateCallbacks.java` | Removed | Relay adapter was collapsed; gesture host callbacks are now provided directly at `InteractionFactory` / `GestureStateControllerFactory` seam. | Keep `GestureStateControllerFactory` host contract direct; avoid reintroducing pass-through adapters without measurable coupling reduction. |
| `host/interaction/GestureStateBridge.java` | Removed | Relay adapter was collapsed; `GestureStateControllerFactory` now accepts `GestureStateController.Host` directly. | Keep gesture policy in `GestureStateController`; avoid reintroducing bridge pass-through layers without measurable coupling reduction. |
| `host/runtime/RuntimeController.java` | Good | Owns product runtime policy: frame-loop readiness, shell-state/overlay refresh, install-state apply, install-triggered restart flow, and **product-terminal tab** session restart (`restartShellSessionForProductTab`). | Keep it runtime-orchestration only; native truth stays in bridge calls and terminal core. |
| `host/runtime/RuntimeHostCallbacks.java` | Good | Functional callback adapter from activity state/native access into `host/runtime/RuntimeController`. | Keep adapter-only; runtime behavior stays in `host/runtime/RuntimeController`. |
| `host/runtime/RuntimeAssembly.java` | Good | Owns product-runtime controller startup assembly so activity no longer inlines runtime callback construction. | Keep this assembly-only; runtime behavior stays in runtime controller + host callbacks. |
| `host/runtime/RuntimeAssemblyCallbacks.java` | Good | Functional callback adapter from activity state/actions into `host/runtime/RuntimeAssembly`. | Keep adapter-only; avoid moving runtime behavior into this adapter. |
| `host/ui/ProductHostStartupBundle.java` | Good | Aggregates `RuntimeStartupForwards`, `FrameLoopStartupForwards`, `SurfaceStartupForwards`, `UserlandSessionStartupForwards`, `InputChromeStartupForwards`, `host.status.StatusTelemetryStartupForwards`, and `WorkflowInstallStartupGlue` for progressive `onCreate` wiring only. | Keep as startup-order aggregation; extend owner domains via their `*StartupForwards` types, not new methods on the activity. |
| `host/ui/ProductHostActivityStartupWiring.java` | Good | Static factories for onCreate callback assembly (`StatusViewCallbacks`, `InteractionCallbacks`, `InputCallbacks`, session/workflow/runtime `*Callbacks`, `UiStartupCallbacks`); `interaction` takes `ProductHostDeclaredTerminalWidgetSlot`. Preserves forwarder wiring without owning product policy. | Keep assembly-only; route new behavior into domain controllers. |
| `host/ui/ProductHostOnCreateStartupCoordinator.java` | Good | Owns the fixed `onCreate` startup call order for the product terminal host activity; no policy, no widened globals. Invokes `ProductHostOnCreateStartupSteps` in the B23-locked sequence. | Keep choreography-only; extend only when a scoped batch adds an ordered phase without reordering existing steps. |
| `host/ui/ProductHostOnCreateStartupSteps.java` | Good | Typed step seam for progressive onCreate assembly phases wired from `ZideActivity` (harness canvas / activity wiring edge). | Keep as the activity’s startup callback surface; do not move assembly bodies here unless a batch explicitly relocates ownership. |
| `host/ui/ProductTerminalLifecycleHost.java` | Good | `LifecycleController.Host` for native bridge plus status/surface/userland forwards. | Keep wiring-only; lifecycle semantics stay in `LifecycleController` + native bridge. |
| `host/ui/WidgetHostAssemblyContext.java` | Good | Immutable dependency bundle for `ProductTerminalWidgetAssemblyHost` (progressive refs via suppliers where needed); `hostDeclaredTerminalWidgetSlot` matches interaction/composition startup value. | Extend only with scoped widget-host batches. |
| `host/ui/ProductTerminalWidgetAssemblyHost.java` | Good | `WidgetAssembly.Host` implementation; `terminalWidgetSlot()` delegates through `WidgetHostAssemblyContext.hostDeclaredTerminalWidgetSlot#terminalWidgetSlotForProductHarness()`. | Keep delegation-only; widget policy remains in existing harness controllers. |
| `host/userland/ShellPresentationHostInputs.java` | Good | Harness seam bundling readiness/install suppliers for shell-blocker presentation without userland types on `WidgetAssembly.Host`. | Keep as thin supplier bundle; presentation truth remains in userland value objects. |
| `host/runtime/RuntimeStartupForwards.java` | Good | Null-guard forwards into `RuntimeController`. | Delegation-only. |
| `host/runtime/FrameLoopStartupForwards.java` | Good | Null-guard forwards into `FrameLoopController`. | Delegation-only. |
| `host/surface/SurfaceStartupForwards.java` | Good | Null-guard forwards into `SurfaceController`. | Delegation-only. |
| `host/userland/UserlandSessionStartupForwards.java` | Good | Null-guard forwards into `UserlandSessionCoordinator`. | Delegation-only. |
| `host/input/InputChromeStartupForwards.java` | Good | Null-guard forwards for hardware keyboard, IME focus recovery, chrome modifier latch. | Delegation-only. |
| `host/status/StatusTelemetryStartupForwards.java` | Good | Null-guard forwards into `StatusController` for package-doctor / operator telemetry (status ownership, not debug UI). | Delegation-only. |
| `host/ui/TerminalWidgetInstance.java` | Good | Immutable bundle of one terminal widget’s surface + selection + gesture controller refs for harness hosting. | Do not fold app-shell or userland orchestration into this type. |
| `host/ui/TerminalWidgetSlotId.java` | Good | Compile-visible slot identity; `checkActiveProductTerminalSlot` enforces active = `PRIMARY` at assembly/composition entry points today; Javadoc points at `ProductTerminalSlotShellMapping` for shell view alignment. | When new slots activate, update the check alongside host policy; do not use checks alone to ship tab behavior. |
| `host/ui/ProductTerminalSlotShellMapping.java` | Good | Single seam: active product `TerminalWidgetSlotId` → `ShellViewId` (today `PRIMARY` → `TERMINAL`); invokes `checkActiveProductTerminalSlot`. Steady-state shell view reassert uses `AppShellNavigation`, not repeated mapping calls. | Extend mapping when `ShellViewId` gains distinct product views; keep chrome factory slot-agnostic until policy scopes it. |
| `host/ui/TerminalWidgetCompositionAssembly.java` | Good | Harness-owned join of `InteractionAssembly.Result` + `WidgetSurfaceHostJoin` into `TerminalWidgetInstance` only; `compose` takes `ProductHostDeclaredTerminalWidgetSlot` first (`terminalWidgetSlotForProductHarness` + `checkActiveProductTerminalSlot`); harness shell/chrome/view-mode refs stay on `WidgetAssembly.Result#harnessHost`. Not tab/multi-instance policy. | Keep `WidgetAssembly.Result` as widget assembly output; instance join stays here, not on `WidgetAssembly.Result` alone. |
| `host/userland/WorkflowInstallStartupGlue.java` | Good | Install completion state transitions + runtime restart delegation. | Keep install orchestration thin; low-level extraction stays in `UserlandInstaller`. |
| `host/ui/ActivityViewBindings.java` | Good | Owns raw activity view lookup and typed binding capture for terminal host wiring; `StatusViewAssembly.Result` exposes the authoritative `activityViewBindings` for activity wiring. | Keep this as lookup-only data binding; no policy or runtime behavior. |
| `host/ui/ChromeFactory.java` | Good | Owns chrome-specific bridge/callback construction; IME policy input uses `ChromeImePolicyInput` from `WidgetAssembly.Host`; intentionally no `TerminalWidgetSlotId` (chrome slot-agnostic freeze). | Reopen slot parameters only with scoped per-slot chrome policy. |
| `host/ui/ProductHostImeState.java` | Good | Activity-owned IME visibility scratch; implements `SurfaceWidgetHostImeVisibility`, `HostImeStateAccess`, and supplies `ChromeImePolicyInput` for widget assembly; fans out to status/input/widget wiring from one instance. | Keep IME policy in B14/B15/B16 seams; extend only with scoped harness batches. |
| `host/ui/HostWindowFlagAccess.java` | Good | Functional seam for `addFlags(int)` without policy types importing `Window`; keep-screen-on wiring uses this from the activity. | Keep minimal; extend window policy only via explicit harness batches. |
| `host/ui/ProductHostKeepScreenOnPolicy.java` | Good | Harness-owned default `FLAG_KEEP_SCREEN_ON` application via `HostWindowFlagAccess`; policy API does not take raw `Window`. | Extend only with explicit settings/product batches; do not scatter window flag policy. |
| `host/interaction/InteractionFactory.java` | Good | Owns selection/gesture interaction controller construction so interaction seams stay out of the generic host assembler. | Keep this construction-only; interaction behavior remains in selection/gesture controllers. |
| `host/interaction/InteractionAssembly.java` | Good | Owns interaction assembly; `assemble` enforces `checkActiveProductTerminalSlot` on `Host`. | Keep this assembly-only; behavior stays in interaction controllers. |
| `host/interaction/InteractionCallbacks.java` | Good | Functional callback adapter into `host/interaction/InteractionAssembly`; stores `ProductHostDeclaredTerminalWidgetSlot` at startup; `terminalWidgetSlot()` delegates via `terminalWidgetSlotForProductHarness()`. | Keep adapter-only; avoid moving interaction behavior into this adapter. |
| `host/input/InputFactory.java` | Good | Owns hardware-keyboard and IME-focus-recovery controller construction so input seams stay out of generic host assembly. | Keep this construction-only; input behavior remains in `input/` controllers. |
| `host/input/InputAssembly.java` | Good | Owns input-view installation and input-controller assembly composition for the activity wiring layer; `Host` exposes `HostImeStateAccess` for IME read/write. | Keep this assembly-only; input behavior remains in `input/` controllers. |
| `host/input/InputCallbacks.java` | Good | Functional callback adapter into `host/input/InputAssembly`; holds `HostImeStateAccess` and explicit `ShellInputView.Host` (no `Context` cast). | Keep adapter-only; avoid adding input behavior here. |
| `host/surface/SurfaceFactory.java` | Good | Owns surface host bridge/callback construction so surface lifecycle assembly stays out of generic host assembly. | Keep this construction-only; surface behavior remains in surface host controllers/bridges. |
| `host/surface/SurfaceWidgetAssembly.java` | Good | Owns surface/widget activity wiring assembly that composes surface and UI host factories for activity use. | Keep this assembly-only; surface/widget behavior remains in dedicated controllers. |
| `host/surface/SurfaceWidgetAssemblyCallbacks.java` | Good | Functional callback adapter from activity state/actions into `host/surface/SurfaceWidgetAssembly`; IME read uses `SurfaceWidgetHostImeVisibility` from `WidgetAssembly.Host`. | Keep adapter-only; avoid adding surface/widget behavior here. |
| `host/runtime/RuntimeFactory.java` | Good | Owns product-runtime and frame-loop construction so runtime assembly stays out of generic host assembly. | Keep this construction-only; runtime behavior remains in runtime controllers. |
| `host/session/SessionFactory.java` | Good | Owns shell-session and userland-session host bridge construction so session seams stay out of generic host assembly. | Keep this construction-only; session behavior remains in session/userland coordinators. |
| `host/session/SessionAssembly.java` | Good | Owns session/runtime wiring assembly that composes session and runtime host factories for activity use. | Keep this assembly-only; business behavior stays in session/runtime controllers. |
| `host/session/SessionAssemblyCallbacks.java` | Good | Functional callback adapter from activity state/actions into `host/session/SessionAssembly`. | Keep adapter-only; avoid adding session/runtime behavior here. |
| `host/status/StatusViewAssembly.java` | Good | Owns initial view binding plus status/viewport host assembly for activity wiring; `Result` is bindings-first (`activityViewBindings` + snapshot reader + `StatusController` + `ViewportController` only; no duplicate per-view fields). | Keep this assembly-only; status logging and viewport policy remain in dedicated controllers. |
| `host/status/StatusViewCallbacks.java` | Good | Functional callback adapter from activity state/actions into `host/status/StatusViewAssembly`; IME via `HostImeStateAccess`. | Keep adapter-only; avoid moving status/viewport behavior into this adapter. |
| `host/ui/WidgetAssembly.java` | Good | Owns product widget/chrome/view-mode/surface host assembly so activity wiring no longer inlines those construction seams; `Host` exposes `SurfaceWidgetHostImeVisibility` + `ChromeImePolicyInput` instead of primitive IME accessors. Takes `AppShellTerminalHostSelectionContext` alongside `Host` so selection is not re-resolved inside `assemble`. Builds `AppShellTerminalViewPolicy` with `ProductTerminalTabDescriptors.defaultsForProductHarness` (APX-B15). | Keep this assembly-only; behavior remains in dedicated controllers/bridges. |
| `host/ui/WidgetCallbacks.java` | Removed | Adapter seam was removed; `WidgetAssembly.Host` is implemented by `ProductTerminalWidgetAssemblyHost` (`WidgetHostAssemblyContext` deps from activity). | Keep `WidgetAssembly` assembly-only; avoid recreating large pass-through adapters unless they remove measurable coupling. |
| `host/ui/UiFactory.java` | Good | Owns UI host construction for shell-state presenter bridge, view-mode controller, and surface-widget controller. | Keep this construction-only; UI behavior remains in dedicated host controllers. |
| `host/ui/UiStartupAssembly.java` | Good | Owns post-construction UI bind/start assembly for activity wiring. | Keep this assembly-only; UI behavior remains in dedicated controllers. |
| `host/ui/UiStartupCallbacks.java` | Good | Functional callback adapter from activity state/actions into `host/ui/UiStartupAssembly`. | Keep adapter-only; avoid adding UI behavior here. |
| `host/ui/ViewModeController.java` | Good | Owns product-view stabilization side effects (viewport notify + scroll-overlay refresh); delegates active terminal shell view to `AppShellTerminalViewPolicy.applyActiveProductTerminalShellView` (no second mapping call). | Keep this focused on product-view activation only; do not grow tab policy here — extend `AppShellTerminalViewPolicy` instead. |
| `host/ui/ShellViewId.java` | Good | Enum of harness shell content slots; tab-ready identity vocabulary; product routing from slot uses `ProductTerminalSlotShellMapping`. | Extend only when multi-view hosting lands; keep names product-neutral. |
| `host/ui/AppShellViewState.java` | Good | Per-shell-view state row; `id` is non-null (`Objects.requireNonNull`); selection + reserved content-ready bit for future multi-view chrome. | Keep immutable; do not embed widget types. |
| `host/ui/AppShellNavigation.java` | Good | Owns chrome drawer sidebar state + active `ShellViewId`; shell view: `applyProductTerminalShellViewActive` + private `replaceActiveShellView`; drawer sidebar: `applyChromeDrawerSidebarOpen` / `applyChromeDrawerSidebarClosed`; product wiring uses `forProductTerminalSlot` (+ optional seeded tab index overload for APX-B14 restore); slice-1 **product terminal session** indices (`PRODUCT_TERMINAL_TAB_COUNT`, `applySelectProductTerminalTab`). Session controls belong in the sidebar per APX-B11; not a second widget slot until a scoped batch defines it. | Keep harness-only; explicit policy methods only. |
| `host/ui/ProductTerminalTabDescriptor.java` | Good | Immutable tab metadata value: stable id + display label + tab index; paired with `AppShellTerminalViewPolicy` list. | Keep small; extend only with scoped tab product batches. |
| `host/ui/ProductTerminalTabDescriptors.java` | Good | Default harness tab table from `strings.xml` labels + stable string ids; must stay aligned with `PRODUCT_TERMINAL_TAB_COUNT`. Exposes `tabIndexForStableIdOrDefault` for APX-B16 activity restore resolution alongside policy. | Update when tab count or default labels change. |
| `host/ui/DeclaredTerminalWidgetSlotCatalog.java` | Good | Declared terminal-slot **catalog** for the product harness (`PRIMARY` only today). `AppShellTerminalSelectionPolicy` routes host declarations through `requireSlotDeclaredForProductHarness` before active-slot checks. Distinct from runtime active-slot policy. | Extend declared array when new `TerminalWidgetSlotId` values ship; keep separate from `checkActiveProductTerminalSlot` until multi-slot runtime is scoped. |
| `host/ui/ProductHostDeclaredTerminalWidgetSlot.java` | Good | Immutable **host-declared slot value** for startup: `forCurrentProductHarness()` wraps catalog default (`PRIMARY` today). `ZideActivity` holds one instance, passes it to `AppShellTerminalHostSelectionContext.forProductHostStartup`; `terminalWidgetSlotForProductHarness()` is the sole public conversion to `TerminalWidgetSlotId` for harness assembly (adapters still expose `Host#terminalWidgetSlot()` at interaction/widget seams). | Extend factory when host declaration varies; keep value type at startup seam. |
| `host/ui/AppShellTerminalHostSelectionContext.java` | Good | Startup **selection context**: `forProductHostStartup(ProductHostDeclaredTerminalWidgetSlot)` stores that value, resolves `DeclaredTerminalWidgetSlotCatalog` + selected routing slot + `AppShellTerminalSelectionPolicy` after `forDeclaredHostSlot`; `hostDeclaredTerminalWidgetSlot()` accessor; `WidgetAssembly.assemble(Host, context)` consumes it without re-resolving selection. | Extend when multi-slot startup varies host-declared slot; keep one context instance per startup path. |
| `host/ui/AppShellTerminalSelectionPolicy.java` | Good | App-shell **selection** policy: which `TerminalWidgetSlotId` is selected for routing; backed by `DeclaredTerminalWidgetSlotCatalog` + `checkActiveProductTerminalSlot`. `AppShellTerminalHostSelectionContext` owns one resolved policy reference for startup; `AppShellNavigation.forProductTerminalSlot` uses the context’s selected slot. | Extend when additional slots activate; pair with catalog + mapping changes; no tab UI in this type. |
| `host/ui/AppShellTerminalViewPolicy.java` | Good | App-shell **activation** policy + chrome drawer sidebar: wraps `AppShellNavigation` privately; owns `applyActiveProductTerminalShellView` and drawer `chromeDrawerSidebarOpen` / `applyChromeDrawerSidebar*` without exposing raw `AppShellNavigation` on the harness bundle; forwards **product terminal tab** selection (`productTerminalTabCount`, `selectedProductTerminalTabIndex`, `applySelectProductTerminalTab`) and **tab metadata** (`productTerminalTabDescriptors` list validated against navigation tab count). APX-B16: `productTerminalTabDescriptorAt`, `productTerminalTabIndexForStableId`, `selectedProductTerminalTabStableId`. `WidgetHarnessHostControllers` carries selection + activation policies. | Extend for activation/view chrome when multi-terminal visibility policy scopes; selection of slot is `AppShellTerminalSelectionPolicy`. |
| `host/ui/ChromeBridge.java` | Good | Owns chrome callback adaptation and assist-button/modifier-latch view presentation wiring; forwards drawer sidebar policy through `AppShellTerminalViewPolicy`; implements `ChromeController.Host` product-terminal tab descriptors + `productTerminalTabButton(index)` (sidebar ids) + `applySelectProductTerminalTab` via policy; IME visibility policy methods on `ChromeController.Host` delegate through `Callbacks` to `ChromeImePolicyInput` from `WidgetAssembly.Host`. | Keep as adapter-only for chrome behavior in `host/ui/ChromeController`. |
| `host/ui/ChromeCallbacks.java` | Removed | Relay adapter was collapsed; `ChromeFactory` now provides `ChromeBridge.Callbacks` directly. | Keep chrome behavior in `host/ui/ChromeController`; avoid reintroducing callback pass-through classes without measurable coupling reduction. |
| `host/userland/ShellStateBridge.java` | Good | Owns product-shell-state presenter callback adaptation and blocker/overlay view binding. | Keep presentation behavior in `userland/ShellStatePresenter`; keep this adapter thin. |
| `host/userland/ShellStateCallbacks.java` | Good | Functional callback adapter from activity state into `host/userland/ShellStateBridge`. | Keep adapter-only; shell-state presentation behavior remains in `ShellStatePresenter`. |
| `host/ui/ChromeController.java` | Watch | Coherent and improving; chrome stays slot-agnostic at type level. Sidebar + IME visibility mutations go through explicit `Host` policy methods (`chromeDrawerSidebar*`, `chromeImeVisibility*`, `apply*`). Binds **product terminal session** controls in the **drawer sidebar** from `Host#productTerminalTabDescriptors` + `productTerminalTabButton`; assist row is input helpers only; distinct session change invokes `Host#onProductTerminalTabSessionActivated` → runtime session restart. | Keep watch status; split assist-bar/sidebar only if either grows more behavior. |
| `host/runtime/RuntimeAssetsBridge.java` | Good | Owns runtime-assets host callback adaptation from activity into `host/runtime/RuntimeAssetsController`. | Keep asset staging behavior in `host/runtime/RuntimeAssetsController`; keep this adapter callback-only. |
| `host/runtime/RuntimeAssetsCallbacks.java` | Good | Functional callback adapter from activity actions into `host/runtime/RuntimeAssetsBridge`. | Keep adapter-only; runtime-asset behavior stays in `host/runtime/RuntimeAssetsController`. |
| `host/runtime/RuntimeAssetsController.java` | Good | Owns font asset staging and userland release loading. | Keep install/update and prefix extraction in `userland`. |
| `host/interaction/SelectionInteractionBridge.java` | Removed | Relay adapter was collapsed; selection host callbacks are now satisfied directly by `SelectionControllerFactory.Host`. | Keep `SelectionControllerFactory` host contract direct; avoid reintroducing relay bridges unless owner coupling measurably drops. |
| `host/interaction/SelectionBridge.java` | Removed | Relay adapter was collapsed; selection native bridge callbacks are now satisfied directly by `SelectionControllerFactory.Host`. | Keep selection behavior in `SelectionController`; avoid reintroducing bridge-only pass-through layers. |
| `host/interaction/SelectionCallbacks.java` | Removed | Relay adapter was collapsed; `InteractionFactory` now provides `SelectionControllerFactory.Host` directly. | Keep selection owner behavior in `SelectionController`; avoid reintroducing callback pass-through classes without measurable coupling reduction. |
| `host/status/StatusBridge.java` | Removed | Relay adapter was collapsed; `StatusViewAssembly` now provides `StatusController.Host` directly at assembly time. | Keep status rendering behavior in `StatusController`; avoid recreating relay bridge classes without measurable coupling reduction. |
| `host/status/StatusCallbacks.java` | Removed | Relay adapter was collapsed with `StatusBridge`; host state/snapshot adaptation now stays local to `StatusViewAssembly`. | Keep adaptation local to assembly seam; avoid pass-through callback classes unless they reduce owner coupling. |
| `host/surface/SurfaceCallbacks.java` | Good | Owns callback adaptation from activity into `host/surface/SurfaceBridge.Callbacks` while preserving bridge contracts. | Keep this adapter-only; do not move surface policy out of `host/surface/SurfaceController`. |
| `host/surface/SurfaceLifecycleCallbacks.java` | Removed | Relay adapter was collapsed; `SurfaceWidgetAssembly` now provides `SurfaceCallbacks.Callbacks` directly. | Keep surface lifecycle behavior in `host/surface/SurfaceController`; avoid reintroducing callback relay classes without measurable coupling reduction. |
| `host/surface/SurfaceBridge.java` | Good | Owns mutable SurfaceView/viewport scheduling state and adapts activity callbacks into the surface host controller. | Keep this as state + callback adapter only; do not move lifecycle policy here. |
| `host/surface/SurfaceController.java` | Watch | Coherent surface owner and improving; recent cleanup extracted repeated native-seq/event composition branches, but it still spans one-shot debug lifecycle probes plus viewport notification concerns. | Keep watch status; if viewport policy expands, move it to `host/ui/ViewportController`. |
| `host/surface/SurfaceWidgetCallbacks.java` | Good | Functional callback adapter from activity state/native access into `host/surface/SurfaceWidgetController`. | Keep adapter-only; widget interaction behavior stays in `host/surface/SurfaceWidgetController`. |
| `host/surface/SurfaceWidgetController.java` | Good | Owns the terminal widget callback surface: surface lifecycle callbacks, product gestures, and scroll-overlay callbacks for one terminal instance. | Keep this widget-scoped; future tabs should compose multiple widget controllers, not fork activity logic. |
| `host/session/ShellBridge.java` | Good | Owns shell-session native bridge callback adaptation from activity into `session/ShellSessionController.Bridge`. | Keep shell poll/restart policy in `ShellSessionController`; keep this adapter callback-only. |
| `host/session/ShellCallbacks.java` | Good | Functional callback adapter from activity native access into `host/session/ShellBridge`. | Keep adapter-only; shell session policy stays in `ShellSessionController`. |
| `host/userland/SessionBridge.java` | Removed | Relay adapter was collapsed; session host callbacks are now provided directly from `SessionFactory` into `UserlandSessionCoordinator`. | Keep poll/telemetry behavior in `UserlandSessionCoordinator`; avoid reintroducing bridge pass-through classes without measurable coupling reduction. |
| `host/userland/SessionCallbacks.java` | Removed | Relay adapter was collapsed with `SessionBridge`; callback mapping now stays local to `SessionFactory`. | Keep adaptation local to session assembly seams; avoid pass-through callback classes unless they reduce owner coupling. |
| `host/userland/ReadinessBlockerCallbacks.java` | Good | Functional callback adapter from activity state/actions into `userland/UserlandReadinessBlockerController`. | Keep adapter-only; readiness-blocker behavior stays in `UserlandReadinessBlockerController`. |
| `host/userland/WorkflowBridge.java` | Good | Owns userland install/workflow host callback adaptation from activity state/actions into `userland/UserlandWorkflowController` using semantic harness actions (apply install state, restart after install, package-doctor completion). | Keep workflow behavior in `UserlandWorkflowController`; keep this adapter state-free except fixed context/handler references. |
| `host/userland/WorkflowCallbacks.java` | Removed | Relay adapter was collapsed; `WorkflowAssembly.Host` now directly satisfies `WorkflowBridge.Callbacks`. | Keep workflow owner behavior in `UserlandWorkflowController`; avoid recreating pass-through callback wrappers without measurable gain. |
| `host/userland/WorkflowAssembly.java` | Good | Owns userland runtime-assets/workflow startup assembly so activity no longer inlines userland bridge/controller construction. | Keep this assembly-only; workflow behavior stays in workflow controller + bridge. |
| `host/userland/WorkflowAssemblyCallbacks.java` | Good | Functional callback adapter from activity state/actions into `host/userland/WorkflowAssembly`. | Keep adapter-only; avoid moving userland workflow behavior into this adapter. |
| `host/ui/ViewModeCallbacks.java` | Good | Functional callback adapter from activity state/actions into `host/ui/ViewModeController`. | Keep adapter-only; view-mode behavior stays in `host/ui/ViewModeController`. |
| `host/ui/ViewportBridge.java` | Good | Owns viewport host callback adaptation and bound product surface/view references for `host/ui/ViewportController`. | Keep viewport behavior in `host/ui/ViewportController`; keep this adapter callback/reference-only. |
| `host/ui/ViewportCallbacks.java` | Good | Functional callback adapter from activity state/actions into `host/ui/ViewportBridge`; IME via `HostImeStateAccess`. | Keep adapter-only; viewport behavior stays in `host/ui/ViewportController`. |
| `host/ui/ViewportController.java` | Good | Small, focused owner of insets and visible viewport size. | Keep terminal grid/scrollback mutation out. |
| `input/HardwareKeyboardController.java` | Good | Owns hardware-keyboard dispatch policy, including IME-hide and follow-bottom handoff. | Keep `InputConnection` composition behavior in `ShellInputView`; keep terminal truth in native bridge. |
| `input/HardwareKeyboardHostCallbacks.java` | Good | Functional callback adapter from activity state/actions into `HardwareKeyboardController`; IME via `HostImeStateAccess`. | Keep adapter-only; hardware-keyboard behavior stays in `HardwareKeyboardController`. |
| `input/ImeFocusRecoveryController.java` | Good | Owns IME-visible focus recovery when the hidden input view drops focus mid-session. | Keep IME show/hide policy in chrome; keep this focused on focus recovery only. |
| `input/ImeFocusRecoveryHostCallbacks.java` | Good | Functional callback adapter from activity state/actions into `ImeFocusRecoveryController`; IME read via `HostImeStateAccess`. | Keep adapter-only; IME focus-recovery behavior stays in `ImeFocusRecoveryController`. |
| `input/ShellInputView.java` | Watch | Correct owner for `InputConnection`; complexity is justified by IME composition and modifier translation. | Keep shell refresh, focus policy, and terminal rendering out. |
| `scroll/ScrollOverlayView.java` | Good | Native Android view owns visual scroll affordance and drag interaction. | Keep scrollback truth in native bridge/session. |
| `selection/SelectionController.java` | Partial | Too large, but currently one product concern: Android selection interaction. It owns word start, drag expansion, handles, toolbar, copy, and autoscroll. | Keep monolithic until a real seam is extracted; internal extractions are behavior-preserving (drag/autoscroll, handle geometry/sync completed; action-mode/clipboard wave is the active milestone per queue). |
| `selection/SelectionControllerFactory.java` | Good | Builds one selection controller from widget-scoped host callbacks and bridges. | Keep as construction-only glue; avoid moving selection behavior out of `SelectionController`. |
| `session/ShellSessionController.java` | Good | Small owner of poll and first auto-start eligibility; APX-B17 calls `UserlandRuntimeSupportLinks.materializeFromReadinessStamp` immediately before the first native `restart()` when `launchReady` (idempotent link re-apply from stamp). | Keep readiness UI and install workflow out. |
| `userland/ShellStatePresenter.java` | Good | Presenter is userland-adjacent because blocker state depends on prefix readiness and install state. | Rename or move only if product shell presentation grows beyond userland readiness. |
| `userland/UserlandArtifact.java` | Good | Package-private manifest value object. | Keep behavior in `UserlandInstaller`. |
| `userland/UserlandReadinessState.java` | Good | Value/parser for prefix readiness. | Keep installation and shell restart out. |
| `userland/UserlandReadinessUiPolicy.java` | Good | Pure copy/action policy for the readiness blocker. | Keep async execution out. |
| `userland/UserlandReadinessBlockerController.java` | Good | Owns readiness-blocker retry/install and debug button policy. | Keep view visibility/layout policy in product-shell presenter/chrome, not here. |
| `userland/UserlandCommandRunner.java` | Good | Runs `zide-pm` with app-private prefix environment; sets `ZIDE_PM_HOST_PLATFORM=android` so in-prefix `zide-pm` can scope Android test-binary catalog paths. | Keep package selection authority in `zide-pm`; Java stays a thin runner. |
| `userland/UserlandInstaller.java` | Watch | Large but cohesive: manifest fetch, verification, extraction, `UserlandRuntimeSupportLinks` install fragment, stamp validation; stamp records `runtime_support_links` for pre-activation materialize. | Split HTTP/archive helpers only if installer grows another product action. |
| `userland/UserlandRuntimeSupportLinks.java` | Good | Owns `runtime_support_links` parsing into shell `mkdir`/`rm`/`ln -s` sequences with host + `zide.embed` path allowlist; shared by install pipeline and `ShellSessionController` pre-restart materialize. | Keep stamp + manifest string format aligned with `ops/android_terminal_host.py` consumer. |
| `userland/UserlandInstallState.java` | Good | Small immutable install state. | Keep as data. |
| `userland/UserlandPolicy.java` | Good | Central prefix path policy. | Keep package/version decisions elsewhere. |
| `userland/UserlandRelease.java` | Good | Parses the bundled release descriptor only. | Keep release production in `../zide-mobile-pm`. |
| `userland/UserlandSessionCoordinator.java` | Good | Owns readiness refresh, shell poll, state application, and auto-start/status telemetry signaling. | Keep install/update execution out. |
| `userland/UserlandWorkflowController.java` | Good | Owns async install and package-doctor workflows; doctor path is read-only (`doctor` + `list-available`); edge install is explicit via `UserlandAndroidTestBinaryInstallLifecycle` using list-derived candidates. | Keep low-level archive extraction in `UserlandInstaller`. |
| `userland/UserlandZidePmListAvailableCandidates.java` | Good | Line parser for `zide-pm list-available` stdout; edge install narrows to `zide-android-*` ids (APX-B13); lexicographic pick inside that set. | Adjust heuristics only when `zide-pm` output contract changes; no Java manifest parsing. |
| `userland/UserlandAndroidTestBinaryInstallLifecycle.java` | Good | `selectAndroidEdgeSpecOrThrow` + `installPackageSpec`; `NoCandidateException` distinguishes `empty_catalog` vs `no_android_edge`. | Keep argv/env centralized here. |

## Structure Pressure

1. Keep reducing `ZideActivity` only where methods still own policy.
2. Keep `SelectionController` monolithic until a real seam appears.
3. Split `host/ui/ChromeController` only if assist/sidebar policy expands.
4. Slim `WidgetAssembly` / `TerminalWidgetCompositionAssembly` host-result surfaces before adding tab behavior; future tabs should consume a documented host API, not Activity field scatter.
5. Split `UserlandInstaller` only if install modes or transport complexity grow.

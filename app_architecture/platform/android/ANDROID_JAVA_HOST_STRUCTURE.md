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

## File Audit

Current shape markers (for hygiene tracking, not hard limits):

- `selection/SelectionController.java`: `1066` lines (monolithic by design for now)
- `ZideActivity.java`: `725` lines
- `input/ShellInputView.java`: `587` lines
- `userland/UserlandInstaller.java`: `425` lines
- `host/ui/WidgetAssembly.java`: `320` lines
- `host/surface/SurfaceBridge.java`: `272` lines
- `host/surface/SurfaceController.java`: `262` lines
- `host/ui/ChromeController.java`: `221` lines
- `host/runtime/RuntimeHostCallbacks.java`: `170` lines
- `host/ui/UiStartupCallbacks.java`: `168` lines
- `host/status/StatusViewAssembly.java`: `161` lines

| File | Contract Fit | Size/Shape | Next Pressure |
| --- | --- | --- | --- |
| `ZideActivity.java` | Good | Wiring-oriented Android entrypoint. JNI declarations remain out; null-safe runtime forwards live in `ProductHostDeferredActions`; widget/interaction/input assembly Host seams expose `harnessContext()` instead of `Activity` where Context suffices. | Keep activity orchestration-only; route any new behavior into the owning host/controller seam instead of adding policy here. |
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
| `host/lifecycle/LifecycleCallbacks.java` | Removed | Relay adapter was collapsed; `ZideActivity` now supplies `LifecycleController.Host` directly. | Keep lifecycle policy in `LifecycleController`; avoid reintroducing pass-through lifecycle adapter classes without measurable coupling reduction. |
| `host/runtime/FrameLoopCallbacks.java` | Good | Functional callback adapter from activity state/native access into `host/runtime/FrameLoopBridge`. | Keep adapter-only; frame-loop policy stays in `host/runtime/FrameLoopController`. |
| `host/runtime/FrameLoopBridge.java` | Good | Owns frame-loop host callback adaptation from activity into `host/runtime/FrameLoopController`. | Keep as callback adapter only; scheduling logic stays in `host/runtime/FrameLoopController`. |
| `host/interaction/GestureStateCallbacks.java` | Removed | Relay adapter was collapsed; gesture host callbacks are now provided directly at `InteractionFactory` / `GestureStateControllerFactory` seam. | Keep `GestureStateControllerFactory` host contract direct; avoid reintroducing pass-through adapters without measurable coupling reduction. |
| `host/interaction/GestureStateBridge.java` | Removed | Relay adapter was collapsed; `GestureStateControllerFactory` now accepts `GestureStateController.Host` directly. | Keep gesture policy in `GestureStateController`; avoid reintroducing bridge pass-through layers without measurable coupling reduction. |
| `host/runtime/RuntimeController.java` | Good | Owns product runtime policy: frame-loop readiness, shell-state/overlay refresh, install-state apply, and install-triggered restart flow. | Keep it runtime-orchestration only; native truth stays in bridge calls and terminal core. |
| `host/runtime/RuntimeHostCallbacks.java` | Good | Functional callback adapter from activity state/native access into `host/runtime/RuntimeController`. | Keep adapter-only; runtime behavior stays in `host/runtime/RuntimeController`. |
| `host/runtime/RuntimeAssembly.java` | Good | Owns product-runtime controller startup assembly so activity no longer inlines runtime callback construction. | Keep this assembly-only; runtime behavior stays in runtime controller + host callbacks. |
| `host/runtime/RuntimeAssemblyCallbacks.java` | Good | Functional callback adapter from activity state/actions into `host/runtime/RuntimeAssembly`. | Keep adapter-only; avoid moving runtime behavior into this adapter. |
| `host/ui/ProductHostDeferredActions.java` | Good | Owns null-safe forwards from early wiring callbacks into controllers that are constructed progressively during activity startup. | Keep this as delegation-only glue; do not add product policy beyond null-guarded controller forwards. |
| `host/ui/ActivityViewBindings.java` | Good | Owns raw activity view lookup and typed binding capture for terminal host wiring. | Keep this as lookup-only data binding; no policy or runtime behavior. |
| `host/ui/ChromeFactory.java` | Good | Owns chrome-specific bridge/callback construction so chrome assembly does not inflate the generic host assembler. | Keep this construction-only; do not move chrome behavior out of `host/ui/ChromeController`. |
| `host/interaction/InteractionFactory.java` | Good | Owns selection/gesture interaction controller construction so interaction seams stay out of the generic host assembler. | Keep this construction-only; interaction behavior remains in selection/gesture controllers. |
| `host/interaction/InteractionAssembly.java` | Good | Owns interaction controller assembly wiring (selection + gesture state) for activity startup. | Keep this assembly-only; behavior stays in interaction controllers. |
| `host/interaction/InteractionCallbacks.java` | Good | Functional callback adapter from activity state/actions into `host/interaction/InteractionAssembly`. | Keep adapter-only; avoid moving interaction behavior into this adapter. |
| `host/input/InputFactory.java` | Good | Owns hardware-keyboard and IME-focus-recovery controller construction so input seams stay out of generic host assembly. | Keep this construction-only; input behavior remains in `input/` controllers. |
| `host/input/InputAssembly.java` | Good | Owns input-view installation and input-controller assembly composition for the activity wiring layer. | Keep this assembly-only; input behavior remains in `input/` controllers. |
| `host/input/InputCallbacks.java` | Good | Functional callback adapter from activity state/actions into `host/input/InputAssembly`. | Keep adapter-only; avoid adding input behavior here. |
| `host/surface/SurfaceFactory.java` | Good | Owns surface host bridge/callback construction so surface lifecycle assembly stays out of generic host assembly. | Keep this construction-only; surface behavior remains in surface host controllers/bridges. |
| `host/surface/SurfaceWidgetAssembly.java` | Good | Owns surface/widget activity wiring assembly that composes surface and UI host factories for activity use. | Keep this assembly-only; surface/widget behavior remains in dedicated controllers. |
| `host/surface/SurfaceWidgetAssemblyCallbacks.java` | Good | Functional callback adapter from activity state/actions into `host/surface/SurfaceWidgetAssembly`. | Keep adapter-only; avoid adding surface/widget behavior here. |
| `host/runtime/RuntimeFactory.java` | Good | Owns product-runtime and frame-loop construction so runtime assembly stays out of generic host assembly. | Keep this construction-only; runtime behavior remains in runtime controllers. |
| `host/session/SessionFactory.java` | Good | Owns shell-session and userland-session host bridge construction so session seams stay out of generic host assembly. | Keep this construction-only; session behavior remains in session/userland coordinators. |
| `host/session/SessionAssembly.java` | Good | Owns session/runtime wiring assembly that composes session and runtime host factories for activity use. | Keep this assembly-only; business behavior stays in session/runtime controllers. |
| `host/session/SessionAssemblyCallbacks.java` | Good | Functional callback adapter from activity state/actions into `host/session/SessionAssembly`. | Keep adapter-only; avoid adding session/runtime behavior here. |
| `host/status/StatusViewAssembly.java` | Good | Owns initial view binding plus status/viewport host assembly for activity wiring. | Keep this assembly-only; status logging and viewport policy remain in dedicated controllers. |
| `host/status/StatusViewCallbacks.java` | Good | Functional callback adapter from activity state/actions into `host/status/StatusViewAssembly`. | Keep adapter-only; avoid moving status/viewport behavior into this adapter. |
| `host/ui/WidgetAssembly.java` | Good | Owns product widget/chrome/view-mode/surface host assembly so activity wiring no longer inlines those construction seams. | Keep this assembly-only; behavior remains in dedicated controllers/bridges. |
| `host/ui/WidgetCallbacks.java` | Removed | Adapter seam was removed; `WidgetAssembly.Host` is now provided directly by `ZideActivity`. | Keep `WidgetAssembly` assembly-only; avoid recreating large pass-through adapters unless they remove measurable coupling. |
| `host/ui/UiFactory.java` | Good | Owns UI host construction for shell-state presenter bridge, view-mode controller, and surface-widget controller. | Keep this construction-only; UI behavior remains in dedicated host controllers. |
| `host/ui/UiStartupAssembly.java` | Good | Owns post-construction UI bind/start assembly for activity wiring. | Keep this assembly-only; UI behavior remains in dedicated controllers. |
| `host/ui/UiStartupCallbacks.java` | Good | Functional callback adapter from activity state/actions into `host/ui/UiStartupAssembly`. | Keep adapter-only; avoid adding UI behavior here. |
| `host/ui/ViewModeController.java` | Good | Owns product-view stabilization side effects (viewport notify + scroll-overlay refresh) and records active shell view on `AppShellNavigation` when product view applies. | Keep this focused on product-view activation only; do not grow terminal policy here. |
| `host/ui/ShellViewId.java` | Good | Enum of harness shell content slots; tab-ready identity vocabulary. | Extend only when multi-view hosting lands; keep names product-neutral. |
| `host/ui/AppShellViewState.java` | Good | Per-shell-view state row (selection + reserved content-ready bit) for future multi-view chrome. | Keep immutable; do not embed widget types. |
| `host/ui/AppShellNavigation.java` | Good | Owns app-shell drawer open/close state and active `ShellViewId`; central harness owner for navigation chrome. | Keep harness-only; chrome reads this instead of ad-hoc flags. |
| `host/ui/ChromeBridge.java` | Good | Owns chrome callback adaptation and assist-button/modifier-latch view presentation wiring; sidebar open state is delegated to `AppShellNavigation`. | Keep as adapter-only for chrome behavior in `host/ui/ChromeController`. |
| `host/ui/ChromeCallbacks.java` | Removed | Relay adapter was collapsed; `ChromeFactory` now provides `ChromeBridge.Callbacks` directly. | Keep chrome behavior in `host/ui/ChromeController`; avoid reintroducing callback pass-through classes without measurable coupling reduction. |
| `host/userland/ShellStateBridge.java` | Good | Owns product-shell-state presenter callback adaptation and blocker/overlay view binding. | Keep presentation behavior in `userland/ShellStatePresenter`; keep this adapter thin. |
| `host/userland/ShellStateCallbacks.java` | Good | Functional callback adapter from activity state into `host/userland/ShellStateBridge`. | Keep adapter-only; shell-state presentation behavior remains in `ShellStatePresenter`. |
| `host/ui/ChromeController.java` | Watch | Coherent and improving; recent cleanup extracted repeated sidebar/IME action branches into named internal seams, but ownership remains broad across sidebar, assist bar, view mode, and IME trigger policy. | Keep watch status; split assist-bar/sidebar only if either grows more behavior. |
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
| `host/ui/ViewportCallbacks.java` | Good | Functional callback adapter from activity state/actions into `host/ui/ViewportBridge`. | Keep adapter-only; viewport behavior stays in `host/ui/ViewportController`. |
| `host/ui/ViewportController.java` | Good | Small, focused owner of insets and visible viewport size. | Keep terminal grid/scrollback mutation out. |
| `input/HardwareKeyboardController.java` | Good | Owns hardware-keyboard dispatch policy, including IME-hide and follow-bottom handoff. | Keep `InputConnection` composition behavior in `ShellInputView`; keep terminal truth in native bridge. |
| `input/HardwareKeyboardHostCallbacks.java` | Good | Functional callback adapter from activity state/actions into `HardwareKeyboardController`. | Keep adapter-only; hardware-keyboard behavior stays in `HardwareKeyboardController`. |
| `input/ImeFocusRecoveryController.java` | Good | Owns IME-visible focus recovery when the hidden input view drops focus mid-session. | Keep IME show/hide policy in chrome; keep this focused on focus recovery only. |
| `input/ImeFocusRecoveryHostCallbacks.java` | Good | Functional callback adapter from activity state/actions into `ImeFocusRecoveryController`. | Keep adapter-only; IME focus-recovery behavior stays in `ImeFocusRecoveryController`. |
| `input/ShellInputView.java` | Watch | Correct owner for `InputConnection`; complexity is justified by IME composition and modifier translation. | Keep shell refresh, focus policy, and terminal rendering out. |
| `scroll/ScrollOverlayView.java` | Good | Native Android view owns visual scroll affordance and drag interaction. | Keep scrollback truth in native bridge/session. |
| `selection/SelectionController.java` | Partial | Too large, but currently one product concern: Android selection interaction. It owns word start, drag expansion, handles, toolbar, copy, and autoscroll. | Keep monolithic until a real seam is extracted; internal extractions are behavior-preserving (drag/autoscroll, handle geometry/sync completed; action-mode/clipboard wave is the active milestone per queue). |
| `selection/SelectionControllerFactory.java` | Good | Builds one selection controller from widget-scoped host callbacks and bridges. | Keep as construction-only glue; avoid moving selection behavior out of `SelectionController`. |
| `session/ShellSessionController.java` | Good | Small owner of poll and first auto-start eligibility. | Keep readiness UI and install workflow out. |
| `userland/ShellStatePresenter.java` | Good | Presenter is userland-adjacent because blocker state depends on prefix readiness and install state. | Rename or move only if product shell presentation grows beyond userland readiness. |
| `userland/UserlandArtifact.java` | Good | Package-private manifest value object. | Keep behavior in `UserlandInstaller`. |
| `userland/UserlandReadinessState.java` | Good | Value/parser for prefix readiness. | Keep installation and shell restart out. |
| `userland/UserlandReadinessUiPolicy.java` | Good | Pure copy/action policy for the readiness blocker. | Keep async execution out. |
| `userland/UserlandReadinessBlockerController.java` | Good | Owns readiness-blocker retry/install and debug button policy. | Keep view visibility/layout policy in product-shell presenter/chrome, not here. |
| `userland/UserlandCommandRunner.java` | Good | Runs `zide-pm` with app-private prefix environment. | Keep package selection authority in `../zide-mobile-pm`. |
| `userland/UserlandInstaller.java` | Watch | Large but cohesive: manifest fetch, verification, extraction, links, stamp validation. | Split HTTP/archive helpers only if installer grows another product action. |
| `userland/UserlandInstallState.java` | Good | Small immutable install state. | Keep as data. |
| `userland/UserlandPolicy.java` | Good | Central prefix path policy. | Keep package/version decisions elsewhere. |
| `userland/UserlandRelease.java` | Good | Parses the bundled release descriptor only. | Keep release production in `../zide-mobile-pm`. |
| `userland/UserlandSessionCoordinator.java` | Good | Owns readiness refresh, shell poll, state application, and auto-start/status telemetry signaling. | Keep install/update execution out. |
| `userland/UserlandWorkflowController.java` | Good | Owns async install and package-doctor workflows. | Keep low-level archive extraction in `UserlandInstaller`. |

## Structure Pressure

1. Keep reducing `ZideActivity` only where methods still own policy.
2. Keep `SelectionController` monolithic until a real seam appears.
3. Split `host/ui/ChromeController` only if assist/sidebar policy expands.
4. Split `UserlandInstaller` only if install modes or transport complexity grow.

# Android Java Host Structure

Purpose: define Java ownership for `android/terminal-host/` and audit whether
file contents match class-level responsibility contracts.

This document is structure authority only. It is not the active todo queue.

## Boundaries

Java code exists to integrate Android-native lifecycle, input, surfaces,
overlays, and app-private userland operations with the Zig terminal runtime.

Rules:

- every Java file must have a class-level Javadoc responsibility contract
- the contract must name the owner boundary, not just restate the class name
- a file should own one Android/product concern
- data classes should stay data-shaped
- controllers should not duplicate another controller's state machine
- `ZideTerminalActivity` should stay Android entrypoint and wiring surface
- terminal truth, shell semantics, and renderer truth stay in Zig

## How To Use This Doc

Use this document to answer only structure questions:

- who owns this behavior?
- does this class shape still match its contract?
- where should new Android logic live?

For active priorities/workflow, use
`docs/todo/android/implementation.md`.

## Package Map

- `debug`: debug-only formatting and debug status/event-log presentation
- `gesture`: raw Android gesture detection and product gesture normalization
- `host`: Android host infrastructure such as surface, viewport, chrome,
  runtime assets, and product frame-loop scheduling
- `input`: Android IME and hardware-key input surface
- `scroll`: Android-native scrollback affordance
- `selection`: Android-native selection interaction over terminal truth
- `session`: shell session polling and auto-start eligibility
- `userland`: app-private prefix state, install/update, package commands, and
  userland blocker presentation

## File Audit

Current shape markers (for hygiene tracking, not hard limits):

- `ZideTerminalActivity.java`: `582` lines
- `host/TerminalChromeHostFactory.java`: `69` lines
- `host/TerminalInteractionHostFactory.java`: `131` lines
- `host/TerminalInputHostFactory.java`: `56` lines
- `host/TerminalInteractionAssembly.java`: `108` lines
- `host/TerminalInteractionAssemblyHostCallbacks.java`: `97` lines
- `host/TerminalInputAssembly.java`: `93` lines
- `host/TerminalInputAssemblyHostCallbacks.java`: `106` lines
- `host/TerminalSurfaceHostFactory.java`: `67` lines
- `host/TerminalSurfaceWidgetAssembly.java`: `127` lines
- `host/TerminalSurfaceWidgetAssemblyHostCallbacks.java`: `212` lines
- `host/TerminalRuntimeHostFactory.java`: `81` lines
- `host/TerminalSessionHostFactory.java`: `52` lines
- `host/TerminalSessionAssembly.java`: `102` lines
- `host/TerminalSessionAssemblyHostCallbacks.java`: `131` lines
- `host/TerminalStatusViewAssembly.java`: `180` lines
- `host/TerminalStatusViewAssemblyHostCallbacks.java`: `106` lines
- `host/TerminalWidgetHostAssembly.java`: `278` lines
- `host/TerminalWidgetHostAssemblyHostCallbacks.java`: `421` lines
- `host/TerminalUiHostFactory.java`: `56` lines
- `host/TerminalUiStartupAssembly.java`: `103` lines
- `host/TerminalUiStartupHostCallbacks.java`: `164` lines
- `selection/TerminalSelectionController.java`: monolithic by design for now

| File | Contract Fit | Size/Shape | Next Pressure |
| --- | --- | --- | --- |
| `ZideTerminalActivity.java` | Partial | Thinner and wiring-oriented. JNI declarations remain out and status/view, interaction, and widget/chrome/view-mode/surface wiring now live in dedicated host assemblies. Remaining pressure is orchestration density rather than direct policy ownership. | Continue extracting only where orchestration density obscures ownership boundaries or increases coupling. |
| `TerminalNativeBridge.java` | Good | Owns JNI library load state and native bridge declarations for the terminal host. | Keep this focused on JNI surface only; do not move Android policy or lifecycle behavior into it. |
| `debug/AndroidDebugFormatter.java` | Good | Pure formatter plus snapshot values. Large constructor surface is acceptable for debug-only snapshots. | Split snapshot values only if formatter starts owning state or capture policy. |
| `debug/TerminalNativeStatusLabels.java` | Good | Owns native status-enum label mapping for debug/operator text. | Keep as pure mapping; avoid embedding behavior/policy. |
| `debug/TerminalSurfaceStateSnapshotReader.java` | Good | Owns native-backed surface snapshot composition for debug status rendering. | Keep it snapshot-only; avoid adding logging policy or UI behavior. |
| `debug/TerminalSurfaceStateSnapshotHostCallbacks.java` | Good | Functional callback adapter from activity-native access into `TerminalSurfaceStateSnapshotReader`. | Keep adapter-only; snapshot composition stays in `TerminalSurfaceStateSnapshotReader`. |
| `debug/TerminalStatusController.java` | Good | Owns debug event log and status text. | Keep product behavior out; it should remain debug/operator presentation. |
| `gesture/ProductGestureController.java` | Good | Larger than a trivial detector, but justified by gesture arbitration and pinch quantization. | Do not add selection/scrollback mutation here; keep it as gesture resolution only. |
| `gesture/TerminalGestureStateController.java` | Good | Owns pinch and scrollback budget/state that used to live in the activity. | Keep gesture detection in `ProductGestureController`; keep terminal truth in the native bridge. |
| `gesture/TerminalGestureStateControllerFactory.java` | Good | Builds one gesture-state controller from widget-scoped host callbacks. | Keep as construction-only glue; no runtime policy in factory. |
| `host/TerminalFrameLoopController.java` | Good | Small host scheduler; moved out of `userland` because it is not prefix policy. | Keep frame execution in native/product runnable, not in this controller. |
| `host/TerminalFrameLoopHostCallbacks.java` | Good | Functional callback adapter from activity state/native access into `TerminalFrameLoopHostBridge`. | Keep adapter-only; frame-loop policy stays in `TerminalFrameLoopController`. |
| `host/TerminalFrameLoopHostBridge.java` | Good | Owns frame-loop host callback adaptation from activity into `TerminalFrameLoopController`. | Keep as callback adapter only; scheduling logic stays in `TerminalFrameLoopController`. |
| `host/TerminalGestureStateFactoryHostCallbacks.java` | Good | Functional callback adapter from activity state/native access into `gesture/TerminalGestureStateControllerFactory`. | Keep adapter-only; gesture policy stays in `TerminalGestureStateController`. |
| `host/TerminalGestureStateHostBridge.java` | Good | Owns gesture-state host callback adaptation from activity into `gesture/TerminalGestureStateController`. | Keep gesture policy in `TerminalGestureStateController`; keep this adapter callback-only. |
| `host/TerminalProductRuntimeController.java` | Good | Owns product runtime policy: frame-loop readiness, shell-state/overlay refresh, install-state apply, and shell restart status flow. | Keep it runtime-orchestration only; native truth stays in bridge calls and terminal core. |
| `host/TerminalProductRuntimeHostCallbacks.java` | Good | Functional callback adapter from activity state/native access into `TerminalProductRuntimeController`. | Keep adapter-only; runtime behavior stays in `TerminalProductRuntimeController`. |
| `host/TerminalActivityViewBindings.java` | Good | Owns raw activity view lookup and typed binding capture for terminal host wiring. | Keep this as lookup-only data binding; no policy or runtime behavior. |
| `host/TerminalChromeHostFactory.java` | Good | Owns chrome-specific bridge/callback construction so chrome assembly does not inflate the generic host assembler. | Keep this construction-only; do not move chrome behavior out of `TerminalChromeController`. |
| `host/TerminalInteractionHostFactory.java` | Good | Owns selection/gesture interaction controller construction so interaction seams stay out of the generic host assembler. | Keep this construction-only; interaction behavior remains in selection/gesture controllers. |
| `host/TerminalInteractionAssembly.java` | Good | Owns interaction controller assembly wiring (selection + gesture state) for activity startup. | Keep this assembly-only; behavior stays in interaction controllers. |
| `host/TerminalInteractionAssemblyHostCallbacks.java` | Good | Functional callback adapter from activity state/actions into `TerminalInteractionAssembly`. | Keep adapter-only; avoid moving interaction behavior into this adapter. |
| `host/TerminalInputHostFactory.java` | Good | Owns hardware-keyboard and IME-focus-recovery controller construction so input seams stay out of generic host assembly. | Keep this construction-only; input behavior remains in `input/` controllers. |
| `host/TerminalInputAssembly.java` | Good | Owns input-view installation and input-controller assembly composition for the activity wiring layer. | Keep this assembly-only; input behavior remains in `input/` controllers. |
| `host/TerminalInputAssemblyHostCallbacks.java` | Good | Functional callback adapter from activity state/actions into `TerminalInputAssembly`. | Keep adapter-only; avoid adding input behavior here. |
| `host/TerminalSurfaceHostFactory.java` | Good | Owns surface host bridge/callback construction so surface lifecycle assembly stays out of generic host assembly. | Keep this construction-only; surface behavior remains in surface host controllers/bridges. |
| `host/TerminalSurfaceWidgetAssembly.java` | Good | Owns surface/widget activity wiring assembly that composes surface and UI host factories for activity use. | Keep this assembly-only; surface/widget behavior remains in dedicated controllers. |
| `host/TerminalSurfaceWidgetAssemblyHostCallbacks.java` | Good | Functional callback adapter from activity state/actions into `TerminalSurfaceWidgetAssembly`. | Keep adapter-only; avoid adding surface/widget behavior here. |
| `host/TerminalRuntimeHostFactory.java` | Good | Owns product-runtime and frame-loop construction so runtime assembly stays out of generic host assembly. | Keep this construction-only; runtime behavior remains in runtime controllers. |
| `host/TerminalSessionHostFactory.java` | Good | Owns shell-session and userland-session host bridge construction so session seams stay out of generic host assembly. | Keep this construction-only; session behavior remains in session/userland coordinators. |
| `host/TerminalSessionAssembly.java` | Good | Owns session/runtime wiring assembly that composes session and runtime host factories for activity use. | Keep this assembly-only; business behavior stays in session/runtime controllers. |
| `host/TerminalSessionAssemblyHostCallbacks.java` | Good | Functional callback adapter from activity state/actions into `TerminalSessionAssembly`. | Keep adapter-only; avoid adding session/runtime behavior here. |
| `host/TerminalStatusViewAssembly.java` | Good | Owns initial view binding plus debug-status/viewport host assembly for activity wiring. | Keep this assembly-only; status rendering and viewport policy remain in dedicated controllers. |
| `host/TerminalStatusViewAssemblyHostCallbacks.java` | Good | Functional callback adapter from activity state/actions into `TerminalStatusViewAssembly`. | Keep adapter-only; avoid moving status/viewport behavior into this adapter. |
| `host/TerminalWidgetHostAssembly.java` | Good | Owns product widget/chrome/view-mode/surface host assembly so activity wiring no longer inlines those construction seams. | Keep this assembly-only; behavior remains in dedicated controllers/bridges. |
| `host/TerminalWidgetHostAssemblyHostCallbacks.java` | Good | Functional callback adapter from activity state/actions into `TerminalWidgetHostAssembly`. | Keep adapter-only; avoid moving widget/chrome/view-mode behavior into this adapter. |
| `host/TerminalUiHostFactory.java` | Good | Owns UI host construction for shell-state presenter bridge, view-mode controller, and surface-widget controller. | Keep this construction-only; UI behavior remains in dedicated host controllers. |
| `host/TerminalUiStartupAssembly.java` | Good | Owns post-construction UI bind/start assembly for activity wiring. | Keep this assembly-only; UI behavior remains in dedicated controllers. |
| `host/TerminalUiStartupHostCallbacks.java` | Good | Functional callback adapter from activity state/actions into `TerminalUiStartupAssembly`. | Keep adapter-only; avoid adding UI behavior here. |
| `host/TerminalViewModeController.java` | Good | Owns product/debug view-mode switching and its side effects (viewport notify, scroll-overlay refresh, debug-session refresh). | Keep this focused on mode transitions; do not move selection or shell/runtime truth here. |
| `host/TerminalChromeHostBridge.java` | Good | Owns chrome callback adaptation, sidebar-open state, and assist-button/modifier-latch view presentation wiring for the chrome controller host contract. | Keep as adapter/state only; keep chrome behavior in `TerminalChromeController`. |
| `host/TerminalChromeHostCallbacks.java` | Good | Functional callback adapter from activity state/actions into `TerminalChromeHostBridge`. | Keep adapter-only; chrome behavior remains in `TerminalChromeController`. |
| `host/TerminalProductShellStateHostBridge.java` | Good | Owns product-shell-state presenter callback adaptation and blocker/overlay view binding. | Keep presentation behavior in `userland/ProductShellStatePresenter`; keep this adapter thin. |
| `host/TerminalProductShellStateHostCallbacks.java` | Good | Functional callback adapter from activity state into `TerminalProductShellStateHostBridge`. | Keep adapter-only; shell-state presentation behavior remains in `ProductShellStatePresenter`. |
| `host/TerminalChromeController.java` | Watch | Coherent today, but broad: sidebar, assist bar, view mode, and IME trigger policy. | Split assist-bar/sidebar only if either grows more behavior. |
| `host/TerminalRuntimeAssetsHostBridge.java` | Good | Owns runtime-assets host callback adaptation from activity into `TerminalRuntimeAssetsController`. | Keep asset staging behavior in `TerminalRuntimeAssetsController`; keep this adapter callback-only. |
| `host/TerminalRuntimeAssetsHostCallbacks.java` | Good | Functional callback adapter from activity actions into `TerminalRuntimeAssetsHostBridge`. | Keep adapter-only; runtime-asset behavior stays in `TerminalRuntimeAssetsController`. |
| `host/TerminalRuntimeAssetsController.java` | Good | Owns font asset staging and userland release loading. | Keep install/update and prefix extraction in `userland`. |
| `host/TerminalSelectionInteractionHostBridge.java` | Good | Owns selection interaction host callback adaptation from activity into `selection/TerminalSelectionController.Host`. | Keep selection behavior in `TerminalSelectionController`; keep this adapter callback-only. |
| `host/TerminalSelectionHostBridge.java` | Good | Owns selection-bridge callback adaptation from activity native calls into `TerminalSelectionController.Bridge`. | Keep as bridge-only adapter; selection behavior stays in `selection/TerminalSelectionController.java`. |
| `host/TerminalSelectionFactoryHostCallbacks.java` | Good | Functional callback adapter from activity state/native access into `selection/TerminalSelectionControllerFactory`. | Keep adapter-only; selection behavior remains in `TerminalSelectionController`. |
| `host/TerminalStatusHostBridge.java` | Good | Owns debug status host callback adaptation from activity state/snapshots into `debug/TerminalStatusController`. | Keep status rendering logic in `TerminalStatusController`; keep this adapter callback-only. |
| `host/TerminalStatusHostCallbacks.java` | Good | Functional callback adapter from activity state/snapshots into `TerminalStatusHostBridge`. | Keep adapter-only; status rendering behavior stays in `TerminalStatusController`. |
| `host/TerminalSurfaceHostCallbacks.java` | Good | Owns callback adaptation from activity into `TerminalSurfaceHostBridge.Callbacks` while preserving bridge contracts. | Keep this adapter-only; do not move surface policy out of `TerminalSurfaceHostController`. |
| `host/TerminalSurfaceHostLifecycleCallbacks.java` | Good | Functional callback adapter from activity state/actions/native hooks into `TerminalSurfaceHostCallbacks`. | Keep adapter-only; surface lifecycle behavior stays in `TerminalSurfaceHostController`. |
| `host/TerminalSurfaceHostBridge.java` | Good | Owns mutable SurfaceView/viewport scheduling state and adapts activity callbacks into the surface host controller. | Keep this as state + callback adapter only; do not move lifecycle policy here. |
| `host/TerminalSurfaceHostController.java` | Watch | Coherent surface owner, but broad because it also schedules debug surface operations and viewport notifications. | If more viewport policy appears, move it to `TerminalViewportController`. |
| `host/TerminalSurfaceWidgetHostCallbacks.java` | Good | Functional callback adapter from activity state/native access into `TerminalSurfaceWidgetController`. | Keep adapter-only; widget interaction behavior stays in `TerminalSurfaceWidgetController`. |
| `host/TerminalSurfaceWidgetController.java` | Good | Owns the terminal widget callback surface: surface lifecycle callbacks, product gestures, and scroll-overlay callbacks for one terminal instance. | Keep this widget-scoped; future tabs should compose multiple widget controllers, not fork activity logic. |
| `host/TerminalShellSessionBridge.java` | Good | Owns shell-session native bridge callback adaptation from activity into `session/ShellSessionController.Bridge`. | Keep shell poll/restart policy in `ShellSessionController`; keep this adapter callback-only. |
| `host/TerminalShellSessionCallbacks.java` | Good | Functional callback adapter from activity native access into `TerminalShellSessionBridge`. | Keep adapter-only; shell session policy stays in `ShellSessionController`. |
| `host/TerminalUserlandSessionHostBridge.java` | Good | Owns userland session refresh/poll telemetry callback adaptation from activity into `userland/UserlandSessionCoordinator`. | Keep poll/telemetry behavior in `UserlandSessionCoordinator`; keep this adapter callback-only. |
| `host/TerminalUserlandSessionHostCallbacks.java` | Good | Functional callback adapter from activity state/actions into `TerminalUserlandSessionHostBridge`. | Keep adapter-only; userland session behavior stays in `UserlandSessionCoordinator`. |
| `host/TerminalUserlandBootstrapBlockerHostCallbacks.java` | Good | Functional callback adapter from activity state/actions into `userland/UserlandBootstrapBlockerController`. | Keep adapter-only; bootstrap-blocker behavior stays in `UserlandBootstrapBlockerController`. |
| `host/TerminalUserlandWorkflowHostBridge.java` | Good | Owns userland install/workflow host callback adaptation from activity state/actions into `userland/UserlandWorkflowController`. | Keep workflow behavior in `UserlandWorkflowController`; keep this adapter state-free except fixed context/handler references. |
| `host/TerminalUserlandWorkflowHostCallbacks.java` | Good | Functional callback adapter from activity state/actions into `TerminalUserlandWorkflowHostBridge`. | Keep adapter-only; workflow behavior stays in `UserlandWorkflowController`. |
| `host/TerminalViewModeHostCallbacks.java` | Good | Functional callback adapter from activity state/actions into `TerminalViewModeController`. | Keep adapter-only; view-mode behavior stays in `TerminalViewModeController`. |
| `host/TerminalViewportHostBridge.java` | Good | Owns viewport host callback adaptation and bound product surface/view references for `TerminalViewportController`. | Keep viewport behavior in `TerminalViewportController`; keep this adapter callback/reference-only. |
| `host/TerminalViewportHostCallbacks.java` | Good | Functional callback adapter from activity state/actions into `TerminalViewportHostBridge`. | Keep adapter-only; viewport behavior stays in `TerminalViewportController`. |
| `host/TerminalViewportController.java` | Good | Small, focused owner of insets and visible viewport size. | Keep terminal grid/scrollback mutation out. |
| `input/TerminalHardwareKeyboardController.java` | Good | Owns hardware-keyboard dispatch policy, including IME-hide and follow-bottom handoff. | Keep `InputConnection` composition behavior in `ShellInputView`; keep terminal truth in native bridge. |
| `input/TerminalHardwareKeyboardHostCallbacks.java` | Good | Functional callback adapter from activity state/actions into `TerminalHardwareKeyboardController`. | Keep adapter-only; hardware-keyboard behavior stays in `TerminalHardwareKeyboardController`. |
| `input/TerminalImeFocusRecoveryController.java` | Good | Owns IME-visible focus recovery when the hidden input view drops focus mid-session. | Keep IME show/hide policy in chrome; keep this focused on focus recovery only. |
| `input/TerminalImeFocusRecoveryHostCallbacks.java` | Good | Functional callback adapter from activity state/actions into `TerminalImeFocusRecoveryController`. | Keep adapter-only; IME focus-recovery behavior stays in `TerminalImeFocusRecoveryController`. |
| `input/ShellInputView.java` | Watch | Correct owner for `InputConnection`; complexity is justified by IME composition and modifier translation. | Keep shell refresh, focus policy, and terminal rendering out. |
| `scroll/TerminalScrollOverlayView.java` | Good | Native Android view owns visual scroll affordance and drag interaction. | Keep scrollback truth in native bridge/session. |
| `selection/TerminalSelectionController.java` | Partial | Too large, but currently one product concern: Android selection interaction. It owns word start, drag expansion, handles, toolbar, copy, and autoscroll. | Keep this monolithic until a cleaner seam exists; the attempted chrome split was reverted because it was not yet a real extraction. |
| `selection/TerminalSelectionControllerFactory.java` | Good | Builds one selection controller from widget-scoped host callbacks and bridges. | Keep as construction-only glue; avoid moving selection behavior out of `TerminalSelectionController`. |
| `session/ShellSessionController.java` | Good | Small owner of poll and first auto-start eligibility. | Keep bootstrap UI and install workflow out. |
| `userland/ProductShellStatePresenter.java` | Good | Presenter is userland-adjacent because blocker state depends on prefix readiness and install state. | Rename or move only if product shell presentation grows beyond userland readiness. |
| `userland/UserlandArtifact.java` | Good | Package-private manifest value object. | Keep behavior in `UserlandInstaller`. |
| `userland/UserlandBootstrapState.java` | Good | Value/parser for prefix readiness. | Keep installation and shell restart out. |
| `userland/UserlandBootstrapUiPolicy.java` | Good | Pure copy/action policy for bootstrap blocker. | Keep async execution out. |
| `userland/UserlandBootstrapBlockerController.java` | Good | Owns bootstrap-blocker retry/install and debug button policy. | Keep view visibility/layout policy in product-shell presenter/chrome, not here. |
| `userland/UserlandCommandRunner.java` | Good | Runs `zide-pm` with app-private prefix environment. | Keep package selection authority in `../zide-mobile-pm`. |
| `userland/UserlandInstaller.java` | Watch | Large but cohesive: manifest fetch, verification, extraction, links, stamp validation. | Split HTTP/archive helpers only if installer grows another product action. |
| `userland/UserlandInstallState.java` | Good | Small immutable install state. | Keep as data. |
| `userland/UserlandPolicy.java` | Good | Central prefix path policy. | Keep package/version decisions elsewhere. |
| `userland/UserlandRelease.java` | Good | Parses the bundled release descriptor only. | Keep release production in `../zide-mobile-pm`. |
| `userland/UserlandSessionCoordinator.java` | Good | Owns bootstrap refresh, shell poll, state application, and auto-start telemetry. | Keep install/update execution out. |
| `userland/UserlandWorkflowController.java` | Good | Owns async install and package-doctor workflows. | Keep low-level archive extraction in `UserlandInstaller`. |

## Structure Pressure

1. Keep reducing `ZideTerminalActivity` only where methods still own policy.
2. Keep `TerminalSelectionController` monolithic until a real seam appears.
3. Split `TerminalChromeController` only if assist/sidebar policy expands.
4. Split `UserlandInstaller` only if install modes or transport complexity grow.

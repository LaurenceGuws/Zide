# Userland host contract (terminal-host)

Authority for how Java userland orchestration (`uk.laurencegouws.terminal.userland`) integrates with the Android harness (`host.userland`, activity wiring).

## Principles

- **Userland** owns staged artifacts, readiness stamps, install/doctor command execution, and presentation policy types (`UserlandInstallState`, `UserlandReadinessState`). It does **not** reference widget (`host.ui` surface assembly), frame loop, or JNI bridge types.
- **Harness** (`WorkflowBridge` / `WorkflowAssembly`, `ReadinessBlockerStartup`, `RuntimeController` wiring via activity) owns threading back to the main `Handler`, telemetry (`StatusController`), native session restart after install, and view wiring for product readiness UI.

## Stable entry surfaces

| Seam | Role |
|------|------|
| `ShellPresentationHostInputs` | Harness-only bundle of suppliers for `UserlandReadinessState` / `UserlandInstallState` used to wire `ShellStateCallbacks` from `WidgetAssembly` without putting userland value types on `WidgetAssembly.Host`. Product truth remains the userland types. |
| `WorkflowBridge.Callbacks` | Install flow (`completeInstall`, `failInstall`, `applyInstallState`), `restartSessionAfterInstall`, package-doctor completion (`markPackageDoctorComplete`), release and event append. |
| `UserlandWorkflowController` | Async install and `zide-pm` doctor; calls only `Host` (implemented by `WorkflowBridge`). |
| `UserlandReadinessBlockerController.Host` | Readiness retry button: `startInstall`, `refreshSessionAfterReadinessRetry` — harness implements via `ReadinessBlockerStartup` + `ReadinessBlockerCallbacks`. |
| `UserlandSessionCoordinator.Host` | Session poll/refresh side effects (readiness apply, shell refresh, telemetry); wired from `SessionAssembly` / activity. |

## Future IDE/editor modes

Alternate harnesses should implement the same callback shapes: supply `Context`/`Handler` where needed, map install/doctor/restart to host policy, and keep userland packages free of surface/widget/controller types.

## Multi-terminal hosting (future)

Per-terminal **tabs or split views** do not relocate userland orchestration into
per-widget holders: readiness/install/session coordination remains a **single**
harness concern unless a future milestone explicitly scopes userland per
workspace. App-shell **selection** of which terminal slot is routed for shell view
is harness-owned (`AppShellTerminalSelectionPolicy` over `DeclaredTerminalWidgetSlotCatalog`);
userland does not branch on slot identity. Widget-facing seams stay in `host` + `TerminalWidgetInstance`; this
document does not change when the harness hosts multiple terminal surfaces.

`TerminalWidgetSlotId` and other harness slot vocabulary identify **terminal
widget hosting** only; they do not fork userland types or workflows. Harness code
maps an active product slot to app-shell `ShellViewId` via
`ProductTerminalSlotShellMapping` (not userland). `AppShellNavigation` remains the
internal owner of active `ShellViewId` and drawer flags after
`AppShellNavigation.forProductTerminalSlot`; harness chrome and view-mode callers
reach shell-view and drawer policy through `AppShellTerminalViewPolicy` (explicit
methods; no public arbitrary shell-view setter on the navigation type). Chrome
construction stays slot-agnostic at the type level until a scoped harness decision
threads slot into chrome policy.

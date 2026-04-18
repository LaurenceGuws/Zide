# Android Java Naming Contract

Purpose: define one naming grammar and glossary for
`android/terminal-host/app/src/main/java/uk/laurencegouws/terminal/**` so names stay
short, unambiguous, and package-led.

This document is naming authority only. It does not replace ownership contracts
in `ANDROID_JAVA_HOST_STRUCTURE.md`.

## Naming Strategy

- prefer package context over long class prefixes
- keep class names role-first and short
- use one canonical term per concept
- avoid stacked synonyms in one class name (`Host` + `Bridge` + `Callbacks`)
- keep behavior-neutral mechanical renames separate from behavior changes
- keep subsystem ownership explicit where needed:
  - use `Harness` for app/activity/app-shell concerns
  - use `Widget` for portable terminal-surface consumer concerns

## Event Key Grammar

- `appendEvent(...)` keys must use `domain.subject.action`
- each segment is lowercase and underscore-safe
- dynamic values belong in key/value suffixes after a space, not in key tokens
  (example: `product.selection.copy result=ok chars=12`)

### Event Suffix Contract

- stable key token first, then whitespace-separated `key=value` pairs
- preferred suffix keys: `reason`, `status`, `result`, `detail`, `rows`,
  `cols`, `size`, `focus`, `shown`, `hidden`, `manual`, `alive`, `chars`
- do not encode dynamic values in event tokens (`foo.bar.value-123` is invalid)
- keep status/result values lowercase and underscore-safe where possible

### JNI Symbol Rule

- do not introduce new `native*Shell*Bridge` symbols in
  `NativeBridge.java`
- use session/selection/surface/readiness vocabulary instead

## Glossary

- `Readiness`: current product-operable state for Android userland
- `Provisioning`: filesystem/prefix materialization and artifact staging
- `BaselinePackages`: required package set needed for first-class use
- `PackageManager`: user-facing package CLI integration (`zide-pm`)

- `Controller`: owns behavior/state transitions for one concern
- `Assembly`: wires a construction graph and returns immutable assembled result
- `Factory`: creates related objects without owning runtime policy
- `Bridge`: adapts one interface boundary to another
- `Callbacks`: typed callback contract passed into an owner
- `Native`: JNI/NDK boundary only

## Package Rules

- keep top-level domains explicit: `debug`, `gesture`, `host`, `input`,
  `scroll`, `selection`, `session`, `userland`
- when a domain grows, split by concern and shorten local class names instead
  of adding more prefixes
- for host-heavy seams, prefer child packages (for example `host.runtime`,
  `host.userland`, `host.lifecycle`) and use local names like
  `RuntimeAssembly`, `WorkflowCallbacks`, `LifecycleController`

## Practical Conventions

- assembly `Host` seams that only need a `Context` for view construction should
  expose `harnessContext()` rather than `activity()` to avoid implying the
  Activity is the widget backbone
- shell-blocker presentation wiring uses `ShellPresentationHostInputs` on
  `WidgetAssembly.Host` so the host interface does not import userland value
  classes; `ShellInputView.Host` must be passed explicitly into input assembly
  callbacks, never cast from `Context`
- use `TerminalWidgetInstance` for the harness-owned bundle of one terminal’s
  surface + selection + gesture seams; do not use it as a generic service locator
- use `TerminalWidgetCompositionAssembly.compose` to combine
  `InteractionAssembly.Result` with `WidgetAssembly.Result` into
  `TerminalWidgetInstance`; shell/chrome/view-mode outputs stay on
  `WidgetAssembly.Result` — it is not the terminal-instance factory by itself
- reserve **slot** / **per-instance** vocabulary for future multi-terminal
  hosting described in `ANDROID_JAVA_HOST_STRUCTURE.md` (contract only; no tab
  product behavior implied by the name alone)
- use `TerminalWidgetSlotId` on `InteractionAssembly.Host` and
  `WidgetAssembly.Host`; pass the same slot into `TerminalWidgetCompositionAssembly.compose`
  as the first parameter — today only `PRIMARY`
- `TerminalWidgetSlotId.checkActiveProductTerminalSlot` is the single choke point
  for “active slot” wiring today; assemblies call it at interaction assembly,
  widget assembly, and composition entry
- map product terminal slot → `ShellViewId` only via
  `ProductTerminalSlotShellMapping.shellViewIdForTerminalSlot` — do not sprinkle
  `ShellViewId.TERMINAL` for active product shell routing outside that seam
- construct product `AppShellNavigation` with `forProductTerminalSlot`; use
  `applyProductTerminalShellViewActive` on view-mode apply instead of invoking
  `ProductTerminalSlotShellMapping` again on hot paths
- `AppShellNavigation` does not expose a public active-shell-view setter; product
  paths use `applyProductTerminalShellViewActive`; `AppShellViewState` construction
  rejects null `ShellViewId` at harness boundaries (contract checks, not product tabs)
- chrome drawer sidebar: use `applyChromeDrawerSidebarOpen` /
  `applyChromeDrawerSidebarClosed` on `AppShellNavigation` (and matching
  `ChromeController.Host` methods) — no generic boolean sidebar setter
- chrome IME visibility on `ChromeController.Host`: `chromeImeVisibilityPresent`,
  `applyChromeImeVisibilityHidden`, `applyChromeImeVisibilityFromOpenAttempt` — no
  generic boolean `setImeVisible` on that seam; `ChromeFactory` takes
  `ChromeImePolicyInput` from `WidgetAssembly.Host` (not raw `BooleanSupplier` /
  `Consumer<Boolean>` for IME assembly)
- `WidgetAssembly.Host`: no primitive `imeVisible` / `setImeVisible`; use
  `SurfaceWidgetHostImeVisibility` for surface reads and `ChromeImePolicyInput` for chrome
  assembly (status/viewport/input hosts keep their own seams)
- activity IME scratch: `ProductHostImeState` on `ZideActivity` (one instance) — not repeated
  `() -> imeVisible` / `this::setImeVisible` closures across status/input/widget assembly
- host callback IME read/write: `HostImeStateAccess` (implemented by `ProductHostImeState`) on
  `StatusViewAssembly.Host`, `ViewportCallbacks`, and `InputAssembly.Host` — not raw
  `BooleanSupplier` / `Consumer<Boolean>` pairs on those adapters
- terminal host keep-screen-on default: `ProductHostKeepScreenOnPolicy` applies
  `FLAG_KEEP_SCREEN_ON` to the activity window — not ad-hoc flag mutations in `ZideActivity`
- in `ZideActivity`, use one authoritative `static final` slot field (e.g.
  `ACTIVE_PRODUCT_TERMINAL_SLOT`) for interaction/widget/composition wiring
  instead of repeating `PRIMARY` literals
- do not add `TerminalWidgetSlotId` to `ChromeFactory` / `ChromeController`
  construction until per-slot chrome policy is scoped (see structure doc freeze)
- do not include `Terminal` when package already scopes terminal host context
- reserve `Product` only for user-facing product behavior distinctions
- reserve `Host` for boundary context where needed; do not repeat it when the
  package or role already encodes host ownership
- avoid `Debug`-view-first naming for new app-shell seams; diagnostics should
  default to logging/scripted flows unless an explicit debug UI milestone opens
- keep JSON/wire/schema keys stable unless a migration is explicitly scoped

### Redundancy Pressure Rule

- package path is primary context (`.../terminal/<domain>/...`); method/class
  names should be concise by default
- avoid redundant pairs like `ProductTerminal*`, `Terminal...Controller` inside
  terminal-scoped packages unless the extra term distinguishes a real competing
  concept
- allow `Product` only when contrasting product UI/runtime behavior against
  debug/operator behavior in the same owner
- prefer naming by behavior (`showSelectionActionMode`, `syncHandles`) over
  ownership echo (`showSelectionActionMode`, `syncTerminalSelectionHandles`)
- do not run broad rename sweeps inside behavior/refactor waves; stage naming
  normalization as mechanical slices once queue authority explicitly opens it

## Rename Campaign Rules

- one mechanical slice at a time
- compile after each slice with:
  `./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac`
- update this naming contract and the Java ownership contract in the same slice
  when naming boundaries move

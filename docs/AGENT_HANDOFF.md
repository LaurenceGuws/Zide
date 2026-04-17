# Handoff

Session entrypoint only. Keep this file short, stable, and current.

## Active Focus

- Product lane: Android terminal excellence
- Active ticket: `AN-A1` interactive Neovim terminal baseline
- Current phase: cleanup, refactor, and standardization (no expansion work)
- Execution rule: run Android queue first; reopen shared renderer work only
  when Android proves the next direct blocker

## Workflow Contract

1. Read the active queue: `docs/todo/android/implementation.md`.
2. Confirm the cut against the source-of-truth docs for that concern:
   `ANDROID_JAVA_HOST_STRUCTURE.md` (ownership),
   `ANDROID_JAVA_NAMING_CONTRACT.md` / `ANDROID_ZIG_BRIDGE_NAMING_CONTRACT.md`
   (naming), and `ANDROID_TERMINAL_HOST_PLAN.md` (architecture boundaries).
3. Take the next smallest cut from `Current Focus`.
4. Validate build + deploy + manual device behavior.
5. Update docs in the same change.
6. Commit small, cohesive units on `main` unless user says otherwise.

When `docs/todo/android/implementation.md` contains a `Milestone Queue`:

- execute only the current milestone scope
- keep commits small, but continue through the milestone until its exit criteria
  are met
- stop at milestone boundary and report:
  `Milestone reached per docs, architect review required.`
- do not self-advance to the next milestone
- include `Blocked by review needed: true|false` in every progress update

## Android Cleanup Execution Contract (No Ambiguity)

Use this when the Android lane is in cleanup/refactor/standardization mode.

- Priority order is strict:
  1) explicit `Active TODO` next-line item in
     `docs/todo/android/implementation.md`
  2) ownership/naming/architecture authority docs
  3) campaign charter guidance
- Do not rephrase charter text as permission to reorder the queue.
- If a proposed cut does not exactly match the current explicit next-line item,
  stop and report mismatch before editing code.
- Do not add process/ceremony scripts, lint gates, or precommit tooling unless
  the user explicitly asks.
- Queue updates must describe simplification outcomes, not helper-name
  inventories.

Required per-commit update format:

- `Commit:` `<hash> <subject>`
- `Queue line (exact):` quote exact current next-line item before the cut
- `Completed cut:` one concrete behavior-preserving change description
- `Files touched:` concrete path list
- `Validation:` exact commands run and result
- `Next work:` exact next-line item after updating queue state

## Source of Truth Map

- Active plan/todo/workflow:
  `docs/todo/android/implementation.md`
- Java ownership contract:
  `app_architecture/platform/android/ANDROID_JAVA_HOST_STRUCTURE.md`
- Zig bridge naming contract:
  `app_architecture/platform/android/ANDROID_ZIG_BRIDGE_NAMING_CONTRACT.md`
- Shell readiness baseline history/decision record:
  `app_architecture/platform/android/ANDROID_SHELL_BRINGUP_PLAN.md`
- Terminal-host architecture authority:
  `app_architecture/platform/android/ANDROID_TERMINAL_HOST_PLAN.md`

## Current Ownership Snapshot

- `GestureStateController`: pinch and scrollback budget/state
- `TerminalChromeController`: IME/sidebar/assist-bar policy
- `TerminalSurfaceHostController`: surface host wiring
- `TerminalViewportController`: visible viewport/inset authority
- `SelectionController`: selection mutation/chrome/autoscroll owner
- `../zide-mobile-pm`: mobile package/artifact production
- JNI export ownership: native bridge now exports only current package-owner
  symbols with Java owner `uk.laurencegouws.terminal`
- Zig bridge API naming pass landed in `src/android_bridge_exports.zig` and
  `src/platform/android_runtime_bridge.zig` to remove stale bridge terminology;
  JNI exports are now split into `src/android_bridge_exports/*.zig` ownership
  files
- Session/selection bridge naming now uses concise runtime API names in
  `src/platform/android_runtime_bridge.zig` with matching JNI helper updates
- terminal session helper seam now lives in
  `src/app/terminal/terminal_session_runtime_factory.zig`
- retired Zig bridge terms include `note*` host/probe entrypoints and
  `ProbeStatus/ProbeState`
- GLES surface status module path is now
  `src/platform/android_gles_surface_status.zig`
- Zig naming contract now includes an explicit forbidden-terms checklist for
  active Android bridge/runtime code
- Java naming authority now includes event suffix contract and
  `native*Shell*Bridge` symbol guidance in
  `ANDROID_JAVA_NAMING_CONTRACT.md`

## Java Hygiene Hotspots (Reassessed)

- `selection/SelectionController.java` remains the largest Java owner
  seam (~1101 lines) and is still monolithic by design.
- `ZideActivity.java` is materially thinner (~615 lines) but remains
  the highest orchestration-pressure seam (~803 lines current after
  callback-host inlining).
- `host/ui/WidgetAssembly.java` (~320 lines) remains callback-fan-out heavy,
  but the dedicated `WidgetCallbacks` adapter has been removed.
- `input/ShellInputView.java` (~545 lines) is now a top practical risk seam
  because it combines dense IME/hardware-key behavior with long methods.
- `host/interaction` adapter depth is now a primary simplification target:
  fresh audit shows several bridge/callback classes are near-100% forwarding
  and can be collapsed without changing owner behavior.
- latest waves collapsed relay-only selection/gesture/workflow adapters;
  continue targeting high-forwarding seams with net file/method deletions.
- latest cut also collapsed status relay adapters (`StatusBridge`,
  `StatusCallbacks`) by composing `StatusController.Host` directly in
  `StatusViewAssembly`.
- latest cut also removed `host/interaction/SelectionCallbacks`; selection host
  contracts are now provided directly at `InteractionFactory`.
- latest cut removed `host/interaction/GestureStateBridge`; gesture host
  contracts now flow directly into `GestureStateController`.
- latest cut removed `host/lifecycle/LifecycleCallbacks`; lifecycle host
  contracts now flow directly from `ZideActivity` into `LifecycleController`.
- latest cut removed `host/ui/ChromeCallbacks`; chrome callbacks now come
  directly from `ChromeFactory` without a relay adapter class.
- adapter-depth checkpoint vs baseline `2a25e5ac`:
  - `Callbacks`: `26 -> 21` files (`-601` lines, `-76` methods)
  - `Bridge`: `13 -> 9` files (`-471` lines, `-56` methods)
- `userland/UserlandInstaller.java` (~425 lines) remains large but cohesive;
  keep watch-only unless behavior complexity expands.
- `host/surface/SurfaceController.java` and `host/ui/ChromeController.java`
  have very high recent churn; keep frozen unless the queue explicitly reopens
  those lanes for a concrete behavior bug.

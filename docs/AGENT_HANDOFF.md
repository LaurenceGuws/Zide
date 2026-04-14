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

- `TerminalGestureStateController`: pinch and scrollback budget/state
- `TerminalChromeController`: IME/sidebar/assist-bar policy
- `TerminalSurfaceHostController`: surface host wiring
- `TerminalViewportController`: visible viewport/inset authority
- `TerminalSelectionController`: selection mutation/chrome/autoscroll owner
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

# Terminal Tabs TODO

## Scope

Make `--mode terminal` viable for daily developer use with backend-owned tab management that stays FFI-ready.

## Constraints

- Keep tabs in a backend workspace layer above `TerminalSession`.
- Keep SDL/UI tab chrome as a projection of backend state, not the source of truth.
- Focus on terminal-only mode first; panes/splits and richer IDE layouts are out of scope.
- Keep background-tab polling/lifecycle explicit and resource-aware.
- Keep exported FFI ownership rules explicit.

## Key References

- `app_architecture/terminal/TERMINAL_WORKSPACE.md`
- `app_architecture/terminal/TERMINAL_API.md`
- `app_architecture/terminal/ffi/BRIDGE_DESIGN.md`
- `app_architecture/terminal/ffi/EVENT_INVENTORY.md`
- `app_architecture/terminal/ffi/EVENT_ABI.md`
- `docs/todo/terminal/ffi_bridge.md`

## Status

Lower-layer ownership is in the right place: the backend workspace exists and terminal-mode tabs are live, but the FFI surface is still single-session and the battle-test/regression authority is still incomplete.

## TODO

### TABS-00 Scope Lock And Architecture Contract

- [x] `TABS-00-01` Write the terminal workspace contract doc and define tab ids, active-tab behavior, close policy, and metadata ownership.
- [x] `TABS-00-02` Define the resource policy for background tabs.

### TABS-01 Backend Workspace Implementation

- [x] `TABS-01-01` Add a backend workspace owner for multiple terminal sessions.
- [x] `TABS-01-02` Add workspace metadata synchronization for title/cwd/alive/exit status.
- [x] `TABS-01-03` Add deterministic workspace tests for create/switch/close/reorder/exit.

### TABS-02 Terminal-Only Mode UX Integration

- [x] `TABS-02-01` Render and drive terminal tabs in `--mode terminal`.
  Notes: shared terminal target invalidates on tab switch; theme reload remaps default colors correctly; single-tab bar visibility is config-gated; tab-count transitions force immediate grid resize.
- [x] `TABS-02-02` Add terminal tab actions and default keybinds.
  Notes: includes new/close/next/previous/index activation and `Ctrl+Shift+Left/Right` aliases.
- [x] `TABS-02-03` Handle tab-close edge cases for live processes.
  Notes: close-confirm modal is core-driven; keyboard and mouse confirmation work; last-tab close requests app shutdown in terminal-only mode.

### TABS-03 FFI Extension For Workspace/Tabs

- [ ] `TABS-03-01` Extend the FFI design docs with the workspace and tab-id model.
- [ ] `TABS-03-02` Add FFI workspace operations with explicit ownership and stable ids.
  Notes: baseline ops are create/close/activate/list/current tab.
- [ ] `TABS-03-03` Add a multi-tab smoke-host flow.

### TABS-04 Battle-Test Harness And Rollout

- [ ] `TABS-04-01` Define a terminal-only manual battle-test matrix for long-running tab workflows.
- [ ] `TABS-04-02` Add replay/regression signals for workspace and tab lifecycle.


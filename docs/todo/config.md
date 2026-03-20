# Config TODO

## Scope

Treat Lua config as a core subsystem with an explicit parser, runtime, and reload contract.

## Priorities

- Align parser, runtime, and reload behavior.
- Make defaults vs overrides explicit.
- Normalize validation and diagnostics.
- Document alias and compatibility policy.
- Keep public examples accurate.

## Integration Points

- `app_architecture/CONFIG.md`
- `assets/config/init.lua`
- `src/config/lua_config.zig`
- `src/main.zig`
- `src/input/input_actions.zig`
- `src/ui/renderer.zig`
- `src/ui/widgets/editor_widget_draw.zig`
- `src/ui/widgets/terminal_widget_draw.zig`

## Current Surface

Implemented today:

- Logging filters and SDL log level
- Theme palette and syntax colors
- Per-domain theme overrides
- Font rendering controls
- Editor wrap and render budgets
- Editor and terminal ligature settings
- Terminal cursor, blink, focus-reporting, and scrollback options
- Shared terminal shell path and start-location defaults
- Keybind routing with default-fill merge behavior

Current caveats:

- Startup/load-order truth now has a stricter documented contract, but reload
  truth for some startup-applied settings still needs fuller field-by-field
  authority.
- Broad test-harness coverage still lags the stricter runtime truth; `test-config`
  now covers the config lane directly, but the wider `tests/` tree still needs
  Zig 0.15 cleanup.
- Legacy aliases still exist without a fully documented policy.
- AltGr correctness was resolved, but broader binding coverage is still incomplete.

## Milestones

### CFG-01 Contract and Docs Baseline

- [x] `CFG-01-01` Replace the old logging-only config doc with a real subsystem doc
- [x] `CFG-01-02` Create a dedicated config tracker
- [x] `CFG-01-03` Classify each field as reloadable, restart-only, partial, or legacy

### CFG-02 Runtime Truth Alignment

- [x] `CFG-02-01` Decide whether app, editor, and terminal fonts are truly separate
  Runtime now treats app chrome, editor text, and terminal text as separate font owners with field-by-field fallback to `app.font`.
- [ ] `CFG-02-02` Make reload behavior explicit for every startup-applied field
- [ ] `CFG-02-02D` Add an explicit terminal-only window chrome config surface
  - Intended direction:
    - `terminal.window_chrome.mode = "native" | "integrated"`
  - This must be documented with explicit interaction rules against
    `terminal.tab_bar.*`; integrated chrome cannot silently inherit the current
    full-width dynamic tab behavior.
  - The config surface should not be Windows-only; Windows is just the first
    native implementation target.
- [x] `CFG-02-02C` Add a shared terminal shell config surface
  `terminal.shell.path` is now parser/runtime-owned and applies to future PTY sessions across IDE/editor/terminal modes; explicit launcher/CLI `--shell` still overrides it.
- [x] `CFG-02-02B` Make per-domain font path/size reloadable
  Config reload now reapplies `app.font`, `editor.font`, and `terminal.font` independently at runtime instead of collapsing them to one shared effective stack.
- [x] `CFG-02-02A` Define strict startup application phases
  `app_architecture/CONFIG.md` now owns the bootstrap phases:
  load/merge -> pre-window settings -> renderer init options -> startup mutables
  -> app state construction -> reload-only for explicit reloadables.
- [x] `CFG-02-03` Reapply `font_rendering` settings on config reload or mark them restart-only
  Reload now reapplies text and font-rendering options and refreshes terminal sizing.

### CFG-03 Input and Binding Correctness

- [x] `CFG-03-01` Finish modifier-model truth for keybinds
  AltGr support is now handled consistently across parse, merge, and runtime match behavior.
- [ ] `CFG-03-02` Document and test keybind merge semantics end to end
  Partial: merge-by-default is implemented, but end-to-end config coverage remains thin.
- [ ] `CFG-03-03` Extend Lua-configurable bindings to pointer gestures on the same action layer

### CFG-04 Validation and Compatibility Policy

- [ ] `CFG-04-01` Normalize validation behavior across config sections
  Partial: invalid-value warning and fallback behavior is in place for several high-use fields, but not yet uniform.
- [ ] `CFG-04-02` Define and document alias policy
- [ ] `CFG-04-03` Make parse failures and allocation failures consistent

### CFG-05 Coverage and Reload Authority

- [ ] `CFG-05-01` Add config field-matrix tests for parser shape and merge behavior
  Partial: `src/config_tests.zig` and `zig build test-config` now provide an initial authority.
  The dedicated config root is source-adjacent on purpose so Zig 0.15 module-path rules do not break the config validation lane.
- [ ] `CFG-05-02` Add reload authority for every field classified as reloadable
- [ ] `CFG-05-03` Keep defaults and docs synchronized as part of every config change
  Partial: the policy exists; the remaining work is enforcement.


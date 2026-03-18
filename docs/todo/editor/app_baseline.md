# Editor App Baseline

## Scope

Reach a clean Notepad-grade baseline for editor-only usage and shared IDE/editor
host usage before optimization-led work resumes.

This queue owns:

- basic editor chrome and action entrypoints
- file/open/save/save as and untitled-buffer flow
- common editor shortcuts and interactions
- user-friendly editor Lua config defaults/surfaces
- user-friendly editor CLI/opening behavior

This queue does not own:

- deep text-engine semantics work tracked in `protocol.md`
- tree-sitter/grammar rollout tracked elsewhere
- optimization-led render work unless it directly supports this feature lane

## Constraints

- Prefer shared IDE/editor-host surfaces over editor-only duplicate stacks.
- Keep editor widget code focused on editing/view behavior, not app-shell policy.
- Integrate features with undo/redo, selection, search, file/session lifecycle,
  config, and rendering rather than bolting on one-off behavior.
- User-facing config and CLI should be simple and discoverable from the start.

## Current Product Priority

1. Basic editor chrome and file flow.
2. Common shortcuts, mouse interactions, and expected editing UX.
3. Friendly editor Lua config and CLI behavior.
4. Only then: optimization and reference-repo comparison.

## Initial Worklist

- [ ] `ED-APP-01` Basic editor chrome surface
  - Add a simple editor action surface for `New`, `Open`, `Save`, `Save As`,
    `Find`, and `Replace`.
  - Keep the presentation lighter than a full Notepad clone, but make the
    operations obvious and available without relying on the initial buffer.
  - Reuse shared IDE/editor host routing where possible.
  - Progress:
    - Landed the first shared-host slice: `OptionsBar` now exposes real `File`
      and `Edit` actions for `New`, `Open`, `Save`, `Save As`, and `Find`
      instead of static labels.
    - Added a shared status-bar path prompt for `Open` and `Save As` so
      editor-only mode can open/save beyond the initial buffer without
      inventing a separate editor-only dialog stack.
    - `Ctrl+S` on an untitled buffer now routes into the same shared `Save As`
      prompt instead of silently doing nothing.
    - `Replace` now also routes through the same shared host prompt surface and
      reuses the editor's existing search state instead of adding a second
      search/replace stack.
    - Remaining work on this item: cleaner menu/action routing, replace-all UX,
      and follow-up polish on the basic chrome surface.

- [ ] `ED-APP-02` File lifecycle and untitled flow
  - Support a clear untitled-buffer baseline for editor mode.
  - Make `new`, `open`, `save`, and `save as` work cleanly through the shared
    editor/session host path.
  - Ensure dirty-state handling is surfaced clearly enough for basic usage.
  - Progress:
    - Opening a file now reuses an already-open editor tab for the same file
      instead of spawning duplicates.
    - Opening a file into the initial clean untitled editor now replaces that
      buffer instead of creating a second editor tab.
    - `Open...` and `Save As...` prompts now seed sensible paths for untitled
      editors based on the current working directory.
    - Remaining work on this item: unsaved-changes guards and any explicit
      close/discard surface for dirty editors.

- [ ] `ED-APP-03` Editor CLI behavior
  - Audit and improve editor-only CLI file opening behavior.
  - Make direct file-open flows obvious and forgiving.
  - Decide how multiple file arguments should map onto the current tab/session
    model.
  - Progress:
    - Startup now opens the first non-mode positional CLI file argument
      directly in editor/IDE mode instead of always booting into the seeded
      welcome buffer.
    - Remaining work on this item: multi-file CLI policy and any line/column
      CLI syntax if we decide to support it.

- [ ] `ED-APP-04` Common shortcuts and interactions
  - Fill the standard editing shortcut set before optimization-led work.
  - Cover common mouse/selection behavior and familiar movement rules.
  - Progress:
    - Added a direct `Ctrl+Shift+S` editor shortcut for `Save As` through the
      same shared path-prompt flow used by menu and mouse action routing.
    - Added a direct `Ctrl+H` editor shortcut for replace, reusing the same
      shared search/prompt routing as the options bar instead of creating a
      separate keyboard-only path.
    - Added a standard `Ctrl+A` editor shortcut for select-all through the
      normal editor action path instead of special-casing selection in input
      handling.
    - Added `Ctrl+Shift+K` delete-line through a real editor-core line delete
      operation instead of faking it through cursor-only behavior.
    - Added `Ctrl+D` duplicate-line through a real editor-core line operation,
      keeping the action/binding split intact so Lua can remap it later if we
      want different defaults.
    - Added a runtime-backed `Ctrl+W` close-editor shortcut for clean editor
      tabs, with last-editor fallback to a fresh untitled buffer instead of
      leaving the host in an empty editor state.
    - Dirty close now routes through the same shared status-bar prompt surface
      and requires explicit discard confirmation instead of silently refusing
      or immediately dropping changes.
    - Added runtime-backed `Ctrl+Tab` and `Ctrl+Shift+Tab` document cycling for
      editor focus using the shared mixed-tab host state instead of editor-only
      index math.
    - Added `Ctrl+G` go-to-line through the shared status-bar prompt surface,
      including `line` and `line:column` input parsing instead of a special
      case dialog.

- [ ] `ED-APP-05` Friendly Lua config for editor usage
  - Make common editor behavior easy to configure with sane defaults.
  - Keep names predictable and aligned with the actual subsystem ownership.

## Shared Integration Targets

- `src/app/app_state_runtime_wiring.zig`
- `src/app/editor/open_file_runtime.zig`
- `src/app/modes/ide/host.zig`
- `src/config/lua_config_iface.zig`
- `src/config/lua_config_ziglua_parse.zig`
- `assets/config/init.lua`

## Notes

- `modularization.md` remains the boundary-cleanup authority when structural
  cleanup is needed to keep this work neat.
- This queue is the authority for the next feature-oriented editor lane.
- `editor_action_baseline_register.md` is the practical action/behavior
  checklist for deciding what belongs in the current Notepad-grade baseline
  while actual bindings stay Lua-driven.

# Status Bar Mode Host

This document defines the current direction for the shared status bar in native
editor and IDE usage.

It exists to replace the accidental "default status bar plus temporary prompt"
model with an explicit mode-host model.

## Problem

Current status-bar behavior is too implicit:

- editor-focused status content behaves like the default baseline
- temporary workflows such as path entry and search compete for the same space
- the bar becomes cramped because active prompts are layered onto content that
  still acts like it is always entitled to remain visible
- shortcut and hint ownership is less clear than it should be

This is the wrong long-term seam for file flow, search, command entry, and
other keyboard-first workflows.

## Direction

Treat the shared status bar as a mode host.

There is no content-neutral default layout.

Instead:

- the focused surface selects a passive status-bar mode
- temporary workflows push an active status-bar mode
- the active mode fully replaces passive content while it is visible

This means the current editor-focused status content should stop being treated
as "the default bar" and should instead become an explicit `editor` mode.

## Mode Classes

### Passive modes

Passive modes are selected by focused surface when no active workflow is open.

Initial passive-mode set:

- `editor`
- `terminal`

Later candidates:

- `workspace`
- `welcome`

### Active modes

Active modes temporarily take full ownership of the status bar.

Initial active-mode set:

- `path`
- `search`
- `command`
- `confirm`

Later candidates:

- `symbol`
- `buffer`
- `workspace-switch`

## Resolution Rule

The status bar should resolve content in this order:

1. if an active mode is present, render the active mode
2. otherwise render the passive mode for the currently focused surface

Meaning:

- editor focus with no active workflow renders passive `editor`
- terminal focus with no active workflow renders passive `terminal`
- starting file-open from editor pushes active `path`
- while `path` is active, editor status content disappears completely instead of
  competing for horizontal space

## Ownership

Each status-bar mode should own:

- layout for the bar while the mode is active
- visible content and hint text
- input grammar
- completions and candidate-list behavior where applicable
- accept/cancel semantics
- mode-local shortcut handling while active

The status-bar host should own:

- active-vs-passive mode selection
- focus-aware passive mode resolution
- push/pop lifecycle for active modes
- rendering dispatch to the current mode

## File Flow Direction

Do not prioritize Linux portal or native file-dialog integration as the primary
file-flow direction.

Instead, current direction is:

1. make file flow a first-class status-bar interaction
2. implement file open / save-as through an explicit `path` mode
3. make `path` mode keyboard-first and completion-driven

The desired `path` mode should behave closer to a native Zide `fzf`-style path
surface than to an OS dialog shim.

Initial `path` mode expectations:

- fuzzy matching over project/workspace files
- current working directory and workspace-root awareness
- support for direct path entry when desired
- recent-file bias where appropriate
- clear accept/cancel behavior
- enough room for completions and hints because passive status content is not
  competing for the same space

## Why This Cut Is Better

- it makes the current editor status content honest by naming it `editor` mode
- it prevents search/path/command interactions from feeling cramped
- it gives one reusable seam for multiple workflows instead of inventing a new
  prompt or dialog surface for each feature
- it keeps behavior consistent across Linux and Windows instead of growing a
  Linux-only file-dialog dependency
- it provides a natural place for mode-scoped shortcuts and completions

## Near-Term Execution Order

1. treat current editor-focused status content as passive `editor` mode
2. add status-bar mode-host state and routing
3. land `path` as the first active mode target
4. move current shared path-prompt behavior behind `path` mode
5. follow with `search` and `command`

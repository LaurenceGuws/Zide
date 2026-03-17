# Terminal Widget Boundary Split TODO

## Scope

Continue the cleanup that separates:

- terminal engine truth
- host/runtime integration
- app/widget chrome

The goal is to stop treating `TerminalWidget` and `TerminalSession` as mixed
owners of terminal semantics, host policy, and viewport chrome.

Review aid:

- `app_architecture/terminal/BOUNDARY_SMELL_CHECKLIST.md`

## Why Now

Recent terminal dogfooding closed a cluster of scrollbar/focus/hover bugs by
moving scrollbar UI out of terminal-content rendering and into app chrome.
That cut exposed the next structural focus clearly:

- terminal viewport truth belongs to the engine/backend contract
- viewport chrome belongs to app/runtime/widget chrome
- host policy should not keep accreting inside `TerminalSession`

This is the next highest-value cleanup lane after the recent scrollbar/chrome
boundary cut.

## Constraints

- Keep native and FFI aligned to the same host/engine contract.
- Do not widen FFI casually; prefer deriving host chrome from existing
  viewport/metadata state where possible.
- Prefer clean ownership cuts over compatibility shims.
- Do not move terminal semantics out of the engine just to make the widget
  smaller.

## Current Boundary Smells

- `src/terminal/core/session_interaction.zig`
  - backend-owned clipboard paste policy still includes host behavior such as
    scrollback reset, bracketed-paste framing, OSC 5522 preference, and input
    byte filtering.
- `src/terminal/core/session_host_queries.zig`
  - mixes engine-derived metadata with host-facing presentation convenience such
    as foreground-process title substitution and close-confirm signal assembly.
- `src/terminal/ffi/shared.zig`
  - bridge event synthesis is correct as bridge ownership, but should remain a
    bridge concern rather than dragging host policy back into core/session code.
- `src/ui/widgets/terminal_widget*.zig`
  - widget code should keep shrinking toward input mapping + content rendering
    glue, not host policy or viewport chrome ownership.

## TODO

- [ ] `WBS-01` Audit terminal host-policy helpers and classify each as engine,
  bridge, or app/widget ownership.
- [ ] `WBS-02` Move remaining viewport chrome ownership out of terminal widget
  code where it is still mixed with content behavior.
- [ ] `WBS-03` Revisit clipboard paste ownership and decide the correct split
  between terminal protocol semantics and host paste policy.
- [ ] `WBS-04` Trim `TerminalSession` host conveniences that are really host
  policy rather than engine truth.
- [ ] `WBS-05` Re-check the FFI surface after each cut and only add fields when
  the host cannot derive required behavior from existing engine state.

## Done When

- Terminal viewport truth is exported once and consumed by both native and FFI
  hosts without native-only shortcuts.
- Widget chrome is owned by app/runtime chrome paths rather than terminal
  content rendering/input internals.
- `TerminalSession` reads more like a narrow engine/host seam and less like a
  container for desktop-only behavior.

## Audit Notes

`WBS-01` initial audit, 2026-03-17:

### Engine Ownership

- `src/terminal/core/session_interaction.zig`
  - bracketed-paste mode detection
  - focus-reporting, auto-repeat, and mouse-reporting mode state
  - OSC 5522 protocol emission itself
- `src/terminal/core/session_host_queries.zig`
  - raw activity summary
  - raw close-confirm ingredients:
    - alt-screen
    - mouse-reporting
    - foreground process presence
    - semantic command activity
- `src/terminal/core/terminal_core.zig`
  - title, cwd, semantic prompt, progress, and scrollback truth

These are terminal-derived facts or protocol semantics. They should stay in the
engine/backend contract.

### Bridge Ownership

- `src/terminal/ffi/shared.zig`
  - event synthesis for:
    - `title_changed`
    - `cwd_changed`
    - `clipboard_write`
    - `child_exit`
    - `alive_changed`
  - cached last-seen host-facing metadata for FFI event generation

This is host-integration glue, but it belongs to the bridge layer rather than
to native widget/runtime code or terminal core.

### Native Host / App Ownership

- `src/terminal/core/session_interaction.zig`
  - `pasteSystemClipboard(...)`
    - resets scrollback to live bottom before paste
    - decides fallback order between OSC 5522 rich paste and plain text
    - filters bytes during bracketed paste for host safety policy
  - `pasteSelectionClipboard(...)`
    - same host-facing paste policy shape, minus the scrollback reset
- `src/terminal/core/session_host_queries.zig`
  - `copyMetadata(...)` currently substitutes title with foreground process
    label when present
  - `closeConfirmSignals(...)` packages host-facing confirmation policy into a
    convenience struct

These are the main remaining "native path convenience in backend clothing"
seams. They are useful, but they are not pure engine truth.

### Current Judgment

The ripest next split is still paste ownership.

Why:

- it is the clearest place where host behavior and protocol behavior are mixed
- it affects native UX directly
- it can be split without widening FFI
- it should let `TerminalSession` stop owning desktop-flavored paste policy

Recommended order:

1. `WBS-03` split paste into:
   - engine protocol helpers:
     - bracketed framing
     - OSC 5522 emission
   - native host policy:
     - viewport-follow behavior
     - fallback ordering
     - byte filtering / safety decisions
2. `WBS-04` revisit metadata/title substitution and close-confirm convenience
   after paste is cleanly split

Current progress:

- `WBS-03` first cut landed:
  - native widget code now owns paste policy in
    `src/ui/widgets/terminal_widget_paste.zig`
  - backend/session no longer exposes "paste the system clipboard for me"
    helpers
  - engine still owns bracketed-paste mode and OSC 5522 protocol emission
- `WBS-04` first cut landed:
  - native close-confirm routing in `src/terminal/core/workspace.zig` now
    derives directly from activity + alt-screen + mouse-reporting truth
  - native path no longer depends on `session.shouldConfirmClose()`

Remaining highest-value seam:

- bridge-side and host-side convenience should now be judged separately:
  - native tab policy already consumes raw title plus activity explicitly
  - bridge/FFI still has convenience packaging such as `closeConfirmSignals(...)`
    and title/cwd event synthesis, which is acceptable as bridge ownership but
    should not leak back into engine/session semantics

Additional progress:

- metadata title is now raw engine truth again
- native terminal tab sync explicitly receives foreground-process label through
  workspace sync state and chooses whether to surface it
- title substitution is no longer hidden inside backend metadata copying
- focused widget scan result:
  - remaining terminal widget responsibilities now mostly read as legitimate
    host/widget glue:
    - focus-report routing
    - OSC clipboard handoff to the host clipboard
    - ctrl-open path resolution using raw cwd metadata
    - hover/open/input glue
  - no equally obvious backend-owned native policy seam remains in the current
    widget files
  - this lane should pause unless a new concrete ownership smell appears

### Deferred But Explicit

- FFI progress exposure is intentionally not part of this native boundary lane.
- Native progress chrome now consumes backend truth cleanly enough for this
  phase.
- Bridge progress should come later as a separate semantic-family cut, not as a
  side effect of widget/session cleanup.

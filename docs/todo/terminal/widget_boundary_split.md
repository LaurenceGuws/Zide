# Terminal Widget Boundary Split TODO

## Scope

Continue the cleanup that separates:

- terminal engine truth
- host/runtime integration
- app/widget chrome

The goal is to stop treating `TerminalWidget` and `TerminalSession` as mixed
owners of terminal semantics, host policy, and viewport chrome.

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

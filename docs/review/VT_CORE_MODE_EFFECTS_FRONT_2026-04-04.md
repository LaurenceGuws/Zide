# VT Core Mode Effects Front

Date: 2026-04-04

## Purpose

Name the next exact broader `TerminalCore` sufficiency contradiction after the
execution-face cleanup wave.

## Current Judgment

The next live contradiction is mode/reset effect ownership.

This is where `TerminalCore` still most clearly reads like:

- core decides part of the terminal behavior
- outer code completes the behavior through selection clearing, input snapshot
  publication, alt-exit presentation feedback, and kitty side effects

## Live Pressure

The pressure is concentrated in:

- [terminal_core.zig](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  - `resetState(self)`
  - `eraseDisplayLocked(self, owner, mode)`
- [terminal_core_modes.zig](/home/home/personal/zide/src/terminal/core/terminal_core_modes.zig)
  - `enterAltScreenCore(...)`
  - `exitAltScreenCore(...)`
- [mode_effects.zig](/home/home/personal/zide/src/terminal/core/session/mode_effects.zig)
  - `resetStateLocked(...)`
  - `enterAltScreen(...)`
  - `exitAltScreen(...)`

## Why This Beats Other Candidates

It beats:

- reopening publication without a new named contract
- reopening runtime compatibility cleanup
- forcing resize immediately

Because this cluster still weakens the first-glance story of
`TerminalCore` as the terminal object:

- reset semantics are split between core and outer mode effects
- alt-screen semantics are split between core and outer mode effects
- the outer layer still feels too involved in completing what should read like
  one terminal-mode transition story

## Required Bar

The next move must not be:

- just moving a few helper calls across files
- deleting `owner` parameters without changing ownership
- dragging publication/reporting concerns into core by accident

The next move must:

- define explicit terminal-mode/reset effects where needed
- let outer layers consume those effects deliberately
- make the mode/reset story read more like terminal truth plus honest outer
  consequences

## Decision

The next default VT front is mode/reset effect ownership unless a stronger
named contradiction overtakes it immediately.

## Progress

The first opening slice is now landed:

- [TerminalCore.eraseDisplayLocked(...)](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  no longer takes outer owner shape just to clear selection
- it now returns explicit `EraseDisplayEffect`
- [terminal_core_protocol.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_protocol.zig)
  consumes the selection-clearing consequence explicitly

Why this counts:

- the semantic erase operation now lives more cleanly on `TerminalCore`
- outer code now consumes one explicit consequence instead of being required as
  the hidden completion path

What remains:

- reset and alt-screen mode transitions still read more owner-shaped than this
  new erase slice

The second opening slice is now landed:

- [TerminalCore.resetState(...)](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  no longer takes outer owner shape just to reset kitty image state
- it now performs that terminal-owned reset step through a tiny local kitty
  shim with only:
  - `allocator`
  - `core`
- [mode_effects.zig](/home/home/personal/zide/src/terminal/core/session/mode_effects.zig)
  now keeps input-mode reset as the explicit outer consequence instead of
  passing the whole shell into core reset

Why this counts:

- terminal reset semantics moved further inward
- outer mode effects now read more like honest non-core reset consequences

What remains now:

- alt-screen enter/exit transitions
- presentation/snapshot effects around those transitions

The third opening slice is now landed:

- [terminal_core_modes.zig](/home/home/personal/zide/src/terminal/core/terminal_core_modes.zig)
  now returns explicit `AltScreenEffect` values for enter/exit transitions
- alt-screen core transitions no longer depend on outer owner shape just to
  clear kitty image state
- [mode_effects.zig](/home/home/personal/zide/src/terminal/core/session/mode_effects.zig)
  now consumes explicit outer consequences instead of hard-coding the full
  post-transition choreography inline

Why this counts:

- alt-screen mode transitions now read more like terminal truth plus explicit
  outer consequences
- the shell no longer acts as the hidden completion path for that whole mode
  transition story

What remains now:

- whether snapshot/publication consequences around mode transitions should stay
  as outer effects or want one narrower explicit contract

## Post-Alt Rerank

That remaining question now reads mostly honest.

Why:

- [input_modes.zig](/home/home/personal/zide/src/terminal/core/input_modes.zig)
  `publishSnapshot(...)` is derived input/publication state, not terminal
  mode truth
- [presentation_feedback.zig](/home/home/personal/zide/src/terminal/core/publication/presentation_feedback.zig)
  `noteAltExitPending(...)` is explicitly presentation feedback, not terminal
  transition semantics

So this front is near a real stop-marker:

- erase-display semantics are core-owned with explicit consequences
- reset semantics are more core-owned and no longer need outer owner shape for
  kitty reset
- alt-screen transitions now return explicit mode effects instead of relying on
  hidden shell completion

Current judgment:

- do not keep stretching mode/reset just to chase one more outer consequence
- the next default pressure returns to broader `TerminalCore` sufficiency
  unless one new exact mode/reset contradiction appears

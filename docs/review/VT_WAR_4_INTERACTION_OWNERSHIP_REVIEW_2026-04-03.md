# VT War 4 Interaction Ownership Review

Date: 2026-04-03

## Purpose

Review the strongest remaining War 4 pressure after the handle check:

- host-to-terminal interaction still feels more shell-owned than
  terminal-owned

This is a design review, not an extraction queue.
The question is whether one coherent interaction slab should move closer to
[TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig),
or whether the current shell/runtime ownership is already the honest boundary.

## Reference Pressure

### WezTerm

[Terminal](/home/home/personal/zide/dev_references/terminals/wezterm/term/src/terminal.rs)
feels sufficient because live terminal-driving semantics terminate on the
terminal object itself:

- `advance_bytes(...)`
- `perform_actions(...)`

Its surrounding state remains rich, but the terminal object still reads as the
place where host-driven terminal behavior lands.

### Zide

The comparable live surface is still split across shell/runtime-side helpers:

- output application:
  [terminal_core_feed.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_feed.zig)
- host input/reporting:
  [session/input.zig](/home/home/personal/zide/src/terminal/core/session/input.zig)
- resize/feed/runtime entrypoint shape:
  [session/runtime.zig](/home/home/personal/zide/src/terminal/core/session/runtime.zig)

## What Already Looks Honest

Some of this ownership is likely correct and should not be forced downward:

- transport attach/detach
- PTY writer access
- external child-exit lifecycle
- thread/poll/backlog observation

Those are shell/runtime concerns, not engine truth.

## Strongest Remaining Tension

The tension is narrower:

### 1. Output application still does not read as a core-owned host verb

- [terminal_core_feed.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_feed.zig)
  wraps:
  - lock
  - parser feed
  - publication update

This is not obviously wrong, but it still reads more like "feed the shell"
than "advance the terminal."

### 2. Live host interaction verbs remain concentrated under session input

- [session/input.zig](/home/home/personal/zide/src/terminal/core/session/input.zig)
  owns:
  - key
  - text
  - mouse
  - focus-report
  - color-scheme report
  - direct byte/text send

Current read:

- some of these are transport encoding concerns and may belong outside core
- but as a group they still make the shell/runtime layer feel like the place
  hosts "interact with the terminal"

### 3. Resize still reads as transport/runtime-first

- [session/runtime.zig](/home/home/personal/zide/src/terminal/core/session/runtime.zig)
  exports `resize(...)`
- the current shape emphasizes transport/runtime reporting more than terminal
  object sufficiency

## Likely Missing Slab

If War 4 continues into code, the strongest candidate is now:

- a host-to-terminal interaction contract

Meaning:

- terminal-driving semantic verbs should read as belonging to the terminal
  center
- runtime shell should remain responsible for:
  - synchronization
  - transport
  - lifecycle
  - thread/runtime effects

The key is not "move everything onto `TerminalCore`."
The key is:

- stop making the shell be the place where the host conceptually "talks to the
  terminal"

## Non-goals

Do not treat these as the same thing:

- engine-owned terminal interaction semantics
- PTY writer mechanics
- lifecycle and thread runtime

If a code step collapses those together, it is wrong.

## Current Judgment

This is now a stronger War 4 target than handle storage shape.

Why:

- handle storage is internal and opaque to the public ABI
- interaction ownership affects the actual mental model of the live stack
- it is the clearest remaining point where WezTerm still feels more obviously
  sufficient as "the terminal"

Progress note, later on 2026-04-03:

- the first narrow slice is now in:
  [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  owns `feedOutputBytesLocked(...)` directly
- [terminal_core_feed.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_feed.zig)
  is now narrowed to shell-owned locking plus publication handoff
- this is the right first test of the War 4 thesis:
  - semantic output application moved closer to the engine center
  - locking and publication remained outside the core
  - no transport/runtime concerns were pulled into `TerminalCore`

## Decision Bar

Only open code cuts here if we can name one coherent interaction slab, such as:

- output feed/apply
- resize/reporting contract
- encoded host input semantics

and move it without:

- forcing transport concerns into core
- inventing another fake facade
- breaking the current rule that runtime shell stays responsible for locking
  and transport effects

## Bottom Line

War 4 now has a stronger active design target than handle identity:

- host-to-terminal interaction ownership

If code work opens next, it should begin by choosing one named interaction slab
rather than another shell/query cleanup pass.

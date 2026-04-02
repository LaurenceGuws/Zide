# VT War 4 Keychar Result Shape

Date: 2026-04-03

## Purpose

Define the only result shape that would justify a War 4 code move in the input
lane.

The question is not "can key input move to core?"
The question is:

- can key/char semantic dispatch be expressed as a clean terminal-owned result
  before writer encoding?

## Pattern From The Prior War 4 Wins

The two successful War 4 cuts already established the rule:

- [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  owns the semantic locked verb
- outer shell code owns:
  - locking
  - publication handoff
  - transport/reporting

Examples:

- `feedOutputBytesLocked(...)`
- `resizeLocked(...)`

Any input continuation should obey the same pattern.

## What The Result Must Not Be

The next shape must not be:

- a new "input facade"
- a result that embeds writer handles
- a result that contains already-encoded escape bytes
- a result that decides PTY vs external transport

Those all recreate shell/runtime mechanics under a different name.

## Candidate Semantic Result

The only plausible result family looks like this:

- no action
- terminal key intent
- terminal char intent
- keypad intent
- local fallback intent

More concretely, the semantic decision should be able to answer:

- should this key/char event be suppressed because repeat is disabled?
- should it become a terminal key event?
- should it become a terminal char event?
- should it become keypad intent under current terminal modes?
- should it request local fallback behavior because no writer path should be
  used?

## What Belongs In Semantic Dispatch

These decisions still look terminal-owned:

- app-cursor fallback selection
- app-keypad mode selection
- key-mode flag interpretation
- repeat gating
- ctrl/alt char fallback classification
- alternate scroll-wheel mapping to arrow-key intent

These describe terminal meaning, not transport mechanics.

## What Must Stay In The Outer Shell

These still belong outside core:

- lock acquisition
- writer existence checks
- PTY/external transport selection
- protocol encoding via
  [input.zig](/home/home/personal/zide/src/terminal/input/input.zig)
- raw write calls
- local echo fallback execution when it depends on missing writer state

This means the shell still executes the result.
The core should not encode or emit bytes directly for this lane.

## Current Risk

One part is still awkward:

- local echo fallback is semantically terminal-ish
- but today it is chosen specifically when no writer exists

That makes it the strongest current reason not to rush a code cut.
If local fallback cannot be represented cleanly without smuggling transport
absence into core semantics, the move is not ready.

## Decision

Do not cut code until one exact result type can be named that:

- expresses key/char intent without encoded bytes
- keeps writer/transport mechanics outside core
- handles local fallback honestly instead of hiding it

## Bottom Line

The next War 4 move is justified only if key/char dispatch can follow the same
shape as the earlier wins:

- core owns semantic decision
- shell owns lock, writer, and encoding

If that result shape does not stay crisp, War 4 should remain closed.

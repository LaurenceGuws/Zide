# VT Protocol Reset Split

Date: 2026-04-03

## Purpose

Define and land the first honest split inside the protocol reset front.

The question is:

- what part of DECSTR is truly terminal-owned reset semantics?
- what part remains explicit outer protocol/runtime effect?

## Split

### Terminal-owned DECSTR reset semantics

Now grouped under:

- `src/terminal/core/protocol/terminal_core_reset.zig`

That slab includes:

- parser state reset
- saved charset reset
- title buffer/default-title reset
- grapheme shaping terminal state reset
- column-mode reset
- active-screen state reset
- kitty image reset
- terminal dirty marking for DECSTR

### Explicit outer reset effects

Still outside that core-side owner, intentionally:

- host-reporting flag reset
- input protocol mode reset
- sync-update reset
- input snapshot publication

## Why This Is The Right Line

This removes one strong "protocol script owns reset" story without pretending
that runtime/reporting consequences belong in `TerminalCore`.

That is the maturity win we want:

- stronger terminal-owned reset semantics
- explicit outer effects
- no fake shell-thinning or transport leakage into core

## Current Judgment

This is the first real reset-contract slice.

If DECSTR continues after this, the next move should only be another whole
semantic split, not helper shaving inside `csi_style_reset.zig`.

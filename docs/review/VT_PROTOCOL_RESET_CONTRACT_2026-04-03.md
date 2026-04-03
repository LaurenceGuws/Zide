# VT Protocol Reset Contract

Date: 2026-04-03

## Purpose

Name the next exact VT scrutiny front after the CSI reply/query wave.

The question is no longer:

- can we flatten one more reply/query helper?

The question is:

- what semantic protocol cluster still keeps `TerminalCore` from feeling like
  the terminal object?

## Current Judgment

The strongest next cluster is protocol reset and reset-adjacent mode cleanup.

This is primarily visible in:

- `src/terminal/protocol/csi_style_reset.zig`

and secondarily reinforced by adjacent mode/input/reporting owners.

## Why This Beats Other Candidates

It beats:

- more shell cleanup
- more CSI reply work
- reopening OSC
- generic parser-owner discomfort

Because reset is one of the strongest "this is the terminal" behaviors.

If reset handling still reads like a mixed outer-orchestration procedure rather
than a terminal-centered contract with explicit outer effects, `TerminalCore`
still loses maturity.

## The Exact Contradiction

`applyDecstrReset(...)` still mixes several kinds of responsibility in one
protocol-owned path:

1. terminal parser/state reset
2. terminal screen/state reset
3. protocol/input mode reset
4. host-reporting flag reset
5. sync-update reset
6. publication/snapshot refresh side effects

That means a major terminal behavior still reads like:

- protocol file orchestrates reset
- inner and outer state are both mutated there
- terminal completeness is still partly implied by an outer procedure

instead of:

- terminal-side reset semantics are grouped explicitly
- outer runtime/reporting consequences remain explicit and separate

## Why This Matters For Completion

This directly pressures:

- item 1:
  `TerminalCore` should feel unquestionably like the terminal object
- item 3:
  protocol execution should terminate on contracts that feel terminal-centered
- item 4:
  input/reporting boundaries should stay explicit instead of collapsing into
  one reset blob

## The Likely Split

The likely contract split is:

### Terminal reset semantics

- parser state reset
- saved charset/title/default-title semantics where they are truly terminal
- screen reset
- column mode reset
- terminal-owned image/screen state reset

### Outer protocol/runtime reset effects

- input protocol snapshot refresh
- host-reporting flag reset
- sync-update/runtime reporting reset
- any explicit publication consequences

The point is not to force all reset behavior into core.

The point is to stop one strong terminal behavior from reading like protocol-
owned mixed cleanup.

## Why This Is A Better Next Front

This is more maturity-relevant than another small mode/query cut because reset
is a first-glance ownership signal.

A strong maintainer expects the terminal object to have a clear answer for
"what does reset mean here?"

If that answer still primarily lives in a protocol cleanup file, Zide still
looks like a library center in progress.

## Next Move

Define the exact reset contract split before code:

- what belongs to terminal reset semantics
- what remains an outer protocol/runtime effect

Then take one whole reset slice only if that split stays honest.

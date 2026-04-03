# VT Protocol Reset Rerank

Date: 2026-04-03

## Purpose

Rerank VT scrutiny after the first DECSTR reset-contract split.

The question is:

- does reset still contain another whole semantic slab worth taking?
- or did the first split remove the real contradiction and leave only explicit
  outer effects that should stay outside core?

## What The First Slice Removed

The first reset slice materially changed the story.

Before:

- `csi_style_reset.zig` still read like a mixed protocol-owned reset script
- terminal reset semantics and outer runtime/reporting effects were intertwined

Now:

- terminal-owned DECSTR reset semantics live behind
  `src/terminal/core/protocol/terminal_core_reset.zig`
- `csi_style_reset.zig` keeps only explicit outer reset effects:
  - host-reporting flag reset
  - input protocol mode reset
  - sync-update reset
  - input snapshot publication

That is a real maturity gain for both:

- completion item 1
- completion item 3

## What Reset No Longer Looks Like

Reset no longer reads like:

- protocol file finishes terminal reset semantics by habit

It now reads more like:

- core-side owner handles terminal reset semantics
- outer layers apply the runtime/reporting reset consequences explicitly

That is close to the right story.

## Current Remaining Reset Surface

The remaining surface in `csi_style_reset.zig` is now mostly:

- host-reporting contract reset
- input protocol mode reset
- sync-update reset
- snapshot refresh

Those are not obviously terminal-owned in the same way DECSTR terminal
semantics were.

So the next move must clear a harder bar than the first slice.

## Current Judgment

The reset front is close to a stop-marker.

Why:

- the strongest omitted terminal-owned slab is already moved
- what remains now reads much more like explicit outer consequences than fake
  terminal ownership
- continuing here by momentum risks turning the front into generic cleanup of a
  file that is already telling a more honest story

## Decision

Protocol reset should pause here unless one new reset-owned contradiction is
named explicitly.

The default next pressure returns to broader `TerminalCore` sufficiency and
protocol-execution maturity from this stronger baseline.

# VT Core Protocol Owner Contradiction

Date: 2026-04-03

## Purpose

Name the next broader `TerminalCore` sufficiency contradiction after:

- shell cleanup
- CSI reply/query cleanup
- DECSTR reset cleanup

The question is:

- what still keeps `TerminalCore` from reading like the terminal object even
  after those fronts were flattened?

## Current Judgment

The strongest remaining contradiction is the remaining semantic gravity in:

- `src/terminal/core/protocol/terminal_core_protocol.zig`

This file is cleaner than the old session-era shapes, but it still reads like a
parallel semantic execution center for important terminal behavior.

## Why This Matters

Against Ghostty and WezTerm pressure, the problem is no longer "too many helper
files."

The problem is:

- a strong maintainer still sees one significant semantic protocol owner beside
  `TerminalCore`

That weakens completion item 1 directly:

- `TerminalCore` still risks reading like the dominant field, not the fully
  sufficient terminal object

It also pressures item 3:

- protocol execution still sometimes terminates on a helper owner instead of
  feeling obviously terminal-centered

## What This File Still Owns

`terminal_core_protocol.zig` still carries major terminal-semantic behavior:

- erase display / erase line
- insert/delete/erase chars
- insert/delete lines
- newline / wrap-newline / reverse-index
- scroll-region operations
- cursor-style / tab-at-cursor
- DECRQSS reply assembly
- kitty image clearing
- palette lookup

Some of these may be fine as narrow implementation helpers.

But as a whole, this still looks like too much semantic gravity living beside
`TerminalCore`.

## Why This Beats Other Candidates

It beats:

- reopening reset
- reopening shell survival
- reopening CSI reply/query
- broad host-contract discomfort

Because this is now the clearest place where the library-center story still
looks split.

## The Real Question

The next move is not:

- "delete `terminal_core_protocol.zig` because single-file purity looks nicer"

The next move is:

- decide whether one whole semantic slab inside `terminal_core_protocol.zig`
  still belongs more naturally on `TerminalCore` itself

## Likely First Slabs

The strongest candidates are:

1. screen-edit and erase semantics
2. scroll/newline/reverse-index semantics
3. DECRQSS state/query assembly

The weakest candidates are:

- palette lookup alone
- tiny mechanical helpers with no architectural effect

## Decision

The next active VT front should be a focused owner split inside
`terminal_core_protocol.zig`, not another shell or protocol cleanup detour.

## Progress

The first whole slab is now landed.

What moved onto `TerminalCore`:

- erase display
- erase line
- insert/delete/erase chars
- insert/delete lines

What this changes:

- screen-edit and erase semantics no longer read as primarily owned by
  `terminal_core_protocol.zig`
- that file is less credible as a parallel semantic center
- `TerminalCore` now reads more naturally as the owner of these terminal-edit
  operations

What remains strongest in `terminal_core_protocol.zig`:

- scroll/newline/reverse-index semantics
- DECRQSS state/query assembly
- smaller mechanical helpers like palette lookup and tab/cursor helpers

## Rerank

From the new baseline, the stronger remaining slab is:

1. scroll/newline/reverse-index semantics
2. DECRQSS state/query assembly

Why scroll/newline/reverse-index wins:

- it still shapes live terminal behavior continuously across text/control
  execution
- it still reads as a protocol helper owner for core movement/scroll behavior
- Ghostty/WezTerm pressure is stronger on "basic terminal motion/scroll
  semantics feel owned by the terminal" than on DECRQSS query polish

Why DECRQSS is second:

- it still matters for protocol-execution maturity
- but it is a narrower query/reply contract, not the main live behavioral
  center

## Next Move

Take the scroll/newline/reverse-index slab next.

Do not jump to DECRQSS first just because it is smaller.

## Progress

The second whole slab is now landed.

What moved onto `TerminalCore`:

- newline semantics
- wrap-newline semantics
- reverse-index semantics

What stayed outside:

- lower-level scrolling helpers in `scrolling.zig`

Why that line is right:

- terminal motion/scroll semantics now read as core-owned
- the lower-level scroll machinery still stays in its focused helper owner
- `terminal_core_protocol.zig` loses another major live behavioral center

## Final Slab

The last remaining whole semantic slab is now DECRQSS state/query assembly.

That should move before any stop-marker, because it is still a coherent
terminal-facing protocol capability rather than just tiny mechanical residue.

## Stop Marker

That final slab is now landed.

The remaining `terminal_core_protocol.zig` surface is now mostly narrow helper
support, not one more meaningful semantic center.

This front should now stop unless a new explicit contradiction appears that is
larger than helper tidying.

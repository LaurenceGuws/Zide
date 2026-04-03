# VT OSC Stop Marker

Date: 2026-04-03

## Purpose

Record the honest stop-marker after both real OSC semantic slabs moved onto
core-side owners.

The question is:

- does OSC still contain one more whole semantic slab worth a dedicated war?

## What Changed

OSC now has two meaningful core-side semantic owners:

- [terminal_core_osc_metadata.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_osc_metadata.zig)
  - title semantics
  - cwd normalization/publication semantics
  - progress semantics
- [terminal_core_osc_semantic.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_osc_semantic.zig)
  - semantic prompt phase transitions and options
  - semantic command-line updates
  - user-var mutation semantics

Protocol-side OSC files are now much closer to:

- routing
- framing
- reply handling where needed

not:

- dense local semantic ownership

## Current Read

There is no new whole OSC semantic slab obvious enough to justify continuing
this war.

What remains in OSC is narrower and more mixed:

- routing in [osc.zig](/home/home/personal/zide/src/terminal/protocol/osc.zig)
- hyperlink handling in
  [osc_hyperlink.zig](/home/home/personal/zide/src/terminal/protocol/osc_hyperlink.zig)
- clipboard and kitty clipboard handling in
  [osc_clipboard.zig](/home/home/personal/zide/src/terminal/protocol/osc_clipboard.zig)
  and
  [osc_kitty_clipboard.zig](/home/home/personal/zide/src/terminal/protocol/osc_kitty_clipboard.zig)

Those do not currently read like one omitted core-side semantic slab in the
same class as the two moves already landed.

## Decision

OSC should stop here unless a fresh named semantic cluster appears.

The next VT pressure should go back to the broader `TerminalCore` protocol
execution maturity question from this stronger baseline.

## Bottom Line

The OSC semantic effects war is now close enough to done that continuing it by
momentum would likely be fake progress.

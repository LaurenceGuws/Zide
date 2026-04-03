# VT CSI Mode Effects Rerank

Date: 2026-04-03

## Purpose

Rerank the CSI mode-effects war after the first full terminal mode/effects
wave landed on both mutation and query paths.

The question is:

- does this war still contain one more whole terminal mode/effects slab?
- or has the remaining pressure changed category?

## What Improved

The first CSI wave is now coherent on both sides:

- [terminal_core_csi_modes.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_csi_modes.zig)
  owns the mutation-side terminal mode-and-screen-effects slab
- [terminal_core_csi_mode_query.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_csi_mode_query.zig)
  owns the corresponding DECRQM read-side terminal mode/query slab

That means the old story:

- “CSI mode mutation/query is one mixed protocol bag”

is materially weaker now.

## What Remains

The remaining `csi_mode_mutation.zig` and `csi_mode_query.zig` surface is no
longer primarily terminal screen-mode semantics.

It is now mostly:

- input protocol mode state
- input snapshot reads
- host-contract reporting flags
- sync-update state

Examples:

- app cursor keys / keypad
- mouse reporting modes
- focus reporting
- bracketed paste
- alternate scroll
- grapheme cluster shaping 2027
- color-scheme reporting 2031
- in-band resize notifications 2048
- kitty paste events 5522

## Current Judgment

This means the active war changed shape.

The remaining pocket is real, but it is no longer:

- terminal mode-and-screen effects

It is now:

- input/reporting contract state

So this exact war should not continue by momentum under the same framing.

## Decision

The CSI mode-effects war is close to a stop-marker.

If terminal continues immediately, the next war should be named more honestly
around:

- CSI input/reporting contract state

not:

- “one more CSI mode-effects slice”

## Bottom Line

The first CSI mode-effects wave paid off.

What remains is a different protocol contract category and should only reopen
under a new name.

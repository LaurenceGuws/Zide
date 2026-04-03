# VT CSI Input Reporting War

Date: 2026-04-03

## Purpose

Open the next VT maturity war from the post-CSI-mode-effects rerank.

The question is:

- what CSI-owned input/reporting contract still keeps protocol execution from
  feeling more terminal-centered after the terminal mode-and-screen-effects
  slab moved out?

## Decision

The next cluster is:

- CSI input/reporting contract state

Not:

- more CSI mode-effects cleanup
- more OSC work
- more reply-sink work

## Why This Wins

After the first CSI wave, the remaining `csi_mode_mutation.zig` and
`csi_mode_query.zig` surface is no longer mainly terminal mode-and-screen
semantics.

It is now mostly:

- input protocol mode state
- input snapshot/query state
- host-contract reporting flags
- sync-update state

Concrete examples:

- app cursor keys
- app keypad
- auto-repeat
- mouse reporting modes
- focus reporting
- bracketed paste
- alternate scroll
- grapheme cluster shaping 2027
- color-scheme reporting 2031
- in-band resize notifications 2048
- kitty paste events 5522

## Why This Is Better Than The Alternatives

### Better than continuing mode-effects

- the terminal mode/effects slab is already grouped on core-side owners
- continuing under that label would blur the architecture story

### Better than broad parser-owner extraction

- this is a named remaining protocol-execution contract
- it keeps the next move specific and reviewable

## Opening Question

The first question for this war is:

- which remaining CSI input/reporting state is true terminal protocol state,
  and which is explicit host/reporting contract that should stay outside core?

## Likely First Boundary

The strongest first split appears to be:

- input protocol modes and their DECRQM read-side contract

versus:

- host-reporting contract flags and runtime-dependent reporting behavior

That suggests the first likely win is not all remaining CSI state together.

It is:

- isolate the input protocol mode/query subset first

while keeping:

- color-scheme reporting
- in-band resize notifications
- kitty paste reporting

explicitly outside until they earn their own contract

## Bottom Line

If VT continues immediately, the next war is now explicit:

- CSI input/reporting contract state

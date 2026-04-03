# VT CSI Mode Effects War

Date: 2026-04-03

## Purpose

Open the next VT maturity war from the post-OSC rerank.

The question is:

- what CSI/ANSI mode-and-effects cluster now most clearly blocks
  `TerminalCore` from feeling like the unquestioned protocol-semantic center?

## Decision

The next cluster is:

- CSI / ANSI mode semantics and screen effects

Not:

- more OSC work
- more reply sink work
- vague parser-owner extraction

## Why This Wins

The remaining maturity pressure is no longer that CSI interaction state is
unclassified.

That groundwork is already landed.

The live problem now is that mode-setting execution still does not read like
one clearer terminal-semantic contract.

Concrete evidence:

- [csi_mode_mutation.zig](/home/home/personal/zide/src/terminal/protocol/csi_mode_mutation.zig)
  still mixes:
  - terminal screen modes
  - input mode semantics
  - alt-screen effects
  - host-contract flags
- [csi_mode_query.zig](/home/home/personal/zide/src/terminal/protocol/csi_mode_query.zig)
  still reflects the same neighborhood on the read side

## Why This Is Better Than The Alternatives

### Better than more OSC

- OSC now has both meaningful semantic slabs on core-side owners
- continuing there would likely be local tidying, not a new maturity win

### Better than more reply sink work

- reply-sink symmetry is not a real maturity goal
- CSI still has a bigger semantic ownership issue than reply emission

### Better than broad parser-owner work

- this gives parser-owner pressure one concrete cluster
- it avoids another vague “protocol discomfort” war

## Opening Question

The first question for this war is:

- which part of CSI mode execution is true terminal mode-and-effects semantics
  that should group behind a cleaner core-side contract, and which part should
  stay outside as host-contract/runtime behavior?

## Likely Opening Boundary

The strongest first boundary appears to be:

- terminal mode-and-screen effects

versus:

- host-contract flag mutation

That means the first likely code win is not “move all of CSI mode mutation.”

It is:

- carve out the terminal mode/effects slab cleanly enough that the remaining
  host-contract flags read as explicit outer contract, not mixed execution

## Bottom Line

The next VT war is now explicit:

- CSI / ANSI mode semantics and screen effects

First progress now landed:

- [terminal_core_csi_modes.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_csi_modes.zig)
  now owns the first real terminal mode-and-screen-effects slab
- [csi_mode_mutation.zig](/home/home/personal/zide/src/terminal/protocol/csi_mode_mutation.zig)
  now delegates that slab there instead of mixing it inline with input modes,
  host-contract flags, sync updates, and column-mode publishing

# VT Sprint Deeper Sufficiency Decision

Date: 2026-04-03

## Purpose

Make the next `vt-sprint` decision explicit after the local
`TerminalCore`-sufficiency cuts.

This is not another extraction queue.
It is the decision point for whether the sprint should escalate into a deeper
design step or stop cleanly.

## Fresh Comparison Read

Against the current references:

- Ghostty still feels cleaner because the engine object itself reads like the
  unmistakable terminal center
- WezTerm still feels mature because the runtime shell is obviously secondary
  to the terminal object

Against current Zide:

- [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  now owns significantly more immutable and semantic host truth
- [TerminalRuntimeShell](/home/home/personal/zide/src/terminal/core/session/terminal_runtime_shell.zig)
  is now visibly narrow and honest
- the old false public objects are gone

So the remaining difference is no longer:

- obvious fake center
- obvious wrapper residue
- obvious query/helper lie

It is now subtler:

- does `TerminalCore` feel sufficiently complete on its own
- or does it still feel like the engine one layer below the "real usable thing"

## Current Judgment

There is no fresh small-cut contradiction obvious enough to justify continuing
the sprint by momentum.

The remaining gap is now design-level:

1. either `TerminalCore` needs one more deliberate capability step so hosts can
   treat it as the clearly sufficient VT center
2. or the current `TerminalCore` + `TerminalRuntimeShell` split is already
   honest enough and the sprint should stop here

## What This Means

The next honest move is not another helper extraction.

It is one of:

1. open a deliberate deeper `TerminalCore` sufficiency design review
2. close `vt-sprint` cleanly

## Decision Lean

Current lean: close the implementation sprint unless a specific missing
`TerminalCore` capability slab can be named first.

Why:

- the shell no longer looks dishonest
- the local easy contradictions are already gone
- continuing without a named missing capability would likely become speculative
  churn

## The Only Good Reason To Continue

Continue only if the next step can be stated as:

- "`TerminalCore` is still missing this specific host-facing engine capability
  that the references make feel obviously engine-owned"

If that statement is not available, the honest move is to stop.

## Bottom Line

`vt-sprint` has reached the point where the next improvement must be justified
as a real design step, not as another cleanup win.

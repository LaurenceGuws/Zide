# VT Sprint Stop Marker

Date: 2026-04-03

## Purpose

Record the honest stop-marker after the recent VT waves:

- input semantics
- public resize
- viewport/selection mutation surface

The question is no longer:

- is there another obvious local contradiction we should cut right now?

It is now:

- is there one named deeper `TerminalCore` capability or object-sufficiency
  design step that justifies reopening code?

## Current Read

From the current live baseline:

- old fake centers are gone
- `TerminalSession` is gone
- `PtyTerminalRuntime` is gone
- `TerminalRuntimeShell` is narrow and honest
- input semantics have real terminal-owned slices now
- public resize has a unified host-facing contract now
- dead session mutation facades are gone

That is enough progress that the remaining gap has changed class.

## What The Remaining Gap Looks Like Now

The remaining difference versus Ghostty and WezTerm does not look like one more
misplaced helper slab.

It looks more like:

- overall library-object feel
- object sufficiency
- terminal-center maturity

That is a real gap.
But it is not the kind of gap that should be attacked with another vague local
extraction.

## What We Explicitly Did Not Find

This pass did not expose another crisp next move of the same quality as:

- moving semantic input decisions onto core
- unifying public resize
- deleting session mutation facades

The likely suspects were checked again:

- input: remaining surface is mostly writer/reporting-shaped
- resize: materially healthier now
- viewport/selection: now mostly honest mutation-plus-refresh owners
- `host_queries`: still mostly honest mixed runtime aggregation

So continuing by momentum would likely become architecture theater.

## Decision

The VT sprint should now stop cleanly from this baseline.

Continue only if a future pass can name one specific deeper
`TerminalCore` capability or object-model gap.

Not:

- "make core feel more sufficient"
- "shrink the shell more"
- "do one more cleanup wave"

But:

- one named capability
- one named contract weakness
- or one named object-model redesign question

## Bottom Line

`zide-vt` is materially closer to a serious standalone library shape.

It is still not near plug-and-play parity with `libghostty-vt`.

But the remaining gap is now design quality, not another obvious extraction
lane.

That means the honest move is:

- stop the sprint here
- keep this baseline
- reopen only when the next deeper question is named precisely

# VT OSC Semantic Effects War

Date: 2026-04-03

## Purpose

Open the next VT maturity war from the post-reply-sink rerank.

The question is:

- what semantic protocol cluster now gives the strongest next improvement to
  `TerminalCore` maturity?

## Decision

The next cluster is:

- OSC semantic effects

Not:

- reply sinks continued
- broad CSI cleanup
- generic parser discomfort

## Why OSC Wins Next

OSC semantic handling now looks like the strongest remaining protocol cluster
that is already mostly terminal-semantic in substance but not yet obviously
organized around one cleaner core-side contract.

Concrete files:

- [osc_title.zig](/home/home/personal/zide/src/terminal/protocol/osc_title.zig)
- [osc_cwd.zig](/home/home/personal/zide/src/terminal/protocol/osc_cwd.zig)
- [osc_progress.zig](/home/home/personal/zide/src/terminal/protocol/osc_progress.zig)
- [osc_semantic.zig](/home/home/personal/zide/src/terminal/protocol/osc_semantic.zig)
- [osc.zig](/home/home/personal/zide/src/terminal/protocol/osc.zig)

## Why This Is Better Than The Alternatives

### Better than more sink work

- the sink lane already paid off
- OSC semantic effects are about terminal meaning, not reply emission

### Better than CSI writer-driven work

- CSI now needs a second contract shape if it continues
- OSC semantic effects already look more like a terminal-semantic cluster

### Better than vague parser-owner work

- this is one explicit protocol family with concrete owners
- it gives the next war a real boundary instead of broad parser unease

## Current Smell

OSC semantic handlers already mutate terminal meaning, but they do so as a set
of protocol-local helpers rather than through one more obviously core-side
semantic contract.

Examples:

- title buffer mutation and publish in
  [osc_title.zig](/home/home/personal/zide/src/terminal/protocol/osc_title.zig)
- cwd normalization flow in
  [osc_cwd.zig](/home/home/personal/zide/src/terminal/protocol/osc_cwd.zig)
- progress state mutation in
  [osc_progress.zig](/home/home/personal/zide/src/terminal/protocol/osc_progress.zig)
- semantic prompt and user-var mutation in
  [osc_semantic.zig](/home/home/personal/zide/src/terminal/protocol/osc_semantic.zig)

That means the next maturity gain is likely:

- one clearer OSC semantic contract beside or on core

not:

- more shell/runtime surgery

## Opening Question

The first question for this war is:

- which OSC semantic effects are already core-owned in substance and should be
  grouped behind a more explicit core-side protocol contract?

Progress now landed:

- the first OSC semantic slab is now grouped under one core-side owner:
  [terminal_core_osc_metadata.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_osc_metadata.zig)
- that owner now carries:
  - title semantics
  - cwd normalization/publication semantics
  - progress semantics
- protocol files now delegate to that owner instead of carrying the semantic
  mutation logic inline:
  - [osc_title.zig](/home/home/personal/zide/src/terminal/protocol/osc_title.zig)
  - [osc_progress.zig](/home/home/personal/zide/src/terminal/protocol/osc_progress.zig)
  - [osc_util.zig](/home/home/personal/zide/src/terminal/protocol/osc_util.zig)
- the second OSC semantic slab is now grouped under one core-side owner:
  [terminal_core_osc_semantic.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_osc_semantic.zig)
- that owner now carries:
  - semantic prompt phase transitions and options
  - semantic command-line updates
  - user-var mutation semantics
- [osc_semantic.zig](/home/home/personal/zide/src/terminal/protocol/osc_semantic.zig)
  now delegates there instead of carrying the mutation logic inline

## Bottom Line

The next VT war is now:

- OSC semantic effects war

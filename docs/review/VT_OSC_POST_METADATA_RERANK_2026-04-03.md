# VT OSC Post-Metadata Rerank

Date: 2026-04-03

## Purpose

Rerank the OSC semantic effects war after the metadata/activity slab moved onto
core.

The question is:

- does OSC stop here
- or is there one more real semantic slab worth taking whole?

## What Improved

The first OSC slab materially changed the shape of the cluster.

Now grouped under one core-side owner:

- [terminal_core_osc_metadata.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_osc_metadata.zig)

That owner now carries:

- title semantics
- cwd normalization/publication semantics
- progress semantics

That means the old “OSC semantics are just scattered protocol helpers” story is
weaker now.

## Remaining Candidates

### 1. Semantic prompt / user vars

This is now the strongest remaining OSC slab.

File:

- [osc_semantic.zig](/home/home/personal/zide/src/terminal/protocol/osc_semantic.zig)

Why it wins:

- it is still clearly semantic
- it still directly mutates core-owned prompt/user-var state
- it remains a dense local cluster that still reads like protocol-local
  choreography rather than one clearer core-side semantic contract

### 2. Stop OSC here

This is plausible, but second.

Why:

- the first slab was already meaningful
- but there is still one obvious whole semantic cluster left

### 3. Broaden back to routing or generic parser pressure

This does not win.

Why:

- the remaining pressure is narrower and more concrete than that

## Current Judgment

That second slab is now landed too:

- [terminal_core_osc_semantic.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_osc_semantic.zig)
  now owns:
  - semantic prompt phase transitions and options
  - semantic command-line updates
  - user-var mutation semantics
- [osc_semantic.zig](/home/home/personal/zide/src/terminal/protocol/osc_semantic.zig)
  now delegates there instead of carrying the mutation logic inline

OSC now reads much more like:

- protocol routing and framing in `src/terminal/protocol/`
- semantic ownership in core-side protocol owners

That means the OSC war is close to a stop-marker unless one fresh, whole
semantic slab appears.

## Bottom Line

The ranked second slab is no longer pending:

- semantic prompt / user-vars is landed

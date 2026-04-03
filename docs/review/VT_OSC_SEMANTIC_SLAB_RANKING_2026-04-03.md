# VT OSC Semantic Slab Ranking

Date: 2026-04-03

## Purpose

Rank the first real code slab inside the OSC semantic effects war.

The question is not:

- which OSC helper file is easiest to move?

It is:

- which semantic OSC cluster is already core-owned in substance and most
  likely to benefit from one clearer core-side protocol contract?

## Ranked Slabs

### 1. Title / CWD / Progress

This is the best opening slab.

Files:

- [osc_title.zig](/home/home/personal/zide/src/terminal/protocol/osc_title.zig)
- [osc_cwd.zig](/home/home/personal/zide/src/terminal/protocol/osc_cwd.zig)
- [osc_progress.zig](/home/home/personal/zide/src/terminal/protocol/osc_progress.zig)
- [osc_util.zig](/home/home/personal/zide/src/terminal/protocol/osc_util.zig)

Why it wins:

- these effects already mutate core-owned terminal/session meaning directly
- they do not depend on writer mechanics
- they read like one coherent metadata/activity slab:
  - title
  - cwd
  - progress
- this is the cleanest chance to make OSC handling feel more like a
  core-side semantic contract instead of a set of protocol-local helpers

### 2. Semantic prompt / user vars

This is second.

File:

- [osc_semantic.zig](/home/home/personal/zide/src/terminal/protocol/osc_semantic.zig)

Why it is second:

- it is clearly semantic
- but it is a denser cluster with more local state choreography and options
- it should benefit from the first slab making the contract shape clearer

### 3. Keep broad `osc.zig` routing as the war

This does not win.

Why:

- routing is not the real maturity issue
- the issue is the semantic contract behind the routed handlers

## Chosen Opening Direction

The first OSC semantic contract should target:

- title / cwd / progress

The likely shape is one explicit core-side OSC metadata/activity semantic
owner, not three isolated moves.

That first slice is now landed:

- [terminal_core_osc_metadata.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_osc_metadata.zig)
  is the new core-side semantic owner
- [osc_title.zig](/home/home/personal/zide/src/terminal/protocol/osc_title.zig),
  [osc_progress.zig](/home/home/personal/zide/src/terminal/protocol/osc_progress.zig),
  and [osc_util.zig](/home/home/personal/zide/src/terminal/protocol/osc_util.zig)
  now delegate semantic mutation there

## Bottom Line

The first code battlefield inside the OSC war is now explicit:

- title / cwd / progress semantic ownership

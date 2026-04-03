# VT Post Sync Publication Rerank

Date: 2026-04-04

## Purpose

Rerank the remaining execution faces after the first synchronized-update
publication contract slice.

## Current Judgment

Publication still wins.

The synchronized-update publication contract was a real slice, but it did not
eliminate publication as the strongest fully surviving execution face.

## Why Publication Still Wins

The active protocol path still reaches the broader publication stack through:

- [view_cache.zig](/home/home/personal/zide/src/terminal/core/publication/view_cache.zig)
- [view_cache_publication.zig](/home/home/personal/zide/src/terminal/core/publication/view_cache_publication.zig)
- [publication_flow.zig](/home/home/personal/zide/src/terminal/core/publication/publication_flow.zig)
- [publication_state.zig](/home/home/personal/zide/src/terminal/core/publication/publication_state.zig)

So publication is not just surviving as a few fields.

It is still surviving as a broader helper contract the active execution path
depends on.

## Why Runtime Is Second

Runtime is still not done, but it is now weaker than publication:

- one explicit write/wake runtime face exists on
  [protocol_execution.zig](/home/home/personal/zide/src/terminal/core/session/protocol_execution.zig)
- what remains is mostly compatibility `session.runtime` reach for active
  helpers, not one equally broad unnamed runtime choreography center

That is a real improvement compared to publication, which still survives
through a broader helper stack.

## Decision

The next exact parser-feed move should stay on publication.

Not:

- generic execution-object shrinking
- runtime compatibility cleanup by momentum

But:

- the next coherent publication contract after synchronized updates

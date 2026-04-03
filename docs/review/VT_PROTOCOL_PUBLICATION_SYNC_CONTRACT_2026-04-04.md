# VT Protocol Publication Sync Contract

Date: 2026-04-04

## Purpose

Name the exact publication contract the active protocol path still needs,
instead of treating "publication" as one undifferentiated surviving execution
face.

## Current Judgment

The active protocol path does not need generic publication ownership.

It needs one narrow publication contract centered on synchronized-update
publication behavior.

The live pressure is concentrated in:

- [sync_updates.zig](/home/home/personal/zide/src/terminal/core/protocol/sync_updates.zig)
- [publication_flow.zig](/home/home/personal/zide/src/terminal/core/publication/publication_flow.zig)
- [view_cache.zig](/home/home/personal/zide/src/terminal/core/publication/view_cache.zig)
- [view_cache_publication.zig](/home/home/personal/zide/src/terminal/core/publication/view_cache_publication.zig)

## Exact Needed Behavior

`sync_updates` currently needs only:

1. observe active render-cache generation/dirty state
2. compare against presented generation
3. bump pending generation when required
4. publish one view-cache update for the current scroll offset

That is much smaller than the full publication slab still visible through
`self.session.publication`.

## Why Earlier Shrink Failed

A direct field-face shrink failed because the active protocol path still calls
generic publication helpers that assume the broader publication slab.

So the next honest move is not:

- "replace publication pointer with fewer fields"

The next honest move is:

- define one sync-update publication contract
- make `sync_updates.zig` consume that contract directly
- only then judge whether the broader publication face can shrink

## Required Bar

The next code move must:

- reduce publication dependence by contract, not by struct cosmetics
- keep view-cache/update-generation behavior explicit
- avoid dragging unrelated publication features into the protocol execution
  surface just because they already live nearby

## Decision

The next default parser-feed publication move is a synchronized-update
publication contract cut.

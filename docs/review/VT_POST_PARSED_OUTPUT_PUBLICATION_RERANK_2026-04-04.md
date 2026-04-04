# VT Post Parsed Output Publication Rerank

Date: 2026-04-04

## Purpose

Rerank the surviving execution faces after the parsed-output publication
contract wave tightened one more time.

## Current Judgment

Publication still wins, but its remaining shape is narrower again.

The active contradiction is no longer broad parsed-output publication.

It is now closer to pending view-refresh / poll publication cadence.

## Why Publication Still Wins

The active runtime/output path still depends on broader publication helpers for:

- pending view-refresh requests
- poll-time publish/update choreography
- render-cache refresh application outside the two already-isolated contracts

The visible pressure is now concentrated more in:

- [publication_flow.zig](/home/home/personal/zide/src/terminal/core/publication/publication_flow.zig)
- [pty_poll_publication.zig](/home/home/personal/zide/src/terminal/core/runtime/pty_poll_publication.zig)
- [io_threads.zig](/home/home/personal/zide/src/terminal/core/runtime/io_threads.zig)

than in the earlier parsed-output feed result paths.

## Why Runtime Is Still Second

Runtime still survives, but now mainly as:

- compatibility `session.runtime` reach for active helpers
- transport/read-thread/IO-buffer ownership

That is still less architecturally broad than the remaining publication helper
story the active output path uses.

## Decision

The next exact parser-feed publication move, if VT stays on this front, should
name one pending-refresh / poll publication contract.

Not:

- more parsed-output symmetry cleanup
- runtime compatibility cleanup by momentum

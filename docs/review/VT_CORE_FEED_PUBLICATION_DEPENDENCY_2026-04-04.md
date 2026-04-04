# VT Core Feed Publication Dependency

Date: 2026-04-04

## Purpose

Name the strongest surviving dependency inside the feed-execution front.

## Current Judgment

Publication/update reach is still the strongest surviving feed dependency.

Why:

- [protocol_execution.zig](/home/home/personal/zide/src/terminal/core/session/protocol_execution.zig)
  still carries the largest active surface around:
  - render-cache reads
  - presented-generation reads
  - pending-generation mutation
  - view-cache updates
  - output-pending mutation
  - pending-refresh request handling
- the runtime face is already narrowed to write/wake mechanics
- the lock face is already narrowed to the mutex
- the protocol-state face is named and narrower than before

## Exact Pressure

The active publication-heavy methods are:

- `currentRenderCache(...)`
- `presentedGeneration(...)`
- `bumpPublicationGeneration(...)`
- `pendingPublicationGeneration(...)`
- `updateViewCacheForProtocol(...)`
- `markOutputPending(...)`
- `viewRefreshPending(...)`
- `takePendingViewRefreshRequest(...)`
- `publishViewRefreshRequest(...)`
- `publishPollUpdate(...)`

That does not mean they are all wrong.

It means publication/update behavior is still the largest reason
`feedOutputBytesLocked(...)` depends on a composite outer execution receiver.

## Decision

The next feed-execution slice should pressure publication/update reach first,
not runtime or locking.

The bar stays the same:

- do not just rename the execution surface
- do not reopen broad publication cleanup
- name one coherent publication/update contract inside feed execution first

## Post-Cadence Rerank

Publication/update reach still wins, but it is materially narrower now.

Why:

- parsed-output publication is now grouped as one explicit contract
- pending-refresh request handling is now grouped as one explicit cadence
  contract
- runtime, locking, and protocol state still do not overtake publication in
  active feed pressure

Current strongest remainder:

- poll-time publish-or-refresh behavior in:
  - [protocol_execution.zig](/home/home/personal/zide/src/terminal/core/session/protocol_execution.zig)
  - [pty_poll_publication.zig](/home/home/personal/zide/src/terminal/core/runtime/pty_poll_publication.zig)

Current judgment:

- publication still narrowly beats the other feed faces
- the next slice, if this front continues, is poll-time publish-or-refresh
  behavior

# VT Core Feed Poll Contract

Date: 2026-04-04

## Purpose

Name the second coherent publication/update contract inside the feed-execution
 front.

## Current Judgment

Pending-refresh / poll cadence is now the strongest remaining feed-publication
cluster.

This cluster covers:

- pending-refresh request presence
- pending-refresh request acquisition
- pending-refresh request publication
- poll-time publish-or-refresh decision

## Why It Wins Now

The first parsed-output publication slice is already landed.

What remains most clearly is:

- [protocol_execution.zig](/home/home/personal/zide/src/terminal/core/session/protocol_execution.zig)
  - `viewRefreshPending(...)`
  - `takePendingViewRefreshRequest(...)`
  - `publishViewRefreshRequest(...)`
  - `publishPollUpdate(...)`
- [pty_poll_publication.zig](/home/home/personal/zide/src/terminal/core/runtime/pty_poll_publication.zig)
  still drives the publish-or-refresh cadence through that surface
- [io_threads.zig](/home/home/personal/zide/src/terminal/core/runtime/io_threads.zig)
  still mixes pending-refresh decisions with parse-thread publish cadence

That is now the strongest surviving feed-publication dependency in substance.

## Decision

The next feed-publication slice should target pending-refresh / poll cadence.

The bar:

- keep it coherent as one cadence contract
- do not widen it into generic runtime-thread cleanup
- rerank immediately after, because publication may stop winning after this

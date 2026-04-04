# VT Protocol Publication Poll Contract

Date: 2026-04-04

## Purpose

Name and cut the next coherent publication contract after synchronized updates
and parsed-output publication.

## Current Judgment

The next surviving publication-helper story was pending-refresh / poll
publication cadence.

The active runtime output path still needed one shared behavior for:

1. checking whether view-refresh publication is pending
2. taking one pending refresh request
3. publishing the pending refresh request
4. publishing one poll-time current view update when data arrived

That was still broader than a single helper call and still visible in both
parse-thread and poll-time runtime paths.

## Live Pressure

Before this slice, the live pressure was concentrated in:

- [pty_poll_publication.zig](/home/home/personal/zide/src/terminal/core/runtime/pty_poll_publication.zig)
- [io_threads.zig](/home/home/personal/zide/src/terminal/core/runtime/io_threads.zig)
- [publication_flow.zig](/home/home/personal/zide/src/terminal/core/publication/publication_flow.zig)

## Progress

That pending-refresh / poll publication cadence is now explicit on
[protocol_execution.zig](/home/home/personal/zide/src/terminal/core/session/protocol_execution.zig):

- `viewRefreshPending(...)`
- `takePendingViewRefreshRequest(...)`
- `publishViewRefreshRequest(...)`
- `publishPollUpdate(...)`

Those operations now drive:

- [pty_poll_publication.zig](/home/home/personal/zide/src/terminal/core/runtime/pty_poll_publication.zig)
- [io_threads.zig](/home/home/personal/zide/src/terminal/core/runtime/io_threads.zig)

Current read after this slice:

- publication still may survive as an execution face
- but three coherent publication contracts are now explicit on the execution
  surface:
  - synchronized updates
  - parsed-output publication
  - pending-refresh / poll publication cadence
- the next rerank should decide whether publication still truly beats runtime
  after those three cuts

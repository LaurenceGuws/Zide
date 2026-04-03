# VT Protocol Publication Parsed Output Contract

Date: 2026-04-04

## Purpose

Name the next coherent publication contract after synchronized updates inside
the parser-feed execution surface.

## Current Judgment

The next active publication dependence is parsed-output publication.

The live protocol/runtime output paths still need one shared behavior:

1. treat a successful feed result as parsed terminal output
2. advance pending publication generation
3. publish the current scroll-offset view-cache state
4. mark output pending when the parse-thread publication path needs it

That is a real publication contract.

It is smaller than the full publication slab, but larger than one sync-update
special case.

## Live Pressure

Before this slice, parsed-output publication was still split across:

- [terminal_core_feed.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_feed.zig)
- [pty_poll_processing.zig](/home/home/personal/zide/src/terminal/core/runtime/pty_poll_processing.zig)
- [io_threads.zig](/home/home/personal/zide/src/terminal/core/runtime/io_threads.zig)
- [publication_flow.zig](/home/home/personal/zide/src/terminal/core/publication/publication_flow.zig)

Those paths were all still depending on publication choreography directly after
feed/apply.

## Required Bar

The next code move must:

- move parsed-output publication behind the execution contract
- keep generation/view-cache/output-pending behavior explicit
- avoid pretending this means generic publication is solved

## Progress

The parsed-output publication contract is now explicit on
[protocol_execution.zig](/home/home/personal/zide/src/terminal/core/session/protocol_execution.zig):

- `noteParsedOutput(...)`
- `consumeFeedResult(...)`
- `publishPendingOutput(...)`
- `markOutputPending(...)`

That contract now drives the active parsed-output paths across:

- [terminal_core_feed.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_feed.zig)
- [pty_poll_processing.zig](/home/home/personal/zide/src/terminal/core/runtime/pty_poll_processing.zig)
- [io_threads.zig](/home/home/personal/zide/src/terminal/core/runtime/io_threads.zig)

Current read after this slice:

- publication still survives inside the execution surface
- but parsed-output publication no longer depends on direct
  `publication_flow` choreography across multiple runtime/feed paths
- the next rerank should judge publication again from this narrower baseline,
  not from the older sync-update-only one

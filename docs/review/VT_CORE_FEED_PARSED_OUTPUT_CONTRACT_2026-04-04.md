# VT Core Feed Parsed Output Contract

Date: 2026-04-04

## Purpose

Split the surviving feed publication dependency into coherent contracts before
more code.

## Current Judgment

The first coherent feed-publication contract is parsed-output publication.

This cluster covers:

- publication generation bump for parsed output
- view-cache update for the current scroll offset after parse
- output-pending marking for parse-thread / no-parse-thread paths

## Why This Slice Wins First

It beats pending-refresh / poll cadence as the first slice because:

- it is directly attached to `feedOutputBytesLocked(...)`
- it appears in the active feed paths:
  - [terminal_core_feed.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_feed.zig)
  - [pty_poll_processing.zig](/home/home/personal/zide/src/terminal/core/runtime/pty_poll_processing.zig)
  - [io_threads.zig](/home/home/personal/zide/src/terminal/core/runtime/io_threads.zig)
- it is the most feed-local part of the surviving publication face

The poll/refresh cluster is real too, but it is more cadence-shaped and less
directly tied to the semantic feed operation itself.

## Decision

The next feed-execution code slice should target parsed-output publication
first.

The bar:

- keep pending-refresh / poll cadence out of the first slice
- make parsed-output publication read more like one explicit contract
- do not widen this into generic publication cleanup

# VT Post Protocol Interaction Rerank

Date: 2026-04-03

## Purpose

Rerank VT maturity after the protocol interaction contract wave.

This is not a generic repo rerank.
It is a VT-specific honesty check after:

- protocol mode state split
- host contract state split
- derived snapshot split
- explicit CSI reply/report snapshotting

## What Improved

The protocol interaction war materially changed the baseline.

Before this wave, the active discomfort was:

- one mixed `session.interaction` bag
- one broad CSI ownership problem

That is no longer the right first-glance read.

What is now explicit in live code:

- [interaction_fields.zig](/home/home/personal/zide/src/terminal/core/session/interaction_fields.zig)
  no longer teaches one interaction blob
- [csi_mode_mutation.zig](/home/home/personal/zide/src/terminal/protocol/csi_mode_mutation.zig)
  and [csi_mode_query.zig](/home/home/personal/zide/src/terminal/protocol/csi_mode_query.zig)
  now read much more like protocol state plus adjacent host contract state
- [csi_reply.zig](/home/home/personal/zide/src/terminal/protocol/csi_reply.zig)
  now owns explicit reply input packaging

## What No Longer Wins As The Next War

### 1. Broad CSI cleanup

This no longer wins.

Reason:

- the broad mixed-state lie is materially flattened
- another local CSI extraction now looks more like tidying than maturity gain

### 2. More interaction bag splitting

This no longer wins either.

Reason:

- the major categories are already explicit:
  - protocol modes
  - host contract
  - derived snapshot

## What Rises Again

### 1. Deeper parser-owner / `TerminalCore` sufficiency

This is back on top.

Reason:

- now that CSI-local state is cleaner, the remaining blocker is more clearly
  whether parser/protocol execution can become more terminal-centered without
  pulling writer/reporting mechanics into core
- the next live pressure is not “which field is mixed”
- it is “what protocol execution contract still prevents
  [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  from feeling more sufficient”

### 2. Narrow reporting pockets

This is second.

Reason:

- there may still be one small reporting-adjacent pocket worth cleaning
- but that is no longer strong enough to drive the main war by default

## Current Judgment

The protocol interaction wave should not continue by momentum.

The next honest VT move is:

1. reopen the deeper parser-owner / `TerminalCore` sufficiency question
2. only fall back to a narrow reporting pocket if that parser-owner question
   still cannot name a concrete contract

## Bottom Line

The protocol interaction war paid off.

It should now hand back to the deeper maturity question:

- what still prevents parser/protocol execution from reading as a more
  terminal-centered contract around `TerminalCore`?

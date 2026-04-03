# VT Core Parser Feed Front

Date: 2026-04-03

## Purpose

Open the next exact core owner-dependency front after the first scrolling win.

## Current Judgment

Parser feed is now the strongest remaining owner-shaped completion path.

The live contradiction is:

- `TerminalCore.feedOutputBytesLocked(self, owner, bytes)` still requires
  outer owner shape to execute parser/protocol semantics
- parser dispatch then terminates on a broad session-shaped surface rather
  than a narrower core-centered execution contract

## Why This Beats Other Candidates

It beats:

- reopening scrolling immediately
- reopening host normalization immediately
- more local protocol tidying

Because parser feed is closer to the center of "this is the terminal" than the
remaining honest outer scrolling consumer.

## Exact Line

The pressure is visible across:

- [terminal_core.zig](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
- [parser.zig](/home/home/personal/zide/src/terminal/parser/parser.zig)
- [parser_dispatch.zig](/home/home/personal/zide/src/terminal/core/protocol/parser_dispatch.zig)

The current shape still says:

- core owns feed as a method
- but owner-shaped session context is still what makes feed execution complete

## Required Bar

The next move must not be:

- just renaming `owner` to something nicer
- forcing parser execution into core while dragging writer/reporting/runtime
  mechanics with it

The next move must be:

- one explicit narrower execution contract between core feed and parser
  semantics

## Decision

The next default VT front is parser feed owner dependency.

## Progress

The blocking contract is now explicit.

Parser/protocol execution still depends on one broad receiver for:

- terminal semantics
- protocol mode / host-contract state
- reply/report/runtime hooks

That means the next code move is not "parser into core."

It is:

- define one narrower execution surface first

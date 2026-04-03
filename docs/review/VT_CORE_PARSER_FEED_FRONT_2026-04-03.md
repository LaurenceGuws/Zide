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

The first real slice is now landed:

- parser/protocol reply/report hooks no longer reach an implicit
  shell-shaped surface by default
- new explicit owner:
  [protocol_runtime.zig](/home/home/personal/zide/src/terminal/core/session/protocol_runtime.zig)
- protocol reply emission and reporting-side runtime reads now flow through
  that owner across:
  - [csi.zig](/home/home/personal/zide/src/terminal/protocol/csi.zig)
  - [csi_mode_mutation.zig](/home/home/personal/zide/src/terminal/protocol/csi_mode_mutation.zig)
  - [csi_mode_query.zig](/home/home/personal/zide/src/terminal/protocol/csi_mode_query.zig)
  - [csi_style_reset.zig](/home/home/personal/zide/src/terminal/protocol/csi_style_reset.zig)
  - [csi_reply.zig](/home/home/personal/zide/src/terminal/protocol/csi_reply.zig)
  - [dcs_apc.zig](/home/home/personal/zide/src/terminal/protocol/dcs_apc.zig)
  - [osc_clipboard.zig](/home/home/personal/zide/src/terminal/protocol/osc_clipboard.zig)
  - [osc_kitty_clipboard.zig](/home/home/personal/zide/src/terminal/protocol/osc_kitty_clipboard.zig)
  - [palette.zig](/home/home/personal/zide/src/terminal/protocol/palette.zig)

This does not finish parser-feed ownership.

It does remove one real lie:

- protocol code no longer depends on "whatever the shell happens to expose"
  for reply/report behavior

The second real slice is now landed too:

- parser/protocol state reads and the remaining grapheme-mode state mutation
  no longer reach raw `session.interaction` from the active protocol surface
- new explicit owner:
  [protocol_state.zig](/home/home/personal/zide/src/terminal/core/session/protocol_state.zig)
- active protocol/core files now consume that owner through:
  - [terminal_core_csi_input_modes.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_csi_input_modes.zig)
  - [csi_mode_query.zig](/home/home/personal/zide/src/terminal/protocol/csi_mode_query.zig)
  - [terminal_core_reset.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_reset.zig)

That means the active parser/protocol surface now has explicit faces for:

- reply/report runtime hooks
- protocol state reads and the remaining grapheme-mode mutation/reset path

The next direct feed-side cut is now landed too:

- [TerminalCore.feedOutputBytesLocked(...)](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  no longer feeds the parser the shell-shaped owner directly
- new feed receiver:
  [protocol_execution.zig](/home/home/personal/zide/src/terminal/core/session/protocol_execution.zig)
- parser execution now runs through:
  - `allocator`
  - `core`
  - protocol-relevant runtime/publication/control/interaction faces

This is the first slice that directly changes the feed receiver itself rather
than only flattening the helpers around it.

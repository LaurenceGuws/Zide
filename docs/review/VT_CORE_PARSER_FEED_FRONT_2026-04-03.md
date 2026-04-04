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

The next execution-surface slice is now landed too:

- [sync_updates.zig](/home/home/personal/zide/src/terminal/core/protocol/sync_updates.zig)
  no longer reaches raw publication fields directly
- [protocol_execution.zig](/home/home/personal/zide/src/terminal/core/session/protocol_execution.zig)
  now exposes explicit publication methods for the protocol path:
  - current render cache
  - presented generation
  - pending-generation bump/read
  - protocol-scoped view-cache update

This does not prove publication is irreducible.

It does make the remaining publication dependence explicit at the execution
surface instead of hiding it as direct protocol-field reach.

The first hostile rerank inside the execution surface is now explicit too:

- `interaction` stays for now because the active protocol/helper path still
  genuinely depends on input and kitty-related state there
- `control` no longer survives as a whole face
- [protocol_execution.zig](/home/home/personal/zide/src/terminal/core/session/protocol_execution.zig)
  now carries only a direct `state_mutex` pointer for locking

That is a real reduction:

- the execution surface no longer pretends the whole control slab is part of
  the protocol contract

The next surviving-face cut is now landed:

- runtime is no longer treated as one undifferentiated execution slab
- [protocol_execution.zig](/home/home/personal/zide/src/terminal/core/session/protocol_execution.zig)
  now carries an explicit runtime write/wake face for:
  - PTY write access
  - external transport write access
  - writer mutex
  - IO wake signaling

That does not fully remove `session.runtime` from the execution object yet,
because active protocol/helpers still assume that compatibility shape.

It does make the runtime contradiction narrower and more explicit.

The next publication pressure pass is now decided too:

- a direct attempt to reduce publication to only a smaller field face did not
  survive the active protocol/publication call graph cleanly
- the generic publication stack still expects the broader publication slab in
  code paths that the protocol execution surface actually touches

That means the current publication judgment is stronger, not weaker:

- publication is still the strongest fully surviving execution face
- the next honest publication move must cut a coherent publication contract,
  not just swap the struct field for a smaller bundle

That publication contract is now named explicitly:

- [VT_PROTOCOL_PUBLICATION_SYNC_CONTRACT_2026-04-04.md](/home/home/personal/zide/docs/review/VT_PROTOCOL_PUBLICATION_SYNC_CONTRACT_2026-04-04.md)
- current target:
  - synchronized-update publication behavior
  - not broad publication slimming

That contract now has its first real code slice too:

- [sync_updates.zig](/home/home/personal/zide/src/terminal/core/protocol/sync_updates.zig)
  now consumes explicit synchronized-update publication operations on
  [protocol_execution.zig](/home/home/personal/zide/src/terminal/core/session/protocol_execution.zig)

The post-sync rerank is now explicit too:

- [VT_POST_SYNC_PUBLICATION_RERANK_2026-04-04.md](/home/home/personal/zide/docs/review/VT_POST_SYNC_PUBLICATION_RERANK_2026-04-04.md)
- publication still wins as the strongest fully surviving execution face

The next coherent publication contract is now landed too:

- [VT_PROTOCOL_PUBLICATION_PARSED_OUTPUT_CONTRACT_2026-04-04.md](/home/home/personal/zide/docs/review/VT_PROTOCOL_PUBLICATION_PARSED_OUTPUT_CONTRACT_2026-04-04.md)
- parsed-output publication now lives on
  [protocol_execution.zig](/home/home/personal/zide/src/terminal/core/session/protocol_execution.zig)
  instead of being finished through direct
  [publication_flow.zig](/home/home/personal/zide/src/terminal/core/publication/publication_flow.zig)
  choreography across:
  - [terminal_core_feed.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_feed.zig)
  - [pty_poll_processing.zig](/home/home/personal/zide/src/terminal/core/runtime/pty_poll_processing.zig)
  - [io_threads.zig](/home/home/personal/zide/src/terminal/core/runtime/io_threads.zig)

Current read:

- publication is still a surviving execution face
- but the active feed/output publication path is now materially narrower than
  the old sync-update-only baseline

The parsed-output publication wave then tightened once more:

- [io_threads.zig](/home/home/personal/zide/src/terminal/core/runtime/io_threads.zig)
  no longer uses direct
  [publication_flow.publishPendingOutputLocked(...)](/home/home/personal/zide/src/terminal/core/publication/publication_flow.zig)
  for the idle publish path
- [pty_poll_publication.zig](/home/home/personal/zide/src/terminal/core/runtime/pty_poll_publication.zig)
  no longer uses direct
  [publication_flow.markOutputPending(...)](/home/home/personal/zide/src/terminal/core/publication/publication_flow.zig)
  when unread buffered IO remains

That means the next surviving publication pressure is narrower again:

- no longer broad parsed-output publication
- now closer to pending-refresh / poll publication cadence

See:

- [VT_POST_PARSED_OUTPUT_PUBLICATION_RERANK_2026-04-04.md](/home/home/personal/zide/docs/review/VT_POST_PARSED_OUTPUT_PUBLICATION_RERANK_2026-04-04.md)

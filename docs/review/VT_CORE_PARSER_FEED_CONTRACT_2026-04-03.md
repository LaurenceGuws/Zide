# VT Core Parser Feed Contract

Date: 2026-04-03

## Purpose

Define the real contract problem inside the parser-feed owner-dependency front.

## Current Judgment

Parser feed is not blocked by parser mechanics alone.

It is blocked by mixed protocol execution state.

Parser/protocol execution still reaches one broad session-shaped receiver for
three different categories:

1. terminal semantics
2. protocol mode / host-contract state
3. reply/report/runtime hooks

That is the real reason `TerminalCore.feedOutputBytesLocked(self, owner, ...)`
still depends on outer owner shape.

## Live Mixed Line

The pressure is visible across:

- [parser_dispatch.zig](/home/home/personal/zide/src/terminal/core/protocol/parser_dispatch.zig)
- [csi.zig](/home/home/personal/zide/src/terminal/protocol/csi.zig)
- [csi_mode_query.zig](/home/home/personal/zide/src/terminal/protocol/csi_mode_query.zig)
- [csi_style_reset.zig](/home/home/personal/zide/src/terminal/protocol/csi_style_reset.zig)
- [terminal_core_csi_input_modes.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_csi_input_modes.zig)

The broad receiver is still used for:

- core screen and history semantics
- protocol mode mutation/query
- host-contract reporting flags
- reply sink emission

## Honest Split

The next contract should separate parser feed execution into explicit faces:

### 1. Terminal semantic surface

This is what should feel closest to `TerminalCore`:

- text/control/screen mutations
- scroll/edit/reset semantics
- OSC semantic effects
- terminal mode/screen effects

### 2. Protocol state surface

Still outside pure core, but narrower than full session shape:

- input protocol mode state
- host-reporting contract flags
- derived input/query snapshot state

### 3. Reply/report sink surface

Explicitly runtime-adjacent:

- protocol reply emission
- runtime-dependent reporting hooks

## Required Bar

The next move must not be:

- "pass `TerminalCore` and `self` both"
- "rename `owner` to `ctx`"
- "move parser into core" while keeping the same mixed receiver shape

The next move must be:

- define one narrower execution surface that parser/protocol code can target
  without requiring full session shape

## Likely First Slice

The cleanest first slice is not broad parser extraction.

It is likely:

- a parser-facing protocol state/sink owner that groups protocol-state and
  reply/report hooks explicitly, so parser/protocol no longer depends on the
  whole session by default

If that shape does not get clean quickly, stop and rerank instead of forcing a
halfway contract.

## Progress

The first contract slice is now explicit:

- [protocol_runtime.zig](/home/home/personal/zide/src/terminal/core/session/protocol_runtime.zig)
  groups:
  - protocol reply sink emission
  - CSI reply runtime snapshot reads
  - reporting flag mutation/query/reset

That means the first parser-facing runtime/state owner is real now, even
though parser feed still has not crossed fully into a narrower execution
surface.

Current read after this slice:

- reply/report hooks are now explicit enough to stop pretending the whole
  session is the protocol runtime API
- protocol state is still mixed enough that parser feed ownership is not done
- the next cut must target protocol state shape, not just more sink rewiring

## Further Progress

The next contract slice is now explicit too:

- [protocol_state.zig](/home/home/personal/zide/src/terminal/core/session/protocol_state.zig)
  groups:
  - CSI input-mode snapshot reads
  - grapheme-cluster-shaping protocol mode state mutation/reset

After this slice:

- the active protocol/core surface no longer reads raw
  `session.interaction.protocol_modes` or `session.interaction.derived_snapshot`
  directly
- parser/protocol now depends on two named outer faces instead:
  - [protocol_runtime.zig](/home/home/personal/zide/src/terminal/core/session/protocol_runtime.zig)
  - [protocol_state.zig](/home/home/personal/zide/src/terminal/core/session/protocol_state.zig)

Current read now:

- the remaining parser-feed contradiction is narrower still
- the next problem is less "broad mixed session reach" and more whether feed
  execution can target a genuinely smaller composite protocol execution
  surface than the current shell-shaped owner

## Feed Receiver Progress

That composite execution surface is now real:

- [protocol_execution.zig](/home/home/personal/zide/src/terminal/core/session/protocol_execution.zig)
  now serves as the parser-feed receiver
- [TerminalCore.feedOutputBytesLocked(...)](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  now constructs that execution object and passes it to the parser instead of
  the shell-shaped owner directly

Current read after this slice:

- parser feed no longer depends on the shell object as its execution receiver
- the receiver is still not pure-core, and should not pretend to be
- but it is now an explicit composite protocol execution surface instead of
  accidental shell reach

## Execution Surface Audit Progress

The first direct audit result is now in:

- publication dependence is now explicit at the execution surface
- [sync_updates.zig](/home/home/personal/zide/src/terminal/core/protocol/sync_updates.zig)
  no longer reaches raw publication fields directly
- [protocol_execution.zig](/home/home/personal/zide/src/terminal/core/session/protocol_execution.zig)
  now names the publication operations the protocol path still needs

Current read after this audit slice:

- `control` is still mostly just lock choreography
- `runtime` is still mostly transport/reply-write dependency
- `publication` is still a real surviving execution face, but it is no longer
  hidden behind raw field reach in the active protocol path
- the next honest question is whether publication can shrink further, or
  whether runtime/transport is now the stronger surviving contradiction

## Hostile Rerank Progress

The first execution-face rerank has now turned into code:

- `control` was the least defensible whole face
- it is now reduced to one direct mutex pointer on
  [protocol_execution.zig](/home/home/personal/zide/src/terminal/core/session/protocol_execution.zig)

Current read after that cut:

- `control` is no longer a meaningful surviving execution face
- `interaction` still survives honestly enough for the active protocol/helper
  path
- the real remaining execution-face pressure is now:
  - `publication`
  - `runtime` / transport write dependency

## Runtime Face Progress

The runtime side is now partially reduced too:

- [protocol_execution.zig](/home/home/personal/zide/src/terminal/core/session/protocol_execution.zig)
  now has an explicit runtime write/wake face
- that face owns only:
  - PTY/external transport write path
  - writer mutex
  - IO wake signaling

Current read after this slice:

- `publication` is still the strongest fully surviving execution face
- `runtime` is now a split state:
  - one exact write/wake face is explicit
  - one compatibility `session.runtime` pointer still survives because active
    protocol/helpers still rely on it
- the next honest move is to pressure publication first, or prove that the
  remaining runtime compatibility is actually the stronger contradiction

## Publication Pressure Decision

The next direct publication pressure pass now has a concrete result:

- trying to shrink publication to only a narrower field bundle did not survive
  the active call graph cleanly
- the protocol execution surface still reaches generic publication helpers that
  assume the broader publication slab

What that means:

- publication remains the strongest fully surviving execution face
- the next real move is not "smaller publication field set"
- the next real move has to be one coherent publication-contract cut that
  reduces those helper assumptions together

The first coherent publication contract is now named:

- synchronized-update publication behavior
- see
  [VT_PROTOCOL_PUBLICATION_SYNC_CONTRACT_2026-04-04.md](/home/home/personal/zide/docs/review/VT_PROTOCOL_PUBLICATION_SYNC_CONTRACT_2026-04-04.md)

That contract is now partially landed:

- the protocol path no longer performs the synchronized-update publication
  steps inline
- `protocol_execution` now owns:
  - `syncUpdateNeedsPublication(...)`
  - `publishSyncUpdate(...)`

Current read:

- publication is still a surviving execution face
- but one real publication contract is now explicit enough to keep cutting
  coherently, instead of attempting another failed whole-face shrink

The rerank after that slice is now explicit:

- publication still beats runtime
- runtime is now second because its surviving dependence is more compatibility
  residue than broad helper choreography
- see
  [VT_POST_SYNC_PUBLICATION_RERANK_2026-04-04.md](/home/home/personal/zide/docs/review/VT_POST_SYNC_PUBLICATION_RERANK_2026-04-04.md)

The next coherent publication slice is now landed too:

- parsed-output publication now goes through
  [protocol_execution.zig](/home/home/personal/zide/src/terminal/core/session/protocol_execution.zig)
  instead of direct
  [publication_flow.zig](/home/home/personal/zide/src/terminal/core/publication/publication_flow.zig)
  choreography across the active feed/runtime paths
- explicit operations now exist for:
  - `noteParsedOutput(...)`
  - `consumeFeedResult(...)`
  - `publishPendingOutput(...)`
  - `markOutputPending(...)`
- see
  [VT_PROTOCOL_PUBLICATION_PARSED_OUTPUT_CONTRACT_2026-04-04.md](/home/home/personal/zide/docs/review/VT_PROTOCOL_PUBLICATION_PARSED_OUTPUT_CONTRACT_2026-04-04.md)

Current read after this slice:

- publication still survives
- but two coherent publication contracts are now explicit on the execution
  surface:
  - synchronized updates
  - parsed-output publication
- the next rerank should now judge whether publication still beats runtime
  from that narrower baseline

That rerank is now tighter too:

- the remaining publication pressure is no longer broad parsed-output
  publication
- the remaining pressure is now closer to pending-refresh / poll publication
  cadence
- see
  [VT_POST_PARSED_OUTPUT_PUBLICATION_RERANK_2026-04-04.md](/home/home/personal/zide/docs/review/VT_POST_PARSED_OUTPUT_PUBLICATION_RERANK_2026-04-04.md)

That pending-refresh / poll contract is now landed too:

- [protocol_execution.zig](/home/home/personal/zide/src/terminal/core/session/protocol_execution.zig)
  now owns:
  - `viewRefreshPending(...)`
  - `takePendingViewRefreshRequest(...)`
  - `publishViewRefreshRequest(...)`
  - `publishPollUpdate(...)`
- active runtime callers now use that contract instead of direct
  [publication_flow.zig](/home/home/personal/zide/src/terminal/core/publication/publication_flow.zig)
  poll/refresh choreography
- see
  [VT_PROTOCOL_PUBLICATION_POLL_CONTRACT_2026-04-04.md](/home/home/personal/zide/docs/review/VT_PROTOCOL_PUBLICATION_POLL_CONTRACT_2026-04-04.md)

The runtime side then lost one more fake face too:

- `ProtocolExecution` no longer carries `session.runtime` as a generic
  session face
- `protocol_reply_sink.zig` now uses the explicit `writePtyBytes(...)`
  contract directly instead of the generic transport helper path

That means:

- the runtime side is now much closer to an honest explicit write/wake
  boundary
- publication no longer gets to win by inertia alone

See:

- [VT_POST_POLL_PUBLICATION_RERANK_2026-04-04.md](/home/home/personal/zide/docs/review/VT_POST_POLL_PUBLICATION_RERANK_2026-04-04.md)

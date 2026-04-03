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

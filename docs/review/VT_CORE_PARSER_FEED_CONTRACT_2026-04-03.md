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

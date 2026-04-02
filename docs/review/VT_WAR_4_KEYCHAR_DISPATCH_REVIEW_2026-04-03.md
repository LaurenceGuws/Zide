# VT War 4 Keychar Dispatch Review

Date: 2026-04-03

## Purpose

Name the only credible continuation path for War 4 after the stop-marker:

- key / char semantic dispatch before writer encoding

This is a design review, not a code queue.

## Why This Specific Slab

The broader "encoded host input" lane is too mixed to open directly.

From the live code:

- [session/input.zig](/home/home/personal/zide/src/terminal/core/session/input.zig)
  mixes:
  - semantic input-mode decisions
  - PTY/external writer access
  - protocol encoding calls
  - local echo fallback
- [key_encoder.zig](/home/home/personal/zide/src/terminal/input/key_encoder.zig)
  maps host keys onto terminal keys/chars, but terminates directly in the
  session input facade
- [input.zig](/home/home/personal/zide/src/terminal/input/input.zig)
  is the real encoding boundary

That means the only plausible next split is not "move input to core".
It is:

- separate semantic dispatch from writer encoding

## Current Mixed Decisions

The strongest semantic decisions still interleaved with writer mechanics are:

- app cursor arrow fallback
- app keypad mode use
- key-mode flag use
- auto-repeat gating
- ctrl/alt char fallback mapping
- local echo fallback when no writer exists
- alternate scroll-wheel to arrow-key mapping

These all feel more terminal-facing than pure transport mechanics.

## What Must Stay Outside Core

These still read as shell/runtime/transport concerns:

- `lockPtyWriter(...)`
- writer existence checks
- PTY vs external transport selection
- `writer.send*` and raw `writer.write(...)`
- kitty/legacy encoding details in
  [input.zig](/home/home/personal/zide/src/terminal/input/input.zig)

If a move drags those into
[TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig),
it is the wrong move.

## Candidate Line

The only line that currently looks defensible is:

- `TerminalCore` owns semantic dispatch decisions for key/char intent
- shell/session input owns:
  - locking
  - writer availability
  - encoding calls
  - local host-side fallback behavior that depends on missing transport

In other words:

- core decides what terminal intent is being expressed
- shell decides whether and how that intent can be encoded onto a live writer

## Why This Is Still Not A Safe Immediate Code Cut

The live code does not yet isolate that line cleanly enough.

Problems:

- semantic branches and `writer.send*` calls are still interleaved
- key and char paths partially duplicate logic
- some behavior is terminal-semantic but still depends on writer absence
  (`echoCharLocallyIfEnabled(...)`)
- `key_encoder.zig` already performs one mapping layer, so a bad move could
  create a second facade instead of a cleaner center

## Current Judgment

War 4 should only continue if it opens on this named design question:

- what exact semantic key/char dispatch result should `TerminalCore` return
  before encoding?

The next code move is justified only if we can express one coherent result
shape such as:

- send this terminal key intent
- send this terminal char intent
- suppress because repeat is disabled
- use app-cursor fallback sequence
- use local fallback path

without embedding writer/transport mechanics into that result.

That specific design bar is now written down in:

- [VT_WAR_4_KEYCHAR_RESULT_SHAPE_2026-04-03.md](/home/home/personal/zide/docs/review/VT_WAR_4_KEYCHAR_RESULT_SHAPE_2026-04-03.md)

## Bottom Line

The only credible War 4 continuation is now explicit:

- key / char semantic dispatch before writer encoding

If that design cannot be made crisp, War 4 is done from the current baseline.

# VT Protocol Reply Sink Contract

Date: 2026-04-03

## Purpose

Name one concrete post-CSI parser-owner blocker.

The question is no longer:

- which interaction fields are still mixed?

The stronger question now is:

- what protocol execution contract still keeps parser/protocol flow anchored
  on shell writer primitives instead of a cleaner terminal-centered boundary?

## Concrete Blocker

The clearest remaining blocker is:

- protocol reply sink ownership

Today, a large share of protocol execution still terminates directly on shell
writer mechanics.

Concrete evidence:

- [csi.zig](/home/home/personal/zide/src/terminal/protocol/csi.zig)
  still uses `lockPtyWriter()` and writer-bound reply helpers
- [dcs_apc.zig](/home/home/personal/zide/src/terminal/protocol/dcs_apc.zig)
  still builds replies and writes them through `writePtyBytes(...)`
- [osc_clipboard.zig](/home/home/personal/zide/src/terminal/protocol/osc_clipboard.zig)
  still writes replies through `writePtyBytes(...)`
- [palette.zig](/home/home/personal/zide/src/terminal/protocol/palette.zig)
  still writes replies through `writePtyBytes(...)`
- [osc_kitty_clipboard.zig](/home/home/personal/zide/src/terminal/protocol/osc_kitty_clipboard.zig)
  still couples reply generation to writer access

## Why This Matters

This is now a better-named blocker than vague parser-owner discomfort.

The remaining maturity gap is not simply:

- “parser code still touches shell things”

It is:

- terminal/protocol execution still lacks one explicit reply-emission contract

That contract gap prevents a cleaner story where:

- protocol handlers decide terminal semantics and reply intent
- outer runtime/shell owns the actual emission mechanics

Instead, many handlers still do both at once.

## What This Is Not

This is not a demand to:

- move writer mechanics into [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
- erase the runtime shell
- force all reply bytes to become core-owned strings immediately

It is a demand to name the missing boundary explicitly.

## Current Best Target Shape

The likely target is one explicit protocol reply sink contract with a line like:

- protocol layer produces reply intent or reply bytes through a named sink
- shell/runtime implements the sink using PTY/external transport writer access

The important part is not the exact type yet.
The important part is that protocol handlers stop teaching:

- “reply generation is naturally done by locking a writer here”

Progress now landed:

- a first explicit shell/runtime sink owner now exists in
  [protocol_reply_sink.zig](/home/home/personal/zide/src/terminal/core/session/protocol_reply_sink.zig)
- the shell exports that sink through
  [runtime.zig](/home/home/personal/zide/src/terminal/core/session/runtime.zig)
  and
  [terminal_runtime_shell.zig](/home/home/personal/zide/src/terminal/core/session/terminal_runtime_shell.zig)
- the first adopter slab is the prebuilt-byte reply family:
  - [dcs_apc.zig](/home/home/personal/zide/src/terminal/protocol/dcs_apc.zig)
  - [osc_clipboard.zig](/home/home/personal/zide/src/terminal/protocol/osc_clipboard.zig)
  - [palette.zig](/home/home/personal/zide/src/terminal/protocol/palette.zig)

## Why This Wins Over Narrow Reporting Pockets

This contract is stronger than another local reporting cleanup because it spans
multiple protocol families:

- CSI
- DCS
- OSC
- kitty clipboard replies

That makes it a more credible next maturity war.

## Bottom Line

The next concrete parser-owner / `TerminalCore` maturity question is now:

- protocol reply sink contract

If VT continues immediately, this is the next design battlefield to open.

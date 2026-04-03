# VT Protocol Reply Sink Shape

Date: 2026-04-03

## Purpose

Define the exact contract shape for the next VT maturity war:

- protocol reply sink ownership

The question is not:

- what helper can wrap `writePtyBytes(...)`?

It is:

- what is the narrowest explicit reply-emission contract that removes direct
  shell writer primitives from protocol handlers without pulling writer
  mechanics into
  [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)?

## Current Reply Shapes

Today there are two real reply families.

### 1. Prebuilt-byte replies

These handlers build the full reply bytes themselves and then emit them.

Examples:

- [dcs_apc.zig](/home/home/personal/zide/src/terminal/protocol/dcs_apc.zig)
- [osc_clipboard.zig](/home/home/personal/zide/src/terminal/protocol/osc_clipboard.zig)
- [palette.zig](/home/home/personal/zide/src/terminal/protocol/palette.zig)
- parts of
  [osc_kitty_clipboard.zig](/home/home/personal/zide/src/terminal/protocol/osc_kitty_clipboard.zig)

Current smell:

- they terminate directly on `writePtyBytes(...)`

### 2. Writer-driven replies

These handlers rely on a locked writer and helper functions that format/write
 directly into it.

Examples:

- [csi.zig](/home/home/personal/zide/src/terminal/protocol/csi.zig)
- [csi_reply.zig](/home/home/personal/zide/src/terminal/protocol/csi_reply.zig)
- parts of
  [osc_kitty_clipboard.zig](/home/home/personal/zide/src/terminal/protocol/osc_kitty_clipboard.zig)

Current smell:

- they terminate on `lockPtyWriter()` and writer-bound reply helpers

## Chosen Contract Shape

The first real sink contract should be:

- byte-oriented reply sink

Meaning:

- protocol handlers can emit fully formed reply bytes through one named sink
- shell/runtime implements the actual write mechanics
- protocol code stops teaching that direct `writePtyBytes(...)` is the natural
  reply boundary

## Why Byte-Oriented Wins First

This is the best first shape because:

- it already matches a large existing slab of protocol code
- it spans multiple protocol families
- it avoids prematurely forcing CSI writer-driven replies into the same shape
- it removes direct shell emission from protocol code without pretending that
  reply formatting must move into core immediately

## What This Does Not Decide Yet

This first sink shape does not settle:

- CSI writer-driven reply refactoring
- whether all reply generation should eventually become byte-oriented
- whether there should later be a richer reply-intent contract above bytes

Those are second-step questions.

## Best First Code Slice

The best first implementation slice is:

- adopt the byte-oriented sink across the prebuilt-byte reply family

Primary files:

- [dcs_apc.zig](/home/home/personal/zide/src/terminal/protocol/dcs_apc.zig)
- [osc_clipboard.zig](/home/home/personal/zide/src/terminal/protocol/osc_clipboard.zig)
- [palette.zig](/home/home/personal/zide/src/terminal/protocol/palette.zig)

Why this slice wins:

- it is one coherent family
- it removes the most direct `writePtyBytes(...)` ownership smell first
- it does not force CSI into a premature shape

## Progress Bar

Real progress will be:

- one explicit reply sink owner for byte replies
- protocol handlers in the first family calling that sink instead of direct
  shell emission

Fake progress will be:

- renaming `writePtyBytes(...)`
- adding a helper that still teaches the same ownership story
- forcing CSI writer-driven replies into the first slice just for uniformity

## Bottom Line

The next code move is now explicit:

- introduce a byte-oriented protocol reply sink
- apply it to the prebuilt-byte reply family first

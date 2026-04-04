# VT Core DECRQSS Owner Front

Date: 2026-04-04

## Purpose

Name and cut the remaining DECRQSS terminal-query slab that still lived under
one helper owner beside
[TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig).

## Current Judgment

After the CSI reply snapshot slice, DECRQSS was the next clean remaining
query-owner contradiction.

The bad story was:

- style-side DECRQSS truth already moved toward core
- but the remaining scroll-region and left-right-margin reply text still lived
  under one helper owner in
  [terminal_core_decrqss.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_decrqss.zig)

That kept one terminal-query slab reading helper-owned instead of directly
core-owned.

## Exact Line

The pressure was concentrated in:

- [terminal_core_decrqss.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_decrqss.zig)
- [terminal_core_protocol.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_protocol.zig)
- [dcs_apc.zig](/home/home/personal/zide/src/terminal/protocol/dcs_apc.zig)

## Required Bar

The move must not be:

- another reply helper reshuffle that leaves the same DECRQSS ownership story

It must:

- make DECRQSS terminal query truth a direct `TerminalCore` capability
- leave DCS framing and reply emission outside core

## Progress

The whole remaining slab is now landed.

What moved onto
[TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig):

- full `decrqssReplyInto(...)` terminal query truth for:
  - cursor style
  - SGR state
  - scroll region
  - left-right margins

What changed:

- [dcs_apc.zig](/home/home/personal/zide/src/terminal/protocol/dcs_apc.zig)
  now asks core directly for DECRQSS reply text
- dead helper owner is gone:
  - [terminal_core_decrqss.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_decrqss.zig)
- dead protocol-side wrapper is gone from
  [terminal_core_protocol.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_protocol.zig)

## Current Read

This is a small but honest `TerminalCore` sufficiency win:

- DECRQSS no longer teaches a helper-owned query center
- DCS framing now reads more cleanly as framing plus reply emission around a
  core-owned query capability

## Decision

Do not reopen DECRQSS ownership unless one stronger remaining query pocket
still clearly bypasses `TerminalCore`.

The next default pressure returns to the broader `TerminalCore` sufficiency
rerank from this cleaner query baseline.

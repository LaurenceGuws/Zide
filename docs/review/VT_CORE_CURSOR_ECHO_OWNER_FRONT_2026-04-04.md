# VT Core Cursor Echo Owner Front

Date: 2026-04-04

## Purpose

Name and cut the remaining small cursor/echo state reads that still taught
direct screen ownership outside
[TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig).

## Current Judgment

After the geometry slice, two small but real bypasses remained:

- config still wrote configured cursor style straight into `core.primary` and
  `core.alt`
- input still read local-echo mode 12 from raw active-screen state

Neither is a top-ranked war by itself, but both weaken the same terminal
object story if left behind.

## Progress

What moved onto
[TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig):

- configured cursor-style application
- local-echo mode 12 read access

What changed:

- [config.zig](/home/home/personal/zide/src/terminal/core/session/config.zig)
  now uses `self.core.setConfiguredCursorStyle(...)`
- [input.zig](/home/home/personal/zide/src/terminal/core/session/input.zig)
  now uses `self.core.localEchoMode12()`

## Current Read

This is a small but honest cleanup of terminal truth ownership:

- config no longer mutates both screens directly for cursor style
- char dispatch no longer reads local echo from raw screen state

## Decision

Do not reopen this slice unless one stronger remaining cursor/echo truth pocket
still clearly bypasses `TerminalCore`.

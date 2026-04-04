# VT Core Kitty Storage Owner Front

Date: 2026-04-04

## Purpose

Name and cut the remaining kitty-storage owner-shaped residue that still made
`TerminalCore` reset/mode/deinit read like they needed outer help for terminal
state cleanup.

## Current Judgment

The next live `TerminalCore` sufficiency contradiction is kitty storage
ownership.

The bad story was:

- core-owned reset and alt-screen transitions still cleared kitty image state
  through local owner shims
- `TerminalCore.deinit(...)` still took outer owner shape just to deinit kitty
  state

That weakened the terminal-object story because terminal-owned kitty storage
cleanup still looked like outer completion, not core truth.

## Exact Line

The pressure was concentrated in:

- [terminal_core.zig](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  - `deinit(...)`
  - `resetState(...)`
- [terminal_core_modes.zig](/home/home/personal/zide/src/terminal/core/terminal_core_modes.zig)
  - alt-screen enter/exit kitty cleanup
- [terminal_core_protocol.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_protocol.zig)
  - full kitty clear helper

## Required Bar

The move must not be:

- another tiny local shim
- just hiding the same owner-shaped dependency behind a different helper

It must:

- make kitty storage clear/deinit read as direct core-owned state cleanup
- leave protocol transport/reply behavior outside core where appropriate

## Progress

The first storage slice is now landed.

What changed:

- new core-side owner:
  [terminal_core_kitty_storage.zig](/home/home/personal/zide/src/terminal/core/terminal_core_kitty_storage.zig)
- [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  now owns:
  - active kitty image clearing
  - full kitty image clearing
  - kitty state deinit
- [terminal_core_modes.zig](/home/home/personal/zide/src/terminal/core/terminal_core_modes.zig)
  no longer builds local owner shims for alt-screen enter/exit cleanup
- [terminal_core_protocol.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_protocol.zig)
  now delegates full kitty clearing to core-owned storage cleanup
- [thread_runtime.zig](/home/home/personal/zide/src/terminal/core/session/thread_runtime.zig)
  no longer passes outer owner shape into `TerminalCore.deinit(...)`

## Current Read

This is a real `TerminalCore` sufficiency win:

- terminal-owned kitty storage cleanup now reads as core-owned state cleanup
- `TerminalCore.deinit(...)` is no longer owner-shaped

What remains outside core still reads narrower and more honest:

- kitty protocol parsing
- kitty reply/transport behavior
- placement dirty-region/runtime interactions

## Decision

Do not reopen kitty storage ownership unless one stronger remaining kitty
dependency still clearly steals ground from `TerminalCore`.

The next default pressure returns to broader `TerminalCore` sufficiency from
this cleaner baseline.

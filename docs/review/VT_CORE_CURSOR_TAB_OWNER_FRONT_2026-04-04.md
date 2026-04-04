# VT Core Cursor Tab Owner Front

Date: 2026-04-04

## Purpose

Name and cut the remaining basic cursor/tab/margin semantic slab that still
made protocol handlers read like they owned terminal navigation behavior
beside `TerminalCore`.

## Current Judgment

The next live `TerminalCore` sufficiency contradiction is cursor/tab owner
gravity.

The bad story was:

- basic terminal navigation semantics still terminated on raw `Screen` calls
  inside protocol/control handlers
- `TerminalCore` already owned edit, scroll, reset, input, resize, and kitty
  storage slabs, but not this basic cursor/tab/margin behavior

That weakened the terminal-object story because fundamental navigation
semantics still looked protocol-owned instead of terminal-owned.

## Exact Line

The pressure was concentrated in:

- [csi_exec.zig](/home/home/personal/zide/src/terminal/protocol/csi_exec.zig)
- [control_handlers.zig](/home/home/personal/zide/src/terminal/core/protocol/control_handlers.zig)
- [esc_effects.zig](/home/home/personal/zide/src/terminal/core/protocol/esc_effects.zig)

Those files still drove:

- cursor motion
- tab / backtab
- carriage return / backspace
- scroll region and left-right margins
- cursor style and tab-stop mutation

through raw screen calls.

## Required Bar

The move must not be:

- a cosmetic wrapper shuffle with no change in semantic center

It must:

- make basic navigation semantics read as `TerminalCore` verbs
- leave lower-level `Screen` mechanics where they belong

## Progress

The first whole slab is now landed.

What moved onto [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig):

- backspace
- tab / backtab
- carriage return
- cursor up/down/forward/back
- next/previous line
- absolute row/column/position
- scroll-region mutation
- left-right margin mutation
- cursor style
- tab-stop set/clear

What changed:

- [csi_exec.zig](/home/home/personal/zide/src/terminal/protocol/csi_exec.zig)
  now routes that slab through core-owned verbs
- [control_handlers.zig](/home/home/personal/zide/src/terminal/core/protocol/control_handlers.zig)
  now routes BS/TAB/CR through core-owned verbs
- [esc_effects.zig](/home/home/personal/zide/src/terminal/core/protocol/esc_effects.zig)
  now routes ESC H through a core-owned tab-stop verb

## Current Read

This is a real `TerminalCore` sufficiency win:

- basic terminal navigation semantics no longer look protocol-owned
- `Screen` remains the mechanism layer
- `TerminalCore` reads more like the terminal object for everyday cursor/tab
  behavior

What remains outside core in this lane now looks narrower and more honest:

- lower-level screen navigation implementation
- protocol framing/routing around those verbs

## Decision

Do not reopen cursor/tab owner pressure unless one stronger remaining
navigation-side contradiction still clearly steals ground from `TerminalCore`.

The next default pressure returns to the broader `TerminalCore` sufficiency
rerank from this cleaner baseline.

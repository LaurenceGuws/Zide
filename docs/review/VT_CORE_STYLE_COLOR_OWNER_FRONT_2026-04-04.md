# VT Core Style Color Owner Front

Date: 2026-04-04

## Purpose

Name and cut the remaining terminal style/color state slab that still made
protocol files own screen-attribute truth beside
[TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig).

## Current Judgment

The next live `TerminalCore` sufficiency contradiction is style/color owner
gravity.

The bad story was:

- SGR mutation still lived in
  [csi_style_reset.zig](/home/home/personal/zide/src/terminal/protocol/csi_style_reset.zig)
  as protocol-local `screen.current_attrs` mutation
- DECRQSS style replies still rebuilt cursor-style and SGR state directly from
  raw screen fields in
  [terminal_core_decrqss.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_decrqss.zig)
- OSC dynamic color queries still read default color truth directly from
  protocol code in
  [palette.zig](/home/home/personal/zide/src/terminal/protocol/palette.zig)

That weakened the terminal-object story because one coherent style/color slab
still read as protocol-owned screen state instead of core-owned terminal
truth.

## Exact Line

The pressure was concentrated in:

- [csi_style_reset.zig](/home/home/personal/zide/src/terminal/protocol/csi_style_reset.zig)
- [terminal_core_decrqss.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_decrqss.zig)
- [palette.zig](/home/home/personal/zide/src/terminal/protocol/palette.zig)

## Required Bar

The move must not be:

- another protocol-side helper shuffle that still leaves style/color truth
  beside core

It must:

- move style/color mutation and query truth onto `TerminalCore`
- leave reply emission and OSC framing outside core

## Progress

The first whole slab is now landed.

New core-side owner:

- [terminal_core_style.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_style.zig)

What moved onto
[TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig):

- SGR style/color mutation
- DECRQSS cursor-style reply text
- DECRQSS SGR reply assembly
- OSC dynamic color query truth

What changed:

- [csi.zig](/home/home/personal/zide/src/terminal/protocol/csi.zig)
  now routes SGR directly through `self.core.applySgrLocked(...)`
- [csi_style_reset.zig](/home/home/personal/zide/src/terminal/protocol/csi_style_reset.zig)
  now keeps only DECSTR outer reset effects
- [terminal_core_decrqss.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_decrqss.zig)
  now delegates style-side DECRQSS truth to core-owned verbs
- [palette.zig](/home/home/personal/zide/src/terminal/protocol/palette.zig)
  now asks core for dynamic color query truth
- dead protocol-side palette helper gravity is removed from
  [terminal_core_protocol.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_protocol.zig)

## Current Read

This is a real `TerminalCore` sufficiency win:

- style/color state no longer reads protocol-owned by default
- SGR mutation now terminates on core-side terminal truth
- style-side query truth is materially flatter at the protocol edge

## Decision

Do not reopen style/color ownership unless one stronger remaining
style-adjacent contradiction still clearly steals ground from `TerminalCore`.

The next default pressure returns to broader `TerminalCore` sufficiency from
this cleaner style/color baseline.

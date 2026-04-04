# VT Core Keymode Owner Front

Date: 2026-04-04

## Purpose

Name and cut the remaining key-mode and grapheme-shaping terminal state slab
that still made input/protocol helpers mutate raw `Screen` state outside
`TerminalCore`.

## Current Judgment

The next live `TerminalCore` sufficiency contradiction is key-mode owner
gravity.

The bad story was:

- key-mode push/pop/modify still mutated the active screen directly from
  [input_modes.zig](/home/home/personal/zide/src/terminal/core/input_modes.zig)
- grapheme shaping still wrote `primary` and `alt` screen state directly from
  [protocol_state.zig](/home/home/personal/zide/src/terminal/core/session/protocol_state.zig)

That weakened the terminal-object story because one coherent protocol-input
terminal state slab still bypassed `TerminalCore`.

## Exact Line

The pressure was concentrated in:

- [input_modes.zig](/home/home/personal/zide/src/terminal/core/input_modes.zig)
- [protocol_state.zig](/home/home/personal/zide/src/terminal/core/session/protocol_state.zig)
- [csi_exec.zig](/home/home/personal/zide/src/terminal/protocol/csi_exec.zig)
  through key-mode query/mutation routing

## Required Bar

The move must not be:

- another helper shim that still leaves protocol-input terminal state outside
  core

It must:

- move key-mode and grapheme-shaping terminal state mutation onto
  `TerminalCore`
- leave runtime reply/write behavior outside core

## Progress

The first whole slab is now landed.

What moved onto [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig):

- key-mode flag sanitization
- key-mode snapshot flags
- key-mode push
- key-mode pop
- key-mode modify
- grapheme-cluster shaping 2027 screen-state mutation

What changed:

- [input_modes.zig](/home/home/personal/zide/src/terminal/core/input_modes.zig)
  now routes key-mode semantics through core-owned verbs
- [protocol_state.zig](/home/home/personal/zide/src/terminal/core/session/protocol_state.zig)
  now routes grapheme-shaping screen mutation through core-owned state

What stays outside, honestly:

- key-mode query reply emission
- derived input snapshot publication

## Current Read

This is a real `TerminalCore` sufficiency win:

- protocol-input terminal state no longer bypasses core for key-mode and
  grapheme-shaping mutation
- the remaining input helper work is narrower and more obviously about
  snapshot/report/write behavior

## Decision

Do not reopen key-mode ownership unless one stronger remaining input-side
terminal state contradiction still clearly steals ground from `TerminalCore`.

The next default pressure returns to broader `TerminalCore` sufficiency from
this cleaner baseline.

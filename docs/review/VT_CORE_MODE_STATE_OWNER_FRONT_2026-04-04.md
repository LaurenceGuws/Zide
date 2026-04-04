# VT Core Mode State Owner Front

Date: 2026-04-04

## Purpose

Name and cut the remaining terminal mode-state slab that still made CSI mode
mutation/query read like helper-owned screen state instead of `TerminalCore`
truth.

## Current Judgment

The next live `TerminalCore` sufficiency contradiction is mode-state owner
gravity.

The bad story was:

- CSI terminal mode mutation still terminated on raw `Screen` mutation inside
  `terminal_core_csi_modes.zig`
- DECRQM terminal mode query still reconstructed terminal mode truth from raw
  screen fields through `terminal_core_csi_mode_query.zig`

That weakened the terminal-object story because one coherent terminal mode
state slab still lived beside `TerminalCore`.

## Exact Line

The pressure was concentrated in:

- [csi_mode_mutation.zig](/home/home/personal/zide/src/terminal/protocol/csi_mode_mutation.zig)
- [csi_mode_query.zig](/home/home/personal/zide/src/terminal/protocol/csi_mode_query.zig)
- the now-removed helper owners:
  - `src/terminal/core/protocol/terminal_core_csi_modes.zig`
  - `src/terminal/core/protocol/terminal_core_csi_mode_query.zig`

## Required Bar

The move must not be:

- another helper rename that leaves terminal mode truth outside core

It must:

- move terminal mode mutation/query truth onto `TerminalCore`
- leave honest outer alt-screen effects outside core

## Progress

The first whole slab is now landed.

What moved onto [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig):

- ANSI terminal mode mutation:
  - insert mode
  - local echo mode 12
  - newline mode
- private terminal mode mutation:
  - screen reverse
  - origin mode
  - autowrap
  - cursor blink
  - cursor visible
  - reverse wrap
  - left-right margin mode 69
  - save-cursor mode 1048
- terminal mode snapshot/query truth for:
  - column mode 132
  - all of the above mode state
  - alt-active state

What stayed outside, honestly:

- alt-screen transitions `47/1047/1049`
- input protocol modes
- reporting flags

What changed:

- [csi_mode_mutation.zig](/home/home/personal/zide/src/terminal/protocol/csi_mode_mutation.zig)
  now routes terminal mode mutation directly through core
- [csi_mode_query.zig](/home/home/personal/zide/src/terminal/protocol/csi_mode_query.zig)
  now builds terminal-mode DECRQM answers from a core-owned snapshot
- the two helper owners above are deleted

## Current Read

This is a real `TerminalCore` sufficiency win:

- terminal mode state no longer looks helper-owned
- DECRQM terminal mode answers now read more directly as core truth
- the remaining outer mode machinery is narrower and more honest

## Decision

Do not reopen terminal mode-state ownership unless one stronger remaining
mode-side contradiction still clearly steals ground from `TerminalCore`.

The next default pressure returns to broader `TerminalCore` sufficiency from
this cleaner baseline.

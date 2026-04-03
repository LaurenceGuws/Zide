# VT CSI Mode Effects Contract

Date: 2026-04-03

## Purpose

Define the first executable contract split inside the CSI mode-effects war.

The question is:

- what part of CSI mode mutation is already terminal mode-and-screen-effect
  semantics and can move behind one cleaner core-side owner now?

## Chosen Split

The first slice is:

- terminal mode and screen effects

Not:

- input protocol mode state
- host-contract flag mutation
- sync-update state
- column-mode publishing

## Included In The First Slice

The first core-side owner now groups:

- ANSI:
  - insert mode
  - local echo mode 12
  - newline mode
- private terminal/screen effects:
  - screen reverse
  - origin mode
  - cursor blink
  - cursor visible
  - reverse wrap
  - left-right margin mode 69
  - alt-screen entry/exit variants
  - save/restore cursor 1048

## Left Outside Intentionally

These remain outside the new owner:

- input mode mutation through
  [input_modes.zig](/home/home/personal/zide/src/terminal/core/input_modes.zig)
- host-contract flags like:
  - `report_color_scheme_2031`
  - `inband_resize_notifications_2048`
  - `kitty_paste_events_5522`
- sync-updates through
  [sync_updates.zig](/home/home/personal/zide/src/terminal/core/protocol/sync_updates.zig)
- column mode 132 through
  [config.zig](/home/home/personal/zide/src/terminal/core/session/config.zig)

## Why This Is Honest

This is not “all of CSI mode mutation.”

It is the first subset that already reads like one terminal-semantic cluster
without dragging publication, host contract, or input-snapshot mechanics into
the same owner.

## Bottom Line

The first CSI mode-effects contract is now explicit:

- terminal mode and screen effects group together on a core-side owner

Read-side progress now landed too:

- [terminal_core_csi_mode_query.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_csi_mode_query.zig)
  now owns the corresponding terminal-mode snapshot/query slice for DECRQM
- [csi_mode_query.zig](/home/home/personal/zide/src/terminal/protocol/csi_mode_query.zig)
  now delegates that read-side terminal subset there while leaving input
  protocol state and host-contract flags outside

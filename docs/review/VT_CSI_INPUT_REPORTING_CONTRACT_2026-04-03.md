# VT CSI Input Reporting Contract

Date: 2026-04-03

## Purpose

Define the first executable split inside the CSI input/reporting war.

The question is:

- what remaining CSI state is already a coherent input protocol mode/query
  contract and can move together without dragging runtime-dependent reporting
  behavior with it?

## Chosen Split

The first slice is:

- input protocol mode mutation and DECRQM query state

Not:

- host-reporting contract flags

## Included In The First Slice

The new core-side owner groups:

- app cursor keys
- app keypad
- auto-repeat
- mouse reporting modes
- focus reporting
- bracketed paste
- alternate scroll
- sync updates
- grapheme cluster shaping 2027
- the corresponding DECRQM read-side answers for that same set

## Left Outside Intentionally

These remain outside the new owner:

- `report_color_scheme_2031`
- `inband_resize_notifications_2048`
- `kitty_paste_events_5522`

Why:

- they are explicit host-reporting contract flags
- they lead directly into runtime-dependent reporting behavior
- pulling them inward with the input modes would blur the contract again

## Why This Is Honest

This is not “all remaining CSI state.”

It is the subset that already reads like one protocol input-mode contract on
both write and DECRQM read paths.

## Bottom Line

The first CSI input/reporting contract is now explicit:

- input protocol modes and their DECRQM query state group together

# VT Shell Mutation Scrollbar Front

Date: 2026-04-03

## Purpose

Take the first mutation-transaction locking slice.

The opening question is:

- can any host mutation path stop opening the shell lock itself and instead use
  a backend-owned mutation transaction boundary?

## Why Scrollbar Drag Went First

The scrollbar drag path was the cleanest first transaction:

- isolated in one app runtime path
- one narrow backend mutation
- no intertwined selection gesture state

This made it a better first slice than the broader pointer-selection flow.

## Slice

[terminal_scrollbar_runtime.zig](/home/home/personal/zide/src/app/terminal/terminal_scrollbar_runtime.zig)
no longer opens the shell lock directly for drag updates.

Instead:

- [scrollback_view.zig](/home/home/personal/zide/src/terminal/core/scrollback_view.zig)
  now owns:
  - `setScrollOffsetFromNormalizedTrack(...)`
- the existing locked helper remains:
  - `setScrollOffsetFromNormalizedTrackLocked(...)`

That changes the transaction story from:

- app opens shell lock
- app drives backend mutation

to:

- app calls one backend mutation verb
- backend owns the lock for that mutation transaction

## Why This Matters

This is a real shell-lock win, not a cosmetic move.

It reduces one whole host-visible mutation pattern where the shell looked like
the transaction boundary for a backend-owned scroll operation.

## What Remains

The larger mutation front is still open:

- pointer/selection gesture flow in
  [terminal_widget_pointer.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_pointer.zig)
- related selection/scrollback transaction boundaries in
  [selection.zig](/home/home/personal/zide/src/terminal/core/selection.zig)
  and
  [scrollback_view.zig](/home/home/personal/zide/src/terminal/core/scrollback_view.zig)

That remaining path is broader and may still be honest in places because it
holds one protected transaction across multiple mutation steps.

## Bottom Line

Scrollbar drag no longer teaches the app to open the shell lock itself for this
mutation path.

That is the first real mutation-locking slice, not the end of the mutation
front.

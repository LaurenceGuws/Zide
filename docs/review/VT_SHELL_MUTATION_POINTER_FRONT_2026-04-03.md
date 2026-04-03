# VT Shell Mutation Pointer Front

Date: 2026-04-03

## Purpose

Take the larger mutation-transaction slice after the scrollbar drag opener.

The question is:

- does the pointer-selection gesture path still need one oversized widget-owned
  shell lock, or can backend mutation verbs own those protected transactions
  themselves?

## Contradiction

Before this slice,
[terminal_widget_pointer.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_pointer.zig)
opened one broad shell lock across the whole gesture flow:

- reset-to-live-bottom for input
- selection clear
- click selection begin
- gesture extension
- range selection
- selection finish
- drag-driven scroll
- wheel scroll

That made the widget look like the mutation transaction boundary for backend
selection and scrollback behavior.

## Slice

Unlocked mutation entrypoints now exist for the pointer-owned backend verbs:

- [selection.zig](/home/home/personal/zide/src/terminal/core/selection.zig)
  - `clearSelectionIfActive(...)`
  - `finishSelectionIfActive(...)`
  - `beginClickSelection(...)`
  - `selectOrUpdateCellInRow(...)`
  - `extendGestureSelection(...)`
- [scrollback_view.zig](/home/home/personal/zide/src/terminal/core/scrollback_view.zig)
  - `resetToLiveBottomForInput(...)`
  - `scrollSelectionDrag(...)`
  - `scrollWheel(...)`

The widget pointer path now calls those backend entrypoints directly and no
longer opens one giant shell lock around the whole gesture flow.

## Why This Matters

This is a real mutation-locking win:

- the widget no longer owns the protected transaction boundary for these
  backend mutations
- selection and scrollback helpers now own their own lock scope per semantic
  mutation
- the shell is less visible as the host-side gesture transaction owner

## What Remains

This does not prove the entire lock front is done.

Still under suspicion:

- render-time snapshot locking and `tryLock()` usage in widget/input paths
- whether any remaining host-facing lock/unlock surface still survives only by
  habit
- whether deeper internal concurrency shape should change at all

## Bottom Line

The broad pointer-selection gesture lock is gone from widget code.

That is the main mutation-locking front, not a cosmetic lock shuffle.

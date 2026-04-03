# VT Shell Lock Post Mutation Rerank

Date: 2026-04-03

## Purpose

Rerank the shell lock front after the two mutation-transaction slices:

- scrollbar drag
- pointer-selection gesture flow

## What Improved

The broadest host-visible locking patterns are materially flatter now.

Hosts/UI no longer need to open shell locks directly for:

- common read-side queries
- scrollbar drag mutation
- the larger pointer-selection / drag-scroll gesture flow

## What Remains

### 1. Render-time snapshot / opportunistic lock use

Strongest examples:

- [terminal_widget_input.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_input.zig)
  `tryLock()` around OSC clipboard extraction

Current read:

- this is now the most visible remaining host-side shell lock pattern
- but it may already be honest:
  - opportunistic
  - narrow
  - snapshot-like
  - explicitly non-blocking

### 2. Mouse-reporting path

Strongest example:

- [terminal_widget_mouse_reporting.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_mouse_reporting.zig)

Current read:

- still widget-held shell lock
- but this path is tightly coupled to live writer/reporting semantics
- it reads more like input/reporting transport pressure than generic shell
  gravity

### 3. Internal config / publication / protocol locking

Examples:

- [config.zig](/home/home/personal/zide/src/terminal/core/session/config.zig)
- [terminal_publication.zig](/home/home/personal/zide/src/terminal/core/publication/terminal_publication.zig)
- [sync_updates.zig](/home/home/personal/zide/src/terminal/core/protocol/sync_updates.zig)

Current read:

- not the next shell-hostile front
- these are internal backend mutation/reporting boundaries, not host-facing
  shell habits

## Judgment

Lock choreography is now close to a stop-marker.

Why:

- the broad read-side pattern is gone
- the broad mutation gesture pattern is gone
- what remains is either:
  - honest narrow snapshot locking
  - or input/reporting paths that belong under transport/reporting scrutiny,
    not a generic lock war

## Decision

Do not keep the lock front active by momentum.

Only reopen it if:

- a new host-visible shell lock pattern appears that is broader than the
  current residual cases

Otherwise:

- return to the broader `TerminalCore` sufficiency / shell-survival rerank
  from this cleaner baseline

## Bottom Line

The shell lock front is no longer the default active contradiction.

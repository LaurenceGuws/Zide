# VT Shell Lock Post Read Rerank

Date: 2026-04-03

## Purpose

Rerank the lock front after the read-side locking slab moved under
[host_queries.zig](/home/home/personal/zide/src/terminal/core/session/host_queries.zig).

The question is:

- what remaining shell lock pattern most directly weakens VT maturity now?

## What Improved

The broadest host-visible read-side pattern is materially flatter.

Hosts and UI callers no longer need to do:

- `shell.lock()`
- reach into `shell.core`
- `shell.unlock()`

for common read-only queries like:

- cwd
- hyperlink URI
- progress

## What Remains

### 1. Mutation transaction locking

Examples:

- [terminal_widget_pointer.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_pointer.zig)
- [terminal_scrollbar_runtime.zig](/home/home/personal/zide/src/app/terminal/terminal_scrollbar_runtime.zig)
- [selection.zig](/home/home/personal/zide/src/terminal/core/selection.zig)
- [scrollback_view.zig](/home/home/personal/zide/src/terminal/core/scrollback_view.zig)

Current read:

- this is now the strongest remaining shell lock front
- many of these flows are genuine multi-step mutation transactions
- but the shell is still highly visible as the thing that opens the protected
  mutation scope

### 2. Render/widget snapshot locking

Examples:

- [terminal_widget_input.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_input.zig)
  clipboard pull with `tryLock()`
- any remaining widget/runtime paths that need a protected snapshot larger than
  one scalar query

Current read:

- smaller than the mutation front
- more likely to be honest if the caller genuinely needs a wider protected
  snapshot

### 3. Internal session/control locking

Examples:

- [input_modes.zig](/home/home/personal/zide/src/terminal/core/input_modes.zig)
- [terminal_core_feed.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_feed.zig)
- [resize_reflow.zig](/home/home/personal/zide/src/terminal/core/resize_reflow.zig)

Current read:

- not the next shell-hostile front
- these are mostly internal concurrency mechanics, not host-facing shell
  gravity

## Decision

The next lock front should be:

- mutation transaction locking

Not:

- more read-side query cleanup
- internal mutex usage in core/session helpers
- generic deletion of `lock()` call sites without a stronger mutation contract

## Bottom Line

After the read-side slice, the remaining lock contradiction is narrower and
more serious:

- hosts still experience the shell as the mutation transaction boundary

If the lock front continues, that is the next place to attack.

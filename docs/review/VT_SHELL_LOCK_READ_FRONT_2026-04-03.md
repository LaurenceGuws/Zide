# VT Shell Lock Read Front

Date: 2026-04-03

## Purpose

Take the first direct slice against shell lock choreography.

The question is:

- do hosts and UI paths still have to experience "lock shell, then reach into
  core" as the normal way to read terminal truth?

## Contradiction

Before this slice, several read-only host/UI paths still took the shell lock
explicitly just to read immutable or snapshot-like terminal truth:

- [terminal_widget_open.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_open.zig)
  for hyperlink URI and cwd reads
- [workspace_host.zig](/home/home/personal/zide/src/terminal/core/workspace_host.zig)
  for active cwd reads
- [terminal_draw_surface_runtime.zig](/home/home/personal/zide/src/app/terminal/terminal_draw_surface_runtime.zig)
  for progress reads

That kept the shell visible as the host's read-side API even when the real
terminal truth already lived lower.

## Slice

The first read-only locking slab now sits under
[host_queries.zig](/home/home/personal/zide/src/terminal/core/session/host_queries.zig):

- `copyCwdText(...)`
- `copyHyperlinkUri(...)`
- `currentProgress(...)`

Those helpers now own synchronization for these read-side queries.

The call sites above no longer take the shell lock themselves just to read core
truth.

## Why This Matters

This does not eliminate locking.

It does make the boundary more honest:

- shell still owns synchronization
- host/UI callers are less exposed to raw lock choreography
- read-side terminal truth no longer teaches "lock, then dig through `core`"
  as the default pattern

## Current Read

This is a real lock-front win, but only the first one.

What remains under active suspicion:

- explicit shell locking around mutation flows
- explicit shell locking inside rendering/widget surfaces that still need
  broader protected snapshots
- whether the shell's public `lock/tryLock/unlock` methods still deserve to
  survive as a host-facing habit

## Bottom Line

The first lock-choreography slice should be judged as:

- less host-visible lock gravity on read-side terminal truth
- not yet a final answer on whether the shell's locking surface is
  irreducible

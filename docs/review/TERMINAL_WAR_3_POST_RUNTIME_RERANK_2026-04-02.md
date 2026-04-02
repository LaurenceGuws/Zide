# Terminal War 3 Post Runtime Rerank 2026-04-02

## Purpose

Re-rank War 3 after the first runtime-shell contradiction wave.

## Current Read

The runtime-shell wave materially landed.

- [session/runtime.zig](/home/home/personal/zide/src/terminal/core/session/runtime.zig)
  no longer owns session allocation and storage-layout assembly
- it no longer owns launch-shell-path bootstrap state
- it no longer owns lifecycle entrypoint concentration

That means the old runtime-shell contradiction is no longer the default War 3
enemy.

At this point:

- [session/runtime.zig](/home/home/personal/zide/src/terminal/core/session/runtime.zig)
  reads much closer to a boring shell
- [terminal_publication.zig](/home/home/personal/zide/src/terminal/core/publication/terminal_publication.zig)
  reads much closer to a boring export edge

The remaining first-glance contradiction is higher-level.

## Strongest Remaining Contradiction

The strongest remaining contradiction now appears to be the session object
model itself:

- [terminal_runtime.zig](/home/home/personal/zide/src/terminal/core/terminal_runtime.zig)
  still exposes `PtyTerminalRuntime` as the obvious aggregate center
- that aggregate still physically owns:
  - `runtime`
  - `core`
  - `interaction`
  - `publication`
  - `control`

Even though runtime and publication API roots are now much narrower, the live
shape still reads like one big session object with several sub-domains hanging
off it, rather than one unmistakable library center plus shell and export edge.

Against Ghostty/WezTerm pressure, this is now the clearer War 3 obstacle.

## What This Means

The next War 3 question is no longer:

- how do we make `session/runtime.zig` smaller?

It is:

- what should the owning session/library object model be if `TerminalCore` is
  truly the center?

## Bottom Line

Runtime-shell cleanup should pause here.

The next likely War 3 battlefield is the aggregate session shape around
`PtyTerminalRuntime`, not more runtime helper shaving.

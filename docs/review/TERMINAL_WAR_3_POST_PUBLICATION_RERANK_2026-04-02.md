# Terminal War 3 Post-Publication Rerank 2026-04-02

## Purpose

Re-rank War 3 after the publication-boundary wave.

## Current Read

The broad publication contradiction is materially reduced now.

After the recent whole-slab cuts:

- flow/choreography moved to
  [publication_flow.zig](/home/home/personal/zide/src/terminal/core/publication/publication_flow.zig)
- widget capture/preparation moved to
  [publication_capture.zig](/home/home/personal/zide/src/terminal/core/publication/publication_capture.zig)
- host-facing generation/frame summary packaging moved to
  [publication_state.zig](/home/home/personal/zide/src/terminal/core/publication/publication_state.zig)
- sync-updates semantics moved to
  [sync_updates.zig](/home/home/personal/zide/src/terminal/core/protocol/sync_updates.zig)

[terminal_publication.zig](/home/home/personal/zide/src/terminal/core/publication/terminal_publication.zig)
is now down to a much narrower shape and mostly reads like:

- snapshot/render-cache export
- render-cache lookup for diff/snapshot consumers
- presentation-feedback re-exports

That is much closer to a boring export edge than the earlier War 3 read.

## New Strongest Contradiction

The next likely War 3 contradiction is now runtime shell weight, not
publication.

Why:

- [session/runtime.zig](/home/home/personal/zide/src/terminal/core/session/runtime.zig)
  still owns:
  - session allocation and full state assembly
  - transport/runtime/publication storage layout initialization
  - transport attach/open/close
  - thread lifecycle entrypoints
  - polling/backlog control
  - launch-shell path state
- even though much of its behavior is forwarded to narrower owners, it still
  reads like important terminal ownership rather than a thin runtime shell
  around an unmistakable engine center

Compared to the references:

- Ghostty still wins on first-glance runtime-shell clarity
- WezTerm still wins on mature runtime assembly discipline

## What This Means

War 3 should now pivot away from publication-by-momentum.

The next question is not:

- "what else can we shave from publication?"

It is:

- "what is the single largest runtime-shell contradiction to `TerminalCore`
  being the indisputable library center?"

## Best Next Question

Which slab in
[session/runtime.zig](/home/home/personal/zide/src/terminal/core/session/runtime.zig)
is the biggest contradiction to "runtime shell only"?

Current candidates:

1. session allocation plus storage-layout assembly in `init(...)`
2. thread/transport lifecycle entrypoint surface
3. launch-shell-path state living on runtime rather than a narrower host shell

## Bottom Line

Publication is no longer the default War 3 enemy.

The next likely War 3 battlefield is runtime-shell shape and assembly weight.

# Terminal War 3 Post Identity Rerank 2026-04-02

## Purpose

Re-rank War 3 after the session-object and public-identity wave.

## Current Read

The live stack is materially cleaner at first glance now:

- publication reads like an export edge
- runtime reads like a shell
- the aggregate session state is grouped under `session`
- the aggregate type is defined as
  [TerminalSession](/home/home/personal/zide/src/terminal/core/session/terminal_session.zig)
- the public root now exports `TerminalSession` directly, with
  `PtyTerminalRuntime` reduced to compatibility residue

That means the earlier War 3 contradictions are no longer the default enemy.

## Strongest Remaining Question

The next question is no longer obviously a local whole-slab cut.

It is broader:

- does `TerminalCore` now read strongly enough as the indisputable library
  center, or is there still a deeper split between engine truth and session
  truth that only a stronger object-model move would fix?

Current bias:

- the remaining issue is now smaller and less obvious than the earlier
  publication/runtime/session-object contradictions
- there is no immediately obvious next local file cut that beats a fresh
  compare-against-references pass

## Bottom Line

War 3 is near a real rerank point again.

Do not keep cutting by momentum unless a fresh review finds another large,
coherent contradiction to the `zide-vt` target shape.

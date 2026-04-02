# VT Sprint Post-Mutation Rerank

Date: 2026-04-02

## Current Read

The `vt-sprint` lane has now landed the meaningful shape changes it needed:

- immutable export reads moved toward
  [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
- `TerminalCore` is exported at the VT root
- app/UI/FFI/workspace/replay consumers now speak
  [TerminalSession](/home/home/personal/zide/src/terminal/core/session/terminal_session.zig)
  directly
- the selection/viewport mutation contract no longer hangs off
  `TerminalSession`
- the mutation facade on `TerminalSession` is deleted

That means the old easy contradiction is gone:

- `TerminalSession` no longer looks like the default convenience center for
  immutable reads plus mutable host interaction

## What `TerminalSession` Now Looks Like

[terminal_session.zig](/home/home/personal/zide/src/terminal/core/session/terminal_session.zig)
is now very small and reads like:

- allocator
- `core`
- `session`
- init
- lock/unlock
- PTY writer access

Progress note, later on 2026-04-02:

- `snapshot` is now off `TerminalSession` too
- replay and regression callers now use
  [terminal_publication.zig](/home/home/personal/zide/src/terminal/core/publication/terminal_publication.zig)
  directly for snapshot export

So the remaining `TerminalSession` story is now even narrower:

- init
- lock/unlock
- PTY writer access

That is much closer to a runtime shell around an engine-centered object than it
was at the start of the sprint.

## Strongest Remaining Gap

The strongest remaining gap is no longer local convenience residue.

It is now a deeper object-model question:

- should `TerminalCore` itself become sufficiently complete that hosts can
  treat it as the true VT library object
- or is `TerminalSession` the true library object, with `TerminalCore` as the
  semantic center inside it

The live code now makes that ambiguity harder to dodge:

- `TerminalCore` looks increasingly sufficient
- `TerminalSession` still owns instantiation, locking, transport wiring, and
  snapshot access

That is not helper-shaving territory anymore.
That is a design choice.

## What Is No Longer The Right Move

Do not keep cutting because the branch still has momentum.

Specifically:

- do not reopen another mutation-helper lane by habit
- do not rename historical PTY-named tests/docs and pretend that is the real
  blocker
- do not split `TerminalSession` further unless a fresh whole-slab
  contradiction appears

## Best Next Move

The next honest step is a design review, not another opportunistic refactor.

That review should answer one question explicitly:

- what is the actual `zide-vt` library object after this sprint?

From the current baseline, the likely serious options are:

1. `TerminalCore` becomes the explicit VT library object, and `TerminalSession`
   becomes runtime/transport shell plus host synchronization shell.
2. `TerminalSession` is explicitly accepted as the VT library object, and
   `TerminalCore` is treated as a strong internal engine center rather than the
   public library identity.

## Bottom Line

`vt-sprint` is now past the stage where local cleanup alone can answer the
plug-and-play question.

The next blocker is explicit object-identity design, not more convenience-slab
deletion.

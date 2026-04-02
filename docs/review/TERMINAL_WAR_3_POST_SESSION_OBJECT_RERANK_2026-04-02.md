# Terminal War 3 Post Session Object Rerank 2026-04-02

## Purpose

Re-rank War 3 after the first aggregate-session-object wave.

## Current Read

The live stack is materially cleaner now:

- publication reads much closer to an export edge
- runtime reads much closer to a shell
- the aggregate object no longer stores flat peer domain fields
- the aggregate type definition no longer lives in `terminal_runtime.zig`

That means the earlier War 3 contradictions are no longer the default enemy.

## Strongest Remaining Contradiction

The strongest remaining contradiction is now likely the public root identity:

- the owning aggregate type is now
  [TerminalSession](/home/home/personal/zide/src/terminal/core/session/terminal_session.zig)
- but the public root still presents it only as `PtyTerminalRuntime` via
  [terminal_runtime.zig](/home/home/personal/zide/src/terminal/core/terminal_runtime.zig)

That keeps one old host/runtime-shaped name at the very top of the stack even
though the underlying shape now reads more like a generic terminal session over
`TerminalCore`.

## Why This Matters

War 3 is now less about helper ownership and more about first-glance library
identity.

A strong maintainer opening the live stack should be able to see the honest
names immediately.

Right now, the code says:

- `TerminalSession`

but the public root still says:

- `PtyTerminalRuntime`

That is a smaller contradiction than the earlier ones, but it is now the most
obvious remaining one.

## Bottom Line

The next honest War 3 question is whether the public root should start
exporting `TerminalSession` directly, while keeping `PtyTerminalRuntime` only as
compatibility residue during the transition.

Status note, later on 2026-04-02:

- the public root now exports
  [TerminalSession](/home/home/personal/zide/src/terminal/core/terminal_runtime.zig)
  directly
- `PtyTerminalRuntime` remains only as a compatibility alias
- that makes the live terminal root read much closer to the actual owning type
  and materially reduces the last obvious naming contradiction in War 3

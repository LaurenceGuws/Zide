# VT Session Removal Design

Date: 2026-04-02

## Purpose

Define the concrete end-state required to delete
[TerminalSession](/home/home/personal/zide/src/terminal/core/session/terminal_session.zig)
instead of merely shrinking it further.

This is the next `vt-sprint` authority after the immutable-export and
mutable-host cleanup waves.

## Current Baseline

After the recent `vt-sprint` cuts:

- immutable terminal content/export is mostly owned by
  [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
- public callers no longer use `PtyTerminalRuntime`
- mutable selection/viewport semantics no longer route through
  `TerminalSession`
- snapshot export is no longer on `TerminalSession`

What remains on
[terminal_session.zig](/home/home/personal/zide/src/terminal/core/session/terminal_session.zig)
is now narrow:

- init
- lock / tryLock / unlock
- PTY writer access

That means `TerminalSession` is no longer blocked by helper residue.
It is blocked by object-model shape.

## Target Shape

The target is no longer ambiguous:

- [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  is the VT library object
- runtime / transport / locking live outside it as a true outer shell
- publication remains an export boundary around core truth
- `TerminalSession` disappears entirely

In other words, the end-state should read like:

- `TerminalCore` is "the terminal"
- a runtime host/shell owns transport threads, writer access, and locking
- hosts do not need a second terminal object to use the engine

That is closer to the first-glance story in Ghostty and WezTerm than the
current "real engine plus real public object" split.

## What Still Forces `TerminalSession` To Exist

Today `TerminalSession` still bundles three things that have not been given a
replacement shape:

1. Construction as one heap object
- callers instantiate `TerminalSession`, not `TerminalCore`
- runtime/session allocation and storage layout still assume one aggregate
  object that embeds core plus outer shell state

2. Lock ownership around the engine
- callers lock `TerminalSession` before they touch terminal state
- the lock lives in outer session/control state, not on `TerminalCore`
- no explicit non-terminal owner currently advertises "I am the synchronized
  runtime shell around this core"

3. Transport/writer access
- PTY writer access is still exposed through `TerminalSession`
- that makes `TerminalSession` look like the necessary live terminal object
  for host mutation even after content/mutation cleanup

Those are not helper methods.
Those are the remaining reasons the object exists.

## What Must Replace It

If `TerminalSession` is to disappear cleanly, the replacement shape should be:

1. `TerminalCore` construction is first-class
- hosts can create a `TerminalCore` directly
- any runtime/session wrapper should be optional and explicit

2. Runtime shell is named as runtime shell
- transport, poll, child-exit, writer access, and synchronization should live
  on a type whose identity is obviously outer-shell/runtime
- that type should not look like "the terminal"

3. Lock ownership is attached to the outer shell, not a fake second terminal
- if native/FFI hosts need synchronized access, they should lock the runtime
  shell around a `TerminalCore`
- they should not have to instantiate a separate object that still reads like
  the real terminal API surface

## Strongest Replacement Direction

From the current baseline, the strongest direction is:

- keep [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  as the only VT object
- introduce or elevate a clearly named outer runtime/transport owner for:
  - allocation wrapper
  - locking
  - PTY writer access
  - transport lifecycle
- move callers that genuinely need runtime shell behavior onto that outer owner
- stop letting the runtime shell masquerade as the terminal object

That would make the code read more like:

- `TerminalCore`
- `TerminalRuntime` or equivalent shell around it

Not:

- `TerminalCore` inside `TerminalSession`

## What Not To Do

Do not:

- keep shrinking `TerminalSession` and call that success
- move locks onto `TerminalCore` just to avoid naming the shell
- invent another compatibility alias that preserves the same ambiguity
- keep using `TerminalSession` as the public VT identity once the real target is
  `TerminalCore`

## First Real Design Questions

The next code wave should answer these explicitly before it starts:

1. What is the real outer-shell type name once `TerminalSession` is gone?
2. Should `TerminalCore` remain stack/value-initializable while the outer shell
   stays heap-owned?
3. Which current `TerminalSession` callers truly need runtime shell behavior,
   and which should move all the way to `TerminalCore`?

## Bottom Line

`TerminalSession` is now small enough that deleting it is no longer a local
cleanup problem.

The remaining work is to separate:

- terminal object identity
from
- runtime shell identity

The sprint should now measure progress by one bar only:

- does this make deleting `TerminalSession` more plausible?

## Progress Note, Later On 2026-04-02

The first identity step is now landed:

- the outer shell is now explicitly named
  [TerminalRuntimeShell](/home/home/personal/zide/src/terminal/core/session/terminal_runtime_shell.zig)
- the VT root exports that shell directly
- live app/UI/workspace/replay/FFI callers now use `TerminalRuntimeShell`
  instead of `TerminalSession`
- [terminal_session.zig](/home/home/personal/zide/src/terminal/core/session/terminal_session.zig)
  is now just a compatibility alias

That is the right direction because it changes the live story from:

- "the public terminal object is `TerminalSession`"

to:

- "`TerminalCore` is the terminal, `TerminalRuntimeShell` is the outer shell"

The next blocker is no longer naming.
It is whether construction, locking, and PTY writer access can be surfaced
through that shell without preserving `TerminalSession` as a meaningful type.

## Progress Note, Later On 2026-04-02 Again

That cut is now landed too:

- [terminal_session.zig](/home/home/personal/zide/src/terminal/core/session/terminal_session.zig)
  is deleted
- the VT root no longer exports `TerminalSession`
- `src/` no longer contains live `TerminalSession` references
- app/UI/workspace/replay/FFI/tests now use
  [TerminalRuntimeShell](/home/home/personal/zide/src/terminal/core/session/terminal_runtime_shell.zig)

So the sprint bar is now materially crossed:

- `TerminalSession` is no longer blocking the live codebase

What remains is narrower:

- how quickly contributor-facing docs and older authority docs should be
  rewritten around `TerminalRuntimeShell`
- whether the next plug-and-play blocker is now `TerminalCore` sufficiency or
  the outer runtime-shell contract

# VT Post Shell Cleanup Rerank

Date: 2026-04-03

## Purpose

Rerank VT maturity after the shell-hostile fronts that were clearly real:

- constructor identity
- FFI handle identity
- read-side lock gravity
- mutation transaction lock gravity

The question is:

- what still most directly keeps Zide behind Ghostty/WezTerm on VT maturity
  now?

## What Is No Longer The Main Problem

These shell fronts are materially flatter now:

### 1. Constructor identity

- the shell no longer constructs itself
- root VT construction now lives on
  [terminal_runtime.zig](/home/home/personal/zide/src/terminal/core/terminal_runtime.zig)

### 2. FFI handle identity

- the ABI remains terminal-named and opaque
- the FFI internals now explicitly store a `shell`, not a vague `session`

### 3. Broad host-visible lock gravity

- read-side shell locking is no longer the default host/UI pattern
- the big mutation transaction patterns are no longer widget/app-owned shell
  locks

These were real contradictions and were worth attacking.

They are no longer the strongest remaining reason Zide loses first-glance
maturity.

## Current Remaining Shell Surface

[terminal_runtime_shell.zig](/home/home/personal/zide/src/terminal/core/session/terminal_runtime_shell.zig)
is now visibly small again:

- `deinit`
- `lock`
- `tryLock`
- `unlock`
- `lockPtyWriter`
- `writePtyBytes`
- `emitProtocolReplyBytes`

That means the shell question is narrower now:

- are these surviving responsibilities irreducible runtime boundary?

## Current Judgment

### Shell survival

The most defensible shell buckets remain:

- transport / writer access
- lifecycle / teardown

The most suspicious surviving shell bucket is now:

- runtime-dependent reporting and reply emission

But even that is no longer obviously stronger than the broader
`TerminalCore` maturity question.

### Strongest overall VT pressure

The top pressure returns to category 1:

- [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  sufficiency and protocol-execution maturity

Why:

- major shell-first teaching paths are materially reduced
- the shell is now closer to something that could plausibly survive hostile
  scrutiny
- if Zide still loses first glance to Ghostty/WezTerm, it is less because the
  shell is too loud and more because the core still may not feel finished
  enough as the terminal object

## Fallback Shell Pressure

If the shell front reopens, the next honest target is not generic shell
cleanup.

It is:

- transport/reporting survival

Meaning:

- can runtime-dependent reporting and reply emission stay shell-owned without
  making protocol execution feel second-rate?

## Decision

The default active front should no longer be "shell cleanup continued."

It should be:

- broader `TerminalCore` sufficiency and protocol-execution maturity

Shell should only stay active if a fresh contradiction proves the surviving
transport/reporting boundary is still taking real ground away from the core.

## Bottom Line

The shell is no longer the obvious enemy.

If Zide still loses on VT maturity now, the next honest explanation is more
likely:

- the core still does not feel complete enough

not:

- the shell is still too visibly in charge

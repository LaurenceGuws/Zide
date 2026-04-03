# VT Shell Hostile Audit

Date: 2026-04-03

## Purpose

Apply the new wartime standard to the surviving
[TerminalRuntimeShell](/home/home/personal/zide/src/terminal/core/session/terminal_runtime_shell.zig).

The question is not:

- is the shell smaller than before?

The question is:

- does each remaining shell responsibility still deserve to exist at all?

## Current Live Shell Surface

Visible root surface:

- [terminal_runtime_shell.zig](/home/home/personal/zide/src/terminal/core/session/terminal_runtime_shell.zig)
  - `init`
  - `initWithOptions`
  - `deinit`
  - `lock`
  - `tryLock`
  - `unlock`
  - `lockPtyWriter`
  - `writePtyBytes`
  - `emitProtocolReplyBytes`

Broader runtime surface still exposed through:

- [runtime.zig](/home/home/personal/zide/src/terminal/core/session/runtime.zig)
  - transport attach/detach
  - process start
  - polling/lifecycle
  - resize with transport-side reporting
  - external outgoing byte capture

## Surviving Responsibility Buckets

### 1. Synchronization

Examples:

- `lock`
- `tryLock`
- `unlock`
- direct `state_mutex` use in core/session helpers and widget/FFI call sites

Current judgment:

- still plausibly irreducible
- but only if the terminal object itself is not expected to internalize
  concurrency policy

Risk:

- easy place for old shell identity to hide, because many call sites still
  experience “session lock + core access” as the normal pattern

### 2. Transport / writer access

Examples:

- `lockPtyWriter`
- `writePtyBytes`
- PTY / external transport attach/detach
- outgoing-byte capture for replay/FFI/testing

Current judgment:

- strongest surviving case for a shell/runtime boundary
- this is the least suspicious shell bucket right now

Risk:

- protocol execution can still feel shell-anchored when reply/report paths
  terminate directly on writer access

### 3. Lifecycle / process ownership

Examples:

- `init`
- `deinit`
- `start`
- `poll`
- child-exit tracking
- thread lifecycle

Current judgment:

- also plausibly irreducible
- but constructor and teardown identity still influence whether hosts feel like
  they are creating “a terminal” or “a shell object with a terminal inside”

Risk:

- object identity can still leak shell-first even if responsibilities are real

### 4. Runtime-dependent reporting

Examples:

- `emitProtocolReplyBytes`
- in-band resize `2048` reporting
- color-scheme reporting `2031`
- kitty paste reporting `5522`

Current judgment:

- real boundary category, but not yet cleanly normalized
- this is the most suspicious surviving shell bucket after transport/lifecycle

Risk:

- these paths can still make protocol execution feel shell-owned rather than
  terminal-owned with explicit reporting consequences

## Immediate Conclusions

### What looks most defensible

1. transport/writer access
2. process/thread lifecycle

### What looks most suspicious

1. runtime-dependent reporting
2. shell-first constructor/object identity feel
3. lock ownership as a pervasive host habit rather than a clearly bounded
   runtime concern

## Ranked Next Questions

### 1. Reporting boundary

Question:

- should reporting paths like `2031`, `2048`, and `5522` stay as shell-owned
  consequences, or do they still obscure a more mature terminal contract?

Why it ranks first:

- it directly weakens protocol-execution maturity
- it is still active in the current CSI front

### 2. Constructor/object identity

Question:

- does the creation story still teach hosts to think in shell-first terms?

Why it ranks second:

- it directly affects library-object feel
- but it is less immediate than the active reporting boundary

### 3. Locking model

Question:

- is explicit host-side lock choreography still the right mature shape, or
  is it preserving too much shell gravity around `TerminalCore`?

Why it ranks third:

- important
- but dangerous to change without a much clearer concurrency design answer

## Bottom Line

The shell is no longer treated as legitimate by default.

From this hostile audit:

- transport and lifecycle still look most defensible
- reporting is now the strongest suspicious surviving shell frontier
- object identity and lock choreography remain under active suspicion

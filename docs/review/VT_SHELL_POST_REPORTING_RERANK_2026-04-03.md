# VT Shell Post Reporting Rerank

Date: 2026-04-03

## Purpose

Rerank the shell-hostile fronts after the reporting bucket moved under one
explicit owner.

The question is:

- what remaining shell contradiction now most directly weakens VT maturity
  purity?

## What Improved

The first suspicious shell bucket is no longer smeared across multiple files.

Now grouped under one owner:

- [host_reporting.zig](/home/home/personal/zide/src/terminal/core/session/host_reporting.zig)

That means:

- `2031`
- `2048`
- `5522`

no longer survive as scattered shell residue in CSI, input, transport, and
interaction helpers.

## What This Changes

Reporting is still a real shell/runtime boundary category, but it is much less
architecturally embarrassing now.

It no longer looks like the single strongest reason the shell still feels too
present.

## What Rises Next

### 1. Constructor / object identity

This is now the strongest remaining shell contradiction.

Why:

- the public root still exports
  [TerminalRuntimeShell](/home/home/personal/zide/src/terminal/core/terminal_runtime.zig)
  as the active host-facing object beside
  [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_runtime.zig)
- creation still teaches hosts to allocate a shell object with a terminal
  inside it:
  - [terminal_runtime_shell.zig](/home/home/personal/zide/src/terminal/core/session/terminal_runtime_shell.zig)
  - [runtime_init.zig](/home/home/personal/zide/src/terminal/core/session/runtime_init.zig)
  - [core_api.zig](/home/home/personal/zide/src/terminal/ffi/core_api.zig)

Why it matters:

- even if the responsibilities are real, object identity still influences
  whether the library feels terminal-centered or shell-first

### 2. Lock choreography

This stays second.

Why:

- explicit `session.lock()` plus `session.core` access is still normal in many
  callers
- but changing concurrency shape is riskier and less obviously ready than the
  constructor/identity question

### 3. Transport / lifecycle

These remain the most defensible shell buckets.

Current read:

- still suspicious in principle
- not the next default attack target from this baseline

## Decision

The next shell-hostile front should be:

- constructor / object identity

Not:

- more reporting work by symmetry
- transport/lifecycle dismantling by momentum

## Bottom Line

After reporting cleanup, the shell’s biggest remaining architectural cost is
now the story it teaches about what the terminal object actually is.

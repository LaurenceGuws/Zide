# VT War 4 Handle Decision

Date: 2026-04-03

## Purpose

Decide whether shell-centered handle storage/creation is truly the strongest
remaining `zide-vt` contradiction, or whether that suspicion weakens once the
actual public ABI is examined.

## Public Surface Check

The exported host contract is already terminal-named and opaque:

- [bridge.zig](/home/home/personal/zide/src/terminal/ffi/bridge.zig)
  exports `ZideTerminalHandle`
- [c_api.zig](/home/home/personal/zide/src/terminal/ffi/c_api.zig)
  exports `zide_terminal_*`

The public consumer does **not** see:

- `TerminalRuntimeShell`
- `session`
- any shell-specific type name

So the strongest version of the earlier suspicion does not fully survive a
public-ABI check.

## What Is Actually Shell-Centered

The shell-centered part is internal:

- [shared.zig](/home/home/personal/zide/src/terminal/ffi/shared.zig)
  stores `session: *TerminalRuntimeShell`
- [core_api.zig](/home/home/personal/zide/src/terminal/ffi/core_api.zig)
  constructs [TerminalRuntimeShell](/home/home/personal/zide/src/terminal/core/session/terminal_runtime_shell.zig)
  and immediately attaches external transport

That still matters for internal contract feel, but it is not the same thing as
the public API literally teaching hosts "you are holding a shell object."

## Re-evaluated Judgment

The handle/constructor issue is real, but weaker than the first synthesis made
it sound.

Why:

- the handle is opaque
- the exported nouns are terminal-centered
- a host-facing instance really does need runtime concerns:
  synchronization, transport, lifecycle, publication, and present ack

This means a shell-backed opaque handle may simply be an honest implementation
detail rather than the last major plug-and-play blocker.

## Stronger Remaining Pressure

After that correction, the stronger remaining War 4 pressure is now:

- host-to-terminal interaction semantics still feel more shell-owned than
  terminal-owned

Evidence:

- [terminal_core_feed.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_feed.zig)
  still treats output application as a shell-shaped helper over core/parser
- [session/input.zig](/home/home/personal/zide/src/terminal/core/session/input.zig)
  still owns the live host interaction verbs:
  key, text, mouse, focus, color-scheme, and PTY write path
- [session/runtime.zig](/home/home/personal/zide/src/terminal/core/session/runtime.zig)
  still owns resize/feed/runtime entrypoint shape above the core

This matches the WezTerm pressure more directly:

- the terminal object there feels sufficient because live terminal-driving
  semantics terminate on it more obviously

## Decision

Do **not** open the next code war on handle storage shape alone.

Why:

- changing internal opaque-handle storage would risk cosmetic surgery
- it could create a worse fake aggregate with no real contract win

Instead:

- accept the current opaque handle as provisionally honest
- move War 4's active target to the host-to-terminal interaction slab

## Bottom Line

The handle/constructor suspicion was useful because it forced a public-contract
check.

That check changes the ranking:

1. handle identity is not the main live blocker
2. the stronger remaining blocker is that terminal-driving interaction still
   feels more shell-owned than terminal-owned

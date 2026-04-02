# VT War 4 Handle Identity Review

Date: 2026-04-03

## Purpose

Evaluate the strongest remaining War 4 contradiction:

- the public host handle and constructor story is still shell-centered

This review is not about shrinking
[TerminalRuntimeShell](/home/home/personal/zide/src/terminal/core/session/terminal_runtime_shell.zig).
It is about deciding whether the public `zide-vt` entrypoint should continue
to make the shell the universal object of record.

## Live Evidence

### The FFI handle is shell-owned

- [shared.zig](/home/home/personal/zide/src/terminal/ffi/shared.zig)
  stores:
  - `session: *TerminalRuntimeShell`

That means the opaque host handle fundamentally points at the shell-centered
object, not at an engine-centered contract.

### Construction is shell-first

- [core_api.zig](/home/home/personal/zide/src/terminal/ffi/core_api.zig)
  creates [TerminalRuntimeShell](/home/home/personal/zide/src/terminal/core/session/terminal_runtime_shell.zig)
  directly in `create(...)`
- it immediately attaches external transport after construction

So the public story is still:

1. create shell
2. attach transport
3. keep opaque shell handle
4. drive both engine and host operations through that handle

### The bridge preserves that identity

- [bridge.zig](/home/home/personal/zide/src/terminal/ffi/bridge.zig)
  exports one `ZideTerminalHandle`
- both `core_api` and `host_api` route through that same shell-centered handle

## Why This Still Matters

The architecture is much cleaner now:

- `TerminalSession` is gone
- `PtyTerminalRuntime` is gone
- [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  owns materially more real truth
- [TerminalRuntimeShell](/home/home/personal/zide/src/terminal/core/session/terminal_runtime_shell.zig)
  is mostly honest

But the host still learns the wrong first-glance story:

- the thing you instantiate and hold is the shell
- the engine is stronger, but still one layer behind the universal public
  handle

That weakens plug-and-play optics more than the remaining local code shape
does.

## Comparison Pressure

### Ghostty

Ghostty still wins the cleaner first-glance library story because the engine
object feels like the terminal, while the outer runtime is secondary.

Even though `libghostty-vt` keeps a narrow public umbrella, the structural
message is still:

- terminal object first
- runtime shell second

### WezTerm

WezTerm pressures the same issue from the opposite end:

- the terminal object feels sufficient enough that runtime surroundings do not
  compete for identity

That makes Zide's remaining mismatch look less like "missing capabilities" and
more like "wrong public entrypoint feel."

## Options

### Option 1: accept shell-centered public handle as the right boundary

Argument:

- the host really does need synchronization, transport, lifecycle, and
  publication interaction
- an opaque shell-centered handle may simply be the honest host boundary

Risk:

- `TerminalCore` becomes the engine in substance but not in public feel
- `zide-vt` remains less obviously swappable than Ghostty/WezTerm at first
  glance

### Option 2: make the public contract more engine-centered while keeping the shell behind it

Argument:

- the host could still hold one public handle, but that handle no longer needs
  to be narrated and stored as "the shell"
- the shell can remain real behind a more engine-centered contract surface

Potential forms:

- handle stores a more neutral aggregate instead of `session: *TerminalRuntimeShell`
- constructor/export wording shifts from "make shell, attach transport" toward
  "make terminal, then configure runtime transport"
- split public handle ownership between core-facing and host-runtime-facing
  contracts only if that does not invent a new fake center

Risk:

- an attempted redesign could create a worse synthetic center if it is only
  cosmetic

## Current Judgment

This is the strongest remaining War 4 target.

Not because the shell is still dishonest internally.
Because the public handle and constructor story still makes the shell the
universal host identity anchor.

## Decision Bar

Only open code cuts here if we can improve the public story to read more like:

- terminal-centered library contract
- runtime shell behind it

without:

- inventing a third object
- widening the public ABI for its own sake
- moving real runtime concerns onto
  [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  just to make it look bigger

## Bottom Line

War 4 now has a concrete opening target:

- handle and constructor identity

If this target proves real under another focused pass, it should beat
`host_queries` cleanup and other local shell cuts.

# VT War 4 Initial Findings

Date: 2026-04-03

## Purpose

Record the first ranked findings from the master scan before the parallel
cross-reference tracks are fully synthesized.

This is not the final War 4 verdict.
It is the current main-agent read from the live code.

## Findings

### 1. The strongest remaining plug-and-play mismatch is shell-anchored instantiation, not file sprawl

The clearest remaining mismatch is that the public host contract still begins
from a shell-owned opaque handle rather than from a more obviously
engine-centered object.

Evidence:

- [shared.zig](/home/home/personal/zide/src/terminal/ffi/shared.zig)
  stores the FFI handle around `session: *TerminalRuntimeShell` at
  [shared.zig:318](/home/home/personal/zide/src/terminal/ffi/shared.zig#L318)
- [core_api.zig](/home/home/personal/zide/src/terminal/ffi/core_api.zig)
  `create(...)` instantiates
  [TerminalRuntimeShell](/home/home/personal/zide/src/terminal/core/session/terminal_runtime_shell.zig)
  directly at
  [core_api.zig:339](/home/home/personal/zide/src/terminal/ffi/core_api.zig#L339)
  and immediately attaches external transport at
  [core_api.zig:384](/home/home/personal/zide/src/terminal/ffi/core_api.zig#L384)
- most FFI entrypoints dispatch through `h.session`, not through a clearer
  split between engine-only and shell-only handles:
  - [host_api.zig:10](/home/home/personal/zide/src/terminal/ffi/host_api.zig#L10)
  - [host_api.zig:17](/home/home/personal/zide/src/terminal/ffi/host_api.zig#L17)
  - [core_api.zig:396](/home/home/personal/zide/src/terminal/ffi/core_api.zig#L396)

Why this matters:

- `TerminalSession` is gone
- `PtyTerminalRuntime` is gone
- but the host still learns "the thing I create and hold is the shell"
- that keeps [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  from feeling like the boring center of the library contract

This is a stronger remaining contradiction than any local helper residue.

### 2. `host_queries.zig` now reads mostly like honest mixed runtime aggregation, not a fake center

The current [host_queries.zig](/home/home/personal/zide/src/terminal/core/session/host_queries.zig)
surface no longer looks like the main contradiction.

Evidence:

- `copyMetadata(...)` combines core-owned metadata state with transport
  liveness and exit status:
  [host_queries.zig:15](/home/home/personal/zide/src/terminal/core/session/host_queries.zig#L15)
- `currentActivityMetadata(...)` combines core-owned semantic/progress truth
  with foreground-process/runtime aggregation:
  [host_queries.zig:45](/home/home/personal/zide/src/terminal/core/session/host_queries.zig#L45)
- `displayTitleText(...)` still overlays transport foreground-process labeling
  over core title text:
  [host_queries.zig:38](/home/home/personal/zide/src/terminal/core/session/host_queries.zig#L38)

Current read:

- this file still mixes core truth with runtime truth
- but that now looks mostly legitimate
- it should not be shaved smaller by momentum unless a reference comparison
  proves one specific packaging decision is still wrong

### 3. Zide's host contract is broader than Ghostty's `vt.h`, but that is not automatically the remaining architecture problem

Ghostty’s public C umbrella is intentionally narrow:

- [vt.h](/home/home/personal/zide/dev_references/terminals/ghostty/include/ghostty/vt.h)

Zide’s host bridge is much broader:

- [bridge.zig](/home/home/personal/zide/src/terminal/ffi/bridge.zig)
- [c_api.zig](/home/home/personal/zide/src/terminal/ffi/c_api.zig)
- snapshots, diffs, metadata, redraw state, events, pending input, present ack,
  host input, viewport control, and child-exit reporting all live there

This makes `zide-vt` less normalized than `libghostty-vt` at first glance.

But current read:

- that breadth matches Zide’s embeddable-host ambition
- the problem is not merely "too many exported functions"
- the problem is whether the broad host contract is still anchored around the
  shell as the universal object of record

So contract breadth is a pressure point, but not yet the strongest finding.

### 4. The current shell itself looks narrow enough to be defensible

The live shell shape is small and specific:

- [terminal_runtime_shell.zig:10](/home/home/personal/zide/src/terminal/core/session/terminal_runtime_shell.zig#L10)

It owns:

- init
- deinit
- locking
- PTY-writer access

That is much closer to a legitimate outer shell than the older
`TerminalSession`/`PtyTerminalRuntime` story.

Current read:

- the shell no longer looks like the main fake center
- the remaining risk is that the rest of the host contract still makes it the
  unavoidable identity anchor

## Preliminary Ranking

1. strongest remaining contradiction:
   shell-anchored host instantiation and opaque-handle identity
2. secondary pressure:
   broad-but-Zide-shaped FFI/public contract normalization
3. likely not the next default target:
   `host_queries.zig` micro-shaving
4. likely not the next default target:
   `TerminalRuntimeShell` local slimming

## Best Next Question

The next comparison should test one thing directly:

- does a serious swappable `zide-vt` need a more engine-centered public handle
  or constructor shape, even if the shell remains real and necessary behind it?

That is now a stronger question than:

- "can we move one more query off the shell?"

## Bottom Line

The strongest remaining mismatch does not look like another small ownership
cleanup.

It looks like a contract-identity problem:

- `TerminalCore` is stronger now
- `TerminalRuntimeShell` is honest now
- but the host still appears to enter the library through the shell, not
  through a clearly engine-centered contract story

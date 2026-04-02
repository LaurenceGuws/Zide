# VT War 4 Synthesis

Date: 2026-04-03

## Purpose

Collapse the first War 4 scrutiny wave into one ranked decision.

This is the point where the scan stops being "compare everything" and starts
naming the single strongest remaining plug-and-play contradiction in the live
`zide-vt` shape.

## Inputs Synthesized

- [VT_WAR_4_SCOPE_AND_SEEDS_2026-04-03.md](/home/home/personal/zide/docs/review/VT_WAR_4_SCOPE_AND_SEEDS_2026-04-03.md)
- [VT_WAR_4_INITIAL_FINDINGS_2026-04-03.md](/home/home/personal/zide/docs/review/VT_WAR_4_INITIAL_FINDINGS_2026-04-03.md)
- [VT_WAR_4_CALLER_DEPENDENCE_REVIEW_2026-04-03.md](/home/home/personal/zide/docs/review/VT_WAR_4_CALLER_DEPENDENCE_REVIEW_2026-04-03.md)
- [VT_CORE_CONTRACT_COMPARISON_2026-04-02.md](/home/home/personal/zide/docs/review/VT_CORE_CONTRACT_COMPARISON_2026-04-02.md)
- [VT_CORE_SUFFICIENCY_REVIEW_2026-04-02.md](/home/home/personal/zide/docs/review/VT_CORE_SUFFICIENCY_REVIEW_2026-04-02.md)
- [Ghostty Terminal.zig](/home/home/personal/zide/dev_references/terminals/ghostty/src/terminal/Terminal.zig)
- [Ghostty vt.h](/home/home/personal/zide/dev_references/terminals/ghostty/include/ghostty/vt.h)
- [WezTerm terminal.rs](/home/home/personal/zide/dev_references/terminals/wezterm/term/src/terminal.rs)

## What Is No Longer The War

The following no longer read like the main contradiction:

- [TerminalRuntimeShell](/home/home/personal/zide/src/terminal/core/session/terminal_runtime_shell.zig)
  file size or local ownership
- broad in-repo shell use in widget/workspace/app code
- another immutable query/export migration onto
  [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
- `host_queries.zig` micro-shaving for its own sake

Current read:

- the shell now looks mostly honest
- most remaining shell use looks legitimate:
  synchronization, transport, liveness, lifecycle, or runtime aggregation
- the easy `TerminalCore` sufficiency wins are already landed

## Ranked Findings

### 1. Strongest remaining contradiction: shell-centered host handle and constructor identity

This is the clearest remaining plug-and-play mismatch.

Evidence:

- [shared.zig](/home/home/personal/zide/src/terminal/ffi/shared.zig)
  stores the FFI handle around `session: *TerminalRuntimeShell`
- [core_api.zig](/home/home/personal/zide/src/terminal/ffi/core_api.zig)
  constructs [TerminalRuntimeShell](/home/home/personal/zide/src/terminal/core/session/terminal_runtime_shell.zig)
  directly and immediately attaches external transport
- the public host story still begins from:
  - create shell
  - hold shell-centered opaque handle
  - dispatch everything through that handle

Why this matters:

- `TerminalSession` is gone
- `PtyTerminalRuntime` is gone
- but the host still learns that the thing it "has" is the shell
- that leaves [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  stronger in substance than in contract identity

### 2. Second real pressure: host-to-terminal interaction semantics still feel more shell-owned than terminal-owned

This is the strongest comparison pressure from WezTerm.

Evidence:

- output application still routes through
  [terminal_core_feed.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_feed.zig)
  as a shell-shaped helper
- input/reporting/writer paths still live under session runtime/input modules:
  - [session/input.zig](/home/home/personal/zide/src/terminal/core/session/input.zig)
  - [session/runtime.zig](/home/home/personal/zide/src/terminal/core/session/runtime.zig)

Current read:

- this is a real design pressure
- but it is still less immediate than the shell-centered public-handle story
- if War 4 opens into code, this is the strongest fallback target after
  handle/constructor identity

### 3. `host_queries.zig` is now mostly an honest mixed boundary

Evidence:

- it mixes core metadata/activity truth with transport liveness, exit state,
  foreground-process labeling, and related runtime aggregation

Current read:

- this is no longer the main fake center
- it should only be reopened if a more specific contract redesign requires it

### 4. Contract breadth is a pressure point, not yet the main contradiction

Zide's host bridge is much broader than Ghostty's narrow
[vt.h](/home/home/personal/zide/dev_references/terminals/ghostty/include/ghostty/vt.h).

Current read:

- that breadth matches Zide's embeddable-host ambition
- the stronger problem is not "too many functions"
- the stronger problem is that the broad host contract is still anchored around
  the shell as the universal public object

## War 4 Decision

War 4 should now be treated as a focused contract-identity war.

The opening question is no longer:

- "what helper or query should move next?"

It is:

- should the public host handle and constructor story become more
  engine-centered, or is the current shell-centered entrypoint already the
  right long-term `zide-vt` boundary?

## Best Next Move

Open the next review/cut on one explicit target:

- FFI handle and constructor identity

The next code move should only happen if it can make the public host-facing
story read more like:

- engine-centered contract
- outer runtime shell behind it

without inventing another fake center.

## Bottom Line

War 4 has now named one real remaining contradiction.

The live `zide-vt` gap is no longer wrapper sludge or local shell gravity.
It is that the host still appears to enter the library through the shell,
while the engine increasingly owns the interesting truth.

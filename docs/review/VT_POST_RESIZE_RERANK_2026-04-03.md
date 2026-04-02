# VT Post-Resize Rerank

Date: 2026-04-03

## Purpose

Record the plug-and-play rerank after the public-resize contract was unified.

The question is:

- what now most directly blocks credible `zide-vt` versus `libghostty-vt`
  pressure from the current live baseline?

## What Just Improved

The public resize story is materially better now:

- hosts no longer teach resize as two separate public steps
- FFI and native paths now use one host-facing resize contract
- in-band resize reporting now uses current cell metrics through that same
  unified path

That means the old resize parity gap no longer deserves default-war status.

## What This Did Not Solve

The resize win did not expose another automatic code move of the same class.

After the live scan:

- `session/input.zig` remains paused because the remaining surface is mostly
  writer/reporting-shaped
- `host_queries.zig` remains paused because it is now mostly honest mixed
  runtime aggregation
- the shell itself remains narrow and honest

So the next blocker is not another easy shell/path cleanup.

## New Ranked Gap List

### 1. `TerminalCore` sufficiency remains the top blocker

Current read:

- the remaining difference versus Ghostty and WezTerm is less about
  mislocated helper slabs
- it is more about whether
  [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  feels fully sufficient enough as the terminal object beneath
  [TerminalRuntimeShell](/home/home/personal/zide/src/terminal/core/session/terminal_runtime_shell.zig)

Why this stays first:

- the obvious local contradictions are now mostly gone
- what remains is more about object completeness and contract feel than
  extraction residue

### 2. Viewport and selection mutation surface is now the clearest concrete fallback

Current read:

- mutation truth is already mostly core-owned
- but many live callers still route through:
  - [content.zig](/home/home/personal/zide/src/terminal/core/session/content.zig)
  - [selection.zig](/home/home/personal/zide/src/terminal/core/session/selection.zig)
- this still weakens the clean story that hosts obviously drive the terminal
  object

Why this is second:

- unlike the broader sufficiency question, this is still concrete enough to
  become a code war if we need one
- but it no longer clearly outranks the broader object-sufficiency pressure

### 3. Host metadata packaging stays paused

Current read:

- [host_queries.zig](/home/home/personal/zide/src/terminal/core/session/host_queries.zig)
  is still mixed, but now mostly honestly so

Why this stays low:

- reopening it now would likely be churn

### 4. ABI normalization still stays low

Current read:

- the FFI boundary is still broader than Ghostty’s
- but breadth alone is still not the main remaining blocker

## Current Judgment

The next VT move should not be:

- another shell-thinning pass
- another input continuation
- another `host_queries` shave

The next VT move should be one of two things:

1. a named `TerminalCore` sufficiency war with one crisp missing capability
2. if that capability cannot be named, a more concrete viewport/selection
   mutation war

## Bottom Line

After the resize wave:

- public resize is materially healthier
- `TerminalCore` sufficiency is still the top blocker
- viewport/selection mutation surface is now the clearest concrete fallback
- if no named sufficiency slab emerges, that fallback should likely become the
  next real code war

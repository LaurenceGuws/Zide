# VT Post-Input Rerank

Date: 2026-04-03

## Purpose

Record the plug-and-play rerank after the input-semantics war landed its clean
semantic slices and hit its honest stop-marker.

The question is:

- what now most directly blocks credible `zide-vt` versus `libghostty-vt`
  plug-and-play pressure?

## What Just Improved

The input-semantics war landed real terminal-owned slices on
[TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig):

- key action dispatch
- keypad action dispatch
- alternate-scroll mapping
- char action dispatch

That matters because the old top blocker was not vague "input mess."
It was the more precise problem that host-driving input semantics still felt
too shell-centered.

That specific pressure is now materially lower.

## What Did Not Turn Into A Clean Continuation

The remaining
[session/input.zig](/home/home/personal/zide/src/terminal/core/session/input.zig)
surface is now mostly:

- direct writer verbs
- reporting verbs
- or explicit shell/runtime mechanics

Specifically:

- `sendText(...)`
- `sendBytes(...)`
- `reportMouseEvent(...)`
- `reportFocusChanged(...)`
- `reportColorSchemeChanged(...)`

do not currently read like the same class of terminal-semantic ownership lie.

So the input war should stay closed from this baseline.

## New Ranked Gap List

### 1. `TerminalCore` sufficiency is now the top blocker again

Current read:

- the shell is narrow and honest
- obvious semantic interaction now reaches core more directly
- the remaining question is no longer whether shell code is too large
- the remaining question is whether
  [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  feels fully sufficient enough, at first glance, to be the library object
  under a thin runtime shell

Why this is now first:

- Ghostty and WezTerm still feel more self-sufficient at the terminal object
  center
- the next remaining gap is more about contract feel and object completeness
  than about another obvious misplaced helper slab

### 2. Public resize still reads shell-first in feel

Current read:

- the semantic resize cut was real
- but the public entrypoint story still feels more shell-first than
  terminal-first

Why it stays second:

- this is still a real parity gap
- but it is weaker than the broader object-sufficiency question

### 3. Viewport and selection mutation still read slightly shell-surfaced

Current read:

- mutation truth is mostly core-owned now
- some host-facing mutation still commonly routes through session-layer modules

Why it stays third:

- it weakens the clean "drive the terminal object" story
- but it is now clearly second-order

### 4. Host metadata packaging stays paused

Current read:

- [host_queries.zig](/home/home/personal/zide/src/terminal/core/session/host_queries.zig)
  is now mostly honest mixed runtime aggregation

Why it stays low:

- this is now more guardrail than war target

### 5. Public ABI normalization still differs from Ghostty

Current read:

- Zide still exposes a broader FFI surface than Ghostty
- but breadth alone is not the main remaining blocker

Why it stays low:

- until `TerminalCore` itself feels sufficiently complete, narrowing the ABI
  is not the highest-value pressure

## Current Judgment

The next VT war should not reopen input by inertia.

The strongest remaining plug-and-play blocker is now:

- whether `TerminalCore` feels sufficiently complete and terminal-owned beneath
  `TerminalRuntimeShell`

That is a design-quality question first, not an automatic extraction queue.

## Best Next Move

Open the next VT war only if it can name one specific remaining
`TerminalCore` sufficiency gap.

Not:

- "make core bigger"
- "shrink the shell more"
- "keep moving helpers"

But:

- identify one concrete capability or host-facing contract that still ought to
  feel terminal-owned
- compare it directly against Ghostty and WezTerm
- cut only if that contradiction is crisp

## Bottom Line

After the input-semantics wave:

- the top blocker is no longer shell-centered input semantics
- the top blocker is now `TerminalCore` sufficiency again
- the next step should be a deeper, named sufficiency war or a clean stop
  marker

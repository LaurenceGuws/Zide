# VT Core Sufficiency Review

Date: 2026-04-02

## Purpose

Evaluate the next plug-and-play blocker after removal of the old public shell
identities.

The question is no longer:

- what is the terminal called?

It is now:

- is [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  sufficiently complete beneath
  [TerminalRuntimeShell](/home/home/personal/zide/src/terminal/core/session/terminal_runtime_shell.zig)
  to read like the real VT library center?

## Current Baseline

Live code now reads as:

- `TerminalCore`
- `TerminalRuntimeShell`

The shell is narrow and honest:

- init
- lock / tryLock / unlock
- PTY writer access

That means the next meaningful pressure is no longer shell naming.

## First Real Sufficiency Signal

The first post-shell cut is now landed:

- immutable clipboard and hyperlink reads no longer route through a dedicated
  shell-query wrapper slab
- [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  now exposes `hyperlinkUri(...)` directly
- FFI and widget callers now follow the cleaner pattern:
  - shell provides synchronization
  - core provides the terminal answer
- the old wrapper slab
  [session/queries.zig](/home/home/personal/zide/src/terminal/core/session/queries.zig)
  is deleted

The next same-class cut is now landed too:

- [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  now packages its own metadata and semantic activity truth via:
  - `metadataState(...)`
  - `activityState(...)`
- [host_queries.zig](/home/home/personal/zide/src/terminal/core/session/host_queries.zig)
  is narrower now:
  - core packages title/cwd/scrollback/semantic-prompt/progress truth
  - shell aggregates transport liveness, exit state, and foreground-process
    data

That is the same correct rule one layer up:

- core packages engine truth
- shell adds only runtime truth

The next narrower same-class cut is now landed too:

- callers that only needed `cwd` no longer route through shell metadata
  packaging
- [workspace_host.zig](/home/home/personal/zide/src/terminal/core/workspace_host.zig)
  and [terminal_widget_open.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_open.zig)
  now lock the shell only for synchronization and read
  [TerminalCore.cwdText(...)](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  directly

That is the same rule at an even smaller scale:

- if the caller only needs one core-owned answer, do not force a shell summary
  object in between

That is the right direction because it makes the shell add only what it truly
owns:

- synchronization

not:

- fake ownership of immutable terminal truth

## What Still Looks Honest On The Shell

These still read like legitimate shell/runtime concerns:

- construction / allocation wrapper
- locking
- PTY writer access
- transport lifecycle and liveness aggregation

Those do not need to be forced onto `TerminalCore` just to make the surface
look smaller.

## What Still Needs Pressure

The next likely sufficiency pressure points are:

1. host metadata packaging that mixes core truth with transport state
2. any remaining immutable or semantic host-facing answer that still routes
   through shell-only wrapper modules
3. whether hosts that only need terminal truth can reach `TerminalCore`
   directly often enough without learning shell-specific habits

## Current Lean

The next plug-and-play blocker is more likely `TerminalCore` sufficiency than
shell excess.

Why:

- the shell is already narrow
- the shell no longer pretends to own immutable query truth
- the remaining gain is making the engine feel fully sufficient beneath the
  shell

## Best Next Move

Keep taking only cuts that satisfy this rule:

- if the answer is immutable terminal truth or semantic engine truth, prefer
  `TerminalCore`
- if the shell adds only synchronization, let callers lock the shell and read
  the core directly
- keep responsibilities on the shell only when they are truly runtime /
  transport responsibilities

## Bottom Line

The sprint is now in the right phase.

The live question is no longer whether there is still a fake public object.
The live question is whether `TerminalCore` is sufficiently complete to make
the shell feel optional in spirit, even where it remains necessary in practice.

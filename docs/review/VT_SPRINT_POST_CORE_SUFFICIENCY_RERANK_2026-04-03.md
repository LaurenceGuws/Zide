# VT Sprint Post-Core-Sufficiency Rerank

Date: 2026-04-03

## Current Read

The `vt-sprint` lane has now landed the meaningful local cuts it needed:

- `TerminalSession` is gone
- `PtyTerminalRuntime` is gone
- immutable core queries no longer hide behind shell query wrappers
- core metadata/activity packaging now lives on
  [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
- callers that only need `cwd` or progress no longer request larger shell
  summaries than they need

That means the easiest "core truth disguised as shell API" cuts are largely
exhausted.

## What The Remaining Shell Looks Like

[TerminalRuntimeShell](/home/home/personal/zide/src/terminal/core/session/terminal_runtime_shell.zig)
now reads mostly as:

- construction / allocation wrapper
- locking
- PTY writer access
- runtime/transport lifecycle

That is not obviously fake gravity anymore.

A serious VT library is allowed to have an outer runtime shell.

## What Still Feels Better In The References

Ghostty and WezTerm still feel slightly stronger at first glance because:

- the engine object feels more fully sufficient on its own
- the runtime shell feels unquestionably secondary

Zide is closer now, but the remaining gap no longer looks like another local
shell-wrapper cleanup.

It looks like one of two things:

1. a deeper `TerminalCore` sufficiency/design question
2. a shell boundary we should now accept as honest

## Current Judgment

The remaining gap is no longer an obvious extraction lane.

The remaining gap is design quality:

- is there one more coherent `TerminalCore` capability slab still missing
- or is the live shape already honest enough that the next improvement would be
  speculative churn

## What Should Not Happen Next

Do not:

- keep shaving `host_queries` because it still exists
- force transport/liveness semantics onto `TerminalCore`
- invent a new cleanup lane just because the sprint has momentum

## Best Next Move

From here, there are only two honest options:

1. open a deliberate deeper `TerminalCore` sufficiency design review against
   Ghostty/WezTerm pressure and identify one specific missing capability slab
2. close `vt-sprint` cleanly and record that the remaining gap is no longer an
   obvious implementation-first contradiction

## Bottom Line

`vt-sprint` is near a real stop-marker.

If we continue, the next move should come from a fresh explicit design
question, not from another small extraction by inertia.

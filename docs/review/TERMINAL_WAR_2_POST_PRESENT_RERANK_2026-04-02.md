# Terminal War 2 Post-Present Re-Rank 2026-04-02

## Purpose

Re-rank War 2 after the first present-invariant wave landed.

This is the decision point after:

- scene submission proof was added
- publication retirement was hardened
- dead widget-local present payload was deleted

The question now is simple:

- what is the next strongest terminal enemy after the present ack ambiguity is
  no longer the center?

## Current Read

The first War 2 present pass was worth doing.

It materially improved the system:

- submitted scene truth is now the authority for terminal present retirement
- weak widget-local feedback is gone
- the remaining Wayland/present bug surface is cleaner and more concrete

But that same success changes the ranking.

The dominant problem is no longer:

- "what should gate terminal acknowledgement?"

The dominant problem is again structural:

- Zide still lacks the cleanest possible engine-owned host/export boundary
- and the heaviest remaining non-engine center is still
  [terminal_publication.zig](/home/home/personal/zide/src/terminal/core/publication/terminal_publication.zig)

## Strongest Current Candidate

### Publication Still Reads Like The Largest Parallel Center

Live size/read pressure:

- [terminal_publication.zig](/home/home/personal/zide/src/terminal/core/publication/terminal_publication.zig): 795 lines
- [terminal_widget.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget.zig): 519 lines
- [terminal_widget_draw.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw.zig): 745 lines
- [workspace.zig](/home/home/personal/zide/src/terminal/core/workspace.zig): 320 lines
- [workspace_host.zig](/home/home/personal/zide/src/terminal/core/workspace_host.zig): 145 lines

The important part is not the raw count.

It is the role pressure:

- publication still owns snapshot/export truth
- publication still owns frame-facing status summaries
- publication still owns present retirement policy
- widget/native code still consumes publication-shaped state directly

That is much better than War 1.

But compared to the strongest references, it is still the heaviest remaining
place where terminal truth appears to branch before it reaches the host.

## Why This Now Beats The Present Lane

The present lane still matters, but its question is narrower now:

- if an omitted-terminal-blit bug still reproduces, that is a concrete scene
  composition bug

That is no longer the same kind of broad architectural enemy.

The broader remaining architecture pressure is:

- publication still feels like a second large terminal center rather than the
  narrowest possible engine export boundary

This is again the strongest first-glance gap against Ghostty-style clarity.

## Strongest Next Review Question

What should publication be after the War 2 present fixes?

Not:

- a helper bag
- a second terminal center
- a native-host convenience bucket

But:

- the narrowest honest engine export boundary needed by widget, workspace,
  pacing, replay, and FFI

## Best Next Battlefield

Open the next War 2 review on this exact question:

- does `terminal_publication.zig` still read like a parallel truth center
  instead of a narrow engine export boundary?

And judge it against:

- live Zide code after the present fixes
- Ghostty engine/surface separation
- our own ambition for a clean native host over one engine truth

## What Not To Do Next

- do not keep grinding the present lane by momentum
- do not reopen solved widget-local present cleanup
- do not drop back into tiny `VTCORE-05` helper hunting

## Bottom Line

The first War 2 present wave made the system more correct.

That success re-exposes the bigger structural gap:

- publication is again the strongest remaining non-engine center

So the next War 2 opener should likely be:

- a fresh publication-boundary review from the live post-present codebase

# Terminal War 2 Post-Host Re-Rank 2026-04-02

## Purpose

Re-rank War 2 after the host-aggregation wave.

This is the next top-level decision point after:

- the present-invariant wave
- the publication-boundary wave
- the host-aggregation wave

The question now is:

- what is the strongest remaining terminal false center or quality gap after
  those three waves materially reduced the earlier default enemies?

## Current Read

The host wave was worth doing.

It moved host-facing:

- frame summaries
- poll counters and metrics
- workspace poll entrypoint
- workspace poll policy

under [workspace_host.zig](/home/home/personal/zide/src/terminal/core/workspace_host.zig).

The live shape now looks like this:

- [terminal_publication.zig](/home/home/personal/zide/src/terminal/core/publication/terminal_publication.zig):
  425 lines
- [workspace.zig](/home/home/personal/zide/src/terminal/core/workspace.zig):
  299 lines
- [workspace_host.zig](/home/home/personal/zide/src/terminal/core/workspace_host.zig):
  247 lines
- [visible_terminal_frame_hooks_runtime.zig](/home/home/personal/zide/src/app/terminal/visible_terminal_frame_hooks_runtime.zig):
  193 lines
- [terminal_draw_surface_runtime.zig](/home/home/personal/zide/src/app/terminal/terminal_draw_surface_runtime.zig):
  65 lines
- [terminal_widget.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget.zig):
  521 lines
- [terminal_widget_draw.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw.zig):
  746 lines
- [parser.zig](/home/home/personal/zide/src/terminal/parser/parser.zig):
  372 lines
- [csi.zig](/home/home/personal/zide/src/terminal/protocol/csi.zig):
  182 lines

The important point is not the line count alone.

It is what still looks second-rate at first glance compared with the strongest
references.

## What No Longer Looks Like The Main Enemy

### Publication by default

Publication is no longer the obvious second center.

It is still heavy, but it now reads much closer to an engine export boundary
than to a widget/publication hybrid center.

### Host aggregation by default

The host path is still not perfect, but it no longer reads like the broad,
distributed false center it was before:

- `workspace_host` now owns the workspace-facing host poll story
- visible-frame hooks now read as visible poll/input routing
- draw-surface runtime is narrow

That lane should not keep moving by momentum.

### Parser/protocol ownership by default

This lane still matters, but it no longer looks like the repo’s loudest
architectural embarrassment.

The protocol/parser files are smaller and less visibly theater-heavy than the
remaining native widget/render center.

## Strongest Remaining Candidates

### Candidate A: Widget / Retained-Render Center

This is now the leading candidate.

Why:

- [terminal_widget.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget.zig)
  and [terminal_widget_draw.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw.zig)
  are now the heaviest remaining native terminal center by far
- they still mix a lot of concerns:
  - retained texture lifecycle
  - draw cache and generation tracking
  - blink and interaction-adjacent state
  - overlay and scrollbar integration
  - widget-local staging for present and redraw
- some of this is honest widget state
- but the pair is now the loudest remaining place where “local host state”
  and “terminal render center” still blur together

This is the strongest candidate for the next structural war.

### Candidate B: Concrete Present Composition Omission Bug

This remains a valid bug lane, not the default structural answer.

If there is still a live repro where:

- the authoritative scene clears
- a submitted frame omits the retained terminal surface
- and present feedback still looks healthy

then that bug should reopen immediately.

But absent a live repro, this should not beat the heavier widget/render center.

### Candidate C: Parser / Text Semantics Below VT Boundary

This remains a real quality bar issue, especially against Ghostty.

But after the War 1 and War 2 flattening waves, it does not currently look
like the strongest first-glance false center in the implementation.

That makes it a follow-up structural candidate, not the default opener.

## Current Judgment

After the host-aggregation wave, the next likely War 2 battlefield is the
widget / retained-render center.

More concretely:

- the broad host path is now much more honest
- publication is no longer the default enemy
- parser/protocol still matter, but they no longer dominate first-glance read
- the heaviest remaining mixed native center is now the widget/render pair

## Best Next Review Question

What still prevents the native terminal widget/render path from reading like a
clean host-side retained surface over one engine truth?

More concretely:

- what in `terminal_widget.zig` is honest local host/widget state
- what in `terminal_widget_draw.zig` is honest retained-surface draw logic
- and what still looks like a broader render/runtime center that should be
  cut or regrouped differently

## Bottom Line

After the host wave, War 2 should probably stop climbing upward and start
driving into the widget / retained-render center.

That is now the loudest remaining local terminal center.

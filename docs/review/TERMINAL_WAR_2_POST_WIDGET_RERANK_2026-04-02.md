# Terminal War 2 Post-Widget Re-Rank 2026-04-02

## Purpose

Re-rank War 2 after the first widget / retained-render wave.

This is the next top-level decision point after:

- the present-invariant wave
- the publication-boundary wave
- the host-aggregation wave
- the first widget / retained-render wave

The question now is:

- what is the strongest remaining terminal false center or quality gap after
  those four waves?

## Current Read

The first widget/render wave was worth doing.

It removed or narrowed three real local slabs:

- widget retained-surface state is now grouped under
  [terminal_widget_retained_state.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_retained_state.zig)
- draw latency publication moved to
  [terminal_widget_draw_metrics.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw_metrics.zig)
- kitty upload/update orchestration moved under
  [terminal_widget_kitty.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_kitty.zig)

The live shape now looks like this:

- [terminal_publication.zig](/home/home/personal/zide/src/terminal/core/publication/terminal_publication.zig):
  425 lines
- [workspace.zig](/home/home/personal/zide/src/terminal/core/workspace.zig):
  299 lines
- [workspace_host.zig](/home/home/personal/zide/src/terminal/core/workspace_host.zig):
  247 lines
- [terminal_widget.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget.zig):
  497 lines
- [terminal_widget_draw.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw.zig):
  690 lines
- [parser.zig](/home/home/personal/zide/src/terminal/parser/parser.zig):
  372 lines
- [visible_terminal_frame_hooks_runtime.zig](/home/home/personal/zide/src/app/terminal/visible_terminal_frame_hooks_runtime.zig):
  193 lines
- [csi.zig](/home/home/personal/zide/src/terminal/protocol/csi.zig):
  182 lines

The key change is not the line count alone.

It is that the widget/render lane now reads much closer to honest retained
surface planning/execution than it did when the wave opened.

## What No Longer Looks Like The Main Enemy

### Widget/render by default

The widget/render lane is still heavy.

But after the first wave, the remaining weight in
[terminal_widget_draw.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw.zig)
now reads much more like actual retained-surface planning/execution than like
a loose mixed center.

That means it is no longer obviously the next default enemy by momentum alone.

### Host aggregation by default

This still looks materially flatter than before:

- `workspace_host` owns host-facing workspace aggregation and poll policy
- visible-frame hooks read as visible poll/input routing
- draw-surface runtime remains narrow

This lane should stay paused unless a larger false center reappears.

### Publication by default

Publication still looks like a real boundary now, not the default second
terminal center.

## Strongest Remaining Candidates

### Candidate A: Parser / Text Semantics Below VT Boundary

This now looks stronger again than it did during the earlier local cleanup
waves.

Why:

- [parser.zig](/home/home/personal/zide/src/terminal/parser/parser.zig)
  is still heavier than the protocol leaf files
- compared with Ghostty, parser/text semantics still look more exposed above
  the cleanest VT boundary than ideal
- now that publication, host aggregation, and widget/render are materially
  flatter, this layer mismatch becomes easier to see again

This is the strongest structural candidate for the next War 2 opener.

### Candidate B: A Concrete Present Composition Omission Bug

Still a valid bug lane, not the default structural answer.

If a live repro still exists where the authoritative scene clears and the
terminal surface is omitted from a submitted frame, that bug should reopen.

But absent a live repro, it should not outrank the strongest structural gap.

### Candidate C: One More Deeper Retained-Surface Owner Cut

This is still possible.

If one more unmistakable owner boundary appears inside
`terminal_widget_draw.zig`, that cut could still be worth taking.

But it should not be assumed.

The first wave got the lane close enough to a stop-marker that another cut now
needs stronger evidence than before.

## Current Judgment

After the first widget/render wave, the next likely War 2 battlefield is
parser / text semantics below the VT boundary.

More concretely:

- publication is not the default enemy
- host aggregation is not the default enemy
- widget/render is much closer to honest retained-surface work
- the strongest remaining first-glance structural gap is again the semantic
  text/protocol layer placement

## Best Next Review Question

What still prevents Zide’s parser / semantic-text / protocol split from
reading as cleanly engine-centered as the strongest references?

More concretely:

- what still lives too high above the VT boundary
- what still forces parser/protocol code to look like a semantic owner instead
  of a narrower engine subsystem
- and what is the next whole-slab cut instead of another helper shave

## Bottom Line

After the widget/render wave, War 2 should likely pivot back to the parser /
text semantics boundary.

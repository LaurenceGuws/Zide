# Terminal Widget Retained Render Review 2026-04-02

## Purpose

Open the likely next War 2 battlefield directly on the live code.

After:

- the present-invariant wave
- the publication-boundary wave
- the host-aggregation wave

the heaviest remaining native terminal center is now the widget / retained
render pair.

This review asks:

- what in that pair is honest local host/widget state
- and what still reads like a broader render/runtime center

## Inputs Reviewed

Live code:

- [terminal_widget.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget.zig)
- [terminal_widget_draw.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw.zig)
- [terminal_widget_view_state.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_view_state.zig)
- [terminal_widget_input.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_input.zig)
- [terminal_widget_draw_grid.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw_grid.zig)
- [terminal_widget_draw_texture.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw_texture.zig)
- [retained_targets_runtime.zig](/home/home/personal/zide/src/ui/renderer/retained_targets_runtime.zig)
- [scene_frame_runtime.zig](/home/home/personal/zide/src/ui/renderer/scene_frame_runtime.zig)

Reference pressure:

- Ghostty `Surface`
- Foot render/damage discipline
- Rio / WezTerm pre-present discipline

## High-Level Read

The pair is heavy for understandable reasons.

A terminal widget with retained texture publication, overlays, hover/open
behavior, blink, selection, and redraw pacing should not be tiny.

So the question is not:

- "why is the widget large?"

The real question is:

- "does the pair still mix too many different centers of gravity to read
  cleanly at first glance?"

## What Looks Honest

These parts mostly read as honest local widget/host retained-render state:

- hover state
- pending open request state
- focus-report policy and last-focus staging
- selection gesture state
- local blink timing state
- retained texture readiness / last rendered generation tracking
- local partial draw buffers used to translate render-cache damage into a
  retained surface update

Those are all plausible host/widget concerns.

Status update:

- the widget root no longer stores that retained-surface planning state as a
  loose field pile
- it now lives in
  [terminal_widget_retained_state.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_retained_state.zig)
  as one grouped retained owner slab

That is a real improvement, but it does not settle the bigger question inside
`terminal_widget_draw.zig`.

## What Still Looks Structurally Heavy

### 1. `terminal_widget_draw.zig` is still the loudest remaining local center

It currently mixes:

- capture/preparation consumption
- retained-surface update planning
- viewport-shift logic
- texture update execution
- kitty image upload/update flow
- overlay draw timing
- latency publication
- scene submission-side terminal surface signaling

Some of this is draw work.

But it is still a lot of different retained-render concerns in one place, and
that is why the file still reads louder than the rest of the native path.

Status update:

- kitty upload/update orchestration no longer lives inline in the draw center
- that flow now runs through
  [terminal_widget_kitty.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_kitty.zig)

That is another real reduction in mixed concern, even though the main retained
surface planning/execution slab still remains.

### 2. Local present/draw bookkeeping is still split across widget and draw

The current split is better than it was:

- publication retirement is gone
- widget-facing view inspection is gone

But the pair still spreads retained draw truth across:

- `terminal_widget.zig`
- `terminal_widget_draw.zig`
- texture/grid/overlay helper files
- `scene_frame_runtime.zig`

The widget-root portion of that split is now cleaner because retained-surface
state is grouped, but the draw center still carries the main retained-render
planning/execution concentration.

That may be honest enough, or it may still want one clearer retained-surface
owner grouping.

### 3. Frame-latency instrumentation lives in the draw center

This is not obviously wrong, but it is one more sign that
`terminal_widget_draw.zig` is carrying more than pure draw execution.

Status update:

- this first secondary slab is now moved out
- draw latency metrics now live in
  [terminal_widget_draw_metrics.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw_metrics.zig)
  instead of inflating the retained-render center

That was the right first cut because it removed a real non-draw concern
without pretending the main retained-surface planning/execution slab is solved.

## What Does Not Currently Look Like The Problem

### `terminal_widget.zig` as a semantic owner

The main widget file is still large, but after the publication and host waves
it reads more like:

- local widget state
- input/open/focus behavior
- retained draw cache ownership

than like a second publication/runtime center.

### View-state helpers

[terminal_widget_view_state.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_view_state.zig)
already absorbed the obvious widget-facing publication inspection slab.

That cut was worth doing and does not look like the next problem anymore.

## Current Judgment

The next likely widget/render battlefield is not the whole widget pair
equally.

It is more specifically:

- whether `terminal_widget_draw.zig` is still too broad a retained-render
  center

That is a better question than reopening `terminal_widget.zig` as if it were
still the main enemy.

Status update after the first wave:

- retained-surface widget state is now grouped
- latency publication is out
- kitty upload/update orchestration is out

That means the remaining weight in
[terminal_widget_draw.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw.zig)
is now much closer to actual retained-surface planning/execution.

So this lane is approaching a rerank point.

The next cut should only happen if it removes one more real owner boundary.
If not, the honest move is to stop and rerank War 2 again from the top.

## Best Next Review Question

Should retained terminal surface planning/execution now have one clearer owner
boundary below `terminal_widget_draw.zig`, or is the current draw file already
the narrowest honest center for that work?

More concretely:

- which parts of draw are true retained-surface planning/execution
- which parts are local widget policy/staging
- and which parts are diagnostics or secondary concerns that should stop
  inflating the draw center

## Bottom Line

If War 2 continues into the widget/render lane, the first serious target
should be:

- the retained-render center inside
  [terminal_widget_draw.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw.zig)

not a generic “split the widget more” campaign.

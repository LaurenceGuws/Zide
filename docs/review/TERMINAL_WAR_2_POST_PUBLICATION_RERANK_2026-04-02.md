# Terminal War 2 Post-Publication Re-Rank 2026-04-02

## Purpose

Re-rank War 2 after the publication-boundary campaign materially shrank
`terminal_publication.zig`.

This is the next top-level decision point after:

- the present-invariant wave
- the publication-boundary wave

The question now is:

- what is the strongest remaining terminal false center after publication is
  no longer obviously the default enemy?

## Current Read

The last publication wave was worth doing.

It removed three whole non-boundary slabs from publication:

- widget-facing draw/view inspection
- internal cache publication choreography
- present-retirement policy

Live size/read pressure is now different:

- [terminal_publication.zig](/home/home/personal/zide/src/terminal/core/publication/terminal_publication.zig): 425 lines
- [presentation_feedback.zig](/home/home/personal/zide/src/terminal/core/publication/presentation_feedback.zig): 113 lines
- [workspace.zig](/home/home/personal/zide/src/terminal/core/workspace.zig): 320 lines
- [workspace_host.zig](/home/home/personal/zide/src/terminal/core/workspace_host.zig): 145 lines
- [visible_terminal_frame_hooks_runtime.zig](/home/home/personal/zide/src/app/terminal/visible_terminal_frame_hooks_runtime.zig): 193 lines
- [terminal_draw_surface_runtime.zig](/home/home/personal/zide/src/app/terminal/terminal_draw_surface_runtime.zig): 65 lines
- [terminal_widget.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget.zig): 521 lines
- [terminal_widget_draw.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw.zig): 746 lines

The important change is not the line count by itself.

It is that publication now reads much more like a real engine export boundary
than it did at the start of War 2.

## What No Longer Looks Like The Main Enemy

### Publication by default

Publication is no longer the obvious second center it was before the last
three cuts.

What remains there mostly reads as:

- snapshot/export contract
- capture/preparation
- generation/frame summaries
- view-refresh/publication coordination
- small sync-updates control

That is close enough to honest boundary material that another split should not
be assumed.

### Present acknowledgement contract

The first War 2 present wave closed that ambiguity.

If a present bug still exists, it is now a concrete scene-composition omission
bug, not a broad architectural contract problem.

## Strongest Remaining Candidates

### Candidate A: Native host aggregation is still the broadest structural gap

This is now the leading candidate.

Why:

- host-visible terminal truth is still spread across:
  - workspace/workspace_host
  - visible-frame input/poll routing
  - terminal widget state
  - draw/runtime host code
- compared to Ghostty’s `Termio -> Terminal/Screen -> Surface` read, Zide’s
  native host path is still more distributed than ideal

This is cleaner than it was during War 1.

But it is now the clearest place where first-glance clarity can still improve
materially.

### Candidate B: Widget-owned retained render state is now the heaviest native center

This is the strongest local candidate.

Why:

- [terminal_widget.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget.zig)
  plus [terminal_widget_draw.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw.zig)
  now carry a large amount of:
  - retained texture state
  - draw-cache state
  - blink/input-adjacent state
  - generation-tracking state
  - widget-local present staging
- some of that is honest host/widget state
- but the pair may now be the loudest remaining native terminal center by
  weight and mixed responsibility

This is the most likely next local battlefield if the broader host rerank does
not reveal a higher-level false center first.

### Candidate C: A concrete present composition omission bug still exists

This is still a valid bug lane, but not the default strategic answer.

Open it only if there is a live reproducible omission after the stronger
present invariant work.

## Current Judgment

War 2 should not keep grinding publication by momentum.

The stronger next structural question is now:

- does the native host path still lack one unmistakable host-facing terminal
  aggregate over engine truth?

If yes, that should become the next campaign.

If no, then the next likely target is the widget/retained-render state center.

## Best Next Review Question

What still prevents the native terminal host path from reading like the
cleanest host over one engine truth?

More concretely:

- is `workspace` / `workspace_host` / visible-frame routing still too
  distributed
- or has the native host path become honest enough that the next real center
  is the widget/retained-render pair?

## Bottom Line

After the publication-boundary wave, the default War 2 enemy changes again.

The next likely battlefield is no longer publication by default.

It is either:

- broader native host aggregation clarity

or:

- the widget/retained-render center

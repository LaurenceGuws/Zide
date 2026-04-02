# Terminal Publication Boundary Review 2026-04-02

## Purpose

Re-evaluate `terminal_publication.zig` after the first War 2 present-invariant
wave.

This is not another helper cleanup list.
It is the live-code judgment of whether publication still reads like:

- a narrow engine export boundary

or:

- a second large terminal center

## Inputs Reviewed

Live code:

- [terminal_publication.zig](/home/home/personal/zide/src/terminal/core/publication/terminal_publication.zig)
- [workspace.zig](/home/home/personal/zide/src/terminal/core/workspace.zig)
- [workspace_host.zig](/home/home/personal/zide/src/terminal/core/workspace_host.zig)
- [terminal_frame_pacing_runtime.zig](/home/home/personal/zide/src/app/terminal/terminal_frame_pacing_runtime.zig)
- [terminal_widget.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget.zig)
- [terminal_widget_draw.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw.zig)

Authority and rerank context:

- [TERMINAL_WAR_2_POST_PRESENT_RERANK_2026-04-02.md](/home/home/personal/zide/docs/review/TERMINAL_WAR_2_POST_PRESENT_RERANK_2026-04-02.md)
- [TERMINAL_WAR_2_PRESENT_INVARIANT_IMPLEMENTATION_2026-04-02.md](/home/home/personal/zide/docs/review/TERMINAL_WAR_2_PRESENT_INVARIANT_IMPLEMENTATION_2026-04-02.md)
- [TERMINAL_WAR_2_SCOUTING_2026-04-02.md](/home/home/personal/zide/docs/review/TERMINAL_WAR_2_SCOUTING_2026-04-02.md)

Reference pressure:

- Ghostty `Terminal` / `Screen` / `Termio` / `Surface`

## Current Judgment

Yes.

`terminal_publication.zig` still reads like the strongest remaining parallel
truth center outside the engine.

That does not mean publication is wrong to exist.

It means publication is still carrying too many different classes of
responsibility at once:

- host-facing snapshot/export shapes
- frame-facing status summaries
- view-refresh queueing
- presentation capture
- presentation retirement policy
- terminal draw-state inspection helpers

That is broader than the cleanest engine export boundary should read.

## Strongest Evidence

### 1. Publication still mixes storage choreography with host-facing contract

Examples in one file:

- `renderCache(...)`
- `renderCacheForGenerationLocked(...)`
- `capturePresentation(...)`
- `prepareLatestPresentation(...)`
- `frameState(...)`
- `completeSubmittedPresentationFeedback(...)`

Those are not one cohesive level of abstraction.

They span:

- host snapshot/export contract
- native present retirement policy
- cache-facing state access

### 2. Publication still owns both export shape and convenience summaries

`FrameState`, `GenerationState`, `PresentationCapture`, `VisibleViewDumpInfo`,
`DrawStateInfo`, `DirtySummary`, and related helper readers all live here.

Some of that is appropriate as export truth.

But taken together, the file still reads less like:

- "here is the one clean boundary hosts consume"

and more like:

- "here is the whole adjacent publication universe"

### 3. Widget/native code still consumes publication in multiple modes

The widget path still uses publication as:

- capture owner
- present-retirement owner
- draw-state helper owner

Pacing/workspace also use publication-shaped state directly.

That is cleaner than before, but it still makes publication look like a broad
semantic center rather than a tighter export boundary over engine truth.

### 4. Publication still carries many diagnostic/draw helpers that are not
obviously part of the boundary

Examples:

- `backgroundRunInfo(...)`
- `baseColorInfo(...)`
- `partialCaptureInfo(...)`
- `renderStateInfo(...)`
- `visibleViewDumpInfo(...)`
- `dirtySummary(...)`
- `drawStateInfo(...)`

These may be useful, but they also inflate first-glance read.

They make publication look closer to a terminal inspection toolkit than a
strict export boundary.

## What Improved

This review is not pretending nothing improved.

Major progress is real:

- frame-facing snapshot truth is now publication-owned
- pacing consumes that snapshot directly
- present retirement is now renderer-proven instead of widget-local
- widget-local present payload is smaller and more honest

So the problem is no longer thin duplication.

The problem is now whole-boundary shape.

Status update:

- the first larger post-present cut has now landed
- widget-facing cache inspection and draw/view helper state no longer lives in
  publication
- that slab now lives in
  [terminal_widget_view_state.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_view_state.zig)
- publication no longer directly reads like a widget draw inspection toolkit
- the second larger cut has now landed
- low-level cache slot choreography no longer lives in publication
- that slab now lives in
  [view_cache_publication.zig](/home/home/personal/zide/src/terminal/core/publication/view_cache_publication.zig)
- publication no longer directly reads like internal render-cache slot
  mechanics

## Best Next Review Question

If publication is meant to be the engine export boundary, what must remain in
that boundary, and what should move below it or beside it?

More concretely:

- which parts of `terminal_publication.zig` are true engine export contract
- which parts are native draw inspection helpers
- which parts are present-retirement policy that deserve a narrower owner

## Likely Hotspots

1. [terminal_publication.zig](/home/home/personal/zide/src/terminal/core/publication/terminal_publication.zig)
   around:
   - capture/preparation
   - frame state / generation summaries
   - present completion

2. [terminal_widget.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget.zig)
   where widget-local draw/present behavior still leans directly on publication

3. [terminal_widget_draw.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw.zig)
   where draw-state helpers from publication shape the native draw path

4. [workspace.zig](/home/home/personal/zide/src/terminal/core/workspace.zig)
   where the active host-facing frame state still forwards publication directly

## Non-Goal

Do not restart tiny helper hunting from this review.

The next worthwhile move should be one larger structural cut that makes
publication read more like:

- the narrowest engine export boundary

and less like:

- a second terminal center with adjacent utility gravity

## Bottom Line

Post-present War 2 is structurally clear again:

`terminal_publication.zig` is still the strongest remaining non-engine center.

The next campaign should open on whole-boundary shape, not on one more local
publication helper.

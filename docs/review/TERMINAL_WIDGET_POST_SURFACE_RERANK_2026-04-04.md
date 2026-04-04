# Terminal Widget Post-Surface Rerank

Date: 2026-04-04

## What Changed

The widget-host stack now has explicit owners for the strongest surviving
host-side buckets:

- controller state
- publication state
- surface state
- debug state

Recent slices also pushed retained bookkeeping behind the surface owner, so
the presenter is no longer carrying broad direct retained-state mutation and
comparison.

## Current Judgment

This lane is close to a stop-marker.

What no longer wins:

- loose controller-state cleanup
- raw publication/cache ownership cleanup
- split top-level kitty vs retained ownership
- broad retained bookkeeping cleanup

The widget shell now reads much more like:

- `session`
- `controller`
- `publication`
- `surface`
- `debug`

That is materially closer to the intended host-side terminal story.

## Remaining Pressure

If this lane continues, the next contradiction must be higher-level and
explicit.

The only plausible remaining local front is:

- sync-update fast-present policy versus retained update/present fallback

centered on:

- [terminal_widget_surface_presenter.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_surface_presenter.zig)

But that no longer wins by default just because the file is still large.

## New Ordering

1. pause and rerank against the broader VT maturity bar from this cleaner
   widget baseline
2. only reopen widget hosting if one fresh presenter-policy contradiction is
   named explicitly
3. do not keep shaving local widget seams by momentum

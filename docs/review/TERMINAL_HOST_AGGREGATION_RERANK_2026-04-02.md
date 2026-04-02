# Terminal Host Aggregation Re-Rank 2026-04-02

## Purpose

Decide whether the next War 2 battlefield should be:

- broader native host aggregation clarity

or:

- the widget/retained-render center

This review is based on the live code after:

- the present-invariant wave
- the publication-boundary wave

## Inputs Reviewed

Live code:

- [workspace.zig](/home/home/personal/zide/src/terminal/core/workspace.zig)
- [workspace_host.zig](/home/home/personal/zide/src/terminal/core/workspace_host.zig)
- [workspace_polling.zig](/home/home/personal/zide/src/terminal/core/workspace_polling.zig)
- [terminal_poll_runtime.zig](/home/home/personal/zide/src/app/terminal/terminal_poll_runtime.zig)
- [terminal_frame_pacing_runtime.zig](/home/home/personal/zide/src/app/terminal/terminal_frame_pacing_runtime.zig)
- [frame_render_idle_runtime.zig](/home/home/personal/zide/src/app/frame_render_idle_runtime.zig)
- [visible_terminal_frame_hooks_runtime.zig](/home/home/personal/zide/src/app/terminal/visible_terminal_frame_hooks_runtime.zig)
- [terminal_draw_surface_runtime.zig](/home/home/personal/zide/src/app/terminal/terminal_draw_surface_runtime.zig)
- [terminal_widget.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget.zig)
- [terminal_widget_draw.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw.zig)

Reference pressure:

- Ghostty `Termio` / `Surface`

## Current Judgment

Broader native host aggregation clarity is still the stronger next battlefield.

The widget/retained-render pair is heavy, but it now mostly reads like local
host/widget state.

The native host path still reads more distributed than it should.

## Why Host Aggregation Still Wins

### 1. One host story is still spread across too many adjacent owners

Current native host flow still spans:

- workspace active-session aggregation
- workspace polling and poll metrics
- app poll policy
- frame pacing / idle policy
- visible terminal input routing
- draw-surface staging

Each piece is cleaner than before.

But the overall host-facing terminal runtime still reads more like adjacent
partial owners than one unmistakable host layer over engine truth.

Status update:

- the first host-facing summary cut is now landed
- active frame state, poll metrics, and poll counters no longer hang off
  `workspace` as host-facing summary accessors
- that summary slab now lives in
  [workspace_host.zig](/home/home/personal/zide/src/terminal/core/workspace_host.zig)
- pacing now consumes that host-facing summary owner directly

### 2. Ghostty still looks cleaner at first glance

Ghostty pressure is not about identical APIs.

It is about reading the system and immediately seeing:

- runtime/transport owner
- engine owner
- surface/host owner

Zide is closer now, but native host truth still feels more distributed across
workspace, polling, frame pacing, and visible-frame hooks than that ideal.

### 3. The widget pair is heavy, but mostly honest

[terminal_widget.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget.zig)
and [terminal_widget_draw.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw.zig)
are large.

But most of that weight is now clearly:

- retained texture state
- local draw cache
- blink and interaction-local state
- widget-local staging for draw and overlays

That is not obviously the same kind of false center pressure as a distributed
host runtime path.

## Strongest Host-Aggregation Hotspots

1. [workspace.zig](/home/home/personal/zide/src/terminal/core/workspace.zig)
   - cleaner now that host-facing summary accessors moved off it
   - still the first host aggregate readers see

2. [workspace_polling.zig](/home/home/personal/zide/src/terminal/core/workspace_polling.zig)
   - policy execution lives beside workspace state rather than behind a more
     unmistakable host runtime owner

3. [terminal_poll_runtime.zig](/home/home/personal/zide/src/app/terminal/terminal_poll_runtime.zig)
   - app-level poll policy still translates host intent separately from
     workspace aggregation

4. [terminal_frame_pacing_runtime.zig](/home/home/personal/zide/src/app/terminal/terminal_frame_pacing_runtime.zig)
   - clean enough locally, but still one more host-facing state consumer that
     helps reveal the distributed shape

5. [visible_terminal_frame_hooks_runtime.zig](/home/home/personal/zide/src/app/terminal/visible_terminal_frame_hooks_runtime.zig)
   - now the real visible poll/input routing owner
   - still part of the same distributed host story

## Best Next Review Question

What should the one unmistakable native host-facing terminal aggregate be now?

More concretely:

- should `workspace` remain that aggregate
- should a narrower host-runtime owner sit above workspace/poll/pacing
- or is the current distribution already honest enough that the next real war
  should pivot down to the widget/retained-render center instead

## Bottom Line

After the publication wave, the next strongest terminal enemy is still not the
widget pair by default.

It is the broader native host aggregation story.

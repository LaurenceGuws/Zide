# Terminal Present Omission Bug Review 2026-04-02

## Purpose

Open the likely next War 2 battlefield directly on the live code.

After:

- the present-invariant hardening wave
- the publication-boundary wave
- the host-aggregation wave
- the first widget / retained-render wave
- the first parser / text boundary wave

the strongest remaining candidate is now the concrete native present
composition omission bug path.

This review asks:

- whether a cleared submitted scene can still omit the authoritative retained
  terminal surface
- and what exact path still permits that

## Inputs Reviewed

Live code:

- [wayland_present.md](/home/home/personal/zide/docs/todo/terminal/wayland_present.md)
- [scene_frame_runtime.zig](/home/home/personal/zide/src/ui/renderer/scene_frame_runtime.zig)
- [retained_targets_runtime.zig](/home/home/personal/zide/src/ui/renderer/retained_targets_runtime.zig)
- [terminal_widget_draw.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw.zig)
- [present_feedback_runtime.zig](/home/home/personal/zide/src/app/present_feedback_runtime.zig)
- [draw_frame_runtime.zig](/home/home/personal/zide/src/app/draw_frame_runtime.zig)

## High-Level Read

The acknowledgment contract is much stronger than before.

That means the remaining bug, if it still exists, is now much cleaner to state:

- the authoritative scene clears
- the frame submits successfully
- the retained terminal surface is not blitted into that submitted scene

If that still happens, the problem is no longer publication retirement.

It is real scene composition omission.

## What Looks Better Now

- present retirement requires renderer-proven submitted scene truth
- terminal surface blits now record generation proof at the scene level
- widget-local weak retirement fields are gone

That means the failure surface is smaller and more falsifiable.

## Current Live Risk

The handoff and present todo still record the live risk as:

- some cleared frames submit with `terminal_texture_draws=0`

The current renderer logging path already exposes the key proof points:

- `renderer.present`
  - `terminal_surface_blits`
  - `terminal_surface_generation`
  - `composition_full_pane_clear`
- `renderer.terminal_present`
  - terminal surface draw calls and destination details

Focused-terminal instrumentation note:

- the omission hunt now emits the same `renderer.present` frame summary in
  focused terminal mode too
- before that fix, the exact bug-scoped frame log was bypassed by the early
  terminal-mode return in present completion

## Strongest Failure Candidates

### 1. Sync-update fast path returning before retained-surface availability is proven

In [terminal_widget_draw.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw.zig),
the sync-update fast path can return before the normal retained-surface
ensure/update path runs.

That is only safe if the retained terminal surface is already available for
blit.

This is now the strongest concrete failure candidate because the old shape was:

- clear scene background
- call retained-surface draw
- silently no-op if the retained target is missing
- return early anyway

That is exactly the kind of omission path that can produce a submitted frame
with zero terminal-surface blits.

That fast-path omission is now fixed on `main`:

- sync-update reuse only returns early when a retained terminal surface is
  actually available for blit

### 2. Retained terminal surface not ready on a frame that still presents

The widget draw path gates scene blit reuse on:

- `self.retained.terminal_texture_ready`
- visible size > 0
- retained target existence

If those preconditions fall false on a frame that still reaches submit after a
scene clear, the terminal can disappear.

Another concrete branch in this area is now fixed too:

- partial retained-surface update aborts no longer return early and skip the
  final retained-surface blit
- they now fall back to the previous retained surface if it is still available

### 3. Active terminal host path not drawing at all on some idle frames

If the active widget path does not execute or exits too early on some idle
frames, the scene can still clear and submit without terminal composition.

That would be a host/frame routing issue rather than a retained-target issue.

## Best Next Investigation Question

On a bad idle frame, which one is true?

1. the terminal widget draw path did not run
2. the widget draw path ran but skipped the retained-surface blit
3. the retained-surface blit happened but scene submission proof/logging is
   still wrong

## Logging Scope

For this bug, the minimum useful live logging is now:

- `renderer.present`
- `renderer.terminal_present`

That is the active `.zide.lua` logging scope for this investigation.

Current live instrumentation also now emits an explicit warning when the widget
is about to present visible terminal content without an available retained
terminal surface:

- `terminal_surface_unavailable_for_present`

That warning should make the remaining live bug trivial to classify if it still
reproduces.

## Current Judgment

The first obvious local omission branches are now materially reduced:

- sync-update reuse no longer returns early without a real retained surface
- partial retained-surface update aborts now fall back to the previous retained
  surface instead of returning blank
- stale widget-local retained readiness is cleared when the retained target is
  absent

That means the next live question is narrower than before:

- if the bug still reproduces, why is the retained terminal surface unavailable
  at all on the bad frame?

So the next good move in this lane is not more blind widget-draw splitting.
It is a repro-driven retained-target availability trace using:

- `renderer.present`
- `renderer.terminal_present`
- `terminal_surface_unavailable_for_present`

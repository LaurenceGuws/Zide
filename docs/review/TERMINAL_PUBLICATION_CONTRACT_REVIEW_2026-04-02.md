# Terminal Publication Contract Review 2026-04-02

## Scope

Review the current terminal publication/native host contract after the recent
`VTCORE-05` cleanup run.

This review is based on live code, not the older pre-cleanup assumptions.

## Sources

Current Zide code:

- `src/terminal/core/publication/terminal_publication.zig`
- `src/terminal/core/workspace.zig`
- `src/terminal/core/workspace_polling.zig`
- `src/app/terminal/terminal_poll_runtime.zig`
- `src/app/terminal/terminal_frame_pacing_runtime.zig`
- `src/app/terminal/terminal_draw_surface_runtime.zig`
- `src/ui/widgets/terminal_widget.zig`

Reference pressure:

- `dev_references/terminals/ghostty/src/termio/Options.zig`
- `dev_references/terminals/ghostty/src/termio/Termio.zig`
- `dev_references/terminals/ghostty/src/Surface.zig`

## Current Read

The implementation is materially better than it was before the recent cuts.

Real improvements already landed:

- widget capture refresh moved under publication ownership
- terminal presentation staging left app-generic state
- widget handoff prep moved under publication ownership
- submission feedback retirement policy moved under publication ownership
- published-generation change checks moved under publication ownership
- frame pressure booleans moved under workspace ownership

That means the old story of “native terminal path just open-codes publication
truth everywhere” is no longer accurate.

But the seam is still not finished.

The remaining problem is no longer scattered helper duplication.
The remaining problem is that the host-side terminal loop still consumes
publication truth through multiple adjacent summaries rather than one clearly
dominant frame/publication contract.

## Reference Pressure

Ghostty is useful here not because it matches our stack exactly, but because it
shows the quality bar for host/IO/render coordination:

- `termio/Options.zig` passes renderer wakeup, renderer mailbox, surface
  mailbox, and renderer state as explicit contract fields
- `termio/Termio.zig` owns IO state and talks to renderer/surface through those
  explicit handles instead of leaving host code to infer the contract from raw
  terminal internals
- `Surface.zig` reads like a real host surface over a renderer and IO pair,
  not like an ad hoc reassembler of low-level terminal state

The lesson for Zide is not “copy Ghostty’s API.”
The lesson is:

- host/runtime should consume owner-shaped state
- redraw and wake decisions should read as contract, not as arithmetic over raw
  generations spread across multiple files

## Findings

### 1. There is still no single dominant terminal frame/publication snapshot

Current shape:

- `terminal_publication.zig` owns generation state and capture/feedback helpers
- `workspace.zig` owns active frame pressure summary
- `terminal_frame_pacing_runtime.zig` still defines its own `Snapshot` and
  consumes a workspace-local active-frame mirror
- `terminal_widget.zig` still keeps a separate draw-cache/presentation handoff
  state shape

This is much better than before, but still leaves the native host reading
through multiple adjacent summaries:

- publication summary
- workspace frame summary
- widget draw/presentation handoff

None of these are individually wrong.
Together, they still stop the native path from reading like one dominant
terminal presentation contract.

### 2. Workspace is acting as the frame-pressure owner, but publication still owns the underlying truth

`workspace.activeFrameState()` now exposes:

- pending/published/presented generations
- redraw_pending
- parse_backlog
- output_pressure

That is a good improvement.

But it also means workspace is now the place where native frame pacing obtains
its terminal publication pressure contract, even though publication still owns
the generation truth underneath.

This may be correct if workspace is the stable host-facing session aggregate.
It may also be a temporary compromise.

This seam is still ambiguous enough to deserve a focused review:

- should native frame pacing consume workspace-owned frame state?
- or should publication expose one stronger active-session frame/publication
  snapshot directly, with workspace forwarding it?

Right now the answer is not crystal clear from our code alone.

### 3. Widget-side publication state is cleaner, but still partially local

`TerminalWidget` is much better now:

- it no longer rebuilds latest capture/generation state by hand
- it no longer owns submission-success retirement policy

But it still owns:

- `pending_presentation_feedback`
- `draw_cache`
- `last_render_generation`
- `terminal_texture_ready`

Some of this is honest widget draw-state.
Some of it is still part of a larger publication/presentation handoff story.

The next mistake would be to move these blindly.
They need a sharper answer to:

- what is true widget-local render cache state?
- what is actually part of terminal publication/presentation contract?

### 4. The remaining host wake/redraw story is spread across poll, pacing, and widget layers

Today:

- polling returns whether published generation advanced
- workspace summarizes active frame pressure
- frame pacing decides redraw/sleep policy
- widget draw consumes latest presentation prep

That is not incoherent.
But it still reads as four closely related layers carrying adjacent parts of the
same terminal presentation truth.

Compared with the reference pressure, this is the biggest remaining smell.

## What Improved

The following older review pressure is now stale or overstated:

- “widget/app code open-codes publication handoff everywhere”
- “app generic state is the terminal presentation staging owner”
- “poll runtime just does publication arithmetic directly”
- “frame pacing recomputes everything from raw generation truth without any
  owner summary”

Those were real before.
They are not the best current description anymore.

## Current Biggest Pain Point

The current biggest pain point is:

- lack of one clearly dominant host-facing terminal frame/publication contract

Not:

- missing publication helpers
- generic wrapper residue
- renderer-root confusion

## Recommended Next Review

Open a focused review on:

- who should own the authoritative host-facing terminal frame/publication
  snapshot

The candidates are:

1. publication owner
2. workspace as host aggregate
3. a new explicit frame/publication contract owner that publication and
   workspace both feed

This review should answer, with code:

- where redraw_pending/parse_backlog/output_pressure should truly come from
- whether widget handoff state belongs inside that same contract or stays local
- whether the poll/pacing/widget path can read through one stronger contract
  instead of three adjacent summaries

Progress note, 2026-04-02:

- publication now owns the host-facing frame/publication snapshot shape via
  `terminal_publication.FrameState`
- workspace now forwards that contract for the active session instead of
  rebuilding redraw/backlog/output-pressure locally
- terminal frame pacing now consumes that same publication-owned snapshot type
  directly instead of maintaining a parallel snapshot shape or local frame-state
  mirrors

## Recommended Review Sequence

1. Compare the current Zide host/publication contract against Ghostty’s
   surface/termio/render-state split more explicitly.
2. Decide the single dominant host-facing terminal frame snapshot.
3. Only after that, cut the next code change.

## Bottom Line

The recent changes did make the implementation better.

The next best move is not more micro-cleanup.
The next best move is a sharper review of the one remaining ambiguous seam:

- what is the single authoritative host-facing terminal frame/publication
  contract?

Rerank note, after the frame-state contract cuts:

- the frame/pacing side of this seam is now close to diminishing returns
- the next likely ambiguity is no longer pacing summary shape
- the next likely ambiguity is whether widget-local presentation handoff state
  (`draw_cache`, `pending_presentation_feedback`, texture/generation tracking)
  is now the correct remaining local state, or whether part of it still belongs
  under a sharper publication/presentation contract

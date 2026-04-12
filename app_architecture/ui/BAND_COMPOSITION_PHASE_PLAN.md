# Band Composition Phase Plan

Purpose: define the next honest renderer gate-5 blocker after
`RB-B3.e` presentable lifecycle parity has been narrowed enough that it is no
longer the strongest shared contract pressure.

This plan is intentionally narrow.

It does not reopen generic presentable cleanup.
It does not start Android GLES backend code.
It does not widen into repo-wide UI restyling or arbitrary shell cleanup.

## Why This Exists

Current code and authority now agree on the stronger remaining renderer
pressure:

- terminal presentable lifecycle is no longer the vaguest blocker
- Metal now satisfies the shared terminal refresh seam structurally and routes
  through the active refresh path
- the stronger remaining shared contract pressure is that fills and their
  dependent text/icon work still do not share one backend-neutral phase
  boundary

That means a future Android renderer would still inherit one uneven ordering
story for ordinary UI/editor/sample composition even if terminal presentable
lifecycle is materially cleaner now.

## Goal

Goal:

- define and land the next narrow band-composition seam where one ordering unit
  owns both fill/background work and its dependent text/icon/outline work
- remove a concrete example of "fill path plus unrelated immediate text path"
  from shared renderer truth

## Required Outcome

After this cut:

- one explicit band/composition seam owns local ordering for both fills and
  dependent text/icon work
- shared code no longer treats that family as generic fills plus unrelated
  immediate text
- the next remaining blocker after this cut is clearer than "phase boundary
  later"

## Initial Scope

Start with shell/UI chrome band composition.

Primary code pressure:

- `src/ui/renderer/renderer_chrome_band_host.zig`
- `src/ui/widgets/terminal_widget_draw.zig`
- `src/ui/text_runtime.zig`
- any narrow host/runtime seam needed to record and replay one band-local
  ordering unit without widening the design prematurely

Owner docs:

- `app_architecture/ui/RENDER_BACKEND_CONTRACT.md`
- `app_architecture/ui/RENDER_BACKEND_CURRENT_STATE.md`
- `docs/todo/ui/renderer.md`
- `docs/todo/android/implementation.md`

## Non-Goals

- no repo-wide generic text phase rewrite in one cut
- no editor-wide band adoption in the same step unless the chrome cut proves
  insufficient
- no Android renderer backend bootstrap
- no fake closure language that claims text/surface phase pressure is solved
  globally after one family adoption

## Acceptance Criteria

This ticket is met when:

- one real band/composition family owns fill plus dependent text/icon ordering
  under one backend-neutral seam
- shared code no longer expresses that family as one fill path plus one
  unrelated immediate text path
- queue and handoff docs can name the next blocker after this cut without
  ambiguity

## Stop Marker

Stop when:

- one narrow band/composition seam is landed and validated
- docs say exactly what family or pressure remains next
- no speculative expansion is added just to make the seam feel more general

## Current Checkpoint (2026-04-11)

- the first narrow chrome-band slice is now in:
  - `renderer_chrome_band_host.Band` can now queue/replay sized text ops
  - band text ops now copy queued text so stack-built/truncated labels are safe
    to replay at `Band.flush()`
  - `side_nav.zig` badge counts no longer bypass the band seam through
    immediate `shell.drawTextSized(...)`
  - that means the side-nav family now keeps background fills, icon text, and
    badge text inside one chrome-band ordering unit
- the second narrow chrome-band slice is now in:
  - `common.zig` exposes pure text truncation separate from immediate drawing
  - `status_bar.zig` routes mode chip text, active field text, selection/caret
    rects, error text, and file-path text through the chrome-band seam
  - tooltip drawing remains outside this seam because it is an overlay, not
    local status-bar composition
- the third narrow chrome-band slice is now in:
  - `shared_top_bar.zig` menu shadow now routes through the menu band instead
    of a direct surface rect next to band-owned menu fill/text
  - `tab_bar.zig` title truncation now separates truncation from drawing and
    queues tab title text through the chrome-band seam
  - tab-bar band text now flushes before `endClip()` so the band replay remains
    inside the tab strip clip boundary
- the fourth narrow chrome-band slice is now in:
  - integrated terminal tab-bar background now routes through the chrome-band
    seam instead of a direct surface rect next to tab text
  - shared window caption buttons now draw their backgrounds and glyph strokes
    through the chrome-band seam
- shell/UI chrome-band composition is now structurally covered for the scanned
  side-nav, status-bar, shared top-bar, tab-bar, config notice, and integrated
  window-caption paths
- remaining direct draws found by the narrowing scan are different semantics:
  editor row/overlay composition, common tooltip overlay, terminal progress /
  scrollbar / content-edge visuals, and close-confirm modal overlay

## Next Pressure

The chrome-band subtarget is no longer the loudest gate-5 pressure.

The next honest pressure should be opened as a separate narrow ticket, not
hidden under chrome-band work:

- either terminal overlay/modal composition, if Android terminal product chrome
  needs those visuals before GLES backend work
- or editor row/overlay composition, if the renderer gate needs the next
  non-terminal family before Android can feel routine

## Remaining Concrete Leak

The strongest remaining concrete leak is now inside the editor overlay owner
itself.

Current code truth:

- `src/ui/widgets/editor_widget_draw_overlay.zig` is the sanctioned owner for
  editor row/overlay composition
- but it still composes fill/background work through
  `renderer_surface_host.drawRect(...)`
- then manually forces ordering with repeated
  `renderer_surface_host.flushQueuedSurfaceDrawsBeforeDependentSurfaceWork(...)`
- then emits dependent text through `renderer_text_host.*`

That means the code now has an honest owner, but it does not yet have one
backend-neutral phase boundary for the whole local ordering unit.

The owner still has to know:

- surface fills are queued
- text is immediate
- a manual flush is required before dependent text or later surface work

That is exactly the remaining text/surface phase-boundary pressure.

## Next Ticket

`RB-B3.j` editor overlay phase-boundary closure

Purpose:

- replace editor-overlay-local manual surface flush choreography with one
  explicit local composition seam that owns both queued fills and dependent
  text/decor emission order

Required outcome:

- `editor_widget_draw_overlay.zig` no longer manually sequences local fill/text
  ordering with repeated surface flush calls
- one local owner seam expresses that ordering unit directly
- docs can then say whether any stronger text/surface leak remains elsewhere

Non-goals:

- no repo-wide text phase rewrite
- no terminal grid/cell batching changes
- no new Android backend work

## Current Checkpoint (2026-04-12)

- first ownership cut is in:
  - immediate editor row-band fallback paths no longer spell
    `beginEditorRowBandGroup(...)` / `endEditorRowBandGroup(...)` directly in
    `editor_widget_draw.zig`
  - immediate decoration emission in `editor_widget_draw_text.zig` no longer
    flushes queued surface rects directly
  - those call sites now route through one owner API:
    `editor_widget_draw_overlay.runImmediateEditorRowBand(...)`
- remaining pressure is now narrower and fully local to the owner module:
  - `editor_widget_draw_overlay.zig` still contains the internal queued-rect
    flush points that separate row-base rect replay, dependent text, and final
    overlay/cursor rect drain
  - that means external choreography is cleaner, but full phase-boundary
    closure is not met yet
- second ownership cut is now in too:
  - non-owner immediate surface-phase callers no longer invoke
    `flushEditorSurfaceRects(...)` directly
  - pane-base, row-base, scrollbar, and immediate-decoration callers now go
    through owner APIs:
    `runImmediateEditorSurfacePhase(...)` or
    `runImmediateEditorRowBand(...)`
  - that means the surviving text/surface phase-boundary knowledge is now
    entirely inside `editor_widget_draw_overlay.zig`
- third ownership cut is now in:
  - the owner module no longer expresses draw-list rect replay as a raw
    two-loop plus unnamed mid-flush block
  - row-base replay and later overlay/pane replay now route through explicit
    owner helpers:
    `replayDrawListRectFamily(...)` and `drawEditorSurfaceRectOp(...)`
  - the remaining direct line-number text helper `drawEditorTextOnBg(...)`
    now also routes through `runImmediateEditorRowBand(...)`
- current blocker reading:
  - external choreography is gone
  - rect/text/cursor phase knowledge is now centralized in owner-local helpers
  - `RB-B3.j` is now met:
    one explicit owner-local seam now owns editor row-band local ordering, and
    non-owner files no longer spell the queued-surface versus immediate-text
    phase boundary directly

## Next Pressure After `RB-B3.j`

The next honest editor-local pressure is narrower than row-band phase
ownership:

- `editor_widget_draw_text.zig` no longer has separate expanded-text helper
  stacks for immediate fallback versus draw-list emission; highlighted text and
  decoration traversal now run through one generic emitter-driven path
- the remaining emitter surface there is now small enough to be an accepted
  owner seam; it no longer carries the real contract split
- IME/composition preview and scrollbars stay outside this ticket by ownership:
  they are cursor-anchored and pane-final overlays, not row-band-local
  ordering leaks

## Next Pressure After Editor Text Emitter Closure

The next honest leak is the cursor-anchored IME composition preview:

- `src/ui/widgets/editor_widget_draw.zig` still draws composing text directly
  through `renderer_text_host.drawTextMonospaceOnBg(...)`
- it also draws the composition underline directly beside that text path
- that means one editor interaction overlay still bypasses an explicit local
  owner seam even though row-band-local ordering is now settled

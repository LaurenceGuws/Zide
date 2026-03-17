# Terminal Dogfood Review 2026-03-17

Purpose: convert the raw first-day native terminal dogfood note into a durable
review record with stable issue ids, status, and owning follow-up references.

Source note:

- local raw capture: `dogfood_test.txt`

Status legend:

- `fixed` — landed on `main`
- `deferred` — explicitly postponed with an owning note
- `superseded` — no longer worth separate follow-up after a larger cut landed

## Summary

This dogfood pass was highly productive. The raw note surfaced a cluster of
boundary and redraw bugs that looked independent at first, but were tightly
related:

- terminal tab/workspace ownership drift
- chrome living too close to terminal content/runtime code
- bridge/native convenience surfaces sitting too close to core/session code
- a small number of redraw/publication edge cases under Codex streaming

Most items from the original note are now fixed. The remaining unresolved items
are both in the same deferred Codex redraw family.

## Issues

### TDF-01 Terminal tab reorder desynchronized visual order from backend order

Original symptom:

- drag-reordering terminal tabs looked correct visually
- keyboard next/previous navigation still followed the old order
- later repro showed title/content/widget ownership drifting after reorder

Disposition:

- `fixed`

Resolution:

- workspace reorder now also keeps terminal widget ownership aligned
- terminal navigation/runtime paths now follow the same reordered authority

Owning references:

- `docs/todo/terminal/tabs.md`

### TDF-02 Codex final-summary dirty tracking corruption

Original symptom:

- after the agent finished, a final streamed summary sometimes updated only
  parts of each row
- any keyboard input woke the UI and cleared the defect immediately

Disposition:

- `deferred`

Reason:

- real reference work against Codex showed a distinct completion-tail flush
  path
- current logging narrowed the suspicious area but did not yield a stable repro
- the bug appears timing-sensitive enough that instrumentation perturbs it
- added visibility is itself part of the problem: once logging/instrumentation
  is increased enough to watch the handoff closely, the repro tends to stop
  triggering
- the best current local hypothesis is therefore a cadence-sensitive
  UI/present invalidation issue around the completion-tail flush, not a generic
  Codex parsing bug or proven scrollback corruption

Owning references:

- `docs/todo/terminal/damage_tracking.md`

### TDF-03 Codex scrollbar flicker while the model was busy

Original symptom:

- terminal scrollbar flickered heavily while Codex was producing scrollback

Disposition:

- `superseded`

Reason:

- terminal scrollbar ownership was moved into app chrome
- the old terminal-owned scrollbar path and its unstable hover/visibility logic
  no longer exist in the same form
- reopen only if the behavior reproduces on current `main`

Owning references:

- `docs/todo/terminal/widget_boundary_split.md`

### TDF-04 Codex resize-while-streaming corruption

Original symptom:

- resizing while Codex was streaming caused scrollback corruption, visual state
  loss, and in some cases apparent scrollback clearing

Disposition:

- `superseded`

Reason:

- later user re-check on current `main` did not reproduce the bug, including
  GUI zoom plus Hyprland forcing a tiled half-monitor resize while Codex was
  actively streaming
- keep the historical note, but do not treat this as an active open issue
  unless it reproduces again

Owning references:

- `docs/todo/terminal/damage_tracking.md`

### TDF-05 Lazydocker box-drawing gaps

Original symptom:

- some box-drawing glyphs disappeared, leaving blank lines in borders

Disposition:

- `fixed`

Resolution:

- unsupported box/block glyphs no longer route into an incomplete special-glyph
  path
- they now fall back to normal font rendering unless explicitly covered

Owning references:

- `docs/todo/ui/terminal_special_glyphs.md`

### TDF-06 Bursty blocked input under redraw pressure

Original symptom:

- bursts of input appeared to pause and then catch up later
- later narrowed to redraw-heavy cases such as `nvim`

Disposition:

- `fixed`

Resolution:

- threaded PTY sessions now stay hot while unread parser-thread IO remains
  buffered

Owning references:

- `docs/todo/terminal/widget.md`

### TDF-07 Copying selected scrollback jumped viewport to the cursor

Original symptom:

- `Ctrl+Shift+C` in normal shell scrollback behaved like live terminal input and
  snapped the viewport back to the cursor

Disposition:

- `fixed`

Resolution:

- copy handling no longer falls through the normal terminal-input path

Owning references:

- `docs/todo/terminal/widget.md`

### TDF-08 Tab chips should show richer child-process metadata

Original request:

- show richer child process metadata than a bare process basename
- support progress-aware tab-chip integration

Disposition:

- `fixed` for native
- `deferred` for FFI

Resolution:

- native tab chips now prefer richer command summaries
- native progress chip/bar support now uses backend progress truth
- FFI progress exposure remains a separate follow-up lane

Owning references:

- `docs/todo/terminal/tabs.md`
- `docs/todo/terminal/ffi_host_semantics.md`

### TDF-09 Focus-loss hover behavior was unstable

Original symptom:

- hover effects near window edges remained active or behaved unnaturally after
  focus loss

Disposition:

- `fixed`

Resolution:

- focus-loss handling now clears or decays transient hover state appropriately
- scrollbar ownership later moved into app chrome, simplifying the feature

Owning references:

- `docs/todo/terminal/widget.md`
- `docs/todo/terminal/widget_boundary_split.md`

### TDF-10 Drag selection anchor felt offset

Original symptom:

- starting a drag from the middle of `H` in `Hello` could skip `H` and begin at
  `e`

Disposition:

- `fixed`

Resolution:

- drag selection now remembers the initial anchor cell immediately, while still
  suppressing a visible one-cell selection on plain mouse-down

Owning references:

- `docs/todo/terminal/widget.md`

## Current Result

From the original note:

- fixed: `7`
- deferred: `1`
- superseded: `2`

The remaining open dogfood work from this first-day note is therefore:

1. `TDF-02` Codex final-summary dirty tracking corruption

Everything else in the raw note is either fixed or no longer a separate
follow-up after larger architectural cuts landed.

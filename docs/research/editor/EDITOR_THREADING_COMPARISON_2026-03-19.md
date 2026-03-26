# Editor Threading Comparison 2026-03-19

## Purpose

Record the current execution-lane comparison for editor highlight/render work so
the next Zide change is a threading/runtime cut, not another redraw-budget
tweak.

## Question

After the Unicode startup probe work, Zide became more responsive, but the logs
still showed that visible highlight generation was produced incrementally on the
foreground frame path. The user-facing result was smooth movement with visibly
streaming syntax color, which is not an acceptable steady design.

The comparison question is:

- where do Zide, Neovim, Neovide, and Notepad++ place expensive editor work
- which lane owns highlight truth
- what should Zide change next

## Zide Today

### Observed execution lanes

- search is already backgrounded:
  - `src/editor/search_highlight.zig`
  - `searchWorkerMain`
  - `std.Thread.spawn(.{}, searchWorkerMain, .{self})`
- grammar bootstrap is backgrounded:
  - `src/editor/search_highlight.zig`
  - `grammarAutoBootstrapWorker`
  - detached worker spawn
- visible highlight warmup is still foreground frame work:
  - `src/app/editor/editor_frame_hooks_runtime.zig`
  - `src/app/editor/editor_visible_caches_runtime.zig`
  - `src/ui/widgets/editor_widget_draw_cache.zig`

### Current foreground path

The current lane is:

1. frame hook decides whether redraw or startup warmup should run
2. `editor_visible_caches_runtime.precompute(...)` runs on that path
3. `precomputeHighlightTokens(...)` calls `highlighter.highlightRange(...)`
4. results are split into per-line cache entries
5. more redraws are requested until visible work drains

This is architecturally better than the earlier repeated-rework bug, but the
work still happens on the render/input lane.

### What the logs showed

Recent probe runs showed:

- repeated highlight rework was fixed
- startup highlight work now starts promptly
- each 4-line visible batch still costs about `50 ms` to `330 ms`

That means the remaining problem is not cache invalidation. The remaining
problem is lane ownership: expensive highlight production still lives on the UI
frame path.

## Neovim

Relevant file:

- `dev_references/editors/neovim/runtime/lua/vim/treesitter/highlighter.lua`

What matters:

- `TSHighlighter` owns persistent highlight state
- highlight state is kept per window in `_highlight_states`
- tree callbacks drive invalidation and redraw requests
- the highlighter tracks whether a window is currently parsing asynchronously
  with `parsing`

Takeaway:

- highlight truth belongs to the editor/runtime layer, not to a widget redraw
  cache
- visible rendering consumes runtime-owned highlight state
- even when work is incremental, the seam is highlighter/runtime owned, not
  “draw path calls highlight now”

Neovim is not a direct background-thread template for Zide, but it is a strong
ownership reference: syntax work is part of editor runtime state, not ad hoc GUI
precompute logic.

## Neovide

Relevant files:

- `dev_references/editors/neovide/src/main.rs`
- `dev_references/editors/neovide/src/bridge/mod.rs`
- `dev_references/editors/neovide/src/bridge/ui_commands.rs`
- `dev_references/editors/neovide/src/editor/mod.rs`

What matters:

- `main.rs` explicitly documents the architecture:
  - bridge is async
  - editor preprocessing runs on its own thread
  - renderer draws editor output
  - window owns input/render loop
- `bridge/mod.rs` starts the editor handler separately from the bridge runtime
- `bridge/ui_commands.rs` splits commands into serial and parallel lanes
- `editor/mod.rs` transforms `RedrawEvent` into `DrawCommand` batches before the
  window consumes them

Takeaway:

- Neovide refuses to make the window/input lane perform the heaviest editor
  preprocessing
- expensive event transformation belongs to a dedicated editor lane
- communication happens through explicit event/command queues

For Zide, this is the clearest structural reference. Our visible highlight fill
belongs in an editor-runtime worker or dedicated editor lane that publishes
ready-to-consume results to the UI path.

## Notepad++

Relevant files:

- `dev_references/editors/notepad-plus-plus/scintilla/doc/ScintillaUsage.html`
- `dev_references/editors/notepad-plus-plus/scintilla/src/Editor.cxx`
- `dev_references/editors/notepad-plus-plus/scintilla/call/ScintillaCall.cxx`

What matters:

- Scintilla handles syntax styling through `SCN_STYLENEEDED`
- styling advances from `SCI_GETENDSTYLED` to the requested position
- `StyleAreaBounded(...)` explicitly bounds foreground styling to stay
  responsive
- `StartIdleStyling(...)` and `IdleStyle()` continue the remaining styling later
- Scintilla also exposes `SetIdleStyling(...)`
- Scintilla exposes `SetLayoutThreads(...)` for layout work

Takeaway:

- Notepad++ does not make the app invent a redraw-triggered highlight pipeline
- the editor engine owns partial styling progress and idle continuation
- bounded foreground work plus engine-owned deferred continuation is a core part
  of the design

For Zide, the lesson is not “copy idle styling literally”. The lesson is that
styling progress belongs to the editor engine/runtime seam, not widget draw
cache logic.

## Comparison Summary

### Zide today

- background threads exist for search and grammar bootstrap
- visible highlight generation still happens on the foreground frame path
- widget/render-precompute code still triggers expensive syntax work

### Neovim

- highlight state is runtime-owned and persistent
- invalidation and redraw flow through editor/runtime callbacks
- GUI-like frame precompute does not own syntax truth

### Neovide

- heavy preprocessing is explicitly off the window/input lane
- bridge, editor, renderer, and window are separate execution lanes
- event/command queues are first-class architecture

### Notepad++

- styling is engine-owned
- bounded foreground work and deferred continuation are built into the editor
  engine seam
- the application does not own syntax work scheduling at the redraw-cache level

## Decision For Zide

The next cut should be:

- remove foreground highlight production from visible-cache precompute
- move visible highlight fill into a persistent editor-runtime worker or
  equivalent editor-owned work lane
- let that lane publish immutable per-range or per-line highlight results keyed
  by highlight epoch and visible-range intent
- keep the UI thread limited to:
  - requesting work
  - applying completed results
  - scheduling redraw when new results arrive

## Concrete Direction

1. Add an editor-owned highlight work service.
   It should own queue state, progress, cancellation, and completed-result
   publication.

2. Make work items epoch-keyed.
   If text or parser state changes, old work must be dropped by epoch rather
   than fought inside widget code.

3. Stop calling `highlightRange(...)` from widget visible precompute.
   That path should consume completed results only.

4. Keep line width, wrap, and grapheme metrics in editor/render ownership.
   Those caches were already proven to be the right seam.

5. Keep redraw driving separate from work production.
   Redraw can request more work, but redraw must not be the place where the
   expensive highlight query executes.

## Recommended Next Implementation

- create a dedicated editor highlight runtime lane
- start with one worker and one result mailbox
- publish completed visible-range batches back to the render cache
- convert current foreground precompute to:
  - submit missing work
  - consume ready work
  - never execute highlight generation inline

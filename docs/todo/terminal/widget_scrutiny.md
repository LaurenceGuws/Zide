# Terminal Widget Scrutiny TODO

## Scope

Turn the native terminal widget stack into a boring, high-quality host of VT
truth.

This queue exists because the widget is still capable of weakening VT maturity
even when `TerminalCore` improves.

The target is not:

- smaller files
- one more local bug fix
- more hot-path cleverness

The target is:

- a widget stack that hosts a mature terminal object through deliberate seams
- a draw path that does not duplicate terminal visual semantics across
  optimized branches
- an input path that does not know a grab bag of session/core verbs
- a retained terminal present path that reads like explicit presenter
  infrastructure

## Authority

- [TERMINAL_WIDGET_HOSTING_DESIGN.md](/home/home/personal/zide/app_architecture/terminal/TERMINAL_WIDGET_HOSTING_DESIGN.md)
- [TERMINAL_WIDGET_HOSTILE_AUDIT_2026-04-04.md](/home/home/personal/zide/docs/review/TERMINAL_WIDGET_HOSTILE_AUDIT_2026-04-04.md)
- [VT_MATURITY_PURITY_CAMPAIGN.md](/home/home/personal/zide/app_architecture/terminal/VT_MATURITY_PURITY_CAMPAIGN.md)
- [VT_MATURITY_COMPLETION_LIST.md](/home/home/personal/zide/app_architecture/terminal/VT_MATURITY_COMPLETION_LIST.md)

## Why This Counts

This queue is not side cleanup.
It directly advances VT maturity by pressuring the native host side where it
still teaches the wrong story.

Primary completion-list pressure:

- item 1: `TerminalCore` must feel like the terminal object
- item 5: host contract must feel deliberate and normalized
- item 8: host edge must not undermine terminal identity
- item 9: peer comparison must not show a clear first-glance loss

Current front, 2026-04-06:

- Linux resize/scrollback breakage is now explicit pressure on this lane.
- terminal pane-fit quality is explicit pressure too:
  the terminal should visually own the pane right up to its edges under zoomed
  TUI layouts instead of floating inside it with dead right/bottom margins
- The current suspicion is not "GL redraw happened to glitch."
- The stronger current suspicion is:
  - terminal resize reflow is not preserving viewport/scrollback truth cleanly
    enough
  - retained terminal presentation does not invalidate strongly enough on
    resize-sensitive geometry changes
- Checkpoint, 2026-04-06 (Renderer Contract Review 1):
  - after deferred terminal grid resize (`post_preinput_hooks_runtime`), all terminal widgets call
    `invalidatePresentationCache()` so retained/direct presentation does not keep geometry from
    before the resize
- Checkpoint, 2026-04-06:
  - terminal presentation geometry now consumes renderer-resolved
    `TerminalViewGeometry` instead of independently recomputing visible fit
    from raw pane size
  - this removes one class of pane-fit drift between widget draw/input
    geometry and retained/direct presentation geometry
  - terminal special-glyph sprite placement now snaps from exact logical cell
    bounds instead of rounded logical boxes, reducing one known fractional-DPI
    source of periodic seams/overlap
  - shade block glyphs such as `░` now route through the same special-sprite
    coverage path as other special glyphs, with fractional-scale horizontal
    edge policy aligned to the text path instead of always-on snapping
  - the terminal widget special-glyph path no longer keeps analytic fallback
    rescue branches for box/shade once the sprite-owned path is chosen
  - terminal pane background ownership now starts from the terminal's live
    resolved background color for the whole pane, so centered-grid remainder
    space no longer leaks shell/app chrome color around the viewport
- Checkpoint, 2026-04-07:
  - drag selection now updates from raw cell geometry instead of the
    row-content-clamped helper used for click selection follow-up
  - view-cache publication no longer treats active selection drag as a
    clean-advance publish case; selection bounds now force reprojection
  - multiline/blank-row selection projection no longer clips to visible
    content columns, so selection geometry matches the actual selected range
- That means this lane now has one concrete product-quality bar in addition to
  the broader widget-hosting audit:
  - resizing the terminal after output already exists must preserve sane
    visible history and must not reuse stale retained presentation state

## Hard Rules

Do not call this lane progress if the change is only:

- moving functions between widget files
- deleting wrappers without changing the hosting story
- making `terminal_widget_draw_grid.zig` smaller while keeping semantic policy
  duplicated across branches
- adding another ad hoc read helper over `RenderCache`
- adding another local input helper that still calls raw session/core verbs

## Validation

Always:

- `zig build test`
- `zig build`
- `zig build check-app-imports`
- `zig build check-input-imports`
- `zig build check-editor-imports`

Manual:

- normal shell prompt in terminal
- `nvim` alt-screen cursor correctness
- fractional scale such as `1.6`
- hover underline and ctrl-open
- pointer selection and drag autoscroll
- mouse reporting enabled TUI
- sync-update / retained-surface correctness when applicable

## Execution Order

### Phase 0: Freeze the redesign target

Goal:

- stop the audit from remaining only historical evidence

Required outputs:

- one current architecture authority for widget hosting
- one active execution queue
- explicit statement that older stop-markers are no longer enough

Completion bar:

- no ambiguity remains about why this lane counts as VT maturity work

### Phase 1: Introduce one `TerminalViewModel`

Goal:

- give draw/input/open/hover/debug one shared publication-derived read model

Required outcome:

- widget subsystems stop each deriving overlapping mini-views from
  `RenderCache`

Likely file pressure:

- `src/ui/widgets/terminal_widget_view_state.zig`
- `src/ui/widgets/terminal_widget.zig`
- `src/ui/widgets/terminal_widget_draw.zig`
- `src/ui/widgets/terminal_widget_input.zig`
- `src/ui/widgets/terminal_widget_command/open.zig`
- `src/ui/widgets/terminal_widget_hover.zig`

Completion bar:

- `RenderCache` read truth is centralized enough that later cuts do not need
  more mini-view helpers

### Phase 2: Split `TerminalSurfacePresenter`

Goal:

- move retained terminal surface policy out of generic widget draw glue

Required outcome:

- retained texture lifecycle
- full vs partial redraw choice
- viewport shift policy
- partial damage planning
- scene-target invalidation linkage
- presentation feedback handoff

all read like one explicit presenter subsystem

Likely file pressure:

- `src/ui/widgets/terminal_widget_draw.zig`
- `src/ui/widgets/terminal_widget_draw_texture.zig`
- `src/ui/widgets/terminal_widget_retained_state.zig`

Completion bar:

- the terminal widget draw path no longer owns presenter infrastructure by
  accident

### Phase 3: Centralize resolved cell style in the painter

Goal:

- stop semantic policy duplication across optimized grid draw branches

Required outcome:

- resolved cell foreground/background/cursor style is computed once
- direct/shaped/special/fallback paths consume that resolved style

Likely file pressure:

- `src/ui/widgets/terminal_widget_draw_grid.zig`
- `src/ui/widgets/terminal_widget_draw_overlay.zig`

Completion bar:

- a cursor/cell semantic bug cannot hide in only one optimized branch

### Phase 4: Collapse widget input around a smaller action contract

Goal:

- stop leaf widget files from knowing a grab bag of session/core verbs

Required outcome:

- keyboard
- pointer selection
- mouse reporting
- paste
- ctrl-open

are mediated through a smaller terminal action/input seam

Likely file pressure:

- `src/ui/widgets/terminal_widget_input.zig`
- `src/ui/widgets/terminal_widget_keyboard.zig`
- `src/ui/widgets/terminal_widget_pointer.zig`
- `src/ui/widgets/terminal_widget_output_protocol_mouse.zig`
- `src/ui/widgets/terminal_widget_paste.zig`
- `src/ui/widgets/terminal_widget_command/open.zig`

Completion bar:

- the widget stack no longer looks session-shaped from the input side

### Phase 5: Push debug ownership out of the main widget shell

Goal:

- keep investigation seams useful without letting them define the widget

Required outcome:

- dump formatting and debug sample ownership move behind explicit debug helpers

Likely file pressure:

- `src/ui/widgets/terminal_widget.zig`
- `src/ui/widgets/terminal_widget_debug_geometry.zig`

Completion bar:

- `TerminalWidget` reads more like controller/orchestrator and less like the
  default storage site for every investigation artifact

### Phase 6: Final rerank against the host-side maturity bar

Goal:

- decide whether the native widget now hosts VT truth cleanly enough that this
  lane can pause honestly

Completion bar:

- the native widget no longer obviously weakens the claim that `zide-vt` is a
  mature hostable terminal object

## TODO

- [x] `TWS-0-01` Freeze the hostile audit and redesign target
  - Evidence:
    - [TERMINAL_WIDGET_HOSTILE_AUDIT_2026-04-04.md](/home/home/personal/zide/docs/review/TERMINAL_WIDGET_HOSTILE_AUDIT_2026-04-04.md)
  - Current authority:
    - [TERMINAL_WIDGET_HOSTING_DESIGN.md](/home/home/personal/zide/app_architecture/terminal/TERMINAL_WIDGET_HOSTING_DESIGN.md)
- [x] `TWS-1-01` Introduce one `TerminalViewModel` for draw/input/open/hover/debug
  - Landed in:
    - [terminal_widget_view_state.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_view_state.zig)
    - [terminal_widget_draw.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw.zig)
    - [terminal_widget_input.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_input.zig)
    - [terminal_widget.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget.zig)
  - What changed:
    - `RenderCache`-derived terminal read truth is now centralized in
      `TerminalViewModel`
    - draw, input, scrollbar, and debug dump now consume that shared model
      instead of each deriving overlapping mini-views separately
    - the older helper exports in `terminal_widget_view_state.zig` now route
      through the same model rather than defining parallel authority
  - Current bar reached:
    - the live terminal widget front has one shared publication-derived read
      model
    - later fronts can now target presenter/painter/input ownership without
      adding more `RenderCache` helper scatter
- [x] `TWS-2-01` Split `TerminalSurfacePresenter` out of generic draw glue
  - Landed in:
    - [terminal_widget_surface_presenter.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_surface_presenter.zig)
    - [terminal_widget_draw.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw.zig)
  - What changed:
    - retained terminal surface fast-path present
    - retained texture lifecycle/use checks
- [ ] `TWS-2-02` Lock resize-sensitive retained presentation invalidation
  - Problem:
    - terminal resize can leave scrollback/viewport presentation looking broken
      after geometry changes
  - Current likely pressure:
    - `src/ui/widgets/terminal_widget_presentation_runtime.zig`
    - `src/ui/widgets/terminal_widget_surface_state.zig`
    - `src/ui/widgets/terminal_widget_presentation_state.zig`
  - Required outcome:
    - retained fast-present reuse tracks resize-sensitive geometry strongly
      enough that stale presentables cannot survive terminal geometry changes
  - Important note:
    - this is probably a secondary front
    - the primary front for the visible bug still looks like terminal-core
      resize reflow / viewport preservation
    - full vs partial redraw choice
    - viewport-shift and damage-plan handling
    - partial-plan capacity/build
    - retained present/unavailable logging
    now live behind one named presenter module instead of one generic draw
    function body
  - What intentionally stayed outside:
    - grid painting
    - overlay painting
    - widget-level geometry/debug samples
    - `kitty.finishDraw(...)` completion after presentation
  - Current bar reached:
    - retained terminal presentation now reads like explicit presenter
      infrastructure
    - `terminal_widget_draw.zig` is no longer the default home of retained
      surface policy and damage planning
- [x] `TWS-2-02` Consolidate retained-surface update planning under one presenter contract
  - Current authority:
    - [TERMINAL_WIDGET_RETAINED_UPDATE_CONTRACT_2026-04-04.md](/home/home/personal/zide/docs/review/TERMINAL_WIDGET_RETAINED_UPDATE_CONTRACT_2026-04-04.md)
  - Landed in:
    - [terminal_widget_surface_presenter.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_surface_presenter.zig)
    - [terminal_widget_retained_state.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_retained_state.zig)
  - What changed:
    - retained partial-plan scratch storage now has one explicit owner in
      `RetainedState`
    - presenter update planning now runs through one
      `RetainedSurfaceUpdatePlan` instead of stitching:
      - texture recreation
      - full vs partial choice
      - viewport shift
      - full-frame fast path
      - partial-plan attachment
      inline inside `updateAndPresent(...)`
  - Current bar reached:
    - retained update planning now reads like one presenter contract instead
      of several helper families plus raw widget-owned arrays
    - the remaining retained-surface contradiction is narrower and now sits on
      execution/present handoff, not scratch-plan ownership
- [x] `TWS-2-03` Collapse retained full/partial span traversal into one execution contract
  - Current authority:
    - [TERMINAL_WIDGET_RETAINED_UPDATE_CONTRACT_2026-04-04.md](/home/home/personal/zide/docs/review/TERMINAL_WIDGET_RETAINED_UPDATE_CONTRACT_2026-04-04.md)
  - Landed in:
    - [terminal_widget_surface_presenter.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_surface_presenter.zig)
  - What changed:
    - full and partial retained updates now share one draw-span traversal
      contract for:
      - background execution
      - glyph execution
    - row/span iteration no longer lives twice in the main presenter body
      with separate full and partial branch logic
  - Current bar reached:
    - retained execution now consumes one shared span contract
    - the remaining retained contradiction is narrower again and centered on
      present-or-fallback choreography plus kitty under/over sequencing
- [x] `TWS-2-04` Collapse retained post-update present choreography into one contract
  - Current authority:
    - [TERMINAL_WIDGET_RETAINED_UPDATE_CONTRACT_2026-04-04.md](/home/home/personal/zide/docs/review/TERMINAL_WIDGET_RETAINED_UPDATE_CONTRACT_2026-04-04.md)
  - Landed in:
    - [terminal_widget_surface_presenter.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_surface_presenter.zig)
  - What changed:
    - retained availability refresh, readiness truth, viewport clip, present
      logging, and final retained-surface present now flow through one
      `RetainedSurfacePresentState`
    - the presenter no longer carries separate `updated` vs `ready` clip
      branches plus a later availability/present tail
  - Current bar reached:
    - retained present-or-fallback choreography is now one explicit presenter
      seam
    - the remaining retained contradiction is mostly text/kitty sequencing
      inside retained execution, not readiness bookkeeping
- [x] `TWS-2-05` Collapse retained text and kitty sequencing into one execution contract
  - Current authority:
    - [TERMINAL_WIDGET_RETAINED_UPDATE_CONTRACT_2026-04-04.md](/home/home/personal/zide/docs/review/TERMINAL_WIDGET_RETAINED_UPDATE_CONTRACT_2026-04-04.md)
  - Landed in:
    - [terminal_widget_surface_presenter.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_surface_presenter.zig)
  - What changed:
    - retained background, kitty-under, glyph, and kitty-over execution now
      flow through one `executeRetainedSurfaceUpdate(...)`
    - full and partial retained update branches no longer each own their own
      separate content sequencing body in the main presenter path
  - Current bar reached:
    - retained content sequencing now reads like one presenter execution
      contract
    - the remaining retained contradiction is now higher-level retained
      policy, especially sync-update fast path versus retained update/present
      behavior
- [x] `TWS-3-01` Centralize resolved cell style and cursor-cell policy in the grid painter
  - Landed in:
    - [terminal_widget_draw_grid.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw_grid.zig)
  - What changed:
    - one `ResolvedTerminalCellStyle` now owns per-cell:
      - resolved foreground/background
      - block-cursor coverage
      - underline state/color
      - blink visibility
      - width units
    - direct, special, shaped, and fallback glyph paths now consume that same
      resolved style instead of re-deriving their own partial cursor/color
      semantics
    - powerline special-sprite seam matching now compares against the resolved
      neighbor background, including cursor-swapped cells
    - focused tests now lock the shared block-cursor and blink-visibility
      behavior
  - Current bar reached:
    - the grid painter no longer has separate branch-owned answers for cursor
      color inversion versus fallback/direct/shaped/special paths
    - a cell-style bug now has one shared owner to pressure instead of four
      optimized branches
- [x] `TWS-4-01` Collapse widget input around a smaller terminal action contract
  - Landed in:
    - [terminal_widget_input_adapter.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_input_adapter.zig)
    - [terminal_widget_input.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_input.zig)
    - [terminal_widget_keyboard.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_keyboard.zig)
    - [terminal_widget_pointer.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_pointer.zig)
    - [terminal_widget_output_protocol_mouse.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_output_protocol_mouse.zig)
    - [terminal_widget_paste.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_paste.zig)
    - [terminal_widget_command/open.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_command/open.zig)
    - [terminal_widget.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget.zig)
  - What changed:
    - keyboard, pointer, mouse reporting, paste, ctrl-open, and OSC clipboard
      polling now go through one `TerminalInputAdapter`
    - the leaf input files no longer import raw session/core modules directly
    - the widget input side now reads more like one terminal action contract
      and less like scattered direct access into session interaction, input,
      selection, scrollback, and host queries
  - Current bar reached:
    - the native terminal widget no longer looks session-shaped from the
      majority of the input leaf surface
    - remaining input pressure is now narrower and more honest than the old
      grab bag of direct VT/session verbs
- [x] `TWS-5-01` Push debug/investigation ownership out of the main widget shell
  - Landed in:
    - [terminal_widget_debug_capture.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_debug_capture.zig)
    - [terminal_widget.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget.zig)
    - [terminal_widget_keyboard.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_keyboard.zig)
  - What changed:
    - visible dump formatting, geometry/sample printing, ASCII capture, and
      debug log emission now live behind one explicit debug helper
    - `TerminalWidget.dumpVisibleAsciiView(...)` is now only a thin delegation
      seam instead of the home of the whole investigation script
    - the keyboard hotkey path no longer assembles debug logging inline
  - Current bar reached:
    - investigation usefulness remains intact
    - but the main widget shell is no longer the default storage site for dump
      formatting and debug log choreography
- [x] `TWS-5-02` Move debug sample storage behind one explicit debug owner
  - Current authority:
    - [TERMINAL_WIDGET_DEBUG_STATE_CONTRACT_2026-04-04.md](/home/home/personal/zide/docs/review/TERMINAL_WIDGET_DEBUG_STATE_CONTRACT_2026-04-04.md)
  - Landed in:
    - [terminal_widget_debug_geometry.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_debug_geometry.zig)
    - [terminal_widget.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget.zig)
    - [terminal_widget_draw.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw.zig)
    - [terminal_widget_draw_overlay.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw_overlay.zig)
    - [terminal_widget_surface_presenter.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_surface_presenter.zig)
    - [terminal_widget_debug_capture.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_debug_capture.zig)
  - What changed:
    - debug sample storage now lives behind one `DebugCaptureState`
    - the widget shell no longer stores the four geometry/text/surface sample
      fields directly
  - Current bar reached:
    - investigation artifacts now read like one explicit debug-state owner
    - the next controller-identity pressure is stronger and more structural
      than sample storage alone
- [x] `TWS-6-01` Rerank the widget stack against the host-side VT maturity bar
  - Current authority:
    - [TERMINAL_WIDGET_POST_FRONT_RERANK_2026-04-04.md](/home/home/personal/zide/docs/review/TERMINAL_WIDGET_POST_FRONT_RERANK_2026-04-04.md)
  - Current judgment:
    - this lane should continue
    - the strongest remaining contradiction is now retained-surface update
      planning and damage ownership
    - the next honest front is:
      - [terminal_widget_surface_presenter.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_surface_presenter.zig)
      - [terminal_widget_draw_texture.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw_texture.zig)
      - [terminal_widget_retained_state.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_retained_state.zig)
- [x] `TWS-6-02` Collapse widget controller-local state behind one explicit owner
  - Current authority:
    - [TERMINAL_WIDGET_CONTROLLER_STATE_CONTRACT_2026-04-04.md](/home/home/personal/zide/docs/review/TERMINAL_WIDGET_CONTROLLER_STATE_CONTRACT_2026-04-04.md)
  - Landed in:
    - [terminal_widget_controller_state.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_controller_state.zig)
    - [terminal_widget.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget.zig)
    - [terminal_widget_draw.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw.zig)
    - [terminal_widget_draw_overlay.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw_overlay.zig)
    - [terminal_widget_input.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_input.zig)
    - [terminal_widget_pointer.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_pointer.zig)
    - [terminal_widget_surface_presenter.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_surface_presenter.zig)
  - What changed:
    - focus-reporting, UI focus, hover, blink/recent-input, pending action,
      and selection gesture state now live behind one
      `TerminalWidgetControllerState`
    - the widget shell no longer stores those controller-local concerns as
      loose top-level fields
    - draw, input, pointer selection, and retained fast-path heuristics now
      consume that named controller owner instead of raw widget baggage
  - Current bar reached:
    - pane-local controller state now reads like one explicit host-side owner
    - the next widget contradiction is no longer loose controller fields by
      default
    - the remaining question is which surviving top-level widget buckets still
      need hostile scrutiny from this cleaner controller baseline
- [x] `TWS-6-03` Collapse widget publication/cache ownership behind one explicit owner
  - Current authority:
    - [TERMINAL_WIDGET_PUBLICATION_STATE_CONTRACT_2026-04-04.md](/home/home/personal/zide/docs/review/TERMINAL_WIDGET_PUBLICATION_STATE_CONTRACT_2026-04-04.md)
  - Landed in:
    - [terminal_widget_publication_state.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_publication_state.zig)
    - [terminal_widget.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget.zig)
    - [terminal_widget_draw.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw.zig)
    - [terminal_widget_input.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_input.zig)
    - [terminal_widget_debug_capture.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_debug_capture.zig)
    - [terminal_widget_paste.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_paste.zig)
    - [terminal_widget_surface_presenter.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_surface_presenter.zig)
    - [post_preinput_hooks_runtime.zig](/home/home/personal/zide/src/app/post_preinput_hooks_runtime.zig)
  - What changed:
    - `RenderCache` lifetime, latest publication capture preparation, and
      widget-facing terminal read-model derivation now live behind one
      `TerminalWidgetPublicationState`
    - the widget shell no longer stores raw `draw_cache`
    - draw, input, debug, paste, presenter, and cursor-blink app logic now
      consume explicit publication/view truth instead of raw widget cache
      storage
  - Current bar reached:
    - publication/cache truth is no longer ambient widget-shell baggage
    - the strongest remaining widget contradiction is now narrower than
      controller plus publication plus retained mixed ownership
- [x] `TWS-6-04` Collapse presenter-side kitty and retained buckets behind one surface owner
  - Current authority:
    - [TERMINAL_WIDGET_SURFACE_STATE_CONTRACT_2026-04-04.md](/home/home/personal/zide/docs/review/TERMINAL_WIDGET_SURFACE_STATE_CONTRACT_2026-04-04.md)
  - Landed in:
    - [terminal_widget_surface_state.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_surface_state.zig)
    - [terminal_widget.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget.zig)
    - [terminal_widget_draw.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw.zig)
    - [terminal_widget_surface_presenter.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_surface_presenter.zig)
  - What changed:
    - kitty image state and retained surface state now live behind one
      `TerminalWidgetSurfaceState`
    - the widget shell no longer stores `kitty` and `retained` as separate
      top-level buckets
    - draw and presenter flow now consume a named surface owner for:
      - alt-screen lifecycle transition tracking
      - kitty prepare/finish draw
      - retained readiness and last-render generation
      - texture-cache invalidation
  - Current bar reached:
    - the widget shell now reads much more like:
      - session
      - controller
      - publication
      - surface
      - debug
    - the next widget contradiction is no longer split top-level surface
      buckets by default
- [x] `TWS-6-05` Collapse retained bookkeeping behind the surface owner
  - Current authority:
    - [TERMINAL_WIDGET_RETAINED_BOOKKEEPING_CONTRACT_2026-04-04.md](/home/home/personal/zide/docs/review/TERMINAL_WIDGET_RETAINED_BOOKKEEPING_CONTRACT_2026-04-04.md)
  - Landed in:
    - [terminal_widget_surface_state.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_surface_state.zig)
    - [terminal_widget_surface_presenter.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_surface_presenter.zig)
  - What changed:
    - retained update deltas, retained update completion, retained target
      availability, and partial-plan access now flow through the surface owner
    - the presenter no longer carries broad direct retained-state field
      mutation and comparison
  - Current bar reached:
    - retained bookkeeping is no longer a broad presenter leak
    - if this lane continues, the next contradiction must be a higher-level
      presenter policy seam
- [x] `TWS-6-06` Rerank the widget lane after controller/publication/surface cleanup
  - Current authority:
    - [TERMINAL_WIDGET_POST_SURFACE_RERANK_2026-04-04.md](/home/home/personal/zide/docs/review/TERMINAL_WIDGET_POST_SURFACE_RERANK_2026-04-04.md)
  - Current judgment:
    - this lane is close to a stop-marker
    - the widget shell now looks materially more deliberate
    - only one plausible local continuation remains:
      - sync-update fast-present policy versus retained update/present fallback
    - that continuation does not win by default from momentum alone

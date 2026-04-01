# Terminal Native Architectural Scrutiny

Date: 2026-03-31

Scope:

- current native terminal implementation on `main`
- engine/host/publication/presentation boundaries
- fallback-path, compatibility-residue, and hack-shaped ownership smells

This is a high-level architectural audit, not a bug diary.
It is written against the current authority docs and the strongest local
references:

- `ghostty`
- `wezterm`
- `alacritty`
- `kitty`

The standard applied here is intentionally strict:

- DRY
- loosely coupled
- one obvious owner per behavior
- minimal compatibility residue
- native path proves the engine contract, not a privileged semantic path

## Executive Judgment

Zide's native terminal architecture is no longer in the "rewrite chaos" phase.
It already has a real engine center, a real transport split, and a real
publication/presentation vocabulary. The remaining issues are now higher-order:

- too much public/root-shell surface area
- too much semantic work still living in host-facing glue seams
- too much duplicated published state
- too much native-path coordination still depending on session/export shells

The main structural problem is no longer "raw VT semantics are scattered
everywhere." The main structural problem is that the system still has too many
coordination shells and mirrors around the true engine.

In short:

- `TerminalCore` is real
- but it is still not obviously the only center
- the old `TerminalSession` center has now been renamed publicly to
  `PtyTerminalRuntime`, but the remaining wrapper/module gravity still needs to
  be cut down further
- widget/render code is still too large and too intimate with publication
  details
- publication still duplicates more state than a best-in-class engine boundary
  should

## Sequential Findings

### 1. `PtyTerminalRuntime` is still too large to be the right public center

Primary files:

- `src/terminal/core/pty_terminal_runtime.zig`
- `src/terminal/core/terminal_runtime.zig`
- `src/terminal/core/terminal_publication.zig`

Evidence:

- `pty_terminal_runtime.zig` is still `791` lines and acts as the root public
  facade for:
  - runtime
  - input
  - protocol
  - rendering/publication
  - content queries
  - selection
  - host queries
  - debug helpers
- the old `terminal.zig` root barrel was deleted after the explicit runtime and
  publication surfaces took over native/widget/FFI/replay/test/smoke call
  paths

Judgment:

- this is cleaner than the older monolith, but still not best-in-class
- the system still reads as "many focused helpers behind one broad god-facade"
  rather than "engine plus narrow host wrapper"
- the newly introduced explicit surfaces
  - `src/terminal/core/terminal_runtime.zig`
  - `src/terminal/core/publication/terminal_publication.zig`
  are the right direction because they give native/FFI/widget consumers an
  enforced explicit entrypoint instead of a broad root barrel
- replay/test debug imports are cleaner now too: they target
  `src/terminal/core/session/debug_api.zig` directly instead of going
  through a flat `terminal_debug.zig` shim
- the old mixed alias hub `src/terminal/core/session_public_types.zig` is also
  gone, which is an honest improvement: `pty_terminal_runtime.zig` now imports
  direct owners instead of hiding public-facing types behind one more helper
  facade
- `src/terminal/core/terminal_runtime.zig` still appears to be the right stable
  public surface, but it no longer routes shared input/selection/progress
  types through `pty_terminal_runtime.zig`; those names now come from their
  direct `session/` owners instead of reinforcing wrapper gravity
- the same cleanup now applies to selection gesture types and key-mode flag
  access, so the public runtime surface depends less on wrapper-owned aliases
  even while staying a stable entrypoint
- the same cleanup now applies in `workspace.zig`, which no longer carries
  stale `session_mod` vocabulary or wrapper-routed progress-state typing
- the PTY runtime regression tests now follow the same rule for snapshot,
  cell/color, dirty-state, and progress-state imports instead of reinforcing
  wrapper gravity through test-only barrel usage
- `src/terminal/core/session/runtime_api.zig` and
  `src/terminal/core/session/publication_api.zig` now carry the runtime and
  publication/present method groups that were previously written inline on
  `pty_terminal_runtime.zig`
- `src/terminal/core/session/runtime.zig`,
  `src/terminal/core/session/input.zig`,
  `src/terminal/core/session/config.zig`, and
  `src/terminal/core/session/interaction.zig` now carry the wrapper behavior
  seams without redundant `session_` naming inside the subtree
- `src/terminal/core/session/input_api.zig` now carries the host input
  send/report method group that was previously written inline on
  `pty_terminal_runtime.zig`
- `src/terminal/core/protocol/terminal_protocol_api.zig` now carries the protocol/VT
  mutation method group that was previously written inline on
  `pty_terminal_runtime.zig`
- the stale `src/terminal/core/session_protocol.zig` forwarding shell is now
  deleted, so that API seam no longer routes through one extra session-named
  hop before reaching the real owners
- `src/terminal/core/session/config_api.zig` now carries the config, palette,
  and mode-setting method group that was previously written inline on
  `pty_terminal_runtime.zig`
- the remaining publication/view-cache helper stubs and the special-case
  `appendHyperlink` wrapper no longer live inline on `pty_terminal_runtime.zig`
- `src/terminal/core/session/debug_api.zig` now owns the debug method group
  instead of making `pty_terminal_runtime.zig` the visible debug authority
- `src/terminal/core/session/content.zig` and
  `src/terminal/core/session/content_api.zig` now carry the wrapper content
  seam without redundant `session_` naming inside the subtree
- `src/terminal/core/session/runtime.zig`,
  `src/terminal/core/session/config.zig`,
  `src/terminal/core/session/input.zig`,
  `src/terminal/core/session/interaction.zig`,
  `src/terminal/core/session/queries.zig`,
  `src/terminal/core/session/selection.zig`,
  `src/terminal/core/session/host_queries.zig`,
  `src/terminal/core/session/host_types.zig`,
  `src/terminal/core/session/init_options.zig`,
  `src/terminal/core/session/input_snapshot.zig`,
  `src/terminal/core/session/presentation_feedback.zig`,
  `src/terminal/core/session/lifecycle.zig`,
  `src/terminal/core/session/mode_effects.zig`,
  `src/terminal/core/session/publication_state.zig`,
  `src/terminal/core/session/publication_updates.zig`,
  `src/terminal/core/session/presentation_handoff.zig`,
  `src/terminal/core/session/thread_runtime.zig`, and
  `src/terminal/core/session/transport_runtime.zig` now follow the same rule:
  subtree ownership is explicit, so the repeated `session_` prefix is gone
- `src/terminal/core/session/lifecycle_api.zig` now owns the lifecycle and
  composition block instead of leaving those direct methods written on the root
  session type
- `src/terminal/core/session/surface_api.zig` now owns the giant content,
  selection, host-query, and interaction alias surface instead of leaving that
  umbrella slab at the top of `pty_terminal_runtime.zig`
- `src/terminal/core/session/types_api.zig` now owns the shared constant/type
  export slab instead of leaving that import-umbrella surface at the bottom of
  `pty_terminal_runtime.zig`
- the flat root state is now also grouped into explicit subsystem-owned
  embedded structs:
  - `session/publication_fields`
  - `session/runtime_fields`
  - `session/interaction_fields`
  - `session/control_fields`
- the first honest directory cut is now in too:
  truly session-owned API/field/debug seams live under
  `src/terminal/core/session/` instead of continuing to sprawl as a flat
  prefix beside engine-owned files
- that subtree is now broad enough to be meaningful:
  runtime, lifecycle, publication-state, publication-update, presentation-
  handoff, content, queries, selection, interaction, and config helpers that
  are still truly wrapper-owned now live there too
- the last obviously wrapper-owned flat residue is now there as well:
  host metadata/types, init options, input send/report helpers, input
  snapshot state, and presentation feedback structs also live under
  `src/terminal/core/session/`
- wrapper-only debug and text-export helpers now also live under the same
  session home:
  `src/terminal/core/session/debug_ops.zig` and
  `src/terminal/core/session/text_export.zig`
- the next honest peer subtree is now in too:
  publication-owned cache, snapshot, and publication helper files now live
  under `src/terminal/core/publication/` instead of continuing to sprawl as
  another flat cluster beside engine-owned files
- that publication home is now broader and more honest:
  the published-view builder and its plan/damage/selection helpers now also
  live under `src/terminal/core/publication/`
- dead core wrapper residue is now being deleted too:
  `state_reset.zig` and `terminal_core_reset.zig` no longer exist as one-line
  pass-through seams
- the next honest peer subtree is now in too:
  parser/protocol execution files now live under
  `src/terminal/core/protocol/` instead of continuing to sprawl as a flat
  execution cluster beside engine-owned files
- the next honest peer subtree is now in too:
  transport/poll/thread runtime execution files now live under
  `src/terminal/core/runtime/` instead of continuing to sprawl as a flat
  runtime cluster beside engine-owned files
- current judgment:
  - this is no longer just "a broad session file with helpers extracted"
  - it is now allocator/core plus grouped subsystems and explicit API seams
  - the rename has already happened
  - the next real question is whether that shell is honest enough to keep,
    not whether more random helper extraction is needed

Why it matters:

- the broad facade makes accidental privileged reach-through cheap
- it hides which contracts are actually stable and narrow
- it keeps native and FFI tempted to depend on the same broad shell instead of
  a more explicit engine/publication boundary

### 2. Printable-text semantics are cleaner, but the final text-effect seam is still too host-shaped

Primary files:

- `src/terminal/core/protocol/terminal_core_text.zig`
- `src/terminal/core/protocol/terminal_protocol_api.zig`
- `src/terminal/core/protocol/control_handlers.zig`

Evidence:

- printable text no longer routes through `parser_hooks.zig`
- codepoint/ASCII traffic now routes directly into `terminal_core_text.zig`
- the dead `terminal_core_dispatch.zig` middleman is now deleted
- `terminal_core_text.zig` now reads core-owned text state directly from
  `TerminalCore` for:
  - active screen access
  - GL charset selection
  - hyperlink attribute application
- the dead `TextContext` adapter layer is now gone too:
  `terminal_core_text.zig` talks directly to `self.core` plus protocol-owned
  effects instead of routing through one more wrapper-shaped contract
- the parser-facing forwarding shell is now gone too:
  `terminal_protocol_api.zig` routes DCS/APC/OSC/CSI traffic directly to the
  real protocol owners instead of stepping through `parser_hooks.zig`
- the `TextEffects` adapter layer is gone too:
  `terminal_core_text.zig` already calls protocol-owned functions directly, so
  `terminal_core_protocol.zig` no longer carries that extra wrapper type
- the remaining callback seam is narrower:
  - wrap/newline effects
  - insert-mode char insertion effects
- that effect seam now lives with protocol ownership in
  `terminal_core_protocol.zig` instead of being wired inline inside the text
  module
- the same ownership correction is now broader:
  newline, wrap-newline, and reverse-index no longer live in
  `control_handlers.zig`; they now live with the rest of the protocol effect
  surface in `terminal_core_protocol.zig`

Reference comparison:

- Ghostty drives parser actions more directly into terminal methods
- Zide has killed the old parser-hook ownership lie, but text execution still
  depends on a host-shaped effect boundary where the strongest references are
  more terminal/protocol-owned

Judgment:

- this is still one of the strongest remaining "wrong layer" smells
- even if it is not the current root cause of any specific bug, it is not the
  cleanest engine shape

### 3. Publication state is duplicated and mirrored too broadly

Primary files:

- `src/terminal/core/render_cache.zig`
- `src/terminal/core/publication/view_cache.zig`
- `src/terminal/core/session_rendering.zig`
- `src/terminal/core/session/presentation_handoff.zig`

Evidence:

- `snapshot()` sometimes returns direct screen-owned state and sometimes a
  render-cache view
- `RenderCache` duplicates a large amount of terminal-visible state:
  - cells
  - dirty rows
  - dirty spans
  - cursor
  - selection projection
  - kitty state
  - scrollback/publication metadata
- `capturePresentation(...)` and `copyPublishedRenderCache(...)` still copy
  large cache snapshots under the session shell
- until the latest cuts, generation vocabulary also overstated one internal
  field as if it were the published truth
  - live code now distinguishes:
    - `pendingGeneration`
    - `publishedGeneration`
    - `presentedGeneration`
  - `snapshot().generation` now reports the published cache generation it
    actually returns

Judgment:

- the publication contract is now explicit, which is good
- but the implementation still feels heavier than ideal because published state
  is mirrored, copied, and coordinated in several places
- this lane is no longer purely theoretical:
  - `RenderCache.total_lines` has already been deleted because it was merely
    `history_len + rows` stored as duplicate cache truth
  - `RenderCache.selection_active` has also been deleted because projected
    selection rows already make selection presence derivable from the cache
  - `view_cache.zig` no longer hand-expands the same broad publication-state
    equality check inline; that contract now lives in
    `RenderCache.matchesPublishedState(...)`
  - `view_cache_publication.zig` now owns part of the publication fast-path
    decision surface (`canSkipPublish`, `canCleanAdvancePublish`,
    `applyCleanAdvancePublish`) instead of leaving that logic smeared inline in
    `view_cache.zig`
  - stale rendering-investigation probe residue is now being purged from the
    live widget/runtime path instead of being normalized as architecture:
    Scroll Lock capture plumbing, widget-side generation shadow state,
    frame-provenance/column probes, and row-pass/fullframe-fastpath probe logs
    do not belong in the permanent terminal design
  - the same rule applies to low-level terminal narration generally:
    draw/cache/parser/poll logs that are not defending a warning path,
    lifecycle edge, contract, or subsystem boundary are stale probe debt in a
    different costume and should be deleted
  - it also now owns projected-diff eligibility and full-dirty metadata
    assignment, which further reduces the amount of publication rule text
    living inline in `view_cache.zig`
  - baseline dirty-row/span/scroll-shift setup is now moving there too, which
    means `view_cache.zig` is losing raw cache-array choreography as well as
    decision logic
  - the copied-from-view dirty-column path and its broad-span logging now live
    there as well, which removes another large inline publication island from
    `view_cache.zig`
  - published cache finalization now lives there as well, which means
    `view_cache.zig` is also losing the hand-written block that assigned blink,
    mode, clear-generation, and viewport-shift state directly
  - visible-cell population now lives there too, which removes the history/grid
    copy loop as another inline publication responsibility from `view_cache.zig`
  - row-hash refinement gating and broad refined-span logging now live with the
    refinement seam too, which removes another renderer-facing decision island
    from `view_cache.zig`
  - widget code is also starting to ask publication explicit questions
    (`viewportInfo`, `scrollbarAllowed`, `drawCursorVisible`, `altTransition`)
    instead of re-deriving those answers ad hoc from raw cache fields
  - widget draw now also asks publication for partial-capture interpretation
    (`partialCaptureInfo`) instead of rebuilding viewport-shift/capture-reason
    logic directly from raw cache flags
  - widget draw now also asks publication for render-state interpretation
    (`renderStateInfo`) instead of reading screen-reverse/cursor/blink state
    directly off raw cache fields each time
  - widget debug/background-run helpers now also ask publication for
    `backgroundRunInfo` instead of reading cursor/screen-reverse state directly
    off raw cache fields
  - widget visible-view diagnostics now also ask publication for
    `visibleViewDumpInfo` instead of hand-assembling another cache header
    inside the widget layer
  - widget scroll models now also ask publication for `scrollbarInfo`
    instead of rebuilding allowed/rows/total-lines/offset from multiple
    cache-derived calls
  - widget lifecycle logging now also asks publication for
    `lifecycleTransitionInfo` instead of repeating inline alt-state
    interpretation in draw code
  - widget draw now also asks publication for `dirtySummary` instead of
    rebuilding dirty-tag/current-reason/dirty-row-count/damage-span/bounds
    state inline from raw cache fields
  - widget draw now also asks publication for `drawStateInfo` instead of
    pulling rows/cols/viewport/render/sync/kitty/cursor facts piecemeal from
    raw cache state
  - widget draw now also uses that same draw-state helper for generation and
    clear-generation bookkeeping instead of scattering raw cache generation
    reads through planning/coherence/handoff paths
  - widget draw now also uses that same draw-state helper for the published
    cell slice and kitty image/placement slices instead of reaching directly
    into cache storage for those arrays
  - widget draw now also asks publication for `baseColorInfo` instead of
    rebuilding first-cell background and reverse-resolved background logic in
    multiple branches
  - the widget-owned partial-plan accounting blob is now isolated in
  - surviving widget-local planning state is now narrower and more honest:
    `ViewportShiftState` owns the viewport-shift seam
    instead of being passed through texture-shift logic as loose locals
  - `PresentPressureState` owns the present-pressure seam instead of leaving
    recent-input/full-frame planning smeared across update-plan forcing and
    pressure logging
  - widget draw handoff/log snapshot state was reduced to one narrow local seam
    (`HandoffState`) instead of repeating the same generation reads across
    plan/commit logs
  - the stronger correction now applies to those draw-log seams too:
    formatting-buffer and logger-handle slabs that only existed to support
    low-level narration are not a structure to preserve; they are debt to
    delete
  - widget draw now also uses helper-owned current alt-state and clean-state
    instead of falling back to raw `cache.alt_active` and repeated
    `cache.dirty == .none` checks where publication already owns the answer
    inside the widget layer
  - that is the standard the rest of the publication war should keep:
    if a cache field is just restating derivable published state, it should die

Why it matters:

- duplication increases the number of "truth-shaped" surfaces
- it makes retirement/ack/damage bugs more likely
- it keeps native rendering tightly coupled to publication internals

### 4. Native widget draw is still too large and too privileged

Primary files:

- `src/ui/widgets/terminal_widget_draw.zig`
- `src/ui/widgets/terminal_widget.zig`

Evidence:

- `terminal_widget_draw.zig` is `1731` lines
- it owns:
  - draw prep
  - texture update planning
  - capture/presentation handoff participation
  - frame metrics
  - generation summaries
  - investigation logging
  - terminal-specific rendering heuristics

Judgment:

- this is not just "renderer glue"
- it is a large native-host coordination shell with too much intimate
  knowledge of terminal publication state

Why it matters:

- oversized widget draw code is a recurring place for native-only truths to
  creep back in
- it makes the presentation layer harder to reason about as a pure host
  consumer of published state

### 5. The current publication/present split is improved, but still too
session-centered

Primary files:

- `src/terminal/core/session/publication_state.zig`
- `src/terminal/core/session/publication_updates.zig`
- `src/terminal/core/session/presentation_handoff.zig`

Evidence:

- these are now nicely split, but still fundamentally operate as helper seams
  over session-owned caches and locks
- acknowledgement, damage retirement, and view-cache refresh still depend on
  the session shell as the coordination center

Judgment:

- this is better than the old blob
- but it is still "session-centered publication split into files," not yet the
  cleanest engine-centered publication object model

### 6. The old shared snapshot adapter deserved deletion, not preservation

Former file:

- `src/terminal/core/snapshot_adapter.zig`

Evidence:

- the adapter returned an almost-empty placeholder shared snapshot
- it carried an explicit TODO saying the mapping waited on a future split
- its only tests locked in that knowingly false placeholder contract

Judgment:

- that seam was not a real boundary; it was a stub pretending to be one
- deleting it is stronger than preserving a fake shared contract in live code

Why it matters:

- if Zide wants native and FFI to sit on one engine truth, the shared snapshot
  seam cannot stay stub-shaped for long

### 7. Re-export patterns still blur the intended contract

Primary files:

- `src/terminal/core/terminal_runtime.zig`
- `src/terminal/core/terminal_publication.zig`
- `src/terminal/core/pty_terminal_runtime.zig`

Evidence:

- public types and methods are re-exported through multiple files
- the remaining re-export surfaces can still hide whether callers are using:
  - engine truth
  - host wrapper convenience
  - publication surface
  - debug/replay surface

Judgment:

- this is not a correctness bug
- it is contract blur, and contract blur creates architectural drift

### 8. Runtime/transport is acceptably split, but still assembled as a shell

Primary files:

- `src/terminal/core/session/runtime.zig`
- `src/terminal/core/session/transport_runtime.zig`
- `src/terminal/core/session/thread_runtime.zig`
- `src/terminal/core/runtime/pty_io.zig`

Evidence:

- runtime and transport ownership are much improved
- but they still read as an extracted assembly shell around `PtyTerminalRuntime`,
  not as a more self-contained host/runtime boundary object

Judgment:

- this is no longer the worst problem
- but it is still a center-of-gravity issue

### 9. Debug and investigation hooks are still embedded in live native seams

Primary files:

- `src/ui/widgets/terminal_widget_draw.zig`
- `src/terminal/parser/parser.zig`
- `src/debug/capture_burst.zig`

Evidence:

- Scroll Lock capture and parser-side burst logging now live in production-path
  files
- they are gated, but the live path still carries ad hoc investigation seams

Judgment:

- good for short-term debugging
- not good as a long-term architectural habit

Why it matters:

- deep live-path probes become invisible structural debt if they are not
  retired quickly

### 10. There are still compatibility mirrors and dual surfaces in the
publication contract

Primary files/docs:

- `app_architecture/terminal/VT_CORE_DESIGN.md`
- `src/terminal/core/render_cache.zig`
- `src/terminal/core/snapshot.zig`

Evidence:

- the docs already acknowledge compatibility/export mirrors
- publication exposes both detailed span state and older union-style fields
- snapshot/render-cache/publication state still contains signs of evolutionary
  layering rather than one final clean contract

Judgment:

- some of this is intentional
- but best-in-class quality eventually means deleting the mirrors, not merely
  documenting them

## Largest Potential Changes For Maximum Payoff

1. Make `TerminalCore` plus an explicit publication object the true public
   center, and shrink `PtyTerminalRuntime` into a narrow host/runtime wrapper.
2. Delete parser-owned semantic text handling from `parser_hooks.zig` by moving
   printable write behavior fully below the VT action boundary.
   Progress note, 2026-04-01, later:
   printable text no longer routes through `parser_hooks.zig`; that seam now
   handles parser-control surfaces only, while printable codepoint/ASCII
   dispatch goes directly through `terminal_core_dispatch.zig` into
   `terminal_core_text.zig`.
3. Keep shrinking `pty_terminal_runtime.zig` now that `terminal.zig` is dead, and
   stop re-exporting broad mixed ownership through runtime/publication helper
   surfaces where direct ownership types would be clearer.
4. Collapse duplicated publication state so one canonical published snapshot
   shape exists, instead of parallel screen/view-cache/render-cache truths.
5. Split native widget draw into smaller renderer-facing units and stop letting
   widget draw participate so directly in terminal publication choreography.
6. Replace the current session-centered publication helpers with a more
   explicit publication/present state object that owns generation, pending, and
   retirement logic directly.
7. Finish the shared snapshot adapter seam so native and shared/FFI consumers
   stop depending on separate snapshot-shaped contracts.
8. Remove remaining compatibility mirrors from publication fields once replay
   and FFI authority can cover the cut.
9. Move investigation/debug capture plumbing out of hot production files into a
   reusable debug instrumentation seam.
10. Re-audit the native widget surface and forbid new terminal semantics from
    landing there unless they are clearly host chrome or input mapping.

## Priority Order

If the goal is maximum architectural payoff rather than minimum risk, the best
order is:

1. shrink the public/root surface
2. move printable semantics below the VT boundary
3. collapse publication duplication
4. shrink widget draw and native present choreography
5. retire mirrors and stubs

If the goal is safer incremental execution, the order is:

1. shared snapshot/public contract cleanup
2. root facade reduction
3. widget draw decomposition
4. parser-hook printable-write migration
5. publication object cleanup

## Recommended Near-Term Rule Changes

These should be treated as explicit architecture rules for future terminal
work:

- no new terminal semantics in widget files
- no new host-policy convenience in `PtyTerminalRuntime`
- no new publication mirrors unless they are temporary and deletion is planned
- no parser-hook behavior that mutates terminal semantics if the engine can own
  it directly
- no investigation scaffolding left in hot files after the owning bug lane
  cools

## Final Assessment

The terminal architecture is no longer suffering from lack of direction.
It is suffering from incomplete convergence.

The biggest payoff is no longer another round of helper extraction for its own
sake. The biggest payoff is to stop tolerating multiple "almost-centers":

- root facade
- parser hook seam
- publication/cache shell
- oversized native widget draw shell

Until those converge further, Zide will keep feeling stronger than average at
the contract level, but weaker than the best references at obvious ownership.

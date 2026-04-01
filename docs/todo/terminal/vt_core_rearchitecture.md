# VT Core Rearchitecture TODO

## Scope

Continue the post-rewrite split that makes the terminal core the architectural center, with PTY, workspace, UI, and FFI layered around it.

## Constraints

- Preserve current desktop behavior while moving ownership.
- Keep the terminal core renderer-agnostic.
- Keep FFI aligned to the core boundary, not to desktop-only session structure.
- Prefer clean ownership cuts over compatibility sludge.
- Treat the native GUI as the reference host for the engine contract, not as a
  privileged terminal path with different semantics from FFI.
- Use `app_architecture/terminal/TERMINAL_SUBSYSTEM_LAYERS.md` when deciding
  which subsystem layer should own a change; do not infer ownership only from
  file placement or historical session structure.

## Current Direction

The passive cleanup phase is over. The active lane is now a deliberate assault
on every architectural seam that keeps `TerminalCore` from being the obvious
center. This is still iterative work, but it is no longer gentle work. Each
cut should remove a structural lie, not merely rearrange the same center of
gravity into smaller files.

## Priority Now

Highest-value remaining items, ranked against the current `libghostty-vt` comparison:

1. `VTCORE-01` break `PtyTerminalRuntime` as the architectural center
   Why: this is still the most visible fake center in the native terminal
   stack. As long as it reads like the real terminal, the architecture is
   lying on first glance.
2. `VTCORE-05` replace duplicated publication truth with an explicit engine-owned publication center
   Why: mirror-heavy publication state keeps native rendering and backend
   retirement too tightly coupled, and it weakens the contract story.
3. `VTCORE-04` move the remaining semantic text/protocol ownership below the VT boundary
   Why: parser-hook text semantics are still one of the clearest "wrong layer"
   smells versus the strongest references.
4. `VTCORE-02` keep the FFI boundary aligned with the stronger native contract
   Why: native must become the cleanest reference host over one engine truth,
   not a privileged semantic owner that FFI tries to imitate later.
5. `VTCORE-06` keep input encoding transport-agnostic as the rest of the kill-order proceeds
   Why: this must remain a peer subsystem, not collapse back into session glue.

Supporting cuts:

- `VTCORE-03` transport is already real; keep it narrow and prevent it from
  becoming a second semantic center
- `VTCORE-07` remains a guardrail: native must become the sharpest host, not a
  special host

Focused follow-up lane:

- `docs/review/TERMINAL_NATIVE_ARCHITECTURAL_SCRUTINY_2026-03-31.md`
  Why: this is the current ruthless read on what still looks second-rate at
  first glance and what should be demolished first.

## Current Milestone

Branch:

- `terminal-war`

Milestone rule:

- keep small checkpoint commits on `terminal-war`
- merge back into `main` once this milestone is validated
- do not stack the next milestone on top of an unmerged one

Current milestone: `M4` make publication center explicit

Merge goal:

- session/publication call paths should route through an explicit
  `terminal_publication` center
- the old `session_rendering` shell should stop acting as the visible
  publication truth center
- docs and validation should capture the ownership shift clearly enough that
  the merge to `main` is a real milestone, not a partial scratch state

Checklist:

- [x] explicit `publication/terminal_publication.zig` center exists
- [x] session/publication call paths route through `publication/terminal_publication`
- [x] `session_rendering.zig` removed from live call paths
- [x] milestone validation pass captured
- [x] milestone merged back into `main`

Validation note, 2026-03-31:

- passed:
  - `zig build test`
  - `zig build check-app-imports`
- ownership shift:
  - session/publication callers now route through
    `src/terminal/core/publication/terminal_publication.zig`
  - the old `src/terminal/core/session_rendering.zig` shell is removed

## TODO

- [x] `VTCORE-00` Define the terminal core boundary.
  Notes: the concrete boundary and target types now live in `app_architecture/terminal/VT_CORE_DESIGN.md`.
- [ ] `VTCORE-01` Separate VT core from host session/runtime.
  Notes: this is no longer a "trim a few helpers" item. This is the campaign to
  dethrone `PtyTerminalRuntime` as the visual and practical center of the
  terminal. Prior extractions still matter, but only insofar as they make
  deletion and decomposition easier. Judge every remaining method, re-export,
  and helper by one question: does it still make `PtyTerminalRuntime` look like
  the real terminal?
  Done when:
  - `PtyTerminalRuntime` no longer reads like the engine at first glance.
  - the public center is explicit and smaller than the current root facade.
  - remaining host/runtime assembly is narrow enough to justify either a hard
    rename or outright deletion of the current `PtyTerminalRuntime` shape.
  Current judgment:
  - helper extraction alone is no longer enough
  - the remaining problem is architectural theater: too many smaller files still
    preserve one broad fake center
  - this lane stays hot until that center is broken
  Progress note, 2026-03-31:
  - landed the first runtime/publication public-surface cut:
    - `src/terminal/core/terminal_runtime.zig`
    - `src/terminal/core/terminal_publication.zig`
  - native app/runtime, widget, FFI, replay-harness, smoke tools, and tests
    were moved onto those explicit surfaces.
  Progress note, 2026-04-01:
  - `src/terminal/core/terminal.zig` is deleted.
  - there is no broad root barrel left in live call paths.
  - this is the first real kill shot against the false public center:
    runtime/publication consumers now have to choose an explicit surface.
  - replay/test debug imports now target
    `src/terminal/core/session/debug_api.zig` directly, so there is no
    extra flat `terminal_debug.zig` shim pretending to be a core peer.
  - `src/terminal/core/session_public_types.zig` is deleted; `pty_terminal_runtime.zig`
    now imports direct ownership modules instead of routing public-facing types
    through a mixed alias hub.
  - the next extraction cut is also in:
    - `src/terminal/core/session/runtime_api.zig`
    - `src/terminal/core/session/publication_api.zig`
  - host/runtime and publication/present public methods are no longer written
    inline on `pty_terminal_runtime.zig`; they are now grouped behind explicit API
    modules and re-exported without behavior changes.
  - `src/terminal/core/session/input_api.zig` now groups the input send/report
    public methods that were previously written inline on
    `pty_terminal_runtime.zig`.
  - `src/terminal/core/protocol/terminal_protocol_api.zig` now groups the protocol/VT
    mutation public methods that were previously written inline on
    `pty_terminal_runtime.zig`.
  - `src/terminal/core/session/config_api.zig` now groups the config, palette,
    and mode-setting public methods that were previously written inline on
    `pty_terminal_runtime.zig`.
  - the remaining publication/view-cache helper stubs and the special-case
    protocol `appendHyperlink` wrapper are no longer written inline on
    `pty_terminal_runtime.zig`; those exceptions now route through the explicit
    publication/protocol API seams too.
  - `src/terminal/core/session/debug_api.zig` now owns the debug method
    group directly; `pty_terminal_runtime.zig`, replay, and tests point at the
    real seam instead of routing through an extra flat wrapper.
  - the wrapper-content seam now follows the same rule:
    `src/terminal/core/session/content.zig` and
    `src/terminal/core/session/content_api.zig` replace the redundant
    `session_content*` naming inside the already-explicit `session/` subtree.
  - `src/terminal/core/session/lifecycle_api.zig` now owns the lifecycle and
    composition block (`init`, screen access, input pressure, lock state,
    resize, shutdown-facing methods) that was still written directly on the
    session root.
  - `src/terminal/core/session/surface_api.zig` now owns the content,
    selection, host-query, and interaction alias slab that used to dominate
    the top of `pty_terminal_runtime.zig`.
  - `src/terminal/core/session/types_api.zig` now owns the bottom export slab
    for shared terminal constants and core-facing type aliases.
  - raw session state is no longer a flat lie:
    - `src/terminal/core/session/publication_fields.zig`
    - `src/terminal/core/session/runtime_fields.zig`
    - `src/terminal/core/session/interaction_fields.zig`
    - `src/terminal/core/session/control_fields.zig`
  - the first honest directory cut is now in too:
    the truly session-owned API, field, and debug seams live under
    `src/terminal/core/session/` instead of squatting as a flat `session_*`
    prefix beside engine-owned files
  - that subtree is now broader and more honest:
    runtime, lifecycle, publication-state, publication-update, presentation-
    handoff, content, queries, selection, interaction, and config helpers that
    are still genuinely wrapper-owned also live under
    `src/terminal/core/session/`
  - the last obviously wrapper-owned flat residue is now there too:
    host metadata/types, init options, input send/report helpers, input
    snapshot state, and presentation feedback structs now also live under
    `src/terminal/core/session/`
  - wrapper-only debug and text-export helpers now also live where they belong:
    `src/terminal/core/session/debug_ops.zig` and
    `src/terminal/core/session/text_export.zig`
  - the old `src/terminal/core/snapshot_adapter.zig` seam is deleted instead of
    being preserved as a knowingly false shared contract placeholder
  - the next honest peer subtree is now in too:
    publication-owned cache, snapshot, and publication helper files now live
    under `src/terminal/core/publication/` instead of continuing to sprawl as
    another flat cluster beside engine-owned files
  - that publication home is now broader and more honest:
    the published-view builder and its plan/damage/selection helpers now also
    live under `src/terminal/core/publication/`
  - dead core wrapper residue is now being deleted too:
    `state_reset.zig` and `terminal_core_reset.zig` no longer exist as
    one-line pass-through seams
  - the next peer subtree is now in too:
    parser/protocol execution files now live under
    `src/terminal/core/protocol/` instead of continuing to sprawl as a flat
    execution cluster beside engine and wrapper files
  - the next peer subtree is now in too:
    transport/poll/thread runtime execution files now live under
    `src/terminal/core/runtime/` instead of continuing to sprawl as a flat
    runtime cluster beside engine and wrapper files
  - `pty_terminal_runtime.zig` now reads as allocator/core plus grouped subsystem
    state and explicit API seams, not as one broad undifferentiated owner.
  - the rename threshold is now crossed:
    - the public PTY-backed wrapper type is now `PtyTerminalRuntime`
    - the old `TerminalSession` public type name is gone from live code paths
    - the old `terminal_session.zig` module path is also gone from live code
      paths; the wrapper now lives in `src/terminal/core/pty_terminal_runtime.zig`
  - `VTCORE-01` is no longer blocked on naming theater:
    the remaining work is to keep shrinking the wrapper until the file and its
    module name are as honest as the type name already is.
- [ ] `VTCORE-02` Make FFI a first-class core interface.
  Notes: shared FFI state plus `host_api` and `core_api` splits are landed; remaining work is maturity and convergence, not proving the shape. Recent slices closed real host-facing gaps such as close-confirm signals and backend-owned viewport control.
  Done when:
  - the best host-facing terminal semantics reachable from native are also reachable through an explicit FFI/core contract, unless the difference is purely renderer-local.
  - FFI no longer needs to approximate native-only ownership or reconstruct backend truth from side channels.
  - new host-facing semantics are judged first by whether they belong to the shared engine contract, not by whether native can reach them internally.
- [ ] `VTCORE-03` Introduce transport-agnostic host integration.
  Notes: transport contracts, writer/read boundaries, external transport, replay-harness use, no-PTY host support, and shared redraw/alive wake behavior are landed; remaining work is deeper cleanup rather than first transport abstraction.
- [ ] `VTCORE-04` Move protocol execution onto core/model contracts.
  Notes: the main protocol relocation is landed, and printable text ownership
  is now moved below parser hooks into `src/terminal/core/protocol/terminal_core_text.zig`.
  The remaining gap is that the text-write contract is still session-shaped and
  not yet reduced to a cleaner engine-owned boundary.
  Progress note, 2026-04-01, later:
  - printable text no longer routes through `parser_hooks.zig` at all
  - codepoint/ASCII traffic now routes directly into
    `terminal_core_text.zig`
  - `parser_hooks.zig` is reduced to parser-control surfaces instead of
    continuing to masquerade as the owner of printable semantics
  Progress note, 2026-04-01, later still:
  - `terminal_core_text.zig` now reads core-owned text state directly from
    `TerminalCore` instead of reaching through session-shaped callbacks for:
    - active screen access
    - GL charset selection
    - hyperlink attribute application
  - the remaining non-core contract is now narrower and more honest:
    only owner-level effects like wrap-newline and insert-chars still cross a
    callback boundary
  - that remaining effect boundary now lives under protocol ownership in
    `src/terminal/core/protocol/terminal_core_protocol.zig` instead of being wired
    inline inside `terminal_core_text.zig`
  - the stale `src/terminal/core/session_protocol.zig` forwarding shell is now
    deleted; `protocol/terminal_protocol_api.zig` routes directly to the real core,
    protocol, mode-effect, feed, and publication owners
  - the API seam name is now honest too:
    `src/terminal/core/protocol/terminal_protocol_api.zig`
  - the dead `src/terminal/core/terminal_core_dispatch.zig` middleman is now
    deleted; `protocol/terminal_protocol_api.zig` routes straight to the real owners
  - newline, wrap-newline, and reverse-index now live under
    `src/terminal/core/protocol/terminal_core_protocol.zig`
    instead of staying split awkwardly with `control_handlers.zig`
- [ ] `VTCORE-05` Simplify snapshot and render publication.
  Notes: the explicit publication center now lives in
  `src/terminal/core/publication/terminal_publication.zig`, and the old live
  `session_rendering.zig` shell is removed. The remaining problem is duplicated
  publication truth: snapshot still switches between direct screen-owned state
  and render-cache-backed state, and the publication object model is still too
  mirror-heavy.
  Progress note, 2026-03-31, later:
  - `terminal_publication.snapshot(...)` now reads from one published render
    cache surface instead of switching between direct screen-owned state and
    render-cache state.
  - dead publication-only mirror state is starting to come out of
    `src/terminal/core/render_cache.zig`; for example,
    `mouse_reporting_active` was removed after confirming it had no host,
    widget, FFI, or publication consumer.
  Progress note, 2026-04-01:
  - publication ownership is now materially sharper:
    - generation bumping, queued view refreshes, pending-refresh application,
      output-pending state, alt-exit pending state, and render-cache slot
      selection are increasingly publication-owned instead of being mutated
      ad hoc from thread/runtime/selection/scrollback/debug code
  - the generation vocabulary is now honest in live code:
    - `pendingGeneration`
    - `publishedGeneration`
    - `presentedGeneration`
  - stale render-defect probe residue is now being deleted instead of carried
    as permanent architecture debt:
    - the Scroll Lock capture trigger path is removed from live shortcut
      handling
    - widget draw no longer carries stale capture-burst, column-probe,
      frame-provenance, fullframe-fastpath, or row-pass probe logs from the
      old rendering-investigation lane
    - the probe-only presented-generation shadow buffer and partial-update
      coherence escalation path are also removed from the widget layer
  - terminal logging ownership is now explicit:
    - temporary probes are session tools and must die with the session that
      needed them
    - draw/cache/parser/poll narration does not get to squat in the live code
      path as fake architecture
    - only contract, warning, lifecycle, and subsystem-boundary logs survive
      by default
    - this now applies beyond widget rendering too:
      input-send chatter, scroll/resize/init narration, disabled-feature
      debug logs, and dirty-retirement storytelling are being deleted from the
      live terminal core
    - parse/publication cadence storytelling and thread-exit narration are now
      in the same bucket; they do not survive unless they defend a real
      warning path or lifecycle contract
  - mirror-heavy cache metadata is now starting to come out of
    `src/terminal/core/render_cache.zig`:
    - `RenderCache.total_lines` is deleted
    - `RenderCache.selection_active` is deleted
    - publication/UI/replay/test readers now derive total line count from
      `history_len + rows` instead of storing one more redundant aggregate
      truth in the cache
    - selection presence is now derived from the published selection-row
      projection instead of storing one more boolean that merely restated it
  - publication comparison logic is also getting less ad hoc:
    - `view_cache.zig` no longer hand-expands the same broad
      cache-bookkeeping equality checks inline
    - `RenderCache.matchesPublishedState(...)` now centralizes the published
      state match contract for those fast paths
  - publication fast-path decisions are starting to move out of the big
    `publication/view_cache.zig` body too:
    - `canSkipPublish(...)`
    - `canCleanAdvancePublish(...)`
    - `applyCleanAdvancePublish(...)`
    now live in `src/terminal/core/publication/view_cache_publication.zig`
  - more publication-rule ownership moved behind that same seam:
    - `canAssignProjectedDiffDamage(...)`
    - `assignFullDirtyMetadata(...)`
    now own projected-diff gating and forced full-dirty metadata assignment
    instead of leaving those rules inline in `publication/view_cache.zig`
  - row-bookkeeping ownership is now moving too:
    - `assignDirtyRows(...)`
    - `assignDirtySpans(...)`
    - `assignDirtyColsFallback(...)`
    - `assignScrollShiftDirtyRows(...)`
    now own the baseline dirty-row/span/scroll-shift setup that used to sit
    inline in `publication/view_cache.zig`
  - the copied-from-view dirty-column branch is also out:
    - `assignDirtyColsFromView(...)`
    now owns the column-copy path and its broad-span logging instead of
    leaving that inline in `publication/view_cache.zig`
  - published-cache finalization is moving there too:
    - `updateBlinkState(...)`
    - `assignPublishedCacheState(...)`
    now own the final cache-state assignment block instead of leaving
    `publication/view_cache.zig` to hand-set those fields inline
  - visible-cell population is moving there too:
    - `populateVisibleCells(...)`
    now owns the history/grid copy loop that used to sit inline in
    `publication/view_cache.zig`
  - row-hash refinement ownership is sharper too:
    - `canRefineRowHashDamage(...)`
    - `logBroadRefinedSpans(...)`
    now live with `publication/view_cache_refinement.zig` instead of leaving the
    refinement gate and broad-span logging inline in `publication/view_cache.zig`
  - widget/publication interaction is starting to tighten too:
    - `viewportInfo(...)`
    - `scrollbarInfo(...)`
    - `scrollbarAllowed(...)`
    - `drawCursorVisible(...)`
    - `altTransition(...)`
    - `lifecycleTransitionInfo(...)`
    now give widget code explicit publication-facing queries instead of making
    it re-derive those answers from raw cache fields every time
  - that widget-facing helper layer now also owns partial-capture interpretation:
    - `partialCaptureInfo(...)`
    now gives widget draw one publication answer for viewport-shift use and
    capture reason instead of rebuilding that logic ad hoc from raw cache flags
  - render-state interpretation is moving there too:
    - `renderStateInfo(...)`
    now gives widget draw one publication answer for screen-reverse, cursor
    visibility-at-live-bottom, cursor style, and blinking-cell presence
  - dirty/render summary interpretation is moving there too:
    - `dirtySummary(...)`
    now gives widget draw one publication answer for dirty-tag, current dirty
    reason, dirty-row count, damage spans, and damage bounds instead of
    rebuilding that state inline from raw cache fields
  - baseline widget draw state is moving there too:
    - `drawStateInfo(...)`
    now gives widget draw one publication-owned summary for rows, cols,
    viewport state, render state, sync-update state, kitty generation, and
    cursor position instead of pulling those facts piecemeal from raw cache
    - it now also owns generation and clear-generation reads used by draw
      planning, coherence checks, and handoff logging
    - it now also owns the live published cell slice and kitty image/placement
      slices used by widget draw instead of leaving those arrays as raw cache
      reads
  - base background color interpretation is moving there too:
    - `baseColorInfo(...)`
    now gives widget draw one publication-owned answer for raw background and
    resolved screen-reverse background instead of rebuilding first-cell color
    logic in multiple places
  - the surviving widget-local planning state is now narrower and more honest:
    - `ViewportShiftState`
    now owns shift rows and exposed-only state so texture-shift planning and
    logging stop passing those facts around as loose locals
  - the same applies to present-pressure planning scratch state:
    - `PresentPressureState`
    now owns recent-input/full-frame pressure facts so update-plan forcing and
    pressure logging stop smearing that state across loose locals
  - the remaining widget-local handoff scratch state was reduced to one narrow
    seam instead of being rebuilt ad hoc:
    - `HandoffState`
    now owns the last/pending/published/presented generation snapshot used by
    widget plan/commit logging instead of rebuilding that state ad hoc
  - the stronger correction now wins over the old “group the logger slab”
    framing:
    - draw-log formatting buffers and logger-handle slabs that only existed to
      support low-level narration are being deleted, not normalized
  - lifecycle/dirty helpers now also own more of the direct truth widget draw
    needs:
    - `lifecycleTransitionInfo(...)` carries current alt-state
    - `dirtySummary(...)` carries clean-state
    so widget draw no longer has to fall back to raw `cache.alt_active` or
    repeated `cache.dirty == .none` checks where helper-owned truth exists
  - widget debug/background-run interpretation is moving there too:
    - `backgroundRunInfo(...)`
    now gives widget helpers one publication answer for cursor-presence and
    background-run reverse resolution instead of reading those raw cache flags
    directly
  - widget dump diagnostics are moving there too:
    - `visibleViewDumpInfo(...)`
    now gives widget debug dumps one publication-owned header summary instead
    of hand-assembling another cache-shaped view inline
  - `snapshot().generation` now reports the generation of the published render
    cache it actually returns, not a newer unpublished pending epoch
  - remaining gap: publication is still mirror-heavy because render-cache and
    related handoff/update state still duplicate too much terminal-visible
    truth.
- [ ] `VTCORE-06` Keep input encoding as a peer subsystem.
  Notes: transport-agnostic writer-based encoding, fake-writer regression coverage, and PTY-backed `PtyTerminalRuntime.sendText(...)` / `sendKey(...)` regressions through the real session writer boundary are in place; remaining work is keeping the subsystem decoupled as the rest of the split finishes.
- [ ] `VTCORE-07` Preserve desktop Zide behavior while opening the embedding path.
  Notes: this means preserving native quality while keeping native and FFI as peer hosts over the same engine truth, with native acting as the lowest-friction reference implementation rather than as a second semantic center.

## Current Kill Order

- [ ] finish destroying `PtyTerminalRuntime` as a false center, including the
      remaining file/module gravity around the now-renamed `PtyTerminalRuntime`
- [ ] move printable semantics below the VT boundary
- [x] move printable semantics below the VT boundary
- [ ] replace duplicated publication/cache truth with one explicit center
- [ ] shrink native widget draw into a host/presentation consumer, not a
      publication co-owner
- [ ] delete mirrors, fallback paths, and compatibility residue that survive
      only because nobody has taken the knife to them yet

## Current Audit Result

- The engine-center gap versus `libghostty-vt` is now mostly about obviousness
  and ownership gravity, not lack of subsystems.
- The largest remaining architectural enemies are:
  - the remaining `pty_terminal_runtime.zig` module/file gravity around
    `PtyTerminalRuntime`
  - parser-hook semantics above the engine
  - duplicated publication truth
  - oversized native widget/render coordination
- The terminal campaign should now judge success by first-glance authority:
  when a strong maintainer opens the code, the engine must obviously be the
  engine.

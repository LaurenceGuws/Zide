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

- [x] explicit `terminal_publication.zig` center exists
- [x] session/publication call paths route through `terminal_publication`
- [x] `session_rendering.zig` removed from live call paths
- [x] milestone validation pass captured
- [x] milestone merged back into `main`

Validation note, 2026-03-31:

- passed:
  - `zig build test`
  - `zig build check-app-imports`
- ownership shift:
  - session/publication callers now route through
    `src/terminal/core/terminal_publication.zig`
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
  - `src/terminal/core/terminal_debug.zig` now owns replay/test debug helpers,
    so `terminal_runtime.zig` no longer exports test/debug authority as if it
    were part of normal host runtime ownership.
  - `src/terminal/core/session_public_types.zig` is deleted; `pty_terminal_runtime.zig`
    now imports direct ownership modules instead of routing public-facing types
    through a mixed alias hub.
  - the next extraction cut is also in:
    - `src/terminal/core/session_runtime_api.zig`
    - `src/terminal/core/session_publication_api.zig`
  - host/runtime and publication/present public methods are no longer written
    inline on `pty_terminal_runtime.zig`; they are now grouped behind explicit API
    modules and re-exported without behavior changes.
  - `src/terminal/core/session_input_api.zig` now groups the input send/report
    public methods that were previously written inline on
    `pty_terminal_runtime.zig`.
  - `src/terminal/core/session_protocol_api.zig` now groups the protocol/VT
    mutation public methods that were previously written inline on
    `pty_terminal_runtime.zig`.
  - `src/terminal/core/session_config_api.zig` now groups the config, palette,
    and mode-setting public methods that were previously written inline on
    `pty_terminal_runtime.zig`.
  - the remaining publication/view-cache helper stubs and the special-case
    protocol `appendHyperlink` wrapper are no longer written inline on
    `pty_terminal_runtime.zig`; those exceptions now route through the explicit
    publication/protocol API seams too.
  - `src/terminal/core/session_debug_api.zig` now owns the root debug method
    group, so `terminal_debug.zig` and `pty_terminal_runtime.zig` both point at an
    explicit debug API seam instead of treating the session root as the owner.
  - `src/terminal/core/session_lifecycle_api.zig` now owns the lifecycle and
    composition block (`init`, screen access, input pressure, lock state,
    resize, shutdown-facing methods) that was still written directly on the
    session root.
  - `src/terminal/core/session_surface_api.zig` now owns the content,
    selection, host-query, and interaction alias slab that used to dominate
    the top of `pty_terminal_runtime.zig`.
  - `src/terminal/core/session_types_api.zig` now owns the bottom export slab
    for shared terminal constants and core-facing type aliases.
  - raw session state is no longer a flat lie:
    - `src/terminal/core/session_publication_fields.zig`
    - `src/terminal/core/session_runtime_fields.zig`
    - `src/terminal/core/session_interaction_fields.zig`
    - `src/terminal/core/session_control_fields.zig`
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
  is now moved below parser hooks into `src/terminal/core/terminal_core_text.zig`.
  The remaining gap is that the text-write contract is still session-shaped and
  not yet reduced to a cleaner engine-owned boundary.
- [ ] `VTCORE-05` Simplify snapshot and render publication.
  Notes: the explicit publication center now lives in
  `src/terminal/core/terminal_publication.zig`, and the old live
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
    `view_cache.zig` body too:
    - `canSkipPublish(...)`
    - `canCleanAdvancePublish(...)`
    - `applyCleanAdvancePublish(...)`
    now live in `src/terminal/core/view_cache_publication.zig`
  - more publication-rule ownership moved behind that same seam:
    - `canAssignProjectedDiffDamage(...)`
    - `assignFullDirtyMetadata(...)`
    now own projected-diff gating and forced full-dirty metadata assignment
    instead of leaving those rules inline in `view_cache.zig`
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

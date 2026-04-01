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
  - `src/terminal/core/terminal_runtime.zig` still earns its role as the
    stable public runtime surface, but it no longer launders shared
    input/selection/progress types through `pty_terminal_runtime.zig`; those
    names now come from their direct `session/` owners
  - that direct-owner cleanup now also covers selection gesture types and
    key-mode flag access, which no longer come through the wrapper either
  - the same cleanup now applies in `src/terminal/core/workspace.zig`, which
    no longer uses stale `session_mod` vocabulary or wrapper-routed
    `ProgressState` typing
  - the PTY runtime regression tests now also stop using the wrapper as a
    type barrel for snapshot, cell/color, dirty-state, and progress-state
    imports
  - replay/test debug imports now target
    `src/terminal/core/session/debug_ops.zig` directly, so there is no
    extra flat `terminal_debug.zig` shim or wrapper-side debug export shell
    pretending to be a core peer.
  - `src/terminal/core/session_public_types.zig` is deleted; `pty_terminal_runtime.zig`
    now imports direct ownership modules instead of routing public-facing types
    through a mixed alias hub.
  - host/runtime public methods are no longer written inline on
    `pty_terminal_runtime.zig`; they now bind directly to
    `src/terminal/core/session/runtime.zig`, while publication/present methods
    re-export straight from
    `src/terminal/core/publication/terminal_publication.zig`
  - the wrapper behavior files now follow the same rule too:
    `src/terminal/core/session/runtime.zig`,
    `src/terminal/core/session/input.zig`,
    `src/terminal/core/session/config.zig`, and
    `src/terminal/core/session/interaction.zig` replace the redundant
    `session_*` naming inside the already-explicit `session/` subtree.
  - the thin wrapper-side input/config API shells are now dead too:
    `src/terminal/core/session/input_api.zig` and
    `src/terminal/core/session/config_api.zig` are deleted, so
    `pty_terminal_runtime.zig` binds straight to
    `src/terminal/core/session/input.zig` and
    `src/terminal/core/session/config.zig`
  - protocol/VT mutation methods no longer route through a separate wrapper
    shell; `pty_terminal_runtime.zig` now points straight at the real protocol
    owners
  - the local CSI reply callback shell is dead too:
    `ReplyCsiContext` is deleted from `src/terminal/protocol/csi.zig`, so
    DSR/DA/window-op/DECRQM/DECSTR reply handling now executes directly in
    `handleCsiOnSession(...)` instead of bouncing through one more adapter
    layer
  - the local CSI execution callback shells are dead too:
    `SimpleCsiContext` and `SpecialCsiContext` are deleted from
    `src/terminal/protocol/csi.zig`, and
    `src/terminal/protocol/csi_exec.zig` now operates on the live runtime
    object directly instead of routing simple/special CSI execution through
    two more adapter structs
  - the DECRQM mode-query shell is dead too:
    `ModeQueryContext` is deleted from
    `src/terminal/protocol/csi_mode_query.zig`, and DECRQM now snapshots mode
    state directly from the live runtime object via
    `csi_mode_query.modeSnapshot(self)`
  - the CSI reply query shells are dead too:
    `QueryContext` and `ScreenQueryContext` are deleted from
    `src/terminal/protocol/csi_reply.zig`, and DSR/window-op reply handling
    now passes raw query/screen state instead of bouncing through callback
    wrappers for three values at a time
  - the SGR query shell is dead too:
    `SgrContext` is deleted from
    `src/terminal/protocol/csi_style_reset.zig`, and SGR application now reads
    palette/default/current attribute state directly from the live runtime
    object instead of routing those three reads through another callback shell
  - the DECSTR reset shell is dead too:
    `DecstrContext` is deleted from
    `src/terminal/protocol/csi_style_reset.zig`, and soft terminal reset now
    runs directly on the live runtime object instead of bouncing through a
    large callback wrapper
  - the CSI mode-mutation shell is dead too:
    `ModeMutationContext` is deleted from
    `src/terminal/protocol/csi_mode_mutation.zig`, and CSI SM/RM mutation now
    applies directly on the live runtime object instead of routing a giant
    callback wrapper through `csi.zig`
  - the CSI writer shell is dead too:
    `CsiWriter` is deleted from `src/terminal/protocol/csi_reply.zig`, and
    CSI reply/query helpers now operate on direct writer objects instead of
    routing one-method writes through an `anyopaque` adapter
  - the DECRQM capture shell is dead too:
    `ModeCaptureContext` is deleted from
    `src/terminal/protocol/csi_mode_query.zig`, and DECRQM mode snapshots now
    construct `ModeSnapshot` directly instead of cloning it through a
    duplicate intermediate struct
  - wrapper-owned screen access is thinner too:
    `src/terminal/core/pty_terminal_runtime.zig` no longer exports
    `activeScreen`, `activeScreenConst`, `isAltActive`, or the local
    `scrollUp` helper; protocol/session/kitty internals now read screen state
    from `self.core` or direct owners instead of treating the wrapper as the
    screen owner
  - the remaining inline runtime/control helper bodies are thinner too:
    launch-shell path access now lives in
    `src/terminal/core/session/runtime.zig`, and lock/tryLock/unlock now live
    in `src/terminal/core/session/control.zig` instead of sitting inline on
    `pty_terminal_runtime.zig`
  - the focus-reporting/runtime tests no longer lean on an implicit wrapper
    method surface for `getCell` / `getCursorPos`; they now call
    `src/terminal/core/protocol/terminal_core_protocol.zig` directly, so test
    code no longer reinforces phantom wrapper ownership for those query helpers
  - publication-owner flag usage is tighter too:
    `src/terminal/core/runtime/pty_poll_publication.zig` and the locked-scroll
    reflow test now use publication-owned helpers like `markOutputPending()`
    and `viewRefreshPending()` instead of peeking at raw publication flags, and
    the dead constant residue at the bottom of
    `src/terminal/core/pty_terminal_runtime.zig` is gone
  - the published-view builder no longer consumes pending refresh work by
    reading raw publication storage directly:
    `src/terminal/core/publication/view_cache.zig` now uses
    `takePendingViewRefresh()` and `pendingGeneration()` from
    `terminal_publication.zig` instead of swapping `view_cache_pending` and
    loading `view_cache_request_offset` / `pending_generation` itself
  - publication capture/snapshot refresh handling now follows that same owner
    rule too:
    `src/terminal/core/publication/terminal_publication.zig` now routes
    pending snapshot/capture refresh work through
    `applyPendingViewRefreshLocked(...)` instead of hand-driving raw
    `view_cache_pending` checks and direct locked refresh calls inside
    `snapshot()` / `captureCopy()`
  - presented-generation retirement now follows that same owner rule too:
    `src/terminal/core/publication/terminal_publication.zig` now retires
    presented generations through one locked publication-owned path instead of
    splitting the contract across `acknowledgePresentedGeneration(...)`,
    `clearPublishedDamageIfGeneration(...)`, and a separate sync-update policy
    helper
  - published-damage clearing is no longer exposed as a public helper:
    publication now treats damage retirement as an internal locked concern
    instead of exporting another storage-oriented operation from
    `terminal_publication.zig`
  - FFI snapshot and diff export now follow the same publication-owned refresh
    rule too:
    `src/terminal/ffi/core_api.zig` uses
    `renderCacheLocked(...)` / `renderCacheForGenerationLocked(...)` from
    `src/terminal/core/publication/terminal_publication.zig` instead of
    manually locking, checking `viewRefreshPending()`, and forcing locked
    refresh work before reading publication state
  - replay, FFI present-ack, and runtime tests no longer treat presentation
    acknowledgement as wrapper contract:
    they now call `notePresentedGeneration(...)` and
    `acknowledgePresentedGeneration(...)` on
    `src/terminal/core/publication/terminal_publication.zig` directly, and the
    dead wrapper exports are removed from `pty_terminal_runtime.zig`
  - the same direct-owner rule now applies to published render-cache reads in
    replay, debug, and runtime tests:
    those paths now use `terminal_publication.renderCache(...)` directly, and
    the dead wrapper `renderCache` export is removed from
    `pty_terminal_runtime.zig`
  - raw generation-cache lookup is no longer part of the public publication
    surface:
    `renderCacheForGeneration(...)` is now publication-internal, and host code
    only gets the locked publication contract through
    `renderCacheForGenerationLocked(...)`
  - the CSI reply/query path lost another forwarding slab:
    `src/terminal/protocol/csi.zig` no longer carries local DA/DSR/window-op
    bounce helpers that only forwarded into `csi_reply.zig` /
    `csi_mode_query.zig`, and CSI reply tests now target
    `src/terminal/protocol/csi_reply.zig` directly for reply-owner behavior
  - DECRQM reply formatting now lives with the DECRQM query owner too:
    `src/terminal/protocol/csi_mode_query.zig` now owns
    `writeDecrqmReply(...)`, and the remaining test-facing DECRQM reply surface
    no longer routes through `csi.zig`
  - duplicate test-facing reply wrappers are dead too:
    `src/terminal/protocol/csi_reply.zig` no longer exposes `pty`-shaped
    wrapper entrypoints that only forwarded into its real writer-owned reply
    helpers, and `src/terminal/protocol/csi_mode_query.zig` no longer carries
    the same duplicate `writeDecrqmReply(...)` wrapper over
    `writeDecrqmReplyWithWriter(...)`; the reply owners now expose one honest
    writer-shaped surface and the CSI reply tests target that contract
    directly
  - the remaining same-object protocol trampolines are thinner too:
    `src/terminal/protocol/csi.zig` no longer routes `handleCsi(...)` through
    a private `handleCsiOnSession(...)`, and
    `src/terminal/protocol/osc_kitty_clipboard.zig` no longer routes
    `parseOsc5522(...)` / `sendPasteEventMimes(...)` through duplicate
    `*OnSession` bounce helpers; those entrypoints now execute directly
  - the dead presentation-feedback alias seam is gone too:
    `src/terminal/core/session/presentation_feedback.zig` is deleted, so
    presentation-feedback types now live only at the publication owner instead
    of surviving as one more wrapper-side alias shell
  - frame-presentation feedback now follows that same owner rule too:
    the duplicate `finishFramePresentation(...)` bounce is gone from both
    `terminal_publication.zig` and `pty_terminal_runtime.zig`, and the app
    draw-surface runtime now calls
    `terminal_publication.completePresentationFeedback(...)` directly
  - publication-only generation/capture/sync reads now follow that same owner
    rule too:
    widget draw, workspace/workspace-polling, FFI redraw tracking, poll
    runtime, and PTY runtime regression tests now call
    `terminal_publication.{pendingGeneration,publishedGeneration,presentedGeneration,capturePresentation,syncUpdatesActive}(...)`
    directly, and `pty_terminal_runtime.zig` no longer re-exports that
    publication-only query/control slab
  - scroll-driven view-cache refresh now follows that same owner rule too:
    replay harness, reflow tests, resize reflow, and scrollback view now call
    `terminal_publication.updateViewCacheForScroll{Locked}(...)` directly, and
    `pty_terminal_runtime.zig` no longer re-exports that publication mutator
    slab either
  - publication mutation authority is explicit in the PTY runtime regression
    tests now too:
    `src/terminal/core/pty_terminal_runtime_tests.zig` no longer stages
    publication through `session.bumpGeneration()` /
    `session.publishCurrentViewLocked(...)`; those tests now call
    `terminal_publication.bumpGeneration(...)` and
    `terminal_publication.publishCurrentViewLocked(...)` directly, so the
    regression authority stops reinforcing wrapper ownership for publication
    mutation
  - wrapper-owned protocol internals are thinner too:
    parser `RIS`, OSC hyperlink handling, FFI feed-output fallback, and the
    PTY runtime protocol/reset regression tests now call the real owners
    directly:
    `terminal_core_feed.feedOutputBytes(...)`,
    `mode_effects.resetState{Locked}(...)`, and
    `terminal_core_protocol.appendHyperlink2048(...)`;
    `pty_terminal_runtime.zig` no longer re-exports that internal
    feed/reset/hyperlink slab
  - the remaining publication/view-cache helper stubs and the special-case
    protocol `appendHyperlink` wrapper are no longer written inline on
    `pty_terminal_runtime.zig`; those exceptions now route through the explicit
    publication/protocol API seams too.
  - the thin wrapper-side debug/content API shells are now dead too:
    `src/terminal/core/session/debug_api.zig` and
    `src/terminal/core/session/content_api.zig` are deleted, so replay/tests
    import `src/terminal/core/session/debug_ops.zig` directly and
    `pty_terminal_runtime.zig` binds straight to
    `src/terminal/core/session/content.zig`
  - the wrapper behavior and support seams now follow the same rule too:
    `src/terminal/core/session/runtime.zig`,
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
    `src/terminal/core/session/thread_runtime.zig`, and
    `src/terminal/core/session/transport_runtime.zig`
    replace the old flat `session_*` naming inside the subtree.
  - publication-owned state no longer routes through a wrapper shell:
    `src/terminal/core/publication/terminal_publication.zig` now owns pending,
    published, and presented generation state along with damage-retirement
    acknowledgement, view-refresh queueing, sync-update publication, and feed
    publication; both `src/terminal/core/session/publication_state.zig` and
    `src/terminal/core/session/publication_updates.zig` are deleted.
  - the thin wrapper-side runtime/lifecycle API shells are now dead:
    `src/terminal/core/session/runtime_api.zig` and
    `src/terminal/core/session/lifecycle_api.zig` are deleted, so
    `pty_terminal_runtime.zig` binds straight to
    `src/terminal/core/session/runtime.zig` plus its few genuinely local
    screen/lock helpers instead of routing through one more forwarding layer
  - the thin shared type/constant alias slab is now dead too:
    `src/terminal/core/session/types_api.zig` is deleted, so
    `src/terminal/core/terminal_runtime.zig`,
    `src/terminal/core/pty_terminal_runtime.zig`, and
    `src/terminal/core/session/runtime.zig` now pull shared constants and
    types from their direct owners instead of routing them through one more
    wrapper-side export file
  - the stable runtime surface is narrower now too:
    `src/terminal/core/terminal_runtime.zig` no longer re-exports
    `ActivityMetadata`, `ProgressMetadata`, `ProgressState`,
    `SelectionGesture`, or `ClickSelectionResult`; active callers now import
    those names from `session/host_types.zig` and `selection.zig` directly
  - the widget-facing input/selection type barrel is narrower too:
    `src/terminal/core/terminal_runtime.zig` no longer re-exports
    `Modifier`, `MouseButton`, `MouseEventKind`, `MouseEvent`,
    `SelectionPos`, or `TerminalSelection`; widget callers now use
    `terminal/model/types.zig` directly while the stable runtime surface keeps
    only the remaining key/mod constant surface
  - the stable runtime surface no longer launders workspace ownership either:
    `src/terminal/core/terminal_runtime.zig` no longer re-exports
    `TerminalWorkspace`, `TerminalTabId`, `TerminalTabSyncEntry`, or
    `TerminalTabSyncState`; active app/test callers now import those names
    from `src/terminal/core/workspace.zig` directly
  - the stable runtime surface no longer acts as the key/mod constant barrel:
    `src/terminal/core/terminal_runtime.zig` no longer re-exports
    `VTERM_KEY_*`, `VTERM_MOD_*`, `KeyAction`, or `KeypadKey`; active widget,
    smoke, and test callers now use `terminal/model/types.zig` and
    `terminal/input/input.zig` directly
  - that leaves `src/terminal/core/terminal_runtime.zig` as a nearly minimal
    stable entrypoint: it now exposes only `PtyTerminalRuntime`, not a broad
    wrapper-adjacent type/constant/workspace barrel
  - one more `VTCORE-01` gravity cut is now in too: `src/terminal/core/terminal_runtime.zig`
    is now literally just the wrapper entrypoint with no dead import residue,
    and `src/terminal/core/pty_terminal_runtime.zig` dropped the dead
    wrapper-side type/constant alias slab that no longer had live callers
  - another real `VTCORE-04` / `VTCORE-01` ownership cut is now in too:
    `src/terminal/parser/parser.zig` and local-echo input now call the real
    protocol/text owners directly, so `src/terminal/core/pty_terminal_runtime.zig`
    no longer carries the old parser-facing method slab for control/CSI/OSC/DCS
    / printable text dispatch
  - the wrapper file also lost another dead local scaffolding block after those
    cuts: stale parser/snapshot/debug/type aliases are gone from
    `src/terminal/core/pty_terminal_runtime.zig`, so the file reads closer to
    its live surface instead of historical baggage
  - the last inline wrapper helper bodies in that lane are gone too:
    `feedOutputBytes`, `resetState`, and the fixed-limit `appendHyperlink`
    helper now live in their real owner modules instead of squatting inline on
    `src/terminal/core/pty_terminal_runtime.zig`
  - `saveCursor` / `restoreCursor` no longer masquerade as wrapper-owned
    protocol surface either: parser/protocol/test callers now use
    `src/terminal/core/terminal_core_modes.zig` directly
  - protocol-only helpers now route to
    `src/terminal/core/protocol/terminal_core_protocol.zig` directly too:
    `paletteColor`, `setCursorStyle`, and DECRQSS reply generation no longer
    pretend to belong to `src/terminal/core/pty_terminal_runtime.zig`
  - the same is now true for the edit/scroll/sync-update protocol cluster:
    protocol modules and runtime tests use
    `terminal_core_protocol.zig` / `terminal_publication.zig` directly for
    erase/edit/scroll-region and sync-update operations, so those no longer sit
    on the wrapper surface either
  - protocol query helpers are shrinking the same way:
    runtime/focus tests now use `terminal_core_protocol.zig` directly for
    `getCell` / `getCursorPos`, so those no longer sit on the wrapper surface
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
  - wrapper-owned runtime helpers no longer import `pty_terminal_runtime.zig`
    for their own defaults, snapshots, or writer types; those now come from
    direct owners under `session/` and `runtime/`, which reduces the wrapper's
    remaining center-of-gravity pull inside its own helper tree
  - workspace and core runtime test entrypoints no longer import
    `pty_terminal_runtime.zig` directly; they now go through
    `terminal_runtime.zig`, which is the honest stable public runtime surface
  - `pty_terminal_runtime.zig` itself no longer exports a broad top-level
    type/constant barrel; only `PtyTerminalRuntime` remains public there,
    which makes the wrapper file read far more honestly at first glance
  - the oversized `src/terminal/core/session/surface_api.zig` aggregate shell
    is gone too; the wrapper now binds directly to the real session-owned
    content/query/selection/host-query/interaction modules instead of routing
    those through one more export facade
  - `terminal_runtime.zig` dropped the dead `keyModeFlagsValue` re-export too;
    callers already use the runtime-instance method, so the stable public
    surface no longer carries that gratuitous alias
- [ ] `VTCORE-02` Make FFI a first-class core interface.
  Notes: shared FFI state plus `host_api` and `core_api` splits are landed; remaining work is maturity and convergence, not proving the shape. Recent slices closed real host-facing gaps such as close-confirm signals and backend-owned viewport control.
  Progress note, 2026-04-01, later:
  - FFI/workspace host-facing title, cwd, and alt-screen reads no longer reach
    through `session.core.*`
  - those reads now route through explicit host-query methods on
    `PtyTerminalRuntime`, which is a better shared host/runtime contract than
    direct core rummaging from outer host layers
  - app-side terminal cursor-style reload no longer mutates `core.primary` and
    `core.alt` directly; it now routes through an explicit runtime config
    method, which is a better host/runtime boundary than direct screen pokes
  - replay/tests no longer seed OSC 5522 clipboard state or kitty state by
    poking `core.kitty_*` internals directly; those now route through explicit
    debug helpers under `src/terminal/core/session/debug_ops.zig`
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
  - the dead `TextContext` adapter struct is now gone too:
    `terminal_core_text.zig` talks directly to `self.core` plus protocol-owned
    effects instead of routing text execution through one more wrapper-shaped
    contract
  - the dead `TextEffects` adapter in
    `src/terminal/core/protocol/terminal_core_protocol.zig` is now gone too;
    the text path already talks to protocol-owned functions directly, so that
    wrapper layer no longer exists
  - the dead `src/terminal/core/protocol/parser_hooks.zig` forwarding shell is
    now gone too; `terminal_protocol_api.zig` routes DCS/APC/OSC/CSI traffic
    directly to the real protocol owners
  - the dead outer `SessionFacade` shell in `src/terminal/protocol/csi.zig` is
    now gone too; CSI now routes directly to `handleCsiOnSession(...)` while
    the smaller execution contexts remain in place
  - the dead outer `SessionFacade` shell in `src/terminal/protocol/osc.zig` is
    now gone too; `terminal_protocol_api.zig` routes OSC directly while the
    smaller OSC subsystem facades remain in place
  - the dead outer `SessionFacade` shell in
    `src/terminal/protocol/dcs_apc.zig` is now gone too;
    `terminal_protocol_api.zig` routes DCS/APC directly while the real DCS/APC
    behavior stays in place
  - the first inner OSC sub-facade batch is gone too:
    `src/terminal/protocol/osc_progress.zig`,
    `src/terminal/protocol/osc_semantic.zig`, and
    `src/terminal/protocol/osc_title.zig` now operate directly on the live
    core/runtime object instead of wrapping it in tiny `SessionFacade` shells
  - the next OSC wrapper batch is gone too:
    `src/terminal/protocol/palette.zig`,
    `src/terminal/protocol/osc_clipboard.zig`, and
    `src/terminal/protocol/osc_hyperlink.zig` now operate directly on the
    live core/runtime object instead of wrapping it in tiny `SessionFacade`
    shells
  - the OSC cwd wrapper chain is gone too:
    `src/terminal/protocol/osc_cwd.zig` and
    `src/terminal/protocol/osc_util.zig` now operate directly on the live
    core/runtime object instead of stacking `SessionFacade` wrappers
  - the remaining inner `SessionFacade` in
    `src/terminal/protocol/osc_kitty_clipboard.zig` is gone too; clipboard
    reads, allocator use, and reply generation now run directly on the live
    session object instead of bouncing through one more manual facade shell
  - the remaining OSC 5522 writer shell is gone too:
    `WriterFacade` is deleted from
    `src/terminal/protocol/osc_kitty_clipboard.zig`, and clipboard reply
    generation now writes directly to the live writer object instead of
    routing one-method writes through another `anyopaque` adapter
  - the parser's own `SessionFacade` shell is gone too:
    `src/terminal/parser/parser.zig` now operates directly on the live
    runtime object, and feed/poll/debug entrypoints call `handleSlice(...)`
    without wrapping the runtime in one more callback facade
  - the outer kitty clipboard wrapper entrypoints are gone too:
    `src/terminal/protocol/osc_kitty_clipboard.zig` still carries internal
    reply/state helpers, but `parseOsc5522(...)` and `sendPasteEventMimes(...)`
    now take the live core/runtime object directly instead of requiring an
    outer `SessionFacade`
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

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

The passive cleanup phase is over.

The active lane is now indefinite VT maturity purity, not opportunistic seam
cleanup.

Use
[VT_MATURITY_PURITY_CAMPAIGN.md](/home/home/personal/zide/app_architecture/terminal/VT_MATURITY_PURITY_CAMPAIGN.md)
as the governing authority for what counts as progress.

Use
[VT_MATURITY_COMPLETION_LIST.md](/home/home/personal/zide/app_architecture/terminal/VT_MATURITY_COMPLETION_LIST.md)
as the numbered sequential completion list for the same scrutiny war.

Use
[VT_MATURITY_FULL_SCOPE_2026-04-03.md](/home/home/personal/zide/docs/review/VT_MATURITY_FULL_SCOPE_2026-04-03.md)
as the comprehensive ranked scope map before opening any new front inside the
same VT scrutiny war.

That means:

- do not hop to side wars by momentum
- do not keep renaming local fronts as separate wars
- do not replace the numbered completion list with ad hoc local win conditions
- do not keep shaving wrappers unless the library-center story gets stronger
- do not reopen flattened local lanes just because they still have files
- only continue code when one named maturity contradiction is explicit

Current full-scope read:

- top blocker: `TerminalCore` sufficiency
- second blocker: public contract normalization
- shell survival is not assumed legitimate; it stays under hostile scrutiny as
  part of the same maturity campaign
- interaction ownership and mutation/publication maturity are now lower-pressure
  guardrails unless a fresh named contradiction appears

- `docs/review/VT_SHELL_HOSTILE_AUDIT_2026-04-03.md`
  Why: with the wartime shell bar now explicit, the shell needs a hostile
  responsibility audit instead of vague legitimacy language.
  Current read:
  - transport/writer access and lifecycle are the most defensible surviving
    shell buckets
  - reporting is now the strongest suspicious shell frontier
  - constructor/object identity and lock choreography remain under active
    suspicion

- `docs/review/VT_SHELL_REPORTING_FRONT_2026-04-03.md`
  Why: the shell audit's first suspicious bucket needs one explicit code front
  instead of staying a vague concern.
  Current read:
  - `2031`, `2048`, and `5522` now live under one explicit
    `host_reporting.zig` owner
  - CSI mutation/query and runtime-dependent reporting behavior now consume
    that owner instead of spreading reporting across multiple shell-shaped
    files
  - this does not prove the reporting boundary is final, but it stops the
    shell from surviving as reporting residue by default

- `docs/review/VT_SHELL_POST_REPORTING_RERANK_2026-04-03.md`
  Why: after the reporting bucket is normalized, the shell fronts need a fresh
  kill-order.
  Current read:
  - reporting is materially less suspicious now
  - constructor/object identity is now the strongest remaining shell
    contradiction
  - lock choreography is second
  - transport/lifecycle remain the most defensible shell buckets

- `docs/review/VT_SHELL_CONSTRUCTOR_IDENTITY_FRONT_2026-04-03.md`
  Why: the shell's strongest remaining contradiction now needs a direct code
  slice instead of staying a rerank note only.
  Current read:
  - constructor ownership now lives on `terminal_runtime.zig`, not on
    `TerminalRuntimeShell`
  - live callers now enter through the VT root constructor path instead of
    `TerminalRuntimeShell.init*`
  - this removes one shell-first teaching path, but the public handle/create
    story still needs scrutiny

- `docs/review/VT_SHELL_HANDLE_IDENTITY_RERANK_2026-04-03.md`
  Why: after the constructor slice, the host-edge identity suspicion needs one
  more honesty check at the FFI boundary.
  Current read:
  - the opaque ABI remains terminal-named
  - the internal handle now admits that it stores a shell, not a vague
    terminal session
  - this weakens host-edge identity pressure again and likely promotes lock
    choreography as the next shell-hostile front

- `docs/review/VT_SHELL_LOCK_READ_FRONT_2026-04-03.md`
  Why: with constructor and handle identity flatter, the next shell-hostile
  contradiction is explicit lock choreography.
  Current read:
  - the first read-side lock slab now lives under `host_queries.zig`
  - host/UI callers no longer need to lock the shell themselves for cwd,
    hyperlink, or progress reads
  - what remains is a narrower question about mutation and rendering-time
    locking, not a broad read-side shell habit

- `docs/review/VT_SHELL_LOCK_POST_READ_RERANK_2026-04-03.md`
  Why: after the first lock slice, the front needs a narrower kill-order.
  Current read:
  - broad read-side lock gravity is no longer the next problem
  - mutation transaction locking is now the strongest remaining shell lock
    front
  - render/widget snapshot locking is second

- `docs/review/VT_SHELL_MUTATION_SCROLLBAR_FRONT_2026-04-03.md`
  Why: the mutation-locking front needs one clean opening slice before the
  broader pointer-selection transaction is challenged.
  Current read:
  - scrollbar drag no longer opens the shell lock directly from app code
  - `scrollback_view.zig` now owns the backend mutation transaction boundary
    for normalized track scrolling
  - the remaining mutation pressure is now the broader pointer-selection
    gesture path

- `docs/review/VT_SHELL_MUTATION_POINTER_FRONT_2026-04-03.md`
  Why: the remaining mutation-locking pressure was the oversized pointer
  gesture transaction.
  Current read:
  - widget pointer input no longer opens one broad shell lock across the full
    selection/scrollback gesture flow
  - backend selection and scrollback verbs now own their own lock scope for
    those mutations
  - the remaining lock question is now narrower again, likely render-time
    snapshot locking or final shell lock surface legitimacy

- `docs/review/VT_SHELL_LOCK_POST_MUTATION_RERANK_2026-04-03.md`
  Why: after the read-side and mutation slices, the lock front needs an
  honesty check before more code.
  Current read:
  - lock choreography is close to a stop-marker
  - the broad host-visible lock patterns are materially gone
  - what remains is mostly narrow snapshot locking or input/reporting transport
    pressure, not a generic shell-lock war

- `docs/review/VT_POST_SHELL_CLEANUP_RERANK_2026-04-03.md`
  Why: after the constructor, handle, and lock fronts, the shell needs a fresh
  top-level rerank against `TerminalCore` sufficiency.
  Current read:
  - the shell is no longer the obvious enemy
  - the strongest remaining VT pressure is broader `TerminalCore` sufficiency
    and protocol-execution maturity again
  - if the shell front reopens, it should reopen only on transport/reporting
    survival, not generic cleanup

- `docs/review/VT_CSI_REPLY_QUERY_CONTRACT_2026-04-03.md`
  Why: after the shell-cleanup wave, the next exact protocol-execution
  contradiction needed to be named more sharply than vague parser discomfort.
  Current read:
  - the next remaining cluster is writer-driven CSI reply/query assembly
  - DSR, DA, bounded window-op replies, and DECRQM still become complete
    host-visible behavior only at the writer-anchored shell edge
  - the first likely slice is DSR plus bounded window-op replies, because they
    already share one explicit snapshot owner without forcing DA/DECRQM into
    the same first shape
  - do not force CSI into the byte-oriented reply sink just for symmetry
  Progress:
  - the first slice is now landed
  - `csi_reply.zig` now owns explicit byte assembly for DSR and bounded
    window-op replies
  - `csi.zig` no longer acquires a raw writer for those reply families; it
    emits their bytes through the named protocol reply sink instead
  - the second slice is now landed too
  - DA now emits through the named protocol reply sink from an explicit byte
    reply contract
  - DECRQM now formats reply bytes through `decrqmReplyInto(...)` and emits
    them through the named protocol reply sink instead of taking a raw writer
    in `csi.zig`
  - this cluster is now close to a real stop-marker and should not reopen
    without one new explicit contradiction

- `docs/review/VT_POST_CSI_REPLY_QUERY_RERANK_2026-04-03.md`
  Why: after the full CSI reply/query wave, VT needs a fresh maturity ranking
  from the stronger protocol-execution baseline.
  Current read:
  - generic shell cleanup is no longer the main problem
  - broad CSI reply/query discomfort is no longer the main problem
  - sink uniformity is not a goal
  - the next active front must now be one broader `TerminalCore`
    protocol-execution sufficiency contradiction or one host-contract weakness
    that clearly outranks everything else

- `docs/review/VT_PROTOCOL_RESET_CONTRACT_2026-04-03.md`
  Why: after the CSI reply/query stop-marker, the next exact semantic protocol
  cluster needed to be named instead of reopening leftover CSI or shell work.
  Current read:
  - the strongest next front is protocol reset and reset-adjacent mode cleanup
  - `csi_style_reset.zig` still mixes terminal reset semantics with input-mode,
    host-reporting, sync-update, and refresh-adjacent outer effects
  - reset is a stronger terminal-object maturity signal than one more local
    mode/query or sink cleanup slice
  Progress:
  - the first split is now landed under
    `src/terminal/core/protocol/terminal_core_reset.zig`
  - DECSTR terminal-owned reset semantics now live behind one core-side owner
  - `csi_style_reset.zig` keeps the explicit outer reset effects:
    host-reporting reset, input-mode reset, sync-update reset, and input
    snapshot publication

- `docs/review/VT_PROTOCOL_RESET_SPLIT_2026-04-03.md`
  Why: the reset front needed one exact ownership split instead of vague reset
  discomfort.
  Current read:
  - terminal-owned DECSTR reset semantics are now grouped explicitly
  - outer protocol/runtime effects remain explicit outside that owner
  - this is a real maturity gain because reset now reads less like a
    protocol-owned mixed script

- `docs/review/VT_PROTOCOL_RESET_RERANK_2026-04-03.md`
  Why: after the first DECSTR split, the reset front needs an honesty check
  before it drifts into local cleanup.
  Current read:
  - reset is close to a stop-marker
  - the strongest omitted terminal-owned slab is already moved
  - the remaining reset surface now reads mostly like explicit outer
    consequences, not fake terminal ownership
  - the default next pressure returns to broader `TerminalCore` sufficiency

- `docs/review/VT_CORE_PROTOCOL_OWNER_CONTRADICTION_2026-04-03.md`
  Why: after shell, reply/query, and reset fronts flattened, the next broader
  `TerminalCore` sufficiency contradiction had to be named directly.
  Current read:
  - `src/terminal/core/protocol/terminal_core_protocol.zig` still carries too
    much semantic gravity beside `TerminalCore`
  - the strongest remaining question is which whole semantic slab there still
    belongs more naturally on `TerminalCore` itself
  - strongest candidate slabs are screen-edit/erase, scroll/newline/reverse-
    index, and DECRQSS state/query assembly
  Progress:
  - the first whole slab is now landed on `TerminalCore`
  - erase display/line and insert/delete/erase char/line semantics no longer
    read as primarily owned by `terminal_core_protocol.zig`
  - the strongest remaining pressure in that file is now scroll/newline/
    reverse-index plus DECRQSS state/query assembly
  Rerank:
  - scroll/newline/reverse-index now clearly beats DECRQSS as the next slab
  - do not take DECRQSS first just because it is smaller
  Progress:
  - scroll/newline/reverse-index is now landed on `TerminalCore`
  - lower-level scrolling helpers remain in `scrolling.zig`
  - the strongest remaining pressure in `terminal_core_protocol.zig` is now
    DECRQSS state/query assembly plus small mechanical helpers
  Final slab:
  - DECRQSS now clearly beats the remaining tiny helpers and should be taken
    before any stop-marker on this front
  Stop marker:
  - that final slab is now landed
  - the remaining `terminal_core_protocol.zig` surface is now mostly narrow
    helper support, not a parallel semantic center

- `docs/review/VT_CORE_PROTOCOL_OWNER_RERANK_2026-04-03.md`
  Why: after the three real slabs landed, this front needed an explicit
  stop-marker rerank.
  Current read:
  - `terminal_core_protocol.zig` is now close to a real stop-marker
  - continuing here would mostly mean tiny helper cleanup and faux progress
  - the next pressure returns to broader `TerminalCore` sufficiency from the
    stronger baseline

- `docs/review/VT_POST_PROTOCOL_OWNER_RERANK_2026-04-03.md`
  Why: after the protocol-owner front is parked, VT needs a fresh top-level
  rerank from the stronger baseline.
  Current read:
  - `terminal_core_protocol.zig` is no longer the next war
  - the next contradiction is likely broader and more object-model or
    contract-quality shaped
  - the next move should name one exact broader `TerminalCore` sufficiency or
    host-contract normalization weakness

- `docs/review/VT_HOST_CONTRACT_NORMALIZATION_2026-04-03.md`
  Why: after the local owner seams flattened, the strongest remaining maturity
  pressure appears to be contract quality at the host edge.
  Current read:
  - the next contradiction is host-contract normalization
  - the risk is no longer lack of capability, but a rich contract that still
    feels historically accumulated instead of boring and deliberate
  - strongest local suspects are `host_api.zig`, `host_queries.zig`, and
    `core_api.zig`
  Progress:
  - the first normalization slice is now landed
  - terminal metadata and runtime metadata are explicit categories again at
    the host query layer
  - FFI metadata assembly now combines terminal metadata, runtime metadata,
    and activity metadata deliberately instead of treating them as one blob

- `docs/review/VT_HOST_METADATA_SPLIT_2026-04-03.md`
  Why: the host normalization front needed one first concrete category split.
  Current read:
  - terminal metadata, runtime metadata, and activity metadata are explicit
    again
  - this improves host-contract clarity without premature ABI churn

- `docs/review/VT_HOST_ACTIVITY_SPLIT_2026-04-03.md`
  Why: after the internal metadata split, the public ABI still taught one
  mixed metadata story and needed a direct normalization cut.
  Current read:
  - `metadataAcquire(...)` is now terminal-only
  - semantic activity moved to its own acquire/release surface
  - runtime state remains on explicit runtime getters instead of being
    re-bundled through terminal metadata

- `docs/review/VT_HOST_SNAPSHOT_METADATA_DUPLICATION_2026-04-03.md`
  Why: after the metadata/activity split, the next host-edge weakness is no
  longer mixed categories inside metadata; it is duplicated title/cwd truth
  across snapshot and metadata surfaces.
  Current read:
  - snapshot and metadata no longer both answer title/cwd
  - snapshot now reads more purely as viewport publication truth
  - metadata now reads more purely as terminal metadata truth

- `docs/review/VT_HOST_SNAPSHOT_METADATA_SPLIT_2026-04-03.md`
  Why: once duplication was named, the next honest move was to remove
  snapshot-owned title/cwd directly instead of preserving two host stories.
  Current read:
  - snapshot no longer carries title/cwd
  - terminal metadata is now the sole host-facing owner of that truth

- `docs/review/VT_HOST_CONTRACT_POST_SNAPSHOT_RERANK_2026-04-03.md`
  Why: after the host metadata/activity/snapshot slices, the next move should
  be justified by a fresh ranking, not by ABI symmetry.
  Current read:
  - host normalization is materially healthier now
  - the broad host-contract contradiction is no longer the default next front
  - if host normalization continues, it should reopen only on one narrower
    overlap like latest-state/status surfaces

- `docs/review/VT_CORE_OWNER_DEPENDENCY_FRONT_2026-04-03.md`
  Why: after the host edge quieted down again, the strongest remaining
  maturity contradiction is broader core sufficiency, specifically
  owner-shaped completion around core semantics.
  Current read:
  - major core behaviors still depend on outer `owner` context
  - the likely kill-order is:
    - scrolling-side owner dependency
    - parser feed owner dependency
    - reset/kitty owner dependency

- `docs/review/VT_CORE_SCROLLING_OWNER_DESIGN_2026-04-03.md`
  Why: scrolling is the first whole owner-dependency slice worth attacking,
  but it mixes core semantics with kitty placement effects and host metrics.
  Current read:
  - the first explicit side-effect cut is now landed:
    `TerminalCore` returns `ScrollAction` for newline/wrap-newline/reverse-index
  - scrolling now consumes that action explicitly outside core
  - the next question is whether the remaining kitty/history consumer is now
    honest enough or still hides another real owner dependency

- `docs/review/VT_CORE_OWNER_POST_SCROLL_RERANK_2026-04-03.md`
  Why: after the first scrolling slice, the front needs a fresh kill-order.
  Current read:
  - scrolling is improved enough to pause
  - the next stronger contradiction is parser feed owner dependency

- `docs/review/VT_CORE_PARSER_FEED_FRONT_2026-04-03.md`
  Why: with scrolling no longer the default next contradiction, the next
  exact owner-shaped completion path is parser feed.
  Current read:
  - `TerminalCore.feedOutputBytesLocked(...)` still depends on outer owner
    shape for parser/protocol execution
  - the next move must define a narrower execution contract there, not just
    rename parameters

- `docs/review/VT_CORE_PARSER_FEED_CONTRACT_2026-04-03.md`
  Why: parser feed is blocked less by parser mechanics than by mixed protocol
  execution state.
  Current read:
  - parser/protocol still reaches one broad receiver for:
    - terminal semantics
    - protocol state / host-contract flags
    - reply/report/runtime hooks
  - the next code move must define one narrower execution surface first
  Progress:
  - parser/protocol reply and reporting hooks now go through one explicit
    `protocol_runtime.zig` owner instead of broad shell exposure
  - this is a real parser-feed ownership improvement, not just naming, because
    protocol files now depend on a named runtime/report surface
  - parser/protocol state reads and the remaining grapheme-mode mutation/reset
    path now go through one explicit `protocol_state.zig` owner instead of
    raw `session.interaction` reach from the active protocol surface
  - the remaining parser-feed problem is now narrower than both sink exposure
    and raw protocol-state reach
  - `TerminalCore.feedOutputBytesLocked(...)` now feeds the parser an explicit
    `protocol_execution.zig` receiver instead of the shell-shaped owner
  - the remaining parser-feed question is now the quality and irreducibility
    of that composite execution surface, not whether the shell is still the
    parser receiver
  - `sync_updates.zig` no longer reaches raw publication fields directly;
    publication dependence is now explicit as execution-surface methods on
    `protocol_execution.zig`
  - the next parser-feed question is now which surviving execution face is
    still the strongest contradiction: publication or runtime/transport
  - `control` no longer survives as a full execution face; the parser feed
    contract now carries only a direct mutex pointer for locking
  - the remaining execution-face pressure is now publication versus
    runtime/transport, not control
  - runtime is now partially reduced too: `protocol_execution.zig` carries an
    explicit write/wake runtime face, while compatibility `session.runtime`
    still survives for active protocol/helper paths
  - publication remains the strongest fully surviving execution face unless a
    fresh rerank proves the remaining runtime compatibility is worse
  - a direct publication-face shrink attempt did not survive the active
    publication call graph cleanly, which strengthens the judgment that
    publication is still the next real execution-face contradiction
  - the next honest publication move is now named explicitly:
    synchronized-update publication contract, not broad publication slimming
  - the first synchronized-update publication slice is now landed on
    `protocol_execution.zig` and `sync_updates.zig`
  - the second parsed-output publication slice is now landed too:
    `protocol_execution.zig` now owns:
    - `noteParsedOutput(...)`
    - `consumeFeedResult(...)`
    - `publishPendingOutput(...)`
    - `markOutputPending(...)`
  - active feed/runtime paths no longer finish parsed output through direct
    `publication_flow` choreography:
    - `terminal_core_feed.zig`
    - `pty_poll_processing.zig`
    - `io_threads.zig`
  - that parsed-output wave then tightened once more:
    - `io_threads.zig` now uses `protocol_execution.publishPendingOutput(...)`
      for the idle publish path too
    - `pty_poll_publication.zig` now uses
      `protocol_execution.markOutputPending(...)` for unread buffered IO
  - the next pending-refresh / poll publication cadence slice is now landed:
    `protocol_execution.zig` now owns:
    - `viewRefreshPending(...)`
    - `takePendingViewRefreshRequest(...)`
    - `publishViewRefreshRequest(...)`
    - `publishPollUpdate(...)`
  - runtime poll/parse callers no longer depend on direct
    `publication_flow` choreography for that shared path:
    - `pty_poll_publication.zig`
    - `io_threads.zig`
  - the dead runtime compatibility residue is now gone from
    `protocol_execution.zig`
  - reply sink emission now uses the explicit `writePtyBytes(...)` contract
    directly through `protocol_reply_sink.zig`
  - post-sync rerank: publication still beats runtime as the strongest fully
    surviving execution face, because the active path still depends on the
    broader view-cache/publication helper stack
  - post-parsed-output rerank: publication still wins, but its remaining shape
    is now pending-refresh / poll publication cadence rather than broad
    parsed-output publication
  - post-poll rerank: runtime compatibility is no longer a broad surviving
    execution face; the next move must freshly prove whether publication still
    wins or whether execution-face cleanup is no longer the default front
  - post-execution-face rerank: no new coherent publication contract is
    obvious enough to keep execution-face cleanup as the default front
  - the next default pressure returns to broader `TerminalCore` sufficiency
    unless one new explicit publication contradiction is named first
  - the next exact broader contradiction is now named:
    mode/reset effect ownership
  - live pressure is concentrated in:
    - `TerminalCore.resetState(...)`
    - `TerminalCore.eraseDisplayLocked(...)`
    - `terminal_core_modes.zig`
    - `mode_effects.zig`
  - the next move should define explicit terminal-mode/reset effects instead
    of leaving outer mode helpers to complete the story by habit
  - the first opening slice is now landed:
    `TerminalCore.eraseDisplayLocked(...)` returns explicit
    `EraseDisplayEffect` instead of taking outer owner shape just to clear
    selection
  - `terminal_core_protocol.zig` now consumes that consequence explicitly
  - the second opening slice is now landed:
    `TerminalCore.resetState(...)` no longer takes outer owner shape just to
    reset kitty image state
  - `mode_effects.zig` now keeps input-mode reset as the explicit outer
    consequence instead of passing the whole shell into core reset
  - the third opening slice is now landed:
    `terminal_core_modes.zig` now returns explicit `AltScreenEffect` values
    for alt-screen enter/exit transitions
  - `mode_effects.zig` now consumes explicit post-transition consequences
    instead of hard-coding the whole outer completion sequence inline
  - post-alt rerank: the remaining snapshot/publication consequences now read
    mostly honest as outer derived-state/presentation work, so this front is
    near a stop-marker
  - the next default pressure returns to broader `TerminalCore` sufficiency
    unless one new exact mode/reset contradiction appears
  - the next exact broader contradiction is now named:
    resize owner dependency
  - live pressure is concentrated in:
    - `TerminalCore.resizeLocked(...)`
    - `resize_reflow.zig`
  - the active mixed story is:
    - terminal reflow and selection remap
    - host cell-metric staging
    - scroll-view publication refresh
    - transport resize reporting
  - the next move must separate terminal resize/reflow truth from those outer
    consequences instead of just renaming `owner`
  - the first resize slice is now landed:
    `TerminalCore.resizeLocked(...)` returns explicit `ResizeEffect`
  - `resize_reflow.zig` no longer performs hidden scroll-view publication
    refresh inside the core resize/reflow path
  - outer resize orchestration now consumes that refresh deliberately after
    core resize returns
  - post-first-slice rerank: host cell metrics and transport resize reporting
    now read mostly honest as host-contract/runtime concerns
  - the next default pressure returns to broader `TerminalCore` sufficiency
    unless one deeper resize-side owner dependency appears
  - the next exact broader contradiction is now named:
    feed execution dependency
  - live pressure is concentrated in:
    - `TerminalCore.feedOutputBytesLocked(...)`
    - `protocol_execution.zig`
  - the surviving issue is no longer shell-shaped ownership
  - it is that core feed still needs a composite execution receiver bundling:
    protocol state, publication/update reach, runtime write/wake reach, and
    lock access
  - the next move must isolate one narrower surviving feed execution
    dependency instead of renaming that receiver again
  - hostile audit result: publication/update reach is still the strongest
    surviving feed dependency inside `protocol_execution.zig`
  - runtime is already narrowed to write/wake mechanics
  - locking is already narrowed to the mutex
  - protocol state is named and narrower than before
  - the next move should therefore name one coherent publication/update
    contract inside feed execution before more code
  - that split is now explicit:
    parsed-output publication is the first coherent feed-publication contract
  - pending-refresh / poll cadence is the second cluster, not the first slice
  - the first parsed-output publication slice is now landed:
    active feed callers no longer spell out generation bump, cache update, and
    output-pending marking separately
  - `protocol_execution.zig` now owns that as one explicit parsed-output
    publication contract
  - rerank after that slice:
    pending-refresh / poll cadence is now the strongest remaining
    feed-publication cluster
  - the next move should target that cadence contract directly
  - the first pending-refresh cadence slice is now landed:
    `protocol_execution.zig` now owns explicit
    `PendingRefreshDecision` handling
  - `io_threads.zig` no longer spells out request-take vs request-publish
    handling as separate parse-thread steps
  - post-cadence rerank:
    publication/update reach still wins, but much more narrowly now
  - the strongest remaining publication piece is poll-time
    publish-or-refresh behavior through `protocol_execution.zig` and
    `pty_poll_publication.zig`
  - that second cadence slice is now landed too:
    `protocol_execution.zig` now owns the poll-time
    `shouldPublishPollUpdate(...)` decision
  - `pty_poll_publication.zig` no longer re-derives that branch itself
  - post-poll rerank:
    publication/update reach no longer wins clearly enough to stay the default
    feed contradiction by inertia
  - the next default pressure returns to the broader feed-execution front from
    this cleaner baseline unless one new exact publication contract is named
  - the next surviving feed face is now named:
    protocol-state reach
  - runtime is still narrowed to write/wake mechanics
  - lock access is still narrowed to the mutex
  - the remaining broad named state face on `protocol_execution.zig` is
    `interaction`, still reached indirectly through `protocol_state.zig`
  - protocol-state-only did not survive the active call graph cleanly
  - blocking dependencies still include:
    - `input_modes.zig`
    - `protocol_runtime.zig`
    - kitty placement/runtime-adjacent host-contract metric reads
  - the next move must split one narrower feed-facing protocol-state contract
    that survives those dependencies instead of pretending `interaction` can
    already disappear
  Progress:
  - the first survivable feed-state split is now landed
  - `protocol_execution.zig` no longer carries one raw `interaction` face
  - the active feed receiver now carries explicit state faces instead:
    - `protocol_modes`
    - `derived_snapshot`
    - `host_contract`
  - `protocol_state.zig` now resolves protocol-mode and derived-snapshot
    access through those explicit faces
  - `input_modes.zig` now mutates and republishes input protocol state through
    that narrower protocol-state contract
  - `host_reporting.zig`, `protocol_runtime.zig`, and kitty placement metrics
    now consume an explicit host-contract face instead of depending on the
    same raw interaction bag
  - the active feed path no longer depends on a monolithic interaction bag;
    the remaining contradiction is narrower than raw interaction reach
  Progress:
  - the surviving host-contract dependency is now split too
  - `protocol_execution.zig` no longer carries one mixed `host_contract` face
  - the active feed receiver now carries two explicit faces instead:
    - reporting contract
    - host metrics
  - `host_reporting.zig` now consumes those two faces explicitly instead of
    treating flags, color state, and cell metrics as one bag
  - `protocol_runtime.zig` now reads CSI reply geometry/color from host
    metrics and resets reporting flags through the reporting-contract face
  - kitty placement now reads only host metrics, not a broader host-contract
    shape
  - the next honest move is a rerank between reporting-contract dependence and
    host-metric dependence, not another generic “host contract” cut
  Progress:
  - the host-metrics side is now split too
  - `protocol_execution.zig` no longer carries one mixed host-metrics face
  - the active feed receiver now carries:
    - reporting contract
    - color-scheme state
    - cell metrics
  - `protocol_runtime.zig` now builds CSI reply runtime state from explicit
    color-scheme and cell-metric faces
  - `host_reporting.zig` now uses:
    - reporting contract plus cell metrics for in-band resize
    - reporting contract plus color-scheme state for color reporting
  - kitty placement now reads only cell metrics, not a broader host-metrics
    shape
  - the next honest rerank is now among:
    - reporting contract flags
    - cell metrics
    - color-scheme state
  Rerank:
  - cell metrics now win
  - reporting contract flags now read mostly honest as explicit host opt-in
    contract
  - color-scheme state is narrower than cell metrics and should not outrank it
  - if this front continues immediately, the next exact host-side
    contradiction is cell-metric dependence
  Progress:
  - the cell-metric contradiction is now materially cut
  - `TerminalCore` now owns current cell metrics directly
  - feed/protocol no longer needs a cell-metrics face on
    `protocol_execution.zig`
  - resize/config/transport now stage and consume cell metrics through core
  - protocol replies, in-band resize reporting, and kitty placement now read
    cell metrics from core-owned state instead of a host-contract bag
  - the remaining host-side faces are now:
    - reporting contract flags
    - color-scheme state
  - the next rerank should decide whether either of those still beats broader
    `TerminalCore` sufficiency
  Final rerank:
  - neither remaining host-side face now beats broader `TerminalCore`
    sufficiency
  - reporting contract flags now read mostly honest as explicit host opt-in
    runtime contract
  - color-scheme state is too narrow to justify staying the active front
  - this feed host-face lane is now at a stop-marker
  - the next default VT pressure returns to broader `TerminalCore`
    sufficiency from this cleaner baseline

Current named category-1 contradiction:

- `docs/review/VT_CORE_EXECUTION_CONTRADICTION_REVIEW_2026-04-03.md`
  Why: the strongest remaining `TerminalCore` maturity gap is no longer
  metadata or wrapper ownership; it is that major core behaviors still depend
  on outer owner/publication choreography to become complete host-visible
  terminal behavior.
  Current read:
  - top target: feed/apply publication path
  - fallback target: selection/viewport refresh choreography
  - do not reduce this to cosmetic shell-thinning
  Progress:
  - feed/apply publication now consumes one explicit core feed result across
    the native feed path and runtime parse paths
  - this removes one layer of ad hoc publication choreography
  - selection mutation now returns explicit core effects and the host wrapper
    consumes them through one publication-flow entrypoint instead of repeating
    refresh choreography after each core call
  - viewport/scrollback offset mutations now consume one shared publication
    entrypoint instead of repeating the same refresh choreography inline
  - the deeper owner-shaped parser dependency still remains open, but is not
    yet a safe code move because parser/protocol execution still mixes terminal
    semantics with session interaction flags and writer/reporting mechanics
  Next step:
  - `docs/review/VT_CORE_PARSER_OWNER_DESIGN_2026-04-03.md`
    Why: the next obvious move after the execution-effect wins needed a design
    check before code.
    Current read:
    - do not force parser-owner extraction yet
    - the real blocker is mixed protocol interaction state, especially CSI
      mode/query and reply/report ownership
    - rerank or open that deeper design war before more code

- `docs/review/VT_POST_EXECUTION_RERANK_2026-04-03.md`
  Why: the recent execution-contract wave changed the shape of category 1 and
  needed a fresh ranking against category 2.
  Current read:
  - category 1 still wins
  - but the next war is now mixed protocol interaction state, not direct
    parser-owner extraction
  - public contract normalization remains second

- `docs/review/VT_PROTOCOL_INTERACTION_CONTRACT_WAR_2026-04-03.md`
  Why: the post-execution rerank needs one explicit battlefield instead of
  vague "mixed protocol state" discomfort.
  Current read:
  - the mixed state in `session.interaction` breaks into distinct categories:
    terminal protocol mode state, host-reporting contract flags, display
    metrics, and derived snapshots
  - the best opening target is CSI mode/query ownership
  - do not extract parser code before reclassifying that mixed state

- `docs/review/VT_CSI_MODE_QUERY_SPLIT_2026-04-03.md`
  Why: the new war needs the exact field-level split before code.
  Current read:
  - CSI mode/query should stop treating `session.interaction` as one kind of
    state
  - the key split is between terminal protocol mode state and host-reporting
    contract state
  - display metrics and derived snapshots are separate again
  Progress:
  - the first CSI ownership slice is now landed
  - `interaction_fields.zig` no longer stores one flat interaction bag
  - the live split is now explicit:
    - `protocol_modes`
    - `host_contract`
    - `derived_snapshot`
  - CSI mode mutation/query, input mode handling, transport resize/reporting,
    and adjacent interaction consumers now use that split directly
  - CSI reply/report now also uses one explicit reply snapshot in
    `csi_reply.zig` instead of hand-assembling cursor/geometry/color data
    inline in `csi.zig`
  - the input snapshot cache no longer hides under protocol mode state; it now
    sits under explicit derived snapshot ownership and the read-side consumers
    use that owner directly
  - the next question is no longer whether the mixed state should be
    reclassified; it is whether the next real slice is CSI reply/report
    ownership or a narrower remaining mixed-state pocket

- `docs/review/VT_PROTOCOL_INTERACTION_POST_CSI_RERANK_2026-04-03.md`
  Why: after the CSI ownership wave, the lane needs an honesty check before it
  turns into more local protocol cleanup by momentum.
  Current read:
  - the broad CSI mixed-state lie is materially flattened
  - protocol mode state, host contract state, derived snapshot state, and
    reply/report snapshot state are all explicit now
  - this lane is close to a stop-marker
  - only reopen it for one narrow reporting pocket if that pocket is clearly
    real
  - otherwise return to the deeper parser-owner / `TerminalCore` sufficiency
    question

- `docs/review/VT_POST_PROTOCOL_INTERACTION_RERANK_2026-04-03.md`
  Why: after the full protocol interaction wave, VT needs another top-level
  maturity rerank from the cleaner baseline.
  Current read:
  - broad CSI cleanup is no longer the next war
  - interaction bag splitting is no longer the next war
  - the next default pressure is deeper parser-owner / `TerminalCore`
    sufficiency again
  - a narrow reporting pocket is now only the fallback, not the main war

- `docs/review/VT_PROTOCOL_REPLY_SINK_CONTRACT_2026-04-03.md`
  Why: the post-protocol rerank needs one concrete parser-owner blocker
  sharper than vague “protocol discomfort.”
  Current read:
  - the next real blocker is protocol reply sink ownership
  - CSI, DCS, OSC, palette, and kitty reply paths still terminate directly on
    shell writer mechanics
  - the next credible war is therefore not more CSI cleanup, but a named
    reply-emission contract that keeps writer mechanics outside core while
    making protocol execution less shell-anchored

- `docs/review/VT_PROTOCOL_REPLY_SINK_SHAPE_2026-04-03.md`
  Why: the new blocker needs an exact first contract shape before code.
  Current read:
  - the first sink should be byte-oriented, not a vague writer-wrapper story
  - the best opening slab is the prebuilt-byte reply family:
    `dcs_apc.zig`, `osc_clipboard.zig`, and `palette.zig`
  - do not force CSI writer-driven replies into the first slice just for
    uniformity
  Progress:
  - the first byte-oriented sink slice is now landed
  - `protocol_reply_sink.zig` owns shell/runtime reply emission for byte
    replies
  - the prebuilt-byte reply family now uses that sink instead of direct
    `writePtyBytes(...)`
  - kitty OSC read replies now use the same sink too, which removes the last
    byte-built OSC reply family still anchored on a locked writer
  - CSI and kitty writer-driven replies remain intentionally out of this first
    slice

- `docs/review/VT_PROTOCOL_REPLY_SINK_RERANK_2026-04-03.md`
  Why: after the byte-oriented sink wave, this lane needs a stop-marker check
  before CSI gets forced into the same shape for symmetry.
  Current read:
  - the byte-oriented sink wave materially paid off
  - the remaining CSI family is writer-driven, so continuation would require a
    second explicit sink shape
  - otherwise this lane should stop and hand back to the deeper parser-owner /
    `TerminalCore` maturity question

- `docs/review/VT_POST_REPLY_SINK_RERANK_2026-04-03.md`
  Why: after the sink wave, VT needs a fresh maturity rerank from the stronger
  protocol baseline.
  Current read:
  - more sink work does not win by default
  - sink uniformity does not win at all
  - the next default pressure is deeper protocol execution maturity around
    `TerminalCore`
  - the next war should therefore name one semantic protocol cluster, not
    “reply sinks continued”

- `docs/review/VT_OSC_SEMANTIC_EFFECTS_WAR_2026-04-03.md`
  Why: the post-sink rerank now needs one named semantic protocol cluster to
  keep VT focused.
  Current read:
  - the next cluster is OSC semantic effects
  - title, cwd, progress, semantic prompt, and user-var handling are already
    mostly terminal-semantic in substance
  - the next maturity gain is likely one clearer core-side OSC semantic
    contract, not more shell/runtime surgery

- `docs/review/VT_OSC_SEMANTIC_SLAB_RANKING_2026-04-03.md`
  Why: the OSC war now needs one first code slab instead of broad OSC
  discomfort.
  Current read:
  - the first slab is title / cwd / progress
  - semantic prompt / user vars are second
  - broad `osc.zig` routing is not the war
  Progress:
  - the first slab is now landed under
    `src/terminal/core/protocol/terminal_core_osc_metadata.zig`
  - title, cwd normalization/publication, and progress semantics now live
    behind one core-side owner
  - protocol files now delegate there instead of carrying that semantic logic
    inline

- `docs/review/VT_OSC_POST_METADATA_RERANK_2026-04-03.md`
  Why: after the first OSC slab, the war needs an honesty check before it
  either stops or drifts into small helper cleanup.
  Current read:
  - the second slab is now landed under
    `src/terminal/core/protocol/terminal_core_osc_semantic.zig`
  - semantic prompt phase transitions/options, semantic command-line updates,
    and user-var mutation now live behind one core-side owner
  - `osc_semantic.zig` now delegates there instead of carrying the mutation
    logic inline
  - OSC is now close to a stop-marker unless one fresh whole semantic slab
    appears

- `docs/review/VT_OSC_STOP_MARKER_2026-04-03.md`
  Why: the OSC war now needs an honest stop-marker after both real slabs
  landed.
  Current read:
  - there is no third whole OSC semantic slab obvious enough to justify
    continuing
  - routing, hyperlink, and clipboard/kitty clipboard handling do not read
    like the same kind of omitted core-side semantic owner
  - the next VT pressure should return to the broader `TerminalCore`
    protocol-execution maturity question

- `docs/review/VT_POST_OSC_RERANK_2026-04-03.md`
  Why: after the OSC stop-marker, VT needs a fresh ranking from the stronger
  protocol baseline.
  Current read:
  - more OSC work does not win
  - more sink work does not win
  - the next default pressure is now CSI / ANSI mode semantics and screen
    effects

- `docs/review/VT_CSI_MODE_EFFECTS_WAR_2026-04-03.md`
  Why: the post-OSC rerank now needs one named protocol-execution cluster
  instead of broad parser-owner discomfort.
  Current read:
  - the next VT war is CSI / ANSI mode semantics and screen effects
  - the opening boundary is terminal mode/screen effects versus host-contract
    flag mutation
  - do not treat this as permission for broad CSI cleanup

- `docs/review/VT_CSI_MODE_EFFECTS_CONTRACT_2026-04-03.md`
  Why: the new war needs one exact first contract split before code drifts
  into generic CSI cleanup.
  Current read:
  - the first slice is terminal mode and screen effects
  - input protocol modes, host-contract flags, sync updates, and column-mode
    publishing stay outside
  Progress:
  - `src/terminal/core/protocol/terminal_core_csi_modes.zig` now owns the
    first terminal mode-and-screen-effects slab
  - `csi_mode_mutation.zig` now delegates that slab there instead of mixing it
    inline with outer contract mutation
  - `src/terminal/core/protocol/terminal_core_csi_mode_query.zig` now owns the
    corresponding read-side terminal mode snapshot/query slice
  - `csi_mode_query.zig` now delegates that terminal subset there while
    leaving input protocol state and host-contract flags outside

- `docs/review/VT_CSI_MODE_EFFECTS_RERANK_2026-04-03.md`
  Why: after the first full mutation/query wave, the lane needs an honesty
  check before it keeps going under the wrong war name.
  Current read:
  - the terminal mode-and-screen-effects slab is materially landed
  - the remaining pocket is now mostly input protocol and host-contract
    reporting state
  - if terminal continues immediately, that next war should be named as a new
    CSI input/reporting contract lane, not more mode-effects cleanup

- `docs/review/VT_CSI_INPUT_REPORTING_WAR_2026-04-03.md`
  Why: the post-mode-effects rerank now needs the next named protocol cluster
  instead of letting CSI drift under the wrong framing.
  Current read:
  - the next VT war is CSI input/reporting contract state
  - the likely first boundary is input protocol mode/query state versus
    host-reporting contract flags
  - do not collapse runtime-dependent reporting behavior into core just for
    symmetry

- `docs/review/VT_CSI_INPUT_REPORTING_CONTRACT_2026-04-03.md`
  Why: the new war needs one exact first split before code drifts into generic
  remaining-CSI cleanup.
  Current read:
  - the first slice is input protocol mode mutation plus DECRQM query state
  - host-reporting flags 2031/2048/5522 stay outside
  Progress:
  - `src/terminal/core/protocol/terminal_core_csi_input_modes.zig` now owns
    the first input protocol mode/query slab
  - `csi_mode_mutation.zig` and `csi_mode_query.zig` now delegate that subset
    there while leaving host-reporting flags outside

## War 4

- `docs/review/VT_PLUGANDPLAY_GAP_MATRIX_2026-04-03.md`
  Why: the next terminal push should stop hopping seam-by-seam and use one
  ranked, comprehensive plug-and-play comparison instead.
  Current read:
  - Zide is now credibly extractable, but still not near true plug-and-play
    parity with `libghostty-vt`
  - the top blocker is host-driving input semantics still feeling too
    shell-centered
  - the next blockers after that are `TerminalCore` sufficiency and the public
    resize story, not publication/runtime sludge
  - immutable export, runtime shell size, and `host_queries.zig` no longer
    deserve default-war status
- `docs/review/VT_INPUT_SEMANTICS_WAR_2026-04-03.md`
  Why: the plug-and-play matrix now makes the next war explicit instead of
  leaving "input" as a vague discomfort.
  Current read:
  - the next uninterrupted VT focus is host-driving input semantics
  - the only honest opener inside that war remains key/char semantic dispatch
    before encoding
  - do not widen this into generic input cleanup, transport rewriting, or
    shell-thinning theater
  Progress:
  - the first key-action slice is now landed
  - `TerminalCore` now owns the semantic key-action dispatch decision while
    shell input still owns lock/writer/encoding
  - keypad-action dispatch is now landed under the same owner too
  - `TerminalCore` now also owns repeat gating, press-only emission, and
    app-keypad mode use for keypad input
  - alternate-scroll mapping is now landed under the same owner too
  - `TerminalCore` now also owns alternate-scroll mode gating, alt-screen
    gating, and arrow-key intent selection
  - char-action dispatch is now landed under the same owner too
  - `TerminalCore` now also owns repeat suppression and local-echo
    eligibility, while shell input still owns fallback execution when no
    writer exists
  - the remaining `session/input.zig` surface now reads mostly writer-shaped
    or reporting-shaped:
    `sendText(...)`, `sendBytes(...)`, mouse reporting, focus reporting, and
    color-scheme reporting
  - so this war should now stop from the stronger baseline unless a new input
    slab appears that is terminal-semantic in substance and separable from
    writer selection, protocol encoding, and transport/reporting
- `docs/review/VT_POST_INPUT_RERANK_2026-04-03.md`
  Why: now that the input war is closed, the VT queue needs a fresh top item
  instead of stale momentum.
  Current read:
  - the top blocker is no longer shell-centered input semantics
  - the top blocker is now `TerminalCore` sufficiency again
  - public resize remains the next most concrete parity gap after that
  - viewport/selection mutation surface is still worth watching, but is now
    clearly second-order
  - `host_queries.zig` and ABI breadth remain lower-priority guardrails, not
    the default war
- `docs/review/VT_PUBLIC_RESIZE_WAR_2026-04-03.md`
  Why: after the post-input rerank, public resize was the clearest next
  concrete parity gap that still had a clean code slice.
  Current read:
  - the old public resize story was split across `setCellSize(...)` and
    `resize(...)`, and FFI taught a different order than native paths
  - the new host-facing contract is `resizeWithCellSize(...)`
  - semantic resize stays core-owned, while locking, transport resize, and
    in-band reporting stay shell/runtime-owned
  - this improves the public VT story without reopening shell-thinning theater
- `docs/review/VT_POST_RESIZE_RERANK_2026-04-03.md`
  Why: after the resize wave, the VT queue needs another honest rerank from
  the new baseline.
  Current read:
  - public resize is materially healthier and no longer the default next war
  - `TerminalCore` sufficiency is still the top blocker
  - viewport/selection mutation surface is now the clearest concrete fallback
  - input, `host_queries`, and generic shell-thinning should remain paused
- `docs/review/VT_VIEWPORT_SELECTION_WAR_2026-04-03.md`
  Why: no crisp new `TerminalCore` sufficiency slab emerged immediately after
  the resize rerank, so the concrete fallback war is now opened directly.
  Current read:
  - the first clean slice was deleting dead session mutation facades
  - live callers now use the real mutation owners directly:
    `scrollback_view.zig` and `selection.zig`
  - this removes one more residual session-shaped layer from the host mutation
    story without reopening generic shell-thinning
- `docs/review/VT_POST_VIEWPORT_SELECTION_RERANK_2026-04-03.md`
  Why: after the first viewport/selection slice, the queue needs another
  honesty check before more code.
  Current read:
  - `selection.zig` and `scrollback_view.zig` now read mostly honest:
    lock ownership + publication refresh around core mutation truth
  - this lane is close to a stop-marker now
  - the stronger remaining pressure is broader `TerminalCore` sufficiency
    again, not another obvious local mutation cut
- `docs/review/VT_SPRINT_STOP_MARKER_2026-04-03.md`
  Why: after the recent VT waves, the queue needs an explicit stop-marker so
  we do not turn broader sufficiency discomfort into fake progress.
  Current read:
  - there is no new honest small-cut contradiction obvious enough to justify
    more VT code right now
  - the remaining gap versus Ghostty/WezTerm is now broader library-object
    feel and design quality
  - reopen VT only if a future pass names one specific deeper `TerminalCore`
    capability or object-model gap

- `docs/review/VT_WAR_4_SCOPE_AND_SEEDS_2026-04-03.md`
  Why: the next scrutiny pass is no longer a cleanup sprint; it is a focused
  design/comparison war around the remaining `zide-vt` plug-and-play gap.
  Current read:
  - the battlefield is now whether one specific missing `TerminalCore`
    capability or host-contract weakness still blocks a credible swappable VT
    library story
  - the work should run as parallel scrutiny tracks:
    engine sufficiency, shell legitimacy, public/FFI contract shape, internal
    caller dependence, and mature-reference pressure
  - success means either naming one real missing capability slab or concluding
    that the remaining gap is mostly normalization/maturity rather than another
    obvious architecture contradiction
- `docs/review/VT_WAR_4_INITIAL_FINDINGS_2026-04-03.md`
  Why: the first master scan now has enough evidence to rank the likely
  remaining contradiction before the full cross-reference wave is complete.
  Current read:
  - the strongest remaining mismatch is shell-anchored host instantiation and
    opaque-handle identity, not shell file size
  - `host_queries.zig` now reads mostly like honest mixed runtime aggregation
  - the public contract is broader than Ghostty's `vt.h`, but the stronger
    question is whether that broad host contract is still anchored on the shell
    instead of a more engine-centered contract story
- `docs/review/VT_WAR_4_CALLER_DEPENDENCE_REVIEW_2026-04-03.md`
  Why: the caller map should prove whether the shell still has fake gravity or
  whether the remaining problem is narrower contract identity.
  Current read:
  - most remaining shell use now looks legitimate
  - widget and workspace paths mostly use the shell for synchronization or
    honest runtime aggregation
  - the strongest remaining suspect is the FFI handle/constructor path that
    still makes the shell the universal host entrypoint
- `docs/review/VT_WAR_4_SYNTHESIS_2026-04-03.md`
  Why: the first comparison wave is now converged enough to stop broad
  scanning and name the strongest remaining contradiction.
  Current read:
  - the shell itself is no longer the war
  - `host_queries.zig` is no longer the main fake center
  - the strongest remaining plug-and-play mismatch is shell-centered host
    handle and constructor identity in the FFI boundary
  - the next fallback target, if that handle story proves acceptable, is a
    deeper host-to-terminal interaction slab that still feels more shell-owned
    than terminal-owned
- `docs/review/VT_WAR_4_HANDLE_IDENTITY_REVIEW_2026-04-03.md`
  Why: the next question is no longer whether the shell is too large.
  It is whether the public host entrypoint still teaches the wrong library
  story.
  Current read:
  - the opaque FFI handle still stores `*TerminalRuntimeShell`
  - creation is still shell-first and transport-attaching immediately after
    shell construction
  - this now looks like the strongest remaining plug-and-play mismatch
- `docs/review/VT_WAR_4_HANDLE_DECISION_2026-04-03.md`
  Why: the stronger claim above needed one more pass against the actual public
  ABI instead of internal storage alone.
  Current read:
  - the public API already exports an opaque terminal-named handle, not a
    shell-named object
  - shell-backed handle storage is therefore weaker as a contradiction than it
    first appeared
  - the stronger remaining War 4 pressure is now host-to-terminal interaction
    ownership, not handle storage shape by itself
- `docs/review/VT_WAR_4_INTERACTION_OWNERSHIP_REVIEW_2026-04-03.md`
  Why: after the handle check, the next strongest comparison pressure is no
  longer handle identity but where live terminal-driving semantics terminate.
  Current read:
  - output application, host input/reporting, and resize still read more
    shell-owned than terminal-owned
  - transport/lifecycle/thread mechanics should stay shell-owned
  - the next code war should only open on one named interaction slab
- `docs/review/VT_WAR_4_INTERACTION_SLAB_RANKING_2026-04-03.md`
  Why: the interaction war should not open on a vague category.
  It should open on the cleanest first slab.
  Current read:
  - output feed/apply is the strongest first target
  - resize is second because it mixes real terminal resize with transport
    reporting and in-band notifications
  - encoded host input is third because it is more tightly coupled to writer
    mechanics
  Progress:
  - the first feed/apply slice is now landed:
    `TerminalCore` owns the semantic `feedOutputBytesLocked(...)` verb while
    `terminal_core_feed.zig` stays responsible for shell-owned locking and
    publication handoff
  - runtime parse paths and debug feed now use that same core-owned verb too,
    making output feed/apply materially coherent as one interaction slab
- `docs/review/VT_WAR_4_RESIZE_REPORT_REVIEW_2026-04-03.md`
  Why: output feed/apply is now coherent enough to stop by default.
  The next clean interaction slab is resize/reporting.
  Current read:
  - terminal resize/reflow semantics should read more terminal-owned
  - transport resize and in-band notifications should stay shell/runtime-owned
  Progress:
  - the first slice is now landed:
    `TerminalCore` owns the semantic `resizeLocked(...)` verb while
    `resize_reflow.zig` still owns shell locking and transport resize/reporting
- `docs/review/VT_WAR_4_POST_RESIZE_RERANK_2026-04-03.md`
  Why: after the first two interaction wins, the next move is no longer
  automatic.
  Current read:
  - encoded host input is still the next candidate
  - but it is more tightly coupled to writer/transport mechanics than the
    first two slabs
  - it needs one more design pass before code, or War 4 should stop and rerank
- `docs/review/VT_WAR_4_INPUT_INTERACTION_DESIGN_2026-04-03.md`
  Why: the remaining input lane needed a real design pass before any code cut.
  Current read:
  - text/byte send, focus/color-scheme reporting, and mouse reporting are all
    too transport/writer-shaped to be good immediate core moves
  - the only plausible next candidate is key/char semantic dispatch before
    writer encoding
  - even that needs a stricter design line first, or War 4 should stop here
- `docs/review/VT_WAR_4_STOP_MARKER_2026-04-03.md`
  Why: War 4 now has two real interaction wins and one honest pause point.
  Current read:
  - feed/apply and resize/reporting were real ownership wins
  - encoded host input did not yield a safe immediate cut
  - continue only by opening a deeper key/char semantic-dispatch design step
    or stop and rerank from this baseline
- `docs/review/VT_WAR_4_KEYCHAR_DISPATCH_REVIEW_2026-04-03.md`
  Why: the stop-marker needed one explicit named continuation path instead of
  vague "input" pressure.
  Current read:
  - the only credible continuation is key/char semantic dispatch before writer
    encoding
  - semantic decisions like app-cursor fallback, key-mode gating, ctrl/alt
    char fallback, and alternate-scroll mapping still feel more
    terminal-facing than writer-facing
  - locking, writer selection, and protocol encoding still belong outside core
  - do not continue unless that line can be expressed as one crisp result
    shape without pulling transport mechanics into `TerminalCore`
- `docs/review/VT_WAR_4_KEYCHAR_RESULT_SHAPE_2026-04-03.md`
  Why: the next step after naming the key/char lane is defining the exact
  semantic result shape that would justify code.
  Current read:
  - the result must stay terminal-semantic, not writer-shaped
  - it can plausibly cover key intent, char intent, keypad intent, suppression,
    and local fallback intent
  - it must not embed writer handles, encoded bytes, or PTY/external transport
    choice
  - if that line cannot stay crisp, War 4 should remain closed
- `docs/review/VT_WAR_4_KEYCHAR_DECISION_2026-04-03.md`
  Why: the result-shape work needed an explicit go/no-go decision instead of
  leaving War 4 in indefinite suspense.
  Current read:
  - local echo fallback is still selected on writer absence, which keeps the
    key/char lane mixed at the shell boundary
  - that means the lane improved in design clarity but still does not justify
    a code cut from this baseline
  - War 4 should remain closed unless that fallback ambiguity is resolved by a
    stronger future design step

## Priority Now

Highest-value remaining items from the current live baseline:

1. `VTWAR4-01` re-rank host-to-terminal interaction ownership
   Why: after the public-ABI check, this now looks like the stronger remaining
   plug-and-play pressure. Live terminal-driving semantics still feel more
   shell-owned than terminal-owned.
   First slab:
   - output feed / apply
   Second slab:
   - resize / report contract
   Current state:
   - encoded host input is the next candidate, but not yet a safe immediate cut
   Design bar:
   - only continue if key/char semantic dispatch can be separated cleanly from
     writer encoding and transport mechanics
   Stop marker:
   - War 4 remains at a legitimate pause point from a materially stronger
     baseline, even after the deeper key/char design pass
2. `VTWAR4-02` keep handle identity as a checked-but-paused concern
   Why: the handle is already opaque and terminal-named publicly, so changing
   internal shell-backed storage alone risks cosmetic surgery.
3. `VTWAR4-03` keep `host_queries.zig` honest but paused
   Why: this is now mostly legitimate mixed runtime aggregation and should not
   be reopened by momentum.
4. `VTWAR4-04` keep contract breadth under scrutiny without narrowing it by dogma
   Why: Zide's host contract is broader than Ghostty's narrow `vt.h`, but the
   key question is contract anchoring, not raw function count.

Supporting cuts:

- `VTCORE-03` transport is already real; keep it narrow and prevent it from
  becoming a second semantic center
- `VTCORE-07` remains a guardrail: native must become the sharpest host, not a
  special host

Focused follow-up lane:

- `docs/review/TERMINAL_WAR_3_LIBRARY_BOUNDARY_RERANK_2026-04-02.md`
  Why: War 2 micro-lanes are no longer the real center of gravity. The next
  serious question is whether the live terminal stack reads like a real
  `zide-vt` library boundary at all.
  Current read:
  - Zide is now rich enough at the host-contract layer
  - the remaining blocker is architecture shape, not capability volume
  - War 3 should open on the engine/library boundary itself
- `docs/review/TERMINAL_WAR_3_LIBRARY_CENTER_REVIEW_2026-04-02.md`
  Why: the first concrete War 3 question is what still prevents the live stack
  from reading like one unmistakable library center plus runtime shell plus
  export boundary.
  Current read:
  - the main blocker is now a three-way center-of-gravity split between
    `terminal_core.zig`, `session/runtime.zig`, and `terminal_publication.zig`
  - the target shape is explicit:
    `TerminalCore` as library center, `session/runtime.zig` as runtime shell,
    `terminal_publication.zig` as export boundary
  - the next cut should remove the single largest contradiction to that shape,
    not merely shrink those files incrementally
- `docs/review/TERMINAL_WAR_3_PUBLICATION_CONTRADICTION_REVIEW_2026-04-02.md`
  Why: the first concrete War 3 contradiction is now clearer.
  Current read:
  - publication is the stronger contradiction than runtime
  - `session/runtime.zig` already reads closer to runtime shell
  - `terminal_publication.zig` still reads too much like a real center
  Progress:
  - the first whole-slab move is now landed
  - generation mutation, view-refresh choreography, and output-pending flow
    now live in `src/terminal/core/publication/publication_flow.zig`
    instead of inflating `terminal_publication.zig`
  - the second whole-slab move is now landed too
  - widget presentation capture/preparation now lives in
    `src/terminal/core/publication/publication_capture.zig`
    instead of inflating `terminal_publication.zig`
  - the third whole-slab move is now landed too
  - host-facing generation/frame summary packaging now lives in
    `src/terminal/core/publication/publication_state.zig`
    instead of inflating `terminal_publication.zig`
  - callers now use that owner directly, so the next publication rerank can
    focus on the remaining export-edge contradiction
  - the next whole-slab move is now landed too
  - sync-updates now lives in
    `src/terminal/core/protocol/sync_updates.zig`
    instead of inflating `terminal_publication.zig`
  - current rerank: the broad publication false-center is materially reduced;
    the next honest question is likely broader War 3 center-of-gravity again,
    not more publication-by-momentum cleanup
- `docs/review/TERMINAL_WAR_3_POST_PUBLICATION_RERANK_2026-04-02.md`
  Why: publication is no longer the default War 3 enemy after the recent
  whole-slab cuts.
  Current read:
  - publication now reads much closer to a boring export edge
  - the next likely contradiction is runtime-shell assembly and storage weight
    in `session/runtime.zig`
- `docs/review/TERMINAL_WAR_3_RUNTIME_CONTRADICTION_REVIEW_2026-04-02.md`
  Why: with publication materially reduced, the next concrete War 3 question is
  now runtime-shell shape.
  Current read:
  - `session/runtime.zig` is behaviorally narrower than before
  - but it still reads too much like important terminal ownership because it
    owns session allocation, storage-layout assembly, lifecycle entrypoints,
    and launch-shell-path state
  Progress:
  - the first runtime-shell slab is now landed
  - session allocation and storage-layout assembly now live in
    `src/terminal/core/session/runtime_init.zig`
    instead of inflating `session/runtime.zig`
  - the next runtime-shell slab is now landed too
  - launch-shell-path state now lives in
    `src/terminal/core/session/launch_shell_path.zig`
    instead of inflating `session/runtime.zig`
  - the next runtime-shell slab is now landed too
  - teardown, child-exit refresh/reporting, and poll now live in
    `src/terminal/core/session/runtime_lifecycle.zig`
    instead of inflating `session/runtime.zig`
- `docs/review/TERMINAL_WAR_3_POST_RUNTIME_RERANK_2026-04-02.md`
  Why: the first runtime-shell wave materially landed, so War 3 needs a fresh
  rerank from the cleaner baseline.
  Current read:
  - runtime and publication roots now read much closer to shell/export edges
  - the next likely contradiction is the aggregate session object model around
    `PtyTerminalRuntime`, not more runtime helper shaving
- `docs/review/TERMINAL_WAR_3_SESSION_OBJECT_REVIEW_2026-04-02.md`
  Why: the next concrete War 3 question is now the owning session/library
  object model.
  Current read:
  - `PtyTerminalRuntime` still reads like the visible aggregate center
  - `TerminalCore` is real, but still not visibly the owning library center
  - the next likely battlefield is the aggregate session shape itself
  Progress:
  - the first session-object cut is now landed
  - `PtyTerminalRuntime` no longer stores `runtime`, `interaction`,
    `publication`, and `control` as peer root fields beside `core`
  - those non-engine domains now live under one grouped
    `src/terminal/core/session/session_fields.zig` slab as `session`
  - the visible library shape is materially cleaner than the earlier flat
    aggregate
  - the aggregate type definition now also lives under
    `src/terminal/core/session/terminal_session.zig` as `TerminalSession`
    instead of being defined inline in `terminal_runtime.zig`
- `docs/review/TERMINAL_WAR_3_POST_SESSION_OBJECT_RERANK_2026-04-02.md`
  Why: the first session-object wave materially landed, so War 3 now needs a
  narrower rerank from the cleaner baseline.
  Current read:
  - the strongest remaining contradiction is likely the public root identity
  - the owning type is now `TerminalSession`, but the public root still only
    says `PtyTerminalRuntime`
  Progress:
  - the public root now exports `TerminalSession` directly
  - `PtyTerminalRuntime` remains only as compatibility residue
- `docs/review/TERMINAL_WAR_3_POST_IDENTITY_RERANK_2026-04-02.md`
  Why: after the identity correction, War 3 needs another hard rerank before
  any more cuts.
  Current read:
  - no new local whole-slab contradiction is immediately obvious
  - the next honest question is whether `TerminalCore` now reads strongly
    enough as the indisputable library center
  Reference pressure:
  - Ghostty still wins the cleanest first-glance library-center story
  - WezTerm reinforces the same maturity bar
  - current Zide read is now close enough that the next move should come from
    a deeper object-model review or a stop-marker, not more local helper cuts
- `docs/review/TERMINAL_WAR_3_CORE_CENTER_REVIEW_2026-04-02.md`
  Why: the remaining War 3 question is no longer local ownership cleanup.
  Current read:
  - the stronger references still make the engine object itself read more
    obviously like the library
  - Zide is much closer now, but `TerminalCore` still reads more like the
    dominant field inside `TerminalSession` than the fully sufficient public
    center
  - this is now too ambiguous for momentum-driven surgery
- `docs/review/TERMINAL_WAR_3_CLOSURE_2026-04-02.md`
  Why: War 3 reached its honest stop-marker.
  Current read:
  - the strongest visible library-boundary contradictions are materially gone
  - the remaining gap is a deeper object-model design question, not a local
    cleanup lane
- `docs/review/TERMINAL_POST_WAR_3_RERANK_2026-04-02.md`
  Why: after closing War 3, the next battlefield must be chosen from the new
  baseline rather than inherited momentum.
- `docs/review/VT_CORE_CONTRACT_COMPARISON_2026-04-02.md`
  Why: `vt-sprint` now needs a direct cross-implementation contract read
  against Zide, Ghostty, and WezTerm.
  Current read:
  - the directly comparable battlefield is the VT-core contract itself
  - the strongest remaining mismatch is no longer publication or runtime file
    weight
  - the strongest mismatch is that `TerminalCore` still reads like the real
    engine while `TerminalSession` still reads like the real public object
  - the next sprint step must therefore choose the actual `zide-vt` library
    object instead of continuing local cleanup around that ambiguity
  Progress:
  - the first `vt-sprint` code cut is now the immutable scrollback/export slab
  - `TerminalCore` now owns read-only scrollback summary and export directly
  - `TerminalSession` no longer advertises the duplicate read-only scrollback
    surface as if that immutable content were session-shell ownership
  - the immutable selection-text export now moved the same way too
  - `TerminalSession` no longer advertises immutable selection/scrollback text
    export as its own public content slab
  - the next same-class move is now in flight too:
    simple engine metadata reads should come from `TerminalCore` directly
    wherever they do not need runtime-shell aggregation
  - the root VT surface now also exports `TerminalCore` directly so the engine
    object is no longer hidden behind only `TerminalSession`/`PtyTerminalRuntime`
    at the main entrypoint
  - app/UI/FFI callers now use `TerminalSession` directly; `PtyTerminalRuntime`
    is reduced to compatibility residue at the VT root
  - workspace and replay-harness infrastructure now use `TerminalSession`
    directly too; the old PTY name is mostly down to compatibility and
    historical test naming
  - the next strongest `vt-sprint` contradiction is no longer naming; it is the
    mutable host-interaction slab still living on `TerminalSession`

- `docs/review/VT_CORE_MUTATION_CONTRACT_REVIEW_2026-04-02.md`
  Why: immutable reads now look core-owned enough; the remaining serious
  plug-and-play blocker is mutable host interaction still needing
  `TerminalSession` because publication invalidation is coupled there
  Progress:
  - the first whole mutable-host slab has now moved in the selection lane
  - higher-level selection semantics now live under `TerminalCore`
  - session-side selection is narrower: lock, call core mutation, refresh
  - the first viewport follow-through is now in too:
    `TerminalCore` owns host-facing scrollback mutation verbs while
    `scrollback_view.zig` keeps lock + publication refresh + UI normalization
  - live widget/FFI callers now use the real session mutation owners directly
    for publication-aware mutation instead of routing those convenience verbs
    through `TerminalSession`
  - the mutation alias slab is now deleted from `TerminalSession`; live code no
    longer treats it as the home for selection/scrollback convenience verbs

- `docs/review/VT_SPRINT_POST_MUTATION_RERANK_2026-04-02.md`
  Why: the sprint is now past helper cleanup; the next blocker is explicit
  object-identity design around `TerminalCore` vs `TerminalSession`
  Progress:
  - `snapshot` is now off `TerminalSession` too
  - replay and regression callers use publication directly for snapshot export
  - the remaining `TerminalSession` story is now init + locking + PTY writer
    shell, which sharpens the next design decision
- `docs/review/VT_SESSION_REMOVAL_DESIGN_2026-04-02.md`
  Why: the sprint bar is now explicit.
  Current read:
  - `TerminalSession` should not merely get smaller; it should disappear
  - the remaining blockers are no longer helper residue
  - the remaining blockers are construction identity, lock ownership, and
    PTY/runtime shell ownership
  - the next code wave should therefore build the replacement shape for those
    responsibilities instead of continuing opportunistic cleanup
  Progress:
  - the first identity step is now landed
  - the outer shell is explicitly named
    `src/terminal/core/session/terminal_runtime_shell.zig`
  - the VT root now exports `TerminalRuntimeShell` directly
  - live app/UI/workspace/replay/FFI callers now use `TerminalRuntimeShell`
    instead of `TerminalSession`
  - `terminal_session.zig` was then deleted entirely
  - the VT root no longer exports `TerminalSession`
  - live `src/` code no longer depends on a `TerminalSession` type at all
  - the historical `PtyTerminalRuntime` alias was then deleted too
  - live `src/` code now reads as `TerminalCore` plus `TerminalRuntimeShell`

- `docs/review/VT_SPRINT_POST_SHELL_RERANK_2026-04-02.md`
  Why: with `TerminalSession` and `PtyTerminalRuntime` gone from live code, the
  next blocker is no longer naming cleanup.
  Current read:
  - the outer shell is now honest enough in name and scope
  - the next plug-and-play question is whether `TerminalCore` is sufficiently
    complete beneath that shell
  - the next code wave should therefore rank `TerminalCore` sufficiency against
    shell-owned responsibilities instead of deleting more compatibility residue

- `docs/review/VT_CORE_SUFFICIENCY_REVIEW_2026-04-02.md`
  Why: the next live sprint pressure is now engine sufficiency beneath the
  shell, not shell identity.
  Progress:
  - the first post-shell sufficiency cut is landed
  - immutable clipboard and hyperlink reads no longer route through
    `src/terminal/core/session/queries.zig`
  - FFI and widget callers now follow the cleaner contract:
    shell provides synchronization, core provides the terminal answer
  - `src/terminal/core/session/queries.zig` is deleted

- `docs/review/VT_SPRINT_POST_CORE_SUFFICIENCY_RERANK_2026-04-03.md`
  Why: the easiest `TerminalCore` sufficiency cuts are now largely landed.
  Current read:
  - the remaining `TerminalRuntimeShell` surface mostly reads as legitimate
    runtime shell, not fake gravity
  - the next gap is either a deeper `TerminalCore` sufficiency design step or a
    clean sprint stop-marker
  - the next move should not be another small extraction by momentum alone

- `docs/review/VT_SPRINT_DEEPER_SUFFICIENCY_DECISION_2026-04-03.md`
  Why: the sprint now needs an explicit go/no-go decision.
  Current read:
  - there is no fresh small-cut contradiction obvious enough to justify more
    local extraction
  - continue only if one specific missing `TerminalCore` capability slab can be
    named first
  - otherwise the honest move is to close `vt-sprint` cleanly from the current
    baseline

- `docs/review/TERMINAL_NATIVE_ARCHITECTURAL_SCRUTINY_2026-03-31.md`
  Why: this is the current ruthless read on what still looks second-rate at
  first glance and what should be demolished first.
- `docs/review/CURRENT_ARCHITECTURE_RERANK_2026-04-02.md`
  Why: the last two weeks materially changed the implementation, so current
  priority now needs to be judged from live code rather than only from older
  review pressure.
- `docs/review/TERMINAL_PUBLICATION_CONTRACT_REVIEW_2026-04-02.md`
  Why: the next terminal battlefield is no longer tiny publication helper
  cleanup; it is identifying the single dominant host-facing terminal
  frame/publication contract.
  Progress:
  - publication now owns the frame/publication snapshot shape directly and
    workspace forwards the active-session contract instead of rebuilding those
    booleans locally
  - frame pacing now consumes that publication-owned snapshot type directly,
    so the next likely ambiguity has shifted away from pacing summaries and
    toward remaining widget-local presentation handoff state
  - that widget-local handoff state now appears mostly honest local host render
    state, so this lane should not keep grinding tiny widget/publication
    extractions without a broader new contract question
- `docs/review/TERMINAL_HOST_CONTRACT_REVIEW_2026-04-02.md`
  Why: after the publication-contract cleanup wave, the next likely native
  terminal battlefield is broader host aggregation and orchestration shape,
  especially `workspace.zig` plus the draw/runtime path.
  Current read:
  - `workspace.zig` is now the strongest remaining native-host aggregate center
  - first real host cut landed: active-session host convenience and
    close-confirm routing now live under
    `src/terminal/core/workspace_host.zig` instead of inflating the main
    workspace aggregate
  - tab sync packaging now lives there too, so the next workspace question is
    whether the remaining workspace surface is now honest enough to stop, or
    whether another real host/runtime convenience slab still belongs elsewhere
  - visible-frame follow-through started too: tab-bar sync no longer rides
    inside `visible_terminal_frame_hooks_runtime.handle(...)`; callers now do
    that post-step themselves, which narrows the visible-frame hook contract
  - the extra single-caller shell `visible_terminal_frame.zig` is gone too;
    the live visible-terminal poll/input routing now sits directly in
    `visible_terminal_frame_hooks_runtime.zig`
  - post-present cleanup is tighter too: terminal presentation-feedback flush
    no longer lives under `terminal_draw_surface_runtime.zig`; it now runs in
    `present_feedback_runtime.zig` with the rest of present completion
  - current rerank: this exact host-aggregation lane is now close to
    diminishing returns; the next terminal move should come from a broader
    engine/publication/native-host rerank, not more local host cleanup by
    momentum
- `docs/review/TERMINAL_WAR_2_RERANK_2026-04-02.md`
  Why: War 1 is now coherent enough to close. The next terminal campaign
  should begin from a fresh top-level rerank against live code and the
  strongest local references, not by inheriting momentum from the old
  micro-lanes.
- `docs/review/TERMINAL_WAR_2_SCOUTING_2026-04-02.md`
  Why: first War 2 scouting found two serious candidates:
  - structural recentering around one engine-owned host-state boundary
  - present/render correctness discipline around submitted terminal truth
  War 2 should start only after choosing explicitly between them.
- `docs/review/TERMINAL_WAR_2_PRESENT_INVARIANT_REVIEW_2026-04-02.md`
  Why: that choice is now made. War 2 should open on present/render
  correctness discipline and define the exact native terminal present
  acknowledgement invariant before the next code cuts.
- `docs/review/TERMINAL_WAR_2_PRESENT_INVARIANT_IMPLEMENTATION_2026-04-02.md`
  Why: the first War 2 implementation contract is now explicit:
  terminal presentation may only retire once submitted scene truth proves the
  authoritative retained terminal surface was actually present for the
  acknowledged generation.
  Current read:
  - the first present-invariant wave is materially complete
  - renderer submission proof is now the retirement authority
  - weak widget-local retirement signals are deleted
  - the next honest question is no longer the ack gate itself
  - it is whether a real scene-composition omission path still exists
- `docs/review/TERMINAL_WAR_2_POST_PRESENT_RERANK_2026-04-02.md`
  Why: after the present-invariant wave landed, the dominant terminal enemy
  likely shifted back to structural pressure.
  Current read:
  - present acknowledgement ambiguity is no longer the center
  - `terminal_publication.zig` is again the heaviest remaining non-engine
    center
  - the next likely War 2 opener is a fresh publication-boundary review from
    the live post-present codebase, not more present cleanup by momentum
- `docs/review/TERMINAL_PUBLICATION_BOUNDARY_REVIEW_2026-04-02.md`
  Why: post-present, the next worthwhile terminal question is whole-boundary
  shape.
  Current read:
  - publication still mixes storage choreography, export contract, capture,
    retirement policy, and draw-state inspection helpers
  - that is cleaner than War 1, but still broader than the narrowest engine
    export boundary should read
  Progress:
  - the first larger cut landed: widget-facing cache inspection and draw/view
    helpers now live in `src/ui/widgets/terminal_widget_view_state.zig`
    instead of inflating publication
  - the second larger cut landed too: low-level cache slot choreography now
    lives in `src/terminal/core/publication/view_cache_publication.zig`
    instead of inflating publication
  - the third larger cut landed too: present-retirement policy now lives in
    `src/terminal/core/publication/presentation_feedback.zig` instead of
    inflating publication
  - current rerank: `terminal_publication.zig` is now much smaller and reads
    closer to a real engine export boundary
  - the next cut should only continue if a fresh review still finds one more
    large false center in the reduced shape
- `docs/review/TERMINAL_WAR_2_POST_PUBLICATION_RERANK_2026-04-02.md`
  Why: after the publication-boundary wave, the default War 2 enemy changes
  again.
  Current read:
  - publication is no longer obviously the main battlefield by default
  - the next likely structural enemy is broader native host aggregation
    clarity
  - the strongest local fallback candidate is the widget/retained-render
    center if the host path now reads honest enough
- `docs/review/TERMINAL_HOST_AGGREGATION_RERANK_2026-04-02.md`
  Why: the next live War 2 decision is whether native host aggregation is
  still too distributed.
  Current read:
  - broader native host aggregation clarity still beats the widget pair as the
    next default battlefield
  - the native host path still reads more distributed than the cleanest
    reference-grade host/runtime split
  - the next question is what the one unmistakable native host-facing terminal
    aggregate should be now
  Progress:
  - active frame state, poll metrics, and poll counters now live under
    `src/terminal/core/workspace_host.zig` as host-facing summary accessors
    instead of hanging off `workspace` directly
  - the host-facing workspace poll entrypoint and poll policy slab now live
    there too
  - `src/app/terminal/terminal_poll_runtime.zig` is now narrowed to the
    single-session fallback path instead of acting as the workspace poll
    orchestration surface
  - current rerank: this lane is now much closer to a stop-marker
  - the remaining split across `workspace_host`, visible-frame hooks, and draw
    now reads narrower and more honest than the earlier distributed host path
  - do not keep cutting here by momentum unless a larger visible-frame false
    center becomes obvious again
- `docs/review/TERMINAL_WAR_2_POST_HOST_RERANK_2026-04-02.md`
  Why: after the host-aggregation wave, the top-level War 2 ranking changes
  again.
  Current read:
  - publication is no longer the default enemy
  - host aggregation is now much closer to honest
  - parser/protocol still matter, but no longer dominate first-glance read
  - the next likely battlefield is now the widget / retained-render center
- `docs/review/TERMINAL_WIDGET_RETAINED_RENDER_REVIEW_2026-04-02.md`
  Why: the post-host rerank now points directly at the widget/render lane.
  Current read:
  - `terminal_widget.zig` now looks more like honest local widget state
  - the real local pressure point is likely
    `src/ui/widgets/terminal_widget_draw.zig`
  - the next serious question is whether retained-surface planning/execution
    inside that file still needs a clearer owner boundary
  Progress:
  - the first non-draw secondary slab is now gone
  - draw latency metrics now live in
    `src/ui/widgets/terminal_widget_draw_metrics.zig`
    instead of inflating `terminal_widget_draw.zig`
  - kitty upload/update orchestration now also runs through
    `src/ui/widgets/terminal_widget_kitty.zig`
    instead of living inline in `terminal_widget_draw.zig`
  - current rerank: this lane is now approaching a stop-marker
  - the remaining weight in `terminal_widget_draw.zig` is much closer to
    actual retained-surface planning/execution
  - do not keep splitting it by momentum unless one more real owner boundary
    becomes obvious
- `docs/review/TERMINAL_WAR_2_POST_WIDGET_RERANK_2026-04-02.md`
  Why: after the first widget/render wave, the top-level War 2 ranking
  changes again.
  Current read:
  - widget/render is no longer obviously the default enemy
  - publication and host aggregation remain paused
  - the next likely structural battlefield is again parser / text semantics
    below the VT boundary
- `docs/review/TERMINAL_PARSER_TEXT_BOUNDARY_REVIEW_2026-04-02.md`
  Why: the post-widget rerank now points directly at parser / semantic-text
  boundary quality.
  Current read:
  - this lane is no longer about wrapper theater
  - the strongest first cut is likely the remaining ESC semantic effect slab
    still routed inline from `src/terminal/parser/parser.zig`
  Progress:
  - that first cut is now landed
  - the ESC semantic effect slab now lives in
    `src/terminal/core/protocol/esc_effects.zig`
    instead of being coordinated inline from `parser.zig`
  - decoded parser dispatch now also lives below the parser boundary in
    `src/terminal/core/protocol/parser_dispatch.zig`
    instead of being hand-routed inline from `parser.zig`
  - current rerank: this lane is now approaching a stop-marker too
  - `parser.zig` reads much closer to parser-local state plus state-machine
    flow over a narrower engine-owned dispatch surface
  - do not keep cutting here by momentum unless one more real semantic slab
    becomes obvious
- `docs/review/TERMINAL_WAR_2_POST_PARSER_RERANK_2026-04-02.md`
  Why: after the first parser wave, the top-level War 2 ranking changes again.
  Current read:
  - the structural false-center wars are no longer the obvious default move
  - the next likely War 2 opener is now the concrete present composition
    omission bug path
- `docs/review/TERMINAL_PRESENT_OMISSION_BUG_REVIEW_2026-04-02.md`
  Why: the post-parser rerank now points back to a concrete native present
  correctness hunt instead of another structural split.
  Current read:
  - this reopened lane is no longer a live bug queue
  - the landed slices should be kept as present-path hardening, not ongoing
    default momentum
  - rerank War 2 from the top again instead of continuing stale bug pursuit
- `docs/review/TERMINAL_WAR_2_POST_OMISSION_RERANK_2026-04-02.md`
  Why: the reopened omission bug hunt turned out to be stale, so War 2 needs a
  fresh top-level ranking again.
  Current read:
  - omission hardening stays landed
  - the omission bug itself no longer deserves to drive the queue
  - the next move should come from a fresh comparison of the live stack

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
  - the protocol-side input-mode mutation slab is thinner too:
    parser keypad mode, CSI key-mode control, DECSTR input-mode reset, and
    private mode mutation now call `src/terminal/core/input_modes.zig` and
    `src/terminal/core/session/config.zig` directly, so
    `src/terminal/core/terminal_runtime.zig` no longer advertises key-mode,
    mouse-mode, bracketed-paste, keypad/app-cursor, or column-mode mutation as
    part of the stable host runtime contract
  - the same is now true for the palette/config mutation slab:
    OSC palette and dynamic-color handlers now call
    `src/terminal/core/session/config.zig` directly, so the stable runtime
    surface no longer advertises palette reset/mutation, dynamic-color
    mutation, or dead ANSI color setters that are not part of the real host
    contract
  - the CSI reply dispatch slab is flatter too:
    `src/terminal/protocol/csi.zig` no longer routes DSR and window-op replies
    through `handleDsrQuery(...)` / `handleWindowOpQuery(...)` in
    `src/terminal/protocol/csi_reply.zig`; CSI now calls the writer-owned reply
    functions directly instead of keeping another forwarding layer alive
  - the same is now true for DECRQM reply dispatch:
    `src/terminal/protocol/csi.zig` no longer routes DECRQM replies through
    `handleDecrqmQuery(...)` in `src/terminal/protocol/csi_mode_query.zig`;
    CSI now computes the mode state and calls the writer-owned DECRQM reply
    function directly
  - the DECRQM snapshot path is thinner too:
    `src/terminal/protocol/csi_mode_query.zig` now reads mouse-mode snapshot
    bits directly from `interaction.input_snapshot`, so the stable runtime
    surface no longer carries one-consumer mouse-mode query helpers or the dead
    `getDamage` export
  - the same is now true for single-caller app/FFI convenience exports:
    `displayTitleText`, `setConfiguredCursorStyle`, `setLaunchShellPath`, and
    `launchShellPath` now route through their direct owners in
    `session/host_queries.zig`, `session/config.zig`, and `session/runtime.zig`
    instead of inflating the stable runtime surface with app-only convenience
    methods
  - the stable runtime surface also no longer carries low-level input-encoder
    plumbing:
    `sendKeyActionWithMetadata`, `sendKeypadAction`, `sendCharAction`, and
    `sendCharActionWithMetadata` now route through
    `src/terminal/core/session/input.zig` directly from the key encoder and
    widget keyboard path instead of pretending to be host-level runtime
    contract
  - widget and FFI copy/query helpers are shrinking the same way too:
    OSC clipboard copy and hyperlink URI copy now route through
    `src/terminal/core/session/queries.zig` directly from widget and FFI
    callers instead of sitting on the stable runtime surface as thin
    convenience exports
  - config-owned screen/palette mutation is off the runtime surface too:
    `setDefaultColors`, `applyThemePalette`, and `setCellSize` now route
    through `src/terminal/core/session/config.zig` from app, workspace, FFI,
    and test callers instead of pretending to be stable host-level runtime
    contract
  - interaction-owned input state and kitty-paste mechanics are off the
    runtime surface too:
    auto-repeat/focus/bracketed-paste/mouse-reporting/key-mode queries plus
    OSC 5522 paste sending now route through
    `src/terminal/core/session/interaction.zig` from widget, protocol, FFI,
    workspace, and test callers instead of pretending to be stable runtime
    contract
  - host-query metadata/state reads are off the runtime surface too:
    title/cwd/alt-screen/alive/activity/metadata copy now route through
    `src/terminal/core/session/host_queries.zig` from widget, app, workspace,
    FFI, and test callers instead of pretending to be stable runtime contract
  - transport/poll lifecycle is off the runtime surface too:
    start/startNoThreads, PTY or external transport attach/drain/close,
    poll/hasData/backlog/input-pressure, and child-exit refresh/report now
    route through `src/terminal/core/session/runtime.zig` from app,
    workspace, replay, FFI, and tests instead of pretending to be stable
    host-level runtime contract
  - input/reporting mechanics are off the runtime surface too:
    sendText/sendBytes/sendKey/sendChar, mouse/focus/color-scheme reporting,
    alternate-scroll reporting, and app-cursor/app-keypad queries now route
    through `src/terminal/core/session/input.zig` from widget, app, protocol,
    FFI, replay, and tests instead of pretending to be stable runtime
    contract
  - protocol-only mode effects are off the runtime surface too:
    alt-screen enter/exit now route through
    `src/terminal/core/session/mode_effects.zig` from CSI mode mutation and
    regression callers instead of pretending to be stable host/runtime
    contract
  - resize is off the runtime surface too:
    terminal resize/reflow now routes through
    `src/terminal/core/session/runtime.zig` from app, workspace, and
    regression callers instead of pretending to be a separate stable host
    contract layer
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
      remaining host-wrapper gravity around `PtyTerminalRuntime`
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
  - the remaining host-wrapper gravity around `PtyTerminalRuntime`, now that
    the dead `pty_terminal_runtime.zig` alias file is gone and
    `terminal_runtime.zig` directly owns the runtime type
  - parser-hook semantics above the engine
  - duplicated publication truth
  - oversized native widget/render coordination
- Another small but honest surface kill is in too: `terminal_runtime.zig`
  dropped dead wrapper exports that had no in-tree callers
  (`copyActivityMetadata`, `sendKittyPasteEvent5522WithHtml`,
  `sendKittyPasteEvent5522WithMime`, `setDefaultColorsLocked`), so the stable
  runtime surface is not carrying fake contract weight for unused entrypoints.
- Another `VTCORE-05` ownership cut is in too: `view_cache.zig` no longer
  reaches through publication for raw active/inactive cache slots and index
  publication. `terminal_publication.zig` now owns that slot choreography via
  `beginCachePublication(...)` / `finishCachePublication(...)`, so view-cache
  publication depends on a contract-shaped owner seam instead of storage-layout
  helpers.
- Another publication-owner cleanup is in too: runtime/thread code no longer
  directly clears output-pending or consumes alt-exit flags through raw
  storage-flavored helpers. That now goes through intent-shaped publication
  entrypoints like `clearPublishedOutputPending(...)` and
  `noteProcessedOutput(...)`.
- Another publication-surface cleanup is in too: the dead
  `copyPublishedRenderCache(...)` export is gone, and debug scroll-offset
  staging no longer hand-composes `clearPendingViewRefresh(...)` plus
  `publishCurrentViewLocked(...)`. That intent now lives under the owner as
  `replacePendingRefreshWithCurrentViewLocked(...)`.
- Another publication contract cut is in too: callers no longer compose
  `takePendingViewRefresh()` plus `pendingGeneration()` themselves.
  `terminal_publication.zig` now exposes a single
  `takePendingViewRefreshRequest(...)` contract so view-cache refresh and parse
  publish paths consume one owner-shaped request instead of reassembling it.
- Another publication-owner summary cut is in too: widget/workspace callers no
  longer assemble pending/published/presented generation triplets from three
  separate publication queries. `terminal_publication.generationState(...)`
  now owns that status snapshot as one contract.
- Another `VTCORE-04` mini-adapter kill is in too: `csi_reply.zig` no longer
  carries `QueryState`, `CursorReport`, and `ScreenState` ferry structs just to
  move a few reply fields across one call boundary. CSI reply handlers now take
  raw owner-shaped arguments directly.
- Another small protocol bounce is gone too: `osc_kitty_clipboard.zig` no
  longer keeps a duplicate `writeReadStatus(...)` wrapper over
  `writeReadStatusWithId(...)`.
- Another small CSI bounce is gone too: `csi_reply.handleDaQuery(...)` is dead,
  and the DA path now calls `writeDaPrimaryReplyWithWriter(...)` directly.
- The terminal campaign should now judge success by first-glance authority:
  when a strong maintainer opens the code, the engine must obviously be the
  engine.
  - publication mutation composition is tighter too:
    test/debug callers no longer hand-compose `bumpGeneration(...)` plus
    `publishCurrentViewLocked(...)` for the common "new generation from current
    view" action; that contract now lives under
    `src/terminal/core/publication/terminal_publication.zig` as
    `bumpAndPublishCurrentViewLocked(...)`
  - widget-side publication capture choreography is tighter too:
    `src/ui/widgets/terminal_widget.zig` no longer hand-composes
    `capturePresentation(...)` plus `publishedGeneration(...)` plus conditional
    recapture for the common "prepare latest presentable capture" action; that
    owner contract now lives under
    `src/terminal/core/publication/terminal_publication.zig` as
    `prepareLatestPresentation(...)`
  - active workspace frame pacing now consumes owner-shaped frame state
    instead of recomputing redraw/backlog/output-pressure from raw
    generation numbers in app runtime
  - native draw/runtime presentation feedback staging is tighter too:
    app state no longer carries terminal-specific pending presentation feedback
    or submission-sequence residue; the active `TerminalWidget` now owns
    pending presentation feedback and
    `src/app/terminal/terminal_draw_surface_runtime.zig` completes it through
    the widget instead of staging terminal publication handoff in generic app
    state
  - scrollback refresh generation policy is tighter too:
    `src/terminal/core/scrollback_view.zig` no longer decides inline whether a
    scrollback offset change should bump generation or only queue refresh; that
    choice now lives under
    `src/terminal/core/publication/terminal_publication.zig` as
    `requestViewRefreshIfOffsetChangedLocked(...)`
  - parse-thread publication choreography is tighter too:
    `src/terminal/core/runtime/io_threads.zig` no longer reconstructs
    "publish current pending generation" or "publish queued refresh request"
    from lower-level publication verbs; those owner actions now live under
    `src/terminal/core/publication/terminal_publication.zig` as
    `publishPendingGenerationLocked(...)` and
    `publishViewRefreshRequestLocked(...)`
  - parse/debug publication intent is tighter too:
    parse loops and debug scroll-offset staging no longer open-code
    "parsed output bumps generation", "pending output publish also marks
    output pending", or "offset change may need a generation bump before
    current-view publish"; those owner actions now live under
    `src/terminal/core/publication/terminal_publication.zig` as
    `noteParsedOutputLocked(...)`,
    `publishPendingOutputLocked(...)`, and
    `publishCurrentViewForScrollOffsetChangeLocked(...)`
  - config publication intent is tighter too:
    `src/terminal/core/session/config.zig` no longer republish theme palette
    changes by routing through multiple publishing setters; config mutation can
    now stage palette/default-color updates without intermediate publication
    churn and publish once for the whole logical change
  - scroll-view refresh policy is tighter too:
    `scrollback_view.zig` and `resize_reflow.zig` no longer coordinate
    scroll-offset refresh choreography themselves; publication now owns those
    owner actions via `refreshScrollViewForOffsetChangeLocked(...)` and
    `refreshScrollViewLocked(...)`
  - another small OSC trampoline is gone too:
    `osc_semantic.zig` no longer routes `parseSemanticPrompt(...)` and
    `parseUserVar(...)` through duplicate same-object `*Direct` helpers
  - poll-side publication choreography is tighter too:
    `src/terminal/core/runtime/pty_poll_publication.zig` no longer manually
    sequences "publish current view if data arrived, then apply pending
    refresh if any"; that owner action now lives under
    `src/terminal/core/publication/terminal_publication.zig` as
    `publishPollUpdateLocked(...)`

## Current Review Scope

- `docs/review/VT_CORE_MODE_STATE_OWNER_FRONT_2026-04-04.md`
  Why: after the cursor/tab owner cut, the next honest `TerminalCore`
  sufficiency contradiction was that terminal mode mutation/query truth still
  lived in helper owners beside core.
  Current read:
  - terminal mode mutation and DECRQM terminal-mode snapshot truth now live on
    `TerminalCore`
  - helper-owned CSI terminal mode state is gone
  - honest outer alt-screen effects remain outside this slice

- `docs/review/VT_CORE_CURSOR_TAB_OWNER_FRONT_2026-04-04.md`
  Why: after the kitty-storage owner cut, the next honest `TerminalCore`
  sufficiency contradiction was that basic cursor/tab/margin semantics still
  terminated on raw screen calls in protocol handlers.
  Current read:
  - cursor, tab, carriage-return, margin, and cursor-style semantics now live
    on direct core-owned verbs
  - control/CSI/ESC handlers now route that slab through `TerminalCore`
  - lower-level `Screen` navigation remains mechanism, not the semantic center

- `docs/review/VT_CORE_KITTY_STORAGE_OWNER_FRONT_2026-04-04.md`
  Why: after the feed host-face stop-marker, the next honest owner-shaped
  contradiction was kitty storage cleanup still depending on outer-shaped
  helpers.
  Current read:
  - kitty storage clear/deinit now lives on direct core-owned cleanup under
    `src/terminal/core/terminal_core_kitty_storage.zig`
  - `TerminalCore.deinit(...)` is no longer owner-shaped
  - alt-screen and reset-side kitty cleanup now read more like direct core
    state cleanup than outer completion
  - protocol/reply/runtime kitty behavior stays outside this slice

- `docs/review/VT_WAR_4_SCOPE_2026-04-03.md`
  Why: the next scrutiny war needs a bounded scope before more code work.
  Current read:
  - the old false-center wars are largely closed
  - the next live question is whether one specific `TerminalCore`
    capability/contract gap still blocks a credible plug-and-play `zide-vt`
    story beside Ghostty and WezTerm
  - the war should be run in bounded cross-reference tracks:
    engine sufficiency, shell legitimacy, public/FFI contract shape, and
    caller dependence discipline

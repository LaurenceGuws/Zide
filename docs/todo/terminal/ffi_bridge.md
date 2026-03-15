# Terminal FFI Bridge TODO

## Scope

Define an embeddable terminal backend surface with stable FFI-oriented contracts, without exporting renderer or UI internals.

## Constraints

- Desktop-first only: Linux, macOS, Windows.
- Keep VT parsing, protocol handling, screen model, and PTY lifecycle in the Zig backend.
- Export explicit ownership and paired free functions for owned buffers.
- Keep the first bridge synchronous and narrow.
- Do not treat the ABI as frozen before smoke-host coverage exists.
- Use `app_architecture/terminal/ffi/BRIDGE_DESIGN.md` together with
  `app_architecture/terminal/TERMINAL_SUBSYSTEM_LAYERS.md` when judging
  whether a bridge change belongs to the shared host contract or to a
  native-only/runtime-only layer.

## Status

The baseline bridge is real and product-shaped:

- design docs exist
- event ABI exists
- snapshot ABI exists
- non-PTY smoke coverage exists
- Python `ctypes` smoke exists
- a dedicated PTY-backed verifier exists

The remaining work is on boundary cleanup and ABI maturity, not on widening the
scope into renderer export.

Current judgment:

- The highest-value native/FFI host-contract asymmetries have materially narrowed.
- Recent cuts closed the strongest remaining gaps in:
  - close-confirm state
  - backend-owned viewport control
  - clipboard payload access
  - host focus reporting
  - host color-scheme reporting
- Do not widen the bridge opportunistically from here.
- The strongest remaining bridge work is now:
  - snapshot/diff ABI maturation
  - PTY-backed verifier hardening
  - only then any advanced event-family expansion that survives the same
    "shared engine contract" bar
- External peer review from the downstream Flutter host is now also positive:
  the same widget/runtime layer survived swapping bridge-owned PTY vs
  Flutter-owned PTY transport, and the old transport-side focus/color-scheme
  reporting asymmetry is now closed through the pending-input bridge path.
- Follow-up now landed on `main`:
  - external transport can drain pending outbound host-input/report bytes
    through the bridge
  - encoded input and host reports no longer need to be PTY-writer-only
    semantics
- Follow-up now also landed for lifecycle truth:
  - external transport can report child exit status back into the shared
    bridge contract
  - `metadata`, `child_exit_status(...)`, and queued `child_exit` events no
    longer require a bridge-owned PTY to stay authoritative
- Hot-path guidance should now be treated as part of the contract:
  - `redraw_state(...)` gates snapshot work
  - `pending_input_acquire(...)` is the outbound batching seam for external
    transport
  - `metadata_acquire(...)` is latest-state, not a per-frame polling habit
- Current bridge audit result:
  - no equally obvious missing host-facing semantic remains after the recent
    viewport, pending-input, focus/color, child-exit, and request-based
    metadata cuts
  - the stronger next lane is ABI/perf maturity, not casual surface growth
- The current performance checkpoint for that lane now lives in:
  - `docs/research/terminal/TERMINAL_FFI_PERFORMANCE_REVIEW_2026-03-15.md`
  - `app_architecture/terminal/ffi/SNAPSHOT_ABI.md`
- One narrow maturity cut already landed there:
  - `snapshot_acquire(...)` no longer performs an extra temporary published
    render-cache copy before building the exported FFI cell buffer
  - `snapshot_acquire(...)` also no longer routes optional title/cwd export
    through `copyMetadata(...)`; snapshot export now gathers published cells
    and requested strings in one locked pass
  - the remaining dominant snapshot cost is now the single explicit copied
    flat cell buffer itself

## TODO

### FFI-00 Contract And Scope Lock

- [x] `FFI-00-01` Write the bridge design doc and choose the primary exported shape.
- [x] `FFI-00-02` Define bridge success criteria and non-goals.

### FFI-01 Session Core Boundary

- [ ] `FFI-01-01` Separate UI-only concerns from the `TerminalSession` contract.
- [-] `FFI-01-02` Introduce the host-facing event/action inventory.
  Notes: milestone-1 queue ABI is locked for title/cwd/clipboard_write/child_exit; redraw, liveness, close-confirm, and clipboard payload semantics now live partly in direct bridge getters rather than only in the event stream.

### FFI-02 Snapshot And Diff ABI

- [-] `FFI-02-01` Design an FFI-safe terminal snapshot layout.
  Notes: baseline full-snapshot ABI is documented and implemented; copied scrollback and text exports exist; remaining work is around further ABI maturation, not first delivery. This is now also the main medium-term performance pressure point on the FFI boundary, because full snapshot acquire still allocates and copies the flat cell buffer on every acquire. The first hot/cold maturity steps have now landed on both latest-state and snapshot ownership surfaces: `metadata_acquire(...)` is request-based, hot scalar fields are always filled, and title/cwd are opt-in through inclusion flags; `snapshot_acquire(...)` is now also request-based, with cells always copied but title/cwd opt-in through inclusion flags. Those replacements were done as clean beta cuts instead of preserving the original no-request forms. The remaining work is now to judge whether snapshot transport itself should evolve, not to reopen getter sprawl.
- [x] `FFI-02-02` Specify ownership rules for exported snapshot buffers.
- [ ] `FFI-02-03` Define the optional damage/diff extension after baseline full snapshot works.
- [-] `FFI-02-04` Define the published-vs-acknowledged generation contract for foreign hosts.
  Notes: `present_ack`, acknowledged/published generation getters, redraw state getters, and shared contract docs are in place; the remaining work is deciding what else belongs in direct getters versus queued events.
- [x] `FFI-02-05` Expose host-controlled viewport scrolling over the bridge.
  Notes: `set_scrollback_offset(...)` and `follow_live_bottom(...)` now let foreign hosts drive the backend-owned visible viewport directly; metadata and snapshots reflect the authoritative offset, and redraw/publication semantics stay unchanged.

### FFI-03 PTY And Host IO Seam

- [x] `FFI-03-01` Define the host-driven PTY/session abstraction.
- [-] `FFI-03-02` Audit platform split and exported bridge expectations.

### FFI-04 Export Surface And Smoke Host

- [-] `FFI-04-01` Create the minimal exported bridge surface with opaque handles.
  Notes: close-confirm state, clipboard-write payload, and pending outbound input/report bytes now have explicit getters/ABI surfaces alongside metadata and redraw-state, so foreign hosts no longer need native-only close-warning, event-only clipboard, or PTY-only host-input notification paths.
- [x] `FFI-04-02` Add a standalone Python ctypes smoke host.
- [x] `FFI-04-03` Add a non-interactive bridge smoke test.
- [-] `FFI-04-04` Stabilize PTY-backed foreign-host start as a separate smoke slice.
  Notes: keep the no-PTY smoke authoritative for ownership/lifetime; PTY-backed startup remains a narrower stabilization track rather than an absent one. Current PTY smoke validates bridge-owned shell startup, `send_text(...)` + `send_key(Enter)` input delivery, one backend-owned viewport pin/follow-live cycle with visible snapshot content actually changing and then restoring, redraw/present, metadata, child-exit, close-confirm getter shape, and host focus/color-scheme reporting on the bridge-owned shell path.

### FFI-05 Host Adapters And Future Productization

- [x] `FFI-05-01` Document Flutter adapter design constraints.
- [x] `FFI-05-02` Evaluate daemon or multiplexer mode as a follow-on, not a prerequisite.

## Current Gaps

- Advanced event families are still deferred.
- PTY-backed foreign-host coverage is narrower than the baseline no-PTY authority path, but it is now a real maintained verifier rather than a missing smoke lane.
- The next useful check is no longer "can a second host use the bridge at
  all?" It is "does the same host contract stay easy and stable when PTY
  ownership changes?"
- Current downstream answer: yes, for redraw/snapshot/present, viewport
  control, command input, and focus/color-scheme reporting.
- Child-exit-status truth is now part of the shared external-host contract too;
  the remaining PTY ownership differences are transport-lifecycle mechanics,
  not terminal redraw/input/viewport or lifecycle-state asymmetry.
- Latest downstream answer: the child-exit re-check against upstream `f9bb94a`
  was clean and the Flutter-owned PTY path kept the same shared widget/runtime
  layer with only transport-local changes.
- Latest downstream metadata answer: the request-based metadata acquire cut was
  also clean in Flutty:
  - binding update was straightforward
  - `include_flags = 0` felt natural for hot scalar reads
  - shared runtime/controller layer stayed the same
  - title/cwd cleanup moved to explicit cached state instead of assuming every
    metadata read carried strings
  - no redraw/viewport/lifecycle regressions were observed
- Latest downstream snapshot answer: the request-based snapshot acquire cut was
  also clean in Flutty after the upstream viewport fix in `4c2a953e`:
  - binding update was straightforward
  - render-path usage naturally stayed on `include_flags = 0`
  - viewport pinning now changes visible snapshot content on current `main`
  - no runtime/controller/widget fork was needed
  - no local workaround logic was required
- Current outcome:
  - no equally obvious missing host-facing semantic remains
  - the stronger next lane is still ABI/perf maturity, especially snapshot
    cell-buffer cost
- The next upstream performance lane should stay narrow:
  - keep `pending_input` as the coarse outbound batch seam
  - keep hosts disciplined around redraw-driven snapshot usage
  - compare diff-oriented export against pinned-handle full-snapshot reuse as
    the next major boundary-cost question, not as an excuse to widen the
    surface casually
- Current paper preference:
  - pinned-handle full-snapshot reuse first
  - diff export second unless a diff design can preserve one acquire, one
    owned result, and one obvious visible-state authority
- Current design rule for the next snapshot lane:
  - pinned-handle reuse only stays preferred if it keeps the same redraw-driven
    host loop shape and does not leak publication-retention complexity into the
    public contract
- Current implementation caution:
  - the existing publication path is still centered on one active render-cache
    slot plus copy-based handoff, so pinned reuse must prove it only needs a
    small bounded retained-generation extension rather than a heavier
    publication store
- Current narrowest plausible follow-on:
  - keep the current double-buffered publication flip path
  - allow at most one extra retained published generation while pinned
  - re-evaluate the preference immediately if real implementation pressure asks
    for more than that
- Current cost caution:
  - because exported FFI cells are not the same layout as internal published
    cache cells, pinned reuse may still require one full visible-cell remap per
    published generation
  - if so, pinned handles only stay attractive when they still beat the current
    baseline on real host behavior, not just on paper
- Current execution rule for that lane:
  - do not widen the bridge first
  - keep the snapshot review focused on host call count, flat cell-buffer
    allocation pressure,
    and latest-state authority
- The bridge remains beta-level and should not be treated as frozen.

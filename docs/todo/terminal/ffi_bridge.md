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

The baseline bridge is real and product-shaped: design docs, event ABI, snapshot ABI, non-PTY smoke coverage, Python ctypes smoke, and a dedicated PTY-backed verifier all exist. The remaining work is on boundary cleanup and maturing the ABI without broadening scope into renderer export.

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
- Follow-up now landed on `main`: external transport can drain pending outbound
  host-input/report bytes through the bridge, so encoded input and host reports
  no longer need to be PTY-writer-only semantics.
- Follow-up now also landed for lifecycle truth: external transport can report
  child exit status back into the shared bridge contract, so `metadata`,
  `child_exit_status(...)`, and queued `child_exit` events no longer require a
  bridge-owned PTY to stay authoritative.
- Hot-path guidance should now be treated as part of the contract:
  - `redraw_state(...)` gates snapshot work
  - `pending_input_acquire(...)` is the outbound batching seam for external
    transport
  - `metadata_acquire(...)` is latest-state, not a per-frame polling habit

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
  Notes: baseline full-snapshot ABI is documented and implemented; copied scrollback and text exports exist; remaining work is around further ABI maturation, not first delivery. This is now also the main medium-term performance pressure point on the FFI boundary, because full snapshot acquire still allocates and copies the flat cell buffer on every acquire.
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
  Notes: keep the no-PTY smoke authoritative for ownership/lifetime; PTY-backed startup remains a narrower stabilization track rather than an absent one. Current PTY smoke validates bridge-owned shell startup, `send_text(...)` + `send_key(Enter)` input delivery, one backend-owned viewport pin/follow-live cycle, redraw/present, metadata, child-exit, close-confirm getter shape, and host focus/color-scheme reporting on the bridge-owned shell path.

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
- The next upstream performance lane should stay narrow:
  - keep `pending_input` as the coarse outbound batch seam
  - keep hosts disciplined around redraw-driven snapshot usage
  - review snapshot/diff evolution as the next major boundary-cost question,
    not as an excuse to widen the surface casually
- The bridge remains beta-level and should not be treated as frozen.

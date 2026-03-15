# Terminal FFI Bridge TODO

## Scope

Define an embeddable terminal backend surface with stable FFI-oriented contracts, without exporting renderer or UI internals.

## Constraints

- Desktop-first only: Linux, macOS, Windows.
- Keep VT parsing, protocol handling, screen model, and PTY lifecycle in the Zig backend.
- Export explicit ownership and paired free functions for owned buffers.
- Keep the first bridge synchronous and narrow.
- Do not treat the ABI as frozen before smoke-host coverage exists.

## Status

The baseline bridge is real and product-shaped: design docs, event ABI, snapshot ABI, non-PTY smoke coverage, and Python ctypes smoke all exist. The remaining work is on boundary cleanup, PTY-backed host stabilization, and maturing the ABI without broadening scope into renderer export.

## TODO

### FFI-00 Contract And Scope Lock

- [x] `FFI-00-01` Write the bridge design doc and choose the primary exported shape.
- [x] `FFI-00-02` Define bridge success criteria and non-goals.

### FFI-01 Session Core Boundary

- [ ] `FFI-01-01` Separate UI-only concerns from the `TerminalSession` contract.
- [-] `FFI-01-02` Introduce the host-facing event/action inventory.
  Notes: milestone-1 queue ABI is locked for title/cwd/clipboard_write/child_exit; redraw, liveness, and close-confirm semantics now live partly in direct bridge getters rather than only in the event stream.

### FFI-02 Snapshot And Diff ABI

- [-] `FFI-02-01` Design an FFI-safe terminal snapshot layout.
  Notes: baseline full-snapshot ABI is documented and implemented; copied scrollback and text exports exist; remaining work is around further ABI maturation, not first delivery.
- [x] `FFI-02-02` Specify ownership rules for exported snapshot buffers.
- [ ] `FFI-02-03` Define the optional damage/diff extension after baseline full snapshot works.
- [-] `FFI-02-04` Define the published-vs-acknowledged generation contract for foreign hosts.
  Notes: `present_ack`, acknowledged/published generation getters, redraw state getters, and shared contract docs are in place; the remaining work is deciding what else belongs in direct getters versus queued events.

### FFI-03 PTY And Host IO Seam

- [x] `FFI-03-01` Define the host-driven PTY/session abstraction.
- [-] `FFI-03-02` Audit platform split and exported bridge expectations.

### FFI-04 Export Surface And Smoke Host

- [-] `FFI-04-01` Create the minimal exported bridge surface with opaque handles.
  Notes: close-confirm state now has an explicit getter/ABI-typed struct alongside metadata and redraw-state, so foreign hosts no longer need a native-only close-warning contract.
- [x] `FFI-04-02` Add a standalone Python ctypes smoke host.
- [x] `FFI-04-03` Add a non-interactive bridge smoke test.
- [-] `FFI-04-04` Stabilize PTY-backed foreign-host start as a separate smoke slice.
  Notes: keep the no-PTY smoke authoritative for ownership/lifetime; PTY-backed startup remains a narrower stabilization track. Current PTY smoke now validates redraw/present, metadata, child-exit, and close-confirm getter shape on the bridge-owned shell path.

### FFI-05 Host Adapters And Future Productization

- [x] `FFI-05-01` Document Flutter adapter design constraints.
- [x] `FFI-05-02` Evaluate daemon or multiplexer mode as a follow-on, not a prerequisite.

## Current Gaps

- Advanced event families are still deferred.
- PTY-backed foreign-host smoke still trails the baseline no-PTY path.
- The bridge remains beta-level and should not be treated as frozen.

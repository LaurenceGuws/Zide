# Terminal FFI Performance Review

Date: 2026-03-15

Status: current checkpoint after the VT/FFI growth phase stabilized across the
native reference host and the downstream Flutter host.

Purpose: record the current hot-path performance judgment for the terminal FFI
contract before more surface hardens.

## Scope

This review is about the host boundary itself:

- call shape
- allocation/copy cost
- redraw/publication/present pacing
- external transport batching
- latest-state authority surfaces

It is not a review of renderer performance or widget-level efficiency.

## Current Contract Judgment

Direction is still sound.

The current bridge is good enough to keep building on, but the remaining
boundary-cost risk is concentrated:

1. `snapshot_acquire(...)` is still the dominant medium-term cost surface.
2. `metadata_acquire(...)` is cheap semantically but still allocates and copies
   cold strings every time.
3. redraw/publication/present is still the right host loop, but only if hosts
   treat `redraw_state(...)` as the gate and avoid speculative snapshot pulls.
4. `pending_input_acquire(...)` is now the correct outbound batching seam for
   external transport and its avoidable extra copy has already been removed.

## Hot-Path Findings

### 1. Snapshot Acquire Is The Main Remaining Boundary Cost

Current shape in [core_api.zig](/home/home/personal/zide/src/terminal/ffi/core_api.zig):

- allocates a `SnapshotOwner`
- allocates a copied flat cell array
- duplicates title
- duplicates cwd

This is acceptable for the current milestone because it is explicit and easy to
bind, but it remains the biggest cost center on the host boundary.

Implication:

- do not widen snapshot use
- do not add “helpful” per-row/per-cell snapshot-side queries
- any future snapshot/diff work should be judged first by host call count and
  allocation pressure, not by ABI cleverness alone

### 2. Metadata Acquire Must Stay Latest-State, Not Per-Frame Habit

`metadata_acquire(...)` is structurally correct as the authoritative latest-state
summary, but it still duplicates title/cwd on every acquire.

That is acceptable if hosts use it as intended:

- lifecycle/title/cwd/scrollback summary when needed
- not a per-frame scalar polling habit

Implication:

- current docs should keep steering hosts away from high-frequency metadata
  polling
- any future split between hot scalars and cold strings should be treated as an
  ABI-maturity step, not an excuse to widen the public surface casually
- the target should be "cheaper hot latest-state without stitched truth", not
  "many small convenience getters"

### 3. Redraw/Present Contract Is Still The Right Host Loop

The current narrow host loop is still the correct one:

1. `poll(...)`
2. `redraw_state(...)`
3. `snapshot_acquire(...)` only when redraw is pending
4. render
5. `present_ack(...)`

This remains the narrowest credible host boundary for a serious embedded host.

What would make it bad is not the model itself, but hosts layering extra calls
around it “just in case.”

Implication:

- `redraw_state(...)` stays the hot-path authority
- `needs_redraw(...)`, published-generation getters, and similar helpers should
  remain secondary/convenience surfaces, not the main loop contract

### 4. Pending Input Is Now The Right External-Transport Seam

External transport now has the correct shape:

- host-owned transport feeds backend output through `feed_output(...)`
- host-owned transport closes input through `close_input(...)`
- backend-owned outbound input/report traffic drains through:
  - `pending_input_acquire(...)`
  - `pending_input_release(...)`

The earlier extra copy inside `pending_input_acquire(...)` is now removed.

Implication:

- keep `pending_input` coarse and destructive
- do not let this drift into callback-style micro-notifications or per-key
  drain expectations

### 5. Event/Getter Overlap Must Stay Disciplined

The current contract is workable because latest-state truth is explicit:

- `metadata_acquire(...)`
- `redraw_state(...)`
- `close_confirm_signals(...)`
- `child_exit_status(...)`
- `clipboard_write(...)`

Events should remain wake/edge signals, not the primary state database.

Implication:

- do not add overlapping convenience APIs unless they clearly avoid host churn
- do not let downstream hosts reconstruct terminal truth by polling many narrow
  helpers every tick

## Rules For Future FFI Changes

1. Never require per-cell or per-row host calls on the visible hot path.
2. New hot-path exports must justify allocation behavior explicitly.
3. `redraw_state(...)` remains the gate for snapshot work.
4. `metadata_acquire(...)` remains latest-state, not a per-frame habit.
5. `pending_input(...)` remains the coarse outbound batching seam for external
   transport.
6. Events should wake hosts, not replace authoritative latest-state getters.
7. Snapshot/diff evolution should optimize host call count and allocation
   pressure first.
8. Do not widen the bridge just because native can reach an internal value more
   directly.
9. Prefer one authoritative getter over several overlapping convenience
   getters.
10. Any future ABI split between hot scalars and cold strings must improve
    boundary efficiency without forcing hosts into stitched truth.

## Immediate Next Step

The next bridge-performance lane should stay narrow:

- review snapshot transport shape
- define the hot-scalar vs cold-string maturity direction more explicitly
- keep the public loop discipline explicit
- avoid widening the bridge until snapshot/diff direction is better defined

This means:

- no rushed diff ABI yet
- no callback expansion
- no convenience surfaces that make hosts chattier

## Current Conclusion

The current redesign is performance-safe enough to continue building on.

The main remaining boundary-cost pressure point is:

- `snapshot_acquire(...)`

Everything else should be judged around that fact instead of broadening the
bridge in unrelated directions.

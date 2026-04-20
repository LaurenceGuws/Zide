# CZH-1031 Transport Helper/Route-Lock Simplification Audit Map

**Ticket:** `CZH-1031`  
**Sprint:** `CZH-S49`  
**Batch:** `CZH-B54`  
**Gate:** `CZH-GATE-108`  
**Date:** 2026-04-20  
**Scope:** behavior-neutral audit + cut map only (no runtime behavior/ABI change)

## Purpose

Audit remaining transport helper duplication and route-lock checks after `CZH-B53` canonical fold-entry collapse,
then define execution cuts for `CZH-1032`..`CZH-1040`.

## Hard constraints

- Behavior freeze.
- No host ABI/C export changes.
- No compatibility/fallback branches.
- No stale probe/debug residue.
- Source comments remain present-tense architecture only.

## Audited transport helper duplication

### Current state

- Refresh/reuse/direct fold functions converge on `presentResultFromOutcomeState` (generic fold helper).
- Intermediate `foldRefreshEntry`, `foldReuseEntry`, `foldDirectEntry` exist as single-caller wrappers.
- Each wrapper simply extracts outcome transport and calls `presentResultFromOutcomeState`.

**Duplication pattern:**

```zig
fn foldRefreshEntry(outcome_state: RefreshOutcomeState, timing) -> TerminalPresentResult {
    return presentResultFromOutcomeState(outcome_state.transport, timing);
}

fn foldReuseEntry(outcome_state: ReusePresentOutcomeState, timing) -> TerminalPresentResult {
    return presentResultFromOutcomeState(outcome_state.transport, timing);
}

fn foldDirectEntry(outcome_state: DirectPresentOutcomeState, timing) -> TerminalPresentResult {
    return presentResultFromOutcomeState(outcome_state.transport, timing);
}
```

**Collapse target:** collapse these wrappers by having `foldXOutcomeToPresent` call `presentResultFromOutcomeState` directly with outcome transport fields, eliminating intermediate entry functions.

## Audited route-lock checks

### Current state

- `RefreshOutcomeState`, `ReusePresentOutcomeState`, `DirectPresentOutcomeState` each carry both:
  - `transport: FoldTransportFields` (carrier struct)
  - Top-level mirror fields: `outcome`, `cache_state_advanced`, `host_surface_target_available`, `shared_surface_attachment_ready`
- Consistency assertions (`assertRefreshOutcomeConsistency`, etc.) verify these fields match.

**Route-lock pattern:**

All outcome structs maintain field-value mirror invariants:
```
transport.outcome == outcome
transport.cache_state_advanced == cache_state_advanced
transport.host_surface_target_available == host_surface_target_available
transport.shared_surface_attachment_ready == shared_surface_attachment_ready
```

**Simplification target:** simplify route-lock checks by making outcome states always read canonical transport values directly, eliminating field duplication and strengthening single-path access patterns.

## Execution cut map (`CZH-1032`..`CZH-1040`)

1. `CZH-1032` — authority tightening for transport helper collapse + route-lock simplification.
2. `CZH-1033` — refresh transport-helper collapse cut.
3. `CZH-1034` — reuse transport-helper collapse cut.
4. `CZH-1035` — direct transport-helper collapse cut.
5. `CZH-1036` — refresh route-lock simplification cut.
6. `CZH-1037` — reuse/direct route-lock simplification cut.
7. `CZH-1038` — helper-level invariants for collapsed helpers + simplified locks.
8. `CZH-1039` — integration invariants + hygiene sweep.
9. `CZH-1040` — full validation ladder + checkpoint + gate handoff.

## Non-goals

- No renderer/backend architecture changes.
- No semantic outcome/followup changes.
- No FFI export/symbol changes.
- No behavioral changes to presentation runtime decision paths.

## Audit conclusion

`CZH-B53` collapsed fold-entry setup and locked boundary field routes. `CZH-B54` now collapses
remaining transport helper wrapper duplication and simplifies route-lock checks to one canonical
transport path per outcome type while preserving behavior and ABI.

# CZH-1041 Assertion/Mapping Simplification Audit Map

**Ticket:** `CZH-1041`  
**Sprint:** `CZH-S50`  
**Batch:** `CZH-B55`  
**Gate:** `CZH-GATE-109`  
**Date:** 2026-04-20  
**Scope:** behavior-neutral audit + cut map only (no runtime behavior/ABI change)

## Purpose

Audit fold-route assertions and transport field mappings after `CZH-B54` transport helper collapse,
then define execution cuts for `CZH-1042`..`CZH-1050`.

## Hard constraints

- Behavior freeze.
- No host ABI/C export changes.
- No compatibility/fallback branches.
- No stale probe/debug residue.
- Source comments remain present-tense architecture only.

## Audited fold-route assertions

### Current state

- Each outcome struct has route-lock assertion in corresponding `assertXOutcomeConsistency()` function.
- Assertions verify that top-level outcome fields match transport carrier fields.
- Outcome-specific assertions also check outcome-type invariants.

**Assertion patterns:**

```zig
pub fn assertRefreshOutcomeConsistency(state: RefreshOutcomeState) void {
    // Route-lock checks
    std.debug.assert(state.transport.outcome == state.outcome);
    std.debug.assert(state.transport.cache_state_advanced == state.cache_state_advanced);
    std.debug.assert(state.transport.host_surface_target_available == state.host_surface_target_available);
    std.debug.assert(state.transport.shared_surface_attachment_ready == state.shared_surface_attachment_ready);
    // Followup consistency
    if (state.followup.required) {
        std.debug.assert(state.followup.reason != .none);
    } else {
        std.debug.assert(state.followup.reason == .none);
    }
}
```

**Collapse target:** consolidate assertions to be simpler and more focused, removing redundancy where outcome fields can be derived directly from transport.

## Audited transport field mappings

### Current state

- Outcome structs carry both `transport: FoldTransportFields` and duplicate top-level fields.
- Fields are copied from transport at construction and verified by assertions.
- Access patterns require reading from top-level fields even though transport is canonical.

**Current mapping pattern:**

```zig
pub const RefreshOutcomeState = struct {
    transport: FoldTransportFields = .{},
    outcome: TerminalPresentOutcome = .presented,
    cache_state_advanced: bool = false,
    host_surface_target_available: bool = false,
    shared_surface_attachment_ready: bool = false,
    followup: presentable_contract.TerminalPresentFollowup = .{},
};
```

**Simplification target:** make outcome field access patterns simpler by reducing or eliminating duplicate fields where transport is the single source of truth.

## Execution cut map (`CZH-1042`..`CZH-1050`)

1. `CZH-1042` — authority tightening for assertion collapse + mapping simplification.
2. `CZH-1043` — refresh fold-route assertion collapse cut.
3. `CZH-1044` — reuse fold-route assertion collapse cut.
4. `CZH-1045` — direct fold-route assertion collapse cut.
5. `CZH-1046` — refresh transport mapping simplification cut.
6. `CZH-1047` — reuse/direct transport mapping simplification cut.
7. `CZH-1048` — helper-level invariants for collapsed assertions + simplified mappings.
8. `CZH-1049` — integration invariants + hygiene sweep.
9. `CZH-1050` — full validation ladder + checkpoint + gate handoff.

## Non-goals

- No renderer/backend architecture changes.
- No semantic outcome/followup changes.
- No FFI export/symbol changes.
- No behavioral changes to assertion timing or order.

## Audit conclusion

`CZH-B54` collapsed transport helpers and simplified route-locks. `CZH-B55` now collapses
remaining fold-route assertions and simplifies transport field mappings to one canonical
carrier per outcome type while preserving behavior and ABI.

# CZH-1082: Helper Surface Pruning + Boundary Glue Removal

Date: 2026-04-20  
Status: Completed as part of CZH-1079..1081 unification commits

## Redundant Helper Removal

### Removed
- `reusePresentEntry(outcome, timing)` — was redundant wrapper around `foldReuseOutcomeToPresent`
  - Only caller: `reuseEligibilityEntry` (inlined in CZH-1080)
  - Lines removed: ~5 lines of wrapper code

### Privatized (made internal-only)
- `foldRefreshOutcomeToPresent()` — internal fold helper (CZH-1079)
- `foldReuseOutcomeToPresent()` — internal fold helper (CZH-1080)
- `foldDirectOutcomeToPresent()` — internal fold helper (CZH-1081)

## Remaining Public API (All Essential)

### Canonical Entries (Widget-calling boundary)
- `refreshPresentEntry(refresh, attachment_ready, timing) -> TerminalPresentResult`
- `reuseEligibilityEntry(eligible, host_target, attachment_ready, timing) -> TerminalPresentResult`
- `directPresentEntry(updated, timing) -> TerminalPresentResult`

### Classification & Construction Helpers
- `classifyRefreshOutcome(refresh, attachment_ready) -> RefreshOutcomeState` — testing/analysis
- `classifyDirectPresentOutcome(updated) -> DirectPresentOutcomeState` — testing/analysis
- `reuseSuccessOutcome() -> ReusePresentOutcomeState` — called from reuseEligibilityEntry

### Eligibility Decision Helpers
- `checkReuseEligibility(plan, input) -> bool` — widget decision logic
- `checkDirectPresentEligibility(input) -> bool` — widget decision logic

### State & Geometry Computation
- `refreshPresentState(surface, renderer, refresh, visible_w, visible_h) -> PresentationPresentState`
- `computeHostSurfaceAttachmentState(renderer, surface) -> struct { host_surface_target_available, shared_surface_attachment_ready }`
- `computePresentationSurfaceGeometry(renderer, terminal_view, view_geometry) -> PresentationGeometry`
- `computeTerminalPresentPlanDecision(...) -> TerminalPresentPlanDecision`

### Orchestration & Hooks
- `executeRefreshPresentFlow(rows, cols, ctx, Hooks) -> TerminalPresentResult` — refresh sequence orchestration
- `presentDraw(renderer, sample_gen, surface_gen, ...) -> void` — present acknowledgement

### Invariant Helpers (Test coverage)
- `assertReuseOutcomeConsistency(state) -> void`
- `assertRefreshOutcomeConsistency(state) -> void`

### Type Definitions (Public structs for outcome/transport data)
- `RefreshOutcomeState` — refresh outcome snapshot
- `DirectPresentOutcomeState` — direct outcome snapshot
- `ReusePresentOutcomeState` — reuse outcome snapshot
- `FoldTransportFields` — shared transport payload

## Pruning Complete

All remaining public symbols are either:
1. Used by the widget layer directly (entries, eligibility checks, computation helpers)
2. Part of the outcome data structures needed for type safety
3. Required for test invariant coverage (assertions, classification helpers)

No aliases, duplicates, or secondary entry routes remain in public API.

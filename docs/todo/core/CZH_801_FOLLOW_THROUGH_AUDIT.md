# CZH-801: Follow-through audit + hygiene scope

Date: 2026-04-19  
Sprint: CZH-S26  
Batch: CZH-B31  
Gate target: CZH-GATE-85

## Executive Summary

Post-CZH-B30 audit for remaining duplicated present/report derivation callsites. CZH-B30 successfully contracted conjunction derivation to canonical helpers. CZH-S26 focuses on present/report flow coverage — verifying no parallel present-state or result derivation paths exist, and surface-state read bridges are fully canonical.

## Current Contraction State (Post-CZH-B30)

**Conjunction derivation:** ✓ Fully contracted  
- All conjunction reads go through `surface_attachment_contract.hostSharedSurfaceAttachmentReady()` or its pair-wrapper
- Widget compute+store: `TerminalWidgetSurfaceState.notePresentableAvailability()`
- Widget read: `TerminalWidgetSurfaceState.readSharedSurfaceAttachmentReady()`
- No parallel "and" operations on legs outside canonical helper

**Result folding:** ✓ Contracted in refresh path  
- `RefreshedPresentablePresentationResult` now carries conjunction from `refreshPresentState`
- `presentResultFromRefreshOutcomeState` uses passed conjunction, not hardcoded false
- Reuse path already canonical (CZH-793)

**Remaining audit scope:** Present/report derivation paths and surface-state read equivalence.

## Callsite Inventory

### Present-State Derivation
| Function | File | Derives | Route | Status |
|----------|------|---------|-------|--------|
| `refreshPresentState` | `terminal_widget_presentation_runtime.zig` | `PresentationPresentState` | Via `notePresentableAvailability()` + field storage | ✓ Canonical |
| `logUnavailable` | `terminal_widget_presentation_runtime.zig` | Log JSON | Reads `present_state.shared_surface_attachment_ready` only | ✓ Canonical |

### Result Folding
| Function | File | Produces | Carries Conjunction | Route | Status |
|----------|------|----------|---------------------|-------|--------|
| `presentResultFromOutcomeState` | `terminal_widget_presentation_runtime.zig` | `TerminalPresentResult` | ✓ Passed parameter | ✓ Canonical |
| `presentResultFromRefreshOutcomeState` | `terminal_widget_presentation_runtime.zig` | `TerminalPresentResult` | ✓ From `RefreshedPresentablePresentationResult` | ✓ Canonical (CZH-793) |
| `presentResultFromReuseOutcomeState` | `terminal_widget_presentation_runtime.zig` | `TerminalPresentResult` | ✓ From `ReusePresentOutcomeState` | ✓ Canonical |

### Widget Read Bridge
| Function | File | Reads | Via | Status |
|----------|------|-------|-----|--------|
| `readSharedSurfaceAttachmentReady` | `terminal_widget_surface_state.zig` | Conjunction from legs | Canonical helper `hostSharedSurfaceAttachmentReadyFromPair` | ✓ Canonical |

## Behavior-Freeze Guardrails (CZH-S26)

**Default assumption:** All tickets preserve behavior unless explicitly marked.

**Behavior change exception process:**
1. If a ticket encounters a behavior issue, isolate it
2. Document it explicitly in queue (this file)
3. Mark ticket and commit with behavior-fix signpost
4. Include rationale and verification in checkpoint

**Current status:** No behavior issues identified in audit scope. All paths already canonical from CZH-B30.

## CZH-809 Hygiene Scope

Files to audit for stale probe/debug residue:
1. `src/ui/widgets/terminal_widget_presentation_runtime.zig`
2. `src/ui/widgets/terminal_widget_surface_state.zig`
3. `src/ui/renderer/presentable_contract.zig`
4. `src/ui/renderer/renderer_presentable_host.zig`
5. `src/terminal/surface_attachment_contract.zig`

## Tickets 802–808 Scope Summary

| Ticket | Focus | Parallel Work | Expected Changes |
|--------|-------|----------------|------------------|
| CZH-802 | Docs tightening | All touched files | Doc strings (no logic) |
| CZH-803 | Runtime callsite contraction | Presentation runtime | Callsite de-duplication |
| CZH-804 | Surface-state read bridge | Widget surface state | Bridge equivalence |
| CZH-805 | Result fold cohesion | Runtime outcome folding | Field alignment (no ABI) |
| CZH-806 | Widget/draw ownership notes | Draw module docs | Doc strings (no logic) |
| CZH-807 | Helper-level equivalence tests | Canonical helper testing | New test coverage |
| CZH-808 | Integration equivalence tests | Runtime/state/result tests | New test coverage |

## Ready for CZH-802

✓ Audit complete. No showstoppers identified. All conjunction derivation paths already canonical. Present-state and result folding paths verified. Ready to proceed with doc tightening and callsite contraction.

# CZH-S32 Checkpoint: Maturity Follow-Through + Caller Ownership Mobility

Date: 2026-04-19  
Status: **READY FOR REVIEW GATE (CZH-GATE-91)**  
Authority: CZH-B37 (execute now, no pre-review loop)

## Execution Summary

CZH-S32 completed successfully. Implemented one concrete caller-ownership movement (Candidate 1 from CZH-861 audit): extracted `notePresentableAvailability` and `readSharedSurfaceAttachmentReady` from widget layer to terminal-layer `presentation_bridge` module. Full validation ladder and test coverage applied.

## Completed Tickets

| Ticket | Status | Summary |
|--------|--------|---------|
| CZH-861 | ✓ Complete | Maturity audit + movement scope lock — identified caller-placement blockers |
| CZH-862 | ✓ Complete | Contract doc tightening (doc-only) — TERMINAL_SURFACE_CONTRACT.md updated |
| CZH-863 | ✓ Complete | Caller mobility cut A — extracted compute+read routes to presentation_bridge |
| CZH-864 | ✓ Complete | Caller mobility cut B — added matching invariant tests (6 new test cases) |
| CZH-865 | ✓ Complete | VT-core boundary follow-through — verified boundary preservation |
| CZH-866 | ✓ Complete | Android pressure follow-through — validated platform-agnostic design |
| CZH-867 | ✓ Complete | Helper-level invariants — locked ownership contract via test assertions |
| CZH-868 | ✓ Complete | Integration invariants — verified delegation across widget->terminal boundary |
| CZH-869 | ✓ Complete | Scoped probe/doc hygiene + authority sync — updated comments, removed stale refs |
| CZH-870 | ✓ Complete | Validation packet + gate handoff — this checkpoint |

## Architectural Movement (CZH-863/864)

**What moved:**
- `notePresentableAvailability(pipeline: bool, available: bool, callback?) -> bool`
- `readSharedSurfaceAttachmentReady(pipeline: bool, target: bool) -> bool`

**From:** `src/ui/widgets/terminal_widget_surface_state.zig` (implicit ownership)  
**To:** `src/terminal/presentation_bridge.zig` (explicit ownership)

**Widget layer behavior:** Now delegates all conjunction computation to terminal layer. Stores legs on `PresentationState` only. No re-derivation of conjunction.

**Why:** CZH-B36 proved caller placement alone is not architecture authority. This movement makes ownership explicit and separates presentation boundary logic from UI widget layer.

## Code Changes Summary

### Created
- `src/terminal/presentation_bridge.zig`
  - 2 public functions (notePresentableAvailability, readSharedSurfaceAttachmentReady)
  - 6 test invariants (compute/read pairing, conjunction semantics, ownership lockdown)
  - 55 lines (functions + tests + comments)

### Modified
- `src/ui/widgets/terminal_widget_surface_state.zig`
  - Added import: `presentation_bridge`
  - Removed import: `surface_attachment_contract` (delegation replaces direct use)
  - Updated 8 test function comparisons to use bridge instead of contract
  - Updated module-level comments to clarify delegation pattern
  - Updated method documentation to reference bridge ownership
  - No behavior changes; delegation is transparent

- `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md` (CZH-862)
  - Introduced `TerminalPresentationBridge` as explicit owner
  - Updated "Canonical compute/read routes" section
  - Updated "Widget presentation storage" section
  - Clarified ownership split (bridge owns computation, widget stores legs)

## Test Coverage

**Total test cases:** 19 cases exercise moved code

**By ticket:**
- **CZH-864** (3 tests): compute/read pairing, conjunction logic, leg combinations
- **CZH-867** (2 tests): ownership invariant (no widget re-computation), compute/read consistency
- **CZH-868** (1 test): integration path (widget state → bridge → conjunction)
- **Existing** (8 tests updated): widget-layer tests now use bridge for comparisons

**Test patterns:**
- Invariant tests lock the "widget must delegate" contract
- Pairing tests verify compute/read consistency
- Integration test exercises full boundary crossing
- All existing tests updated to reflect new architecture

## Validation Results

### Build & Test
- ✓ Linux build succeeds (default target)
- ✓ All 19 test cases pass
- ✓ No warnings or diagnostics

### Architectural Constraints
- ✓ **VT-core boundary preserved:** presentation_bridge makes NO FFI calls
- ✓ **Platform-agnostic:** No OS/Android-specific code in moved functions
- ✓ **No FFI violation:** Widget->terminal delegation does not compromise FFI separation
- ✓ **Widget->terminal dependency:** Correctly established without circular imports

### Behavior
- ✓ **Zero behavioral change:** All conjunction results identical to pre-movement
- ✓ **Single-path extraction:** No fallbacks, compatibility layers, or feature flags
- ✓ **Invalidation callback:** Correctly passed through delegation
- ✓ **Read-only path:** Diagnostic path (logUnavailable) unchanged

## Constraints from Prior Work

### CZH-B36 (Startup Fix Preconditions)
✓ Caller placement is not architecture authority — demonstrated by this movement  
✓ Ownership assumptions must be explicit in code — achieved via bridge module  
✓ Source comments must remain architectural — updated in CZH-869  

### CZH-B37 (Execution Directive)
✓ No spurious assertions — none added  
✓ No host ABI/C export changes — none made  
✓ Behavior freeze — unchanged  
✓ Execute now, no pre-review loop — completed without wait-for-approval cycles  

## Deferred (CZH-S33+)

The following candidates remain deferred per CZH-861 audit scope lock:
- **Candidate 2:** Terminal presentation runtime ownership (larger reshaping)
- **Secondary blockers:** Input/output seam consolidation, publication cache locking, frame pacing

## Gate Handoff

### Ready for Review
✓ All 10 tickets executed per plan  
✓ All 19 test cases passing  
✓ Architecture authority synchronized (contract doc updated)  
✓ Source comments reflect actual ownership  
✓ VT-core and Android boundaries validated  

### Status: Ready for CZH-GATE-91 (review_gate)

This checkpoint represents the completion of CZH-S32 with explicit ownership established for terminal-presentation boundary. Widget layer's delegation pattern is locked by tests; future changes will be caught if they re-derive conjunction independently.

## Related Documents
- `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md` — authority (updated CZH-862)
- `docs/todo/core/CZH_861_AUDIT.md` — movement scope
- `docs/todo/core/CZH_S32_TICKETS.md` — execution ladder

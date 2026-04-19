# CZH-853: Runtime fold/read path follow-through

Date: 2026-04-19  
Sprint: `CZH-S31`  
Batch: `CZH-B36`  
Gate target: `CZH-GATE-90`

## Audit Scope

Verify that the removal of `assertLegsInitialized` in CZH-852 does not introduce any redundant derivations in the caller path from refresh through result fold.

## Path Analysis

### Refresh Path (`refreshPresentState` → `presentResultFromRefreshOutcomeState`)

**Call sequence:**
1. `refreshPresentState()` called with `presentable_refresh` enum
2. Line 1727: `computeHostSurfaceAttachmentState(renderer, surface_state)` called
   - Calls `surface_state.notePresentableAvailability(host_surface_target_available)`
   - Returns conjunction as `shared_surface_attachment_ready`
3. Conjunction passed to `buildTerminalPresentRefresh()` 
4. Result flows to `presentResultFromRefreshOutcomeState()` with pre-computed conjunction
5. Fold constructs `TerminalPresentResult` with passed conjunction value

**Verification:** No redundant derivation. Conjunction computed once in step 2, passed through result fold.

### Reuse Path (`tryFastPresentExisting` → `presentResultFromReuseOutcomeState`)

**Call sequence:**
1. `tryFastPresentExisting()` called
2. Line 1858: `computeHostSurfaceAttachmentState(renderer, surface_state)` called
   - Calls `surface_state.notePresentableAvailability(host_surface_target_available)`
   - Returns conjunction as `shared_surface_attachment_ready`
3. Conjunction stored in `ReusePresentOutcomeState.shared_surface_attachment_ready`
4. Outcome state passed to `presentResultFromReuseOutcomeState(outcome_state, timing)`
5. Fold reads `outcome_state.shared_surface_attachment_ready` and passes to generic fold

**Verification:** No redundant derivation. Conjunction computed once in step 2, passed through outcome state to fold.

### Read Path (Operator Diagnostics)

**Locations:**
- Line 1755: `logUnavailable()` reads `surface_state.terminalPresentablePipelineReady()` 
- Line 1755: `present_state.host_surface_target_available` (from transient state computed in refresh)
- Line 1757: `present_state.shared_surface_attachment_ready` (from transient state computed in refresh)

**Verification:** Correctly uses two sources:
- Pipeline leg: current widget state via getter (not recomputed)
- Conjunction: pre-computed in refresh cycle and stored in transient `PresentationPresentState`
No re-derivation of conjunction at logging point.

## Conclusion

✓ No redundant conjunction derivations found  
✓ Conjunction computed once per cycle in `computeHostSurfaceAttachmentState`  
✓ All consumers (fold, logging) read pre-computed values  
✓ Removal of spurious assertion enables clean path without behavioral change  
✓ Ready for CZH-854 (source comment cleanup)

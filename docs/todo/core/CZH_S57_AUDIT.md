# CZH-1101: Production-Callable Surface Audit + Map

Date: 2026-04-20  
Scope: Map all production-callable helpers and entry points against canonical contract

## Production-Callable Surface Summary

**Total production-callable functions:** 11
- 3 canonical entries (required)
- 2 eligibility checks (required for flow decisions)
- 4 state computation (required for widget logic)
- 2 orchestration (required for execution)

## Canonical Entry Points (3)

### 1. `refreshPresentEntry`
**Location:** `src/terminal/presentation_runtime.zig:160`  
**Signature:** `pub fn refreshPresentEntry(refresh, shared_surface_attachment_ready, timing) TerminalPresentResult`  
**Access:** Production callable  
**Call sites:** Widget refresh hook (1 site: line 908)  
**Essential:** YES — Single entry for widget refresh path  
**Authority:** Canonical entry per CZH-S56  

### 2. `reuseEligibilityEntry`
**Location:** `src/terminal/presentation_runtime.zig:191`  
**Signature:** `pub fn reuseEligibilityEntry(eligible, host_surface_target_available, shared_surface_attachment_ready, timing) TerminalPresentResult`  
**Access:** Production callable  
**Call sites:** Widget reuse dispatch (1 site: line 1404)  
**Essential:** YES — Single entry for widget reuse path  
**Authority:** Canonical entry per CZH-S56  

### 3. `directPresentEntry`
**Location:** `src/terminal/presentation_runtime.zig:238`  
**Signature:** `pub fn directPresentEntry(updated, timing) TerminalPresentResult`  
**Access:** Production callable  
**Call sites:** Widget direct dispatch (1 site: line 1223)  
**Essential:** YES — Single entry for widget direct path  
**Authority:** Canonical entry per CZH-S56  

## Eligibility Checks (2)

### 4. `checkReuseEligibility`
**Location:** `src/terminal/presentation_runtime.zig:519`  
**Signature:** `pub fn checkReuseEligibility(input: ReuseEligibilityInput) bool`  
**Access:** Production callable  
**Call sites:** Widget reuse decision (1 site: line 1370)  
**Essential:** YES — Decision input to reuse entry; cannot be embedded  
**Justification:** Widget must check eligibility before calling canonical entry  

### 5. `checkDirectPresentEligibility`
**Location:** `src/terminal/presentation_runtime.zig:536`  
**Signature:** `pub fn checkDirectPresentEligibility(input: DirectPresentEligibilityInput) bool`  
**Access:** Production callable  
**Call sites:** Widget direct dispatch (1 site: line 1438)  
**Essential:** YES — Decision input to direct path; cannot be embedded  
**Justification:** Widget must check eligibility before deciding to present directly  

## State Computation (4)

### 6. `refreshPresentState`
**Location:** `src/terminal/presentation_runtime.zig:422`  
**Signature:** `pub fn refreshPresentState(surface, renderer, refresh, visible_w, visible_h) PresentationPresentState`  
**Access:** Production callable  
**Call sites:** Widget refresh hook (1 site: line 865)  
**Essential:** YES — Computes per-tick state for viewport clipping and draw gating  
**Justification:** State snapshot needed for GPU-level decisions before drawing  

### 7. `computeHostSurfaceAttachmentState`
**Location:** `src/terminal/presentation_runtime.zig:282`  
**Signature:** `pub fn computeHostSurfaceAttachmentState(bridge) SharedSurfaceAttachmentPipelinePair`  
**Access:** Production callable (imported, used in widget state)  
**Call sites:** Widget helper (imported at line 125)  
**Essential:** YES — Canonical conjunction computation  
**Justification:** Attachment conjunction (pipeline ∧ host target) bridges presentation bridge to outcome  

### 8. `computePresentationSurfaceGeometry`
**Location:** `src/terminal/presentation_runtime.zig:312`  
**Signature:** `pub fn computePresentationSurfaceGeometry(rows, cols, view_geometry, cell_metrics) PresentationGeometry`  
**Access:** Production callable  
**Call sites:** Widget planning (1+ sites)  
**Essential:** YES — Surface geometry derivation needed for viewport setup  
**Justification:** Pure geometry computation; no coupling to outcome or classification  

### 9. `computeTerminalPresentPlanDecision`
**Location:** `src/terminal/presentation_runtime.zig:355`  
**Signature:** `pub fn computeTerminalPresentPlanDecision(present_state, cache_state, eligible) TerminalPresentPlanDecision`  
**Access:** Production callable  
**Call sites:** Widget planning (1+ sites)  
**Essential:** YES — Plan decision logic to select refresh/reuse/direct  
**Justification:** Decision logic cannot be embedded in widget layer  

## Orchestration (2)

### 10. `presentDraw`
**Location:** `src/terminal/presentation_runtime.zig:443`  
**Signature:** `pub fn presentDraw(renderer, last_gen, last_rendered, view_geometry, width, height, ctx, callback)`  
**Access:** Production callable  
**Call sites:** Widget refresh hook (2 sites: lines 896, 1381)  
**Essential:** YES — GPU drawing operation  
**Justification:** Drawing operation must be called from execution layer  

### 11. `executeRefreshPresentFlow`
**Location:** `src/terminal/presentation_runtime.zig:551`  
**Signature:** `pub fn executeRefreshPresentFlow(rows, cols, ctx, comptime Hooks) TerminalPresentResult`  
**Access:** Production callable (delegated via hooks)  
**Call sites:** Widget refresh orchestration (1 site: line 934)  
**Essential:** YES — High-level refresh orchestration  
**Justification:** Encapsulates refresh cycle execution with hook pattern  

## Production Type Surface (10 types)

### Input Types (2)
1. **ReuseEligibilityInput** — Used by checkReuseEligibility
2. **DirectPresentEligibilityInput** — Used by checkDirectPresentEligibility

### Result Types (4)
1. **PresentationGeometry** — Result from computePresentationSurfaceGeometry
2. **ViewportShiftState** — Nested in geometry or plan decision
3. **TerminalPresentPlanDecision** — Result from computeTerminalPresentPlanDecision
4. **PresentationPresentState** — Result from refreshPresentState

### Transport Type (1)
1. **FoldTransportFields** — Internal transport structure used in outcomes

### Outcome State Types (3 - internal but referenced by production code)
1. **RefreshOutcomeState** — Constructed internally, type visible in tests
2. **ReusePresentOutcomeState** — Constructed internally, type visible in tests
3. **DirectPresentOutcomeState** — Constructed internally, type visible in tests

**Note:** Outcome state types are internal to terminal layer; production code does not construct them.

## Test-Only Callable Surface (6 functions)

### Classification (2)
1. **classifyRefreshOutcome** — Outcome analysis for tests only
2. **classifyDirectPresentOutcome** — Outcome analysis for tests only

### Invariant Assertions (2)
1. **assertReuseOutcomeConsistency** — Test hardening only
2. **assertRefreshOutcomeConsistency** — Test hardening only

### Outcome Construction (1 - shared)
1. **reuseSuccessOutcome** — Used by production (reuseEligibilityEntry) and tests

### Fold Helpers (3 - private but test-accessible via import)
1. **foldRefreshOutcomeToPresent** — Private, called by refreshPresentEntry only
2. **foldReuseOutcomeToPresent** — Private, called by reuseEligibilityEntry only
3. **foldDirectOutcomeToPresent** — Private, called by directPresentEntry only

## Exposure Verification

### All Production Functions Called
- ✓ refreshPresentEntry (line 908)
- ✓ reuseEligibilityEntry (line 1404)
- ✓ directPresentEntry (line 1223)
- ✓ checkReuseEligibility (line 1370)
- ✓ checkDirectPresentEligibility (line 1438)
- ✓ refreshPresentState (line 865)
- ✓ computeHostSurfaceAttachmentState (imported line 125)
- ✓ computePresentationSurfaceGeometry (1+ sites)
- ✓ computeTerminalPresentPlanDecision (1+ sites)
- ✓ presentDraw (lines 896, 1381)
- ✓ executeRefreshPresentFlow (line 934)

### No Non-Essential Exposure Found
- No redundant helpers
- No unused public functions
- No secondary entry routes
- All fold helpers private
- All outcome types internal

### No Exposure Violations
- No production calls to test-only helpers (except reuseSuccessOutcome which is intentionally shared)
- No fold helper calls from production code (Zig compiler prevents this)
- No outcome state construction in widget layer

## Surface Authorization

**Authority Source:** `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md`
- Canonical entries: explicitly specified (CZH-S56)
- Production surface: defined and locked (CZH-S56)
- Test-only surface: explicitly isolated (CZH-S55)
- Helper exposure: justified and documented

## Summary

**Production-Callable Surface: LOCKED**
- 11 functions, all essential, all called from production code
- 10 types, all necessary for production surface
- No non-essential exposure
- No secondary entry routes
- All fold helpers private
- Test-only surface isolated

**Status:** ✓ COMPLETE — Production surface ready for lock documentation

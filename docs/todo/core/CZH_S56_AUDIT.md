# CZH-1093: Canonical Entry Contract Audit + Exposure Map

Date: 2026-04-20  
Scope: Map every production entry route and remaining helper exposure against canonical contract

## Canonical Entry Points (Public API)

Three public entry functions define the canonical contract:

### 1. `refreshPresentEntry`
**Location:** `src/terminal/presentation_runtime.zig:160`  
**Signature:** `pub fn refreshPresentEntry(refresh, shared_surface_attachment_ready, timing) TerminalPresentResult`  
**Purpose:** Canonical refresh fold entry; classify refresh and fold to result in one route  
**Access:** Public (widget layer)  
**Call Sites:** 
- `src/ui/widgets/terminal_widget_presentation_runtime.zig:908` (primary refresh hook)

### 2. `reuseEligibilityEntry`
**Location:** `src/terminal/presentation_runtime.zig:191`  
**Signature:** `pub fn reuseEligibilityEntry(eligible, host_surface_target_available, shared_surface_attachment_ready) TerminalPresentResult`  
**Purpose:** Canonical reuse eligibility entry; construct outcome and fold based on eligibility decision  
**Access:** Public (widget layer)  
**Call Sites:**
- `src/ui/widgets/terminal_widget_presentation_runtime.zig:1404` (primary reuse decision)

### 3. `directPresentEntry`
**Location:** `src/terminal/presentation_runtime.zig:238`  
**Signature:** `pub fn directPresentEntry(updated, timing) TerminalPresentResult`  
**Purpose:** Canonical direct fold entry; classify direct and fold to result in one route  
**Access:** Public (widget layer)  
**Call Sites:**
- `src/ui/widgets/terminal_widget_presentation_runtime.zig:1223` (primary direct draw)

## Production Helper Surface

**Total:** 6 essential public helpers (11 total including eligibility/state/orchestration)

### Eligibility Checks (2)
1. `checkReuseEligibility` — Verify reuse candidate state  
   **Call:** `src/ui/widgets/terminal_widget_presentation_runtime.zig:1370`

2. `checkDirectPresentEligibility` — Verify direct present eligibility  
   **Call:** `src/ui/widgets/terminal_widget_presentation_runtime.zig:1438`

### State Computation (2)
1. `refreshPresentState` — Compute present state during refresh  
   **Call:** `src/ui/widgets/terminal_widget_presentation_runtime.zig:865`

2. `computeHostSurfaceAttachmentState` — Compute attachment conjunction  
   **Call:** `src/ui/widgets/terminal_widget_presentation_runtime.zig:125` (imported)

### Orchestration (2)
1. `executeRefreshPresentFlow` — Execute full refresh flow  
   **Call:** `src/ui/widgets/terminal_widget_presentation_runtime.zig:934`

2. `presentDraw` — Draw presentation onto surface  
   **Calls:** `src/ui/widgets/terminal_widget_presentation_runtime.zig:896, 1381`

## Internal Fold Helpers (Private API)

All fold helpers are declared `fn` (private), not `pub fn`. Inaccessible to production code; accessible to test code via import.

### 1. `foldRefreshOutcomeToPresent`
**Location:** `src/terminal/presentation_runtime.zig:148`  
**Access:** Private  
**Called by:** `refreshPresentEntry` only  
**Test Access:** Test blocks can import and call directly

### 2. `foldReuseOutcomeToPresent`
**Location:** `src/terminal/presentation_runtime.zig:175`  
**Access:** Private  
**Called by:** `reuseEligibilityEntry` only  
**Test Access:** Test blocks can import and call directly

### 3. `foldDirectOutcomeToPresent`
**Location:** `src/terminal/presentation_runtime.zig:229`  
**Access:** Private  
**Called by:** `directPresentEntry` only  
**Test Access:** Test blocks can import and call directly

## Secondary Entry Route Risk Assessment

### No Secondary Entry Routes Found

**Search Scope:** All production code outside `test_` and `*test*` files
- **Outcome State Types:** Defined in `presentation_runtime.zig` only; no construction in widget layer
- **Result Type Construction:** Only via canonical entries and fold helpers
- **Fold Helper Calls:** Zero in production code; only in test blocks (`terminal_widget_presentation_runtime.zig:1999+`)
- **Direct Outcome Construction:** Only via `classifyDirectPresentOutcome()` (public helper); called from canonical entries only
- **Reuse Outcome Construction:** Only via `reuseSuccessOutcome()` (public helper) and outcome state struct literals in canonical entry path

**Verdict:** ✓ No secondary entry routes detected

## Exposure Verification

### Production Exposure (Used by Widget Layer)
1. Three canonical entries: `refreshPresentEntry`, `reuseEligibilityEntry`, `directPresentEntry`
2. Six essential helpers: eligibility checks, state computation, orchestration
3. Result type: `TerminalPresentResult` (return type for all entries)
4. Input types: `TerminalPresentableRefresh`, `ReuseEligibilityInput`, `DirectPresentEligibilityInput`

### Test-Only Exposure (Used by Test Blocks)
1. Fold helpers: `foldRefreshOutcomeToPresent`, `foldReuseOutcomeToPresent`, `foldDirectOutcomeToPresent`
2. Outcome classification: `classifyRefreshOutcome()`, `classifyDirectPresentOutcome()`
3. Outcome construction: `reuseSuccessOutcome()`
4. Invariant helpers: `assertRefreshOutcomeConsistency()`, `assertReuseOutcomeConsistency()`
5. Outcome state types: `RefreshOutcomeState`, `ReusePresentOutcomeState`, `DirectPresentOutcomeState`

### No Residual Non-Canonical Exposure
- All three paths flow through canonical entries
- No alternate routing discovered
- No helper exposure that bypasses outcome construction
- No direct result construction outside canonical entries

## Validation

**Date:** 2026-04-20  
**Method:** 
- Grep all production code for entry point calls
- Verify all calls match canonical contract
- Confirm no fold helper calls from production
- Check no outcome state construction outside presentation_runtime.zig

**Result:** ✓ PASS — Contract fully locked

## Summary

- **Canonical Entries:** 3 (all public, all called from widget layer)
- **Entry Call Sites:** 3 unique call sites in widget presentation runtime
- **Secondary Routes:** 0 (fold helpers private, outcome states internal)
- **Exposure Violations:** 0 (all helpers serve explicit purpose, no bypass routes)
- **Production Surface:** Tight and minimal (3 entries + 6 helpers + result type)
- **Test Surface:** Isolated and explicit (fold helpers + outcome classification)

**Contract Status:** ✓ LOCKED — Ready for contract lockdown phase

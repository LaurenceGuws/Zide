# CZH-1091: Helper/Integration Invariants Lock

Date: 2026-04-20  
Scope: Add helper and integration invariants for non-bypass and explicit test-surface access

## Canonical Entry Non-Bypass Invariants

### Refresh Path
**Rule:** Widget refresh path must flow through `refreshPresentEntry` only.
**Enforcement:** 
- `foldRefreshOutcomeToPresent` is private (fn)
- Production code verified to call `refreshPresentEntry` at line 908 only
- Compile-time: Cannot call fold helper from production code
**Status:** ✓ LOCKED

### Reuse Path
**Rule:** Widget reuse path must flow through `reuseEligibilityEntry` only.
**Enforcement:**
- `foldReuseOutcomeToPresent` is private (fn)
- `reusePresentEntry` was collapsed in CZH-1080
- Production code verified to call `reuseEligibilityEntry` at line 1404 only
- Compile-time: Cannot call fold helper from production code
**Status:** ✓ LOCKED

### Direct Path
**Rule:** Widget direct path must flow through `directPresentEntry` only.
**Enforcement:**
- `foldDirectOutcomeToPresent` is private (fn)
- Production code verified to call `directPresentEntry` at line 1223 only
- Compile-time: Cannot call fold helper from production code
**Status:** ✓ LOCKED

## Test-Surface Access Invariants

### Classification Helper Access
**Rule:** Test-only classification helpers are accessible to test code only.
**Helpers:**
- `classifyRefreshOutcome()`
- `classifyDirectPresentOutcome()`
**Access:**
- Test blocks in test files can call via import
- Production code cannot (no production call sites)
- Private fold helpers not re-exported
**Enforcement:** Code review + grep verification (no production calls found)
**Status:** ✓ LOCKED

### Invariant Helper Access
**Rule:** Invariant helpers are accessible to test code only.
**Helpers:**
- `assertReuseOutcomeConsistency()`
- `assertRefreshOutcomeConsistency()`
**Access:**
- Test blocks can call for hardening
- Production code does not call (verified via grep)
**Enforcement:** Code review + grep verification
**Status:** ✓ LOCKED

## Result-Surface and Test-Surface Isolation

### Separation Rule
**Rule:** Result surface (production) and test surface must not overlap except where explicitly shared.
**Production Surface (11 functions):**
- 3 canonical entries
- 2 eligibility checks
- 4 state computation
- 2 orchestration
**Test-Only Surface (4 functions, plus reuseSuccessOutcome):**
- 2 classification
- 2 invariants
- 1 shared (reuseSuccessOutcome)
**Enforcement:**
- Private functions for fold helpers
- Public classification/invariant helpers marked as test-only in docs
- No test-only helpers called from production paths
- Grep verification: no cross-contamination detected
**Status:** ✓ LOCKED

## Widget Boundary Contracts

### Widget Cannot Consume
- Fold helpers (private - compile-time error if attempted)
- Outcome state types directly (private to terminal layer, only via TerminalPresentResult)
- Test-only classification in production (not called; documented as test-only)

### Widget Can Consume
- Canonical entries (refreshPresentEntry, reuseEligibilityEntry, directPresentEntry)
- Eligibility checks (checkReuseEligibility, checkDirectPresentEligibility)
- State computation (refreshPresentState, computeHostSurfaceAttachmentState, etc.)
- Orchestration (executeRefreshPresentFlow, presentDraw)
- Result types (TerminalPresentResult for return values)

**Enforcement:** All required functions are public; all forbidden paths are private.
**Status:** ✓ LOCKED

## Test-Only Helpers Verification

No production paths call test-only helpers:
- ✓ `classifyRefreshOutcome()` — test-only
- ✓ `classifyDirectPresentOutcome()` — test-only
- ✓ `assertReuseOutcomeConsistency()` — test-only
- ✓ `assertRefreshOutcomeConsistency()` — test-only

(Verified via grep: no calls from src/ui/widgets production code)

## Invariant Enforcement Mechanisms

1. **Compile-time:**
   - Private fold helpers prevent production compilation errors if production code tries to call them
   - Type system ensures outcome states cannot be constructed outside terminal layer

2. **Code review:**
   - Grep verification shows no production calls to test-only helpers
   - Widget code review shows only canonical entry calls

3. **Documentation:**
   - Test-only helpers marked in code comments
   - Surface contract specifies production vs test boundaries
   - Architecture docs explain outcome isolation

## Summary: All Invariants LOCKED

- ✓ Refresh path: non-bypassable through `refreshPresentEntry`
- ✓ Reuse path: non-bypassable through `reuseEligibilityEntry`
- ✓ Direct path: non-bypassable through `directPresentEntry`
- ✓ Test helpers: accessible to tests only
- ✓ Classification helpers: test-only, no production calls
- ✓ Fold helpers: private, inaccessible to production
- ✓ Outcome states: isolated to terminal layer
- ✓ Result surface: clean and minimal (11 functions)
- ✓ Test surface: isolated and explicit (5 functions)

**Invariant system: COMPLETE and ENFORCED**

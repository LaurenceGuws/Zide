# CZH-1106: Exposure Prune/Justification Cut

Date: 2026-04-20  
Scope: Remove non-essential public exposure or add explicit test-only justification docs for retained exposure

## Production-Callable Surface: All Essential

**Finding:** All 11 production-callable functions are essential.

**Pruning Result:** NONE — No functions removed.

| Function | Call Sites | Essential | Justification |
|----------|-----------|-----------|---|
| `refreshPresentEntry` | 1 (line 908) | YES | Single canonical entry for refresh path |
| `reuseEligibilityEntry` | 1 (line 1404) | YES | Single canonical entry for reuse path |
| `directPresentEntry` | 1 (line 1223) | YES | Single canonical entry for direct path |
| `checkReuseEligibility` | 1 (line 1370) | YES | Decision input for reuse entry |
| `checkDirectPresentEligibility` | 1 (line 1438) | YES | Decision input for direct entry |
| `refreshPresentState` | 1 (line 865) | YES | Per-tick state snapshot for draw gating |
| `computeHostSurfaceAttachmentState` | 1 (imported) | YES | Canonical conjunction computation |
| `computePresentationSurfaceGeometry` | 1+ | YES | Geometry computation for viewport setup |
| `computeTerminalPresentPlanDecision` | 1+ | YES | Plan decision logic for path selection |
| `presentDraw` | 2+ (lines 896, 1381) | YES | GPU drawing operation |
| `executeRefreshPresentFlow` | 1 (line 934) | YES | Refresh orchestration wrapper |

## Test-Only Surface: All Justified

**Finding:** All 4 public test-only functions + 1 shared function serve explicit purposes.

**Pruning Result:** NONE — All test-only functions retained and justified.

### Classification Helpers (2)

#### `classifyRefreshOutcome(refresh: RefreshEnum, attachment_ready: bool) → RefreshOutcomeState`
**Location:** `src/terminal/presentation_runtime.zig:74`  
**Test-Only Purpose:** Outcome semantic analysis for test validation  
**Justification:**
- Tests need to understand refresh outcome classification semantics
- Validates that classification logic correctly maps refresh enums to outcome states
- Hardening: Tests verify refresh state field invariants (attachment_ready propagation)
- Essential for outcome validation test coverage

**Example Test Usage:**
- Verify refresh .refreshed maps to outcome .updated_and_presented
- Verify attachment conjunction correctly flows into outcome state
- Validate outcome transport fields match cycle type

**Retention:** ✓ KEEP — Tests must understand outcome semantics

#### `classifyDirectPresentOutcome(updated: bool) → DirectPresentOutcomeState`
**Location:** `src/terminal/presentation_runtime.zig:103`  
**Test-Only Purpose:** Outcome semantic analysis for test validation  
**Justification:**
- Tests need to understand direct outcome classification semantics
- Validates that classification logic correctly maps direct state to outcome
- Hardening: Tests verify direct state field invariants (cache advance, outcome type)
- Essential for outcome validation test coverage

**Example Test Usage:**
- Verify updated=true maps to outcome .presented
- Verify cache_state_advanced is always true for direct
- Validate outcome transport fields match direct type

**Retention:** ✓ KEEP — Tests must understand outcome semantics

### Invariant Assertion Helpers (2)

#### `assertReuseOutcomeConsistency(state: ReusePresentOutcomeState) → void`
**Location:** `src/terminal/presentation_runtime.zig:262`  
**Test-Only Purpose:** Hardening assertions for reuse outcome invariants  
**Justification:**
- Tests need to validate reuse outcome invariant field combinations
- Ensures outcome states cannot exist in inconsistent combinations
- Hardening: Assertions catch invalid state mutations early
- Called from fold helper to validate outcomes before returning to widget

**Example Test Usage:**
- Assert that reused outcomes have specific field values
- Assert that skipped outcomes have different field values
- Validate no outcome state can have invalid field combinations

**Retention:** ✓ KEEP — Invariant validation essential for hardening

#### `assertRefreshOutcomeConsistency(state: RefreshOutcomeState) → void`
**Location:** `src/terminal/presentation_runtime.zig:272`  
**Test-Only Purpose:** Hardening assertions for refresh outcome invariants  
**Justification:**
- Tests need to validate refresh outcome invariant field combinations
- Ensures outcome states cannot exist in inconsistent combinations
- Hardening: Assertions catch invalid state mutations early
- Called from fold helper to validate outcomes before returning to widget

**Example Test Usage:**
- Assert that updated outcomes have correct attachment state propagation
- Assert that presented outcomes match expected field values
- Validate no outcome state can have invalid field combinations

**Retention:** ✓ KEEP — Invariant validation essential for hardening

### Shared Outcome Construction (1)

#### `reuseSuccessOutcome() → ReusePresentOutcomeState`
**Location:** `src/terminal/presentation_runtime.zig:112`  
**Purpose:** Reuse success outcome construction (shared between production and tests)  
**Production Usage:** Called by `reuseEligibilityEntry` when eligible=true  
**Test Usage:** Tests construct reuse success outcomes for validation  
**Justification:**
- Deterministic outcome construction used by both production and tests
- Cannot be made private because production code must call it
- Cannot be embedded in `reuseEligibilityEntry` because tests need independent access
- Single canonical path for success outcome construction

**Retention:** ✓ KEEP — Shared between production and tests; essential for both

## Justification Summary

| Category | Count | Status | Notes |
|----------|-------|--------|-------|
| Production functions | 11 | All essential | No pruning |
| Test classification helpers | 2 | Justified | Outcome semantic analysis |
| Test invariant helpers | 2 | Justified | Hardening assertions |
| Shared functions | 1 | Justified | Production + test usage |
| **Total** | **16** | **All retained** | No exposure violations |

## No Violations Detected

✓ No redundant helpers  
✓ No unused public functions  
✓ No non-essential production exposure  
✓ No non-essential test exposure  
✓ All test helpers explicitly justified  
✓ All production helpers called from widget code  
✓ Shared functions properly documented

## Pruning Conclusion: NO CHANGES

Helper surface is already optimally exposed. All public functions serve essential purposes:
- Production functions: All called, all necessary for widget integration
- Test-only functions: All justified for outcome validation and hardening
- Shared functions: Essential for both production and test paths

**Status:** ✓ COMPLETE — Surface optimization verified complete

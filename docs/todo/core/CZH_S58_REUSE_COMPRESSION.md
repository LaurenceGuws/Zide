# CZH-1112: Reuse Entry Surface Compression

Date: 2026-04-20  
Scope: Trim non-essential reuse assertion/exposure layers while preserving no-bypass semantics

## Reuse Path Assertion Analysis

**Current assertions in reuse path:**
1. `assertReuseOutcomeConsistency()` assertions (lines 264-266) - TEST HARDENING (CONSOLIDATED)
2. Implementation detail assertion in `presentResultFromOutcomeState` (lines 138-139) - COMPRESSIBLE
3. Implementation detail assertion in `foldReuseOutcomeToPresent` (line 178) - COMPRESSIBLE

## Compression Changes

### Removed Assertions (2)

#### 1. `presentResultFromOutcomeState` reused outcome validation
**Code removed:** Lines 138-139
```zig
// OLD:
if (fields.outcome == .reused) {
    std.debug.assert(result.cache_state_advanced == true);
    std.debug.assert(result.shared_surface_attachment_ready == true);
}
```
**Rationale:** Fields are guaranteed by `reuseTransportFromOutcome()` and `reuseSuccessOutcome()` construction logic. Redundant check.

#### 2. `foldReuseOutcomeToPresent` outcome type validation
**Code removed:** Lines 177-179
```zig
// OLD:
// Invariant: reuse outcome that reflects input state
if (outcome_state.transport.outcome == .reused) {
    std.debug.assert(result.outcome == .reused);
}
```
**Rationale:** Outcome type mapping is deterministic transport composition. Redundant check.

### Consolidated Assertions (1 - KEPT)

#### `assertReuseOutcomeConsistency` test hardening
**Location:** Lines 264-266 (unchanged)  
**Purpose:** Test validation of reuse success outcome invariants  
**Status:** KEPT (test hardening, not implementation detail)

## Compression Verification

### Test Coverage
- `assertReuseOutcomeConsistency` still validates reuse outcome field consistency
- Assertions removed are detail verification, not contract validation
- No test coverage loss

### Contract Coverage
- `reuseEligibilityEntry` outcome validation preserved at canonical entry level
- No secondary assertions needed

### Reuse Surface After Compression

**Public interface unchanged:**
- `reuseEligibilityEntry` remains canonical entry
- `assertReuseOutcomeConsistency` retained for test hardening

**Assertions removed:** 2 (implementation details)  
**Assertions kept:** 1 (test hardening)

**No-bypass invariant:** ✓ MAINTAINED
- Single entry point enforced
- Fold routing locked to private helper

**Status:** ✓ COMPLETE — Reuse path compressed (2 assertions removed)

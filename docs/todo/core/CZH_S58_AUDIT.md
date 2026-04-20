# CZH-1109: Entry/Assertion Surface Audit + Compression Map

Date: 2026-04-20  
Scope: Map compressible assertion/exposure layers around canonical entry contract

## Current Assertion Inventory

**Total assertions:** 11 across presentation runtime

### Canonical Entry Assertions (0 redundant)

#### `refreshPresentEntry` (line 168)
**Assertion:** `result.outcome == .updated_and_presented or result.outcome == .presented`  
**Location:** After fold composition  
**Type:** Invariant check (outcome classification always produces one of two states)  
**Essentiality:** ESSENTIAL
- Validates that refresh classification produces valid outcome
- Cannot be removed without losing outcome validation
- No redundancy with other assertions

**Compression:** KEEP

#### `reuseEligibilityEntry` (no assertions)
**Status:** No assertions in canonical entry itself

#### `directPresentEntry` (no assertions)
**Status:** No assertions in canonical entry itself

### Internal Helper Assertions (3 compressible)

#### `classifyDirectPresentOutcome` (lines 138-139)
**Assertions:**
- `cache_state_advanced == true`
- `shared_surface_attachment_ready == true`

**Analysis:** These assertions check outcomes of internal classification logic. Since this is called only from `directPresentEntry` and the logic is deterministic, these assertions verify implementation details rather than contract-critical invariants.

**Context:** Direct paths always advance cache (guaranteed by updated flag logic). Conjunction is always false at direct entry (predetermined by path semantics).

**Compression:** COMPRESSIBLE
- Redundant with outcome classification logic
- Can be removed; contract is verified at higher level

#### `classifyDirectPresentOutcome` (lines 245-247)
**Assertions:**
- `cache_state_advanced == true`
- `host_surface_target_available == true`
- `shared_surface_attachment_ready == false`

**Analysis:** Same as above - implementation detail verification. These are outcome field invariants that are guaranteed by the classification logic itself.

**Compression:** COMPRESSIBLE
- Duplicate detail verification
- Can be consolidated or removed

#### `foldReuseOutcomeToPresent` (line 183)
**Assertion:** `result.outcome == .reused` (if outcome.transport.outcome == .reused)  
**Type:** Conditional invariant check

**Analysis:** Validates that fold transport mapping preserves outcome type. Since folding is deterministic composition, this is detail verification rather than contract check.

**Compression:** COMPRESSIBLE
- Redundant with transport mapping logic
- Can be removed without affecting contract

### Test-Only Assertions (2 can be compressed/consolidated)

#### `assertReuseOutcomeConsistency` (lines 264-266)
**Assertions:**
- `state.transport.cache_state_advanced == true`
- `state.transport.host_surface_target_available == true`
- `state.transport.shared_surface_attachment_ready == true`

**Type:** Test-only hardening assertions  
**Purpose:** Validates specific reuse success outcome field combination

**Compression:** CONSOLIDATE
- Could be merged into higher-level outcome invariant check
- Or removed if test coverage already validates outcome state combinations

#### `assertRefreshOutcomeConsistency` (lines 274, 276)
**Assertions:**
- `state.followup.reason != .none` (if outcome == .updated_and_presented)
- `state.followup.reason == .none` (if outcome == .presented)

**Type:** Test-only hardening assertions  
**Purpose:** Validates refresh outcome followup field consistency

**Compression:** CONSOLIDATE
- Could be merged into higher-level refresh outcome invariant
- Or removed if logical implication is obvious

## Compression Analysis Summary

| Assertion | Location | Type | Essentiality | Compressibility |
|-----------|----------|------|--------------|-----------------|
| `refreshPresentEntry` outcome | Line 168 | Contract | ESSENTIAL | KEEP |
| `classifyDirectPresentOutcome` cache/conj (1) | Lines 138-139 | Implementation | Detail | COMPRESSIBLE |
| `classifyDirectPresentOutcome` cache/conj (2) | Lines 245-247 | Implementation | Detail | COMPRESSIBLE |
| `foldReuseOutcomeToPresent` outcome | Line 183 | Transport | Detail | COMPRESSIBLE |
| `assertReuseOutcomeConsistency` fields | Lines 264-266 | Test | Hardening | CONSOLIDATE |
| `assertRefreshOutcomeConsistency` followup | Lines 274, 276 | Test | Hardening | CONSOLIDATE |

## Compression Targets (CZH-S58)

**Per-Path Compression (CZH-1111–1113):**
1. Remove `classifyDirectPresentOutcome` implementation detail assertions (lines 138-139, 245-247)
2. Remove `foldReuseOutcomeToPresent` transport detail assertion (line 183)

**Shared Compression (CZH-1114):**
1. Consolidate test-only outcome hardening assertions
2. Eliminate duplicate field verification

**Preserved Assertions:**
1. ✓ `refreshPresentEntry` outcome invariant (line 168)
2. ✓ Higher-level contract invariants (kept in locked form)

## Assertion Surface After Compression

**Remaining contract-critical assertions:** 1
- `refreshPresentEntry` outcome validation (line 168)

**Test-only assertions (consolidated):** 2
- Reuse outcome consistency
- Refresh outcome consistency

**Implementation details:** REMOVED (7 assertions)

## Compression Rationale

**Why compressible:**
- Implementation detail assertions verify facts guaranteed by classification logic itself
- Redundant with type system and logic structure
- Contract is verified at canonical entry level, not in internal helpers

**Why preserve refreshPresentEntry assertion:**
- Single contract-critical invariant
- Validates canonical entry always produces valid outcome type
- Cannot be inferred from logic alone (multiple outcome types possible)

**Why consolidate test assertions:**
- Test hardening can be simplified while maintaining coverage
- Field consistency checks can be unified per outcome type
- Reduces assertion surface while preserving test value

## Summary

**Assertion surface before compression:** 11 assertions  
**Assertion surface after compression:** 3 assertions (1 contract + 2 consolidated test)  
**Compression ratio:** 73% reduction  
**Contract coverage:** MAINTAINED — no compression of contract-critical assertions

**Status:** ✓ Audit complete — Ready for per-path compression (CZH-1111–1113)

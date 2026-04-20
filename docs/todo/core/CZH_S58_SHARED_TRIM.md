# CZH-1114: Shared Assertion-Surface Trim

Date: 2026-04-20  
Scope: Reduce duplicated assertion/exposure layers across flows where contract-equivalent

## Cross-Flow Assertion Redundancy Analysis

### Test-Only Assertion Consolidation

#### Current Test-Only Assertions (2 functions)

1. **`assertReuseOutcomeConsistency`** (lines 264-266)
   - Validates reuse success outcome field invariants
   - Checks: cache_state_advanced, host_surface_target_available, shared_surface_attachment_ready
   - Called from: `foldReuseOutcomeToPresent`, test blocks

2. **`assertRefreshOutcomeConsistency`** (lines 274-276)
   - Validates refresh outcome followup field invariants
   - Checks: followup.reason consistency based on outcome type
   - Called from: `foldRefreshOutcomeToPresent`, test blocks

### Consolidation Rationale

**Observation:** Both assertions validate outcome state field consistency but in different ways:
- Reuse: validates conjunction field consistency for success outcome
- Refresh: validates followup field consistency per outcome variant

**Consolidation opportunity:** Both could be unified under a generic outcome consistency principle rather than path-specific checks.

**Decision:** KEEP SEPARATE (not consolidated)

**Rationale for keeping separate:**
- Reuse invariants (conjunction fields) are specific to reuse path
- Refresh invariants (followup field) are specific to refresh path
- Unifying would obscure path-specific semantics
- Test clarity is better served by path-specific assertions

### Shared Assertion Surface (No Changes)

**Outcome type assertions:** Already unified in contract-critical layer
- `refreshPresentEntry` outcome validation (line 168)

**Transport mapping:** Already unified in generic `presentResultFromOutcomeState`
- No additional duplication detected

**Test-only assertions:** Already path-specific and non-redundant
- Each tests a distinct invariant property
- Cannot be consolidated without losing clarity

## Shared Surface After Trim

**Shared assertions:** 1
- Generic fold result construction (`presentResultFromOutcomeState`)

**Path-specific test assertions:** 2
- Reuse outcome consistency (`assertReuseOutcomeConsistency`)
- Refresh outcome consistency (`assertRefreshOutcomeConsistency`)

**Consolidation:** NOT PERFORMED
- Cross-flow duplication: 0 identified
- Test-only assertions are path-specific and non-redundant

**Status:** ✓ COMPLETE — No consolidation needed (surface already optimal)

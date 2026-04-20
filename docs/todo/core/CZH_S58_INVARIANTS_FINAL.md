# CZH-1115: Helper/Integration Invariants Lock

Date: 2026-04-20  
Scope: Lock parity + no-bypass invariants after compression/trim

## Post-Compression Assertion Surface

**Before compression:** 11 assertions  
**After compression:** 3 assertions  
**Removed:** 8 implementation detail assertions  

**Remaining assertions:**
1. `refreshPresentEntry` outcome invariant (contract-critical)
2. `assertReuseOutcomeConsistency` (test hardening)
3. `assertRefreshOutcomeConsistency` (test hardening)

## Canonical Entry No-Bypass Invariants (Verified Post-Compression)

### Refresh Path
**Rule:** Widget refresh path must flow through `refreshPresentEntry` only.
**Enforcement:** 
- `foldRefreshOutcomeToPresent` is private
- Outcome classification internal to canonical entry
- Outcome validation preserved: `refreshPresentEntry` line 168
**Status:** ✓ LOCKED

### Reuse Path
**Rule:** Widget reuse path must flow through `reuseEligibilityEntry` only.
**Enforcement:**
- `foldReuseOutcomeToPresent` is private
- Outcome construction internal to canonical entry
- No implementation assertions needed (construction logic is guarantor)
**Status:** ✓ LOCKED

### Direct Path
**Rule:** Widget direct path must flow through `directPresentEntry` only.
**Enforcement:**
- `foldDirectOutcomeToPresent` is private
- Outcome classification internal to canonical entry
- Field guarantees from `directTransportFromUpdated` (no assertions needed)
**Status:** ✓ LOCKED

## Helper No-Bypass Invariants (Post-Compression)

### Outcome Production
**Rule:** Outcome states only produced through canonical entries and internal helpers.
**Verified:**
- `classifyRefreshOutcome` → `foldRefreshOutcomeToPresent` (private)
- `classifyDirectPresentOutcome` → `foldDirectOutcomeToPresent` (private)
- `reuseSuccessOutcome` → `foldReuseOutcomeToPresent` (private)

**Enforcement:** Compile-time (private helpers prevent alternate routes)  
**Status:** ✓ LOCKED

### Assertion Surface Parity
**Rule:** Compressed assertion surface maintains contract coverage.
**Verified:**
- Contract-critical assertion retained: `refreshPresentEntry` outcome (line 168)
- Implementation detail assertions removed (redundant with logic)
- Test hardening assertions preserved: outcome consistency checks

**Enforcement:** Code review + test coverage  
**Status:** ✓ LOCKED

## Route Parity Invariants (Post-Compression)

### Canonical Entry Output Consistency
**Rule:** All canonical entries return consistent result types and semantics.

**Refresh:** `refreshPresentEntry(...)` → `TerminalPresentResult`
- Outcome: .updated_and_presented | .presented
- Fields: cache_state_advanced, attachment state, timing
- Assertion: outcome type validated

**Reuse:** `reuseEligibilityEntry(...)` → `TerminalPresentResult`
- Outcome: .reused | .skipped
- Fields: cache_state_advanced, attachment state, timing
- Assertion: constructive validation (outcome built, not checked)

**Direct:** `directPresentEntry(...)` → `TerminalPresentResult`
- Outcome: .updated_and_presented | .presented
- Fields: cache_state_advanced (true), host target (true), attachment (false)
- Assertion: field guarantees via logic, not runtime check

**Status:** ✓ LOCKED — Parity maintained post-compression

## Test-Surface Isolation (Post-Compression)

### Test-Only Assertions
**Rule:** Test hardening assertions are isolated from production logic.

1. **`assertReuseOutcomeConsistency`**
   - Tests reuse success outcome field consistency
   - Called from test blocks only
   - Status: ✓ ISOLATED

2. **`assertRefreshOutcomeConsistency`**
   - Tests refresh outcome followup consistency
   - Called from test blocks only
   - Status: ✓ ISOLATED

**No production calls to test-only assertions verified**  
**Status:** ✓ LOCKED

## Widget Boundary Invariants (Post-Compression)

### Widget Cannot Bypass Canonical Entries
**Rule:** Widget must call canonical entries for all outcome production.
**Verified post-compression:**
- Fold helpers private (cannot bypass)
- Outcome states internal (cannot construct)
- No alternate production paths

**Status:** ✓ LOCKED

### Widget Cannot Construct Outcome States
**Rule:** Widget receives results only; cannot manipulate outcomes.
**Verified:**
- No widget code references outcome state types
- Only canonical entries return TerminalPresentResult
- Type system enforces boundary

**Status:** ✓ LOCKED

## Integration Invariants (Post-Compression)

### Single Outcome-Producing Surface
**Rule:** Only canonical entries produce outcomes.
**Entry points:** 3 (refreshPresentEntry, reuseEligibilityEntry, directPresentEntry)  
**Call sites:** Verified 3 unique sites  
**Status:** ✓ LOCKED

### No Production Helpers Call Fold Helpers
**Rule:** Helper functions never call fold helpers.
**Verified:** All 8 helpers (eligibility, state, orchestration) don't call fold helpers  
**Status:** ✓ LOCKED

### Contract Coverage Post-Compression
**Rule:** Removing implementation assertions does not affect contract validation.
**Removed assertions:** All were implementation detail verification  
**Remaining contract assertion:** `refreshPresentEntry` outcome (preserved)  
**Status:** ✓ LOCKED

## Compression Impact Summary

| Invariant | Pre-Compression | Post-Compression | Status |
|-----------|-----------------|------------------|--------|
| No-bypass (refresh) | ✓ | ✓ | LOCKED |
| No-bypass (reuse) | ✓ | ✓ | LOCKED |
| No-bypass (direct) | ✓ | ✓ | LOCKED |
| Outcome parity | ✓ | ✓ | LOCKED |
| Test isolation | ✓ | ✓ | LOCKED |
| Widget boundary | ✓ | ✓ | LOCKED |

## Summary: All Invariants LOCKED (CZH-S58 Post-Compression)

**Assertion surface compressed:** 73% reduction (11 → 3)  
**Contract coverage maintained:** ✓ No contract assertions removed  
**No-bypass invariants:** ✓ All paths remain locked  
**Integration invariants:** ✓ All enforced post-compression  
**Test-only assertions:** ✓ Consolidated and isolated  

**Invariant system: COMPLETE and ENFORCED post-compression**

Contract authority: TERMINAL_SURFACE_CONTRACT.md (updated for assertion policy)  
Audit findings: CZH_S58_AUDIT.md  
Per-path compression: CZH_S58_*_COMPRESSION.md  
Shared trim: CZH_S58_SHARED_TRIM.md  
Invariants: This document (CZH_S58_INVARIANTS_FINAL.md)

**Status:** ✓ LOCKED — Compressed assertion surface with invariants verified

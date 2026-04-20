# CZH-1144: Reuse Path Sustained Enforcement

Date: 2026-04-20  
Scope: Consolidated baseline + enforcement for reuse path post-seal

## Reuse Path Surface (Locked by CZH-S59)

### Canonical Entry Point
- **Function:** `reuseEligibilityEntry(eligible, host_surface_target_available, shared_surface_attachment_ready, timing) → TerminalPresentResult` (line 182)
- **Scope:** Single canonical entry for reuse path, no alternate routes
- **Fold Helper:** `foldReuseOutcomeToPresent` is private `fn` (not `pub fn`)
- **Governance:** No secondary entry routes allowed

### Outcome Construction
- **Function:** `reuseSuccessOutcome()` (line 112)
- **Status:** Production essential, public (called by production + tests)
- **Governance:** No alternate success outcome construction allowed

### Eligibility Check
- **Function:** `checkReuseEligibility(input)` (line 506)
- **Status:** Production essential, public
- **Governance:** No alternate eligibility checking allowed

## Reuse Path No-Bypass Invariant

**Core Rule:** Widget reuse path flows through `reuseEligibilityEntry` only.

### Compile-Time Enforcement
- `foldReuseOutcomeToPresent` is `fn` not `pub fn`
- Cannot be called from widget code; type checker prevents bypass
- Status: ✓ ENFORCED

### Outcome State Isolation
- `ReusePresentOutcomeState` is internal structure never visible to widget
- Widget never constructs or manipulates outcomes directly
- Only canonical entry produces outcomes via `reuseSuccessOutcome()`
- Status: ✓ ENFORCED

### No Alternate Success Signal
- `reuseSuccessOutcome()` is only success outcome production path
- No alternate success state construction allowed
- Reuse path outcome always routed through canonical entry
- Status: ✓ ENFORCED

**No-bypass invariant locked:** ✓ VERIFIED

## Reuse Path Enforcement Layers (CZH-S61 Verified)

See TERMINAL_SURFACE_CONTRACT.md "Enforcement Layers" matrix for layer definitions.

**Per-Path Verification:**

- **Compile-Time:** ✓ `foldReuseOutcomeToPresent` private (line 170, type system enforces)
- **Runtime:** ✓ Outcome construction deterministic via `reuseSuccessOutcome()` (test: "success outcome invariants")
- **Test:** ✓ `assertReuseOutcomeConsistency()` (line 249) isolated; 3 binding tests verify invariants
- **Code Review:** ✓ Architect approval gates for canonical entry changes

## Reuse Path Regression Guards

- **No Alternate Fold Routing:** `foldReuseOutcomeToPresent` private; ✓ No alternate routing
- **Outcome Construction Single-Path:** `reuseSuccessOutcome()` only path; ✓ Verified
- **Test-Only Helper Isolation:** `assertReuseOutcomeConsistency()` test-only; ✓ No production calls
- **No Outcome State Mutation:** Direct flow eligibility → construction → fold → result; ✓ Verified
- **Transport Field Consistency:** Attachment fields constructed consistently; ✓ Deterministic
- **Eligibility Decision Immutability:** Decision determines outcome type directly; ✓ No re-evaluation

## Reuse Path Change Control

**What requires architect approval:**
- New canonical entry for reuse (prohibited)
- Changes to outcome type set (e.g., adding .deferred)
- New success outcome construction path
- Changes to eligibility check semantics
- Fold helper exposure (prohibited)

**What engineer can change (no approval needed):**
- Private helper implementation (internal only)
- Internal transport field computation (fields unchanged)
- Test-only assertions (new hardening allowed if isolated)
- Comments and documentation

## Sustained Enforcement Checklist

- ✓ Canonical entry locked (single route enforced)
- ✓ Fold helper private (no external calls possible)
- ✓ Outcome state internal (widget cannot construct)
- ✓ Success outcome construction single-path (only `reuseSuccessOutcome`)
- ✓ Eligibility check locked (no alternate eligibility paths)
- ✓ Test surface isolated (test assertions not called from production)
- ✓ No outcome mutation possible (direct flow to result)
- ✓ Transport deterministic (no conditional fields)
- ✓ Eligibility decision immutable (no re-evaluation)
- ✓ Compile-time enforcement (type system)
- ✓ Runtime enforcement (outcome construction)
- ✓ Test enforcement (coverage)
- ✓ Code review enforcement (architecture gates)

**Reuse path sustained enforcement:** ✓ COMPLETE AND LOCKED

Status: Ready for integration with CZH-1145+ direct/shared simplifications

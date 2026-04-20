# CZH-1145: Direct Path Sustained Enforcement

Date: 2026-04-20  
Scope: Consolidated baseline + enforcement for direct path post-seal

## Direct Path Surface (Locked by CZH-S59)

### Canonical Entry Point
- **Function:** `directPresentEntry(updated, timing) → TerminalPresentResult` (line 229)
- **Scope:** Single canonical entry for direct path, no alternate routes
- **Fold Helper:** `foldDirectOutcomeToPresent` is private `fn` (not `pub fn`)
- **Governance:** No secondary entry routes allowed

### Outcome Classification
- **Function:** `classifyDirectPresentOutcome(updated)` (line 103)
- **Status:** Public (used by production + tests)
- **Contract:** Outcome types frozen (2 states: .updated_and_presented | .presented)

### Eligibility Check
- **Function:** `checkDirectPresentEligibility(input)` (line 523)
- **Status:** Production essential, public
- **Governance:** No alternate eligibility checking allowed

## Direct Path No-Bypass Invariant

**Core Rule:** Widget direct path flows through `directPresentEntry` only.

### Compile-Time Enforcement
- `foldDirectOutcomeToPresent` is `fn` not `pub fn`
- Cannot be called from widget code; type checker prevents bypass
- Status: ✓ ENFORCED

### Outcome State Isolation
- `DirectPresentOutcomeState` is internal structure never visible to widget
- Widget never constructs or manipulates outcomes directly
- Only canonical entry produces outcomes via `classifyDirectPresentOutcome()`
- Status: ✓ ENFORCED

### No Alternate Classification
- `classifyDirectPresentOutcome` is only outcome classification path
- No alternate classification functions exist
- Widget uses this via canonical entry only
- Status: ✓ ENFORCED

**No-bypass invariant locked:** ✓ VERIFIED

## Direct Path Enforcement Layers (CZH-S61 Verified)

See TERMINAL_SURFACE_CONTRACT.md "Enforcement Layers" matrix for layer definitions.

**Per-Path Verification:**

- **Compile-Time:** ✓ `foldDirectOutcomeToPresent` private (line 220, type system enforces)
- **Runtime:** ✓ All 3 transport fields deterministically set (test: "classification pure", "folding uses canonical helper")
- **Test:** ✓ Classification verified via `classifyDirectPresentOutcome()`; deterministic flow
- **Code Review:** ✓ Architect approval gates for canonical entry changes

## Direct Path Regression Guards

- **No Alternate Fold Routing:** `foldDirectOutcomeToPresent` private; ✓ No alternate routing
- **Outcome Field Guarantees:** All 3 fields guaranteed (cache=true, host=true, attach=false); ✓ Verified
- **Classification Helper Safe:** Test-only usage; ✓ No production logic dependency
- **No Outcome State Mutation:** Direct flow classify → fold → result; ✓ Verified
- **Updated Flag Determinism:** Classification depends only on `updated` boolean; ✓ Deterministic
- **Transport Field Construction:** All three fields always assigned; ✓ No conditional logic

## Direct Path Change Control

**What requires architect approval:**
- New canonical entry for direct (prohibited)
- Changes to field guarantees (cache, host target, attachment)
- Changes to outcome type set (e.g., adding .deferred)
- Changes to updated flag interpretation
- Changes to result field set in TerminalPresentResult
- Fold helper exposure (prohibited)

**What engineer can change (no approval needed):**
- Private helper implementation (internal only)
- Internal transport field computation (guarantees maintained)
- Test-only assertions (new hardening allowed if isolated)
- Comments and documentation

## Sustained Enforcement Checklist

- ✓ Canonical entry locked (single route enforced)
- ✓ Fold helper private (no external calls possible)
- ✓ Outcome state internal (widget cannot construct)
- ✓ No alternate classification (only path established)
- ✓ Field guarantees maintained (all 3 fields always correct)
- ✓ Updated flag determinism (classification depends only on boolean)
- ✓ No outcome mutation possible (direct flow to result)
- ✓ Transport deterministic (no conditional fields)
- ✓ Eligibility check locked (no alternate eligibility paths)
- ✓ Compile-time enforcement (type system)
- ✓ Runtime enforcement (field guarantees)
- ✓ Test enforcement (coverage)
- ✓ Code review enforcement (architecture gates)

**Direct path sustained enforcement:** ✓ COMPLETE AND LOCKED

Status: Ready for integration with CZH-1146 shared simplifications

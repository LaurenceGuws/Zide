# CZH-1144: Reuse Path Sustained Enforcement (CZH-S68 Determinism Hardened)

Date: 2026-04-20 (Determinism hardening: 2026-04-21 — CZH-S68)  
Scope: Consolidated baseline + enforcement for reuse path; determinism format standardized per CZH-S68 criteria

## Reuse Path Surface (Locked by CZH-S59)

### Canonical Entry Point
- **Function:** `reuseEligibilityEntry(eligible, host_surface_target_available, shared_surface_attachment_ready, timing) → TerminalPresentResult` (presentation_runtime.zig:182)
- **Scope:** Single canonical entry for reuse path, no alternate routes
- **Fold Helper:** `foldReuseOutcomeToPresent[private]` (fn not pub fn)
- **Governance:** No secondary entry routes allowed

### Outcome Construction
- **Function:** `reuseSuccessOutcome()` (presentation_runtime.zig:112)
- **Status:** Production essential, public (called by production + tests)
- **Governance:** See TERMINAL_SURFACE_CONTRACT.md "Signal Definitions" for outcome type set

### Eligibility Check
- **Function:** `checkReuseEligibility(input)` (presentation_runtime.zig:506)
- **Status:** Production essential, public
- **Governance:** No alternate eligibility checking allowed

## Reuse Path Enforcement Claims (CZH-S68 Determinism Format)

Authority reference: TERMINAL_SURFACE_CONTRACT.md "Enforcement Claims Binding Reference"

**Reuse path contains 4 enforcement claims. All determinism criteria met per CZH-S68.**

### Claim 5: Eligibility Decision Immutability (Reuse Variant)

**Statement:** Reuse eligibility decision determines outcome type deterministically; no re-evaluation or mutation of outcome type after decision.

**Coverage:** See TERMINAL_SURFACE_CONTRACT.md "Coverage Evidence Consolidated Table" Claim 5 (Reuse: RT+Test, reuseSuccessOutcome():112).

---

### Claim 6: Outcome Type Freeze (Reuse Variant)

**Statement:** Reuse outcome type set is frozen at compile-time to `.reused | .skipped`.

**Coverage:** See TERMINAL_SURFACE_CONTRACT.md "Coverage Evidence Consolidated Table" Claim 6 (Reuse variant: .reused | .skipped, CT+Test).

---

### Claim 7: Transport Consistency (Reuse Variant)

**Statement:** Transport fields are consistent for both reused and non-reused paths.

**Coverage:** See TERMINAL_SURFACE_CONTRACT.md "Coverage Evidence Consolidated Table" Claim 7 (Reuse: RT+Test, reuseTransportFromOutcome()).

---

### Claim 8: Success Signal Uniqueness (Reuse Variant)

**Statement:** Only outcome type `.reused` signals reuse success; no alternate success indicators exist.

**Coverage:** See TERMINAL_SURFACE_CONTRACT.md "Coverage Evidence Consolidated Table" Claim 8 (Reuse: CT+Test, ReusePresentOutcomeState[enum_set]).

---

## Reuse Path Regression Guards

### Guard 1: No Alternate Fold Routing
- **Risk:** Widget code bypasses canonical entry via alternate fold path
- **Lock:** `foldReuseOutcomeToPresent[private]` (Claim 7)
- **Verification:** ✓ No alternate routing detected

### Guard 2: Eligibility Decision Immutability
- **Risk:** Outcome type re-evaluated after eligibility decision
- **Lock:** `reuseSuccessOutcome()` determinism (Claim 5)
- **Verification:** ✓ No re-evaluation paths exist

### Guard 3: Outcome Type Uniqueness
- **Risk:** Additional outcome types added, breaking signal uniqueness
- **Lock:** `ReusePresentOutcomeState[enum_frozen]` (Claims 6, 8)
- **Verification:** ✓ Enum set locked

### Guard 4: Test-Only Helper Isolation
- **Risk:** Test assertions called from production code
- **Lock:** `assertReuseOutcomeConsistency()[internal]` (test-only)
- **Verification:** ✓ No production calls to assertion helpers

### Guard 5: Transport Consistency Across Paths
- **Risk:** Reused and non-reused outcomes have inconsistent fields
- **Lock:** `reuseTransportFromOutcome()` logic (Claim 7)
- **Verification:** ✓ Both paths preserve required fields

### Guard 6: No Outcome State Mutation
- **Risk:** Outcome state modified after construction
- **Lock:** Type privacy + direct flow eligibility → construction → fold (Claim 5)
- **Verification:** ✓ Outcome immutable after construction

## Reuse Path Change Control

**What requires architect approval:**
- New canonical entry for reuse (prohibited per Claim 5)
- Changes to outcome type set (Claim 6 freeze)
- New success outcome construction path (Claim 5)
- Changes to eligibility check semantics (Claim 5)
- Fold helper exposure (prohibited)

**What engineer can change (no approval needed):**
- Private helper implementation (internal only)
- Internal transport field computation (fields unchanged, Claim 7)
- Test-only assertions (new hardening allowed if isolated)
- Comments and documentation

## Sustained Enforcement Checklist

- ✓ Canonical entry locked (single route enforced)
- ✓ Fold helper private (Claim 7: no external calls possible)
- ✓ Outcome state internal (widget cannot construct)
- ✓ Eligibility decision immutable (Claim 5: no re-evaluation)
- ✓ Outcome type frozen (Claims 6, 8: enum set immutable)
- ✓ Success signal unique (Claim 8: only .reused indicates success)
- ✓ Transport consistent (Claim 7: both paths preserve fields)
- ✓ Test surface isolated (all claims: test helpers not called from production)
- ✓ No outcome mutation possible (direct flow to result)
- ✓ Compile-time enforcement (Claims 6, 8: type system)
- ✓ Runtime enforcement (Claims 5, 7: outcome construction and mapping)
- ✓ Test enforcement (all 4 claims: coverage)
- ✓ Code review enforcement (architecture gates for sealed boundaries)

**Reuse path sustained enforcement:** ✓ COMPLETE AND LOCKED
**Determinism format:** ✓ APPLIED (4/4 claims standardized per CZH-S68)
**Cross-references:** ✓ COMPLETE (all claims map to TERMINAL_SURFACE_CONTRACT authority)

## Reuse Path Drift-Guard Summary (CZH-S69)

All 8 drift-guard standards (per TERMINAL_SURFACE_CONTRACT.md "Drift-Guard Reference Table") apply to reuse claims.

**Path-specific drift-guard notes:**
- **Guard 5 (Cross-Path):** Outcome type freeze (Claim 6: .reused | .skipped) and success signal uniqueness (Claim 8) are shared with refresh/direct paths; must maintain variant notation and relationship mappings
- **Guard 7 (Cross-Refs):** Reuse claims in shared lock mappings must be updated when shared claims change

**Maintenance gate:** Code review checklist (8 guards) required before any reuse claim addition/modification.

## Reuse Path Invariant-Lock Tightening (CZH-S72)

Per TERMINAL_SURFACE_CONTRACT.md "Invariant-Lock Tightening Requirements", the following gap categories apply to reuse:

**Gap 1: Outcome Type Assertions (ADDRESSED)**
- Status: ✓ Outcome types locked by `ReusePresentOutcomeState[enum_frozen]`
- Lock: Enum definition constrains outcomes to .reused | .skipped (Claim 6)
- Assertion: Type system prevents other values at compile time

**Gap 2: Field Guarantee Verification (ADDRESSED)**
- Status: ✓ Transport fields computed in both `.reused` and `.skipped` paths
- Lock: `reuseTransportFromOutcome()` maps both branches; all fields always present (Claim 7)
- Claim: Claim 7 (Transport Consistency) guarantees consistency across paths

**Gap 3: Eligibility-Classification Coupling (ADDRESSED)**
- Status: ✓ Outcome determined solely by eligibility decision
- Lock: `reuseSuccessOutcome()` construction depends only on eligibility input (Claim 5)
- Claim: Claim 5 (Eligibility Decision Immutability) ensures deterministic mapping

**Gap 4: Attachment State Single-Path (NOT APPLICABLE)**
- Applies to: Shared path only (Claim 13)
- Reuse: Uses canonical bridge path for attachment state

**Gap 5: Transport Routing Verification (ADDRESSED)**
- Status: ✓ All transports route through `foldReuseOutcomeToPresent[private]`
- Lock: Fold helper is private; type system prevents bypass
- Claim: Claim 7 (Transport Consistency) enforced by routing lock

**Gap 6: Outcome Immutability (ADDRESSED)**
- Status: ✓ Outcome state internal; widget cannot construct
- Lock: `ReusePresentOutcomeState[internal]` not exported
- Claim: Outcome immutable after construction (direct flow)

**Invariant-Lock Coverage:** 5 of 6 gaps apply to reuse; all 5 are locked
- Type-system locks: Gaps 1, 3, 5, 6
- Determinism lock: Gap 2

**Maintenance contract:** Invariant locks remain locked across future modifications to Claims 5-8.

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

**Lock Specification (Determinism Format):**
| Layer | Artifact | Detail |
|-------|----------|--------|
| Runtime | `reuseSuccessOutcome():112` | Outcome constructed deterministically from eligibility decision only; no alternate paths |
| Test | test_presentation_runtime.zig:41-47 | "Reuse success outcome invariants hold" validates deterministic construction |

**Enforcement verification:** ✓ VERIFIED
- Runtime: Outcome construction logic determined solely by eligibility input (no re-evaluation)
- Test: Invariant test confirms decision-determines-outcome property
- Code-review: Outcome construction changes require review

**Ambiguity status:** ✓ NONE (2/4 layers: RT+Test)

---

### Claim 6: Outcome Type Freeze (Reuse Variant)

**Statement:** Reuse outcome type set is frozen at compile-time to `.reused | .skipped`.

**Lock Specification (Determinism Format):**
| Layer | Artifact | Detail |
|-------|----------|--------|
| Compile-time | `ReusePresentOutcomeState[enum_frozen]` | Zig enum type definition (outcome variant set immutable) |
| Test | test_presentation_runtime.zig (outcome type tests) | Outcome type tests validate only .reused and .skipped produced |

**Enforcement verification:** ✓ VERIFIED
- Compile-time: Enum definition locked by type system
- Test: Type tests confirm only valid variants produced
- Code-review: Type changes require architect approval

**Ambiguity status:** ✓ NONE (2/4 layers: CT+Test)

---

### Claim 7: Transport Consistency (Reuse Variant)

**Statement:** Transport fields (cache_state_advanced, host_surface_target_available, shared_surface_attachment_ready) are consistent for both reused and non-reused paths.

**Lock Specification (Determinism Format):**
| Layer | Artifact | Detail |
|-------|----------|--------|
| Runtime | `reuseTransportFromOutcome()` | Transport mapping logic for both .reused and .skipped outcomes; all paths preserve required fields |
| Test | test_presentation_runtime.zig | "Reuse fold helper preserves non-reused transport" + boundary test validates both paths |

**Enforcement verification:** ✓ VERIFIED
- Runtime: Transport mapping deterministic per outcome type (both paths covered)
- Test: Boundary test confirms consistency across both branches
- Code-review: Transport mapping changes require review

**Ambiguity status:** ✓ NONE (2/4 layers: RT+Test)

---

### Claim 8: Success Signal Uniqueness (Reuse Variant)

**Statement:** Only outcome type `.reused` signals reuse success; no alternate success indicators exist.

**Lock Specification (Determinism Format):**
| Layer | Artifact | Detail |
|-------|----------|--------|
| Compile-time | `ReusePresentOutcomeState[enum_set]` | Outcome type enum constrains outcomes to exactly .reused (success) and .skipped (not success) |
| Test | test_presentation_runtime.zig:41-47 | "Reuse success outcome invariants" validates success signal uniqueness |

**Enforcement verification:** ✓ VERIFIED
- Compile-time: Type enum prevents additional success signals
- Test: Invariant test confirms .reused is only success path
- Code-review: Outcome type additions prohibited without architect approval

**Ambiguity status:** ✓ NONE (2/4 layers: CT+Test)

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

Status: Ready for CZH-1193 (direct determinism rewrite)

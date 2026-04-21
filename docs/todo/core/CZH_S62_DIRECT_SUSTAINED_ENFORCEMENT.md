# CZH-1145: Direct Path Sustained Enforcement (CZH-S68 Determinism Hardened)

Date: 2026-04-20 (Determinism hardening: 2026-04-21 — CZH-S68)  
Scope: Consolidated baseline + enforcement for direct path; determinism format standardized per CZH-S68 criteria

## Direct Path Surface (Locked by CZH-S59)

### Canonical Entry Point
- **Function:** `directPresentEntry(updated, timing) → TerminalPresentResult` (presentation_runtime.zig:229)
- **Scope:** Single canonical entry for direct path, no alternate routes
- **Fold Helper:** `foldDirectOutcomeToPresent[private]` (fn not pub fn)
- **Governance:** No secondary entry routes allowed

### Outcome Classification
- **Function:** `classifyDirectPresentOutcome(updated)` (presentation_runtime.zig:103)
- **Status:** Public (used by production + tests)
- **Contract:** See TERMINAL_SURFACE_CONTRACT.md "Signal Definitions" for outcome type set

### Eligibility Check
- **Function:** `checkDirectPresentEligibility(input)` (presentation_runtime.zig:523)
- **Status:** Production essential, public
- **Governance:** No alternate eligibility checking allowed

## Direct Path Enforcement Claims (CZH-S68 Determinism Format)

Authority reference: TERMINAL_SURFACE_CONTRACT.md "Enforcement Claims Binding Reference"

**Direct path contains 3 enforcement claims. All determinism criteria met per CZH-S68.**

### Claim 9: Updated Flag Determinism (Direct Variant)

**Statement:** Outcome classification depends only on the `updated` boolean flag; no other state influences the classification.

**Lock Specification (Determinism Format):**
| Layer | Artifact | Detail |
|-------|----------|--------|
| Runtime | `classifyDirectPresentOutcome():103-115` | Pure function classification logic depends only on updated parameter |
| Test | test_presentation_runtime.zig:30-39 | "Direct present outcome classification is pure" validates determinism |

**Enforcement verification:** ✓ VERIFIED
- Runtime: Classification function is pure (no state dependence)
- Test: Purity test confirms classification determinism
- Code-review: Logic changes must maintain purity property

**Ambiguity status:** ✓ NONE (2/4 layers: RT+Test)

---

### Claim 10: Field Guarantees (Direct Variant)

**Statement:** Result fields `cache_state_advanced` (always true), `host_surface_target_available` (always true), `shared_surface_attachment_ready` (always false for direct path) are guaranteed to be present and correct in all outcomes.

**Lock Specification (Determinism Format):**
| Layer | Artifact | Detail |
|-------|----------|--------|
| Compile-time | `TerminalPresentResult[field_set]` | Result struct requires all 3 fields by type definition |
| Runtime | `directTransportFromUpdated():140-165` | Field assignment logic deterministically computes all fields based on updated flag |
| Test | test_presentation_runtime.zig:80-93 | "field preservation test validates all three" confirms field guarantees |

**Enforcement verification:** ✓ VERIFIED
- Compile-time: Struct type requires all fields (compile error if missing)
- Runtime: Transport mapping deterministically sets all fields with correct values
- Test: Field preservation test validates all 3 fields present and correct
- Code-review: Field mapping changes require validation

**Ambiguity status:** ✓ NONE (3/4 layers: CT+RT+Test)

---

### Claim 11: Outcome Type Freeze (Direct Variant)

**Statement:** Direct outcome type set is frozen at compile-time to `.updated_and_presented | .presented`.

**Lock Specification (Determinism Format):**
| Layer | Artifact | Detail |
|-------|----------|--------|
| Compile-time | `DirectPresentOutcomeState[enum_frozen]` | Zig enum type definition (outcome variant set immutable) |
| Test | test_presentation_runtime.zig:30-39 | "Direct present outcome classification is pure" validates outcome types |

**Enforcement verification:** ✓ VERIFIED
- Compile-time: Enum definition locked by type system
- Test: Classification test confirms only valid types produced
- Code-review: Type changes require architect approval

**Ambiguity status:** ✓ NONE (2/4 layers: CT+Test)

---

## Direct Path Regression Guards

### Guard 1: No Alternate Fold Routing
- **Risk:** Widget code bypasses canonical entry via alternate fold path
- **Lock:** `foldDirectOutcomeToPresent[private]` (implicit from Claims 9-11)
- **Verification:** ✓ No alternate routing detected

### Guard 2: Updated Flag Determinism
- **Risk:** Classification depends on state other than updated flag
- **Lock:** `classifyDirectPresentOutcome()` purity (Claim 9)
- **Verification:** ✓ Pure function verified

### Guard 3: Field Guarantees Maintained
- **Risk:** Some fields not computed or computed incorrectly
- **Lock:** `TerminalPresentResult[field_set]` + `directTransportFromUpdated()` (Claim 10)
- **Verification:** ✓ All fields always computed; values guaranteed correct

### Guard 4: Outcome Type Uniqueness
- **Risk:** Additional outcome types added, breaking field guarantees
- **Lock:** `DirectPresentOutcomeState[enum_frozen]` (Claim 11)
- **Verification:** ✓ Enum set locked

### Guard 5: No Outcome State Mutation
- **Risk:** Outcome state modified after classification
- **Lock:** Type privacy + direct flow classify → fold → result (all claims)
- **Verification:** ✓ Outcome immutable after classification

### Guard 6: Eligibility Check Independence
- **Risk:** Eligibility check results influence outcome type
- **Lock:** Outcome classification depends only on updated flag (Claim 9)
- **Verification:** ✓ No coupling to eligibility check logic

## Direct Path Change Control

**What requires architect approval:**
- New canonical entry for direct (prohibited)
- Changes to field guarantees (Claim 10 guarantees)
- Changes to outcome type set (Claim 11 freeze)
- Changes to updated flag interpretation (Claim 9)
- Changes to result field set in TerminalPresentResult
- Fold helper exposure (prohibited)

**What engineer can change (no approval needed):**
- Private helper implementation (internal only)
- Internal transport field computation (guarantees maintained, Claim 10)
- Test-only assertions (new hardening allowed if isolated)
- Comments and documentation

## Sustained Enforcement Checklist

- ✓ Canonical entry locked (single route enforced)
- ✓ Fold helper private (no external calls possible)
- ✓ Outcome state internal (widget cannot construct)
- ✓ Classification pure (Claim 9: depends only on updated flag)
- ✓ Field guarantees maintained (Claim 10: all 3 fields guaranteed)
- ✓ Outcome type frozen (Claim 11: enum set immutable)
- ✓ No outcome mutation possible (direct flow to result)
- ✓ Transport deterministic (Claim 10: all fields always computed)
- ✓ Eligibility check independent (Claim 9: outcome not coupled to eligibility)
- ✓ Compile-time enforcement (Claim 10, 11: type system)
- ✓ Runtime enforcement (Claims 9, 10: pure function + field logic)
- ✓ Test enforcement (all 3 claims: coverage)
- ✓ Code review enforcement (architecture gates for sealed boundaries)

**Direct path sustained enforcement:** ✓ COMPLETE AND LOCKED
**Determinism format:** ✓ APPLIED (3/3 claims standardized per CZH-S68)
**Cross-references:** ✓ COMPLETE (all claims map to TERMINAL_SURFACE_CONTRACT authority)

## Direct Path Drift-Guard Summary (CZH-S69)

All 8 drift-guard standards (per TERMINAL_SURFACE_CONTRACT.md "Drift-Guard Reference Table") apply to direct claims.

**Path-specific drift-guard notes:**
- **Guard 5 (Cross-Path):** Outcome type freeze (Claim 11: .updated_and_presented | .presented) shared with refresh/reuse paths; field guarantees (Claim 10) also shared across paths
- **Guard 7 (Cross-Refs):** Direct claims in shared lock mappings must be updated when shared claims change

**Maintenance gate:** Code review checklist (8 guards) required before any direct claim addition/modification.

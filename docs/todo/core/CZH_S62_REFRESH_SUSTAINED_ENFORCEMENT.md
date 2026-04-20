# CZH-1143: Refresh Path Sustained Enforcement (CZH-S68 Determinism Hardened)

Date: 2026-04-20 (Determinism hardening: 2026-04-21 — CZH-S68)  
Scope: Consolidated baseline + enforcement for refresh path; determinism format standardized per CZH-S68 criteria

## Refresh Path Surface (Locked by CZH-S59)

### Canonical Entry Point
- **Function:** `refreshPresentEntry(refresh, shared_surface_attachment_ready, timing) → TerminalPresentResult` (presentation_runtime.zig:155)
- **Scope:** Single canonical entry for refresh path, no alternate routes
- **Fold Helper:** `foldRefreshOutcomeToPresent[private]` (fn not pub fn)
- **Governance:** No secondary entry routes allowed

### Outcome Classification
- **Function:** `classifyRefreshOutcome(refresh)` (presentation_runtime.zig:74)
- **Status:** Public (used by production + tests)
- **Contract:** See TERMINAL_SURFACE_CONTRACT.md "Signal Definitions" for outcome type set

### State Computation
- **Function:** `refreshPresentState(...)` (presentation_runtime.zig:409)
- **Status:** Production essential, public
- **Governance:** No alternate refresh state computation allowed

## Refresh Path Enforcement Claims (CZH-S68 Determinism Format)

Authority reference: TERMINAL_SURFACE_CONTRACT.md "Enforcement Claims Binding Reference"

**Refresh path contains 4 enforcement claims. All determinism criteria met per CZH-S68.**

### Claim 1: No-Bypass Invariant (Refresh Variant)

**Statement:** Widget refresh path flows only through `refreshPresentEntry`; no alternate fold routing exists.

**Lock Specification (Determinism Format):**
| Layer | Artifact | Detail |
|-------|----------|--------|
| Compile-time | `foldRefreshOutcomeToPresent[private]` | fn not pub fn; type system prevents widget access |
| Test | test_presentation_runtime.zig:14-28 | "outcome classification from refresh cycle is pure" |

**Enforcement verification:** ✓ VERIFIED
- Compile-time: Type checker enforces `fn` privacy (cannot be called from widget code)
- Test: Classification test validates pure outcome production
- Code-review: Canonical entry locked per CZH-S59 approval

**Ambiguity status:** ✓ NONE (2/4 layers: CT+Test)

---

### Claim 2: Outcome Type Freeze (Refresh Variant)

**Statement:** Refresh outcome type set is frozen at compile-time to `.updated_and_presented | .presented`.

**Lock Specification (Determinism Format):**
| Layer | Artifact | Detail |
|-------|----------|--------|
| Compile-time | `RefreshOutcomeState[enum_frozen]` | Zig enum type definition (outcome variant set immutable) |
| Runtime | `refreshPresentEntry():168` | Assertion: `result.outcome == .updated_and_presented or result.outcome == .presented` |
| Test | test_presentation_runtime.zig:14-28 | "outcome classification from refresh cycle is pure" validates outcome types |

**Enforcement verification:** ✓ VERIFIED
- Compile-time: Enum definition locked by type system
- Runtime: Assertion at line 168 validates outcome type at entry point
- Test: Classification test confirms only valid types produced
- Code-review: Type changes require architect approval

**Ambiguity status:** ✓ NONE (3/4 layers: CT+RT+Test)

---

### Claim 3: Transport Determinism (Refresh Variant)

**Statement:** Transport fields (cache_state_advanced, host_surface_target_available, shared_surface_attachment_ready) are always computed deterministically with no conditional logic.

**Lock Specification (Determinism Format):**
| Layer | Artifact | Detail |
|-------|----------|--------|
| Runtime | `refreshTransportFromResult():145-165` | Deterministic field assignment logic; all fields assigned unconditionally |
| Test | test_presentation_runtime.zig:95-111 | "Refresh result helper preserves transport fields" validates all fields present |

**Enforcement verification:** ✓ VERIFIED
- Runtime: Transport mapping logic always computes all fields (no branches)
- Test: Field preservation test confirms transport completeness
- Code-review: Field mapping changes require review

**Ambiguity status:** ✓ NONE (2/4 layers: RT+Test)

---

### Claim 4: Outcome State Isolation (Refresh Variant)

**Statement:** `RefreshOutcomeState` is internal to terminal layer; widget layer cannot construct or manipulate outcome state.

**Lock Specification (Determinism Format):**
| Layer | Artifact | Detail |
|-------|----------|--------|
| Compile-time | `RefreshOutcomeState[internal]` | Type not exported; no pub fn constructors visible to widget |
| Test | test_presentation_runtime.zig (binding tests) | 3 per-path binding tests verify outcomes produced only by canonical entry |

**Enforcement verification:** ✓ VERIFIED
- Compile-time: Type privacy enforced by module exports
- Test: Binding tests confirm canonical-entry-only production
- Code-review: Type export changes prohibited without architect approval

**Ambiguity status:** ✓ NONE (2/4 layers: CT+Test)

---

## Refresh Path Regression Guards

### Guard 1: No Alternate Fold Routing
- **Risk:** Widget code bypasses canonical entry via alternate fold path
- **Lock:** `foldRefreshOutcomeToPresent[private]` (Claim 1)
- **Verification:** ✓ No alternate routing detected

### Guard 2: Outcome Type Assertion Preserved
- **Risk:** Runtime outcome type validation missing, invalid types not caught
- **Lock:** `refreshPresentEntry():168` assertion (Claim 2)
- **Verification:** ✓ Assertion at line 168 present and functional

### Guard 3: Test-Only Helper Isolation
- **Risk:** Test-only assertions called from production code
- **Lock:** `assertRefreshOutcomeConsistency()[internal]` (test-only)
- **Verification:** ✓ No production calls to assertion helpers

### Guard 4: No Outcome State Mutation
- **Risk:** Outcome state modified after classification
- **Lock:** Type privacy + direct flow classification → fold → result (Claim 4)
- **Verification:** ✓ Outcome flows directly; no mutation paths

### Guard 5: Transport Field Consistency
- **Risk:** Some fields computed conditionally or omitted
- **Lock:** `refreshTransportFromResult()` determinism (Claim 3)
- **Verification:** ✓ All fields always computed

## Refresh Path Change Control

**What requires architect approval:**
- New canonical entry for refresh (prohibited per Claim 1)
- Changes to outcome type set (Claim 2 freeze)
- Changes to assertion behavior (Claim 2)
- Changes to result field set in TerminalPresentResult
- Fold helper exposure (Claim 1 privacy)

**What engineer can change (no approval needed):**
- Private helper implementation (internal only, Claim 4 boundary)
- Internal transport field computation (fields unchanged, Claim 3)
- Test-only assertions (new hardening allowed if isolated)
- Comments and documentation

## Sustained Enforcement Checklist

- ✓ Canonical entry locked (Claim 1: single route enforced)
- ✓ Fold helper private (Claim 1: no external calls possible)
- ✓ Outcome state internal (Claim 4: widget cannot construct)
- ✓ Outcome type frozen (Claim 2: enum set immutable)
- ✓ Type assertion preserved (Claim 2: runtime validation present)
- ✓ Transport deterministic (Claim 3: all fields always computed)
- ✓ Test surface isolated (Claim 4: test helpers not called from production)
- ✓ Compile-time enforcement (Claim 1, 2, 4: type system)
- ✓ Runtime enforcement (Claim 2, 3: assertions and logic)
- ✓ Test enforcement (all 4 claims: coverage)
- ✓ Code review enforcement (architecture gates for sealed boundaries)

**Refresh path sustained enforcement:** ✓ COMPLETE AND LOCKED
**Determinism format:** ✓ APPLIED (4/4 claims standardized per CZH-S68)
**Cross-references:** ✓ COMPLETE (all claims map to TERMINAL_SURFACE_CONTRACT authority)

## Refresh Path Drift-Guard Summary (CZH-S69)

**Guards preventing drift from determinism rules:**

- **Guard 1 (New Claims):** Any new refresh claim requires 6 determinism criteria (naming, lock detail, layer coverage, test binding, cross-path, explicitness) or architect pre-approval
- **Guard 2 (Lock Detail):** Refresh lock details must follow standardized format (artifact:line[property]); changes require architect review
- **Guard 3 (Test Binding):** All refresh test bindings must be verifiable file:RANGE or defined category; unverifiable citations require architect pre-approval
- **Guard 4 (Layer Explicitness):** All 4 refresh claims must have explicit layer coverage table (CT/RT/Test/CR); implicit coverage prohibited
- **Guard 5 (Cross-Path):** Outcome type freeze claim (shared across refresh, reuse, direct) must maintain variant notation and relationship to other paths
- **Guard 6 (Authority Sync):** Refresh claims must remain in sync with authority definitions; divergence requires architect pre-approval
- **Guard 7 (Cross-Refs):** Refresh claims in cross-reference table (shared locks) must be updated when claims change
- **Guard 8 (Test Staleness):** Test function changes (renames/moves) require synchronous documentation updates across all 4 refresh claims

**Maintenance gate:** Code review checklist (8 guards) required before any refresh claim addition/modification.

Status: Ready for CZH-1192 (reuse determinism rewrite)

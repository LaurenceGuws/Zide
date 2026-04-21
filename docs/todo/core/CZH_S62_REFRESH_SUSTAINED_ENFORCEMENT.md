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

**Coverage:** See TERMINAL_SURFACE_CONTRACT.md "Coverage Evidence Consolidated Table" Claim 1 (Refresh: CT+Test, foldRefreshOutcomeToPresent[private]).

---

### Claim 2: Outcome Type Freeze (Refresh Variant)

**Statement:** Refresh outcome type set is frozen at compile-time to `.updated_and_presented | .presented`.

**Coverage:** See TERMINAL_SURFACE_CONTRACT.md "Coverage Evidence Consolidated Table" Claim 2 (Refresh variant: .updated_and_presented | .presented, CT+RT+Test).

---

### Claim 3: Transport Determinism (Refresh Variant)

**Statement:** Transport fields are always computed deterministically with no conditional logic.

**Coverage:** See TERMINAL_SURFACE_CONTRACT.md "Coverage Evidence Consolidated Table" Claim 3 (Refresh: RT+Test, refreshTransportFromResult():145-165).

---

### Claim 4: Outcome State Isolation (Refresh Variant)

**Statement:** `RefreshOutcomeState` is internal to terminal layer; widget layer cannot construct or manipulate outcome state.

**Coverage:** See TERMINAL_SURFACE_CONTRACT.md "Coverage Evidence Consolidated Table" Claim 4 (Refresh: CT+Test, RefreshOutcomeState[internal]).

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

All 8 drift-guard standards (per TERMINAL_SURFACE_CONTRACT.md "Drift-Guard Reference Table") apply to refresh claims.

**Path-specific drift-guard notes:**
- **Guard 5 (Cross-Path):** Outcome type freeze claim (Claim 2) shared across refresh, reuse, direct paths; must maintain variant notation (.updated_and_presented | .presented) and relationship to other outcome type freeze variants

**Maintenance gate:** Code review checklist (8 guards) required before any refresh claim addition/modification.

## Refresh Path Invariant-Lock Tightening (CZH-S72)

Per TERMINAL_SURFACE_CONTRACT.md "Invariant-Lock Tightening Requirements", the following gap categories apply to refresh:

**Gap 1: Outcome Type Assertions (ADDRESSED)**
- Status: ✓ Present at `refreshPresentEntry():168`
- Assertion: `result.outcome == .updated_and_presented or result.outcome == .presented`
- Lock: Outcome type set frozen (Claim 2) enforced by assertion at entry point

**Gap 2: Field Guarantee Verification (ADDRESSED)**
- Status: ✓ Fields computed deterministically in `refreshTransportFromResult():145-165`
- Lock: All 3 fields (cache_state_advanced, host_surface_target_available, shared_surface_attachment_ready) always assigned unconditionally
- Claim: Claim 3 (Transport Determinism) guarantees no conditional logic

**Gap 3: Eligibility Check Coupling (NOT APPLICABLE)**
- Applies to: Direct path only (Claim 9 purity)
- Refresh: No eligibility check in refresh path

**Gap 4: Attachment State Single-Path (NOT APPLICABLE)**
- Applies to: Shared path only (Claim 13)
- Refresh: Widget uses `readSharedSurfaceAttachmentReady()` from bridge (canonical path)

**Gap 5: Transport Routing Verification (ADDRESSED)**
- Status: ✓ All transports route through `foldRefreshOutcomeToPresent[private]`
- Lock: Fold helper is private (`fn` not `pub fn`); type system prevents alternate routes
- Claim: Claim 1 (No-Bypass Invariant) enforced by type privacy

**Gap 6: Outcome Immutability (ADDRESSED)**
- Status: ✓ Outcome state internal to terminal layer
- Lock: `RefreshOutcomeState[internal]` not exported; widget cannot construct
- Claim: Claim 4 (Outcome State Isolation) enforced by module exports

**Invariant-Lock Coverage:** 4 of 6 gaps apply to refresh; all 4 are locked (type-system or assertion)
- Type-system locks: Gaps 1, 5, 6
- Runtime assertion: Gap 2

**Maintenance contract:** Invariant locks remain locked across future modifications to Claims 1-4.

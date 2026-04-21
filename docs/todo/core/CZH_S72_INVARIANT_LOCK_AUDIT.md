# CZH-1221: Invariant-Lock Audit + Gap Map

Date: 2026-04-21  
Scope: Identify gaps in invariant locks around consolidated coverage evidence; map tightening opportunities per path.

## Invariant-Lock Concept

**What:** Runtime or compile-time invariants that enforce coverage claims cannot be violated without explicit assertion or type-system error.

**Why:** Drift-guards (CZH-S69) prevent documentation drift; invariant locks prevent runtime drift (code changes that would violate claims).

**Current state:** Regression guards document invariants (Guards 1-5 per path); but not all gaps have explicit locks.

## Regression Guards Current State (Per-Path)

### Refresh: 5 Guards
- Guard 1: No Alternate Fold Routing (`foldRefreshOutcomeToPresent[private]`)
- Guard 2: Outcome Type Assertion Preserved (`refreshPresentEntry():168` assertion)
- Guard 3: Test-Only Helper Isolation (`assertRefreshOutcomeConsistency[internal]`)
- Guard 4: No Outcome State Mutation (type privacy)
- Guard 5: Transport Field Consistency (`refreshTransportFromResult()` determinism)

### Reuse: 6 Guards
- Guard 1: No Alternate Fold Routing
- Guard 2: Eligibility Decision Immutability
- Guard 3: Outcome Type Uniqueness
- Guard 4: Test-Only Helper Isolation
- Guard 5: Transport Consistency Across Paths
- Guard 6: No Outcome State Mutation

### Direct: 6 Guards
- Guard 1: No Alternate Fold Routing
- Guard 2: Updated Flag Determinism
- Guard 3: Field Guarantees Maintained
- Guard 4: Outcome Type Uniqueness
- Guard 5: No Outcome State Mutation
- Guard 6: Eligibility Check Independence

### Shared: 5 Locks (different naming from per-path guards)
- Lock 1: Generic Fold Composition Privacy
- Lock 2: Attachment State Single-Path Computation
- Lock 3: Transport Routing Immutability
- Lock 4: No Shared Outcome Production
- Lock 5: State Computation Immutability

## Invariant-Lock Gap Analysis

### Gap 1: Outcome Type Assertion Coverage (All Paths)

**Current state:** Only refresh has explicit assertion at entry point (`refreshPresentEntry():168`)

**Gap:** Reuse, direct, shared don't have explicit runtime assertions validating outcome type constraints

**Risk:** Outcome type changes could be introduced without triggering assertions

**Tightening opportunity:**
- Add outcome type assertions to reuse/direct/shared entry points
- Assert outcome variants match expected set per path
- Make assertions explicit in code review (not implicit in enum)

---

### Gap 2: Field Guarantee Assertions (All Paths)

**Current state:** Direct path documents field guarantees (Claim 10); other paths don't explicitly verify all fields present

**Gap:** No runtime assertions checking all 3 transport fields (cache_state_advanced, host_surface_target_available, shared_surface_attachment_ready) are computed

**Tightening opportunity:**
- Add field presence assertions to all transport mapping functions
- Assert each field has expected value per claim
- Verify no conditional logic that could skip fields

---

### Gap 3: Eligibility Check Coupling (Direct Path)

**Current state:** Guard 6 (Eligibility Check Independence) documents that eligibility check doesn't influence outcome type

**Gap:** No assertion verifying classification depends only on `updated` flag (Claim 9 purity)

**Tightening opportunity:**
- Add assertion in `classifyDirectPresentOutcome` that output depends only on input parameter
- Or add test-only verification that purity invariant holds

---

### Gap 4: Single-Path Attachment Computation (Shared)

**Current state:** Lock 2 documents single-path computation via `computeHostSurfaceAttachmentState`

**Gap:** No assertion preventing widget code from re-deriving attachment state independently

**Tightening opportunity:**
- Add assertion in TerminalPresentationBridge that all attachment state reads go through canonical path
- Or mark re-derivation functions as internal/private

---

### Gap 5: Transport Routing Verification (All Paths)

**Current state:** Lock 3 (shared) documents all transports route through canonical folds

**Gap:** No runtime verification that transport fields are computed only through fold helpers, not independently

**Tightening opportunity:**
- Add assertion in result construction that transport fields have expected source
- Or make result construction private (only fold helpers can construct)

---

### Gap 6: No Outcome Mutation (All Paths)

**Current state:** Documented as direct flow (classify → fold → result)

**Gap:** Type system prevents construction, but no assertion preventing modification post-construction

**Tightening opportunity:**
- Result type could be const/immutable to prevent post-construction mutation
- Or add assertion in any code that modifies outcome state

---

## Invariant-Lock Tightening Map

| Gap | Path(s) | Current Lock | Proposed Tightening | Type |
|-----|---------|--------------|---------------------|------|
| 1 | All | Enum type system | Runtime assertions on entry | Assertion |
| 2 | All | Claim documentation | Runtime field presence checks | Assertion |
| 3 | Direct | Guard doc | Purity assertion or test | Assertion/Test |
| 4 | Shared | Lock documentation | Read-only/private enforcement | Type system |
| 5 | All | Lock documentation | Transport origin verification | Assertion |
| 6 | All | Type privacy | Const result type or mutation assert | Type system/Assertion |

## Tightening Scope for CZH-S72

### Phase 1: Authority Definition (CZH-1222)
- Define "Invariant-Lock Tightening Requirements"
- Specify which gaps are priority for tightening
- Document assertion patterns and where they should be added

### Phase 2: Per-Path Tightening (CZH-1223..1226)
For each path:
- Identify which gaps apply (1-6)
- Add assertions/locks (runtime or type-system)
- Verify no behavior change (behavior-neutral requirement)
- Update regression guards documentation

### Phase 3: Verification (CZH-1227)
- Verify all gaps covered
- Check assertions aren't skipped in any code path
- Ensure type-system locks are enforced

---

## Risk Assessment

**Risk 1: Assertions add overhead**
- Mitigation: Make assertions conditional on debug builds, or check only on entry points

**Risk 2: Type-system changes could affect other code**
- Mitigation: Narrow changes to specific functions; use local type definitions where possible

**Risk 3: Behavioral change**
- Mitigation: Requirement is behavior-neutral; any assertion should fire same way regardless of assertion presence

---

## Audit Conclusion

**Status:** ✓ AUDITED

**Findings:**
1. Regression guards document invariants but gaps exist in runtime enforcement
2. 6 main gaps identified: outcome type assertions, field guarantees, eligibility coupling, attachment computation, transport routing, outcome mutation
3. Tightening candidates: runtime assertions (Gaps 1,2,3,5) + type-system hardening (Gaps 4,6)
4. Scope for CZH-S72: Add explicit invariant locks per path without changing behavior
5. Priority: High (ensures runtime enforcement of documented invariants)

**Recommendation:** Proceed with three-phase tightening (CZH-1222..1227) to close all 6 gaps with explicit invariant locks.

**Next action:** CZH-1222 (Authority invariant-lock requirements)

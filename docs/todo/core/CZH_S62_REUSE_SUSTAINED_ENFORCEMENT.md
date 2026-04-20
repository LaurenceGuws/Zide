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

### 1. Compile-Time Enforcement (Type System)
- **Owner:** Zig type system + module visibility
- **Responsibility:** Prevent invalid function calls at compile time
- **Enforcement:** Private fold helper and outcome type isolation prevent bypass
- **Verification:** ✓ `foldReuseOutcomeToPresent` remains private (line 170)
- **Status:** ✓ LOCKED

### 2. Runtime Enforcement (Assertions)
- **Owner:** Production assertions in canonical entry
- **Responsibility:** Detect outcome construction violations
- **Enforcement:** Outcome constructed deterministically in `reuseEligibilityEntry` (line 182)
- **Check:** `reuseSuccessOutcome()` called per eligibility decision
- **Verification:** ✓ No assertion needed; construction logic guarantees outcome validity
- **Test Binding:** `test_presentation_runtime.zig:41-47` "Reuse success outcome invariants hold"
- **Status:** ✓ LOCKED

### 3. Test Enforcement (Test Coverage)
- **Owner:** Unit test suite (zig build test)
- **Responsibility:** Detect regression vectors in test execution
- **Enforcement:** Tests validate outcome consistency, field guarantees
- **Check:** `assertReuseOutcomeConsistency()` (line 249) isolated to tests
- **Verification:** ✓ No production calls to test helper detected
- **Test Binding:** `test_presentation_runtime.zig:131-152` "Reuse fold helper preserves non-reused transport"
- **Test Binding:** `test_presentation_runtime.zig:154-179` "Reuse boundary helper forwards reused/non-reused consistently"
- **Test Binding:** `test_presentation_runtime.zig:227-247` "Fold routes consume contracted transport carrier"
- **Status:** ✓ LOCKED

### 4. Code Review Enforcement (Architecture)
- **Owner:** Architect approval for contract-affecting changes
- **Responsibility:** Block new entry points, signature changes, exposure violations
- **Enforcement:** Eligibility decision immutable; all changes require architect approval
- **Check:** No re-evaluation of eligibility inside canonical entry
- **Verification:** ✓ Code review gates specified
- **Status:** ✓ LOCKED

## Reuse Path Regression Guards

### Guard 1: No Alternate Fold Routing
- **Risk:** Widget code bypasses canonical entry via alternate fold path
- **Enforcement:** `foldReuseOutcomeToPresent` private; code review + compile-time privacy
- **Verification:** ✓ No alternate routing detected

### Guard 2: Outcome Construction Single-Path
- **Risk:** New outcome construction helper added (e.g., `reuseSkippedOutcome()`)
- **Enforcement:** Code review + change control
- **Verification:** ✓ `reuseSuccessOutcome()` remains only construction path

### Guard 3: Test-Only Helper Isolation
- **Risk:** Production code calls `assertReuseOutcomeConsistency` for logic
- **Enforcement:** Code review + test coverage
- **Verification:** ✓ Test helper isolated; no production calls detected

### Guard 4: No Outcome State Mutation
- **Risk:** Widget or helper code modifies outcome state after production
- **Enforcement:** Code review + integration tests
- **Verification:** ✓ Outcome flows directly: eligibility → construction → fold → result

### Guard 5: Transport Field Consistency
- **Risk:** Transport field computation modified to bypass field guarantees
- **Enforcement:** Code review + invariant verification
- **Verification:** ✓ Transport fields deterministic (attachment fields constructed consistently)

### Guard 6: Eligibility Decision Immutability
- **Risk:** Eligibility check returns one result, but canonical entry re-checks differently
- **Enforcement:** Code review + outcome construction verification
- **Verification:** ✓ Eligibility decision determines outcome type (.reused | .skipped) directly

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

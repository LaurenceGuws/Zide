# CZH-1143: Refresh Path Sustained Enforcement

Date: 2026-04-20  
Scope: Consolidated baseline + enforcement for refresh path post-seal

## Refresh Path Surface (Locked by CZH-S59)

### Canonical Entry Point
- **Function:** `refreshPresentEntry(refresh, shared_surface_attachment_ready, timing) → TerminalPresentResult` (line 155)
- **Scope:** Single canonical entry for refresh path, no alternate routes
- **Fold Helper:** `foldRefreshOutcomeToPresent` is private `fn` (not `pub fn`)
- **Governance:** No secondary entry routes allowed

### Outcome Classification
- **Function:** `classifyRefreshOutcome(refresh)` (line 74)
- **Status:** Public (used by production + tests)
- **Contract:** Outcome types frozen (2 states: .updated_and_presented | .presented)

### State Computation
- **Function:** `refreshPresentState(...)` (line 409)
- **Status:** Production essential, public
- **Governance:** No alternate refresh state computation allowed

## Refresh Path No-Bypass Invariant

**Core Rule:** Widget refresh path flows through `refreshPresentEntry` only.

### Compile-Time Enforcement
- `foldRefreshOutcomeToPresent` is `fn` not `pub fn`
- Cannot be called from widget code; type checker prevents bypass
- Status: ✓ ENFORCED

### Outcome State Isolation
- `RefreshOutcomeState` is internal structure never visible to widget
- Widget never constructs or manipulates outcomes directly
- Only canonical entry produces outcomes
- Status: ✓ ENFORCED

### No Alternate Classification
- `classifyRefreshOutcome` is only outcome classification path
- No alternate classification functions exist
- Widget uses this via canonical entry only
- Status: ✓ ENFORCED

**No-bypass invariant locked:** ✓ VERIFIED

## Refresh Path Enforcement Layers (CZH-S61 Verified)

### 1. Compile-Time Enforcement (Type System)
- **Owner:** Zig type system + module visibility
- **Responsibility:** Prevent invalid function calls at compile time
- **Enforcement:** Private fold helper cannot be imported/called externally
- **Verification:** ✓ `foldRefreshOutcomeToPresent` remains private (line 143)
- **Status:** ✓ LOCKED

### 2. Runtime Enforcement (Assertions)
- **Owner:** Production assertions in canonical entry
- **Responsibility:** Detect outcome type violations
- **Enforcement:** Contract-critical assertion at canonical entry output (line 168)
- **Check:** `result.outcome == .updated_and_presented or result.outcome == .presented`
- **Verification:** ✓ Assertion preserved; validates outcome contract
- **Test Binding:** `test_presentation_runtime.zig:14-28` "outcome classification from refresh cycle is pure"
- **Status:** ✓ LOCKED

### 3. Test Enforcement (Test Coverage)
- **Owner:** Unit test suite (zig build test)
- **Responsibility:** Detect regression vectors in test execution
- **Enforcement:** Tests validate no-bypass invariants, test-only isolation
- **Check:** `assertRefreshOutcomeConsistency()` (line 259) isolated to tests
- **Verification:** ✓ No production calls to test helper detected
- **Test Binding:** `test_presentation_runtime.zig:64-78` "Refresh classification carries inline conjunction"
- **Test Binding:** `test_presentation_runtime.zig:95-111` "Refresh result helper preserves transport fields"
- **Test Binding:** `test_presentation_runtime.zig:113-129` "Refresh result helper preserves followup fields"
- **Status:** ✓ LOCKED

### 4. Code Review Enforcement (Architecture)
- **Owner:** Architect approval for contract-affecting changes
- **Responsibility:** Block new entry points, signature changes, exposure violations
- **Enforcement:** All changes touching canonical entry require architect approval
- **Verification:** ✓ Code review gates specified
- **Status:** ✓ LOCKED

## Refresh Path Regression Guards

### Guard 1: No Alternate Fold Routing
- **Risk:** Widget code bypasses canonical entry via alternate fold path
- **Enforcement:** `foldRefreshOutcomeToPresent` private; code review + compile-time privacy
- **Verification:** ✓ No alternate routing detected

### Guard 2: Outcome Type Assertion Preserved
- **Risk:** Outcome type assertion removed, losing contract validation
- **Enforcement:** Assertion surface governance (architect approval required)
- **Verification:** ✓ Assertion at line 168 present and functional

### Guard 3: Test-Only Helper Isolation
- **Risk:** Production code calls `assertRefreshOutcomeConsistency` for logic
- **Enforcement:** Code review + test coverage
- **Verification:** ✓ Test helper isolated; no production calls

### Guard 4: No Outcome State Mutation
- **Risk:** Widget or helper code modifies outcome state after production
- **Enforcement:** Code review + integration tests
- **Verification:** ✓ Outcome flows directly: classify → fold → result

### Guard 5: Transport Field Consistency
- **Risk:** Transport field computation modified to bypass field guarantees
- **Enforcement:** Code review + invariant verification
- **Verification:** ✓ Transport fields deterministic per outcome type

## Refresh Path Change Control

**What requires architect approval:**
- New canonical entry for refresh (prohibited)
- Changes to outcome type set (e.g., adding .deferred)
- Changes to assertion behavior
- Changes to result field set in TerminalPresentResult
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
- ✓ No alternate classification (only path established)
- ✓ Test surface isolated (test assertions not called from production)
- ✓ Outcome type assertion preserved (contract-critical check present)
- ✓ No outcome mutation possible (direct flow to result)
- ✓ Transport deterministic (no conditional fields)
- ✓ Compile-time enforcement (type system)
- ✓ Runtime enforcement (assertions)
- ✓ Test enforcement (coverage)
- ✓ Code review enforcement (architecture gates)

**Refresh path sustained enforcement:** ✓ COMPLETE AND LOCKED

Status: Ready for integration with CZH-1144+ reuse/direct/shared simplifications

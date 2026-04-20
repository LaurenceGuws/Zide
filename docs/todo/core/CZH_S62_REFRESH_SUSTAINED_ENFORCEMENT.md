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

See TERMINAL_SURFACE_CONTRACT.md "Enforcement Layers" matrix for layer definitions.

**Per-Path Verification:**

- **Compile-Time:** ✓ `foldRefreshOutcomeToPresent` private (line 143, type system enforces)
- **Runtime:** ✓ Outcome type assertion line 168 validates contract (test: "outcome classification pure")
- **Test:** ✓ `assertRefreshOutcomeConsistency()` (line 259) isolated; 3 binding tests verify invariants
- **Code Review:** ✓ Architect approval gates for canonical entry changes

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

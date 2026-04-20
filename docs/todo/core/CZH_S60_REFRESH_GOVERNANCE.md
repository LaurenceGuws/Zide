# CZH-1127: Refresh Path Governance Lock Baseline

Date: 2026-04-20  
Scope: Establish governance baseline for refresh path post-seal

## Refresh Path Governance Surface

### Canonical Entry Point (Locked)
- **Function:** `refreshPresentEntry(refresh, shared_surface_attachment_ready, timing)` (line 155)
- **Status:** Single canonical entry, no alternate routes
- **Privacy:** fold helper `foldRefreshOutcomeToPresent` is private
- **Governance:** No secondary entry routes allowed

### Outcome Classification (Locked)
- **Function:** `classifyRefreshOutcome(refresh)` (line 74)
- **Status:** Public (used by production + tests)
- **Governance:** Outcome types frozen (2 states: .updated_and_presented | .presented)

### State Computation (Locked)
- **Function:** `refreshPresentState(...)` (line 409)
- **Status:** Production essential, public
- **Governance:** No alternate refresh state computation allowed

## Refresh Path No-Bypass Invariant

**Rule:** Widget refresh path flows through `refreshPresentEntry` only.

**Enforcement Mechanisms:**

1. **Compile-Time Privacy**
   - `foldRefreshOutcomeToPresent` is `fn` not `pub fn`
   - Cannot be called from widget code
   - Type checker prevents bypass

2. **Outcome State Isolation**
   - `RefreshOutcomeState` is internal structure
   - Widget never constructs or manipulates outcomes
   - Only canonical entry produces outcomes

3. **No Alternate Classification**
   - `classifyRefreshOutcome` is the only outcome classification path
   - No alternate classification functions exist
   - Widget uses this via canonical entry only

**Verification Status:** ✓ NO-BYPASS INVARIANT LOCKED

## Refresh Path Regression Guards

### Guard 1: No Alternate Fold Routing
**Risk:** Widget code finds alternate path to fold outcome (hypothetical future code)
**Check:** 
- `foldRefreshOutcomeToPresent` remains private
- No intermediate fold composition functions added
- No outcome-to-result mapping outside canonical entry

**Enforcement:** Code review + compile-time privacy

### Guard 2: Outcome Type Assertion Preserved
**Risk:** Outcome type assertion removed, losing contract validation
**Check:**
- `refreshPresentEntry` line 168: `result.outcome == .updated_and_presented or result.outcome == .presented`
- Assertion remains present and functional
- No removal without architect approval

**Enforcement:** Assertion surface governance (requires architect approval)

### Guard 3: Test-Only Helper Isolation
**Risk:** Production code calls `assertRefreshOutcomeConsistency` for logic (not test hardening)
**Check:**
- `assertRefreshOutcomeConsistency` (line 259) remains test-only
- No production calls exist
- Located with other test helpers

**Enforcement:** Code review + test coverage

### Guard 4: No Outcome State Mutation
**Risk:** Widget or helper code modifies outcome state after production
**Check:**
- `RefreshOutcomeState` fields never modified post-production
- No intermediate storage of outcome state with mutations
- Outcome flows directly from classification to folding to result

**Enforcement:** Code review + integration tests

### Guard 5: Transport Field Consistency
**Risk:** `refreshTransportFromResult` modified to bypass field guarantees
**Check:**
- Transport field construction remains deterministic
- No conditional fields or branching transport logic
- All fields set consistently per outcome type

**Enforcement:** Code review + invariant verification

## Refresh Path Change Control

**What requires architect approval:**
- New canonical entry for refresh (prohibited)
- Changes to outcome type set (e.g., adding .deferred state)
- Changes to assertion behavior (even if asserting same condition)
- Changes to result field set in TerminalPresentResult

**What engineer can change:**
- Private helper implementation (internal only)
- Internal transport field computation (as long as fields unchanged)
- Test-only assertions (new hardening checks allowed if isolated)
- Comments and documentation

## Refresh Path Governance Checklist

- ✓ Canonical entry locked (single route enforced)
- ✓ Fold helper private (no external calls possible)
- ✓ Outcome state internal (widget cannot construct)
- ✓ No alternate classification (classifyRefreshOutcome is only path)
- ✓ Test surface isolated (test assertions not called from production)
- ✓ Outcome type assertion preserved (contract-critical check present)
- ✓ No outcome mutation possible (direct flow to result)
- ✓ Transport deterministic (no conditional fields)

**Refresh path governance:** ✓ LOCKED

Next: CZH-1128 reuse governance lock baseline

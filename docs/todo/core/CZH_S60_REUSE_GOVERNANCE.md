# CZH-1128: Reuse Path Governance Lock Baseline

Date: 2026-04-20  
Scope: Establish governance baseline for reuse path post-seal

## Reuse Path Governance Surface

### Canonical Entry Point (Locked)
- **Function:** `reuseEligibilityEntry(outcome, host_surface_target_available, shared_surface_attachment_ready, timing)` (line 182)
- **Status:** Single canonical entry, no alternate routes
- **Privacy:** fold helper `foldReuseOutcomeToPresent` is private
- **Governance:** No secondary entry routes allowed

### Outcome Construction (Locked)
- **Function:** `reuseSuccessOutcome()` (line 112)
- **Status:** Production essential, public (called by production + tests)
- **Governance:** No alternate success outcome construction allowed

### Eligibility Check (Locked)
- **Function:** `checkReuseEligibility(input)` (line 506)
- **Status:** Production essential, public
- **Governance:** No alternate eligibility checking allowed

## Reuse Path No-Bypass Invariant

**Rule:** Widget reuse path flows through `reuseEligibilityEntry` only.

**Enforcement Mechanisms:**

1. **Compile-Time Privacy**
   - `foldReuseOutcomeToPresent` is `fn` not `pub fn`
   - Cannot be called from widget code
   - Type checker prevents bypass

2. **Outcome State Isolation**
   - `ReusePresentOutcomeState` is internal structure
   - Widget never constructs or manipulates outcomes
   - Only canonical entry produces outcomes

3. **No Alternate Success Signal**
   - `reuseSuccessOutcome()` is only success outcome production
   - No alternate success state construction
   - Reuse path outcome always routed through canonical entry

**Verification Status:** ✓ NO-BYPASS INVARIANT LOCKED

## Reuse Path Regression Guards

### Guard 1: No Alternate Fold Routing
**Risk:** Widget code finds alternate path to fold outcome
**Check:**
- `foldReuseOutcomeToPresent` remains private
- No intermediate fold composition functions added
- No outcome-to-result mapping outside canonical entry

**Enforcement:** Code review + compile-time privacy

### Guard 2: Outcome Construction Single-Path
**Risk:** New outcome construction helper added (e.g., `reuseSkippedOutcome()`)
**Check:**
- `reuseSuccessOutcome()` remains only outcome construction path
- No alternate construction helpers added
- All reuse outcomes routed through canonical entry

**Enforcement:** Code review + change control

### Guard 3: Test-Only Helper Isolation
**Risk:** Production code calls `assertReuseOutcomeConsistency` for logic
**Check:**
- `assertReuseOutcomeConsistency` (line 249) remains test-only
- No production calls exist
- Located with other test helpers
- Called only from `foldReuseOutcomeToPresent` for hardening

**Enforcement:** Code review + test coverage

### Guard 4: No Outcome State Mutation
**Risk:** Widget or helper code modifies outcome state after production
**Check:**
- `ReusePresentOutcomeState` fields never modified post-production
- No intermediate storage of outcome state with mutations
- Outcome flows directly from eligibility decision through construction to folding to result

**Enforcement:** Code review + integration tests

### Guard 5: Transport Field Consistency
**Risk:** `reuseTransportFromOutcome` modified to bypass field guarantees
**Check:**
- Transport field construction remains deterministic
- All attachment fields (cache_state_advanced, host_surface_target_available, shared_surface_attachment_ready) constructed consistently
- No conditional transport branching

**Enforcement:** Code review + invariant verification

### Guard 6: Eligibility Decision Immutability
**Risk:** Eligibility check returns one result, but canonical entry re-checks and produces different outcome
**Check:**
- Eligibility decision (`eligible` parameter) determines outcome type (.reused | .skipped)
- No re-evaluation of eligibility inside canonical entry
- Direct outcome construction from eligibility input

**Enforcement:** Code review + outcome construction verification

## Reuse Path Change Control

**What requires architect approval:**
- New canonical entry for reuse (prohibited)
- Changes to outcome type set (e.g., adding .deferred state)
- Changes to assertion behavior (test hardening frozen)
- New success outcome construction path
- Changes to eligibility check semantics

**What engineer can change:**
- Private helper implementation (internal only)
- Internal transport field computation (as long as fields unchanged)
- Test-only assertions (new hardening checks allowed if isolated)
- Comments and documentation

## Reuse Path Governance Checklist

- ✓ Canonical entry locked (single route enforced)
- ✓ Fold helper private (no external calls possible)
- ✓ Outcome state internal (widget cannot construct)
- ✓ Success outcome construction single-path (reuseSuccessOutcome is only path)
- ✓ Eligibility check locked (no alternate eligibility paths)
- ✓ Test surface isolated (test assertions not called from production)
- ✓ No outcome mutation possible (direct flow to result)
- ✓ Transport deterministic (no conditional fields)
- ✓ Eligibility decision immutable (no re-evaluation)

**Reuse path governance:** ✓ LOCKED

Next: CZH-1129 direct governance lock baseline

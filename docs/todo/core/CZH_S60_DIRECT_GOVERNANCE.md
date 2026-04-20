# CZH-1129: Direct Path Governance Lock Baseline

Date: 2026-04-20  
Scope: Establish governance baseline for direct path post-seal

## Direct Path Governance Surface

### Canonical Entry Point (Locked)
- **Function:** `directPresentEntry(updated, timing)` (line 229)
- **Status:** Single canonical entry, no alternate routes
- **Privacy:** fold helper `foldDirectOutcomeToPresent` is private
- **Governance:** No secondary entry routes allowed

### Outcome Classification (Locked)
- **Function:** `classifyDirectPresentOutcome(updated)` (line 103)
- **Status:** Public (used by production + tests)
- **Governance:** Outcome types frozen (2 states: .updated_and_presented | .presented)

### Eligibility Check (Locked)
- **Function:** `checkDirectPresentEligibility(input)` (line 523)
- **Status:** Production essential, public
- **Governance:** No alternate eligibility checking allowed

## Direct Path No-Bypass Invariant

**Rule:** Widget direct path flows through `directPresentEntry` only.

**Enforcement Mechanisms:**

1. **Compile-Time Privacy**
   - `foldDirectOutcomeToPresent` is `fn` not `pub fn`
   - Cannot be called from widget code
   - Type checker prevents bypass

2. **Outcome State Isolation**
   - `DirectPresentOutcomeState` is internal structure
   - Widget never constructs or manipulates outcomes
   - Only canonical entry produces outcomes

3. **No Alternate Classification**
   - `classifyDirectPresentOutcome` is the only outcome classification path
   - No alternate classification functions exist
   - Widget uses this via canonical entry only

**Verification Status:** ✓ NO-BYPASS INVARIANT LOCKED

## Direct Path Regression Guards

### Guard 1: No Alternate Fold Routing
**Risk:** Widget code finds alternate path to fold outcome
**Check:**
- `foldDirectOutcomeToPresent` remains private
- No intermediate fold composition functions added
- No outcome-to-result mapping outside canonical entry

**Enforcement:** Code review + compile-time privacy

### Guard 2: Outcome Field Guarantees Maintained
**Risk:** Field guarantees removed or made conditional
**Check:**
- `cache_state_advanced`: always true (direct always advances cache)
- `host_surface_target_available`: always true (direct assumes available)
- `shared_surface_attachment_ready`: always false (direct pre-set to false)
- All fields guaranteed by `directTransportFromUpdated` logic
- No conditional field assignment

**Enforcement:** Code review + invariant verification

### Guard 3: Test-Only Helper Isolation
**Risk:** Production code calls classification helper for logic (not test analysis)
**Check:**
- `classifyDirectPresentOutcome` remains available for test analysis
- No test-only assertions in direct path (deterministic path)
- No new test assertions added without architect approval

**Enforcement:** Code review + test coverage

### Guard 4: No Outcome State Mutation
**Risk:** Widget or helper code modifies outcome state after production
**Check:**
- `DirectPresentOutcomeState` fields never modified post-production
- No intermediate storage of outcome state with mutations
- Outcome flows directly from classification to folding to result

**Enforcement:** Code review + integration tests

### Guard 5: Updated Flag Determinism
**Risk:** `updated` flag evaluation changed to use alternate data source
**Check:**
- Outcome classification depends only on `updated` boolean parameter
- No secondary data sources used for classification
- Classification logic remains deterministic

**Enforcement:** Code review + outcome classification verification

### Guard 6: Transport Field Construction
**Risk:** `directTransportFromUpdated` modified to make fields conditional
**Check:**
- All three transport fields always assigned (no conditional logic)
- Field values remain constant regardless of updated flag variation
- No branching transport construction

**Enforcement:** Code review + invariant verification

## Direct Path Change Control

**What requires architect approval:**
- New canonical entry for direct (prohibited)
- Changes to field guarantees (cache, host target, attachment)
- Changes to outcome type set (e.g., adding .deferred state)
- Changes to updated flag interpretation
- Changes to result field set in TerminalPresentResult

**What engineer can change:**
- Private helper implementation (internal only)
- Internal transport field computation (as long as guarantees maintained)
- Test-only assertions (new hardening checks allowed if isolated)
- Comments and documentation

## Direct Path Governance Checklist

- ✓ Canonical entry locked (single route enforced)
- ✓ Fold helper private (no external calls possible)
- ✓ Outcome state internal (widget cannot construct)
- ✓ No alternate classification (classifyDirectPresentOutcome is only path)
- ✓ Field guarantees maintained (all 3 fields always true/false as documented)
- ✓ Updated flag determinism (classification depends only on updated boolean)
- ✓ No outcome mutation possible (direct flow to result)
- ✓ Transport deterministic (no conditional fields)
- ✓ Eligibility check locked (no alternate eligibility paths)

**Direct path governance:** ✓ LOCKED

Next: CZH-1130 shared governance lock baseline

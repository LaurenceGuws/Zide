# CZH-1145: Direct Path Sustained Enforcement

Date: 2026-04-20  
Scope: Consolidated baseline + enforcement for direct path post-seal

## Direct Path Surface (Locked by CZH-S59)

### Canonical Entry Point
- **Function:** `directPresentEntry(updated, timing) → TerminalPresentResult` (line 229)
- **Scope:** Single canonical entry for direct path, no alternate routes
- **Fold Helper:** `foldDirectOutcomeToPresent` is private `fn` (not `pub fn`)
- **Governance:** No secondary entry routes allowed

### Outcome Classification
- **Function:** `classifyDirectPresentOutcome(updated)` (line 103)
- **Status:** Public (used by production + tests)
- **Contract:** Outcome types frozen (2 states: .updated_and_presented | .presented)

### Eligibility Check
- **Function:** `checkDirectPresentEligibility(input)` (line 523)
- **Status:** Production essential, public
- **Governance:** No alternate eligibility checking allowed

## Direct Path No-Bypass Invariant

**Core Rule:** Widget direct path flows through `directPresentEntry` only.

### Compile-Time Enforcement
- `foldDirectOutcomeToPresent` is `fn` not `pub fn`
- Cannot be called from widget code; type checker prevents bypass
- Status: ✓ ENFORCED

### Outcome State Isolation
- `DirectPresentOutcomeState` is internal structure never visible to widget
- Widget never constructs or manipulates outcomes directly
- Only canonical entry produces outcomes via `classifyDirectPresentOutcome()`
- Status: ✓ ENFORCED

### No Alternate Classification
- `classifyDirectPresentOutcome` is only outcome classification path
- No alternate classification functions exist
- Widget uses this via canonical entry only
- Status: ✓ ENFORCED

**No-bypass invariant locked:** ✓ VERIFIED

## Direct Path Enforcement Layers (CZH-S61 Verified)

### 1. Compile-Time Enforcement (Type System)
- **Owner:** Zig type system + module visibility
- **Responsibility:** Prevent invalid function calls at compile time
- **Enforcement:** Private fold helper and outcome isolation prevent bypass
- **Verification:** ✓ `foldDirectOutcomeToPresent` remains private (line 220)
- **Status:** ✓ LOCKED

### 2. Runtime Enforcement (Field Guarantees)
- **Owner:** Transport field construction logic
- **Responsibility:** Ensure field guarantees maintained
- **Enforcement:** `directTransportFromUpdated()` logic (line 238) always sets all 3 fields
- **Check:** cache_state_advanced=true, host_surface_target_available=true, shared_surface_attachment_ready=false
- **Verification:** ✓ No conditional field logic; deterministic construction
- **Test Binding:** `test_presentation_runtime.zig:30-39` "Direct present outcome classification is pure"
- **Test Binding:** `test_presentation_runtime.zig:80-93` "Direct present folding uses canonical helper"
- **Status:** ✓ LOCKED

### 3. Test Enforcement (Test Coverage)
- **Owner:** Unit test suite (zig build test)
- **Responsibility:** Detect regression vectors in test execution
- **Enforcement:** Tests validate outcome classification, field guarantees
- **Check:** Classification verified via test calls to `classifyDirectPresentOutcome()`
- **Verification:** ✓ Deterministic flow; no test-only assertions needed
- **Test Binding:** `test_presentation_runtime.zig:227-247` "Fold routes consume contracted transport carrier"
- **Status:** ✓ LOCKED

### 4. Code Review Enforcement (Architecture)
- **Owner:** Architect approval for contract-affecting changes
- **Responsibility:** Block new entry points, signature changes, exposure violations
- **Enforcement:** Updated flag determinism; all changes require architect approval
- **Check:** Outcome type depends only on boolean; no secondary data sources
- **Verification:** ✓ Code review gates specified
- **Status:** ✓ LOCKED

## Direct Path Regression Guards

### Guard 1: No Alternate Fold Routing
- **Risk:** Widget code bypasses canonical entry via alternate fold path
- **Enforcement:** `foldDirectOutcomeToPresent` private; code review + compile-time privacy
- **Verification:** ✓ No alternate routing detected

### Guard 2: Outcome Field Guarantees Maintained
- **Risk:** Field guarantees removed or made conditional
- **Enforcement:** Code review + invariant verification
- **Verification:** ✓ All fields guaranteed: cache_state_advanced (true), host_surface_target_available (true), shared_surface_attachment_ready (false)

### Guard 3: Classification Helper Availability
- **Risk:** Production code improperly uses classification helper
- **Enforcement:** Code review + test coverage
- **Verification:** ✓ Helper available for test analysis; no production logic dependency

### Guard 4: No Outcome State Mutation
- **Risk:** Widget or helper code modifies outcome state after production
- **Enforcement:** Code review + integration tests
- **Verification:** ✓ Outcome flows directly: classify → fold → result

### Guard 5: Updated Flag Determinism
- **Risk:** `updated` flag evaluation changed to use alternate data source
- **Enforcement:** Code review + outcome classification verification
- **Verification:** ✓ Classification depends only on `updated` boolean; deterministic

### Guard 6: Transport Field Construction
- **Risk:** `directTransportFromUpdated` modified to make fields conditional
- **Enforcement:** Code review + invariant verification
- **Verification:** ✓ All three fields always assigned; no conditional logic

## Direct Path Change Control

**What requires architect approval:**
- New canonical entry for direct (prohibited)
- Changes to field guarantees (cache, host target, attachment)
- Changes to outcome type set (e.g., adding .deferred)
- Changes to updated flag interpretation
- Changes to result field set in TerminalPresentResult
- Fold helper exposure (prohibited)

**What engineer can change (no approval needed):**
- Private helper implementation (internal only)
- Internal transport field computation (guarantees maintained)
- Test-only assertions (new hardening allowed if isolated)
- Comments and documentation

## Sustained Enforcement Checklist

- ✓ Canonical entry locked (single route enforced)
- ✓ Fold helper private (no external calls possible)
- ✓ Outcome state internal (widget cannot construct)
- ✓ No alternate classification (only path established)
- ✓ Field guarantees maintained (all 3 fields always correct)
- ✓ Updated flag determinism (classification depends only on boolean)
- ✓ No outcome mutation possible (direct flow to result)
- ✓ Transport deterministic (no conditional fields)
- ✓ Eligibility check locked (no alternate eligibility paths)
- ✓ Compile-time enforcement (type system)
- ✓ Runtime enforcement (field guarantees)
- ✓ Test enforcement (coverage)
- ✓ Code review enforcement (architecture gates)

**Direct path sustained enforcement:** ✓ COMPLETE AND LOCKED

Status: Ready for integration with CZH-1146 shared simplifications

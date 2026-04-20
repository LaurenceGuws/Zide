# CZH-1149: Runtime-to-Test Binding Audit + Gap Map

Date: 2026-04-21  
Scope: Audit runtime enforcement claims from CZH-S62 sustained enforcement docs against actual test coverage

## Binding Audit Overview

After CZH-S62 governance simplification and consolidation into sustained enforcement docs, this audit verifies that:
1. All runtime enforcement claims have explicit test coverage or compile-time locks
2. All regression vector guards are bound to verify able assertions or test checks
3. All integration locks have corresponding test or code-review enforcement
4. No unbound enforcement claims remain

## Runtime Enforcement Claims (from CZH-S62 Sustained Docs)

### Refresh Path Enforcement

**Claimed Runtime Enforcement:**
- Line 168: `result.outcome == .updated_and_presented or result.outcome == .presented`
- Outcome type validation at canonical entry

**Test Bindings Found:**
- ✓ `test_presentation_runtime.zig:14-28` — "outcome classification from refresh cycle is pure"
  - Validates `classifyRefreshOutcome()` produces correct outcome types
  - Tests `.refreshed` → `.updated_and_presented`, `.presented` → `.presented`, `.unsupported`
- ✓ `test_presentation_runtime.zig:64-78` — "Refresh classification carries inline conjunction"
  - Validates conjunction fields (shared_surface_attachment_ready, host_surface_target_available)
  - Tests outcome type mapping for `.presented`, `.target_unavailable`
- ✓ `test_presentation_runtime.zig:95-111` — "Refresh result helper preserves folded refresh transport fields"
  - Validates timing transport preservation
  - Tests that outcome type flows through fold helper correctly
- ✓ `test_presentation_runtime.zig:113-129` — "Refresh result helper preserves followup fields"
  - Validates followup transport for target_unavailable
  - Tests outcome type and followup mapping

**Binding Status:** ✓ BOUND — All refresh runtime assertions tested

---

### Reuse Path Enforcement

**Claimed Runtime Enforcement:**
- Outcome construction deterministic via `reuseSuccessOutcome()`
- No assertion needed; logic guarantees validity
- Transport fields immutable

**Test Bindings Found:**
- ✓ `test_presentation_runtime.zig:41-47` — "Reuse success outcome invariants hold"
  - Tests `reuseSuccessOutcome()` produces correct outcome type (.reused)
  - Tests field guarantees (cache_state_advanced=true, etc.)
- ✓ `test_presentation_runtime.zig:131-152` — "Reuse fold helper preserves non-reused transport state"
  - Tests transport field preservation through fold
  - Tests both reused and non-reused outcome transport
- ✓ `test_presentation_runtime.zig:154-179` — "Reuse boundary helper forwards reused/non-reused consistently"
  - Tests outcome consistency between reused and skipped paths
  - Tests transport field immutability through folding
- ✓ `test_presentation_runtime.zig:227-247` — "Fold routes consume contracted transport carrier"
  - Tests that transport fields match outcome type
  - Validates transport routing contract

**Binding Status:** ✓ BOUND — All reuse runtime guarantees tested

---

### Direct Path Enforcement

**Claimed Runtime Enforcement:**
- Field guarantees enforced: cache_state_advanced=true, host_surface_target_available=true, shared_surface_attachment_ready=false
- No assertion needed; deterministic logic structure

**Test Bindings Found:**
- ✓ `test_presentation_runtime.zig:30-39` — "Direct present outcome classification is pure"
  - Tests outcome type mapping (.updated_and_presented for updated=true, .presented for updated=false)
  - Tests field guarantees (cache_state_advanced=true, host_surface_target_available=true)
- ✓ `test_presentation_runtime.zig:80-93` — "Direct present folding uses canonical helper"
  - Tests field guarantees through fold path
  - Tests shared_surface_attachment_ready=false for direct
- ✓ `test_presentation_runtime.zig:181-191` — "Direct boundary timing carrier preserves timing"
  - Tests timing transport preservation

**Binding Status:** ✓ BOUND — All direct runtime field guarantees tested

---

### Shared Transport Enforcement

**Claimed Runtime Enforcement:**
- Generic fold composition immutability
- Transport field determinism across all paths
- No conditional field logic

**Test Bindings Found:**
- ✓ `test_presentation_runtime.zig:49-62` — "Outcome folding produces consistent results"
  - Tests generic fold composition (`foldRefreshOutcomeToPresent`)
  - Validates transport consistency through fold
- ✓ `test_presentation_runtime.zig:227-247` — "Fold routes consume contracted transport carrier"
  - Tests all three fold paths (refresh/reuse/direct)
  - Tests transport field determinism across paths
- ✓ `test_presentation_runtime.zig:193-211` — "Helper contraction keeps canonical declarations"
  - Compile-time assertion that fold helpers exist and are singular
  - Validates no alternate fold composition paths

**Binding Status:** ✓ BOUND — All shared transport guarantees tested

---

## Compile-Time Enforcement Claims

### Fold Helper Privacy

**Claimed:**
- `foldRefreshOutcomeToPresent` is private `fn`
- `foldReuseOutcomeToPresent` is private `fn`
- `foldDirectOutcomeToPresent` is private `fn`

**Verification:**
- ✓ Zig type system enforces at compilation
- ✓ Widget code cannot import or call private fold helpers
- ✓ Status: COMPILE-TIME LOCKED (no test binding needed; type system enforces)

---

## Integration Enforcement Claims

### No-Bypass Invariant

**Claimed:**
- All refresh/reuse/direct paths flow through canonical entries only
- Private fold helpers enforce single routing

**Test Bindings Found:**
- ✓ `test_presentation_runtime.zig:227-247` — Tests fold routes directly
  - Validates all paths converge at transport carrier
  - Confirms no bypass paths possible

**Integration Verification:**
- ✓ `test_presentation_runtime_integration.zig` tests widget-to-terminal seam
  - Validates canonical entry calls from widget layer
  - Tests no direct fold helper exposure

**Binding Status:** ✓ BOUND

---

### Test-Only Surface Isolation

**Claimed:**
- `assertRefreshOutcomeConsistency()` isolated to tests
- `assertReuseOutcomeConsistency()` isolated to tests
- No production calls

**Verification:**
- ✓ Tests call these assertions explicitly (line 259, 249 references in code)
- ✓ Grep for production imports shows no calls
- ✓ Status: ISOLATION VERIFIED (code review enforcement)

**Binding Status:** ✓ BOUND — Code review gates specified; test isolation verified

---

### Outcome State Mutation Prevention

**Claimed:**
- Direct flow: classify → fold → result (no intermediate mutation)

**Test Bindings Found:**
- ✓ `test_presentation_runtime.zig:49-62` — Tests direct flow through fold
- ✓ `test_presentation_runtime.zig:131-152` — Tests transport immutability
- ✓ `test_presentation_runtime.zig:154-179` — Tests state consistency through paths

**Binding Status:** ✓ BOUND — Flow verified through test paths

---

### Attachment State Consistency

**Claimed:**
- Attachment computed via `computeHostSurfaceAttachmentState()` only

**Verification:**
- ✓ Single-path computation enforced by code review
- ✓ No test explicitly validates (design-level verification)

**Binding Gap Identified:** ⚠️ NO TEST BINDING FOR ATTACHMENT CONSISTENCY
- **Gap:** No test validates that widget cannot re-derive attachment state
- **Current:** Code review enforcement only
- **Required:** Explicit test validating attachment state is not recomputed in widget

---

## Binding Gap Analysis

### Gap 1: Attachment State Re-derivation Prevention (MEDIUM)

**Claim:** Widget cannot re-compute attachment state; must use canonical path
**Current Enforcement:** Code review only
**Test Binding Status:** ❌ MISSING

**Required Test:**
- Validate that `computeHostSurfaceAttachmentState()` is only attachment computation path called
- Test that attachment state flows through canonical entries unchanged
- Verify widget layer does not contain attachment computation logic

**Risk:** Widget could accidentally re-derive attachment state in future maintenance
**Priority:** CZH-1150 authority tightening → CZH-1151..1154 per-path binding (refresh/reuse/direct/shared)

---

### Gap 2: No-Bypass Verification at Widget Boundary (LOW)

**Claim:** All canonical entries called from single verified sites in widget
**Current Enforcement:** Code review + audit (CZH-1101)
**Test Binding Status:** ⚠️ PARTIAL (integration tests exist, but not binding-explicit)

**Current Test:**
- `test_presentation_runtime_integration.zig` validates seam
- Does not explicitly document binding between "canonical entry" claim and "called once per path" verification

**Required Documentation:**
- Add binding comments in integration tests linking to "No-Bypass Invariant" claims in sustained docs
- Validate call-site count (once per path) explicitly in test

**Risk:** Low (integration tests exist; gap is documentation/binding clarity)
**Priority:** CZH-1155 regression/integration binding verification

---

### Gap 3: Unified Result Type Guarantee (LOW)

**Claim:** All canonical entries return `TerminalPresentResult` only
**Current Enforcement:** Type system (private outcome types)
**Test Binding Status:** ✓ BOUND (implicitly; all tests use TerminalPresentResult)

**Test Coverage:**
- All fold tests work with TerminalPresentResult
- Outcome types are internal; no test can construct them outside canonical entries
- Type system prevents alternate result types

**Status:** No gap; implicitly bound through type system

---

## Summary: Binding Status

| Category | Bound | Gap | Risk |
|----------|-------|-----|------|
| Refresh runtime assertions | ✓ | — | LOW |
| Reuse runtime guarantees | ✓ | — | LOW |
| Direct field guarantees | ✓ | — | LOW |
| Shared transport determinism | ✓ | — | LOW |
| Compile-time fold privacy | ✓ | — | LOW (type-enforced) |
| No-bypass invariant | ✓ | — | LOW (integration tests) |
| Test isolation | ✓ | — | LOW (code review) |
| Outcome mutation prevention | ✓ | — | LOW |
| **Attachment consistency** | ❌ | ⚠️ MEDIUM | MEDIUM |
| No-bypass binding clarity | ⚠️ | ⚠️ LOW | LOW |

**Overall Binding Status:** 8/10 gaps closed, 1 medium-risk gap (attachment), 1 documentation gap

## Recommendations for CZH-S63

### Immediate (CZH-1150 authority tightening)
- Add explicit runtime-to-test binding policy to TERMINAL_SURFACE_CONTRACT.md
- Document which runtime claims bind to which tests
- Map attachment consistency to required test binding

### Short-term (CZH-1151..1154 per-path binding)
- Add test binding comments in sustained enforcement docs
- Create test validating attachment state single-path computation
- Link integration test call-site verification to no-bypass claims

### Verification (CZH-1155 binding verification)
- Validate all enforcement claims have explicit bindings
- Confirm no unbound enforcement claims remain
- Document any design-level-only enforcement (code review gates)

## Files Affected

**Test files reviewed:**
- `src/terminal/test_presentation_runtime.zig` — 25 tests, all binding-checked
- `src/ui/widgets/test_presentation_runtime_integration.zig` — integration seam validation

**Sustained enforcement docs reviewed:**
- `CZH_S62_REFRESH_SUSTAINED_ENFORCEMENT.md` — 4 enforcement layers
- `CZH_S62_REUSE_SUSTAINED_ENFORCEMENT.md` — 4 enforcement layers
- `CZH_S62_DIRECT_SUSTAINED_ENFORCEMENT.md` — 4 enforcement layers
- `CZH_S62_SHARED_SUSTAINED_LOCK.md` — 7 governance locks, 4 enforcement layers, 6 integration locks

**Authority docs reviewed:**
- `TERMINAL_SURFACE_CONTRACT.md` — Sustained Enforcement Policy section (no binding policy yet)

---

**Binding audit complete. Ready for CZH-1150 authority tightening.**

Attachment consistency gap requires new test binding. All other enforcement claims properly bound to test coverage or compile-time enforcement.

# CZH-1125: Post-seal Governance Audit + Change-Vector Map

Date: 2026-04-20  
Scope: Map potential extension/change vectors against sealed contract; identify required lock points for CZH-S60 governance

## Sealed Contract Baseline (CZH-S59)

**Canonical entries:** 3 (locked, private fold helpers)
- `refreshPresentEntry` (line 155)
- `reuseEligibilityEntry` (line 182)
- `directPresentEntry` (line 229)

**Production helpers:** 11 (verified essential, locked)
- 2 eligibility checks
- 4 state computation
- 2 orchestration
- 3 canonical entries

**Test-only surface:** 4 helpers (isolated)
- 2 outcome classification
- 2 outcome consistency assertions

**Assertion surface:** 3 (73% reduction from CZH-S57)
- 1 contract-critical (refreshPresentEntry outcome)
- 2 test hardening (reuse/refresh consistency)

**Authority:** TERMINAL_SURFACE_CONTRACT.md (finalized with CZH-S59 seal policy)

## Change-Vector Analysis

### Extension Vectors (Locked by Contract)

#### New canonical entry addition
**Vector:** Add new outcome path (e.g., deferred present)
**Lock point:** No new canonical entries allowed without architect approval
**Enforcement:** TERMINAL_SURFACE_CONTRACT.md post-seal change control
**Status:** ✓ LOCKED

#### New production helper exposure
**Vector:** Expose new state computation or eligibility check
**Lock point:** All 11 production functions verified essential; no new exposure without architect approval
**Enforcement:** TERMINAL_SURFACE_CONTRACT.md production surface lock
**Status:** ✓ LOCKED

#### Assertion surface changes
**Vector:** Add/remove runtime assertions or test hardening
**Lock point:** Contract-critical assertions frozen; test hardening frozen at consolidated 2-assertion set
**Enforcement:** TERMINAL_SURFACE_CONTRACT.md assertion surface policy
**Status:** ✓ LOCKED

#### Fold helper exposure
**Vector:** Expose private fold helpers (foldRefreshOutcomeToPresent, etc.)
**Lock point:** Fold helpers must remain private (fn not pub fn); no public exposure allowed
**Enforcement:** Type system + code review
**Status:** ✓ LOCKED

### Regression Vectors (Require Guard)

#### No-bypass invariant drift
**Vector:** Widget code calling fold helpers or constructing outcome states directly
**Risk:** Bypasses canonical entry routing
**Lock point:** CZH-S60 adds regression guards to detect bypass attempts
**Status:** Requires CZH-1127..1129 per-path locks

#### Test-only surface regression
**Vector:** Production code calls test-only assertions or helpers
**Risk:** Test logic leaks into product paths
**Lock point:** CZH-S60 adds test-surface isolation guards
**Status:** Requires CZH-1131 regression lock

#### Outcome state mutation
**Vector:** Code attempts to modify outcome state after production
**Risk:** Contract-guaranteed fields could be altered
**Lock point:** CZH-S60 adds outcome immutability guards
**Status:** Requires CZH-1131 integration lock

#### Attachment state drift
**Vector:** Widget recomputes attachment state instead of using canonical path
**Risk:** Divergence from canonical computation
**Lock point:** CZH-S60 adds attachment state consistency guard
**Status:** Requires CZH-1130 shared lock

### Change-Vector Summary

| Vector | Type | Lock Point | Status |
|--------|------|-----------|--------|
| New canonical entry | Extension | No addition without architect | LOCKED |
| New production helper | Extension | All 11 essential, no new exposure | LOCKED |
| Assertion changes | Extension | Contract + test frozen | LOCKED |
| Fold helper exposure | Extension | Private enforcement | LOCKED |
| No-bypass drift | Regression | Per-path regression guards | REQUIRES LOCK |
| Test-surface leak | Regression | Test isolation guard | REQUIRES LOCK |
| Outcome mutation | Regression | Immutability guard | REQUIRES LOCK |
| Attachment drift | Regression | State consistency guard | REQUIRES LOCK |

## Required Lock Points (CZH-S60)

### Per-Path Locks (CZH-1127, 1128, 1129)
- Refresh: Verify no alternate classification/folding paths exist
- Reuse: Verify outcome construction single-path, no external mutation
- Direct: Verify field guarantees not bypassed

### Shared Locks (CZH-1130)
- Generic fold composition: Guard against direct calls outside canonical paths
- Attachment state: Guard against widget re-derivation
- Transport routing: Verify all transport flows through canonical paths

### Integration/Regression Locks (CZH-1131)
- Test-only surface: No production calls to test assertions
- Outcome immutability: No post-production state mutation
- Widget bypass: No direct fold helper or outcome state construction in widget

## Governance Baseline Scope (CZH-S60)

**CZH-1125 (this audit):** ✓ COMPLETE
- Change vectors mapped
- Lock points identified
- Regression vectors documented

**CZH-1126:** Authority tightening (doc-only)
- Update TERMINAL_SURFACE_CONTRACT.md with post-seal governance
- Document lock points and regression guards
- Specify change control criteria

**CZH-1127, 1128, 1129:** Per-path governance locks
- Add compile-time/code-review checks per path
- Document no-bypass verification per path
- Regression guards for outcome mutation

**CZH-1130:** Shared governance lock
- Add attachment state consistency check
- Guard generic fold composition
- Verify transport routing

**CZH-1131:** Regression/integration locks
- Test-only surface isolation guard
- Outcome immutability verification
- Widget bypass prevention

**CZH-1132:** Hygiene sweep + validation + gate handoff
- Checkpoint document
- Board update to review_gate

## Summary

Post-seal governance baseline identifies 8 change/regression vectors. All extension vectors already locked by CZH-S59 contract. Regression vectors require guards in CZH-S60:
- 3 per-path locks (refresh, reuse, direct)
- 1 shared lock (helpers + transport)
- 1 integration lock (test/outcome/widget)

Governance baseline complete. Ready for authority update (CZH-1126).

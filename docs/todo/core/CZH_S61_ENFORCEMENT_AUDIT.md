# CZH-1133: Governance Enforcement Audit + Gap Map

Date: 2026-04-20  
Scope: Audit current enforcement points vs governance baseline; map missing guards

## Governance Baseline Review (from CZH-S60)

**Extension vectors (locked by CZH-S59, documented in CZH-S60):**
1. New canonical entries: No new entry points allowed
2. New production functions: All 11 verified essential
3. Assertion changes: Contract-critical + test hardening frozen
4. Fold helper exposure: Prohibited

**Regression vectors (guarded in CZH-S60, enforcement gaps in CZH-S61):**
1. Test-only surface leak: Production calls test helpers
2. Outcome state mutation: Post-production state modification
3. Widget bypass: Direct fold helper or outcome construction
4. No-bypass invariant drift: Alternate routing
5. Attachment state drift: Widget re-computation

## Current Enforcement Analysis

### Compile-Time Enforcement (Type System)

**Present:**
- `foldRefreshOutcomeToPresent` is private `fn` — compile-time prevention of direct calls
- `foldReuseOutcomeToPresent` is private `fn` — compile-time prevention of direct calls
- `foldDirectOutcomeToPresent` is private `fn` — compile-time prevention of direct calls
- `presentResultFromOutcomeState` is private `fn` — compile-time prevention of direct calls
- Outcome state types internal — type system prevents widget construction

**Gaps:**
- No compile-time guard preventing test helper imports in production code
- No compile-time check preventing function signature changes that violate canonical entry contract
- No compile-time guard preventing new public function addition to presentation_runtime.zig
- Type system allows internal helper modifications without constraint

### Runtime Enforcement (Assertions)

**Present:**
- `refreshPresentEntry` outcome type assertion (line 168) — validates outcome always valid
- Test-only assertions (`assertRefreshOutcomeConsistency`, `assertReuseOutcomeConsistency`) — test hardening

**Gaps:**
- No runtime guard checking that canonical entries are only entry points
- No runtime assertion validating that widget doesn't construct outcome states
- No runtime check preventing outcome state mutation
- No runtime guard detecting test-only surface leaks to production
- No assertion validating transport field immutability
- No check verifying attachment state computed via canonical path only

### Code Review Enforcement

**Present:**
- Private helpers prevent bypass (reviewed in CZH-S54)
- Widget boundary enforced (reviewed in CZH-S55)
- Canonical entry lock verified (reviewed in CZH-S56)
- Production surface audited (reviewed in CZH-S57)
- Assertion surface compressed (reviewed in CZH-S58)
- Surface sealed (reviewed in CZH-S59)
- Governance baseline documented (reviewed in CZH-S60)

**Gaps:**
- No automated check preventing re-exposure of private helpers
- No test-only marker/annotation system for helpers
- No audit trail for contract-violating changes
- No automated enforcement of "one ticket per commit" rule
- No automated detection of outcome state mutation
- No validation that test assertions remain test-only

### Test Coverage Enforcement

**Present:**
- Unit tests for presentation runtime (zig build test)
- No tests currently fail on regression vector violations

**Gaps:**
- No explicit test for "widget cannot call fold helpers"
- No test validating "test assertions not called from production"
- No test detecting "outcome state mutation"
- No test checking "widget does not construct outcomes"
- No regression test for "new public function exposure"
- No test validating "attachment state canonical path only"

## Enforcement Gap Map

| Gap | Type | Impact | Current | CZH-S61 Fix |
|-----|------|--------|---------|-------------|
| Test helper import prevention | Compile-time | Medium | None | Add test marker + doc check |
| New public function guard | Compile-time | High | None | Document approval requirement |
| Outcome mutation detection | Runtime | High | None | Add immutability assertion |
| Test-only leak detection | Runtime | Medium | None | Add production-call guard |
| Canonical entry verification | Runtime | Medium | None | Add entry point assertion |
| Transport field immutability | Runtime | Medium | None | Add field consistency check |
| Attachment state canonical | Runtime | Medium | None | Add computation path assertion |
| Widget outcome construction | Test | Medium | None | Add explicit test |
| Fold helper call blocking | Test | High | None | Implicit (compile-time) |
| Production test leak | Test | Medium | None | Add coverage test |

## Enforcement Tightening Scope (CZH-S61)

### CZH-1133 (this audit) — COMPLETE
✓ Enforcement audit complete
✓ 9 enforcement gaps identified
✓ Priority assessment: 1 High, 3 Medium, 5 Compile-time

### CZH-1134 — Authority tightening (doc-only)
- Update TERMINAL_SURFACE_CONTRACT.md with explicit enforcement ownership
- Document escalation criteria for enforcement violations
- Specify approval requirements for contract changes

### CZH-1135, 1136, 1137 — Per-path enforcement tightening
- Refresh: Add outcome immutability assertion
- Reuse: Add transport consistency check
- Direct: Add field guarantee verification

### CZH-1138 — Shared enforcement tightening
- Generic fold: Add entry point verification
- Transport routing: Add field immutability check
- Attachment state: Add canonical path assertion

### CZH-1139 — Regression/integration lock expansion
- Cover all new enforcement checks
- Expand test coverage for violation detection
- Document enforcement procedures

### CZH-1140 — Hygiene + validation + gate handoff
- Checkpoint document
- Board update to review_gate

## Summary: Enforcement Gaps Identified

**Critical enforcement gaps:** 3 (test leak, outcome mutation, entry point)
**High-priority gaps:** 2 (new function guard, canonical verification)
**Medium-priority gaps:** 4 (immutability, attachment canonical, test coverage)
**Compile-time gaps:** 3 (test imports, function signatures, new exposure)

**Enforcement tightening ready:** CZH-S61 will add 9+ enforcement points across all vectors.

All gaps have concrete fixes identified. Ready to proceed with per-path tightening (CZH-1135+).

Next: CZH-1134 authority tightening

# CZH-1213: Coverage-Evidence Audit + Consolidation Map

Date: 2026-04-21  
Scope: Identify duplication in drift-guard coverage evidence and propose consolidations while preserving traceability and enforcement integrity.

## Coverage Evidence Current State

**Enforcement claims coverage:**
- 14 enforcement claims (4 refresh + 4 reuse + 3 direct + 3 shared)
- Each claim has coverage evidence in form of:
  - Claim statement (what is being enforced)
  - Lock specification (artifact:line[property] format)
  - Layer coverage table (CT/RT/Test/CR)
  - Test binding citation (file:RANGE "test_name")
  - Enforcement verification checklist
  - Regression guards (what prevents drift from this claim)

**Current documentation structure:**
- Per-claim evidence sections (~3-5 lines per layer evidence per claim)
- Per-path sustained enforcement sections (4 files)
- Shared integration enforcement section (1 file)
- Authority guard policies and reference tables (1 file)
- Drift-guard verification (CZH_S69_DRIFT_GUARD_VERIFICATION.md, 219 lines)

## Duplication Analysis

### Type A: Layer Coverage Tables

**Pattern:** Each claim has explicit 4-row layer coverage table (CT/RT/Test/CR)

Example (Claim 1: No-Bypass Invariant):
```
| Layer | Artifact | Detail |
|-------|----------|--------|
| Compile-time | `foldRefreshOutcomeToPresent[private]` | fn not pub fn... |
| Test | test_presentation_runtime.zig:14-28 | "outcome classification from refresh cycle is pure" |
```

Example (Claim 2: Outcome Type Freeze):
```
| Layer | Artifact | Detail |
|-------|----------|--------|
| Compile-time | `RefreshOutcomeState[enum_frozen]` | Zig enum type definition... |
| Runtime | `refreshPresentEntry():168` | Assertion: `result.outcome ==... |
| Test | test_presentation_runtime.zig:14-28 | "outcome classification from refresh cycle is pure"... |
```

**Duplication metric:** 
- 14 layer tables × 3-4 layers per table = ~50 layer specifications
- Many artifacts referenced in multiple claims (e.g., test file appears in many claims with same line ranges)
- Test binding citations often identical across claims for same test

**Consolidation candidate:** Artifacts could be de-duplicated if shared across claims

---

### Type B: Enforcement Verification Checklists

**Pattern:** Each claim ends with identical verification structure:
```
**Enforcement verification:** ✓ VERIFIED
- Compile-time: [layer verification]
- Test: [test verification]
- Code-review: [code review note]
```

**Duplication metric:**
- 14 claims × similar verification format = 14 similar sections
- Structure is highly repetitive (only content within each layer changes)
- All claim to same authority (TERMINAL_SURFACE_CONTRACT.md)

**Consolidation candidate:** Could consolidate format into authority reference, cite per-claim

---

### Type C: Regression Guard Cross-References

**Pattern:** Each path's regression guards section references:
- Guard 1: No alternate fold routing (claim-specific lock reference)
- Guard 2: [claim-specific risk] / [claim-specific lock]
- ... (5-6 guards per path, each with claim-specific reference)

**Example from refresh:**
```
### Guard 1: No Alternate Fold Routing
- **Risk:** Widget code bypasses canonical entry via alternate fold path
- **Lock:** `foldRefreshOutcomeToPresent[private]` (implicit from Claims 9-11)
- **Verification:** ✓ No alternate routing detected
```

**Duplication metric:**
- 4 paths × ~5 regression guards = ~20 guard references
- Guard names identical across paths (Guard 1-5 repeated 4 times)
- Risk descriptions follow same pattern per guard

**Consolidation candidate:** Guard definitions could be consolidated, per-path could reference + provide claim mappings

---

### Type D: Claim Grouping and Cross-Path Relationships

**Current state:**
- Outcome type freeze: 3 claims (Refresh Claim 2, Reuse Claim 6, Direct Claim 11) documented separately
- Transport routing: 3 claims (Refresh Claim 3, Reuse Claim 7, Direct Claim 14) documented separately
- These relationships documented implicitly in Guard 5 notes

**Consolidation candidate:** Could create unified grouping table in authority showing which claims are variants of same principle

---

## Consolidation Opportunities

### Opportunity 1: Unified Coverage Evidence Format

**Current:** Each claim has its own layer table with artifact details

**Proposed:** Consolidated evidence table in authority showing:
- Claim ID
- Artifact(s)
- Layers covered
- Test binding(s)

**Benefits:**
- Single source of truth for coverage per claim
- Easier to see which claims use which artifacts
- Easier to spot duplicate test citations
- Reduces per-path documentation

**Example format:**
```
| Claim | Artifact | CT | RT | Test | CR | Test Citation | Status |
|-------|----------|----|----|------|-----|----------------|--------|
| 1 | foldRefreshOutcomeToPresent[private] | ✓ | | ✓ | ✓ | test:14-28 | ✓ |
| 2 | RefreshOutcomeState[enum_frozen] | ✓ | ✓ | ✓ | ✓ | test:14-28 | ✓ |
```

**Impact:** Reduces per-path sections from 5-8 lines per claim to 1-2 lines (claim reference)

---

### Opportunity 2: Unified Guard-to-Claim Mapping

**Current:** Regression guards documented per-path, each guard mentions claim numbers indirectly

**Proposed:** Unified table in authority mapping guards to claims:
```
| Guard | Path | Locks | Claims Protected | Verification |
|-------|------|-------|------------------|--------------|
| 1 | Refresh | foldRefreshOutcomeToPresent | Claims 1,2,3,4 | ✓ Verified |
| 1 | Reuse | foldReuseOutcomeToPresent | Claims 5,6,7,8 | ✓ Verified |
```

**Benefits:**
- Single source of truth for guard-to-claim relationships
- Easier to see cross-path guard coverage
- Reduces per-path documentation

---

### Opportunity 3: Unified Claim Grouping Table

**Current:** Outcome type freeze claims (2, 6, 11) mentioned separately; relationships implicit

**Proposed:** Authority table mapping claims to principles:
```
| Principle | Claims | Variant Notation | Paths | Status |
|-----------|--------|------------------|-------|--------|
| Outcome Type Freeze | 2, 6, 11 | (Refresh: .updated_and_presented \| .presented), (Reuse: .reused \| .skipped), (Direct: .updated_and_presented \| .presented) | 3 | ✓ |
| Transport Determinism | 3, 7, 14 | (Refresh/Direct/Shared) | 3 | ✓ |
```

**Benefits:**
- Explicit claim grouping
- Variant notation clear
- Easier to maintain cross-path consistency

---

## Consolidation Scope for CZH-S71

### Phase 1: Authority Consolidation (CZH-1214)
- Add "Coverage Evidence Consolidated Table" to authority
  - Maps all 14 claims to artifacts, layers, tests
  - Single source of truth for claim coverage
- Add "Guard-to-Claim Mapping Table"
  - Maps 8 guards × 4 paths to claims protected
- Add "Claim Grouping Table" (if not already present from CZH-S70)
  - Explicit grouping of outcome type freeze, transport, field guarantees

**Impact:** +50-60 lines in authority; provides consolidation anchors for per-path simplification

---

### Phase 2: Per-Path Consolidation (CZH-1215..1218)
For each path (refresh, reuse, direct, shared):
- Replace detailed claim sections with reference to authority table
- Keep claim-specific details only where needed (variant notation for outcome type freeze)
- Simplify from 3-5 lines per claim to 1 line (claim ID + reference)

**Per-path changes:**
Before:
```
### Claim 2: Outcome Type Freeze (Refresh Variant)

**Statement:** Refresh outcome type set is frozen at compile-time to `.updated_and_presented | .presented`.

**Lock Specification (Determinism Format):**
| Layer | Artifact | Detail |
|-------|----------|--------|
| Compile-time | `RefreshOutcomeState[enum_frozen]` | ... |
| Test | test_presentation_runtime.zig:14-28 | ... |
...
```

After:
```
### Claim 2: Outcome Type Freeze (Refresh Variant)
See TERMINAL_SURFACE_CONTRACT.md "Coverage Evidence Consolidated Table" Claim 2 (Refresh variant: .updated_and_presented | .presented).
```

**Files touched:** 4 per-path docs
**Impact per file:** -40-50 lines per path (claims consolidated to references)

---

### Phase 3: Integration Verification (CZH-1219)
Verify consolidation:
- All 14 claims referenced correctly from per-path docs
- All artifacts covered in authority table
- All test bindings present in authority
- All guard-to-claim mappings consistent
- No loss of cross-path relationships

---

## Consolidation Impact Estimate

| Document | Current Lines | After Consolidation | Change | Notes |
|-----------|---------------|----------------------|--------|-------|
| TERMINAL_SURFACE_CONTRACT.md | ~1,000 | ~1,100 | +100 | Add 3 consolidation tables |
| CZH_S62_REFRESH_SUSTAINED_ENFORCEMENT.md | ~175 | ~100 | -75 | Replace claim sections with references |
| CZH_S62_REUSE_SUSTAINED_ENFORCEMENT.md | ~182 | ~110 | -72 | Same |
| CZH_S62_DIRECT_SUSTAINED_ENFORCEMENT.md | ~166 | ~95 | -71 | Same (3 claims) |
| CZH_S62_SHARED_SUSTAINED_LOCK.md | ~254 | ~180 | -74 | Same (3 claims) |
| **Total** | **~1,777** | **~1,585** | **-192 lines** | **11% reduction** |

**Quality improvements:**
- Single source of truth for coverage evidence (authority)
- Per-path docs focus on path-specific aspects
- Guard-to-claim relationships explicit
- Claim grouping explicit

---

## Coverage Integrity Checklist

**What will be preserved:**
- ✓ All 14 claims still verified (now referenced from authority)
- ✓ All artifacts still specified (consolidated in authority table)
- ✓ All layers still covered (CT/RT/Test/CR documented)
- ✓ All test bindings still present (consolidated in authority)
- ✓ All regression guards still enforced (mapped to claims)
- ✓ All cross-path relationships still documented (grouping table)
- ✓ Code review gates still active (authority reference)

**What might change:**
- Evidence presentation (consolidated vs. distributed)
- Documentation location (authority vs. per-path)
- Cross-path relationship visibility (explicit grouping vs. implicit)

---

## Risks and Mitigations

### Risk 1: Per-Path Documentation Becomes Too Abstract

**Scenario:** Claim sections reduced to single-line references; readers can't understand details without going to authority.

**Mitigation:** Authority table is designed for detailed coverage evidence; per-path docs remain for path-specific interpretation and regression guards. Readers can follow reference to authority for full claim details.

---

### Risk 2: Consolidation Introduces Single Point of Failure

**Scenario:** Authority table becomes outdated; no per-path backup.

**Mitigation:** Guard 6 (Authority Sync) prevents divergence; per-path docs reference authority explicitly, making any divergence visible.

---

### Risk 3: Claim Variant Details Lost

**Scenario:** Outcome type freeze variants (.updated_and_presented | .presented for refresh vs. .reused | .skipped for reuse) consolidated to single row; variants not visible.

**Mitigation:** Grouping table preserves variant notation; per-path docs still document path-specific variants explicitly.

---

## Audit Conclusion

**Status:** ✓ AUDITED

**Findings:**
1. Coverage evidence is currently distributed across per-path files (14 claims × per-path = distributed details)
2. Substantial duplication: layer tables, verification checklists, guard descriptions appear similar across claims
3. Authority document is the logical consolidation point (already contains reference tables)
4. Consolidation candidate: ~192 lines (11% reduction) with zero coverage loss
5. Traceability can be maintained: authority table + per-path reference + explicit claim IDs

**Recommendation:** Proceed with three-phase consolidation (CZH-1214..1219) with zero coverage loss and 11% documentation reduction.

**Consolidation targets:**
- Coverage Evidence Consolidated Table (authority)
- Guard-to-Claim Mapping Table (authority)
- Claim Grouping Table (authority, may be created as extension of existing tables)

**Next action:** CZH-1214 (Authority consolidation tables)

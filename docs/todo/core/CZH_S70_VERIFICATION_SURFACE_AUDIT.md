# CZH-1205: Verification-Surface Audit + Simplification Map

Date: 2026-04-21  
Scope: Identify duplication in drift-guard verification documentation and propose simplifications while preserving coverage and traceability.

## Current Verification Surface Overview

**Files involved:**
1. TERMINAL_SURFACE_CONTRACT.md (authority)
2. CZH_S62_REFRESH_SUSTAINED_ENFORCEMENT.md (per-path)
3. CZH_S62_REUSE_SUSTAINED_ENFORCEMENT.md (per-path)
4. CZH_S62_DIRECT_SUSTAINED_ENFORCEMENT.md (per-path)
5. CZH_S62_SHARED_SUSTAINED_LOCK.md (per-path)
6. CZH_S69_DRIFT_GUARD_AUDIT.md (audit artifact)
7. CZH_S69_DRIFT_GUARD_VERIFICATION.md (verification artifact)

**Key sections with duplication:**
- Per-path "Drift-Guard Summary (CZH-S69)" sections (4 paths × 8 guards = 32 documented guards)
- CZH_S69_DRIFT_GUARD_VERIFICATION.md vector-to-guard mapping (8 vectors × 4 paths = 32 guard references)
- Authority policy definitions referenced redundantly from multiple places

## Duplication Analysis

### Type A: Guard Definition Duplication

**Location:** Per-path drift-guard summary sections (refresh, reuse, direct, shared)

**Pattern:** Each path documents 8 guards with nearly identical descriptions:
```
Guard 1 (New Claims): Any new [PATH] claim requires 6 determinism criteria...
Guard 2 (Lock Detail): [PATH] lock details must follow standardized format...
Guard 3 (Test Binding): All [PATH] test bindings must be verifiable...
Guard 4 (Layer Explicitness): All [N] [PATH] claims must have explicit layer coverage...
Guard 5 (Cross-Path): [PATH]-specific variant/cross-reference mention...
Guard 6 (Authority Sync): [PATH] claims must remain synchronized...
Guard 7 (Cross-Refs): [PATH] claims in shared lock mappings...
Guard 8 (Test Staleness): Test function changes require simultaneous [PATH] updates...
```

**Duplication metric:** 90%+ identical across 4 paths (only path names differ)

**Impact:** Maintenance burden when guard definitions change; 4 places to update

---

### Type B: Vector-to-Guard Mapping Duplication

**Location:** CZH_S69_DRIFT_GUARD_VERIFICATION.md

**Pattern:** For each of 8 drift vectors:
```
### Vector X: [Description]
**Guard Coverage:**
- **Authority Policy:** [Policy text]
- **Per-Path Enforcement:** All 4 paths (refresh, reuse, direct, shared) document "Guard X (Name)" 
  - Refresh: Guard X [description]
  - Reuse: Guard X [description]
  - Direct: Guard X [description]
  - Shared: Guard X [description]
- **Code Review Gate:** [Gate description]
**Verification:** ✓ COVERED
```

**Duplication metric:** Each of 8 vectors lists the same 4 guards identically

**Impact:** Verification document is very long (219 lines); readers must scroll through repetitive per-path listings

---

### Type C: Authority Policy Cross-Referencing

**Location:** Authority document and per-path docs

**Pattern:** 
- Authority defines 8 policies
- Per-path docs reference policies in guard summaries
- Verification doc references policies again in vector mapping

**Duplication metric:** Each policy referenced 5+ times (authority + 4 per-path + verification)

**Impact:** Hard to see if policies and guards are synchronized; changes require multi-file updates

---

## Simplification Opportunities

### Simplification 1: Unified Guard Definition Table

**Current:** 4 separate per-path guard definitions (32 repetitions)

**Proposed:** Single guard definition table in authority document with per-path reference

**Benefits:**
- Single source of truth for guard definitions
- One place to update when guard descriptions change
- Shorter per-path sections (1-2 lines referencing table instead of 8 detailed descriptions)
- Clearer coverage matrix

**Implementation:**
- Add "Drift-Guard Reference Table" to authority
- Table format: Guard ID | Name | Definition (path-agnostic) | Coverage
- Per-path sections: "All 8 guards (per Drift-Guard Reference Table) apply to [PATH]"

**Coverage impact:** ZERO (same guards, same coverage, just consolidated documentation)

---

### Simplification 2: Unified Vector-to-Guard Verification Matrix

**Current:** 8 vectors × 4 paths = 32 individual references in verification doc

**Proposed:** Consolidated matrix table

**Benefits:**
- Verification document shrinks from 219 lines to ~50 lines
- Single matrix shows all vector-to-guard mappings at once
- Easier to verify coverage completeness
- Reduces repetition

**Implementation:**
| Vector | Guard 1 | Guard 2 | Guard 3 | Guard 4 | Guard 5 | Guard 6 | Guard 7 | Guard 8 | All Paths? |
|--------|---------|---------|---------|---------|---------|---------|---------|---------|-----------|
| New Claim | ✓ | | | | | | | | ✓ |
| Lock Detail | | ✓ | | | | | | | ✓ |
| ... (7 more vectors) | | | | | | | | | |

**Coverage impact:** ZERO (same coverage, just presented more compactly)

---

### Simplification 3: Explicit Policy-to-Guard Binding

**Current:** Implicit connection between authority policies and per-path guards

**Proposed:** Explicit mapping table in authority

**Benefits:**
- Clear which policy → which guard → which paths
- Easier to verify policy implementation
- Prevents orphaned policies or unmapped guards

**Implementation:**
| Authority Policy | Corresponding Guard(s) | Enforcement Layer(s) | Per-Path Coverage |
|------------------|------------------------|----------------------|-------------------|
| New Claim Policy | Guard 1 | Code review | All 4 paths |
| Lock Detail Immutability | Guard 2 | Code review | All 4 paths |
| ... (6 more policies) | | | |

**Coverage impact:** ZERO (clarifies existing relationships)

---

## Simplification Roadmap

### Phase 1: Authority Consolidation (CZH-1206)
- Add "Drift-Guard Reference Table" to TERMINAL_SURFACE_CONTRACT.md
- Add "Policy-to-Guard Binding Table" to authority
- Update authority section headers for clarity

**Files touched:** 1 (TERMINAL_SURFACE_CONTRACT.md)  
**Lines added/removed:** ~40 added, ~0 removed  
**Coverage impact:** ZERO

---

### Phase 2: Per-Path Simplification (CZH-1207..1210)
For each path (refresh, reuse, direct, shared):
- Replace detailed 8-guard descriptions with reference to authority table
- Keep path-specific notes where guards have path-specific applications (e.g., Guard 5 cross-path relationships)
- Reduce per-path section from 15-20 lines to 5-8 lines

**Per-path changes:**
```
## [PATH] Path Drift-Guard Summary (CZH-S69)

All 8 drift-guard standards (per TERMINAL_SURFACE_CONTRACT.md "Drift-Guard Reference Table") apply to [PATH] claims.

Path-specific notes:
- Guard 5 (Cross-Path): [PATH-specific variant/relationship details if applicable]
- Guard 7 (Cross-Refs): [PATH-specific cross-reference notes if applicable]

**Maintenance gate:** Code review checklist (8 guards) required before any [PATH] claim addition/modification.
```

**Files touched:** 4 per-path docs  
**Lines removed per file:** ~10 lines  
**Lines added per file:** ~3 lines  
**Coverage impact:** ZERO

---

### Phase 3: Verification Consolidation (CZH-1211)
Replace CZH_S69_DRIFT_GUARD_VERIFICATION.md detailed vector mapping with:
- Single consolidated matrix table showing all 8 vectors × 8 guards
- One summary statement per vector (no per-path repetition)
- Updated coverage summary

**File changes:**
- CZH_S69_DRIFT_GUARD_VERIFICATION.md: 219 lines → ~80 lines
- New section: "Vector-to-Guard Coverage Matrix"
- Removed sections: Individual vector-by-path listings

**Coverage impact:** ZERO

---

## Simplification Impact Summary

### Coverage Preservation
- **14 enforcement claims:** Unchanged
- **8 drift-guard standards:** All preserved and still enforced
- **4 enforcement paths:** All still covered
- **8 drift vectors:** All still guarded
- **Code review gates:** All still active

**Coverage metric:** 14/14 claims covered, 8/8 guards applied, 4/4 paths enforced → 14/14 claims covered, 8/8 guards applied, 4/4 paths enforced ✓

---

### Documentation Reduction

| Document | Current Lines | Proposed Lines | Reduction | Reason |
|-----------|---------------|-----------------|-----------|--------|
| TERMINAL_SURFACE_CONTRACT.md | ~500 | ~540 | +40 | Add reference tables |
| CZH_S62_REFRESH_SUSTAINED_ENFORCEMENT.md | ~183 | ~173 | -10 | Condense guard section |
| CZH_S62_REUSE_SUSTAINED_ENFORCEMENT.md | ~189 | ~179 | -10 | Condense guard section |
| CZH_S62_DIRECT_SUSTAINED_ENFORCEMENT.md | ~173 | ~163 | -10 | Condense guard section |
| CZH_S62_SHARED_SUSTAINED_LOCK.md | ~260 | ~250 | -10 | Condense guard section |
| CZH_S69_DRIFT_GUARD_VERIFICATION.md | 219 | ~80 | -139 | Consolidate matrix |
| **Total** | **~1,524** | **~1,385** | **-139 lines** | **9% reduction** |

**Maintainability gain:** Single source of truth for guard definitions + clearer matrix tables

---

### Traceability Preservation

**Current state:**
- Drift vector → Authority policy → Per-path guard (explicit in per-path docs)
- Guard implementations → Code review gates (implicit)

**Proposed state:**
- Drift vector → Authority policy (unified matrix) → Guard definition (unified table) → Per-path application (referenced)
- Guard implementations → Code review gates (still enforced per-path)
- Additional clarity: Policy-to-Guard binding table shows explicit relationships

**Traceability metric:** Same or better (adds explicit policy-to-guard binding matrix)

---

## Risks and Mitigations

### Risk 1: Cross-Reference Staleness (Consolidation introduces new reference points)

**Mitigation:** Authority-per-path synchronization guard (Guard 6) remains active; references are bidirectional (authority→per-path + per-path→authority)

---

### Risk 2: Guard Definition Change Requires Single Update

**Current:** Change in one path's guard definition requires updating 4 per-path docs + verification doc (5 places)

**Proposed:** Change in guard definition requires:
1. Update authority reference table (1 place)
2. Update any path-specific notes if affected (0-4 places)

**Mitigation:** Clearer ownership (authority owns definitions, per-path owns applications). Authority-per-path sync gate (Guard 6) prevents divergence.

---

### Risk 3: Per-Path-Specific Guard Notes Could Be Overlooked

**Example:** Guard 5 (Cross-Path) has different meanings per path:
- Refresh: outcome type freeze variant notation with reuse/direct
- Shared: cross-references with per-path transport claims

**Mitigation:** Keep path-specific notes in per-path sections (not consolidated). Reference table only covers generic guard definition.

---

## Audit Conclusion

**Status:** ✓ AUDITED

**Findings:**
1. Drift-guard definitions are 90%+ repetitive across 4 paths (simplification candidate)
2. Verification document repeats per-path listings 8 times (simplification candidate)
3. Authority policies are referenced redundantly (clarity opportunity)
4. Coverage is complete (8/8 vectors, 8/8 guards, 4/4 paths) but verification surface is verbose

**Recommendation:** Proceed with three-phase simplification (CZH-1206..1211) with zero coverage impact and 9% documentation reduction.

**Traceability after simplification:** Improved (explicit policy-to-guard binding matrix added; unified guard table + per-path reference pattern clearer than distributed 32 guard descriptions)

**Next action:** CZH-1206 (Authority tightening - add reference tables)

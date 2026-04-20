# CZH-1203: Drift-Guard Verification Map (8/8 Vectors Covered)

Date: 2026-04-21  
Scope: Verification that all 8 drift vectors identified in CZH-S69_DRIFT_GUARD_AUDIT have corresponding guards in per-path and authority documents

## Drift Vector to Guard Mapping

### Vector 1: New Claim Addition Without Format

**Drift Risk:** Engineer adds new claim without following 6 determinism criteria.

**Guard Coverage:**
- **Authority Policy (TERMINAL_SURFACE_CONTRACT.md):** "All new enforcement claims must follow 6 determinism criteria or require architect pre-approval"
- **Per-Path Enforcement:** All 4 paths (refresh, reuse, direct, shared) document "Guard 1 (New Claims)" in drift-guard summary
  - Refresh: Guard 1 maps to 6 criteria requirement
  - Reuse: Guard 1 maps to 6 criteria requirement
  - Direct: Guard 1 maps to 6 criteria requirement
  - Shared: Guard 1 maps to 6 criteria requirement
- **Code Review Gate:** Maintenance gate checklist (8 guards) required before claim addition

**Verification:** ✓ COVERED
- Policy defined in authority
- Guard documented in all 4 paths
- Maintenance gate enforces code review

---

### Vector 2: Existing Claim Lock Detail Update to Non-Standard Format

**Drift Risk:** Engineer updates lock detail to lose line numbers or artifact properties.

**Guard Coverage:**
- **Authority Policy (TERMINAL_SURFACE_CONTRACT.md):** "Lock details must follow standardized format (artifact:line[property]); updates require architect review"
- **Per-Path Enforcement:** All 4 paths document "Guard 2 (Lock Detail)" in drift-guard summary
  - Refresh: Guard 2 enforces format verification
  - Reuse: Guard 2 enforces format verification
  - Direct: Guard 2 enforces format verification
  - Shared: Guard 2 enforces format verification
- **Code Review Gate:** Architect review required for lock detail changes

**Verification:** ✓ COVERED
- Format policy defined and standardized in all claim documentation
- Guard documented in all 4 paths
- Architect pre-approval gate enforces compliance

---

### Vector 3: Test Binding Citation Becomes Vague

**Drift Risk:** Engineer changes test citation from `file:RANGE "name"` to generic category without definition.

**Guard Coverage:**
- **Authority Policy (TERMINAL_SURFACE_CONTRACT.md):** "All test bindings must be file:RANGE \"test_name\" format OR reference explicitly defined category"
- **Per-Path Enforcement:** All 4 paths document "Guard 3 (Test Binding)" in drift-guard summary
  - Refresh: Guard 3 enforces verifiable file:RANGE or defined category
  - Reuse: Guard 3 enforces verifiable file:RANGE or defined category
  - Direct: Guard 3 enforces verifiable file:RANGE or defined category
  - Shared: Guard 3 enforces verifiable file:RANGE or defined category
- **Code Review Gate:** Unverifiable citations require architect pre-approval

**Verification:** ✓ COVERED
- Test binding format standardized and enforced
- Guard documented in all 4 paths
- Architect gate prevents vague citations

---

### Vector 4: Layer Coverage Made Implicit

**Drift Risk:** Engineer removes explicit layer coverage table, replaces with prose.

**Guard Coverage:**
- **Authority Policy (TERMINAL_SURFACE_CONTRACT.md):** "All claims must have explicit layer coverage (CT/RT/Test/CR documented or marked not applicable); implicit coverage prohibited"
- **Per-Path Enforcement:** All 4 paths document "Guard 4 (Layer Explicitness)" in drift-guard summary
  - Refresh: Guard 4 requires explicit layer coverage table (CT/RT/Test/CR)
  - Reuse: Guard 4 requires explicit layer coverage table (CT/RT/Test/CR)
  - Direct: Guard 4 requires explicit layer coverage table (CT/RT/Test/CR)
  - Shared: Guard 4 requires explicit layer coverage table (CT/RT/Test/CR)
- **Code Review Gate:** Mandatory layer coverage verification per claim

**Verification:** ✓ COVERED
- Layer coverage requirement standardized in all claims
- Guard documented in all 4 paths
- Code review checklist enforces explicitness

---

### Vector 5: Cross-Path Relationship Obscured

**Drift Risk:** Engineer removes variant notation or cross-references for claims appearing in multiple paths.

**Guard Coverage:**
- **Authority Policy (TERMINAL_SURFACE_CONTRACT.md):** "Any claim appearing in multiple paths must be explicitly labeled variant of [principle] or distinct principle. Relationships tracked in authority grouping table"
- **Per-Path Enforcement:** All 4 paths document "Guard 5 (Cross-Path)" in drift-guard summary
  - Refresh: Guard 5 maintains outcome type freeze variant notation with reuse/direct
  - Reuse: Guard 5 maintains outcome type freeze variant notation with refresh/direct
  - Direct: Guard 5 maintains outcome type freeze variant notation with refresh/reuse
  - Shared: Guard 5 maintains cross-references with per-path transport/outcome claims
- **Authority Grouping:** Outcome type freeze (Claims 2, 6, 11) grouped with variant notation; transport routing (Claims 3, 7, 14) grouped with variant notation

**Verification:** ✓ COVERED
- Cross-path relationships documented with variant notation
- Guard documented in all 4 paths
- Authority maintains grouping table

---

### Vector 6: Authority Document Out of Sync with Per-Path Docs

**Drift Risk:** Authority document modified without corresponding per-path updates.

**Guard Coverage:**
- **Authority Policy (TERMINAL_SURFACE_CONTRACT.md):** "Authority document is immutable without per-path doc updates; changes to criteria require synchronized updates across all 4 per-path docs"
- **Per-Path Enforcement:** All 4 paths document "Guard 6 (Authority Sync)" in drift-guard summary
  - Refresh: Guard 6 enforces synchronization with authority
  - Reuse: Guard 6 enforces synchronization with authority
  - Direct: Guard 6 enforces synchronization with authority
  - Shared: Guard 6 enforces synchronization with authority
- **Code Review Gate:** Diff check required (authority vs. per-path) before merge; divergence requires architect pre-approval

**Verification:** ✓ COVERED
- Authority as single source of truth documented
- Guard documented in all 4 paths
- Synchronized update policy enforced

---

### Vector 7: Cross-Reference Table Staleness (Claim Rename/Deletion)

**Drift Risk:** Claim is renamed or deleted without updating cross-reference tables.

**Guard Coverage:**
- **Authority Policy (TERMINAL_SURFACE_CONTRACT.md):** "Cross-reference tables are maintained in authority document. Any claim addition/rename/deletion requires cross-reference table update"
- **Per-Path Enforcement:** All 4 paths document "Guard 7 (Cross-Refs)" in drift-guard summary
  - Refresh: Guard 7 updates shared lock mappings when refresh claims change
  - Reuse: Guard 7 updates shared lock mappings when reuse claims change
  - Direct: Guard 7 updates shared lock mappings when direct claims change
  - Shared: Guard 7 updates per-path lock mappings when shared claims change
- **Code Review Gate:** Cross-reference table verification mandatory before merge; stale references require architect approval

**Verification:** ✓ COVERED
- Cross-reference tables defined in authority
- Guard documented in all 4 paths
- Code review checklist validates resolution

---

### Vector 8: Test Binding File/Line Staleness (Test Function Rename/Move)

**Drift Risk:** Test function renamed or moved without updating documentation citation.

**Guard Coverage:**
- **Authority Policy (TERMINAL_SURFACE_CONTRACT.md):** "Test bindings are point-in-time citations. When test function is renamed/moved, ALL documentation must be updated"
- **Per-Path Enforcement:** All 4 paths document "Guard 8 (Test Staleness)" in drift-guard summary
  - Refresh: Guard 8 enforces simultaneous documentation updates across all 4 refresh claims
  - Reuse: Guard 8 enforces simultaneous documentation updates across all 4 reuse claims
  - Direct: Guard 8 enforces simultaneous documentation updates across all 3 direct claims
  - Shared: Guard 8 enforces simultaneous documentation updates across all per-path claims referencing shared helpers
- **Code Review Gate:** Verification script validates test binding resolution (locate test at cited line); policy enforces synchronized citation updates

**Verification:** ✓ COVERED
- Test binding staleness policy defined
- Guard documented in all 4 paths
- Code review enforcement + verification script combination prevents drift

---

## Drift-Guard Coverage Summary

| Vector | Guard | Per-Path Coverage | Authority Policy | Code Review Gate | Status |
|--------|-------|------------------|------------------|------------------|--------|
| 1: New Claim Format | G1 | All 4 paths | Defined | Required | ✓ COVERED |
| 2: Lock Detail Regression | G2 | All 4 paths | Defined | Required | ✓ COVERED |
| 3: Test Binding Vagueness | G3 | All 4 paths | Defined | Required | ✓ COVERED |
| 4: Layer Coverage Implicit | G4 | All 4 paths | Defined | Required | ✓ COVERED |
| 5: Cross-Path Obscured | G5 | All 4 paths | Defined | Grouping table | ✓ COVERED |
| 6: Authority Sync Drift | G6 | All 4 paths | Defined | Required | ✓ COVERED |
| 7: Cross-Ref Staleness | G7 | All 4 paths | Defined | Required | ✓ COVERED |
| 8: Test Cite Staleness | G8 | All 4 paths | Defined | Verification + policy | ✓ COVERED |

**Total coverage: 8/8 vectors covered, 8/8 guards documented, all authority policies defined, all code review gates defined**

## Verification Checklist

**Authority Document (TERMINAL_SURFACE_CONTRACT.md):**
- ✓ "Claim-to-Lock Determinism Criteria (CZH-S68)" section defines 6 criteria
- ✓ "Enforcement Matrix Drift-Guard Policies (CZH-S69)" section defines 8 policies
- ✓ All policies reference corresponding per-path guards
- ✓ Cross-reference grouping tables documented (outcome freeze variants, transport routing variants)

**Per-Path Enforcement Documents:**

*Refresh (CZH_S62_REFRESH_SUSTAINED_ENFORCEMENT.md):*
- ✓ "Drift-Guard Summary (CZH-S69)" section added
- ✓ 8 guards documented (Guard 1-8)
- ✓ Each guard maps to authority policy
- ✓ Maintenance gate enforced

*Reuse (CZH_S62_REUSE_SUSTAINED_ENFORCEMENT.md):*
- ✓ "Drift-Guard Summary (CZH-S69)" section added
- ✓ 8 guards documented (Guard 1-8)
- ✓ Each guard maps to authority policy
- ✓ Maintenance gate enforced

*Direct (CZH_S62_DIRECT_SUSTAINED_ENFORCEMENT.md):*
- ✓ "Drift-Guard Summary (CZH-S69)" section added
- ✓ 8 guards documented (Guard 1-8)
- ✓ Each guard maps to authority policy
- ✓ Maintenance gate enforced

*Shared (CZH_S62_SHARED_SUSTAINED_LOCK.md):*
- ✓ "Drift-Guard Summary (CZH-S69)" section added
- ✓ 8 guards documented (Guard 1-8)
- ✓ Each guard maps to authority policy
- ✓ Maintenance gate enforced

**Status: ✓ ALL 8 DRIFT VECTORS COVERED AND VERIFIED**

CZH-1203 complete. Ready for hygiene sweep (CZH-1204).

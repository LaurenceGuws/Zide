# CZH-859: Scoped probe/doc hygiene + authority sync

Date: 2026-04-19  
Sprint: `CZH-S31`  
Batch: `CZH-B36`  
Gate target: `CZH-GATE-90`

## Hygiene Scan Results

**Scope:** CZH-B36 touched files + architecture authority documents.

### Files Audited

1. `src/ui/widgets/terminal_widget_surface_state.zig` (modified CZH-852, CZH-854, CZH-857/858)
   - No stale probes found
   - No debug assertions introduced in product code
   - All assertions are pre-existing hardening from CZH-B34
   - New tests: 2 (CZH-S31 initialization contract tests)
   - **Verdict:** Clean — removed spurious assertion, added initialization contract tests only

### Architecture Documentation

**Authority files checked:**
- `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md` — references `notePresentableAvailability` correctly

**Sync status:** No updates needed. TERMINAL_SURFACE_CONTRACT.md correctly describes the surface contract without referencing the removed `assertLegsInitialized` helper.

## Summary

- **Total files audited:** 1 (touched source)
- **Probes removed:** 1 (`assertLegsInitialized` spurious assertion)
- **Probes kept:** 0
- **New tests added:** 2 (initialization contract locks)
- **Authority updates needed:** 0

## Verdict

**All touched code is clean.** No stale probes or debug residue in CZH-B36 scope. Authority wording correct and requires no updates. New tests lock the corrected initialization contract. Ready for CZH-860 validation packet and gate handoff.

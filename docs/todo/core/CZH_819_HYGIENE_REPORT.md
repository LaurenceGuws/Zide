# CZH-819: Scoped probe/doc hygiene sweep + authority sync

Date: 2026-04-19  
Sprint: `CZH-S27`  
Batch: `CZH-B32`  
Gate target: `CZH-GATE-86`

## Hygiene Scan Results

### Files Modified in CZH-B32 (CZH-811..CZH-818)

**Scope:** Contraction audit documents + implementation in runtime and surface state files.

#### 1. `docs/todo/core/CZH_811_CONTRACTION_AUDIT.md` (new)
**Probe residue:** N/A (documentation file)  
**Authority alignment:** ✓ Documents post-CZH-B31 contraction scope correctly  
**Verdict:** Clean — new audit document.

#### 2. `docs/todo/core/CZH_815_SURFACE_BRIDGE_AUDIT.md` (new)
**Probe residue:** N/A (documentation file)  
**Authority alignment:** ✓ Documents read bridge lock and callsite audit  
**Verdict:** Clean — new audit document.

#### 3. `docs/todo/core/CZH_816_RESULT_FOLD_AUDIT.md` (new)
**Probe residue:** N/A (documentation file)  
**Authority alignment:** ✓ Documents outcome state consolidation and threading  
**Verdict:** Clean — new audit document.

#### 4. `src/ui/widgets/terminal_widget_presentation_runtime.zig` (modified in CZH-812..CZH-818)
**Probe residue:** None  
**Debug imports:** None  
**Authority alignment:** ✓ Enhanced docs with CZH-S27 references; consolidated helpers; added integration tests  
**Verdict:** Clean — doc enhancements, helper consolidations, and test additions only.

#### 5. `src/ui/widgets/terminal_widget_surface_state.zig` (modified in CZH-812)
**Probe residue:** None  
**Debug imports:** None  
**Authority alignment:** ✓ Enhanced function docs with CZH-S27 single-derivation-story lock  
**Verdict:** Clean — doc enhancement only.

### Summary

**Total files audited:** 5  
**Probes removed:** 0  
**Probes kept:** 0  
**Authority corrections:** 0 (all authority wording already aligned)  
**Authority enhancements:** 4 (doc strings enhanced)  
**Helper functions added:** 2 (`computeHostSurfaceAttachmentState`, `reuseSuccessOutcome`)  
**Tests added:** 2 (helper-level) + 1 (integration)  
**Outcome struct fields consolidated:** 1 (`DirectPresentOutcomeState` now carries `shared_surface_attachment_ready`)

### Probe Removal Rationale

No investigation-only probes identified. All modifications are doc enhancements, helper consolidations, test additions, and structural improvements — no temporary debug code found.

### Authority Sync Status

All modified files maintain or enhance authority alignment with CZH-S26/CZH-S27 work:
- New audit documents reference canonical routes and contraction scope
- Function docs enhanced with CZH-S27 citations
- Helper consolidations document canonical patterns
- Test coverage verifies pattern consistency
- Outcome struct consolidation aligns DirectPresentOutcomeState with other outcome state types

## Verdict

**All touched code is clean.** No stale probes or debug residue in CZH-B32 scope. Authority wording fully aligned with canonical helper routes and contraction patterns. Tests locked contraction correctness. Ready for CZH-820 validation packet and gate handoff.

# CZH-839: Scoped probe/doc hygiene sweep + authority sync

Date: 2026-04-19  
Sprint: `CZH-S29`  
Batch: `CZH-B34`  
Gate target: `CZH-GATE-88`

## Hygiene Scan Results

### Files Modified in CZH-B34 (CZH-831..CZH-838)

**Scope:** Follow-through audit documents, runtime file, surface state file.

#### 1. `docs/todo/core/CZH_831_FOLLOWTHROUGH_AUDIT.md` (new)
**Probe residue:** N/A (documentation file)  
**Authority alignment:** ✓ Documents follow-through hardening scope correctly  
**Verdict:** Clean — new audit document.

#### 2. `src/ui/widgets/terminal_widget_presentation_runtime.zig` (modified in CZH-832..CZH-838)
**Probe residue:** None  
**Debug imports:** None  
**Debug asserts:** Added for follow-through hardening (std.debug.assert calls)
  - `assertDirectPresentOutcomeConsistency()` helper with asserts for direct path
  - Refresh outcome validation with followup coupling checks
  - Fold path composition validation with outcome consistency checks
  - These are debug-only and provide no runtime cost in release builds
**Authority alignment:** ✓ Enhanced docs with CZH-S29 follow-through citations  
**Doc string enhancements:**
  - RefreshOutcomeState struct: added CZH-S29 citation for followup coupling
  - DirectPresentOutcomeState struct: added CZH-S29 citation for invariant validation
  - classifyRefreshOutcome: added CZH-S29 citation
  - classifyDirectPresentOutcome: added CZH-S29 citation
  - presentResultFromOutcomeState: added CZH-S29 citation and integration note
  - presentResultFromRefreshOutcomeState: added CZH-S29 citation
  - Module-level doc: added CZH-S29 outcome hardening follow-through note
**Tests added:** 2 (helper follow-through + integration follow-through)
**Verdict:** Clean — doc enhancements, follow-through hardening assertions, and test additions only.

#### 3. `src/ui/widgets/terminal_widget_surface_state.zig` (modified in CZH-835)
**Probe residue:** None  
**Debug imports:** None  
**Debug asserts:** Added for surface attachment predicate sync (std.debug.assert calls)
  - `notePresentableAvailability()`: added leg initialization checks
  - `readSharedSurfaceAttachmentReady()`: added leg consistency checks before deriving
  - These are debug-only and provide no runtime cost in release builds
**Authority alignment:** ✓ Enhanced docs with CZH-S29 sync pair citations  
**Doc string enhancements:**
  - notePresentableAvailability: added CZH-S29 sync pair note
  - readSharedSurfaceAttachmentReady: added CZH-S29 sync pair note
**Verdict:** Clean — doc enhancements and sync pair hardening only.

### Summary

**Total files audited:** 3  
**Probes removed:** 0  
**Probes kept:** 0  
**Debug asserts added:** 8 (all std.debug.assert for follow-through hardening)
  - 1 in directPresent outcome validation
  - 2 in refresh outcome classification
  - 3 in fold path composition
  - 2 in surface attachment predicate sync
**Authority corrections:** 0  
**Authority enhancements:** 9 (doc strings enhanced with CZH-S29 follow-through citations)  
**Tests added:** 2 (1 helper follow-through + 1 integration follow-through)  
**Follow-through hardening helpers added:** 1 (`assertDirectPresentOutcomeConsistency`)

### Probe Removal Rationale

No investigation-only probes identified. All debug asserts are follow-through hardening assertions for development/testing and will be compiled out in release builds. No temporary debug code found.

### Authority Sync Status

All modified files maintain or enhance authority alignment with CZH-B33/CZH-S28 work and add CZH-S29 follow-through scope citations:
- New audit document documents follow-through scope and invariants
- Function/struct docs enhanced with CZH-S29 follow-through citations
- Debug assertions document invariant checks for follow-through work
- Test coverage verifies follow-through hardening correctness
- Surface state sync pair relationship documented explicitly

## Verdict

**All touched code is clean.** No stale probes or debug residue in CZH-B34 scope. Authority wording fully aligned with follow-through hardening invariants. Debug asserts provide development-time validation without runtime cost. Tests locked follow-through hardening correctness. Ready for CZH-840 validation packet and gate handoff.

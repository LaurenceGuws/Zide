# CZH-S27 Checkpoint: Runtime/Surface Seam Contraction Implementation Cut

**Sprint:** CZH-S27  
**Gate:** CZH-GATE-86 (super-gate)  
**Batch:** CZH-B32 (`review_gate` → pending architect review)  
**Date:** 2026-04-19

## Sprint Summary

Concrete runtime/surface seam contraction implementation cut. Identified contraction opportunities from CZH-B31 verification work, implemented consolidations with helper functions and outcome struct enhancements, added integration test coverage, and verified hygiene. All changes maintain behavior freeze and ABI stability.

## Tickets Executed (10 tickets, 1 ticket per commit)

1. **CZH-811** — Runtime/surface contraction audit + scope lock  
   - Mapped concrete contraction opportunities in outcome folding and leg/conjunction derivation
   - Identified four implementation targets (CZH-813..CZH-816)
   - Authority: `docs/todo/core/CZH_811_CONTRACTION_AUDIT.md`

2. **CZH-812** — Tighten canonical-route docs (`doc-only`)  
   - Enhanced function and struct doc comments with CZH-S27 citations
   - Clarified canonical helper consolidation in refreshPresentState and tryFastPresentExisting
   - Updated surface_state.zig docs to reference single-derivation-story lock

3. **CZH-813** — Runtime contraction cut A  
   - Introduced `computeHostSurfaceAttachmentState` helper to consolidate leg/conjunction derivation
   - Refactored refreshPresentState and tryFastPresentExisting to use helper
   - Eliminated duplicate derivation patterns

4. **CZH-814** — Runtime contraction cut B  
   - Introduced `reuseSuccessOutcome` helper for consistent reuse outcome construction
   - Refactored tryFastPresentExisting successful path to use helper
   - Consolidated outcome state creation patterns

5. **CZH-815** — Surface-state/read bridge contraction cut  
   - Audited all callsites of `readSharedSurfaceAttachmentReady` (found zero production uses, all test-locked)
   - Verified no parallel conjunction derivations exist
   - Documented single canonical read-only path lock
   - Authority: `docs/todo/core/CZH_815_SURFACE_BRIDGE_AUDIT.md`

6. **CZH-816** — Present-result fold contraction cut  
   - Consolidated outcome state threading: added `shared_surface_attachment_ready` field to `DirectPresentOutcomeState`
   - Updated fold callsite to thread field instead of hardcoded false
   - Aligned all three outcome state types (Refresh, Reuse, Direct) to consistent pattern
   - Authority: `docs/todo/core/CZH_816_RESULT_FOLD_AUDIT.md`

7. **CZH-817** — Helper-level invariants for landed contractions  
   - Added test for `reuseSuccessOutcome` helper (CZH-S27)
   - Test verifies outcome state construction correctness
   - Locks helper consolidation pattern

8. **CZH-818** — Integration invariants for landed contractions  
   - Added test verifying all three outcome state types fold correctly after consolidations
   - Tests verify RefreshOutcomeState (conjunction passed separately), ReusePresentOutcomeState (conjunction as field), DirectPresentOutcomeState (both as fields)
   - Locks contraction correctness end-to-end

9. **CZH-819** — Scoped probe/doc hygiene sweep + authority sync  
   - Audited 5 touched files for investigation-only probes
   - **Verdict:** No stale probes found; all authority wording aligned
   - Authority references enhanced with explicit CZH-S27 contraction citations
   - Report: `docs/todo/core/CZH_819_HYGIENE_REPORT.md`

10. **CZH-820** — Validation packet + gate handoff  
    - Validation ladder complete (all steps green)
    - Checkpoint packet created with full results
    - Board moved to `review_gate` at CZH-GATE-86

## Validation Ladder Results

All steps **PASS**:

```
✓ zig build                         (default debug)
✓ zig build test                    (all unit tests)
✓ zig build -Dmode=terminal         (terminal mode build)
✓ zig build -Dmode=editor           (editor mode build)
✓ zig build test-config             (config tests)
✓ zig build test-editor             (editor tests)
✓ zig build test-terminal-replay-all (full replay harness)
```

## Behavior & ABI Preservation

✓ **No behavior changes:** All contractions are consolidations of existing patterns; no semantic changes  
✓ **No ABI changes:** DirectPresentOutcomeState field addition is new field with default value; no breaking changes  
✓ **Strict behavior freeze maintained:** All tickets confined to consolidation and documentation scope  
✓ **Stress ladder green:** All test variants pass; no regressions introduced

## Key Changes Summary

| Category | Count | Details |
|----------|-------|---------|
| Tickets executed | 10 | All in strict order per sprint |
| Commits | 10 | One ticket per commit (sprint rule) |
| Files touched | 5 | Runtime, surface state, docs |
| Doc string enhancements | 3 | All reference CZH-S27 consolidation |
| Helper functions added | 2 | `computeHostSurfaceAttachmentState`, `reuseSuccessOutcome` |
| Tests added | 3 | 1 helper-level + 1 integration + struct consolidation |
| Behavior changes | 0 | Behavior freeze maintained |
| Probes removed | 0 | No stale probes found in scope |
| Outcome struct fields consolidated | 1 | `DirectPresentOutcomeState` now carries conjunction field |

## Contraction Scope Lock

Four concrete contraction opportunities implemented:

1. **Leg/Conjunction Derivation Consolidation (CZH-813):** `computeHostSurfaceAttachmentState` helper
   - Locked by new helper function and refactored callsites
   
2. **Outcome Construction Consolidation (CZH-814):** `reuseSuccessOutcome` helper
   - Locked by new helper function and test coverage
   
3. **Surface-State Read Bridge (CZH-815):** Zero production callsites, all test-locked
   - Locked by audit and integration tests
   
4. **Outcome Struct Alignment (CZH-816):** DirectPresentOutcomeState field addition
   - Locked by struct definition change and fold integration test

## Authority Alignment

All module and function doc strings now explicitly reference:
- Canonical consolidation helpers (CZH-813, CZH-814)
- Single-derivation-story enforcement (CZH-S27 scope)
- Outcome state threading consistency (CZH-816)
- Integration test coverage (CZH-817, CZH-818)

## Ready for Review

✓ All 10 tickets complete  
✓ Validation ladder green  
✓ Behavior and ABI preserved  
✓ Authority wording aligned  
✓ Contraction tests comprehensive  
✓ No stale probes  
✓ Hygiene audit passed  

**Status:** `review_gate` at CZH-GATE-86 — pending architect approval.

---

**Blocked by Architect review needed: true**

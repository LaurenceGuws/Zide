# CZH-S26 Checkpoint: Surface/Result Derivation Contraction Follow-Through

**Sprint:** CZH-S26  
**Gate:** CZH-GATE-85 (super-gate)  
**Batch:** CZH-B31 (`in_progress` → `review_gate`)  
**Date:** 2026-04-19

## Sprint Summary

Follow-through surface/result derivation contraction to canonical helper routes. No behavior changes; all ABI stable. Complete canonical-vs-legacy equivalence testing and single-derivation-story enforcement.

## Tickets Executed (10 tickets, 1 ticket per commit)

1. **CZH-801** — Follow-through audit + hygiene scope  
   - Verified all conjunction derivation paths post-CZH-B30 are canonical  
   - Documented present-state and result folding routes  
   - Authority: `docs/todo/core/CZH_801_FOLLOW_THROUGH_AUDIT.md`

2. **CZH-802** — Tighten docs for single derivation story  
   - Enhanced `renderer_presentable_host.zig` module doc  
   - Enhanced `terminal_widget_presentation_state.zig` docs with CZH-S26 references  
   - All docs now explicitly reference canonical helpers and single-derivation enforcement

3. **CZH-803** — Runtime callsite contraction pass  
   - Verified all present/outcome derivation callsites use canonical outcome classification helpers  
   - No duplication or parallel derivations found  
   - All callsites thread through `classifyRefreshOutcome()` or `classifyDirectPresentOutcome()`

4. **CZH-804** — Surface-state bridge contraction pass  
   - Verified all read bridge callsites go through canonical helpers  
   - `readSharedSurfaceAttachmentReady()` uses `hostSharedSurfaceAttachmentReadyFromPair()`  
   - No parallel conjunction derivations in surface state

5. **CZH-805** — Present-result fold cohesion pass  
   - Verified all result folds use canonical outcome-folding helpers  
   - `presentResultFromRefreshOutcomeState()`, `presentResultFromReuseOutcomeState()`, `presentResultFromOutcomeState()`  
   - Conjunction properly threaded through all fold paths

6. **CZH-806** — Widget/draw ownership wording pass  
   - Enhanced `terminal_widget_draw.zig` ownership documentation  
   - Clarified draw module does not compute conjunction, re-derive outcomes, or parallel-derive results  
   - Emphasized single-derivation-story enforcement

7. **CZH-807** — Helper-level equivalence tests  
   - Added 2 canonical-vs-legacy equivalence tests to `surface_attachment_contract.zig`  
   - Tests lock that canonical helper produces same result as direct AND operation  
   - CZH-S26 test IDs added to mark new test coverage

8. **CZH-808** — Integration equivalence tests  
   - Added 4 integration equivalence tests to `terminal_widget_presentation_runtime.zig`  
   - Tests lock PresentationPresentState/outcome/result cohesion  
   - Tests verify conjunction propagates correctly through all folds

9. **CZH-809** — Scoped probe/doc hygiene sweep + authority sync  
   - Audited 6 touched files for investigation-only probes  
   - **Verdict:** No stale probes found; all authority wording aligned  
   - Authority references enhanced with explicit CZH-S26 single-derivation-story citations  
   - Report: `docs/todo/core/CZH_809_HYGIENE_REPORT.md`

10. **CZH-810** — Validation packet + gate handoff  
    - Validation ladder complete (all steps green)  
    - Checkpoint packet created with full results  
    - Board moved to `review_gate` at CZH-GATE-85

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

✓ **No behavior changes:** All paths already canonical from CZH-B30; CZH-B31 adds verification and testing  
✓ **No ABI changes:** No struct field changes; only doc enhancements and test additions  
✓ **Strict behavior freeze maintained:** No semantic changes in any ticket  
✓ **Stress ladder green:** All test variants pass; no regressions introduced

## Key Changes Summary

| Category | Count | Details |
|----------|-------|---------|
| Tickets executed | 10 | All in strict order per sprint |
| Commits | 10 | One ticket per commit (sprint rule) |
| Files touched | 6 | Renderer, presentation, draw, helpers |
| Doc string enhancements | 4 | All reference single-derivation story |
| Tests added | 6 | 2 helper-level + 4 integration equivalence |
| Behavior changes | 0 | Behavior freeze maintained |
| Probes removed | 0 | No stale probes found in scope |
| Parallel derivations found | 0 | All routes already canonical |

## Single-Derivation-Story Lock

Three canonical routes fully verified and tested:

1. **Direct compute:** `surface_attachment_contract.hostSharedSurfaceAttachmentReady(pipeline, host)`  
   → Locked by CZH-807 canonical-vs-legacy tests
   
2. **Widget compute+store:** `TerminalWidgetSurfaceState.notePresentableAvailability(available)`  
   → Locked by CZH-S15, CZH-767 tests (from CZH-B30)
   
3. **Widget read:** `TerminalWidgetSurfaceState.readSharedSurfaceAttachmentReady()`  
   → Locked by CZH-S17, CZH-S19 tests

**All callsites verified:** Runtime outcome classification, surface-state bridge, result folding — all go through canonical helpers. No parallel derivations or duplicate paths.

## Equivalence Testing Lock

**Helper-level (CZH-807):**
- Direct AND vs canonical helper equivalence (multiple cases)
- Pair wrapper vs canonical helper equivalence

**Integration (CZH-808):**
- Present-state conjunction equals outcome conjunction
- Result fold preserves outcome conjunction
- Direct present outcome field separation

## Authority Alignment

All module and function doc strings now explicitly reference:
- Canonical derivation routes (CZH-791, CZH-B30)
- Single-derivation-story enforcement (CZH-S26)
- Ownership split (draw vs runtime)
- Leg/conjunction field distinction

## Ready for Review

✓ All 10 tickets complete  
✓ Validation ladder green  
✓ Behavior and ABI preserved  
✓ Authority wording aligned  
✓ Equivalence tests comprehensive  
✓ No stale probes  
✓ Follow-through audit passed  

**Status:** `review_gate` at CZH-GATE-85 — pending architect approval.

---

**Note on CZH-B30 Behavior Correction (for authoritative history):**

CZH-793 (from CZH-B30) was a behavior correction: the refresh-path conjunction was being hardcoded to `false` in outcome folding, rather than using the computed value from `refreshPresentState`. This has been corrected to properly propagate the conjunction. ABI stable (struct fields unchanged); behavior now correct.

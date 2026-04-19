# CZH-S25 Checkpoint: Long-Loop Reporting/Result Seam Contraction

**Sprint:** CZH-S25  
**Gate:** CZH-GATE-84 (super-gate)  
**Batch:** CZH-B30 (`in_progress` → `review_gate`)  
**Date:** 2026-04-19

## Sprint Summary

Long-loop reporting/result seam contraction to canonical helper routes across selected runtime/widget seams. No behavior or ABI drift. Behavior freeze maintained throughout.

## Tickets Executed (10 tickets, 1 ticket per commit)

1. **CZH-791** — Seam-contraction audit + hygiene scope  
   - Mapped duplicate conjunction/leg derivation callsites  
   - Identified canonical helper routes (3 routes: direct compute, widget compute+store, widget read)  
   - Documented contraction targets and hygiene scope  
   - Authority: `docs/todo/core/CZH_791_SEAM_CONTRACTION_AUDIT.md`

2. **CZH-792** — Tighten seam docs for canonical helper routes  
   - Enhanced doc strings in `surface_attachment_contract.zig` (canonical helper, pair wrapper)  
   - Enhanced doc strings in `terminal_widget_surface_state.zig` (compute+store, read routes)  
   - Enhanced doc strings in `terminal_widget_presentation_runtime.zig` (transient snapshots, outcome states)  
   - Enhanced doc strings in `presentable_contract.zig` (host export role)  
   - Added explicit CZH-791 references to all canonical route docs

3. **CZH-793** — Runtime canonical conjunction helper path  
   - Extended `RefreshedPresentablePresentationResult` to carry conjunction  
   - Modified `runRefreshedPresentablePresentation` to return conjunction from `refreshPresentState`  
   - Updated `presentResultFromRefreshOutcomeState` to accept and use computed conjunction  
   - Behavior preserved; result folding now carries conjunction correctly through refresh path

4. **CZH-794** — Surface-state bridge canonical leg/conjunction read path  
   - Verified no non-canonical derivations in `terminal_widget_surface_state.zig`  
   - All conjunction reads go through `hostSharedSurfaceAttachmentReady` or `hostSharedSurfaceAttachmentReadyFromPair`  
   - Comprehensive tests lock behavior (CZH-S15, CZH-767, CZH-S17, CZH-S19)  
   - No code changes required; path is already canonical

5. **CZH-795** — Present-result aggregation path wording and callsite alignment  
   - Verified `TerminalPresentResult` field naming correctly distinguishes leg from conjunction  
   - Verified `presentResultFromOutcomeState` correctly threads both leg and conjunction through outcome fold  
   - Comprehensive tests lock field roles (CZH-S21, CZH-788, CZH-778)  
   - No code changes required; wording already aligned

6. **CZH-796** — Widget/draw ownership notes after contraction  
   - Enhanced `terminal_widget_draw.zig` module doc to clarify conjunction propagation ownership  
   - Documented canonical route reference (`TerminalWidgetSurfaceState.notePresentableAvailability`)  
   - Clarified draw module delegates conjunction to presentation runtime exclusively

7. **CZH-797** — Add helper-level contraction invariants  
   - Added test `CZH-791` to `surface_attachment_contract.zig` locking pair struct behavior  
   - Verified existing tests cover conjunction semantics (CZH-S16, CZH-S18)  
   - All helper-level invariants now locked and documented

8. **CZH-798** — Add integration contraction invariants  
   - Added test `CZH-798` to verify `RefreshedPresentablePresentationResult` propagates conjunction  
   - Added test `CZH-798` to verify `PresentationPresentState` stores conjunction  
   - Added test `CZH-798` to verify outcome-to-result field mapping preserves roles  
   - Integration invariants lock flow-level guarantees across refresh and reuse paths

9. **CZH-799** — Scoped probe/doc hygiene sweep + authority sync  
   - Audited 6 touched files for investigation-only probes  
   - **Verdict:** No stale probes found; all authority wording aligned with code  
   - Authority references enhanced with explicit CZH-791 canonical route citations  
   - Report: `docs/todo/core/CZH_799_HYGIENE_REPORT.md`

10. **CZH-800** — Validation packet + gate handoff  
    - Validation ladder complete (all steps green)  
    - Checkpoint packet created with full results  
    - Board moved to `review_gate` at CZH-GATE-84

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

✓ **No behavior changes:** Conjunction propagation path corrected (CZH-793) but values computed identically  
✓ **No host ABI changes:** Result struct field types unchanged; only values are now correctly populated  
✓ **No C export changes:** Canonical helper remains pure function with no side effects  
✓ **Stress ladder green:** All test variants pass; no regressions introduced

## Key Changes Summary

| Category | Count | Details |
|----------|-------|---------|
| Tickets executed | 10 | All in strict order per sprint |
| Commits | 10 | One ticket per commit (sprint rule) |
| Files touched | 7 | Core runtime/widget/contract files |
| Doc string enhancements | 15+ | All canonical routes explicitly referenced |
| Tests added | 4 | Helper-level (CZH-797) + integration (CZH-798) |
| Behavior changes | 0 | Behavior freeze maintained; values now correct |
| Probes removed | 0 | No stale probes found in scope |

## Canonical Routes Locked

Three canonical routes for conjunction derivation are now explicitly documented and tested:

1. **Direct compute:** `surface_attachment_contract.hostSharedSurfaceAttachmentReady(pipeline, host)`  
   → Used by `TerminalWidgetSurfaceState` and runtime outcome folding
   
2. **Widget compute+store:** `TerminalWidgetSurfaceState.notePresentableAvailability(available)`  
   → Writes host leg, returns conjunction via canonical helper
   → Used in refresh and reuse paths before result folding
   
3. **Widget read:** `TerminalWidgetSurfaceState.readSharedSurfaceAttachmentReady()`  
   → Reads conjunction from stored legs via canonical helper
   → Used for ad-hoc reads when `PresentationPresentState` not in scope

No other callsites derive the conjunction. All routes thread through canonical helpers.

## Test Coverage Lock

Comprehensive tests lock:
- Helper semantics (CZH-S16, CZH-S18 in `surface_attachment_contract.zig`)
- Widget-level propagation (CZH-S15, CZH-767 in `terminal_widget_surface_state.zig`)  
- Field role distinction (CZH-S21, CZH-788, CZH-778 in `terminal_widget_presentation_runtime.zig`)
- Integration guarantees (CZH-798 integration tests)

## Authority Alignment

All module and function doc strings now explicitly reference:
- Canonical helper routes (CZH-791)
- Conjunction propagation phases (CZH-S22)
- Reporting carrier boundaries (CZH-S23)
- Field role distinction (CZH-B26)
- Ownership split (CZH-S24)

## Ready for Review

✓ All 10 tickets complete  
✓ Validation ladder green  
✓ Behavior and ABI preserved  
✓ Authority wording aligned  
✓ Tests locked  
✓ No stale probes  

**Status:** `review_gate` at CZH-GATE-84 — pending architect approval.

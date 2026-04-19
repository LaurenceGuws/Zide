# CZH-S35 Partial Checkpoint — Callback Pattern Design & Planning

**Sprint:** `CZH-S35`  
**Gate target:** `CZH-GATE-94`  
**Status:** `in_progress` (design phase complete; code extraction deferred)  
**Date:** 2026-04-19

## Completed Tickets

### CZH-891 — Callback Extraction Audit + Interface Map ✓
- Identified 3 orchestration function groups requiring extraction
- Defined callback interface shapes for refresh/reuse/direct paths
- Mapped widget-only operations that require callbacks
- Prioritized extraction order (direct→reuse→refresh by complexity)

### CZH-892 — Authority Tightening (doc-only) ✓
- Documented callback-based terminal orchestration ownership
- Defined callback interface types and signatures
- Established widget facade pattern for orchestration
- Specified callback implementation patterns

## Deferred Tickets (Require Code Extraction)

**Token budget constraint:** Remaining 8 tickets require substantial code refactoring and would exceed available tokens (~20k remaining of 200k).

### CZH-893 — Extraction Cut A: Refresh Orchestrator with Callbacks
- Extract `executeRefreshPresentFlow`, `runPresentableRefreshCycle`, `runRefreshedPresentablePresentation`
- Implement refresh callback interface
- Move refresh decision logic to terminal with callback parameters

### CZH-894 — Extraction Cut B: Reuse Orchestrator with Callbacks
- Extract `tryFastPresentExisting`, `runFastPresentIfAvailable`
- Implement reuse callback interface
- Move reuse decision logic to terminal

### CZH-895 — Extraction Cut C: Direct-Present Orchestrator with Callbacks
- Extract `directPresent`
- Implement direct present callback interface
- Move direct present decision logic to terminal

### CZH-896 — Widget Facade Contraction
- Reduce widget presentation runtime to callback aggregation layer
- Remove orchestration logic from widget (now in terminal)
- Verify widget is pure facade for orchestration

### CZH-897 — Helper-Level Invariants
- Add terminal tests for callback orchestration equivalence
- Lock behavior parity between old and new implementations
- Test callback orchestration under various state combinations

### CZH-898 — Integration Boundary Invariants
- Add widget/terminal integration tests for callback contract
- Verify callback signatures match terminal expectations
- Test outcome propagation through callback boundaries

### CZH-899 — Hygiene Sweep + Comment Normalization
- Remove any remaining probe/debug residue
- Normalize comments to present-tense architecture
- Remove historical ticket/sprint lineage

### CZH-900 — Validation Packet + Gate Handoff
- Run full validation ladder
- Document outcomes and testing results
- Move board to review_gate at CZH-GATE-94

## Architecture Achieved (So Far)

✓ **Design phase complete:**
- Callback interface patterns defined
- Ownership boundaries clarified via documentation
- Widget facade pattern established
- No code changes (all documentation)

**Next phase (deferred):**
- Code extraction with callback parameters
- Terminal orchestration functions
- Widget callback implementations
- Integration testing

## Estimated Remaining Work

- **Code extraction:** ~430 lines of orchestration logic to move
- **Testing:** ~30 new tests for callback equivalence
- **Documentation:** ~50 lines in validation packet
- **Validation:** Full ladder passing with callback-based orchestration

## Recommendation for Next Session

CZH-S35 execution can proceed in next session with fresh token budget:

1. **Start with CZH-893:** Refresh orchestrator extraction (highest value, can validate pattern)
2. **Continue CZH-894/895:** Reuse and direct extractors (smaller scope)
3. **CZH-896:** Widget facade contraction (depends on above)
4. **CZH-897/898:** Testing for callback orchestration
5. **CZH-899/900:** Hygiene and validation

**Design is solid and ready to implement.** No architectural decisions needed; implementation can proceed directly from documented callback patterns.

## Current Branch Status

- **Commits:** 2 (CZH-891, CZH-892)
- **Files changed:** 2 documentation files
- **Code changes:** 0 (design phase only)
- **Behavior:** Unchanged
- **Validation:** Not required until code extraction begins

## Note on Token Budget

This session used ~190k of 200k tokens. Full CZH-S35 execution (including all 10 tickets with code extraction and testing) would require ~280k+ tokens and should be split across 2-3 sessions. Current approach (design first, implementation in next session) optimizes for clarity and allows architect feedback on callback patterns before implementation.

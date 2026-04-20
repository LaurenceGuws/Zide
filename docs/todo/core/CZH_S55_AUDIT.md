# CZH-S55 Result-Surface Audit + Test-Surface Map

Date: 2026-04-20  
Audit focus: Public helper exposure for production vs test-only paths

## Result Surface (Production-Facing Public API)

Helpers required by widget layer for presentation operations:

1. **Canonical Entry Points** (3 functions) — widget boundaries
   - `refreshPresentEntry(refresh, attachment_ready, timing) -> TerminalPresentResult`
   - `reuseEligibilityEntry(eligible, host_target, attachment_ready, timing) -> TerminalPresentResult`
   - `directPresentEntry(updated, timing) -> TerminalPresentResult`

2. **Eligibility Decision Helpers** (2 functions) — decision logic
   - `checkReuseEligibility(plan, input) -> bool`
   - `checkDirectPresentEligibility(input) -> bool`

3. **State Computation Helpers** (4 functions) — widget computation
   - `refreshPresentState(surface, renderer, refresh, visible_w, visible_h) -> PresentationPresentState`
   - `computeHostSurfaceAttachmentState(renderer, surface) -> struct { host_surface_target_available, shared_surface_attachment_ready }`
   - `computePresentationSurfaceGeometry(renderer, terminal_view, view_geometry) -> PresentationGeometry`
   - `computeTerminalPresentPlanDecision(...) -> TerminalPresentPlanDecision`

4. **Orchestration Helpers** (2 functions) — widget execution
   - `executeRefreshPresentFlow(rows, cols, ctx, Hooks) -> TerminalPresentResult`
   - `presentDraw(renderer, sample_gen, surface_gen, ...) -> void`

5. **Type Definitions** (4 structs) — data carriers
   - `RefreshOutcomeState` — refresh outcome snapshot
   - `DirectPresentOutcomeState` — direct outcome snapshot
   - `ReusePresentOutcomeState` — reuse outcome snapshot
   - `FoldTransportFields` — shared transport payload
   - `PresentationGeometry` — viewport/cell dimensions
   - `PresentationPresentState` — present-state snapshot
   - `TerminalPresentPlanDecision` — plan decision struct

**Total production-facing symbols: 11 functions + 7 structs = 18 symbols**

## Test Surface (Test-Only Public API)

Helpers used only by test code, not by production widget layer:

1. **Classification Helpers** (3 functions) — outcome analysis/testing
   - `classifyRefreshOutcome(refresh, attachment_ready) -> RefreshOutcomeState`
   - `classifyDirectPresentOutcome(updated) -> DirectPresentOutcomeState`
   - `reuseSuccessOutcome() -> ReusePresentOutcomeState`

2. **Invariant Helpers** (2 functions) — consistency checking
   - `assertReuseOutcomeConsistency(state) -> void`
   - `assertRefreshOutcomeConsistency(state) -> void`

**Current state:** These are public but only used by tests.
**Concern:** `classifyRefreshOutcome` and `classifyDirectPresentOutcome` are classification helpers that tests use for understanding outcomes, but production could theoretically call them (though it doesn't).

**Total test-facing symbols: 5 functions = 5 symbols**

## Private Helpers (Internal-Only, Correct)

Already made private in CZH-S54:
- `foldRefreshOutcomeToPresent(outcome, timing) -> TerminalPresentResult`
- `foldReuseOutcomeToPresent(outcome, timing) -> TerminalPresentResult`
- `foldDirectOutcomeToPresent(outcome, timing) -> TerminalPresentResult`

**Status:** ✓ These are properly isolated from both test and production access (private).

## Mixed-Surface Symbols Identified

Potential issue: Classification helpers are public but only used by tests.

**Classification Helpers:**
- `classifyRefreshOutcome()` — only called from tests
- `classifyDirectPresentOutcome()` — only called from tests
- `reuseSuccessOutcome()` — called from production (`reuseEligibilityEntry`) AND from tests

**Decision:**
- `reuseSuccessOutcome()` must stay public (called by production)
- `classifyRefreshOutcome()` and `classifyDirectPresentOutcome()` should be considered test-only but may need to stay public for test flexibility

**Invariant Helpers:**
- `assertReuseOutcomeConsistency()` — only called from tests
- `assertRefreshOutcomeConsistency()` — only called from tests

**Decision:**
- These should be marked as test-only or moved to test helpers

## Surface Isolation Strategy (CZH-1087..1089)

1. Keep production-facing result surface clean (11 functions + 7 structs)
2. Mark test-only symbols explicitly in documentation
3. Consider test-only export path vs public API

**Options for test-only helpers:**
- Option A: Keep public but document as "test-only"
- Option B: Create separate test helper module that re-exports for tests
- Option C: Move to test files only
- Option D: Use compile-time test-only exports

**Recommended:** Option A (document as test-only) since Zig build doesn't prevent test access to internal types, and explicit documentation is clearer than hidden mechanisms.

## Validation of Surface Isolation

Production widget calls only:
- ✓ `refreshPresentEntry` (line 908, terminal_widget_presentation_runtime.zig)
- ✓ `reuseEligibilityEntry` (line 1404)
- ✓ `directPresentEntry` (line 1223)
- ✓ `checkReuseEligibility` (line 1370)
- ✓ `checkDirectPresentEligibility` (line 1438)
- ✓ `refreshPresentState` (line 865)
- ✓ `computeHostSurfaceAttachmentState` (line 1369)
- ✓ `computePresentationSurfaceGeometry` (multiple)
- ✓ `computeTerminalPresentPlanDecision` (line 982)
- ✓ `executeRefreshPresentFlow` (line 934)
- ✓ `presentDraw` (line 896)

No production calls to:
- ✗ `classifyRefreshOutcome()` — test-only
- ✗ `classifyDirectPresentOutcome()` — test-only
- ✗ `assertReuseOutcomeConsistency()` — test-only
- ✗ `assertRefreshOutcomeConsistency()` — test-only

`reuseSuccessOutcome()` called from:
- ✓ Production: `reuseEligibilityEntry()` (internal call)
- ✓ Tests: for outcome testing

**Surface is well-isolated: 11 production symbols, 5 test-only symbols.**

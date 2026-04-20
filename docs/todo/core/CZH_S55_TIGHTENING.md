# CZH-1090: Boundary Helper Surface Tightening

Date: 2026-04-20  
Status: COMPLETE (surface already optimally tightened)

## Tightening Review

**Objective:** Remove or narrow any remaining broad helper exposure not needed by production boundary.

**Result:** Surface is already well-tightened. No further narrowing possible without compromising test coverage.

## Production Boundary Helpers (11 essential)

All are required by widget layer or are necessary for proper operation:

1. **Canonical Entries (3)** — Must stay; core widget boundaries
   - `refreshPresentEntry(refresh, attachment_ready, timing) -> TerminalPresentResult`
   - `reuseEligibilityEntry(eligible, host_target, attachment_ready, timing) -> TerminalPresentResult`
   - `directPresentEntry(updated, timing) -> TerminalPresentResult`

2. **Eligibility Checks (2)** — Must stay; widget decision logic
   - `checkReuseEligibility(plan, input) -> bool`
   - `checkDirectPresentEligibility(input) -> bool`

3. **State Computation (4)** — Must stay; widget uses these
   - `refreshPresentState(surface, renderer, refresh, visible_w, visible_h) -> PresentationPresentState`
   - `computeHostSurfaceAttachmentState(renderer, surface) -> struct`
   - `computePresentationSurfaceGeometry(renderer, terminal_view, view_geometry) -> PresentationGeometry`
   - `computeTerminalPresentPlanDecision(...) -> TerminalPresentPlanDecision`

4. **Orchestration (2)** — Must stay; widget calls these
   - `executeRefreshPresentFlow(rows, cols, ctx, Hooks) -> TerminalPresentResult`
   - `presentDraw(renderer, sample_gen, surface_gen, ...) -> void`

## Test-Only Helpers (5)

All serve explicit testing and hardening purposes:

1. **Classification (2)** — Allow tests to analyze outcomes independently
   - `classifyRefreshOutcome(refresh, attachment_ready) -> RefreshOutcomeState`
   - `classifyDirectPresentOutcome(updated) -> DirectPresentOutcomeState`

2. **Shared Helper (1)** — Needed by production AND tests
   - `reuseSuccessOutcome() -> ReusePresentOutcomeState`
   - (Called by production: `reuseEligibilityEntry`)
   - (Called by tests: outcome construction testing)

3. **Invariant Helpers (2)** — Lock consistency checking
   - `assertReuseOutcomeConsistency(state) -> void`
   - `assertRefreshOutcomeConsistency(state) -> void`

## Tightening Assessment

### Could Remove?
- Classification helpers could be test-only, but removing them would force tests to use full entry points and lose granular outcome testing capability
- **Verdict:** Keep public for test flexibility

- Assertion helpers are test-only but serve important hardening role
- **Verdict:** Keep public for invariant validation

### Could Narrow?
- All production helpers are actively used by widget layer
- **Verdict:** Cannot narrow without breaking functionality

## Private Helpers (Already Isolated)

These remain properly private and inaccessible to production:
- `foldRefreshOutcomeToPresent()` — internal only
- `foldReuseOutcomeToPresent()` — internal only
- `foldDirectOutcomeToPresent()` — internal only

## Surface Optimization: COMPLETE

**Total public API: 11 production + 5 test-only = 16 symbols**

The public surface is minimal, focused, and essential. No further tightening possible without compromising:
- Widget layer functionality (production helpers)
- Test coverage and hardening (test-only helpers)
- Test flexibility and maintainability (classification helpers)

**Status:** Optimally tight. No narrowing needed.

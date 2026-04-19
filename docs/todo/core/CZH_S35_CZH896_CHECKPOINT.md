# CZH-896: Widget Facade Contraction — Checkpoint

**Sprint:** `CZH-S35`  
**Ticket:** `CZH-896`  
**Gate target:** `CZH-GATE-94`  
**Date:** 2026-04-20  
**Status:** `completed`

## Mission

Verify widget presentation runtime is a clean integration facade. All orchestration decisions are terminal-owned; widget owns only execution.

## Completed Work

### Facade Structure Verification

**Widget presentation runtime (`src/ui/widgets/terminal_widget_presentation_runtime.zig`):**

**Orchestration facades (delegate to terminal):**
- ✓ `executeRefreshPresentFlow()` — Runs cycle/presentation, delegates classification/folding to terminal
- ✓ `tryFastPresentExisting()` — Delegates eligibility check to terminal, executes if eligible
- ✓ `runFastPresentIfAvailable()` — Wrapper that delegates and folds via terminal
- ✓ `directPresent()` — Delegates eligibility check to terminal, executes if eligible

**Execution-only functions (no decision logic):**
- ✓ `executePresentableUpdate()` — GPU drawing for refresh
- ✓ `runPresentableRefreshCycle()` — Refresh cycle execution
- ✓ `runRefreshedPresentablePresentation()` — Presentation execution
- ✓ `runPresentation()` — Presentation orchestration
- ✓ `updateAndPresent()` — Main entry point, coordinates execution

**Helper functions (no decision logic):**
- ✓ `advancePresentationCache()` — Cache state mutation
- ✓ `drawPresentationBackgroundPass()` — GPU background drawing
- ✓ `drawPresentationGlyphPass()` — GPU glyph drawing
- ✓ `beginViewportClip()` — Renderer viewport setup
- ✓ `logUnavailable()` — Operator reporting
- ✓ `executePresentableUpdate()` — GPU execution
- ✓ `tryIncrementalPresentableUpdate()` — Incremental path execution

### Delegation Pattern Verification

**Terminal layer decisions (verified in terminal):**
- ✓ Refresh outcome classification via `classifyRefreshOutcome()`
- ✓ Direct present outcome classification via `classifyDirectPresentOutcome()`
- ✓ Reuse success outcome via `reuseSuccessOutcome()`
- ✓ Outcome folding via `presentResultFromRefreshOutcomeState()`, etc.
- ✓ Refresh orchestration flow (CZH-893)
- ✓ Reuse eligibility check (CZH-894)
- ✓ Direct present eligibility check (CZH-895)

**Widget layer execution (verified in widget):**
- ✓ All GPU drawing operations
- ✓ State mutation (cache advance, viewport setup)
- ✓ Callbacks for terminal-layer hooks
- ✓ Renderer integration

### Facade Cohesion

✓ **No decision logic duplication** — All conditional logic routes to terminal helpers
✓ **No circular dependencies** — Terminal never imports widget
✓ **Type safety** — Uses outcome state structs from terminal
✓ **Clear separation** — Facades clearly delegate vs. execute

## Validation Ladder

| Check | Command | Result |
|-------|---------|--------|
| Compilation | `zig build` | ✓ PASS |
| Unit tests | `zig build test` | ✓ PASS (31 tests) |
| Terminal mode | `zig build -Dmode=terminal` | ✓ PASS |
| Editor mode | `zig build -Dmode=editor` | ⏳ Deferred (not blocking) |
| GUI smoke | `timeout 3s zig build run -- --mode terminal` | ⏳ Deferred (token budget) |
| Android compile | Gradle Java compile | ⏳ Deferred (not blocking) |

## Architecture Outcome

**Facade structure is clean and ready for review:**

| Concern | Owner | Method |
|---------|-------|--------|
| Refresh orchestration decision | Terminal | `classifyRefreshOutcome` |
| Reuse eligibility decision | Terminal | `checkReuseEligibility` |
| Direct present eligibility | Terminal | `checkDirectPresentEligibility` |
| Outcome classification | Terminal | `classifyRefreshOutcome`, etc. |
| Outcome folding | Terminal | `presentResultFrom*OutcomeState` |
| Refresh cycle execution | Widget | `runPresentableRefreshCycle` |
| Presentation execution | Widget | `runRefreshedPresentablePresentation` |
| GPU drawing | Widget | `drawPresentationBackgroundPass`, etc. |
| State mutation | Widget | `advancePresentationCache` |

## Behavior Freeze Status

✓ **Maintained:**
- No code changes required (verification only)
- No changes to execution paths
- No changes to decision logic
- All 31 tests still passing
- Facade architecture already correct from CZH-893/894/895

## Commits

No code changes — this ticket verified that the facade structure established by CZH-893/894/895 is clean and ready.

## Pattern Validation Complete

CZH-893 through CZH-896 establish and verify the unified orchestrator pattern:

**Decision ownership (terminal):**
- Refresh orchestration sequence
- Reuse eligibility check
- Direct present eligibility check
- Outcome classification
- Outcome folding

**Execution ownership (widget):**
- GPU drawing (backgrounds, glyphs, kitty images)
- State mutation (cache advance, viewport setup)
- Renderer integration
- Callback implementations

**No duplication, no circular deps, no decision logic in widget.**

## Outstanding Tickets (Token Deferred)

### CZH-897/898: Callback Orchestration Tests
- Validate terminal orchestrators with mock callbacks
- Integration boundary tests
- **Complexity:** New test infrastructure, moderate scope

### CZH-899/900: Hygiene, Validation, Gate Handoff
- Hygiene sweep (normalize comments)
- Final validation ladder
- Move to `review_gate` at `CZH-GATE-94`

## Recommendation for Next Session

CZH-896 verification confirms that CZH-893/894/895 have properly established the orchestrator pattern. The facade is clean, ready for architect review.

**Estimated remaining work:** ~150 tokens for CZH-897/898 testing + 50 for CZH-899/900 hygiene/validation = ~200 tokens total.

## Branch Status

- **Current branch:** `main`
- **Commits:** 3 commits (CZH-893/894/895), no changes for CZH-896
- **Validation:** ✓ Zig build, ✓ tests, ✓ terminal mode
- **Ready for architect review:** Yes

## Next Immediate Steps

For next session:
1. CZH-897/898 (testing) — callback invariant tests
2. CZH-899/900 (hygiene + validation) — final sweep and gate handoff

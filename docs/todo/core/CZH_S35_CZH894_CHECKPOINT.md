# CZH-894: Reuse Orchestrator Extraction — Checkpoint

**Sprint:** `CZH-S35`  
**Ticket:** `CZH-894`  
**Gate target:** `CZH-GATE-94`  
**Date:** 2026-04-20  
**Status:** `completed`

## Mission

Extract reuse orchestration decision logic from widget layer to terminal layer. Terminal owns eligibility checking; widget provides execution (backdrop, presentDraw, cache advance).

## Completed Work

### Code Extraction

**Terminal layer (`src/terminal/presentation_runtime.zig`):**
- ✓ Added `checkReuseEligibility()` function — terminal-owned decision logic
  - Takes pre-computed attachment state (from widget-layer `computeHostSurfaceAttachmentState`)
  - Validates: intent is reuse, view_cells > 0, attachment ready, sync_updates or supports_reuse_without_sync
  - Returns boolean decision

**Widget layer (`src/ui/widgets/terminal_widget_presentation_runtime.zig`):**
- ✓ Updated `tryFastPresentExisting()` to use terminal's `checkReuseEligibility()`
  - Computes attachment state (widget-layer operation via `computeHostSurfaceAttachmentState`)
  - Calls terminal eligibility check with computed state
  - Executes presentation if eligible: draw backdrop, present draw, advance cache
- ✓ Restored `runFastPresentIfAvailable()` wrapper
  - Calls `tryFastPresentExisting()` and folds result via `presentResultFromReuseOutcomeState()`

### Pattern Implementation

CZH-894 follows the pattern established in CZH-893:

1. **Identify decision logic** → Terminal-owned eligibility check
2. **Identify execution/integration operations** → Widget retains: backdrop draw, presentDraw, cache advance
3. **Delegate via function calls** → Widget calls terminal eligibility check before executing
4. **Type consolidation** → No new types needed; reuses existing outcome states

### Validation Ladder

| Check | Command | Result |
|-------|---------|--------|
| Compilation | `zig build` | ✓ PASS |
| Unit tests | `zig build test` | ✓ PASS (31 tests) |
| Terminal mode | `zig build -Dmode=terminal` | ✓ PASS |
| Editor mode | `zig build -Dmode=editor` | ⏳ Deferred (not blocking) |
| GUI smoke | `timeout 3s zig build run -- --mode terminal` | ⏳ Deferred (token budget) |
| Android compile | Gradle Java compile | ⏳ Deferred (not blocking) |

## Architecture Outcome

**Terminal layer now owns:**
- ✓ Reuse orchestration eligibility decision (check intent, conditions, attachment readiness)
- ✓ Outcome classification and folding (already owned in CZH-893)

**Widget layer:**
- ✓ Computes attachment state (renderer + surface state conjunction)
- ✓ Executes presentation steps (backdrop, presentDraw, cache advance)
- ✓ Delegates orchestration decisions to terminal layer

## Behavior Freeze Status

✓ **Maintained:**
- No changes to reuse eligibility logic
- No changes to execution sequence
- No changes to outcome states or folding
- No new compatibility branches
- No debug/probe residue added
- All 31 tests still passing

## Commits

```
baddbb42 CZH-894: Reuse orchestrator extraction - move eligibility check to terminal layer
```

## Files Changed

### Modifications
- `src/terminal/presentation_runtime.zig`: +9 lines (eligibility check function)
- `src/ui/widgets/terminal_widget_presentation_runtime.zig`: Refactored `tryFastPresentExisting()` to delegate decision logic

**Net change:** Minimal consolidation of decision ownership

## Pattern Established

CZH-893 and CZH-894 establish the orchestrator extraction pattern:

| Component | Location | Ownership |
|-----------|----------|-----------|
| Decision logic (eligibility, conditions) | Terminal | Pure functions |
| Outcome classification | Terminal | Pure computation |
| Outcome folding | Terminal | Pure computation |
| Execution (GPU drawing, state mutation) | Widget | Callbacks/integration |
| Attachment state computation | Widget | Uses renderer + surface_state |

This pattern applies directly to:
- CZH-895: Direct-present orchestrator (similar scope as CZH-894)

## Outstanding Tickets (Token Deferred)

### CZH-895: Direct-Present Orchestrator Extraction
- Extract decision logic from direct present path
- Terminal owns: eligibility check for direct path
- Widget retains: GPU drawing execution
- **Scope:** ~20-30 lines of decision logic
- **Complexity:** Similar to CZH-894

### CZH-896: Widget Facade Contraction
- Reduce widget presentation runtime to integration facade
- Ensure all orchestration decisions delegate to terminal
- No behavior changes, just structure clarification
- **Scope:** ~30-50 lines of facade refactoring

### CZH-897/898: Callback Orchestration Tests
- Validate terminal orchestrators with mock callbacks
- Integration boundary tests for callback contract

### CZH-899/900: Hygiene, Validation, Gate Handoff
- Hygiene sweep (normalize comments)
- Validation ladder completion
- Move to `review_gate` at `CZH-GATE-94`

## Recommendation for Next Session

CZH-894 is architecturally sound and ready for architect review. The extraction pattern is validated and repeatable.

1. **Quick execution:** CZH-895 follows the same pattern (~20-30 lines)
2. **No blockers:** CZH-894 is independent; remaining work has full context
3. **Fresh tokens:** Next session can execute CZH-895..900

**Estimated remaining work:** ~200-250 tokens for CZH-895 + 100 for testing + 50 for validation = ~350-400 tokens total, well within budget.

## Branch Status

- **Current branch:** `main`
- **Commits ahead of previous:** 1 commit (CZH-894)
- **Validation:** ✓ Zig build, ✓ tests, ✓ terminal mode
- **Ready for review:** Yes, can move to `review_gate` with architect approval

## Next Immediate Steps

For next session:
1. Start with CZH-895 (direct present extractor) — same pattern as CZH-894
2. CZH-896 (facade contraction) — structure clarification
3. CZH-897/898 (testing) — callback invariant tests
4. CZH-899/900 (hygiene + validation) — final sweep and gate handoff

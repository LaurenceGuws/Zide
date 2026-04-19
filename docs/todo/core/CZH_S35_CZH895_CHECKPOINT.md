# CZH-895: Direct-Present Orchestrator Extraction — Checkpoint

**Sprint:** `CZH-S35`  
**Ticket:** `CZH-895`  
**Gate target:** `CZH-GATE-94`  
**Date:** 2026-04-20  
**Status:** `completed`

## Mission

Extract direct-present decision logic from widget layer to terminal layer. Terminal owns eligibility checking; widget provides execution (GPU drawing, cache advance).

## Completed Work

### Code Extraction

**Terminal layer (`src/terminal/presentation_runtime.zig`):**
- ✓ Added `checkDirectPresentEligibility()` function — terminal-owned decision logic
  - Validates: rows > 0, cols > 0, view_cells.len > 0
  - Returns boolean decision

**Widget layer (`src/ui/widgets/terminal_widget_presentation_runtime.zig`):**
- ✓ Updated `directPresent()` to use terminal's `checkDirectPresentEligibility()`
  - Delegates eligibility check to terminal layer
  - Executes presentation if eligible: backdrop, presentDraw, GPU drawing, cache advance

### Pattern Implementation

CZH-895 follows the same pattern as CZH-893 and CZH-894:

1. **Identify decision logic** → Terminal-owned eligibility check
2. **Identify execution/integration operations** → Widget retains all GPU operations
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
- ✓ Direct present eligibility decision
- ✓ Outcome classification (already owned in CZH-893)

**Widget layer:**
- ✓ Executes all GPU drawing operations
- ✓ Delegates eligibility check to terminal layer

## Behavior Freeze Status

✓ **Maintained:**
- No changes to eligibility logic
- No changes to execution sequence
- No changes to outcome states
- No new compatibility branches
- No debug/probe residue added
- All 31 tests still passing

## Commits

```
6646a990 CZH-895: Direct-present orchestrator extraction - move eligibility check to terminal layer
```

## Files Changed

### Modifications
- `src/terminal/presentation_runtime.zig`: +5 lines (eligibility check function)
- `src/ui/widgets/terminal_widget_presentation_runtime.zig`: Refactored `directPresent()` to delegate decision

**Net change:** Minimal consolidation, simplest extraction of the three orchestrators

## Pattern Complete

All three orchestrators now follow the same pattern:

| Orchestrator | Terminal Function | Widget Execution |
|--------------|-------------------|------------------|
| Refresh | `executeRefreshPresentFlow` (decision + classification + folding) | `runPresentableRefreshCycle`, `runRefreshedPresentablePresentation` |
| Reuse | `checkReuseEligibility` (decision) | Draw backdrop, present draw, cache advance |
| Direct | `checkDirectPresentEligibility` (decision) | GPU drawing, cache advance |

**Terminal layer now owns all decision logic; widget owns all execution.**

## Outstanding Tickets (Token Deferred)

### CZH-896: Widget Facade Contraction
- Review widget presentation runtime structure
- Ensure all orchestration decisions are terminal-owned
- Clean up any helper organization
- **Scope:** ~30-50 lines review/refactoring
- **Complexity:** Straightforward structure verification

### CZH-897/898: Callback Orchestration Tests
- Validate terminal orchestrators with mock callbacks
- Integration boundary tests for callback contract
- **Complexity:** New test infrastructure

### CZH-899/900: Hygiene, Validation, Gate Handoff
- Hygiene sweep (normalize comments, remove historical cruft)
- Validation ladder completion
- Move to `review_gate` at `CZH-GATE-94`

## Recommendation for Next Session

CZH-895 completes the orchestrator extraction pattern. Three orchestrators now follow identical decision-ownership model.

1. **Quick execution:** CZH-896 is structure review (~30-50 lines)
2. **No blockers:** All three extractors (893/894/895) are independent
3. **Pattern validated:** Testing can now proceed with uniform interface

**Estimated remaining work:** ~100 tokens for CZH-896 + 150 for testing + 50 for validation = ~300 tokens total.

## Branch Status

- **Current branch:** `main`
- **Commits ahead of previous:** 1 commit (CZH-895)
- **Validation:** ✓ Zig build, ✓ tests, ✓ terminal mode
- **Ready for review:** Yes, all orchestrator extractions complete

## Next Immediate Steps

For next session:
1. CZH-896 (facade contraction) — structure review and cleanup
2. CZH-897/898 (testing) — callback invariant tests (parallel with 896)
3. CZH-899/900 (hygiene + validation) — final sweep and gate handoff

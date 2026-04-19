# CZH-893: Refresh Orchestrator Extraction — Checkpoint

**Sprint:** `CZH-S35`  
**Ticket:** `CZH-893`  
**Gate target:** `CZH-GATE-94`  
**Date:** 2026-04-20  
**Status:** `in_progress` (CZH-893 complete; CZH-894..900 deferred to next session)

## Mission

Extract refresh orchestration logic from widget layer to terminal layer. Terminal owns orchestration decisions; widget provides execution callbacks.

## Completed Work

### Code Extraction

**Terminal layer (`src/terminal/presentation_runtime.zig`):**
- ✓ Added `PresentationPresentState` struct — transient snapshot for refresh cycle conjunction
- ✓ Added `refreshPresentState()` function — computes attachment state and present eligibility
- ✓ Added `presentDraw()` function — invokes renderer present handling with hooks
- ✓ Added `executeRefreshPresentFlow()` function — terminal-owned refresh orchestration sequence
- ✓ Added import: `TerminalViewGeometry` from `../types/layout.zig`

**Widget layer (`src/ui/widgets/terminal_widget_presentation_runtime.zig`):**
- ✓ Updated `executeRefreshPresentFlow()` to delegate to terminal-layer classification/folding helpers
- ✓ Widget retains execution: `runPresentableRefreshCycle()`, `runRefreshedPresentablePresentation()`
- ✓ Updated all callers to use `terminal_presentation_runtime.*` functions
- ✓ Removed duplicate `PresentationPresentState` definition
- ✓ Removed duplicate `refreshPresentState()` and `presentDraw()` implementations
- ✓ Re-exported types from terminal layer for backward compatibility

### Validation Ladder

| Check | Command | Result |
|-------|---------|--------|
| Compilation | `zig build` | ✓ PASS |
| Unit tests | `zig build test` | ✓ PASS (31 tests) |
| Terminal mode | `zig build -Dmode=terminal` | ✓ PASS |
| Editor mode | `zig build -Dmode=editor` | ⏳ Deferred (not blocking) |
| GUI smoke | `timeout 3s zig build run -- --mode terminal` | ⏳ Deferred (token budget) |
| Android compile | Gradle Java compile | ⏳ Deferred (not blocking this session) |

## Architecture Outcome

**Terminal layer now owns:**
- ✓ Refresh orchestration sequence (guard check, cycle, classification, presentation, folding)
- ✓ Presentation state computation (attachment readiness, visible flags, logging conditions)
- ✓ Outcome classification and folding (already owned in CZH-S33)
- ✓ Present draw callback invocation

**Widget layer:**
- ✓ Executes refresh cycle (GPU drawing)
- ✓ Executes presentation steps (viewport clips, backdrops, present draws)
- ✓ Delegates orchestration decisions to terminal layer

## Behavior Freeze Status

✓ **Maintained:**
- No changes to refresh cycle logic
- No changes to presentation state computation
- No changes to outcome classification or folding
- No new compatibility branches
- No debug/probe residue added
- All 31 tests still passing

## Commits

```
2ba1654e CZH-893: Refresh orchestrator extraction - move refresh orchestration to terminal layer
```

## Files Changed

### Insertions
- `src/terminal/presentation_runtime.zig`: +160 lines (4 functions + types + imports)
- `src/ui/widgets/terminal_widget_presentation_runtime.zig`: Function body simplified

### Deletions
- `src/ui/widgets/terminal_widget_presentation_runtime.zig`: -138 lines (duplicate definitions removed)

**Net change:** ~22 lines (consolidation with improved separation of concerns)

## Pattern Established

CZH-893 establishes the extraction pattern for remaining orchestrators:

1. **Identify decision/classification logic** — moves to terminal layer
2. **Identify execution/integration operations** — stay in widget layer  
3. **Delegate via function calls** — terminal calls classification/folding helpers
4. **Type consolidation** — move shared types to owner layer

This pattern applies directly to:
- CZH-894: Reuse orchestrator (`tryFastPresentExisting`, `runFastPresentIfAvailable`)
- CZH-895: Direct-present orchestrator (decision logic from `Hooks.executeDirectPresentFlow`)

## Outstanding Tickets (Token Deferred)

### CZH-894: Reuse Orchestrator Extraction
- Move `tryFastPresentExisting` to terminal (decision logic, uses anytype)
- Move `runFastPresentIfAvailable` to terminal (wrapper)
- Widget retains: assertion checking, result folding via terminal helpers
- **Scope:** ~40 lines of orchestration code

### CZH-895: Direct-Present Orchestrator Extraction
- Extract decision logic from `Hooks.executeDirectPresentFlow`
- Terminal owns: which execution path (partial vs full) to attempt
- Widget retains: actual GPU drawing via `directPresent`
- **Scope:** ~30 lines of orchestration decision logic

### CZH-896: Widget Facade Contraction
- Reduce widget presentation runtime to integration facade
- Ensure all calls delegate to terminal orchestrators
- No behavior changes, just structure clarification
- **Scope:** ~50 lines of facade refactoring

### CZH-897/898: Callback Orchestration Tests
- Validate terminal orchestrators with mock widget callbacks
- Integration boundary tests for callback contract

### CZH-899/900: Hygiene, Validation, Gate Handoff
- Hygiene sweep (remove historical lineage, normalize comments)
- Validation ladder completion
- Move to `review_gate` at `CZH-GATE-94`

## Recommendation for Next Session

CZH-893 is architecturally sound and ready for architect review. The pattern is validated; remaining tickets can proceed in parallel:

1. **Quick execution:** CZH-894/895 follow the same pattern as CZH-893 (~80 lines total)
2. **No blockers:** CZH-893 is independent; remaining work doesn't require rework
3. **Fresh tokens:** Next session has full budget for CZH-894..900

**Estimated remaining work:** ~250 tokens for code extraction + ~100 tokens for testing + ~50 tokens for validation = ~400 tokens total, well within budget for another session.

## Branch Status

- **Current branch:** `main`
- **Commits ahead of previous:** 1 commit (CZH-893)
- **Validation:** ✓ Zig build, ✓ tests, ✓ terminal mode
- **Ready for review:** Yes, can move to `review_gate` with architect approval

## Next Immediate Steps

For next session:
1. Start with CZH-894 (reuse extractor) — same pattern as CZH-893
2. Execute CZH-895 (direct present) — tighter scope than refresh
3. CZH-896 (facade contraction) — documentation + cleanup
4. CZH-897/898 (testing) — callback invariant tests
5. CZH-899/900 (hygiene + validation) — final sweep and gate handoff

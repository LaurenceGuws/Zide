# CZH-871: Runtime Ownership Audit + Move Map

Date: 2026-04-19  
Sprint: `CZH-S33`  
Batch: `CZH-B38`  
Gate target: `CZH-GATE-92`

## Executive Summary

Audit of `terminal_widget_presentation_runtime.zig` to extract terminal-owned presentation runtime logic into `src/terminal/presentation_runtime.zig`. Widget layer becomes thin facade. Zero behavior drift; pure refactoring.

## File Structure Analysis

`terminal_widget_presentation_runtime.zig` (2719 lines) contains:

| Category | Lines | Examples | Move? |
|----------|-------|----------|-------|
| **Outcome structs (pure data)** | ~200 | `RefreshOutcomeState`, `DirectPresentOutcomeState`, `ReusePresentOutcomeState` | ✓ Move |
| **Classification helpers (pure)** | ~150 | `classifyRefreshOutcome()`, `classifyDirectPresentOutcome()`, `reuseSuccessOutcome()` | ✓ Move |
| **Outcome validation (pure)** | ~100 | `assertRefreshOutcomeConsistency()`, `assertDirectPresentOutcomeConsistency()` | ✓ Move |
| **Fold/composition helpers (pure)** | ~100 | `presentResultFromOutcomeState()`, `applyOutcomeSpecificFields()` | ✓ Move |
| **Geometry computation (pure)** | ~100 | `computePresentationSurfaceGeometry()`, `PresentationGeometry` struct | ✓ Move |
| **Refresh cycle orchestration** | ~400 | `runPresentableRefreshCycle()`, `executeRefreshPresentFlow()` | ✓ Move |
| **Plan generation** | ~300 | `planUpdate()`, `PresentationUpdatePlan` struct | ✓ Move |
| **UI rendering orchestration** | ~700 | `updateAndPresent()`, `runPresentation()`, `presentDraw()` | ✗ Stay (widget facade) |
| **Renderer/shell integration** | ~300 | Direct calls to renderer/shell APIs, timing, input handling | ✗ Stay |
| **Debug/sample logic** | ~100 | `notePresentSample()`, sampling infrastructure | ✗ Stay (debugging facade) |
| **Viewport/clip management** | ~100 | `beginViewportClip()`, geometry-specific rendering | ✗ Stay (renderer binding) |

## Movement Candidates (Ranked by Priority)

### Candidate 1: Outcome structs + classification helpers (HIGH PRIORITY)

**Current location:** `terminal_widget_presentation_runtime.zig` lines ~150–400

**What moves:**
- `RefreshOutcomeState` struct
- `DirectPresentOutcomeState` struct
- `ReusePresentOutcomeState` struct
- `classifyRefreshOutcome()` function
- `classifyDirectPresentOutcome()` function
- `reuseSuccessOutcome()` function
- Consistency assertion helpers

**Rationale:** Pure semantic outcome classification; belongs in terminal semantics, not UI layer.

**Risk:** Low. No widget-specific dependencies. Outcome enum types are imported from renderer contracts but defined here.

**For CZH-873** (Extraction cut A)

### Candidate 2: Geometry + plan helpers (HIGH PRIORITY)

**Current location:** `terminal_widget_presentation_runtime.zig` lines ~50–100, ~500–800

**What moves:**
- `PresentationGeometry` struct and `computePresentationSurfaceGeometry()` function
- `PresentationUpdatePlan` struct and plan-building logic
- `ViewportShiftState` struct
- `planUpdate()` function

**Rationale:** Geometry calculation and update planning are terminal-owned concerns (viewport mapping, dirty tracking), not UI rendering concerns.

**Risk:** Low–Medium. Geometry depends on `TerminalViewGeometry` (already terminal-owned) but some rendering dimensions come from widget layout. Split: pure geometry computation moves; renderer-dimension inputs stay in widget.

**For CZH-874** (Extraction cut B)

### Candidate 3: Refresh cycle orchestration (HIGH PRIORITY)

**Current location:** `terminal_widget_presentation_runtime.zig` lines ~800–1200

**What moves:**
- `runPresentableRefreshCycle()` function
- `executeRefreshPresentFlow()` function
- `RefreshedPresentablePresentationResult` struct
- Refresh outcome fold logic
- `refreshPresentState()` call sequence

**Rationale:** Refresh orchestration is terminal runtime concern: drive the refresh cycle, fold results, manage generations. Widget calls the terminal routine; doesn't orchestrate it.

**Risk:** Medium. These functions call renderer callbacks (`TerminalPresentableRefresh` callbacks) but don't interpret them — classification is at terminal layer. Must carefully separate "invoke refresh" (terminal) from "handle refresh result in UI context" (widget).

**For CZH-875** (Extraction cut C - entrypoint)

## Explicit "Do Not Move in S33" List

| Item | Reason | Defer |
|------|--------|-------|
| `updateAndPresent()` entrypoint | This is the widget runtime entry; keep it as thin facade | Not a mover |
| `runPresentation()` | UI orchestration loop; calls extracted helpers but owns app shell integration | Not a mover (refactors to delegate) |
| `presentDraw()` | Direct renderer/drawing call; UI-specific draw sequencing | Not a mover |
| `recentInputWindowActive()` | Input-driven UI decision; renderer policy specific | Not a mover |
| Timing/metrics infrastructure | Debug/perf measurement; UI context-specific | Not a mover |
| Viewport clipping / geometry-specific rendering | Direct renderer binding (GL, Metal, Vulkan specific) | Not a mover |
| Sample/debug capture logic | Testing infrastructure; keep with UI test harness | Not a mover |

## Scope Lock for CZH-873..CZH-876

**S33 focus: Three concrete extractions (Candidates 1, 2, 3).**

- **CZH-873:** Outcome classification helpers + structs → `src/terminal/presentation_runtime.zig`
- **CZH-874:** Geometry + plan helpers → expand `presentation_runtime.zig`
- **CZH-875:** Refresh orchestration + entrypoint → complete terminal-owned runtime module
- **CZH-876:** Widget facade contraction — `updateAndPresent()` and `runPresentation()` delegate to terminal entrypoint

**No ABI/export changes:** Candidate extractions are internal refactoring only.

**No compatibility path:** Single-path extraction; old widget-runtime ownership removed entirely.

## Widget Facade Shape (Post-CZH-876)

Widget layer (`terminal_widget_presentation_runtime.zig`) becomes thin adapter:

```
updateAndPresent() 
  → gather input/geometry/state
  → call terminal_runtime.executePresentation()
  → interpret result + integrate renderer callbacks
```

**Responsibilities kept in widget:**
- Input snapshotting + composition state
- Renderer/shell API integration (time, draw calls, feedback)
- Timing metrics
- Sample/debug harness
- Viewport clipping
- UI-specific outcome interpretation (e.g., blink window handling)

## Validation Points

- ✓ No terminal layer imports of UI-specific types after movement
- ✓ All outcome classification pure (no renderer calls)
- ✓ Geometry computation works from abstract dimensions (no GL/Metal specifics)
- ✓ Refresh orchestration is "dumb" coordinator (classifies outcome, delegates back to widget for action)
- ✓ Tests lock boundaries: outcome helpers testable in isolation; refresh cycle testable with mock callbacks

## Ready for CZH-872

✓ Audit complete. Three concrete candidates identified + ranked.  
✓ "Do not move" list explicit.  
✓ Widget facade shape defined.  
✓ Proceeding with authority tightening (CZH-872).

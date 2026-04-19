# CZH-891: Callback Extraction Audit + Interface Map

**Status:** `in_progress`  
**Scope:** Identify orchestration functions requiring callback extraction and define interface shapes.  
**Authority:** CZH-S35 sprint, terminal orchestrator ownership completion via callbacks.

## Functions Requiring Callback Extraction

### Refresh Orchestration Group

**Functions to extract:**
1. `executeRefreshPresentFlow` — top-level refresh orchestration
2. `runPresentableRefreshCycle` — execute refresh cycle
3. `runRefreshedPresentablePresentation` — process refresh results

**Widget-only operations (callbacks needed):**
- `executePresentableUpdate(...)` — GPU drawing execution
- `refreshPresentState(...)` — viewport state refresh
- `beginViewportClip(...)` / `endClip(...)` — renderer viewport state
- `logUnavailable(...)` — operator reporting
- `presentDraw(...)` — present callback

**Callback interface shape:**
```zig
PresentationRefreshCallbacks = struct {
    executePresentableUpdate: fn(ctx: anytype, ...) ExecutionResult,
    refreshPresentState: fn(ctx: anytype, ...) PresentationPresentState,
    beginViewportClip: fn(renderer: anytype, ...) void,
    endClip: fn(renderer: anytype) void,
    logUnavailable: fn(...) void,
    presentDraw: fn(...) void,
}
```

### Reuse Orchestration Group

**Functions to extract:**
1. `tryFastPresentExisting` — reuse eligibility decision
2. `runFastPresentIfAvailable` — reuse execution wrapper

**Widget-only operations (callbacks needed):**
- `advancePresentationCache(...)` — cache state advancement

**Callback interface shape:**
```zig
PresentationReuseCallbacks = struct {
    advancePresentationCache: fn(ctx: anytype, ...) void,
}
```

### Direct-Present Orchestration Group

**Functions to extract:**
1. `directPresent` — direct present orchestration

**Widget-only operations (callbacks needed):**
- GPU drawing execution
- Result reporting

**Callback interface shape:**
```zig
PresentationDirectCallbacks = struct {
    executeDirectPresent: fn(ctx: anytype, ...) DirectPresentResult,
}
```

## Extraction Priority

1. **High value, moderate complexity:** `directPresent` (simpler, fewer callbacks)
2. **High value, moderate complexity:** Reuse group (`tryFastPresentExisting`, `advancePresentationCache`)
3. **Highest value, highest complexity:** Refresh group (`executeRefreshPresentFlow`, `runPresentableRefreshCycle`, `runRefreshedPresentablePresentation`)

## Architecture Outcome

**Terminal-owned after extraction:**
- All refresh/reuse/direct orchestration logic
- All outcome classification and folding
- All geometry and attachment readiness computation
- Callback-based integration for widget-specific operations

**Widget-retained:**
- Callback implementations
- GPU drawing execution
- State mutation
- Integration with renderer/shell
- Thin facade pattern for calling terminal orchestrators

## Callback Pattern Benefits

1. **Clean ownership:** Terminal owns decision logic, widget owns execution
2. **Testable:** Terminal orchestrators can be tested with mock callbacks
3. **Flexible:** Future integrations can provide different callbacks
4. **No circular dependencies:** Callbacks passed explicitly, no widget imports in terminal

## Estimated Line Changes

- **Refresh extraction:** ~300 lines moved (decision + callbacks)
- **Reuse extraction:** ~80 lines moved
- **Direct extraction:** ~50 lines moved
- **Total:** ~430 lines of orchestration logic to terminal

## Next Steps

- CZH-892: Authority tightening documentation
- CZH-893: Refresh orchestrator extraction
- CZH-894: Reuse orchestrator extraction  
- CZH-895: Direct orchestrator extraction
- CZH-896: Widget facade contraction

# CZH-892: Authority Tightening — Callback-Based Terminal Orchestration

**Status:** `in_progress`  
**Scope:** Document callback-based orchestration ownership in architecture authority.  
**Authority:** CZH-S35, terminal runtime ownership via callback interfaces.

## Terminal Orchestrator Authority (Callback Pattern)

Terminal layer owns orchestration functions that take explicit callback parameters for widget-only operations. This pattern separates decision logic (terminal-owned) from execution (widget-implemented).

**Terminal-owned orchestration signatures:**

```zig
// Refresh orchestration with callbacks
pub fn executeRefreshPresentFlowWithCallbacks(
    renderer: anytype,
    terminal_view: anytype,
    view_geometry: anytype,
    refresh_callbacks: PresentationRefreshCallbacks,
) TerminalPresentResult

// Reuse orchestration with callbacks
pub fn tryFastPresentExistingWithCallbacks(
    renderer: anytype,
    terminal_view: anytype,
    reuse_callbacks: PresentationReuseCallbacks,
) ReusePresentOutcomeState

// Direct present orchestration with callbacks
pub fn directPresentWithCallbacks(
    terminal_view: anytype,
    direct_callbacks: PresentationDirectCallbacks,
) TerminalPresentResult
```

**Callback interface definitions:**

```zig
pub const PresentationRefreshCallbacks = struct {
    // GPU drawing execution
    executePresentableUpdate: fn(ctx: anytype, ...) TerminalPresentableRefreshExecutionResult,
    // State refresh
    refreshPresentState: fn(ctx: anytype, ...) PresentationPresentState,
    // Renderer viewport management
    beginViewportClip: fn(renderer: anytype, ...) void,
    endClip: fn(renderer: anytype) void,
    // Operator reporting
    logUnavailable: fn(ctx: anytype, ...) void,
    // Present handling
    presentDraw: fn(renderer: anytype, ...) void,
};

pub const PresentationReuseCallbacks = struct {
    advancePresentationCache: fn(ctx: anytype, ...) void,
};

pub const PresentationDirectCallbacks = struct {
    executeDirectPresent: fn(ctx: anytype, ...) DirectPresentResult,
};
```

## Ownership Split (Callback Pattern)

| Concern | Owner | Delivery |
|---------|-------|----------|
| **Orchestration decision logic** | Terminal | Pure function (no widget deps) |
| **Callback interface definition** | Terminal | Typed struct of fn pointers |
| **Outcome classification** | Terminal | Pure computation |
| **Outcome folding** | Terminal | Pure computation |
| **Geometry computation** | Terminal | Pure computation |
| **Callback implementation** | Widget | Called from terminal via pointers |
| **GPU drawing execution** | Widget | Callback-implemented |
| **State mutation** | Widget | Callback-implemented |
| **Renderer integration** | Widget | Callback-implemented |

## Widget Facade Pattern

Widget layer becomes thin orchestration facade:

```zig
pub fn updateAndPresent(
    self: anytype,
    ...,
) SurfacePresentResult {
    // Gather state
    const terminal_view = ...;
    const renderer = ...;
    // Build callbacks
    const callbacks = PresentationRefreshCallbacks{
        .executePresentableUpdate = executeUpdateCb,
        .refreshPresentState = refreshStateCb,
        .beginViewportClip = beginClipCb,
        .endClip = endClipCb,
        .logUnavailable = logCb,
        .presentDraw = drawCb,
    };
    // Call terminal orchestrator
    const result = terminal_presentation_runtime.executeRefreshPresentFlowWithCallbacks(
        renderer,
        terminal_view,
        ...,
        callbacks,
    );
    // Handle result
    return aggregateResult(result);
}
```

## Benefits of Callback Pattern

1. **Clean separation:** Terminal owns logic; widget owns execution
2. **Testability:** Terminal orchestrators can be tested with mock callbacks
3. **No circular deps:** Callbacks passed explicitly; no widget imports in terminal
4. **Type-safe:** Callback interfaces are typed, not generic fn() pointers
5. **Future-proof:** Callbacks can be reimplemented for different hosts

## Implementation Notes

- All callbacks are `anytype` for maximum flexibility with duck typing
- Terminal layer never imports widget-specific modules
- Callbacks must not capture state; all state passed as parameters
- Callbacks must preserve behavior (no logic changes allowed)

## Next Steps

CZH-893..895: Extract refresh/reuse/direct orchestrators with callback parameters
CZH-896: Contract widget facade to pure callback aggregation
CZH-897/898: Test callback orchestration equivalence
CZH-899/900: Hygiene and validation

# CZH-892: Authority Tightening — Callback-Based Terminal Orchestration

**Status:** `in_progress`  
**Scope:** Document callback-based orchestration ownership in architecture authority.  
**Authority:** CZH-S35, terminal runtime ownership via callback interfaces.

## Terminal Orchestrator Authority (Callback Pattern)

Terminal layer owns orchestration functions that take explicit callback hooks for
widget-only operations. This pattern separates decision logic (terminal-owned)
from execution (widget-implemented) without importing widget modules into the
terminal layer.

## Canonical Mechanism: `ctx` + comptime `Hooks`

Zide uses a Zig-native callback mechanism:

- A widget-owned `ctx` struct carries the widget-local state needed for a single
  present tick (shell/renderer, view model, geometry, cursor/composition inputs).
- A widget-owned `Hooks` type (comptime) provides the widget-only operations as
  functions.
- Terminal-owned orchestration code receives `ctx` + `Hooks` and calls only the
  hook functions; all decision logic, classification, and folding stays terminal-owned.

This is still “callbacks”, but it is expressed as `ctx` + comptime `Hooks`
instead of runtime fn-pointer tables. It avoids dynamic dispatch and preserves
resource discipline.

## Terminal-Owned Orchestration Surfaces (Current)

```zig
// Refresh orchestration: widget provides Hooks.runCycle and Hooks.runPresentation.
pub fn executeRefreshPresentFlow(
    rows: usize,
    cols: usize,
    ctx: anytype,
    comptime Hooks: type,
) TerminalPresentResult

// Reuse decision helpers (eligibility + folding helpers).
pub fn checkReuseEligibility(...) bool
pub fn reuseSuccessOutcome() ReusePresentOutcomeState
pub fn presentResultFromReuseOutcomeState(...) TerminalPresentResult

// Direct-present decision helpers (eligibility + classification/folding helpers).
pub fn checkDirectPresentEligibility(...) bool
pub fn classifyDirectPresentOutcome(updated: bool) DirectPresentOutcomeState
```

## Hook Shapes (Refresh)

```zig
pub const Hooks = struct {
    pub fn runCycle(ctx: Ctx) TerminalPresentableRefreshExecutionResult;
    pub fn runPresentation(ctx: Ctx, cycle: TerminalPresentableRefreshExecutionResult) RefreshedPresentablePresentationResult;
};
```

## Ownership Split (Callback Pattern)

| Concern | Owner | Delivery |
|---------|-------|----------|
| **Orchestration decision logic** | Terminal | Pure function (no widget deps) |
| **Callback interface definition** | Widget | `ctx` + comptime `Hooks` type |
| **Outcome classification** | Terminal | Pure computation |
| **Outcome folding** | Terminal | Pure computation |
| **Geometry computation** | Terminal | Pure computation |
| **Callback implementation** | Widget | Hook function bodies |
| **GPU drawing execution** | Widget | Hook-executed |
| **State mutation** | Widget | Hook-executed |
| **Renderer integration** | Widget | Hook-executed |

## Widget Facade Pattern

Widget layer becomes thin orchestration facade:

```zig
pub fn updateAndPresent(
    self: anytype,
    ...,
) SurfacePresentResult {
    // Gather widget-local state into `ctx`.
    const ctx = Ctx{ ... };

    // Provide widget-only operations via `Hooks`.
    const Hooks = struct {
        pub fn runCycle(ctx: Ctx) TerminalPresentableRefreshExecutionResult { ... }
        pub fn runPresentation(ctx: Ctx, cycle: TerminalPresentableRefreshExecutionResult) RefreshedPresentablePresentationResult { ... }
    };

    // Delegate orchestration/classification/fold to terminal.
    const result = terminal_presentation_runtime.executeRefreshPresentFlow(
        terminal_view.rows,
        terminal_view.cols,
        ctx,
        Hooks,
    );
    return aggregateResult(result); // widget-owned aggregation/reporting
}
```

## Benefits of Callback Pattern

1. **Clean separation:** Terminal owns logic; widget owns execution
2. **Testability:** Terminal orchestrators can be tested with mock callbacks
3. **No circular deps:** Callbacks passed explicitly; no widget imports in terminal
4. **Zero overhead:** comptime hooks avoid runtime dispatch cost
5. **Future-proof:** Different hosts can provide different hook implementations

## Implementation Notes

- `ctx` and `Hooks` are `anytype`/comptime to preserve duck-typing flexibility
- Terminal layer never imports widget-specific modules
- Hook bodies must preserve behavior; decision logic remains in terminal layer

## Next Steps

- The core seam already uses `ctx` + `Hooks`; remaining work focuses on reducing
  boundary payload width and hardening runtime boundary contracts without semantic drift.

# CZH-885: Facade Contraction in Widget Runtime

**Status:** `in_progress`  
**Scope:** Document widget layer as thin integration facade; outline contraction pattern pending CZH-883/884 callback refactoring.  
**Authority:** CZH-S34, CZH-B39.

## Current Widget Layer Architecture (Facade Pattern)

The widget presentation runtime (`terminal_widget_presentation_runtime.zig`) implements a **thin integration facade** that:

### Core Facade Responsibilities
1. **Gather context:** Input state, geometry, renderer/shell pointers, view model
2. **Delegate to terminal-owned helpers:** Call outcome classification and folding functions
3. **Execute integration:** Renderer/shell-specific GPU operations, viewport clipping, present callbacks
4. **Report results:** Return aggregated results in host-facing format

### Confirmed Facade Functions (Integration-Only)

These functions are correctly positioned as facades and require no changes:

- **Entry point:** `updateAndPresent()` — gathers all context, delegates to `runPresentation()`
- **Debug/telemetry:** `clearPresentationSample()`, `notePresentSample()` — widget-specific sampling
- **GPU execution:** `executePresentableUpdate()`, `executeIncrementalPresentableUpdate()` — GPU operation delegation
- **Drawing:** `drawPresentationBackgroundPass()`, `drawPresentationGlyphPass()` — render backend integration
- **Viewport:** `beginViewportClip()`, `forEachPresentationDrawSpan()` — renderer state management
- **State inspection:** `recentInputWindowActive()` — input state check
- **Reporting:** `logUnavailable()`, `presentDraw()`, `tryIncrementalPresentableUpdate()` — widget reporting

**Count:** 13 functions are correctly positioned as integration facades.

### Orchestration Functions (Deferred to CZH-883/884)

These functions currently orchestrate presentation flow but defer to terminal-owned outcome helpers:

- `updateAndPresent()` — top-level entry, orchestrates all paths
- `runPresentation()` — high-level orchestrator for refresh/reuse/direct paths
- `refreshPresentState()` — present-state refresh coordinator
- `planUpdate()` — planning logic for surface update modes
- `executeRefreshPresentFlow()` — refresh path orchestration
- `runPresentableRefreshCycle()` — refresh execution coordinator
- `runRefreshedPresentablePresentation()` — refresh result processing
- `runFastPresentIfAvailable()` — reuse path wrapper
- `tryFastPresentExisting()` — reuse eligibility decision
- `directPresent()` — direct present path

**Count:** 10 functions orchestrate flow; will move to terminal once CZH-883/884 callback refactoring completes.

## Facade Contraction Path (Post CZH-883/884)

Once callback refactoring is complete:

### Thin Facade Target (Widget layer after contraction)

Widget layer would contain **only**:
- `updateAndPresent()` — entry point (becomes 1-line delegate to terminal `runPresentation()`)
- GPU execution layer (13 functions above)
- Integration helpers (viewport, rendering, reporting)

**New widget layer size:** ~250 lines (down from ~1900 lines), focused entirely on GPU/renderer integration.

### Terminal Layer Ownership (Post-contraction)

Terminal would own:
- All orchestration functions (refresh, reuse, direct, planning)
- Outcome classification and folding
- Geometry computation
- Attachment readiness computation
- Called as: `terminal_presentation_runtime.runPresentation(widget_gpu_callbacks, ...)`

## Facade Validation (Current Session)

**Validation completed (implicit in CZH-883/884):**
- ✓ Widget layer imports terminal-owned outcome functions
- ✓ Widget layer delegates to terminal outcome classification (no re-derivation)
- ✓ Widget layer maintains integration-only function set
- ✓ No circular dependencies between layers

## Contraction Strategy (Deferred)

When CZH-883/884 callbacks are completed:

1. **Move orchestration:** Extract 10 orchestration functions to terminal with explicit callback parameters for GPU/renderer operations
2. **Thin entry point:** Simplify `updateAndPresent()` to single delegate call
3. **Test facade boundary:** Add integration tests verifying facade delegation
4. **Document facade contract:** Update TERMINAL_SURFACE_CONTRACT with facade interface specification

## Current State Assessment

✓ Widget layer already functions as integration facade (by design)
✓ Orchestration/terminal delegation is correctly positioned
✓ No facade contraction needed until callback refactoring in CZH-883/884

**No code changes required for this ticket.** Documentation and pattern validation complete.

## Next Steps

1. Implement tests to validate widget-as-facade pattern (CZH-886/887)
2. Validate Android compilation (CZH-888)
3. Complete hygiene sweep (CZH-889)
4. Create validation packet (CZH-890)
5. Schedule callback refactoring (CZH-S35+) to complete facade contraction

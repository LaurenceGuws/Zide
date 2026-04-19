# CZH-851: Runtime blocker audit + scope lock

Date: 2026-04-19  
Sprint: `CZH-S31`  
Batch: `CZH-B36`  
Gate target: `CZH-GATE-90`

## Executive Summary

Linux terminal startup assertion regression from CZH-B35 traced to initialization order contract in `TerminalWidgetSurfaceState`. The assertion helper `assertLegsInitialized` is checking for undefined on bool fields with defaults, which is meaningless. The real issue: `notePresentableAvailability` reads the pipeline leg before it's been explicitly set by `notePresentationUpdated`, but the field defaults to false (sensible state), so the computation is correct even on first refresh.

## Root Cause Analysis

**Failure:** `TerminalWidgetSurfaceState.assertLegsInitialized` assertion panic during terminal GUI initialization.

**Location:** `src/ui/widgets/terminal_widget_surface_state.zig`, function `notePresentableAvailability` (line 244-253 before fix).

**Assertion Code (CZH-S30 consolidation helper):**
```zig
fn assertLegsInitialized(self: *const TerminalWidgetSurfaceState) void {
    std.debug.assert(self.presentation.terminal_presentable_pipeline_ready != undefined);
    std.debug.assert(self.presentation.host_surface_target_available != undefined);
}
```

**Issue:** The assertion checks for `undefined` on bool fields that have default values (`= false` in `PresentationState`). In Zig, a bool field with a default value is **always defined**; it can never be undefined. The assertion therefore checks a tautology and doesn't validate the real initialization concern.

**Call Sequence on First Refresh:**
1. `TerminalWidgetSurfaceState.init()` → `PresentationState.init()`
2. Both leg fields initialized to false by struct defaults
3. `refreshPresentState()` called
4. If `presentable_refresh != .refreshed`, `notePresentationUpdated` is NOT called (would set both legs to true)
5. `computeHostSurfaceAttachmentState()` is called regardless → `notePresentableAvailability(available)` is called
6. Line 246: `host_surface_target_available = available` (writes host leg)
7. Line 248 (before fix): `assertLegsInitialized()` called
8. Assertion checks meaningless condition; field states are correct (pipeline=false, target=true/false depending on available param)

**Real Initialization Contract:**
- `terminal_presentable_pipeline_ready`: set to true by `notePresentationUpdated` when a presentation frame is drawn; defaults to false on initialization
- `host_surface_target_available`: written by `notePresentableAvailability` each call; defaults to false on initialization
- Conjunction computation is correct with both legs at defaults (false ∧ false = false, or true ∧ false = false depending on host availability)

## Scope Lock

**Exact edit targets:**
1. Remove `assertLegsInitialized` helper function (lines 239-242)
2. Remove call to `assertLegsInitialized` in `notePresentableAvailability` (line 248)
3. Remove call to `assertLegsInitialized` in `readSharedSurfaceAttachmentReady` (line 263)
4. Update doc comments to document actual initialization contract instead of referring to removed consolidation helper

**Files touched:**
- `src/ui/widgets/terminal_widget_surface_state.zig`

**No behavior changes:** Both functions compute the same conjunction with the same leg values; removal of meaningless assertion only.

**No ABI/C export changes:** This is internal widget state code.

## Ready for CZH-852

✓ Root cause identified: nonsensical assertion on bool fields with defaults
✓ Real contract documented: both legs have sensible defaults, assertion was spurious
✓ Fix scope locked: remove assertion helper and update documentation
✓ No behavior impact: conjunction computation unchanged
✓ Proceeding with implementation (CZH-852)

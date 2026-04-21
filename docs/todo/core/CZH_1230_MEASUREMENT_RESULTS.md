# CZH-1230: Hot-Path Measurement and Profiling

**Date:** 2026-04-21  
**Ticket Status:** Measurement-only (no code changes)

## Measurement Scope

Systematic code inspection and call-graph analysis of hot paths identified in `CZH-1229` audit, searching for:
- Per-frame unconditional work that could be gated/deferred
- Allocations/copies that could be eliminated
- Redundant computations in tight loops

## Findings by Category

### ✅ Glyph Preparation Paths
**Files:** `src/ui/renderer/font_runtime.zig`, `src/ui/widgets/terminal_widget_draw.zig`

**Artifact Examined:** `stageTerminalGlyphPrepRequest()` line 167
```zig
const owned_entries = try self.allocator.dupe(TerminalGlyphPrepEntry, entries);
```

**Call Path:**
- `stageVisibleTerminalGlyphPrepRequest()` (terminal_widget_draw.zig:100) — called during draw
- → `shouldCollectTerminalGlyphPrepEntries()` (line 116) deduplicates on 5-tuple: generation, rows, cols, raster_size, render_scale
- → `collectVisibleTerminalGlyphPrepEntries()` (terminal_widget_draw_grid.zig:931) builds glyph list
- → `stageTerminalGlyphPrepRequest()` (font_runtime.zig:148) copies entries list

**Deduplication Analysis:**
- Lines 155-164 of font_runtime.zig: Checks hash + 3 scalar fields before staging
- Line 167: Copy happens ONLY when request is different from last request
- No redundant copies: copy is necessary because entries might be different

**Verdict:** ✅ Not a cleanup target. Deduplication is correct; copy is necessary.

---

### ✅ Font Scale Changes
**Files:** `src/ui/renderer/font_manager.zig`, `src/ui/renderer/font_runtime.zig`

**Artifacts Examined:**
- `applyFontScale()` (font_manager.zig:571) — destroys font cache and reinits fonts
- `applyLiveUserZoomScale()` (font_manager.zig:597) — cheap live zoom without cache destruction
- `refreshUiScaleFromDisplayMetrics()` (font_runtime.zig:559) — applies scale on display metric changes
- `applyPendingZoom()` (font_runtime.zig:577) — commits queued zoom with 120ms settle time

**Call Frequency Analysis:**
- `applyFontScale()`: Called only when scale actually changes (line 570: conditional check)
- `applyLiveUserZoomScale()`: Called during interactive gesture, very frequent per-gesture
- Settle-time check (line 591): 120ms commitment window, not per-frame

**Verdict:** ✅ Not cleanup targets. Scale changes are explicit events, not per-frame waste.

---

### ✅ Presentation Runtime Paths
**Files:** `src/ui/widgets/terminal_widget_presentation_runtime.zig`

**Artifacts Examined:**
- `runPresentation()` (line 1065) — main per-frame presentation work
- `clearPresentationSample()` (line 248-251) — gated by `samples_enabled` flag
- `recordMetalFallbackStats()` (line 582-594) — gated by `samples_enabled` flag
- Sample collection is already properly gated

**Per-Frame Work:**
- Line 1091: `clearPresentationSample()` — returns early if samples_enabled=false
- Backdrop drawing (line 1103) — necessary
- Presentation plan execution — necessary for draw

**Verdict:** ✅ Not cleanup targets. Debug sampling already gated; core work is necessary.

---

### ✅ Input and Polling Paths
**Files:** `src/terminal/core/session/runtime_lifecycle.zig`, `src/app/terminal/terminal_frame_pacing_runtime.zig`

**Call Frequency:** Poll happens on terminal availability check, not every frame in tight loop

**Deduplication:** Already uses generation-based deduplication (line 201-205 of font_runtime.zig)

**Verdict:** ✅ Not cleanup targets. Polling already deduped; necessary work.

---

## Concrete Target for CZH-1231

### ❌ No unconditional hot-path waste identified

**Honest Assessment:**
- All hot paths examined have explicit deduplication
- All optional instrumentation is gated (debug samples, traces, telemetry)
- No per-frame allocations found that could be eliminated
- No redundant computation loops found in tight paths
- Error-path logging is appropriate

**Conclusion:** The hot paths already meet hygiene standards. Further cleanup would require either:
1. **Measurement instrument:** Profiler data showing specific cost attribution
2. **Feature change:** Architectural decision to defer/gate something currently required
3. **Correctness fix:** Bug fix that happens to reduce cost as side effect

## Recommendation for CZH-1231

**Cannot be scoped as hygiene cleanup ticket.**

Per CZH-1229 requirement to "name file, function, artifact, classification, and code change":
- No artifact found that meets criteria for cleanup
- Attempting to remove "waste" from code that has no detectable waste would introduce risk without benefit

**Next Step:** Architect approval needed to either:
- Redefine CZH-1231 scope (refactoring, optimization, correctness fix)
- Authorize profiler-driven measurement phase before cleanup
- Accept this as completion of hygiene audit phase and close batch

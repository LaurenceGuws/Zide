# CZH-1235: Widget Naming/Topology Cut Map

**Date:** 2026-04-21  
**Scope:** Inventory `src/ui/widgets/` and define first bounded rename/topology cuts for extraction readiness.

---

## Current Widget Inventory

**Total files:** 39 modules, ~15,400 lines  
**Module categories:** 
- Editor widgets (8 files)
- Terminal widgets (23 files) 
- Shared widgets (6 files)
- Common utilities (2 files)

**Terminal widgets breakdown:**
- Main widget: `terminal_widget.zig` (facade)
- Draw subsystem: 5 files (draw.zig, draw_grid.zig, draw_metrics.zig, draw_overlay.zig, draw_presentation.zig)
- Presentation runtime: 2 files (presentation_runtime.zig, presentation_state.zig)
- Input subsystem: 7 files (input.zig, input_adapter.zig, keyboard.zig, pointer.zig, mouse_reporting.zig, paste.zig, hover.zig)
- State subsystem: 4 files (controller_state.zig, surface_state.zig, publication_state.zig, view_state.zig)
- Other: 3 files (kitty.zig, open.zig) + 2 debug files

---

## Naming Issues Identified

### Issue 1: Input Subsystem Scattered Across Files
**Problem:** Input-related functionality split without clear module boundary:
- `terminal_widget_input.zig` — main input processing
- `terminal_widget_input_adapter.zig` — adapter layer (vague name, unclear ownership)
- `terminal_widget_keyboard.zig` — keyboard input
- `terminal_widget_pointer.zig` — mouse position / click input
- `terminal_widget_mouse_reporting.zig` — protocol-level mouse reporting (confusing: is this input or output?)
- `terminal_widget_paste.zig` — paste handling
- `terminal_widget_hover.zig` — hover state (naming lacks context: hover what?)

**Current boundary:** No clear seam; all methods exposed on main `TerminalWidget` struct via imports

**Impact:** Code extractors cannot reason about input ownership; modules interdependent

---

### Issue 2: Draw vs Presentation Naming Conflict
**Problem:** "Presentation" appears in multiple contexts with different meanings:
- `terminal_widget_draw_presentation.zig` — **draw-time decisions** (reuse/refresh/direct), not runtime
- `terminal_widget_presentation_runtime.zig` — **execution** of presentation (GPU ops, state mutation)
- `terminal_widget_presentation_state.zig` — **state** for presentation cache/invalidation

**Current confusion:** Caller reads `draw_presentation` and expects presentation-time logic; actually contains draw-plan decisions

**Impact:** Misleading module names; extraction requires renaming to clarify ownership

---

### Issue 3: State Files Use Generic Adjectives
**Problem:** State modules named by what they hold, not by what they own:
- `terminal_widget_controller_state.zig` (internal controller borrow logic)
- `terminal_widget_surface_state.zig` (host-facing surface attachment state)
- `terminal_widget_publication_state.zig` (publication generation/cache state)
- `terminal_widget_view_state.zig` (viewport scroll/geometry state)

**Current issue:** Names don't clarify ownership relationships; external callers unsure which state object to mutate when

**Impact:** Refactorers avoid touching state layers due to unclear boundaries

---

## Non-Goals for This Sprint

❌ Do not reorganize all terminal input handling into one `terminal_input/` folder  
❌ Do not split shared_top_bar into separate module  
❌ Do not reorganize editor widget draw path in this sprint  
❌ Do not rename state files without corresponding ownership clarity gains

---

## First Two Code Cuts

### CZH-1236: Terminal Input Subsystem Naming Clarity

**Target:** Rename scattered input files to clarify subsystem boundary

**Concrete renames:**
1. `terminal_widget_input_adapter.zig` → `terminal_widget_input_bridge.zig`
   - **Reason:** "adapter" is vague; "bridge" clarifies it translates host input to product input
   - **Import sites identified (9):**
     - `src/ui/widgets/terminal_widget.zig`
     - `src/ui/widgets/terminal_widget_input.zig`
     - `src/ui/widgets/terminal_widget_keyboard.zig`
     - `src/ui/widgets/terminal_widget_pointer.zig`
     - `src/ui/widgets/terminal_widget_paste.zig`
     - `src/ui/widgets/terminal_widget_open.zig`
     - `src/ui/widgets/terminal_widget_mouse_reporting.zig` (rename partner file)
     - `src/app/macos_metal_terminal_diagnostic_runtime.zig`
     - any transitive compile/test sites through these imports

2. `terminal_widget_mouse_reporting.zig` → `terminal_widget_output_protocol_mouse.zig`
   - **Reason:** "mouse_reporting" sounds like input; actually outputs mouse protocol responses
   - **Clarification:** "output_protocol" makes it clear this is terminal → host, not input
   - **Import sites identified (1):**
     - `src/ui/widgets/terminal_widget_input.zig`
   - **Tests affected:** Any tests that reference terminal mouse state

**Non-code changes:**
- Update comments in `terminal_widget.zig` input() method to document input ownership boundaries
- Add module-level doc to `input_bridge.zig` clarifying it's the sole host->product input translation seam

**Acceptance:**
- Rename operations complete
- Imports updated
- Tests passing
- Comments clarify that all product input routes through these two seams

---

### CZH-1237: Presentation Naming Disambiguation

**Target:** Rename presentation files to clarify draw-time vs runtime vs state ownership

**Concrete renames:**
1. `terminal_widget_draw_presentation.zig` → `terminal_widget_draw_plan.zig`
   - **Reason:** File contains draw-**plan** logic (reuse/refresh/direct decision), not presentation execution
   - **Clarification:** "plan" is concrete; readers understand this is decision-logic before GPU work
   - **Import sites identified (2):**
     - `src/ui/widgets/terminal_widget_draw.zig`
     - `src/ui/widgets/terminal_widget_presentation_runtime.zig`
   - **Type renames:** `FullFrameFastPathDecision` → `DrawPlanDecision` (if used publicly)

2. `terminal_widget_presentation_state.zig` → `terminal_widget_presentation_cache_state.zig`
   - **Reason:** File owns presentation **cache** invalidation, not presentation execution state
   - **Clarification:** "cache_state" is precise; readers know this is about cached presentable state, not GPU submission
   - **Import sites identified (3):**
     - `src/ui/widgets/terminal_widget_presentation_runtime.zig`
     - `src/ui/widgets/terminal_widget_surface_state.zig`
     - any dependent compile/test sites through these modules

**Non-code changes:**
- Add module-level doc to `draw_plan.zig`: "Draw planning and execution selection (before GPU work)"
- Add module-level doc to `presentation_runtime.zig`: "Presentation execution (GPU operations and state mutation)"
- Add module-level doc to `presentation_cache_state.zig`: "Presentation cache invalidation and lifecycle"

**Acceptance:**
- Renames complete
- Imports updated and tested
- Module-level docs added (see ENGINEERING.md reference pattern)
- Tests passing
- Boundary between plan/runtime/cache is now clear to readers

---

## Topology Cuts for Future Tickets

### CZH-1238 (First topology cut):
**Candidate 1:** Extract `terminal_widget_view_state.zig` into dedicated view module
- Current: Standalone file, used only by main widget
- Proposal: Keep as-is for CZH-S74; no extraction benefit until presentation state refactored
- **Decision:** Defer

**Candidate 2:** Consolidate "output protocol" modules
- `terminal_widget_output_protocol_mouse.zig` (will be renamed from mouse_reporting)
- Potential: Move to `terminal_widget_output_protocol/` folder with mouse.zig submodule
- **Decision:** Not yet; wait for hygiene+naming to stabilize before topology split

**Recommended topology cut for CZH-1238:**
- Separate `terminal_widget_open.zig` into `terminal_widget_command/open.zig` (preparation for command subsystem extraction)
- Clarification: Opens are handled as commands, not input

---

## Extraction Readiness Checklist

After CZH-1236 + CZH-1237 complete, extraction becomes feasible when:
- ✅ Input subsystem boundary is clear (bridge + output_protocol)
- ✅ Presentation subsystem naming disambiguated (plan + runtime + cache)
- ⚠️ State ownership clarified (still pending; may be separate sprint)
- ⚠️ Draw grid/metrics/overlay subsystem boundary established (pending CZH-S75)

---

## Summary Table

| File | Current Name | Target Name | Reason | CZH |
|------|--------------|-------------|--------|-----|
| terminal_widget_input_adapter.zig | (vague) | input_bridge.zig | clarify host→product translation seam | 1236 |
| terminal_widget_mouse_reporting.zig | (input-sounds) | output_protocol_mouse.zig | clarify product→host protocol, not input | 1236 |
| terminal_widget_draw_presentation.zig | (confusing) | draw_plan.zig | clarify this is planning, not execution | 1237 |
| terminal_widget_presentation_state.zig | (vague) | presentation_cache_state.zig | clarify this owns cache lifecycle | 1237 |

---

## Next Steps

**CZH-1236 execution:** Rename `terminal_widget_input_adapter.zig` → `terminal_widget_input_bridge.zig` + `terminal_widget_mouse_reporting.zig` → `terminal_widget_output_protocol_mouse.zig`

**CZH-1237 execution:** Rename `terminal_widget_draw_presentation.zig` → `terminal_widget_draw_plan.zig` + `terminal_widget_presentation_state.zig` → `terminal_widget_presentation_cache_state.zig`

**Validation:** All tests pass, imports resolve, module boundaries are clearer to future readers

# Agent Handover (Editor Modularization)

Date: 2026-01-24

## Progress
- Terminal modularization steps 6–10 complete and committed.
- Added terminal import layering check: `zig build check-terminal-imports`.
- Added editor modularization plan: `app_architecture/editor/MODULARIZATION_PLAN.md`.
- Updated editor docs to reflect modularization focus.
- Removed stale `src/terminal_replay_tests.zig`.
- Editor modularization Step 1: selection helpers extracted to `src/editor/view/selection.zig`.
- Editor modularization Step 2: layout helpers extracted to `src/editor/view/layout.zig`.
- Editor modularization Step 3: scroll helpers extracted to `src/editor/view/scroll.zig`.
- Editor modularization Step 4 (prep): added `src/editor/render/draw_list.zig`.
- Editor modularization Step 5: input handlers extracted to `src/ui/widgets/editor_widget_input.zig`.
- Editor modularization Step 6: renderer editor helpers extracted to `src/editor/render/renderer_ops.zig`.
- Editor modularization Step 7: draw orchestration extracted to `src/ui/widgets/editor_widget_draw.zig`.
- Added editor import layering check: `zig build check-editor-imports`.
- Added editor render snapshot harness in `src/editor_tests.zig` (draw ops log baseline).
- Added editor render cache + dirty redraw path (EditorRenderCache + editor texture draw).
- Editor cached rendering is now in main draw loop (EditorWidget.drawCached).
- Integrated EditorDrawList command buffer into cached draw path.
- Added render cache regression test for dirty-line updates.
- Tightened render cache eviction to prune older entries before clearing.
- Routed cached scrollbars through the draw list.
- Routed non-cached scrollbars through the draw list.
- Added cached draw snapshot baseline test.
- Added tree-sitter integration task list (Neovim-based).
- Implemented tree-sitter query loading from runtime paths with per-language query cache.
- Cached draw now records segment hashes even on forced redraws.

## Overview
- Terminal module split is stable; import layering enforced.
- Editor work moved from extraction-only into render-performance changes (cache + dirty redraw), backed by a render snapshot harness.
  - Selection/column mapping helpers moved into `editor/view/selection.zig`.
  - Visual line layout helper moved into `editor/view/layout.zig`.
  - Scrollbar drag mapping helpers moved into `editor/view/scroll.zig`.
  - Render draw list skeleton added under `editor/render/`.
  - EditorWidget input methods now route through `editor_widget_input.zig`.
  - EditorWidget draw methods now route through `editor_widget_draw.zig`.
  - Renderer editor-specific helpers now live in `editor/render/renderer_ops.zig`.
  - `zig build` passes after making input-called helpers public.
  - Tree-sitter integration focus documented; tasks tracked separately.
  - Tree-sitter highlight queries now load from runtime paths and skip `_` captures.
  - Highlight precompute now initializes the highlighter in cached draw paths.

## Next Steps
1) Add render cache stress test for eviction behavior.
2) Evaluate draw list usage for text runs outside cached path.
3) Add cached draw selection/highlight coverage in tests.
4) Tree-sitter highlight integration planning tasks (see treesitter_todo.yaml).

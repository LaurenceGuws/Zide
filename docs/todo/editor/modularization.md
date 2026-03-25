# Editor Modularization Plan

Date: 2026-01-24

Goal: split the editor into clear layers with stable APIs so we can grow features without ballooning `editor_widget.zig` or `renderer.zig`.

Status note, 2026-03-15:

- The large-file split is materially underway; this file should now be read as
  current target structure plus remaining work, not as a running diary.
- Detailed dated extraction history belongs in a compact historical appendix,
  not in the main authority path.
- Current editor architecture context also lives in:
  - `app_architecture/editor/DESIGN.md`
  - `docs/todo/editor/widget.md`
  - `docs/todo/editor/protocol.md`

## Scope
- Editor widget + text engine + syntax + rendering pipeline (editor-side).
- Preserve current behavior; start with extraction-only refactors.
- Keep hot paths allocation-light (per editor design principles).

## Constraints
- Small, reviewable diffs.
- No behavior changes during extraction-only refactors.
- Behavior changes require a harness-backed baseline (now in place for editor render).
- Validation for editor slices should include `zig build test`,
  `zig build check-editor-imports`, and `zig build -Doptimize=ReleaseFast`.

## Related Tracking
- Tree-sitter integration tasks live in `docs/todo/editor/treesitter.md`.

## Target Layer Split
1) UI Widget (input + draw orchestration)
   - `src/ui/widgets/editor_widget.zig`
2) View Model (layout, selections, cursor navigation, view state)
   - `src/editor/view/*` (new)
3) Editor Core (commands, undo/redo, selection model)
   - `src/editor/editor.zig`
4) Text Model (rope/piece tree)
   - `src/editor/rope.zig`
5) Syntax/Highlight
   - `src/editor/syntax.zig`
6) Rendering Support (glyph metrics, caching, draw lists)
   - `src/ui/renderer.zig` (split later)

## Proposed Module Map (incremental)
- `src/editor/view/layout.zig` — line/column to pixel mapping, line wrapping, viewport transforms.
- `src/editor/view/cursor.zig` — cursor movement rules (word, line, page).
- `src/editor/view/selection.zig` — selection model + normalization.
- `src/editor/view/scroll.zig` — scroll offsets + caret visibility.
- `src/editor/view/metrics.zig` — cached line metrics (height, column widths).

- `src/editor/render/draw_list.zig` — editor draw primitives (text runs, highlights, cursors).
- `src/editor/render/highlight.zig` — syntax highlight to draw spans.

(Names are targets; start with extracting one subsystem per step.)

## Stable API Surface (proposed)
EditorWidget should depend on:
- `EditorSession` (commands + state)
- `EditorView` (layout/selection/scroll)
- `EditorDrawList` (render-ready primitives)

Proposed contracts (sketch):
- `EditorSession` owns text model + undo/redo.
- `EditorView` owns viewport, cursor, selection, and exposes layout queries.
- `EditorDrawList` is immutable per-frame and allocation-free during render.

## Layering Rules (imports)
- `ui/widgets/editor_widget.zig` → `editor/view/*`, `editor/editor.zig`, `editor/render/*`.
- `editor/view/*` → `editor/editor.zig`, `editor/text_store.zig`, `editor/rope.zig`, `editor/syntax.zig` (read-only), `editor/types.zig`, no UI.
- `editor/render/*` → `editor/view/*`, `editor/syntax.zig`, `editor/types.zig`, no UI.
- `editor/editor.zig` → `editor/text_store.zig`, `editor/rope.zig`, `editor/syntax.zig`, `editor/types.zig` only.

Use `zig build check-editor-imports` to enforce these rules.

## Migration Steps (incremental)
1) Extract view state (cursor + selection) into `src/editor/view/selection.zig`.
2) Extract layout helpers into `src/editor/view/layout.zig`.
3) Extract scrolling logic into `src/editor/view/scroll.zig`.
4) Introduce `EditorDrawList` to decouple rendering.
5) Split `editor_widget.zig` into input + draw orchestration.
6) Split renderer editor-specific code into `src/editor/render/*`.
7) Add editor render snapshot harness (baseline draw ops).
8) Implement render cache + dirty redraw path (render texture + per-seg hashing).

## Progress

Current landed shape:

- selection, layout, scroll, cursor, and metrics helpers are extracted under
  `src/editor/view/*`
- major `editor.zig` responsibilities are being split into focused modules
- major `syntax.zig` responsibilities are being split into focused modules

Current remaining pressure points:

- `editor.zig` still acts as too much of a universal owner/facade
- `syntax.zig` still needs continued contraction toward a narrow root facade
- renderer/editor-specific seams still need clearer ownership once widget-side
  modularization settles

Boundary checkpoint, 2026-03-17:

- editor cursor, gutter, and current-line chrome now render from editor-owned
  draw helpers rather than `Renderer` editor-specific methods
- `src/ui/renderer.zig` remains on generic primitives for editor paths; editor
  chrome assembly lives on the editor/widget side
- wrapped-line traversal and visual cursor-move bridging now live in
  `src/editor/view/runtime.zig`; `EditorWidget` provides line/cluster access but
  no longer owns those traversal rules directly
- visible segment iteration now has an editor-owned helper in
  `src/editor/render/traversal.zig`; the immediate draw path already uses it and
  the cached draw path is the next rebase target
- shared segment paint helpers now live in `src/editor/render/segment_paint.zig`
  and have first-cut seam tests in the owning render modules
- shared gutter/text-origin/visible-line geometry now lives in
  `src/editor/view/chrome_geometry.zig` and is consumed by widget draw/input
- shared scrollbar metrics/geometry now also route through
  `src/editor/view/chrome_geometry.zig` so widget draw/input use one authority
- draw and precompute paths now build an editor-owned frame surface in
  `src/editor/view/frame.zig` so cached/immediate rendering stop reading most
  live editor state directly from widget code
- hit-testing and scrollbar input now also read through that frame/view surface
  for cursor/scroll/line geometry state instead of reaching into raw editor
  state ad hoc
- horizontal cursor-visibility and horizontal scroll target derivation now also
  route through `src/editor/view/runtime.zig` / `src/editor/view/cursor.zig`
  instead of duplicating line-width/cluster work inside `EditorWidget`
- hit-testing, immediate draw, and cached precompute now share a runtime-backed
  line acquisition path for text/clusters/width instead of open-coding buffer
  reads and cluster loading in each widget path
- immediate and cached draw now also share an editor-owned visible-frame /
  per-line prep seam in `src/editor/render/visible_prep.zig` so visible-range
  state assembly is less ad hoc inside widget draw code
- highlight-range acquisition and cached-vs-fallback token selection now also
  route through that `visible_prep.zig` seam instead of living inline in widget
  draw paths
- the next strictness pass should keep shrinking the remaining widget-owned
  editor state reads so the widget becomes orchestration over narrower editor
  view/render facades

## Historical extraction checkpoint (2026-03-10)

- Completed step 1 (selection view extracted).
- Completed step 2 (layout helpers extracted).
- Completed step 3 (scrolling + visual-row mapping delegated to `src/editor/view/scroll.zig`).
- Extracted cursor movement helpers into `src/editor/view/cursor.zig`.
- Extracted viewport + line metrics helpers into `src/editor/view/metrics.zig`.
- 2026-03-10: began the `editor.zig` large-file split by extracting the search/highlight subsystem into `src/editor/search_highlight.zig`; `editor.zig` now delegates search worker lifecycle, regex matching, query replacement, and highlighter lifecycle through a focused subsystem module instead of carrying that logic inline.
- 2026-03-10: continued the `editor.zig` split by extracting selection state, multi-caret movement, rectangular selection expansion, and undo-selection bookkeeping into `src/editor/selection_state.zig`; `editor.zig` now owns less raw selection machinery directly.
- 2026-03-10: continued the `editor.zig` split by extracting cursor navigation, selection-extension commands, and cursor position/setter bookkeeping into `src/editor/navigation.zig`; `editor.zig` is now much closer to an edit-operation facade.
- 2026-03-10: continued the `editor.zig` split by extracting text mutation operations into `src/editor/edit_ops.zig`; insert/delete/replace flows and mutation-side highlight update plumbing now live outside the root editor owner.
- 2026-03-10: began the `syntax.zig` large-file split by extracting query loading, capture-kind mapping, and query-cache ownership into `src/editor/syntax_queries.zig`; `syntax.zig` now keeps more of the actual runtime highlight/injection execution and less cache/bootstrap code inline.
- 2026-03-10: continued the `syntax.zig` split by extracting syntax highlighter runtime lifecycle, layered highlighting, injected-language loading, and injection execution into `src/editor/syntax_runtime.zig`; `syntax.zig` now leans more toward predicate/directive/token utility ownership.
- 2026-03-10: continued the `syntax.zig` split by extracting predicate evaluation, directive handling, injection-setting collection, node-text helpers, and the simple regex matcher into `src/editor/syntax_predicates.zig`; `syntax.zig` is now down to 855 LOC and is primarily a facade over query/runtime/predicate modules plus token overlap assembly.
- 2026-03-10: finished the `syntax.zig` split by extracting highlight-token overlap splitting/post-processing into `src/editor/syntax_tokens.zig`; `syntax.zig` is now down to 733 LOC and acts as the root syntax facade over focused subsystem modules rather than a god-file.
- 2026-03-26: began editor-side adoption of the shared runtime-policy vocabulary in `src/editor/search_highlight.zig`; search scheduling, worker fallback, stale-result drops, and highlight scheduling logs now use explicit editor interactive/background intents instead of only ad hoc pending/worker wording.
- 2026-03-26: added editor-owned search/highlight runtime counters in `src/editor/editor.zig` and surfaced them through `src/app/editor/editor_display_prepare.zig`, so async scheduling, sync fallbacks, stale-result drops, worker spawn failures, large-file highlight skips, and highlight init attempts now have measurable per-epoch totals.

## Non-goals (for now)
- No new features or UI changes.
- No text model changes unless tests are added first.
- No renderer-wide refactors before editor harness exists.

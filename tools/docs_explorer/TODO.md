# Docs Explorer Todo

## Current Priority

### Tree widget cleanup

- [ ] Replace the current active-branch connector approximation with true
      row-owned tree geometry.
      - Every row should own:
        - vertical continuation
        - horizontal elbow
        - active-path highlight
      - Do not keep extending the current container-height hack.
      - Authority:
        - [design/TREE_WIDGET.md](/home/home/personal/zide/tools/docs_explorer/design/TREE_WIDGET.md)
- [ ] Redesign the open-folder joint before changing CSS again.
      - Closed `>` state stays as-is.
      - Open state must use the same row-owned connector grammar.
      - Do not add `summary` or `.folder-children` continuation patches.

### Full-text search

- [x] Add a separate ripgrep-backed header search instead of overloading the
      sidebar tree filter.
      - Sidebar input remains path/tree filtering only.
      - Header search now streams local `rg` hits into a modal result list.
- [ ] Polish search-hit navigation so focusing a result in the rendered viewer
      is more exact than first-match term highlighting.
- [ ] Decide what the hosted/pages story should be for full-text search.
      - Current behavior is local-dev only via `docs_explorer.py`.

### Theme and shell cleanup

- [~] Keep the shell theme system token-driven instead of letting component CSS
      grow local one-off surfaces.
      - Outer shell/header/pane/control/viewer materials now derive much more
        cleanly from `theme.css`.
      - Remaining work: continue removing component-local background formulas
        when a named theme token would be clearer.
- [ ] Audit dark/light drift through theme tokens first and component rules
      second.
- [x] Keep project config limited to base palette overrides.
      - Derived shell/control/viewer materials remain CSS-owned.
      - Do not expand config into per-component styling knobs by default.
- [ ] Keep the app header intentionally small and shell-level.
      - Avoid turning it back into a document breadcrumb/navigation bar.

### State foundation

- [~] Introduce a dedicated app-state module instead of storing behavior across
      `main.js`, DOM attributes, and `localStorage` calls.
      - `ts/state.ts` now owns the first persistence/default seams.
      - Remaining work: options/search/current-doc state transitions still need
        a cleaner shared model and less direct DOM orchestration.
- [ ] Define a clear state shape for:
      - current doc
      - theme
      - sidebar width
      - sidebar collapsed state
      - options menu state
      - search query
      - document header/load state
      - tree filter/active state
      - viewer body render state
- [ ] Centralize persistence reads/writes behind a small state/persistence seam.
- [ ] Keep typing work sequenced after the module/state split.
      - First stabilize module boundaries and state ownership.
      - Then keep TypeScript aligned to those stable seams.
      - Avoid using types to justify muddled ownership.

### Module refactor

- [~] Split the old `main.js` monolith into concern-owned modules.
      - app bootstrap
      - layout/sidebar controls
      - options/menu controls
      - state/config wiring
      - Current extraction landed:
        - `ts/app.ts`
        - `ts/shell/app_shell.ts`
        - `ts/docs/doc_controller.ts`
        - `ts/docs/doc_routing.ts`
        - `ts/docs/doc_render_cycle.ts`
        - `ts/config.ts`
        - `ts/state.ts`
        - `ts/tree/tree_state.ts`
        - `ts/docs/view_state.ts`
        - `ts/docs/viewer_state.ts`
        - `ts/layout.ts`
        - `ts/options_menu.ts`
      - Remaining work:
        - keep `ts/docs/doc_controller.ts` as assembly only
        - continue shrinking cross-module DOM assumptions
- [x] Rename the source tree from `js/` to `ts/` and group modules by concern.
      - `docs/`, `tree/`, `theme/`, `shell/`, and `shared/` now own the main
        source seams.
- [x] Split tree and shell internals so concern folders are structural, not
      cosmetic.
      - `ts/tree/` now separates model, markup, state, and DOM orchestration.
      - `ts/shell/` now separates DOM lookup, icon injection, and shell boot.

### Config-driven identity

- [~] Move project identity into config instead of code/CSS edits.
      - Title/icon/default doc already live in `config/project.json`.
      - Brand-level light/dark palette overrides now live there too.
      - More shell/control/viewer surface behavior now derives from those base
        palette tokens.
      - Repo fetch base path now lives there too.
      - Remaining work: decide how far config should go beyond palette/base
        tokens without turning the tool into a per-project styling DSL.
- [x] Split `styles/base.css` by concern.
      - `base.css` is now the import root.
      - `theme.css`, `shell.css`, `tree.css`, `controls.css`,
        `viewer.css`, and `responsive.css` now own the main style seams.

### Python vs JS ownership

- [ ] Keep `docs_explorer.py` minimal and document the rule that Python is only
      for serving and optional generation tasks.
- [ ] If doc-index generation is automated, add a separate generation script
      rather than bloating the launcher.

## Nice To Have

- [ ] Keyboard escape to close options menu.
- [ ] Persist expanded tree folders.
- [ ] Better iconography for controls.
- [ ] Auto-generate `config/docs-index.json`.
- [x] Add support for multiple project configs.
- [ ] Add a short local style-guide note for shell materials so future UI work
      does not reintroduce per-widget background drift.

## Deliberately Deferred

- [ ] Framework migration.
- [ ] Search indexing beyond simple path filtering.
- [ ] Rich YAML-specific rendering.

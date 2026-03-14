# Docs Explorer Todo

## Current Priority

### State foundation

- [~] Introduce a dedicated app-state module instead of storing behavior across
      `main.js`, DOM attributes, and `localStorage` calls.
      - `js/state.js` now owns the first persistence/default seams.
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
      - Then move straight to real TypeScript.
      - Lightweight JSDoc is allowed only as a temporary seam aid.
      - Initial TS migration has started from the stable center.

### Module refactor

- [~] Split `js/main.js` into:
      - app bootstrap
      - layout/sidebar controls
      - options/menu controls
      - state/config wiring
      - Current extraction landed:
        - `js/app.js`
        - `js/app_shell.js`
        - `js/doc_controller.js`
        - `js/config.js`
        - `js/state.js`
        - `js/tree_state.js`
        - `js/view_state.js`
        - `js/viewer_state.js`
        - `js/layout.js`
        - `js/options_menu.js`
      - Remaining work:
        - give state transitions a cleaner module boundary

### Config-driven identity

- [~] Move project identity into config instead of code/CSS edits.
      - Title/icon/default doc already live in `config/project.json`.
      - Brand-level light/dark palette overrides now live there too.
      - Remaining work: decide whether typography and more shell accents belong
        in config or should stay in CSS defaults.
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
- [ ] Add support for multiple project configs.

## Deliberately Deferred

- [ ] Framework migration.
- [ ] Search indexing beyond simple path filtering.
- [ ] Rich YAML-specific rendering.

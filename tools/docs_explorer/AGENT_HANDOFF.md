# Docs Explorer Handoff

## Current State

- The docs explorer is now a small reusable static app under
  `tools/docs_explorer/`.
- It has been split into:
  - `index.html` shell
  - `styles/base.css`
  - `js/` modules
  - `config/project.json`
  - `config/docs-index.json`
  - `docs_explorer.py` local launcher
- Runtime extraction has started:
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
  - `js/project_theme.js`
- TypeScript migration has started from the stable center.
- Current build path:
  - `npm run build:docs-explorer`
  - output goes to `tools/docs_explorer/build/js/`
- The UI now supports:
  - dark/light theme toggle
  - Markdown rendering
  - Mermaid rendering
  - collapsible tree navigation
  - resizable sidebar groundwork
  - options popover

## Current Focus

- Refactor large files into tighter, more focused modules.
- Establish a solid state-handling base before adding more features.
- Make Python-vs-JS ownership explicit so the tool does not drift.
- Keep project identity config-driven where that improves reuse across repos.

## Ownership Direction

### Python

Python should stay minimal and boring.

Own only:

- local static-file serving
- optional offline/local generation tasks
- optional index/config generation scripts

Do not let Python become:

- runtime app state owner
- renderer/controller logic
- UI composition layer

### JavaScript

JavaScript should own the browser app runtime.

Own:

- UI state
- navigation state
- theme state
- sidebar/layout state
- Markdown/Mermaid orchestration
- user interactions

## Immediate Next Work

1. Refactor any remaining large UI/runtime files into focused modules.
2. Introduce an explicit app-state model for:
   - current doc
   - theme
   - sidebar width
   - sidebar collapsed state
   - options menu open/closed state
   - search query
3. Keep config loading and app runtime separate.
4. Decide whether doc-index generation remains manual JSON or becomes a small
   build/refresh utility.
5. Keep TypeScript discussion sequenced after the file-split/state-boundary
   work, not before it.
   - When the time is right, move straight to TypeScript.
   - Do not spend effort on a longer-term `checkJs` path.
6. Be deliberate about config scope:
   - title/icon/default doc/palette are good config candidates
   - avoid turning config into an unstructured CSS dump

## Constraints

- Keep all docs for this tool inside `tools/docs_explorer/`.
- Do not update main repo docs for tool-internal iteration unless explicitly
  requested.
- Prefer simple static-app architecture over framework adoption.
- Reusability across repos matters, so keep project config separate from app
  logic.

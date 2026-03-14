# Docs Explorer Architecture

## Goal

Provide a lightweight, reusable local docs browser for repo Markdown without
requiring a frontend framework or backend service.

## Current Structure

- `index.html`
  - minimal shell and mount points only
- `js/app_shell.js`
  - DOM lookup
  - shell branding/title/icon wiring
  - shell theme/bootstrap initialization
- `js/app.js`
  - application composition root
  - runtime wiring between state, shell, docs, layout, and options
- `tsconfig.json`
  - minimal TypeScript compile config for docs explorer
  - emits browser ESM into `build/js`
- `styles/base.css`
  - stylesheet manifest/import root
- `styles/theme.css`
  - theme tokens and theme-level defaults
- `styles/shell.css`
  - shell layout and outer chrome
- `styles/tree.css`
  - sidebar search/tree styling
- `styles/controls.css`
  - buttons, options menu, theme toggle
- `styles/viewer.css`
  - rendered markdown content styling
- `styles/responsive.css`
  - responsive and collapsed-sidebar rules
- `js/main.js`
  - tiny entrypoint only
- `js/config.js`
  - project/docs index loading
- `js/state.js`
  - app-state defaults and persistence helpers
- `js/types.js`
  - shared JSDoc typedefs for state/config/shell contracts
- `js/layout.js`
  - sidebar width/collapse behavior
- `js/options_menu.js`
  - options popover behavior
- `js/doc_controller.js`
  - document loading
  - hash/search wiring
  - document tree refresh
  - theme-triggered Mermaid rerender delegation
- `js/view_state.js`
  - document header/status state transitions
  - document chrome rendering from explicit state
- `js/tree_state.js`
  - tree filter/active-path state transitions
  - tree rendering from explicit state
- `js/viewer_state.js`
  - viewer body render state transitions
  - loading/error/content HTML rendering from explicit state
- `js/tree.js`
  - tree rendering and active-node sync
- `js/viewer.js`
  - document loading and viewer updates
- `js/theme.js`
  - theme selection and persistence
- `js/mermaid.js`
  - Mermaid initialization and rerendering
- `js/markdown.js`
  - Markdown renderer setup
- `js/utils.js`
  - small shared helpers
- `config/project.json`
  - project-specific title/icon/defaults
  - project-specific palette overrides for light/dark theme identity
- `config/docs-index.json`
  - project-specific doc list
- `docs_explorer.py`
  - local launcher

## Runtime Ownership

### Browser app

The browser runtime is the real app.

It should own:

- app state
- UI state transitions
- view rendering
- persistence in `localStorage`
- project config loading
- doc fetch lifecycle

### Python launcher

The launcher is support infrastructure only.

It should own:

- local HTTP serving
- optional future helper commands

It should not own:

- app state
- routing
- navigation decisions
- rendering decisions

## State Model Direction

The app should converge toward one explicit state object instead of scattered
DOM-driven updates.

Recommended app state shape:

- `project`
- `docs`
- `current_doc`
- `theme`
- `sidebar.width`
- `sidebar.collapsed`
- `options_menu.open`
- `search.query`

The first explicit state step is now in `js/state.js`, but transitions are
still only partially centralized. The next goal is to make the remaining view
updates flow through clearer state/controller seams instead of ad hoc event
handlers.

Theme is now part of explicit app state rather than being owned only through
DOM reads and local storage helpers.
Document header/load state is now also moving into explicit app state instead
of being mutated directly inside document-loading code.
Tree filter/active state is moving the same way so the tree is no longer a
special-case DOM island.
Viewer body rendering is now moving the same way, reducing the amount of inline
presentation logic in `viewer.js`.

Recommended pattern:

- state mutations happen through named functions
- DOM updates are triggered from those state transitions
- persistence is centralized instead of scattered across modules

This does not require React or another framework. A small explicit state module
is enough.

The current typing direction is:

- the stable center has started moving to `.ts`
- browser output is compiled into `build/js`
- remaining `.js` modules can move over incrementally
- no long-lived `checkJs` path

## Typing Direction

Do not move to TypeScript before the large file splits and state-boundary work
are done.

Reason:

- current risk is muddled ownership and mixed concerns, not lack of type syntax
- moving to TypeScript too early would type temporary seams and then force those
  types to be rewritten during the refactor
- the cleaner order is:
  - split large files
  - define explicit runtime state ownership
  - stabilize module contracts
  - then move to real `.ts`

Short rule:

- architecture first
- types second

If the browser-side state model grows enough that contract drift becomes a real
risk, TypeScript becomes much more attractive. Until then, keep the codebase
light and focus on module/state shape first.

## Reuse Direction

To reuse this tool across repos:

- keep the app generic
- move repo-specific identity into config
- move doc-index generation into a small optional helper

The generic app should not know about Zide-specific architecture concepts.
It also should not require CSS edits for simple project-level branding changes.

## Refactor Targets

Current likely next candidates:

- `styles/base.css`
  - now just the stylesheet entrypoint/import manifest
- `js/app.js`
  - good current composition root; avoid letting it bloat back into a new
    monolith

## Non-goals

- no SPA framework migration unless the tool becomes dramatically more complex
- no backend dependency
- no custom Markdown authoring workflow
- no duplication of source docs inside the tool

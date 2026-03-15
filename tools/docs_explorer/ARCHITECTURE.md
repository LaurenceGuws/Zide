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
  - theme tokens and derived shell/control/viewer surface formulas
- `styles/shell.css`
  - app-shell layout and outer chrome
  - atmospheric background field
  - app-level header above sidebar and content
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
  - project-specific light/dark palette overrides
  - explicit `repoBasePath` for hosted/local content fetches
- `config/project.pages.json`
  - alternate hosted/pages config without mutating local defaults
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

The app should keep converging toward one explicit state object instead of
scattered DOM-driven updates.

Current app state shape is centered on:

- `current_doc`
- `theme`
- `sidebar.width`
- `sidebar.collapsed`
- `options_menu.open`
- `search.query`
- `document.title`
- `document.subtitle`
- `document.raw_link`
- `viewer.html`
- `tree.filter`
- `tree.active_path`
- `tree.expanded_paths`

The next cleanup goal is not "add more features" but to keep reducing places
where DOM structure or CSS-specific assumptions leak across module boundaries.

Theme is now part of explicit app state rather than being owned only through
DOM reads and local storage helpers. Document chrome, tree state, and viewer
body state now also flow through explicit controller/state seams instead of
being mutated ad hoc inside the fetch/render path.

Recommended pattern:

- state mutations happen through named functions
- DOM updates are triggered from those state transitions
- persistence is centralized instead of scattered across modules

This does not require React or another framework. A small explicit state module
is enough.

The current typing direction is:

- the browser app center is now on `.ts`
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
- support multiple project config variants when runtime pathing differs

The generic app should not know about Zide-specific architecture concepts.
It also should not require CSS edits for simple project-level branding changes.
Hosted/local path handling should be explicit in config rather than buried in
hardcoded relative URL helpers.

## Current Shell Model

The current shell should follow one simple visual rule:

- the outer shell owns atmosphere
- panes own material layers
- small wrappers and controls should prefer transparency, border, and hover
  state before adding their own local fill

That means:

- avoid per-widget decorative backgrounds when a pane/token already exists
- keep shell/control/viewer materials derived from theme tokens
- do not let local one-off `color-mix(...)` values grow faster than the token
  system

## Refactor Targets

Current likely next candidates:

- `styles/theme.css`
  - continue consolidating repeated surface formulas into named tokens
- `js/view_state.ts`
  - keep document chrome intentionally small and avoid letting app-shell
    branding/navigation concerns turn back into document-specific chrome
- `js/app.js`
  - keep it as composition root only; do not let it bloat back into a new
    monolith

## Non-goals

- no SPA framework migration unless the tool becomes dramatically more complex
- no backend dependency
- no custom Markdown authoring workflow
- no duplication of source docs inside the tool

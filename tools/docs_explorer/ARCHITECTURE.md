# Docs Explorer Architecture

## Goal

Provide a lightweight, reusable local docs browser for repo Markdown without
requiring a frontend framework or backend service.

## Current Structure

- `index.html`
  - minimal shell and mount points only
- `ts/shell/shell_dom.ts`
  - DOM lookup
  - required shell element contract
- `ts/shell/shell_icons.ts`
  - shell icon asset injection
  - shared icon sizing normalization
- `ts/shell/app_shell.ts`
  - shell branding/title/source-link wiring
  - shell theme/bootstrap initialization
- `ts/app.ts`
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
- `ts/main.ts`
  - tiny entrypoint only
- `ts/config.ts`
  - project/docs index loading
- `ts/state.ts`
  - app-state defaults and persistence helpers
- `ts/shared/types.ts`
  - shared type contracts for state/config/shell/runtime seams
- `ts/layout.ts`
  - sidebar width/collapse behavior
- `ts/options_menu.ts`
  - options popover behavior
- `ts/docs/doc_controller.ts`
  - small composition seam for docs routing + render lifecycle
  - document tree refresh
  - theme-triggered Mermaid rerender delegation
- `ts/docs/doc_routing.ts`
  - hash/search wiring
  - route/search events separated from document fetch/render lifecycle
- `ts/docs/doc_render_cycle.ts`
  - current-doc resolution
  - document loading lifecycle wiring
  - document chrome update callbacks
  - highlight trigger on ready
- `ts/docs/view_state.ts`
  - document status state transitions
  - small shell-header document chrome rendering from explicit state
- `ts/tree/tree_state.ts`
  - tree filter/active-path state transitions
  - tree rendering from explicit state
- `ts/tree/tree_model.ts`
  - tree model creation from doc paths
- `ts/tree/tree_markup.ts`
  - tree HTML markup generation from the tree model
- `ts/docs/viewer_state.ts`
  - viewer body render state transitions
  - loading/error/content HTML rendering from explicit state
- `ts/tree/tree.ts`
  - tree rendering and active-node sync
- `ts/docs/viewer.ts`
  - document loading and viewer updates
- `ts/theme/theme.ts`
  - theme selection and persistence
- `ts/docs/mermaid.ts`
  - Mermaid initialization and rerendering
- `ts/docs/markdown.ts`
  - Markdown renderer setup
- `ts/shared/utils.ts`
  - small shared helpers
- `ts/shared/vendor_types.ts`
  - typed browser-vendor seams
- `ts/shared/external.d.ts`
  - typed ESM/CDN module declarations
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

- the browser app source lives under `ts/`
- source is grouped by concern instead of one flat source directory
- browser output is compiled into `build/js`
- there is no long-lived `checkJs` path anymore

## Typing Direction

The original caution about “architecture first, types second” still applies,
but the core move to real TypeScript has now happened.

Reason:

- current risk is muddled ownership and mixed concerns, not lack of type syntax
- the value of `.ts` is now in keeping the new module seams explicit and harder
  to erode

Short rule:

- architecture first
- types second
- keep the type layer thin and aligned to stable seams

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
- `ts/docs/view_state.ts`
  - keep document chrome intentionally small and avoid letting app-shell
    branding/navigation concerns turn back into document-specific chrome
- `ts/docs/doc_controller.ts`
  - keep it as composition/assembly only; do not let it become the integration
    junk drawer again
- `ts/app.ts`
  - keep it as composition root only; do not let it bloat back into a new
    monolith
- `ts/tree/`
  - keep model, markup, and DOM orchestration separate as the tree evolves
- `ts/shell/`
  - keep DOM lookup, icon loading, and bootstrap concerns separate

## Non-goals

- no SPA framework migration unless the tool becomes dramatically more complex
- no backend dependency
- no custom Markdown authoring workflow
- no duplication of source docs inside the tool

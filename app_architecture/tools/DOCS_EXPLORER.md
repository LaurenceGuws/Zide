# Docs Explorer

Date: 2026-03-14

Purpose: define the high-level ownership and scope for the local browser-based
 docs explorer under `tools/docs_explorer/`.

## Why it exists

Zide's docs surface has grown enough that opening Markdown files directly is no
longer the best way to browse architecture, reference docs, and active work
queues.

The docs explorer exists to provide:

- a lightweight local wiki-like viewer for `docs/` and `app_architecture/`
- a file-tree navigation surface for active docs
- inline Markdown rendering for architecture/design docs
- inline Mermaid rendering for docs that already use diagrams

This is a local contributor/operator tool, not a product feature.

## Current location

- `tools/docs_explorer/index.html`
- `tools/docs_explorer/docs_explorer.py`
- `tools/docs_explorer/README.md`
- `tools/docs_explorer/config/project.json`
- `tools/docs_explorer/config/project.pages.json`

## Ownership split

### `tools/docs_explorer/`

Owns:

- local serving/bootstrap
- UI shell and navigation tree
- Markdown rendering
- Mermaid rendering
- local docs-viewer behavior

Does not own:

- terminal/runtime architecture truth
- workflow policy
- architecture doc contents themselves

### `docs/` and `app_architecture/`

Remain the source of truth for the rendered content.

The explorer should not become a second documentation source.

## Design goals

- zero-build or near-zero-build local usage
- easy to run from the repo with Python available
- repo-native file navigation rather than a synthetic docs CMS
- visually clear, but still tool-like rather than app-marketing-like

## Non-goals

- no external docs hosting requirement
- no backend service
- no content database
- no attempt to replace Markdown files with a custom editor or schema
- no CI/docs-publish pipeline

## Current constraints

- the viewer currently uses browser-side fetch, so it should be opened through
  the local HTTP launcher rather than directly as `file://`
- the runtime is now a small static app with TypeScript source and generated
  browser ESM output under `tools/docs_explorer/build/js/`
- the doc index is currently JSON-driven (`config/docs-index.json`) rather than
  generated at request time
- YAML files may appear in navigation, but the primary rendering target is
  Markdown
- `main` remains source-only for this tool; hosted GitHub Pages snapshots are a
  release-branch concern

## Expected next steps

- consider auto-generated doc indexing so the tree stays in sync without manual
  edits
- consider persisted navigation state for expanded folders and last-opened doc
- keep the hosted release/docs entrypoint aligned with the local tool so README
  and release docs do not drift from the actual Pages surface

# Tools Layout

This document defines the repository layout contract for `tools/`.

## Rule

`tools/` is a parent directory for tool domains.

It must not accumulate loose root files. New tools should live inside a
domain-specific subdirectory.

## Current Domains

- `tools/build_tools/`
  - build reports, mode gates, and size checks
- `tools/checks/`
  - shared repo policy and import-layer checks
- `tools/docs_browser/`
  - project-owned docs-browser config for the standalone docs explorer
- `tools/docs_explorer/`
  - local docs-explorer implementation workspace
- `tools/editor/`
  - editor-specific theme tooling
- `tools/grammar/`
  - grammar maintenance entrypoints
- `tools/grammar_packs/`
  - grammar-pack source, scripts, work area, and published pack artifacts
- `tools/logs/`
  - log inspection helpers
- `tools/packaging/`
  - packaging and staged-release helpers
- `tools/perf/`
  - performance and resource-capture tooling
- `tools/term_manual_test/`
  - manual terminal-test assets and supporting workspaces
- `tools/terminal/`
  - terminal capture helpers
- `tools/ui/`
  - UI-specific tooling such as font-rendering helpers
- `tools/windows/`
  - Windows-specific contracts and helpers

## Placement Rules

- Put new tools in the narrowest domain that already matches the job.
- Create a new domain only when an existing one would become misleading.
- Keep build graph references and docs aligned with the real path on the same
  change.
- If a tool becomes user- or operator-facing, update the relevant reference or
  architecture doc rather than relying on directory discovery.
- Generated caches such as `__pycache__/` do not belong in the repository.

## Update Rule

When moving or adding tools:

1. update build/script entrypoints
2. update owning docs and examples
3. run local validation against the moved entrypoints

Use `docs/todo/repo_structure.md` for future structural cleanup tracking and
`docs/WORKFLOW.md` for overall documentation placement rules.

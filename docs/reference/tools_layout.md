# Tools Layout

This document defines the repository layout contract for `tools/`.

## Rule

`tools/` is a parent directory for tool domains.

It must not accumulate loose root files. New tools should live inside a
domain-specific subdirectory.

## Current Domains

- `tools/build_tools/`
  - build-related tooling grouped into:
  - `reports/` for build reports and summaries
  - `checks/` for build policy and size checks
  - `gates/` for higher-level workflow gate scripts
  - `smokes/` for manual or operator-run smoke helpers
- `tests/checks/`
  - shared repo policy and import-layer checks
- `app_architecture/docs_browser/`
  - project-owned docs-browser config for the standalone docs explorer
- `tools/docs_explorer/`
  - local docs-explorer implementation workspace
- `tools/editor/`
  - editor-specific tooling, including:
  - `theme/` for theme import and resolved-theme helpers
  - `tree_sitter/` for repo-local consumer/proxy tooling around the
    dedicated grammar producer repo
  - grammar-pack production tooling no longer lives in this repo; see sibling
    repo `../zide-tree-sitter`
- `tools/observability/`
  - observability tooling, including:
  - `logs/` for log inspection helpers
  - `perf/` for performance and resource-capture tooling
  - `rendering/font/` for font-rendering capture and comparison helpers
- `tools/packaging/`
  - packaging helpers, including Windows packaging contracts
- `tools/terminal/`
  - terminal tooling, including:
  - `capture/` for terminal capture helpers
  - `term_manual_test/` for manual terminal-test assets and supporting workspaces

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

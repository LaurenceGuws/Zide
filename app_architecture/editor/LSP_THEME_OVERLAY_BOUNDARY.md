# LSP Theme Overlay Boundary

This document defines the current boundary for LSP and semantic-token theming
relative to the resolved base theme export contract.

It exists to preserve the current exploration/example implementation pressure
without pulling LSP-specific policy into the base theme contract early.

## Status

- this is a deferred boundary, not an active integration lane
- current base-theme work should not expand to absorb LSP overlay policy
- current LSP-related exporter/compare behavior is kept as example/reference
  implementation pressure, not as base-theme authority

## Core Decision

- `@lsp.*` names are not part of the base resolved-theme contract
- LSP and semantic-token theming should be treated as a separate overlay layer

## Why This Boundary Exists

- keeping `@lsp.*` out of base avoids forcing upstream semantic-token/LSP work
  into the core theme-import path
- base theme import should stay focused on stable colorscheme-resolved editor
  theming:
  - `groups`
  - `captures`
  - `links`
  - core style/color keys
- overlay layering is a better fit for runtime-dependent highlight state

## What We Keep As Example Implementation Pressure

Current tooling is still allowed to observe and report LSP overlay names.

That example/reference pressure currently lives in:

- `tools/nvim_resolved_theme_export.lua`
- `tools/nvim_resolved_theme_compare.py`

Current behavior we are intentionally keeping:

- exporter output may include observed `@lsp.*` names in resolved snapshots
- compare output may classify `@lsp.*` names and show which coarse syntax slots
  they help cover
- compare output can be run either:
  - with LSP contribution included
  - or with `--exclude-lsp` for base-only fit reporting

This keeps the future overlay lane concrete without making it a blocker on the
base-theme path.

## Current Example Findings

Using the current `zide-core` preset:

- with LSP contribution included, `tokyonight-night` reaches `21/21` coarse
  syntax slots in the comparison probe
- with `--exclude-lsp`, the same export drops to `18/21`
- the recurring base-only weak spots in the current sample set are:
  - `escape`
  - `function_method`
  - `type_builtin`

This is useful evidence for the future overlay lane:

- LSP overlays materially increase coarse syntax-slot coverage
- that contribution is real and should remain visible in tooling
- but it should not redefine the base contract

## Current Non-goals

- implementing final LSP overlay merge semantics
- deciding final precedence between base theme, Treesitter captures, semantic
  tokens, diagnostics, and user highlights
- forcing importer-side base ingestion to understand `@lsp.*`

## Future Integration Target

When this lane becomes active, it should answer:

- what the LSP overlay artifact shape is
- how it composes on top of the base resolved-theme artifact
- what merge/precedence rules apply between:
  - base groups/captures/links
  - Treesitter-derived highlights
  - semantic tokens / `@lsp.*`
  - diagnostics
  - user/runtime highlights

## Current Authority Links

- base contract:
  - `app_architecture/editor/RESOLVED_THEME_EXPORT_CONTRACT.md`
- owning queue:
  - `docs/todo/editor/theme_import.md`
- editor architecture entrypoint:
  - `app_architecture/editor/DESIGN.md`

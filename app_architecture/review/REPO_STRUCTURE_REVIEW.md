# Repo Structure Review

Date: 2026-03-10

## Scope

This review covers non-product repo structure only:

1. test layout clarity
2. tooling root duplication
3. stale/outdated docs and stale test artifacts

It does not re-rank product architecture ownership inside `src/`.

## Current Findings

### 1. Tests have no explicit repo-wide layout

Current testing assets are split across three different patterns:

- source-adjacent Zig test entry files in `src/`
  - examples: `src/editor_tests.zig`, `src/terminal_reflow_tests.zig`, `src/input_tests.zig`
- subsystem-adjacent test files inside product trees
  - example: `src/terminal/core/terminal_session_tests.zig`
- replay/golden fixtures under `fixtures/`
  - especially `fixtures/terminal/*.{vt,golden,json}`

This is not inherently wrong, but there is no explicit rule describing:

- which tests belong in `src/`
- which tests belong near the subsystem they exercise
- which tests should be grouped under a dedicated `tests/` root
- whether `fixtures/` is authoritative for replay data only, or also for generated evidence

The result is navigation cost and unclear ownership.

### 2. Tooling roots are duplicated

Repo-level tooling currently lives in:

- `tools/`
- `src/tools/`

At review time, `src/tools/` only contained:

- `tools/grammar_fetch.zig`
- `tools/grammar_update.zig`

Those files read like repository maintenance tools, not runtime product modules. This made the split between `tools/` and `src/tools/` look accidental rather than intentional.

### 3. Docs mix active guidance, historical review, and evidence

The current doc surface is broad:

- `docs/` for workflow/handoff/high-level operator docs
- `app_architecture/` for active architecture docs, todos, reviews, migration records, and historical investigations
- fixture/evidence style outputs also exist outside docs, for example terminal replay `.json` files under `fixtures/terminal/`

There is no explicit lifecycle rule for:

- active docs
- historical review docs
- generated evidence / goldens / captured outputs
- stale completed todos

That makes it hard to tell what is still authoritative versus archival.

## Reference Repo Comparison

Local references show much clearer conventions:

- tests usually live under one explicit root such as `test/` or `tests/`
  - examples: `terminals/ghostty/test`, `terminals/foot/tests`, `editors/neovim/test`, `fonts/harfbuzz/test`
- tools usually live under one explicit root such as `tools/`
  - examples: `terminals/kitty/tools`, `rendering/skia/tools`, `terminals/iterm2/tools`
- docs usually live under one explicit root such as `doc/` or `docs/`
  - examples: `terminals/kitty/docs`, `terminals/wezterm/docs`, `editors/helix/docs`

This does not mean Zide should copy one exact layout, but it does mean the current ambiguity is not an unavoidable low-level project pattern.

## Recommended Policy

### Tests

Adopt one explicit repo-wide rule:

- `fixtures/` is for replay inputs, goldens, captured evidence, and stable test assets only
- `tests/` is for integration/harness suites and multi-module test entrypoints
- product-adjacent test files inside `src/` are allowed only when locality materially improves comprehension of a tightly coupled subsystem

That means the problem is not "tests near code"; the problem is "no explicit layout contract."

Status:

- policy written
- `tests/` root established
- aggregate test entrypoint moved out of `src/`
- first category-based re-home landed for generic root-level app/editor/config/layout/widget test entrypoints
- category-based re-homing of scattered root-level test files remains follow-up work

### Tools

Adopt one repo tooling root:

- `tools/` owns repo maintenance, import checks, build reports, grammar management, packaging helpers, and manual test helpers
- `src/tools/` should not exist unless a tool is actually shipped or imported as product/runtime code

### Docs

Adopt a three-way distinction:

- `docs/` = active operator workflow and top-level contributor guidance
- `app_architecture/` = active architecture specs, current plans, and current todos
- `app_architecture/review/` = historical reviews and investigation records

Additionally:

- generated evidence should live with fixtures or dedicated evidence folders, not mixed into active docs
- completed stale todos should be closed or archived instead of lingering as active planning surfaces

## Priority Order

1. define and document the repo-wide testing layout
2. remove the duplicated tooling root by collapsing `src/tools/` into `tools/`
3. classify active vs historical docs and identify stale surfaces for deletion or archival

## Initial Hotspots

Highest-priority structural hotspots:

- scattered Zig test entry files in `src/`
- duplicated `src/tools/` vs `tools/`
- active-vs-historical ambiguity in `app_architecture/`

Lower-priority for now:

- fixture naming consistency inside `fixtures/terminal/`
- manual test assets inside `tools/term_manual_test/`

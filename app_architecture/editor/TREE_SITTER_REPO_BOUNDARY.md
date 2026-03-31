# Tree-sitter Repo Boundary

This document is the current authority for splitting Zide's Tree-sitter stack
between the app repo and the dedicated `zide-tree-sitter` repo.

## Goal

Move generic Tree-sitter grammar-pack ownership out of `zide` without moving
editor/runtime semantics out of `zide`.

The split must improve:

- reuse
- release discipline
- ownership clarity
- app build simplicity
- DRY boundaries between grammar tooling and editor runtime

It must not turn the new repo into a disguised editor-runtime repo.

## Repo Ownership

### `zide-tree-sitter` owns

- grammar-pack source-of-truth config
- grammar sync/fetch/build/release tooling
- pack manifests and packaging format
- shipped query assets that are generic Tree-sitter language/query inputs
- generated syntax mapping assets used by consumers
- documentation for pack production and release flow

In current `zide`, that means the future repo should absorb ownership around:

- `tools/editor/grammar/grammar_update.zig`
- `tools/editor/grammar/grammar_fetch.zig`
- `tools/editor/grammar_packs/**`
- `assets/queries/**`
- `assets/syntax/generated.lua`
- the generation path that produces syntax mapping assets from grammar metadata

### `zide` keeps

- editor runtime ownership
- tree-sitter loader/runtime policy
- query compilation and highlight execution
- syntax registry consumption logic
- editor-facing language resolution policy
- manual editor-specific highlight behavior and overrides
- any app/user/project override paths under the Zide config model

That means `zide` keeps ownership around:

- `src/editor/grammar_manager.zig`
- `src/editor/syntax.zig`
- `src/editor/syntax_runtime.zig`
- `src/editor/syntax_queries.zig`
- `src/editor/syntax_registry.zig`
- `src/editor/treesitter_api.zig`
- `src/editor/manual_highlights.zig`
- `assets/syntax/overrides.lua`

## Boundary Rules

### What must not move out of `zide`

- editor runtime execution
- visible highlight semantics
- app-owned override layering
- user config path policy
- project override path policy
- any editor-host behavior

### What must not stay in `zide`

- grammar-pack build orchestration
- grammar source fetch/update logic
- release packaging logic for parser/query packs
- generic shipped query corpora for supported languages
- generated syntax mapping data whose source of truth is the grammar-pack lane

## Asset Contract

`zide-tree-sitter` should publish a consumer-facing asset contract, not raw
implementation assumptions.

Initial contract:

- grammar packs under:
  - `<cache>/<lang>/<version>/...`
- per-pack query files:
  - `highlights`
  - `injections`
  - `locals`
  - `tags`
  - `textobjects`
  - `indents`
- manifest file per installed pack
- generated syntax mapping Lua file for extension/basename/injection lookup

`zide` should consume those assets through stable paths or imported artifacts,
not by depending on the internal script layout of the producer repo.

## Migration Order

### Phase 1: authority + scaffold

- define the boundary in docs
- create the dedicated repo
- scaffold its README, package metadata, and repo structure

### Phase 2: tooling extraction

- move grammar sync/fetch/update code
- move grammar pack scripts/config
- move query corpora and generated syntax mapping inputs
- keep `zide` temporarily consuming produced artifacts through a clear local path

### Phase 3: consumer contract

- make `zide` consume released or pinned `zide-tree-sitter` assets
- remove app-repo ownership of moved tooling/assets
- leave only consumer/runtime/editor policy in `zide`

## Definition Of Done

This split is done when:

- `zide-tree-sitter` can build/update grammar packs without the `zide` repo
- `zide` no longer owns grammar production tooling
- `zide` still owns runtime/editor semantics cleanly
- the produced asset contract is documented and stable
- fresh local setup for both repos is documented and repeatable

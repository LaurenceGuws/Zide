# Tree-sitter Repo Extraction

## Goal

Extract generic Tree-sitter grammar-pack ownership into the dedicated
`zide-tree-sitter` repo without moving editor/runtime semantics out of `zide`.

Authority:

- `app_architecture/editor/TREE_SITTER_REPO_BOUNDARY.md`

## Queue

- [x] `TS-REPO-01` Define repo boundary
  - ownership split documented
  - migration phases documented
  - done criteria documented

- [x] `TS-REPO-02` Create dedicated repo
  - GitHub repo exists
  - local repo exists under `~/personal`

- [x] `TS-REPO-03` Scaffold dedicated repo
  - README explains repo purpose and contract
  - package metadata exists
  - initial directory structure exists

- [x] `TS-REPO-04` Extract grammar tooling
  - move grammar update/fetch entrypoints
  - move grammar pack config/scripts
  - document local release/build flow

- [x] `TS-REPO-05` Extract shipped query/mapping assets
  - move generic query corpora
  - move syntax mapping generation ownership
  - keep `zide` on a stable consumer contract

- [x] `TS-REPO-06` Rewire `zide` consumption
  - remove moved-tool ownership from `zide`
  - document the new local setup
  - validate grammar install/update from the new repo

Current state:

- `zig build grammar-update` in `zide` proxies into sibling repo
  `../../zide-tree-sitter`
- produced query/mapping assets are installed into the user Tree-sitter asset
  root
- `zide` runtime resolves shared assets through an asset-root search path
- mirrored producer asset ownership in `zide/assets/` was removed

## Notes

- `assets/syntax/overrides.lua` stays in `zide`; it is app policy, not generic
  grammar-pack ownership.
- `src/editor/**` runtime files stay in `zide`; this extraction is not an
  editor-runtime extraction.

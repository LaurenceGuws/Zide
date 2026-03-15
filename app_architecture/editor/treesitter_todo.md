# Tree-sitter TODO

## Scope

Tree-sitter integration for syntax highlighting and semantic metadata.

## Constraints

- Baseline highlight correctness before advanced query features.
- Match Neovim query and capture semantics where practical.
- Keep immediate and cached render parity deterministic.
- Prefer incremental invalidation over full recompute.
- Cache queries and capture mappings per language.

## References

- `reference_repos/editors/neovim/runtime/doc/treesitter.txt`
- `reference_repos/editors/neovim/runtime/lua/vim/treesitter/{highlighter.lua,query.lua}`

## TODO

- [x] `TS-01` Query and capture pipeline
  - Runtime highlight queries load and compile per language.
  - Captures map to token kinds or highlight groups.
  - Leading `_` captures are ignored.

- [ ] `TS-02` Metadata and priorities
  - Priority metadata parsing is implemented.
  - Overlap splitting now produces non-overlapping segments by priority.
  - Capture taxonomy covers common alias captures and finer token kinds.
  - Runtime sampling logs unmapped captures.
  - Rendering respects conceal and url metadata.
  - Remaining work: finish Neovim-style metadata completeness and hardening.

- [ ] `TS-03` Predicates and directives
  - `eq?`, `any-of?`, `contains?`, and `match?` are implemented.
  - `set!` is implemented for priority and metadata.
  - Remaining work: `offset!`, `gsub!`, and `trim!`, plus any extension registry needs.

- [ ] `TS-04` Incremental invalidation
  - Tree edits and changed-range tracking exist.
  - Render cache invalidates by dirty line range instead of full clears.
  - Replay tests compare incremental output against full reparse, including multiline deletes and larger fixtures.
  - Undo/redo still forces full reparse for safety.

- [ ] `TS-05` Injected languages
  - Injection query cache and included-range highlighting are implemented.
  - Highlight priority is biased by injection depth.
  - Grammar packs now carry multiple query types and syntax registry supports injection language overrides.

- [ ] `TS-06` Render integration
  - Highlight spans translate into stable `HighlightToken` ordering for immediate and cached draw paths.
  - Ordering tie-break coverage exists, including conceal and url metadata behavior.
  - Immediate vs cached rendering parity tests exist for conceal and url handling.

- [x] `TS-07` Dynamic grammar loader
  - Parser `.so` loading, runtime query lookup, and bundled fallbacks are in place.
  - See `app_architecture/editor/treesitter_dynamic_roadmap.md`.

- [x] `TS-08` Grammar pack install tooling
  - Packs install from `tools/grammar_packs/dist` into `~/.config/zide/grammars`.
  - See `app_architecture/editor/treesitter_dynamic_roadmap.md`.


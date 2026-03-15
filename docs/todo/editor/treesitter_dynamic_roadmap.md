# Tree-sitter Dynamic Grammar Roadmap

Date: 2026-01-24

Goal: fully automate Tree-sitter grammar/query pulling, compiling, and runtime loading.

This roadmap is optimized for a new agent to pick up with minimal context. Each step is intended
to be small and testable, and to reuse the existing `tools/grammar_packs` workflow.

## Current State (2026-01-28)
- Grammar pack tooling builds multi-query packs (highlights/injections/locals/tags/textobjects/indents).
- Runtime loader + syntax registry are implemented (`src/editor/grammar_manager.zig`, `src/editor/syntax_registry.zig`).
- `zig build grammar-update` installs packs into `~/.config/zide/grammars`.
- Tree-sitter runtime is vendored in `vendor/tree-sitter/`; Zig language is built-in.

## Target Runtime Layout
Default cache dir (Linux):
```
~/.config/zide/grammars/<lang>/<version>/
  - <lang>_<version>_<os>_<arch>.so
  - <lang>_<version>_highlights.scm
  - <lang>_<version>_injections.scm
  - <lang>_<version>_locals.scm
  - <lang>_<version>_tags.scm
  - <lang>_<version>_textobjects.scm
  - <lang>_<version>_indents.scm
  - manifest.json
```

## Roadmap Steps

### Step 1: Loader + Registry (runtime) — done
Implemented loader + registry:
- resolve language by file extension
- find a cached grammar pack on disk
- `dlopen` the `.so` and resolve `tree_sitter_<lang>` symbol
- read query text for that language (highlights + additional query types)

Implemented files:
- `src/editor/grammar_manager.zig`
- `src/editor/syntax_registry.zig` (extension + basename → language map, defaults + overrides)
- `src/editor/syntax.zig` (`createHighlighterForLanguage`)
- `src/editor/editor.zig` (registry lookup)

Errors/logging:
- log missing packs clearly (language + expected path)
- avoid language-specific fallbacks; use the same lookup path for all languages

Defaults + overrides:
- Defaults baked at `assets/syntax/generated.lua` (generated from Neovim + parsers.lua)
- Manual overrides at `assets/syntax/overrides.lua` (extensions, basenames, globs)
- User overrides at `~/.config/zide/syntax.lua`
- Project overrides at `.zide/syntax.lua`

### Step 2: Pack Fetch/Install (local) — done
CLI command in place:
- `zig build grammar-update`
- runs `tools/grammar_packs/scripts/sync_from_nvim.sh`, `fetch_grammars.sh`, `build_all.sh`
- installs `tools/grammar_packs/dist/` into `~/.config/zide/grammars`
- writes per-pack `manifest.json` next to the `.so` + query files
- supports `--skip-git` and `--continue-on-error` for best-effort builds
- supports `--targets` / `--skip-targets` to limit os/arch combos
 - supports `--jobs <n>` to parallelize pack builds

Implemented files:
- `tools/grammar_update.zig`

### Step 3: Auto-sync Queries (optional)
Keep queries in sync with nvim-treesitter:
- add a helper to copy `tools/grammar_packs/work/queries/<lang>_<query>.scm`
  into `assets/queries/<lang>/<query>.scm`
- this keeps editor defaults aligned with upstream across all query types

Suggested files:
- `tools/grammar_packs/scripts/sync_queries_to_assets.sh` (new)
- `docs/todo/editor/treesitter_dynamic_roadmap.md` (update with exact command)

### Step 4: On-demand Download (optional)
If no local pack exists:
- fetch from a configured URL (GitHub releases or custom host)
- verify manifest checksum
- install and load without restarting

Suggested files:
- `src/editor/grammar_downloader.zig`
- config option in `assets/config/init.lua` for `grammar_base_url`

## Testing Plan (pending)
- Unit test: `GrammarManager.resolveLanguage("foo.java") == .java`
- Unit test: `GrammarManager.loadQuery("zig")` reads correct file
- Integration: open `.bashrc` and a `.java` file with installed packs

## Notes
- Keep memory bounded: cache `TSQuery` per language; reuse `TSLanguage` handles.
- Avoid global refactors until tests for new path exist.

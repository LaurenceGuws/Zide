# Tree-sitter Dynamic Grammar Roadmap

Date: 2026-01-24

Goal: fully automate Tree-sitter grammar/query pulling, compiling, and runtime loading.

This roadmap is optimized for a new agent to pick up with minimal context. Each step is intended
to be small and testable, and to reuse the existing `tools/grammar_packs` workflow.

## Current State
- Queries live under `assets/queries/<lang>/highlights.scm`.
- Only Zig highlights are guaranteed to work; other languages need parser loading.
- Grammar pack tooling already exists in `tools/grammar_packs/`.
- Tree-sitter runtime is vendored in `vendor/tree-sitter/`.

## Target Runtime Layout
Default cache dir (Linux):
```
~/.config/zide/grammars/<lang>/<version>/
  - <lang>_<version>_<os>_<arch>.so
  - <lang>_<version>_highlights.scm
  - manifest.json
```

## Roadmap Steps

### Step 1: Loader + Registry (runtime)
Add a lightweight runtime loader that can:
- resolve language by file extension
- find a cached grammar pack on disk
- `dlopen` the `.so` and resolve `tree_sitter_<lang>` symbol
- read `highlights.scm` text for that language

Suggested files:
- `src/editor/grammar_manager.zig` (new)
- `src/editor/syntax_registry.zig` (extension + basename → language map, defaults + overrides)
- `src/editor/syntax.zig` (add `createHighlighterForLanguage`)
- `src/editor/editor.zig` (replace hard-coded detection with registry lookup)

Errors/logging:
- log missing packs clearly (language + expected path)
- keep Zig fallback to avoid regression

Defaults + overrides:
- Defaults baked at `assets/syntax/generated.lua` (generated from Neovim + parsers.lua)
- Manual overrides at `assets/syntax/overrides.lua` (extensions, basenames, globs)
- User overrides at `~/.config/zide/syntax.lua`
- Project overrides at `.zide/syntax.lua`

### Step 2: Pack Fetch/Install (local)
Add a CLI command or tool to build + install packs locally:
- `zig build grammar-update`
- runs `tools/grammar_packs/scripts/sync_from_nvim.sh`, `fetch_grammars.sh`, `build_all.sh`
- installs `tools/grammar_packs/dist/` into `~/.config/zide/grammars`
- writes per-pack `manifest.json` next to the `.so` + `highlights.scm`
- supports `--skip-git` and `--continue-on-error` for best-effort builds
- supports `--targets` / `--skip-targets` to limit os/arch combos
 - supports `--jobs <n>` to parallelize pack builds

Suggested files:
- `src/tools/grammar_update.zig` (new)

### Step 3: Auto-sync Queries (optional)
Keep queries in sync with nvim-treesitter:
- add a helper to copy `tools/grammar_packs/work/queries/<lang>_highlights.scm`
  into `assets/queries/<lang>/highlights.scm`
- this keeps editor defaults aligned with upstream

Suggested files:
- `tools/grammar_packs/scripts/sync_queries_to_assets.sh` (new)
- `app_architecture/editor/treesitter_dynamic_roadmap.md` (update with exact command)

### Step 4: On-demand Download (optional)
If no local pack exists:
- fetch from a configured URL (GitHub releases or custom host)
- verify manifest checksum
- install and load without restarting

Suggested files:
- `src/editor/grammar_downloader.zig`
- config option in `assets/config/init.lua` for `grammar_base_url`

## Testing Plan
- Unit test: `GrammarManager.resolveLanguage("foo.java") == .java`
- Unit test: `GrammarManager.loadQuery("zig")` reads correct file
- Integration: open `.bashrc` and a `.java` file with installed packs

## Notes
- Keep memory bounded: cache `TSQuery` per language; reuse `TSLanguage` handles.
- Avoid global refactors until tests for new path exist.

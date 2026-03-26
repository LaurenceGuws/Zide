# Grammar Packs Tooling

This nested tooling project is responsible for building and publishing Tree-sitter grammar packs.
It is intentionally decoupled from the app and Zig runtime.

## What this does
- Syncs parser metadata + queries from `nvim-treesitter`.
- Clones grammar sources at the exact revisions used by nvim.
- Builds shared-library grammar packs for all languages.
- Packages `highlights.scm`, `injections.scm`, `locals.scm`, `tags.scm`, `textobjects.scm`, and `indents.scm` alongside each pack (when present).
- Publishes assets to GitHub Releases.

## Running

```
cd tools/grammar_packs
scripts/release.sh
```

Configuration lives in `config/grammar_packs.json`.

## Important
All fetched sources and built artifacts live in `work/` and `dist/` and are gitignored.

## App Integration
The app uses:
```
zig build grammar-update -- --skip-git --continue-on-error --jobs 8
```

Current local behavior:
- on Windows, `grammar-update` runs through PowerShell and Python 3
- on Windows, the default local target is `windows/x86_64`
- explicit `--targets` / `--skip-targets` still override that default

This writes:
- `tools/editor/grammar_packs/dist/manifest.json`
- `assets/syntax/generated.lua` (extension + basename → grammar map)

Manual edits belong in:
- `assets/syntax/overrides.lua`

## Mapping coverage helper
To check that every installed grammar pack maps to at least one extension/basename:
```
tools/editor/grammar_packs/scripts/check_syntax_coverage.py
```

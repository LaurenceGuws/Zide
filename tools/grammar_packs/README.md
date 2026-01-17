# Grammar Packs Tooling

This nested tooling project is responsible for building and publishing Tree-sitter grammar packs.
It is intentionally decoupled from the app and Zig runtime.

## What this does
- Syncs parser metadata + queries from `nvim-treesitter`.
- Clones grammar sources at the exact revisions used by nvim.
- Builds shared-library grammar packs for all languages.
- Packages `highlights.scm` alongside each pack.
- Publishes assets to GitHub Releases.

## Running

```
cd tools/grammar_packs
scripts/release.sh
```

Configuration lives in `config/grammar_packs.json`.

## Important
All fetched sources and built artifacts live in `work/` and `dist/` and are gitignored.


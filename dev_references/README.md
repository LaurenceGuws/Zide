# Dev References

Local development reference corpus used for architectural comparison, source
review, and implementation cross-checks.

This tree is:

- not a dependency root
- not vendored product source
- not shipped with releases
- not linked into builds

Its purpose is to keep local reference implementations and source material
available while designing and reviewing Zide.

Primary setup tool:

- `python3 ops/setup_reference_corpus.py`

Reference groups currently used by the corpus:

- `terminals/`
- `editors/`
- `zig_projects/`
- `databases/`
- `text/`
- `backends/`
- `fonts/`
- `rendering/`
- `sdlwiki_md/`

The clone inventory for the Git-backed groups lives in:

- `ops/reference_corpus_inventory.json`

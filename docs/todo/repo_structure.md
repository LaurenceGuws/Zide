# Repo Structure TODO

## Scope

Track non-product repo structure cleanup: test layout, tooling roots, and documentation placement.

## Tasks

- [x] `REPO-TEST-01` Define explicit repo-wide testing layout
  Canonical split is now documented between source-adjacent tests, `tests/`, and `fixtures/`, and `tests/` has the aggregate entrypoint.
- [x] `REPO-TOOLS-01` Collapse duplicated tooling roots
  `src/tools` was removed; grammar maintenance tools now live under `tools/`.
- [x] `REPO-DOC-01` Classify active versus historical documentation
  Doc lifecycle policy is now recorded in `docs/WORKFLOW.md` and summarized in `docs/INDEX.md`.
- [x] `REPO-TEST-02` Re-home scattered multi-module Zig test entrypoints
  Root-level app/editor/config/layout/widget entrypoints moved into `tests/`; terminal root entrypoints followed, with exceptions documented in `tests/README.md`.
- [x] `REPO-DOC-02` Remove or archive stale docs and stale completed todos
  Completed through staged cleanup of stale trackers and misplaced docs; the app-mode layering tracker was moved into review as historical rollout evidence.
- [x] `REPO-TOOLS-02` Define `tools/` domain layout and placement rules
  `tools/` is now explicitly documented as a parent directory for tool domains in `docs/reference/tools_layout.md`; loose root files were removed and repo references were updated to the new paths.
- [x] `REPO-TOOLS-03` Collapse fake tool micro-domains and stale wrappers
  Import checks now live under `tools/checks/`, the dead `scripts/dev/` compatibility wrappers were removed, the ignored-yet-source-looking `build/` root was deleted, root junk files were removed, and terminfo reference dumps moved from `assets/terminfo/` into `docs/reference/terminal_terminfo_reference/`.

Agent bootstrap prompt (use this verbatim)

You are an agent working on Zide, a Zig-based IDE.
You must follow AGENTS.md exactly — do not invent your own workflow.

First, do this in order:

Read AGENTS.md.

Read docs/AGENT_HANDOFF.md.

Read app_architecture/editor/treesitter_dynamic_roadmap.md.

Read app_architecture/editor/treesitter_todo.yaml.

Read src/editor/syntax.zig.

## Handover Notes (2026-01-25)
- Tree-sitter dynamic grammar support updated: syntax registry now loads `assets/syntax/generated.lua` + `assets/syntax/overrides.lua`.
- Added glob matching for syntax registry (supports `*` and `?`; uses full path when pattern contains `/`).
- Added manual mappings in `assets/syntax/overrides.lua`, including globs (Blade/Helm/Hocon/Glimmer/etc) and injection-only placeholders.
- Coverage tool added: `tools/grammar_packs/scripts/check_syntax_coverage.py` now reports extensions/basenames/globs/injections; dump via `--dump-lua-out`.
- Removed untracked `vendor/tree-sitter-bash/` and `vendor/tree-sitter-java/` per user request.
- Fixed highlight overflow panics in `src/ui/widgets/editor_widget_draw.zig` (clamp `token.start - line_start`).

Next session focus: full query plan.
- Packaging currently only copies `*_highlights.scm` into packs (`tools/grammar_packs/scripts/package_queries.sh`).
- Runtime only loads `highlights` per language (`src/editor/syntax.zig`).
- Need to extend packaging + runtime to support other query types (`injections.scm`, `locals.scm`, `tags.scm`, `textobjects.scm`, `indents.scm`) and injection handling (TS-05).

## Handover Notes (2026-01-25) — Layering Split
- AppShell façade enforced for widgets and main; widgets now take `*app_shell.Shell` and pass through `rendererPtr()` as needed.
- Added shared types under `src/types/` with `mod.zig` entrypoint: input/actions/layout/snapshots.
- Editor snapshot stub now fills `line_offsets`, cursor, and small text (`text_owned` indicates ownership). Tests cover ownership.
- Terminal snapshot adapter stub now maps rows/cols/cursor only (cells empty). Tests pin this behavior.
- `tools/app_import_check.zig` updated to treat `src/types` as shared and forbid types importing `src/ui`.
- `AppState.draw()` and `AppState.update()` now compute/use `WidgetLayout` for geometry.
- `InputBatch` lifecycle wired; `AppState.update()` receives batch; widgets read from batch for input.
- Terminal widget draw now consumes an `InputSnapshot` for hover state instead of polling renderer input.
- `buildInputBatch` moved into `src/input/input_builder.zig` to keep `main.zig` slimmer.
- Top-level UI draws (options/tab/side/status bars) now use `InputSnapshot` instead of querying input during draw.
- `InputBatch` now captures input state/events; editor/terminal widgets and `AppState.update()` read from batch instead of renderer.

Current state (do not question this):

Tree-sitter dynamic grammar roadmap exists (2026-01-24) under app_architecture/editor/treesitter_dynamic_roadmap.md.

Multi-language query loading is implemented in src/editor/syntax.zig (loads from .zide/, config path, and assets/).

Tree-sitter runtime is vendored in vendor/tree-sitter/.

vendor/tree-sitter-bash/ and vendor/tree-sitter-java/ are intentionally untracked to support dynamic pulling.

Your role:

Implement full Tree-sitter dynamic grammar support (TSUpdate-style workflow) quickly and end-to-end.

Large refactors are allowed to move fast.

Do not commit until I explicitly approve after running tests.

Hard rules (never violate):

Refactors are allowed and expected.

Avoid unrelated cleanups.

Behavior changes are allowed but must be backed by tests.

If you introduce new tooling, document it in the relevant app_architecture/editor docs.

Before coding:

State the scope and major files touched.

Move fast; no need to wait for confirmation unless blocked.

After coding:

List changed files.

List tests run (or note if not run).

Show git status -sb.

Stop and wait for approval.

Do not be verbose.

# App Mode Layering Validation Matrix

Status note, 2026-03-15:

- This file is retained as historical validation evidence for the completed
  mode-layer extraction lane.
- It is no longer a live gate bundle for current architecture work.
- Use `app_architecture/APP_LAYERING.md` for present-tense boundary rules.

This document is the compatibility authority for the app mode layering extraction.

## Baseline compatibility goals

- Runtime mode parsing must remain compatible:
  - `zig build run`
  - `zig build run -- --mode terminal`
  - `zig build run -- --mode editor`
  - `zig build run -- --mode ide`
- Focused build entry steps must remain functional:
  - `zig build run-terminal`
  - `zig build run-editor`
  - `zig build run-ide`

## Required gates after each extraction checkpoint

1. `zig build test`
2. `zig build check-terminal-imports`
3. `zig build check-app-imports`
4. `zig build check-input-imports`
5. `zig build check-editor-imports`
6. `zig build mode-gates`

For local extraction loops, you may run `zig build mode-gates-fast` between commits and reserve `zig build mode-gates` for checkpoint validation.
Both bundles include `mode-size-check`.

Helper wrapper:

- `tools/mode_gates.sh fast`
- `tools/mode_gates.sh full`
- `tools/mode_gates.sh manual-smokes`

Binary size tracking:

- `zig build mode-size-report`
- `zig build mode-size-check`
- or `tools/report_mode_binary_sizes.sh` after `zig build`
<<<<<<<< HEAD:app_architecture/review/archive/app_mode_layering_validation.md
- Baseline snapshot file: `app_architecture/review/archive/mode_binary_size_baseline.md`
========
- Baseline snapshot file: `docs/review/archive/mode_binary_size_baseline.md`
>>>>>>>> main:docs/review/archive/app_mode_layering_validation.md

## Manual interactive compatibility smokes (run when explicitly requested)

1. `zig build mode-smokes-manual`
2. `zig build run-terminal`
3. `zig build run-editor`
4. `zig build run-ide`

## Layer-slice validation policy

- Do not progress to the next slice unless all required gates pass.
- Any extraction-only refactor that changes behavior is invalid; split behavior changes into separate scoped work.
- If a gate fails:
  - Fix in the same slice, or
  - Revert the slice and re-land with smaller changes.

## Checkpoint recording template

Use this for each checkpoint commit:

- `commit`: `<hash>`
- `slice`: `<MODE-xx-yy>`
- `intent`: `<what was extracted>`
- `gates_run`: `<list>`
- `result`: `pass|fail`
- `notes`: `<compat observations>`

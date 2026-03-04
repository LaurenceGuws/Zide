# App Mode Layering Validation Matrix

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
2. `zig build check-app-imports`
3. `zig build check-input-imports`
4. `zig build check-editor-imports`
5. `zig build run`
6. `zig build run -- --mode terminal`
7. `zig build run -- --mode editor`
8. `zig build run -- --mode ide`
9. `zig build run-terminal`
10. `zig build run-editor`
11. `zig build run-ide`
12. `zig build test-terminal-replay -- --all`

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


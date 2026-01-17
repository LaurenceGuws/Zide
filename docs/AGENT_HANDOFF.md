# Agent Handoff (Zide)

Date: 2026-01-16

## Summary of this session

- Added scrollback UI controls (scrollbar + drag) and fixed scroll region resize so scrollback captures lines.
- Added a simple app logger to emit terminal scrollback debug logs to `zide.log` (and stderr).

## Key changes

### PTY abstraction
- `src/terminal/pty.zig` selects platform PTY implementation.
- `src/terminal/pty_unix.zig` uses `openpty` + fork/exec; non‑blocking master; macOS login shell path.
- `src/terminal/pty_windows.zig` ConPTY stub matches common API.
- `src/terminal/pty_stub.zig` fallback for unsupported OS.
- `TerminalSession` now owns a PTY and pipes input/output through it.

### UTF‑8 + stream + CSI
- Added `src/terminal/utf8.zig` and `src/terminal/stream.zig` to decode bytes into codepoints/control bytes.
- Added `src/terminal/csi.zig` and CSI dispatch in `src/terminal/terminal.zig`.
- Implemented ESC + CSI parsing to prevent raw escape text in output.

### CSI operations (current)
- Cursor: `A/B/C/D` (move), `H/f` (CUP), `G` (CHA), `d` (VPA), `E/F` (CNL/CPL)
- Erase: `J` (ED), `K` (EL)
- Insert/Delete: `@` (ICH), `P` (DCH), `L` (IL), `M` (DL)
- Scroll: `S` (SU), `T` (SD), `r` (DECSTBM)
- Reset: `ESC c`

### SGR
- Implemented `0`, `1`, `22`, `7`, `27`, `39`, `49`
- 16‑color palette: `30–37`, `40–47`, `90–97`, `100–107`
- 256‑color + truecolor: `38/48;5;<idx>` and `38/48;2;<r>;<g>;<b>`

### Stability fixes
- Cursor clamping on resize.
- Bounds checks in erase/line handling and write path.
- Newline now resets column.

## Current terminal state

- Terminal output renders from a real PTY with minimal VT parsing.
- Colors (16/256/truecolor) and basic cursor/erase operations work.
- Scrollback captures lines when the full screen scrolls; UI shows a scrollbar and supports drag/wheel.
- Full SGR coverage and advanced CSI not yet supported.
- Dirty‑row tracking not implemented.

## Design docs

- `docs/terminal/DESIGN.md` contains current decisions and progress.
- Roadmap lives at `docs/terminal/terminal_widget_todo.yaml`.

## Next suggested steps (in order)

1) Implement grid dirty‑row tracking to reduce redraw work.
2) Add scrollback viewport polish (selection/copy, scrollback indicators).
3) Expand CSI for modes and attributes, then refine performance.

## Workflow (Docs + Research)

This workflow should be followed when advancing terminal layers:

1) Identify the next layer or task from `docs/terminal/terminal_widget_todo.yaml`.
2) Read the relevant references listed in the YAML for that layer.
3) Summarize findings in `docs/terminal/DESIGN.md` under the layer section:
   - What the reference implementations do.
   - The decision we choose and why.
   - Any tradeoffs or caveats.
4) Implement the smallest coherent slice that matches the decision.
5) Update `docs/terminal/DESIGN.md` progress for that layer.
6) Run `zig build` (and `zig build run` if behavior changed) to validate.
7) Update `docs/AGENT_HANDOFF.md` with:
   - What changed.
   - Current state.
   - Exact next steps.

## Files to review first

- `src/terminal/terminal.zig`
- `src/terminal/pty_unix.zig`
- `src/terminal/csi.zig`
- `docs/terminal/DESIGN.md`

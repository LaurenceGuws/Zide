# Agent Handoff (Zide)

Date: 2026-01-17

## Quick start for next agent

- Repo: `/home/home/personal/zide`
- Recent commits: `8e735fd` (keyboard input/kitty protocol), `b484b6b` (OSC 52/8), `e932292` (alt screen + cursor save).
- Current focus: terminal input correctness + mouse reporting + OSC 8 rendering.

Suggested next steps:
1) Add mouse reporting (X10/VT200/SGR).
2) Decide how to render OSC 8 hyperlinks in cell attrs/renderer.
3) Add minimal manual tests for CSI‑u keyboard behavior.

## Summary of this session

- Cached terminal rendering into a render texture and only re-rendered dirty rows into it.
- Cursor is now drawn as a per-frame overlay so cursor moves don't require texture updates.
- Kept dirty tracking ownership in the terminal widget (clear after draw).
- Added a scrollback indicator overlay when the viewport is scrolled.
- Added glyph atlas compaction and a reusable upload buffer to reduce per-glyph allocations.
- Added alternate screen switching and per-screen cursor save/restore, including ESC 7/8 and CSI s/u.
- OSC clipboard (52) now decodes into a pending clipboard buffer; OSC 8 hyperlinks are parsed and tracked.
- CSI u / kitty keyboard protocol now supported with per-screen flag stacks and modifier-aware encoding.
- Legacy modifier handling now covers letters, numbers, and punctuation; macOS Command is reserved for app shortcuts.
- Added a Lua config POC for logging and per-component logger filtering.
- Added `assets/config/init.lua` as the defaults reference and documented log config and raylib log levels.
- Added frame pacing metrics (frame/draw/input latency) for tuning and profiling.
- Logging now supports separate file vs console filters; call sites don’t decide destinations.
- Refined ED (erase display) damage to use per-row column bounds for the cursor row.
- Added basic terminal selection with translucent highlight and Ctrl+Shift+C clipboard copy.
- Selection auto-scrolls when dragging beyond the terminal viewport.

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

### Dirty tracking
- Added `dirty_rows` to the grid with `markDirtyRange` and `markDirtyAll`.
- Updated write/erase/insert/delete/scroll paths to mark partial damage ranges instead of full.
- Terminal widget now uses dirty rows to update a render texture instead of redrawing the full grid each frame.
### Glyph atlas
- `TerminalFont` now reuses a staging buffer for texture uploads and compacts the atlas when full.
### Logging config (POC)
- Logging is now component-scoped (`app_logger.logger("name")`) and supports config-driven filtering.
- Lua config loader reads `assets/config/init.lua`, then user config, then `.zide.lua` for overrides.
- Log filters can be set per destination (`log.file` and `log.console`).
### Metrics
- Added lightweight EMA metrics for frame time, draw time, and input-to-draw latency.

## Current terminal state

- Terminal output renders from a real PTY with minimal VT parsing.
- Colors (16/256/truecolor) and basic cursor/erase operations work.
- Scrollback captures lines when the full screen scrolls; UI shows a scrollbar and supports drag/wheel.
- Full SGR coverage and advanced CSI not yet supported.
- Dirty-row tracking is implemented; renderer caches the terminal in a texture and only updates dirty rows.
- Glyph atlas compacts instead of failing when full.
- Frame pacing metrics are collected in `terminal/metrics.zig`.
- Basic mouse selection highlights and Ctrl+Shift+C copy are supported (selection clears on resize and on input that resumes live view).
- Selection auto-scrolls when dragging beyond the viewport; scrollback indicator shows when scrolled.
- Alternate screen buffer supported via DECSET ?47/?1047/?1049; alt screen disables scrollback.
- Save/restore cursor supported via ESC 7/8, CSI s/u, and DECSET ?1048.
- OSC 52 clipboard payloads are decoded and forwarded to the UI clipboard; OSC 8 hyperlinks stored as state (no rendering yet).
- Keyboard protocol stacks (CSI >/< /=/? u) supported per screen; modifier-aware key encoding for CSI u sequences.
- Clipboard paste supports Ctrl+Shift+V and middle-click.
- Bracketed paste mode (?2004) is honored when enabled by the shell.
- Basic OSC parsing now consumes OSC 0/2 sequences to avoid printing prompt metadata.

## Terminal planning notes

- We started applying the performance strategy by cutting hover-driven redraws over the terminal (no hover UX), reducing CPU while keeping responsiveness elsewhere.
- Next performance steps remain refinement of partial redraw (column damage) and selection/copy polish.

## Design docs

- `docs/terminal/DESIGN.md` contains current decisions and progress.
- Roadmap lives at `docs/terminal/terminal_widget_todo.yaml`.

## Next suggested steps (in order)

1) Add mouse reporting (X10/VT200/SGR) to support TUI mouse interaction.
2) Decide how to surface OSC 8 hyperlink state in the renderer/cell attrs.

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

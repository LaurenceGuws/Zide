# Agent Handoff (Zide)

Date: 2026-01-20

## Quick start for next agent

- Repo: `/home/home/personal/zide`
- Current focus: terminal protocol correctness + UI parity with Ghostty (Codex input bg issue).
- Key docs:
  - `docs/terminal/DESIGN.md`
  - `docs/terminal/terminal_widget_todo.yaml`
  - `docs/terminal/protocol_todo.yaml`

Suggested next steps:
1) Read `docs/terminal/protocol_todo.yaml` and follow the reference repo links listed in each task before coding.
2) Check off tasks in `docs/terminal/protocol_todo.yaml` as they are completed (keep notes concise).
3) Reproduce Codex input background issue (compare against Ghostty).
4) Use `terminal.osc` + `terminal.sgr` + `terminal.io` logs to confirm which sequences are sent.
5) Close remaining gaps in `docs/terminal/protocol_todo.yaml` in priority order.

## Summary of this session

- OSC: added palette (OSC 4/104), dynamic colors (OSC 10–19 + 110–119), and OSC 52 clipboard read replies.
- OSC 7 CWD parsing implemented (file:// URI, host validation, percent‑decode, path normalization).
- SGR: underline on/off (4/24), underline color (58/59), and RGBA (38/48/58:6) support.
- Added OSC reply logging + raw CSI logging for debugging.
- Docs updated: `docs/terminal/protocol_todo.yaml` task statuses kept in sync.

## Current issues

- Codex input field background still does not render. Codex sends `OSC 10;?` and `OSC 11;?` queries only; no `48` background SGR observed. Raw CSI logging shows only `CSI 0/39/49 m`.
- Lazygit arrow navigation fixed via DECCKM, but re-validate after further input changes.

## Key changes (recent)

- `src/terminal/core/terminal.zig`
  - OSC palette + dynamic colors
  - OSC 7 CWD parsing
  - OSC 52 clipboard read replies
  - SGR underline + underline color + RGBA
  - OSC/CSI debug logging
- `src/terminal/parser/csi.zig`
  - max CSI params = 16
  - `:` treated as a separator in SGR
- `docs/terminal/protocol_todo.yaml`
  - Checklist updated for completed tasks

## Files to review first

- `src/terminal/core/terminal.zig`
- `src/terminal/parser/parser.zig`
- `src/terminal/parser/csi.zig`
- `docs/terminal/DESIGN.md`
- `docs/terminal/protocol_todo.yaml`

# Agent Handoff (Zide)

Date: 2026-01-19

## Quick start for next agent

- Repo: `/home/home/personal/zide`
- Current focus: terminal protocol correctness + UI parity with Ghostty (Codex input bg issue).
- Key docs:
  - `docs/terminal/DESIGN.md`
  - `docs/terminal/terminal_widget_todo.yaml`
  - `docs/terminal/protocol_todo.yaml`

Suggested next steps:
1) Reproduce Codex input background issue (compare against Ghostty).
2) Use `terminal.osc` + `terminal.sgr` logs to confirm which sequences are sent.
3) Close gaps in `docs/terminal/protocol_todo.yaml` in priority order.

## Summary of this session

- Implemented DSR/DA replies needed by Codex (`CSI 5/6 n` + `CSI c`).
- Added DECCKM app cursor keys and SS3 arrow output.
- Increased CSI parameter capacity to 16 and accept `:` in SGR sequences.
- Added OSC default color set/query handling (OSC 10/11), plus query replies for 12/19.
- Added debug logging tags for terminal protocol tracing (`terminal.csi`, `terminal.sgr`, `terminal.osc`, `terminal.io`, `terminal.alt`).
- Added protocol gap checklist in `docs/terminal/protocol_todo.yaml`.

## Current issues

- Codex input field background does not render. Codex sends `OSC 10;?` and `OSC 11;?` queries only; no `OSC 10/11` set observed. Likely missing:
  - Dynamic color reset handling (OSC 110–119)
  - Palette ops (OSC 4/104) and/or dynamic color updates applied to existing cells
  - Proper OSC query reply semantics/terminator tracking
- Lazygit arrow navigation fixed via DECCKM, but re-validate after further input changes.

## Key changes (recent)

- `src/terminal/core/terminal.zig`
  - DSR/DA replies
  - DECCKM app cursor keys
  - OSC 10/11 set + query
  - OSC 12/19 query replies
  - OSC debug logging
- `src/terminal/parser/csi.zig`
  - max CSI params = 16
  - `:` treated as a separator in SGR
- `docs/terminal/protocol_todo.yaml`
  - Detailed protocol gap list with references

## Files to review first

- `src/terminal/core/terminal.zig`
- `src/terminal/parser/parser.zig`
- `src/terminal/parser/csi.zig`
- `docs/terminal/DESIGN.md`
- `docs/terminal/protocol_todo.yaml`

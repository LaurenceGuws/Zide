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
5) Close remaining gaps in `docs/terminal/protocol_todo.yaml` in priority order (next: IMG-01 kitty graphics follow-ups or TERM-01 terminfo sweep).

## Summary of this session

- Kitty graphics: expanded control parsing, chunking with S/O, zlib inflate (o=z), storage limits + eviction, scroll-anchored placements, and z-layer rendering order.
- Kitty graphics: delete actions implemented (d=a/A/i/I/n/N/c/C/p/P/z/Z/r/R/x/X/y/Y), placement ids tracked, and quiet replies (q=0/1) with basic OK/ERR responses; query action (a=q) acknowledged.
- Kitty graphics: parented placements supported (P/Q/H/V) with offsets; virtual placements stored but not rendered.

## Current issues

- Codex input field background still does not render. Codex sends `OSC 10;?` and `OSC 11;?` queries only; no `48` background SGR observed. Raw CSI logging shows only `CSI 0/39/49 m`.
- Lazygit arrow navigation fixed via DECCKM, but re-validate after further input changes.
- NumLock state is not tracked; keypad always treated as keypad unless app keypad mode is disabled.
- XTGETTCAP support is minimal (TN/Co/RGB only).
- Kitty graphics: no proper error replies for specific failure cases; responses are basic OK/ERR and do not match kitty error codes.
- Kitty graphics: delete semantics are approximate (e.g., 'n/N' treated like 'i/I'); no placement queries, no animation support.
- Kitty graphics: virtual placements are ignored in rendering; parent/child cycle/validation is minimal vs kitty.

## Key changes (recent)

- `src/terminal/core/terminal.zig`
  - Kitty graphics: parsing/validation, chunking + zlib inflate, storage limits, delete actions, parented placements, basic replies
- `src/terminal/parser/parser.zig`
  - DCS parser added (minimal)
- `src/ui/widgets/terminal_widget.zig`
  - Kitty z-layer ordering + skip virtual placements
- `src/terminal/parser/csi.zig`
  - max CSI params = 16
  - `:` treated as a separator in SGR
- `docs/terminal/protocol_todo.yaml`
  - Checklist updated for completed tasks
- `scripts/manual.sh`
  - XTGETTCAP query helper

## Files to review first

- `src/terminal/core/terminal.zig`
- `src/terminal/parser/parser.zig`
- `src/terminal/parser/csi.zig`
- `docs/terminal/DESIGN.md`
- `docs/terminal/protocol_todo.yaml`

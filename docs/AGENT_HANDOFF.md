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

- Kitty graphics: PNG decoded to RGBA in core so dimensions are known for cursor advance; scrollback overlays now move with viewport.
- Kitty graphics: query (`a=q`) validates payloads and returns `ENODATA`/`EBADPNG`/`EINVAL` as appropriate; `ENOENT` for missing images; cycle + depth checks (`ECYCLE`/`ETOODEEP`) for parented placements.
- Kitty graphics: per-screen storage (primary vs alt) so alt apps like yazi can render without leaking to scrollback; alt entry/exit clears its own kitty state.
- Terminfo: added `assets/terminfo/xterm-kitty.info` and set TERM to xterm-kitty with fallback to xterm-256color when missing.

## Current issues

- Codex input field background still does not render. Codex sends `OSC 10;?` and `OSC 11;?` queries only; no `48` background SGR observed. Raw CSI logging shows only `CSI 0/39/49 m`.
- Lazygit arrow navigation fixed via DECCKM, but re-validate after further input changes.
- NumLock state is not tracked; keypad always treated as keypad unless app keypad mode is disabled.
- XTGETTCAP support is minimal (TN/Co/RGB only).
- Kitty graphics: delete semantics are approximate (e.g., 'n/N' treated like 'i/I'); no placement queries, no animation support.
- Kitty graphics: virtual placements (U=1) are stored but not rendered; no unicode placeholder handling.
- Kitty graphics: file/temp/shm media support is basic; error mapping for file/shm failures is still coarse.

## Key changes (recent)

- `src/terminal/core/terminal.zig`
  - Kitty graphics: parsing/validation, chunking + zlib inflate, storage limits, delete actions, parented placements, query validation, per-screen storage, PNG decode, alt screen handling
- `src/terminal/parser/parser.zig`
  - DCS parser added (minimal)
- `src/ui/widgets/terminal_widget.zig`
  - Kitty z-layer ordering + viewport-aware overlay placement
- `src/terminal/io/pty_unix.zig`
  - TERM set to xterm-kitty with fallback to xterm-256color
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

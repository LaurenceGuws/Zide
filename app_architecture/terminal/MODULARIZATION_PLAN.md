# Terminal Modularization Plan

Date: 2026-01-24

Goal: split the terminal implementation into clear layers with a stable API surface, while preserving behavior and minimizing regressions.

## Scope
- Terminal core + protocol handling + screen model + snapshot API.
- Keep UI rendering in `src/ui/widgets/terminal_widget.zig` and renderer/font code in `src/ui/`.
- Preserve all current features (OSC/CSI/DCS, kitty graphics, scrollback, selection, input).

## Non-goals (for this phase)
- Major behavior changes.
- New protocol features or large refactors of renderer/font code.

## Constraints
- Test-first migration (add terminal tests before moving code).
- No feature removal; changes must be traceable to current behavior.
- Keep hot paths allocation-free and branch-light (per `DESIGN.md`).

## Target Layer Split (mapping to `app_architecture/terminal/DESIGN.md`)
1) UI Integration: `src/ui/widgets/terminal_widget.zig` (renderer + input mapping).
2) Snapshot API: `src/terminal/core/snapshot.zig` (immutable per-frame data).
3) PTY + IO: `src/terminal/io/*.zig` + optional `src/terminal/core/pty_driver.zig`.
4) VT Parser: `src/terminal/parser/*.zig` (byte stream to actions).
5) Screen Model: `src/terminal/model/*` (grid + scrollback + selection).
6) Protocol Handlers:
   - `src/terminal/protocol/csi.zig`
   - `src/terminal/protocol/osc.zig`
   - `src/terminal/protocol/dcs_apc.zig`
7) Kitty Graphics: `src/terminal/kitty/graphics.zig`
8) Input Encoding: `src/terminal/input/encoder.zig` (CSI u/kitty mapping)

## Stable API Surface (public)
`TerminalSession` should expose only:
- lifecycle: `init`, `deinit`, `start`, `poll`, `resize`, `setCellSize`
- input: `sendKey`, `sendKeypad`, `sendChar`, `sendText`, `reportMouseEvent`
- state: `snapshot`, `selectionState`, `clearSelection`
- queries: `currentCwd`, `takeOscClipboard`, `hyperlinkUri`, `isAlive`
- locks: `lock`, `unlock`

`TerminalSnapshot` contract:
- Borrowed slices, valid until next snapshot.
- No per-frame allocations during render.

## Contract-First API Spec
Add `app_architecture/terminal/TERMINAL_API.md` with a per-API contract table:
- ownership/lifetime of returned data
- allocation behavior
- thread/concurrency expectations
- invariants (cursor bounds, scrollback rules, alt-screen rules)
- error semantics (error sets, when failures can occur)
- tests that cover the contract

## Feature Inventory (code-derived)
Before refactor, generate a feature list directly from current code:
- OSC/CSI/DCS/APC coverage from handler switch statements
- key encoding + modifier rules from input encoder
- kitty graphics actions supported (store/place/delete/clear)
Capture this list in `app_architecture/terminal/FEATURE_INVENTORY.md`.

## Test-First Safety Net
Approved fixture list (authoritative; 16 total):
- VT replay fixtures (15):
  - cursor_moves_basic
  - erase_line_and_display
  - insert_delete_chars
  - scroll_region_basic
  - sgr_16_256_truecolor
  - sgr_reverse_and_reset
  - alt_screen_enter_exit
  - scrollback_push
  - osc_title_bel
  - osc_cwd_st
  - osc_8_hyperlink_bel
  - osc_52_clipboard_bel
  - utf8_wide_and_combining
  - selection_basic_flow (harness API hooks)
  - kitty_store_place_delete
- Encoder unit test (1):
  - csi_u_encoder_bytes

Separation is enforced:
- VT replay tests
- harness API tests (selection)
- encoder unit tests (CSI-u)

## Baseline Fixture Capture (golden tests)
Add a replay harness to:
- feed a `.vt` fixture
- emit a deterministic snapshot string (grid + cursor + attrs + scrollback summary)
- store baseline goldens from current implementation before moving code

Approved replay harness outline is the design source of truth:
- snapshot string must encode title/cwd/clipboard/hyperlink tagging state
- grid encoding must be deterministic (blank cells, attrs encoding, wide-char handling, scrollback view)

## Layer Enforcement
Define explicit layer rules (e.g., UI → core → model/parser/io).
Add a lightweight build-time check to block forbidden imports or deep coupling.
Layer check implemented via `zig build check-terminal-imports` (see `tools/terminal_import_check.zig`).
Document allowed import directions before any refactor work begins.

## Migration Steps (incremental, each builds + tests)
1) Implement replay harness (per approved outline; no refactor).
2) Capture baseline golden fixtures from current implementation.
3) Generate `FEATURE_INVENTORY.md` derived from code.
4) Finalize `TERMINAL_API.md` with contracts tied to fixtures/tests.
5) Extract snapshot types into `core/snapshot.zig` (pure move + re-export).
6) Extract protocol handlers (CSI/OSC/DCS/APC) into `terminal/protocol`.
7) Extract kitty graphics into `terminal/kitty/graphics.zig`.
8) Move screen ops into `model/screen_ops.zig` or expand `model/screen.zig`.
9) Move selection state/extraction into `model/selection.zig`.
10) Reduce `terminal/core/terminal.zig` to a thin orchestrator.

Progress:
- Completed step 5 (snapshot types + encoding extracted into `terminal/core/snapshot.zig`).
- Completed step 6 (protocol handlers extracted into `terminal/protocol`).
- Completed step 7 (kitty graphics extracted into `terminal/kitty/graphics.zig`).
- Completed step 8 (screen ops expanded in `terminal/model/screen.zig`).
- Completed step 9 (selection types/state in `terminal/model/selection.zig`).
- In progress step 10 (cursor/key-mode/default-cell/dirty/grid helpers moved into `terminal/model/screen/` with `screen.zig` facade, plus damage/query helpers, markDirty delegations, basic cursor movement ops, CSI cursor helpers, newline action, and write helpers).

## Regression Checklist (keep in sync)
- OSC coverage: 0/2/7/8/10/11/12/19/52 + XTGETTCAP.
- SGR: 16/256/truecolor + bold/reverse.
- CSI: cursor, erase, insert/delete, scroll region, DA/DSR.
- Alt screen state + scrollback rules.
- Kitty graphics (payload decode as currently implemented, placements, delete actions).
- Key input: CSI u/kitty flags + modifier handling.

## Refactor Rules (hard)
- Extraction-only until tests and goldens pass.
- No behavior changes during file moves; any semantic change requires a separate, test-driven step.
- Keep diffs small and reviewable; do not move multiple subsystems at once.
- Extraction-only constraint: no renaming of public symbols, no logic changes, no behavior-motivated simplifications, no "while we're here" cleanups.

## Decisions Locked
- Approved fixture list (16 total) is authoritative.
- Replay harness snapshot format is fixed by the approved outline.
- Tests + goldens gate all refactors.
- Extraction-only means no renames, no cleanup, no behavior changes.

# Terminal Replay Harness Spec

Date: 2026-01-24

Purpose: define the deterministic replay harness and snapshot encoding used for baseline goldens.

## Scope
- VT replay fixtures (authoritative list in `MODULARIZATION_PLAN.md`)
- Harness API fixtures (selection)
- Encoder unit tests (CSI-u encoder bytes)

## Harness Inputs + Fixture Types

1) VT replay fixtures
- Input: raw VT byte sequences.
- Output: snapshot string.

2) Harness API fixtures (selection)
- Input: VT feed + explicit harness calls for selection start/update/finish.
- Output: snapshot string includes selection state.

3) Encoder unit tests
- Input: direct call to encoder with key/modifiers.
- Output: byte sequence string (not a TerminalSnapshot).

Each fixture includes:
- terminal size (rows/cols)
- start cursor position (row/col)
- line ending mode (`\n` only unless specified)
- input string (human-readable)
- assertion categories (grid, cursor, attrs, scrollback, alt-screen, hyperlinks, clipboard, kitty images)
- fixture type: vt | harness_api | encoder

## Replay Pipeline

VT replay flow:
1) Create session (rows/cols, cell size if needed).
2) Feed bytes into parser/handler as current code does (no PTY).
3) Optionally apply harness API calls (selection).
4) Call `snapshot()` once after all input.
5) Convert snapshot + auxiliary state into deterministic string.

Encoder test flow:
1) Call encoder with key/mod inputs.
2) Emit encoded bytes string.

## Deterministic Snapshot String Format

Header:
```
TERM_SNAPSHOT v1
size: 6x12
cursor: r=<row> c=<col> visible=<0|1> style=<style>
alt: <0|1>
scrollback: count=<N> view_offset=<offset>
title: "<title_or_empty>"
cwd: "<cwd_or_empty>"
clipboard: "<base64_or_empty>"
```

Grid encoding (viewport):
- Blank cell: use `·` (or another fixed ASCII-safe marker, but keep it consistent).
- Normal cell: UTF-8 char as stored.
- Wide char: two cells:
  - first cell contains glyph
  - second cell contains WIDE_FOLLOW marker (fixed, e.g. `→` or `#`)
- Combining mark: represent as base+combining if stored in same cell; otherwise use a fixed combining marker (deterministic rule).

Attributes encoding (deterministic):
- Prefer per-run summary:
```
attrs:
row1: (cols 1-3) fg=default bg=default bold=0 rev=0 ul=0 link=0
row1: (cols 4-5) fg=red bg=default bold=0 rev=1 ul=0 link=2
```
- If per-run is too complex initially, emit per-cell tuples with stable ordering.

Hyperlinks:
- Include link table:
```
links:
id=1 uri="https://example.com"
```
- Link IDs referenced by attrs per cell or per run.

Scrollback:
- Include last N lines, deterministic order.
```
scrollback:
line0: <encoded row>
line1: <encoded row>
```
- Header must include `count` and `view_offset`.

Kitty graphics:
- Include summary (no raw bytes):
```
kitty:
images=<count> placements=<count>
image ids: [1,2,...]
placement ids: [(img=1, id=3), ...]
```

## State Assertions (explicit capture)
Snapshot must include:
- title (if stored)
- cwd (if stored)
- pending clipboard (if stored)
- hyperlink tagging (link_id table + ranges)

If not accessible via public API, use test-only debug access:
- read-only accessors under test build, or
- a `debugSnapshot()` that includes these fields.

## Determinism Rules
- Snapshot after all input is consumed.
- Fixed terminal size + initial cursor per fixture.
- Normalize line endings per fixture.
- No timers/randomness.

Notes:
- Scrollback push ordering aligned with Ghostty/Kitty; `scrollback_push` golden updated.

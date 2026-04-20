# `CZH-S65` Tickets — Enforcement Signal Compression with Verifiability Retention

Sprint: `CZH-S65`  
Authority parent: accepted `CZH-B69` enforcement surface compaction  
Super-gate: `CZH-GATE-124`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit.
- Behavior freeze: signal compression only.
- No host ABI/C export changes in this sprint.
- Keep changes single-path; no compatibility/fallback branches.
- Source comments stay present-tense architecture only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.

## Ticket list

### `CZH-1165` Signal audit + compression map
- Audit enforcement signal fields/comments/docs/tests for compression candidates that preserve verifiability.

### `CZH-1166` Authority tightening (`doc-only`)
- Tighten `TERMINAL_SURFACE_CONTRACT.md` signal-compression policy and retention criteria.

### `CZH-1167` Refresh signal compression
- Compress refresh enforcement signal expression while preserving bound verifiability.

### `CZH-1168` Reuse signal compression
- Compress reuse enforcement signal expression while preserving bound verifiability.

### `CZH-1169` Direct signal compression
- Compress direct enforcement signal expression while preserving bound verifiability.

### `CZH-1170` Shared signal compression
- Compress shared enforcement signal expression while preserving cross-path lock clarity.

### `CZH-1171` Regression/integration verifiability retention verification
- Verify all compressed signals remain explicitly verifiable by compile/test locks.

### `CZH-1172` Hygiene sweep + validation packet + gate handoff
- Probe/debug residue sweep on touched files.
- Record full validation ladder in `implementation.md`.
- Add `CZH_S65_CHECKPOINT.md` and move board to `review_gate` at `CZH-GATE-124`.

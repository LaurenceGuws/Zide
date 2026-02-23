# Terminal Protocol Accuracy Progress

Date started: 2026-02-23
Source review: terminal protocol/code audit against `reference_repos/terminals/*` quality seeds
Owner: agent

## Purpose

Track protocol support/accuracy findings from the review as discrete, traceable fixes.

Rules for this document:
- Each finding has a stable ID (`PA-01`, `PA-02`, ...).
- Status changes must include date + evidence (files/tests).
- "Done" means code change landed and a verification step was run.
- Large scope parity gaps can be split into sub-items; do not silently close them.

## Status Legend

- `todo`: not started
- `in_progress`: actively being fixed
- `done`: fixed and verified
- `deferred`: intentionally postponed with reason
- `partial`: mitigated but not full parity

## Findings Tracker

| ID | Severity | Status | Summary | Acceptance Criteria |
|---|---|---|---|---|
| PA-01 | High | done | Unicode width/cursor accounting incorrect in core write path | Wide codepoints occupy correct cell width; combining marks attach correctly; replay fixtures pass |
| PA-02 | High | partial | Replay `assertions` metadata is ignored; fixture intent not enforced | Harness consumes `assertions` (or field removed/replaced) and coverage intent is explicit/tested |
| PA-03 | Medium-High | done | Kitty invalid controls can be dropped without explicit ERR reply | Invalid kitty commands produce `ERR`/`EINVAL` response when reply is allowed |
| PA-04 | Medium | todo | Kitty graphics command/delete surface is partial vs kitty/ghostty | Scope split into concrete parity tasks and progress tracked; command support expanded or explicitly deferred |
| PA-05 | Medium | todo | Kitty keyboard / CSI-u alternate/disambiguation flags tracked but not encoded | `alternate_key` / disambiguation flags affect output and tests cover behavior |
| PA-06 | Medium | done | X10 mouse encoding can emit `0` for large coords | X10 coord encoding saturates/falls back safely; no invalid zero coord bytes from overflow |
| PA-07 | Medium | done | Bare SGR `58` likely treated incorrectly as reset | Bare `58` no longer resets underline color; `59` remains reset |
| PA-08 | Medium-Low | todo | CSI/DCS/APC coverage is subset of reference terminals | Sub-gaps enumerated and prioritized with explicit roadmap/tests |

## Detailed Findings (Source Review Snapshot)

### PA-01 Unicode Width / Cursor Accounting

Evidence from review:
- `writeCodepoint` wrote `width = 1` for all non-combining codepoints.
- Combining marks were appended assuming single-cell progression.
- Replay fixture `utf8_wide_and_combining` failed with cursor mismatch (`expected c=6`, `actual c=5`).

Status:
- `done` (2026-02-23)

Implemented:
- Width-aware `Screen.writeCodepoint`
- Width-2 continuation cells (`width=0`, `x=1`)
- Overwrite cleanup for wide roots/continuations
- Combining mark attachment skips continuations
- Pre-wrap for width-2 glyphs at right edge
- Added replay fixture for wide-char edge wrapping

Files:
- `src/terminal/model/screen/screen.zig`
- `src/terminal/core/parser_hooks.zig`
- `fixtures/terminal/utf8_wide_and_combining.golden`
- `fixtures/terminal/utf8_wide_wrap_edge.vt`
- `fixtures/terminal/utf8_wide_wrap_edge.json`
- `fixtures/terminal/utf8_wide_wrap_edge.golden`

Verification:
- `zig build test-terminal-replay -- --all`

Residual gap:
- Width classification is locale-neutral and keeps East Asian ambiguous characters narrow.

### PA-02 Replay Assertions Metadata Not Enforced

Evidence from review:
- `FixtureMeta.assertions` exists but `runFixture` does not consume it.
- Fixture JSONs advertise categories (`clipboard`, `hyperlinks`, `kitty`, `cursor`) without harness enforcement.
- PTY-gated reply paths are under-tested because replay sessions have no PTY.

Status:
- `partial` (2026-02-23)

Implemented (increment 1):
- Replay harness now consumes `assertions` instead of ignoring them.
- Unknown assertion tags fail the fixture run.
- Added explicit support for current fixture tags (`grid`, `cursor`, `attrs`, `clipboard`, `hyperlinks`, `selection`, `scrollback`, `title`, `cwd`, `kitty`, `alt-screen`, `encoder`).
- Added lightweight category checks for several tags (clipboard/hyperlinks/selection/title/cwd/kitty).

Files:
- `src/terminal/replay_harness.zig`

Verification:
- `zig build test-terminal-replay -- --all`

Remaining work:
- PTY reply paths still untested in replay (`DSR/DA/OSC query/DCS/kitty replies`).
- Some tags remain recognized-but-not-semantic (`grid`, `cursor`, `attrs`, `scrollback`) until per-section assertions are implemented.

Planned fix shape (candidate):
- Phase 1: enforce/assert known assertion tags and surface them in harness output.
- Phase 2: use assertions to filter/validate snapshot sections or explicit sub-assertions.
- Phase 3: add PTY-stubbed reply fixtures for DSR/DA/OSC/DCS/kitty replies.

### PA-03 Kitty Invalid Command Error Replies

Evidence from review:
- Invalid kitty controls are logged then returned without response.
- `writeKittyResponse` exists but is bypassed on validation failure.

Status:
- `done` (2026-02-23)

Implemented:
- Invalid kitty controls now emit `EINVAL` through `writeKittyResponse` before returning.

Files:
- `src/terminal/kitty/graphics.zig`

Verification:
- `zig build test-terminal-replay -- --all` (regression sweep; no kitty fixture regressions)

Residual gap:
- No PTY-attached replay/unit test yet validates the emitted reply bytes for invalid commands (`PA-02` / PTY reply coverage gap).

### PA-04 Kitty Graphics Surface Partial vs Reference

Evidence from review:
- `validateKittyControl` currently accepts only `t/T/p/d/q`.
- Delete action coverage is partial.

Status:
- `todo`

Notes:
- This is a parity expansion item, not a single bug fix. Split before implementation.

### PA-05 Kitty Keyboard / CSI-u Alternate-Key & Disambiguation Flags

Evidence from review:
- `key_mode_report_alternate_key` declared but not used in encoder output.
- Current kitty key mapping is intentionally subset-focused.

Status:
- `todo`

### PA-06 X10 Mouse Overflow Encoding

Evidence from review:
- `mouseEncodeCoordX10` returns `0` if encoded coord exceeds byte range.

Status:
- `done` (2026-02-23)

Implemented:
- `mouseEncodeCoordX10` now saturates to `255` instead of returning `0` on overflow.
- Added direct unit coverage for overflow behavior.

Files:
- `src/terminal/input/mouse_report.zig`
- `src/terminal_mouse_report_tests.zig`

Verification:
- `zig test src/terminal_mouse_report_tests.zig`
- `zig build test-terminal-replay -- --all`

### PA-07 SGR Bare `58` Handling

Evidence from review:
- Extended `58;...` parsing exists.
- Bare `58` is later handled like `59` reset.

Status:
- `done` (2026-02-23)

Implemented:
- Removed the bare `58` reset case from the non-extended SGR switch so `58` is only handled via the extended-color parser path and incomplete `58` is ignored.

Files:
- `src/terminal/protocol/csi.zig`

Verification:
- `zig build test-terminal-replay -- --all`

### PA-08 CSI/DCS/APC Coverage Subset

Evidence from review:
- CSI parser supports current TUI needs but not broad xterm extension surface.
- DCS limited to XTGETTCAP; APC limited to kitty graphics.

Status:
- `todo`

Notes:
- Track as roadmap item with sub-issues (e.g., missing DCS queries, APC extensions, CSI tabs/window ops).

## Change Log

### 2026-02-23

- Created progress tracker from protocol support/accuracy review.
- Completed `PA-01` (Unicode width/cursor correctness baseline + edge-wrap replay coverage).
- Completed `PA-03` (kitty invalid control emits `EINVAL` reply).
- Completed `PA-06` (X10 coord overflow saturates to `255`; added unit coverage).
- Completed `PA-07` (removed bare `58` reset behavior in SGR parser).
- Advanced `PA-02` to `partial` (replay assertions are now consumed and validated; PTY reply coverage still pending).

## Next Work Queue (Ordered)

1. `PA-02` PTY reply fixture/stub coverage + stronger semantic assertion checks
2. `PA-05` Kitty keyboard alternate/disambiguation flags
3. `PA-04` Kitty graphics parity decomposition
4. `PA-08` CSI/DCS/APC parity decomposition

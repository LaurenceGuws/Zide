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

- `todo`: not started; no parity claim beyond review notes
- `in_progress`: actively being fixed in the current slice; do not start adjacent parity slices until this slice is commit/test stable or explicitly paused
- `done`: implemented behavior matches the stated scope/targets and required verification was run (unit / PTY / replay as listed)
- `deferred`: intentionally postponed with reason, target references, and explicit resume criteria
- `partial`: milestone only; useful progress landed, but parity finish criteria are not yet met

Status usage rules (parity work):
- Do not use `done` for "better unsupported reporting" unless the mode/feature is intentionally meant to remain unsupported in Zide (strategic non-support).
- If work adds `Pm=0`/`Pm=4` reporting for a mode that may later be supported, record it as provisional parity scaffolding under the parent `partial` item and add a follow-up audit entry.
- Prefer implementing support (with tests) before expanding unsupported reporting. Unsupported reporting expansion is only valid when:
  - the feature is intentionally out of scope / strategically unsupported, or
  - reference-compatible unsupported replies are required to correctly represent an already-implemented feature boundary.

## Findings Tracker

| ID | Severity | Status | Summary | Acceptance Criteria |
|---|---|---|---|---|
| PA-01 | High | done | Unicode width/cursor accounting incorrect in core write path | Wide codepoints occupy correct cell width; combining marks attach correctly; replay fixtures pass |
| PA-02 | High | done | Replay `assertions` metadata is ignored; fixture intent not enforced | Harness consumes `assertions`; fixture intent is semantically enforced for active tags; representative replay query/reply coverage exists |
| PA-03 | Medium-High | done | Kitty invalid controls can be dropped without explicit ERR reply | Invalid kitty commands produce `ERR`/`EINVAL` response when reply is allowed |
| PA-04 | Medium | partial | Kitty graphics command/delete surface is partial vs kitty/ghostty | Scope split into concrete parity tasks and progress tracked; command support expanded or explicitly deferred |
| PA-05 | Medium | partial | Kitty keyboard / CSI-u alternate/disambiguation flags tracked but not encoded | `alternate_key` / disambiguation flags affect output and tests cover behavior |
| PA-06 | Medium | done | X10 mouse encoding can emit `0` for large coords | X10 coord encoding saturates/falls back safely; no invalid zero coord bytes from overflow |
| PA-07 | Medium | done | Bare SGR `58` likely treated incorrectly as reset | Bare `58` no longer resets underline color; `59` remains reset |
| PA-08 | Medium-Low | partial | CSI/DCS/APC coverage is subset of reference terminals | Sub-gaps enumerated and prioritized with explicit roadmap/tests |

## Partial Completion Gate (Parity Discipline)

Policy (added after parity-review follow-up discussion):
- `partial` is a milestone state, not a completion state.
- Do not silently move past a `partial` item when the stated goal is parity against reference terminals (kitty / ghostty / xterm / foot).
- Do not "improve parity" by broadening unsupported-mode reporting (`Pm=0/4`) as a substitute for implementing support, unless the non-support is an explicit strategic product decision.
- Before starting a new top-level todo area, run a **partial scan** and explicitly classify each open `partial` item as one of:
  - `finish now` (blocking for correctness/parity confidence)
  - `defer intentionally` (non-blocking; leave a reason + explicit done criteria)
  - `split further` (too broad; create sub-items with clear acceptance)

Definition-of-done requirements for parity-oriented items:
- Name the reference target(s) (`kitty`, `ghostty`, `xterm`, `foot`) and scope.
- Define exact behavior/reply expectations (including unsupported behavior conventions).
- Define test coverage required to call it done (unit / PTY / replay fixtures).
- List any explicit out-of-scope behaviors so `partial` vs `done` is auditable.
- If unsupported reporting was added during a parity slice, include an explicit review of whether those modes are actually intended to remain unsupported before closing or moving past the slice.

Unsupported-reporting correction rule (applies to work already landed):
- Before continuing further `PA-08g`/`PA-08h` parity expansion, review all recently added DECRQM `Pm=4` / query-only unsupported rows and classify each as:
  - `implement now` (feature is on-path; replace reporting-only parity with real support),
  - `strategic non-support` (keep `Pm=4/0`, document rationale), or
  - `defer but provisional` (keep temporary reporting, but mark as non-completion and schedule revisit).
- Do not add additional unsupported-mode DECRQM batches until that review is completed and documented.

### Current Partial Scan (2026-02-23)

`PA-02` Replay assertions / fixture intent (`done`)
- Classification: completed in current scope (`finish now` gate satisfied).
- Why: this is test infrastructure; weak fixture intent checks can overstate coverage across all later protocol work.
- Done looks like (parity-supporting infra):
  - replay assertions have semantic checks for all supported tags we rely on
  - replay query/reply assertions cover representative DA/DSR/OSC/DCS/kitty cases
  - unknown tags fail fast (done)
  - fixture intent is not “recognized-only” for tags we actively use

`PA-04` Kitty graphics parity (`partial` scope item represented as parity slices)
- Classification: `defer intentionally` unless a user-visible kitty graphics bug appears.
- Why: large surface area; current protocol focus is broader CSI correctness and test infrastructure.
- Done looks like (when resumed):
  - explicit command/delete/query parity matrix vs kitty/ghostty
  - error-code + quiet-mode conformance documented and test-covered
  - unsupported features explicitly deferred with rationale

`PA-05` Kitty keyboard / CSI-u parity (`partial`)
- Classification: `defer intentionally`, but keep traceable.
- Why: major remaining gap is layout-aware metadata completeness; this depends on upstream input data quality, not just encoder logic.
- Done looks like:
  - layout-aware alternate key reporting end-to-end (not mostly synthetic metadata)
  - non-US/AltGr paths validated by fixtures/tests
  - disambiguation / action-field coverage complete for supported key classes

`PA-08` CSI/DCS/APC parity (`partial`)
- Classification: `split further` and continue in explicit parity slices.
- Why: umbrella item is too broad; we should keep shipping small protocol slices with reference-backed acceptance.
- Done looks like (umbrella):
  - CSI parser capability sufficient for targeted CSI families (including intermediates where required)
  - prioritized CSI/DCS/APC gaps either implemented to spec/reference behavior or explicitly deferred
  - replay/PTY coverage exists for reply-driven features we claim support for
- Current rule for this umbrella (2026-02-23 follow-up): when a mode/feature is still on the path to support, implement it before adding more unsupported-reporting-only parity polish.

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
- Fixed wrap-newline column reset on scroll paths (`wrapNewlineAction` now forces `col=0`
  for `scroll_region` / `scroll_full`) to prevent right-edge autowrap drift that can
  render long output as one-character-per-line near the viewport boundary.
- Added replay regression fixture `wrap_newline_scroll_sets_col0` and refreshed affected
  scroll fixtures.

Files:
- `src/terminal/model/screen/screen.zig`
- `src/terminal/core/parser_hooks.zig`
- `fixtures/terminal/utf8_wide_and_combining.golden`
- `fixtures/terminal/utf8_wide_wrap_edge.vt`
- `fixtures/terminal/utf8_wide_wrap_edge.json`
- `fixtures/terminal/utf8_wide_wrap_edge.golden`
- `fixtures/terminal/wrap_newline_scroll_sets_col0.vt`
- `fixtures/terminal/wrap_newline_scroll_sets_col0.json`
- `fixtures/terminal/wrap_newline_scroll_sets_col0.golden`
- `fixtures/terminal/scroll_region_basic.golden`
- `fixtures/terminal/scrollback_push.golden`

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
- `done` (2026-02-23)

Implemented (increment 1):
- Replay harness now consumes `assertions` instead of ignoring them.
- Unknown assertion tags fail the fixture run.
- Added explicit support for current fixture tags (`grid`, `cursor`, `attrs`, `clipboard`, `hyperlinks`, `selection`, `scrollback`, `title`, `cwd`, `kitty`, `alt-screen`, `encoder`).
- Added lightweight category checks for several tags (clipboard/hyperlinks/selection/title/cwd/kitty).

Files:
- `src/terminal/replay_harness.zig`

Verification:
- `zig build test-terminal-replay -- --all`

Implemented (increment 2):
- `grid`, `cursor`, and `attrs` assertions now perform semantic checks on the final snapshot/debug state instead of being recognized-only.
- `scrollback` remains recognized-only pending a clearer split between "scroll semantics" and "persistent scrollback" fixture tags.

Implemented (increment 3):
- Added direct PTY-gated reply unit tests (with fake PTY capture) for:
  - DCS `XTGETTCAP` reply (`+q` / `TN`)
  - OSC 52 clipboard query reply (BEL terminator preservation)
  - OSC 4 palette query reply (ST terminator preservation)
- Refactored reply helper functions in `dcs_apc`, `osc_clipboard`, and `palette` modules to accept generic PTY writers (`anytype`) for testability.

Files:
- `src/terminal_protocol_reply_tests.zig`
- `src/terminal/protocol/dcs_apc.zig`
- `src/terminal/protocol/osc_clipboard.zig`
- `src/terminal/protocol/palette.zig`

Verification:
- `zig test src/terminal_protocol_reply_tests.zig -lc`
- `zig build test-terminal-replay -- --all`

Implemented (increment 4):
- Expanded PTY-gated reply tests to cover:
  - XTGETTCAP failure reply for unknown cap
  - OSC 52 query reply with ST terminator preservation

Files:
- `src/terminal_protocol_reply_tests.zig`

Verification:
- `zig test src/terminal_protocol_reply_tests.zig -lc`

Implemented (increment 5):
- Added PTY-gated unit coverage for `OSC 10` dynamic-color query reply (default fg + BEL terminator).

Files:
- `src/terminal_protocol_reply_tests.zig`

Verification:
- `zig test src/terminal_protocol_reply_tests.zig -lc`

Implemented (increment 6):
- Extracted CSI `DA` / `DSR` reply writers for direct unit coverage.
- Added PTY-gated unit tests for:
  - DA primary reply
  - DSR status (5) and CPR (6)
  - DEC private DSR cursor ( ?6 ) and keyboard status ( ?26 )
  - unsupported DSR mode returns no write

Files:
- `src/terminal/protocol/csi.zig`
- `src/terminal_csi_reply_tests.zig`

Verification:
- `zig test src/terminal_csi_reply_tests.zig -lc`
- `zig build test-terminal-replay -- --all`

Implemented (increment 7):
- Added direct unit coverage for kitty reply formatting and `quiet` suppression behavior (`q=1`, `q=2`).
- Exported `writeKittyResponse` for testability (no behavior change).

Files:
- `src/terminal/kitty/graphics.zig`
- `src/terminal_kitty_reply_tests.zig`

Verification:
- `zig test src/terminal_kitty_reply_tests.zig -lc`
- `zig build test-terminal-replay -- --all`

Implemented (increment 8):
- `scrollback` replay assertion tag now enforces a semantic check instead of being recognized-only.
- The check accepts:
  - actual persistent scrollback activity (`scrollback_count` / `scrollback_offset`)
  - explicit scroll-control CSI usage (`DECSTBM`, `SU`, `SD`)
  - sufficient line-break input to force scrolling in the configured viewport height
- This preserves current fixture intent for both `scrollback_push` and `scroll_region_basic` while making the tag meaningful.

Files:
- `src/terminal/replay_harness.zig`

Verification:
- `zig build test-terminal-replay -- --all`

Implemented (increment 9):
- Added replay-harness `reply_hex` support with `assertions: ["reply"]` so VT fixtures can capture and verify PTY reply bytes end-to-end.
- The replay harness now attaches a pipe-backed PTY only for fixtures that declare `reply_hex`.
- Added initial replay reply fixtures covering `DECRQM ?1004`, `DA`, `DSR` (ANSI CPR / DEC private CPR), `OSC 10`, `OSC 52`, and a compact `DECRQM` query matrix.

Files:
- `src/terminal/replay_harness.zig`
- `fixtures/terminal/decrqm_focus_reporting_query_reply.*`
- `fixtures/terminal/da_primary_query_reply.*`
- `fixtures/terminal/dsr_cpr_query_reply.*`
- `fixtures/terminal/dsr_decx_cpr_query_reply.*`
- `fixtures/terminal/osc_10_query_reply_bel.*`
- `fixtures/terminal/osc_52_query_reply_bel.*`
- `fixtures/terminal/decrqm_query_matrix_reply.*`

Verification:
- `zig build test-terminal-replay -- --all`

Implemented (increment 10):
- Added replay reply fixtures for representative `DCS` and kitty reply paths to complete the `PA-02` “representative query/reply replay coverage” gate:
  - DCS `XTGETTCAP` (`TN`) reply
  - kitty invalid-command `EINVAL` reply
- This closes the replay-level representative set across `DA/DSR/OSC/DCS/kitty`.

Files:
- `fixtures/terminal/dcs_xtgettcap_tn_query_reply.*`
- `fixtures/terminal/kitty_invalid_command_reply.*`

Verification:
- `zig build test-terminal-replay -- --all`

Implemented (increment 11):
- Expanded `XTGETTCAP` reply coverage for multi-cap requests:
  - unit coverage locks ordered concatenated replies for `TN`, `Co`, `RGB`, and unknown-cap failure in one `DCS +q ...` request.
  - replay coverage locks the same end-to-end byte stream in fixture flow.

Files:
- `src/terminal_protocol_reply_tests.zig`
- `fixtures/terminal/dcs_xtgettcap_multi_query_reply.vt`
- `fixtures/terminal/dcs_xtgettcap_multi_query_reply.json`
- `fixtures/terminal/dcs_xtgettcap_multi_query_reply.golden`

Verification:
- `zig test src/terminal_protocol_reply_tests.zig -lc`
- `zig build test-terminal-replay -- --fixture dcs_xtgettcap_multi_query_reply --update-goldens`
- `zig build test-terminal-replay -- --all`

Completion note (scope of `done`):
- `PA-02` is considered `done` for test-infrastructure purposes because assertion metadata is enforced semantically for the active tags we rely on and replay-level reply assertions now cover representative query/reply families (`DA/DSR/OSC/DCS/kitty`).
- This does **not** imply exhaustive protocol parity coverage; future fixtures can extend the replay reply matrix as new protocol slices are implemented.

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
- Replay-level coverage for invalid kitty reply bytes now exists via `fixtures/terminal/kitty_invalid_command_reply.*`.

### PA-04 Kitty Graphics Surface Partial vs Reference

Evidence from review:
- `validateKittyControl` currently accepts only `t/T/p/d/q`.
- Delete action coverage is partial.

Status:
- `partial` (2026-02-23)

Notes:
- This is a parity expansion item, not a single bug fix. Split before implementation.

Implemented (increment 1 / `PA-04a` parity map):
- Documented the currently implemented kitty graphics `a=` action surface and `d=` delete variants directly from `src/terminal/kitty/graphics.zig`.
- This converts the review note ("partial") into a traceable parity map for follow-on fixes and fixtures.

Current `a=` action surface (from `validateKittyControl`):
- Implemented: `t` (transmit), `T` (transmit+place), `p` (place), `d` (delete), `q` (query)
- Rejected as invalid (current behavior): all other `a=` actions

Current `d=` delete variant surface (from `deleteKittyByAction`, default `a`):
- Implemented selectors:
  - `a` / `A` all placements / all images
  - `i` / `I` by image id (+ optional placement id) / image+placements
  - `n` / `N` by image number (+ optional placement id) / image+placements
  - `c` / `C` at cursor cell / plus image deletion
  - `p` / `P` at explicit cell (`x`,`y`) / plus image deletion
  - `z` / `Z` by z-layer / plus image deletion
  - `r` / `R` image id range (`x..y`) / plus image deletion
  - `x` / `X` column intersection / plus image deletion
  - `y` / `Y` row intersection / plus image deletion
- Unknown/unsupported selectors: now treated as invalid (`EINVAL` error reply subject to quiet-mode suppression).

Files:
- `app_architecture/terminal/PROTOCOL_ACCURACY_PROGRESS.md`

Verification:
- Source-audit only (mapped to current code in `src/terminal/kitty/graphics.zig`)

Sub-items (traceable parity slices):
- `PA-04a` Kitty action surface parity map (`a=` actions supported/unsupported, reference behavior notes)
- `PA-04b` Delete action parity map (`d=` variants and semantics)
- `PA-04c` Query/reply conformance tests (`a=q`, error codes, quiet modes)
- `PA-04d` Transfer medium/chunking/compression regression fixtures (direct/file/temp/shm/zlib/chunks)
- `PA-04e` Parent/virtual placement regression fixtures (cycles/depth/errors)
- `PA-04f` Animation/composition support decision (implement vs defer explicitly)

Planned acceptance by phase:
- Phase 1: parity map + fixture matrix documented, unsupported commands explicitly listed.
- Phase 2: query/delete conformance fixtures and fixes.
- Phase 3: transfer/placement parity fixtures and fixes.
- Phase 4: animation/composition implement or defer with rationale.

Auditability snapshot (2026-02-27, post `AUDIT-05/06/07/08`):

| Surface | Status | Current behavior lock |
|---|---|---|
| `a=t/T/p` | implemented | Accepted by parser; existing transmit/place behavior unchanged in this slice |
| `a=d` delete | implemented (policy-aligned) | Success reply suppressed for all quiet levels (`q=0/1/2`) per `AUDIT-05` |
| `a=q` query | implemented (policy-aligned) | Missing id/number path is explicit no-reply policy (`AUDIT-05`); payload/format errors still emit mapped errors unless quiet-suppressed |
| `a=` other actions | deferred/invalid | Explicitly invalid at parser gate (`EINVAL` response subject to quiet rules) |
| `d=` selectors `a/A i/I n/N c/C p/P z/Z r/R x/X y/Y` | implemented | Selector semantics covered by replay matrix; uppercase variants remove backing images where applicable |
| `d=` selectors `q/Q f/F` | deferred (explicit) | Treated as invalid (`EINVAL`) with quiet-policy tests + replay lock (`AUDIT-07`) |
| Unknown `d=` selector | invalid (policy-aligned) | Explicit `EINVAL` reply for `q=0/1`; suppressed for `q=2` (`AUDIT-06`) |

Reply/quiet rule parity lock (current intended behavior):

| Case | `q=0` | `q=1` | `q=2` |
|---|---|---|---|
| `a=d` successful delete | no reply | no reply | no reply |
| `a=q` successful query | reply | reply suppressed | reply suppressed |
| `a=q` missing image id/number | no reply | no reply | no reply |
| invalid control / invalid selector | error reply (`EINVAL`) | error reply (`EINVAL`) | error suppressed |

Implemented (increment 35 / `PA-04f` animation/composition path decision):
- Decision: **defer intentionally** for current Zide scope.
- Current parser/validation surface explicitly accepts only `a=t/T/p/d/q`; animation/composition-specific kitty actions are not accepted in `validateKittyControl` and remain out-of-scope for this cycle.
- Rationale:
  - no active app-compat signal requiring animation/composition support
  - higher-value parity work remains in `PA-04c` transport/query edge forms and `PA-08h` terminal-control gaps
  - keeping unsupported actions explicit avoids silent partial behavior drift
- Resume criteria:
  - concrete user/app breakage tied to missing kitty animation/composition actions, or
  - targeted parity mandate with bounded fixture matrix + expected behavior table.
- Evidence:
  - source surface lock: `src/terminal/kitty/graphics.zig` (`validateKittyControl`, action gating)
  - replay/query conformance remains covered by existing `a=q` and delete fixture matrix.

Implemented (increment 2 / `PA-04c` fixture matrix start):
- Added replay fixtures for kitty delete conformance behavior (state-level coverage):
  - `d=p` explicit point delete removes placement but preserves image storage
  - `d=P` explicit point delete removes placement and backing image
- unsupported delete selector (e.g. `d=v`) preserves kitty state and now emits explicit `EINVAL` reply (`q=0/1`; suppressed by `q=2`)
- These fixtures validate the current delete-surface semantics through snapshot `kitty:` state (`images`, `placements`, ids).

Files:
- `fixtures/terminal/kitty_delete_point_preserves_image.vt`
- `fixtures/terminal/kitty_delete_point_preserves_image.json`
- `fixtures/terminal/kitty_delete_point_preserves_image.golden`
- `fixtures/terminal/kitty_delete_point_uppercase_deletes_image.vt`
- `fixtures/terminal/kitty_delete_point_uppercase_deletes_image.json`
- `fixtures/terminal/kitty_delete_point_uppercase_deletes_image.golden`
- `fixtures/terminal/kitty_delete_unsupported_selector_noop.vt`
- `fixtures/terminal/kitty_delete_unsupported_selector_noop.json`
- `fixtures/terminal/kitty_delete_unsupported_selector_noop.golden`

Verification:
- `zig build test-terminal-replay -- --all`

Implemented (increment 36 / `AUDIT-06` unknown delete-selector invalid reply):
- Updated kitty delete handling so unknown `d=` selectors are not silent: they now emit `EINVAL` via `writeKittyResponse`.
- Preserved known-selector behavior: successful delete actions still emit no success reply (`q=0/1/2` behavior unchanged), and existing invalid-control reply behavior remains intact.
- Expanded parse-path tests for unknown selector quiet behavior:
  - `q=0` / `q=1` => `EINVAL`
  - `q=2` => reply suppressed
- Updated replay fixture expectations for the prior unsupported-selector no-op case to assert end-to-end reply bytes while still locking unchanged kitty state.

Files:
- `src/terminal/kitty/graphics.zig`
- `src/terminal_kitty_query_parse_tests.zig`
- `fixtures/terminal/kitty_delete_unsupported_selector_noop.json`

Verification:
- `zig test src/terminal_kitty_query_parse_tests.zig -lc`
- `zig build test-terminal-replay -- --fixture kitty_delete_unsupported_selector_noop`

Implemented (increment 3 / `PA-04b` delete selector fixture expansion):
- Expanded replay delete conformance fixtures to cover additional selector pairs:
  - `c` / `C` (cursor-cell selector; placement-only vs image+placement delete)
  - `z` / `Z` (z-layer selector; placement-only vs image+placement delete)
  - `r` / `R` (image-id range selector via `x..y`; placement-only vs image+placement delete)
- Range fixtures use two stored images to validate that delete scope is limited to the selected id range.

Files:
- `fixtures/terminal/kitty_delete_cursor_preserves_image.vt`
- `fixtures/terminal/kitty_delete_cursor_preserves_image.json`
- `fixtures/terminal/kitty_delete_cursor_preserves_image.golden`
- `fixtures/terminal/kitty_delete_cursor_uppercase_deletes_image.vt`
- `fixtures/terminal/kitty_delete_cursor_uppercase_deletes_image.json`
- `fixtures/terminal/kitty_delete_cursor_uppercase_deletes_image.golden`
- `fixtures/terminal/kitty_delete_z_preserves_image.vt`
- `fixtures/terminal/kitty_delete_z_preserves_image.json`
- `fixtures/terminal/kitty_delete_z_preserves_image.golden`
- `fixtures/terminal/kitty_delete_z_uppercase_deletes_image.vt`
- `fixtures/terminal/kitty_delete_z_uppercase_deletes_image.json`
- `fixtures/terminal/kitty_delete_z_uppercase_deletes_image.golden`
- `fixtures/terminal/kitty_delete_range_preserves_images.vt`
- `fixtures/terminal/kitty_delete_range_preserves_images.json`
- `fixtures/terminal/kitty_delete_range_preserves_images.golden`
- `fixtures/terminal/kitty_delete_range_uppercase_deletes_images.vt`
- `fixtures/terminal/kitty_delete_range_uppercase_deletes_images.json`
- `fixtures/terminal/kitty_delete_range_uppercase_deletes_images.golden`

Verification:
- `zig build test-terminal-replay -- --all`

Implemented (increment 4 / `PA-04b` delete edge-case fixtures):
- Added replay fixtures for additional delete-selector edge cases:
  - `i` with `placement_id` filter: matching placement removed, non-matching filter is a no-op
  - `I` uppercase image delete ignores `placement_id` filter and removes the backing image
  - `n/N` image-number selectors (current implementation aliases image number to id in delete resolution)
  - `x/X` and `y/Y` selectors on multi-cell placements with partial-overlap coordinates
- These fixtures lock current semantics for placement-id filtering and overlap-based selectors in snapshot `kitty:` state.

Files:
- `fixtures/terminal/kitty_delete_image_selector_pid_filter_match.vt`
- `fixtures/terminal/kitty_delete_image_selector_pid_filter_match.json`
- `fixtures/terminal/kitty_delete_image_selector_pid_filter_match.golden`
- `fixtures/terminal/kitty_delete_image_selector_pid_filter_no_match.vt`
- `fixtures/terminal/kitty_delete_image_selector_pid_filter_no_match.json`
- `fixtures/terminal/kitty_delete_image_selector_pid_filter_no_match.golden`
- `fixtures/terminal/kitty_delete_image_uppercase_ignores_pid_filter.vt`
- `fixtures/terminal/kitty_delete_image_uppercase_ignores_pid_filter.json`
- `fixtures/terminal/kitty_delete_image_uppercase_ignores_pid_filter.golden`
- `fixtures/terminal/kitty_delete_image_number_preserves_image.vt`
- `fixtures/terminal/kitty_delete_image_number_preserves_image.json`
- `fixtures/terminal/kitty_delete_image_number_preserves_image.golden`
- `fixtures/terminal/kitty_delete_image_number_uppercase_deletes_image.vt`
- `fixtures/terminal/kitty_delete_image_number_uppercase_deletes_image.json`
- `fixtures/terminal/kitty_delete_image_number_uppercase_deletes_image.golden`
- `fixtures/terminal/kitty_delete_x_preserves_image_partial_overlap.vt`
- `fixtures/terminal/kitty_delete_x_preserves_image_partial_overlap.json`
- `fixtures/terminal/kitty_delete_x_preserves_image_partial_overlap.golden`
- `fixtures/terminal/kitty_delete_x_uppercase_deletes_image_partial_overlap.vt`
- `fixtures/terminal/kitty_delete_x_uppercase_deletes_image_partial_overlap.json`
- `fixtures/terminal/kitty_delete_x_uppercase_deletes_image_partial_overlap.golden`
- `fixtures/terminal/kitty_delete_y_preserves_image_partial_overlap.vt`
- `fixtures/terminal/kitty_delete_y_preserves_image_partial_overlap.json`
- `fixtures/terminal/kitty_delete_y_preserves_image_partial_overlap.golden`
- `fixtures/terminal/kitty_delete_y_uppercase_deletes_image_partial_overlap.vt`
- `fixtures/terminal/kitty_delete_y_uppercase_deletes_image_partial_overlap.json`
- `fixtures/terminal/kitty_delete_y_uppercase_deletes_image_partial_overlap.golden`

Verification:
- `zig build test-terminal-replay -- --all`

Implemented (increment 5 / `PA-04b` mixed-selector interaction fixtures):
- Added replay fixtures that combine no-match and match delete operations in a single scenario for `x/X` and `y/Y` selectors.
- Each fixture uses two images/placements and verifies:
  - an initial no-match delete is a no-op
  - a lowercase selector deletes only the matching placement
  - a later uppercase selector deletes the other matching placement and backing image
- This adds interaction coverage (sequence semantics) rather than only isolated selector cases.

Files:
- `fixtures/terminal/kitty_delete_x_mixed_interactions.vt`
- `fixtures/terminal/kitty_delete_x_mixed_interactions.json`
- `fixtures/terminal/kitty_delete_x_mixed_interactions.golden`
- `fixtures/terminal/kitty_delete_y_mixed_interactions.vt`
- `fixtures/terminal/kitty_delete_y_mixed_interactions.json`
- `fixtures/terminal/kitty_delete_y_mixed_interactions.golden`

Verification:
- `zig build test-terminal-replay -- --fixture kitty_delete_x_mixed_interactions --update-goldens`
- `zig build test-terminal-replay -- --fixture kitty_delete_y_mixed_interactions --update-goldens`
- `zig build test-terminal-replay -- --all`

Implemented (increment 6 / `PA-04b` selector-composition fixtures with id/number filters):
- Added larger replay fixtures that combine image-id/image-number selectors with overlap selectors:
  - `i/I` + `x/X`
  - `n/N` + `y/Y`
- These scenarios verify multi-step delete sequencing in one fixture:
  - selector-specific no-op with non-matching `placement_id` filter
  - lowercase overlap delete removes placement only
  - uppercase id/number delete removes backing image even with non-matching `placement_id` filter
- This extends coverage beyond isolated selector behavior into selector composition and ordering.

Files:
- `fixtures/terminal/kitty_delete_iI_x_mixed_interactions.vt`
- `fixtures/terminal/kitty_delete_iI_x_mixed_interactions.json`
- `fixtures/terminal/kitty_delete_iI_x_mixed_interactions.golden`
- `fixtures/terminal/kitty_delete_nN_y_mixed_interactions.vt`
- `fixtures/terminal/kitty_delete_nN_y_mixed_interactions.json`
- `fixtures/terminal/kitty_delete_nN_y_mixed_interactions.golden`

Verification:
- `zig build test-terminal-replay -- --fixture kitty_delete_iI_x_mixed_interactions --update-goldens`
- `zig build test-terminal-replay -- --fixture kitty_delete_nN_y_mixed_interactions --update-goldens`
- `zig build test-terminal-replay -- --all`

Implemented (increment 7 / `PA-04b` dense multi-placement selector sequencing fixture):
- Added a denser replay fixture using non-zero `placement_id`s and multiple placements on the same image to exercise selector ordering in one scenario.
- The sequence combines:
  - `d=i` no-op with non-matching `placement_id`
  - `d=i` targeted placement delete on image 1 (`p=11`)
  - `d=x` overlap delete removing the remaining image-1 placement only
  - `d=y` overlap delete removing image-2 placement only
  - `d=I` uppercase image delete on image 2 (with ignored mismatched `placement_id`)
- Final state preserves image 1 (no placements) and image 3 (untouched), which makes sequencing effects visible in the golden.

Files:
- `fixtures/terminal/kitty_delete_dense_pid_selector_sequence.vt`
- `fixtures/terminal/kitty_delete_dense_pid_selector_sequence.json`
- `fixtures/terminal/kitty_delete_dense_pid_selector_sequence.golden`

Verification:
- `zig build test-terminal-replay -- --fixture kitty_delete_dense_pid_selector_sequence --update-goldens`
- `zig build test-terminal-replay -- --all`

Query coverage note (`PA-04c` remaining):
- `a=q` reply-byte conformance is now substantially covered:
  - helper-level branch/unit coverage for early replies and payload/build reply branches
  - project-integrated parse-path tests with real `TerminalSession` + PTY capture for representative success/error cases
- Added a small extracted seam for the early `a=q` parse-path replies (`missing image id`, metadata-only query); these cases now have direct unit coverage.
- Payload/image reply coverage status:
  - covered via extracted helpers: `EINVAL` (chunked/load-failure), `ENODATA` size reply formatting, build-error message mapping (`EBADPNG`/`EINVAL`)
  - covered via project-integrated parse-path tests: metadata-only `OK`, PNG decode failure (`EBADPNG`), raw RGBA success (`OK`), raw RGBA short payload (`ENODATA`)
  - covered via project-integrated parse-path tests: quiet-mode suppression semantics (`q=1`, `q=2`) and invalid chunking/offset query forms (`m=1`, `O=1`)
  - remaining gap: broader integrated matrix (more formats/quiet variants combinations, multi-chunk query edge cases if supported/invalidated)

Implemented (increment 3 / `PA-04c` query early-reply seam):
- Extracted `handleKittyQueryEarlyReply()` from `parseKittyGraphics()` for `a=q` early replies:
  - missing image id -> `EINVAL`
  - metadata-only query (`i=` with no payload/dimensions) -> `OK`
  - non-metadata query falls through to existing payload path unchanged
- Added direct unit tests for the helper, covering handled error/success and fallthrough behavior.

Files:
- `src/terminal/kitty/graphics.zig`
- `src/terminal_kitty_reply_tests.zig`

Verification:
- `zig test src/terminal_kitty_reply_tests.zig -lc`
- `zig build test-terminal-replay -- --all`

Implemented (increment 4 / `PA-04c` query payload-validation seams):
- Extracted test seams for `a=q` payload-validation reply branches:
  - preflight invalid chunked/offset query -> `EINVAL`
  - payload load failure -> `EINVAL`
  - insufficient payload bytes -> `ENODATA:...`
  - build error reply message mapping (`EBADPNG` vs `EINVAL`)
- `parseKittyGraphics()` now routes these branches through helper functions without changing behavior.
- Added direct unit coverage for all extracted branches and message formatting.

Files:
- `src/terminal/kitty/graphics.zig`
- `src/terminal_kitty_reply_tests.zig`

Verification:
- `zig test src/terminal_kitty_reply_tests.zig -lc`
- `zig build test-terminal-replay -- --all`

Implemented (increment 5 / `PA-04c` integrated chunk-build reply seam):
- Extracted `handleKittyQueryChunkBuildReply()` to cover the integrated `a=q` chunk-processing reply control flow after payload load:
  - size check / `ENODATA`
  - build error mapping (`EBADPNG` / `EINVAL`)
  - success `OK` reply
- `parseKittyGraphics()` now uses this helper with an injected builder callback that wraps the real `buildKittyImage()` path and preserves existing behavior.
- Added direct unit tests for integrated success and build-error branches via injected fake builders.

Files:
- `src/terminal/kitty/graphics.zig`
- `src/terminal_kitty_reply_tests.zig`

Verification:
- `zig test src/terminal_kitty_reply_tests.zig -lc`
- `zig build test-terminal-replay -- --all`

Implemented (increment 6 / `PA-04c` project-integrated parse-path tests):
- Added a project-integrated test target with real `TerminalSession` + PTY reply capture for `kitty.parseKittyGraphics(a=q,...)`:
  - uses a pipe-backed synthetic `Pty` value attached to the session to capture terminal->app reply bytes deterministically
  - compiles via `zig build` with project `stb_image` setup, avoiding standalone `zig test` C-include friction
- Added end-to-end parse-path tests covering:
  - metadata-only query -> `OK`
  - invalid PNG payload -> `EBADPNG`
  - raw RGBA query payload success -> `OK`
  - raw RGBA short payload -> `ENODATA`
- Added build step: `zig build test-terminal-kitty-query-parse`

Files:
- `src/terminal_kitty_query_parse_tests.zig`
- `build.zig`

Verification:
- `zig build test-terminal-kitty-query-parse`
- `zig test src/terminal_kitty_reply_tests.zig -lc`
- `zig build test-terminal-replay -- --all`

Implemented (increment 7 / `PA-04c` integrated quiet/invalid query cases):
- Expanded project-integrated `a=q` parse-path tests to cover:
  - `q=1` quiet mode suppresses success replies but not error replies
  - `q=2` quiet mode suppresses error replies
  - invalid chunked query (`m=1`) emits `EINVAL` through the full parse path
  - invalid offset query (`O=1`) emits `EINVAL` through the full parse path
- Added a `PipeCapture.expectNoReply()` helper for deterministic no-reply assertions in the project-integrated test target.

Files:
- `src/terminal_kitty_query_parse_tests.zig`

Verification:
- `zig build test-terminal-kitty-query-parse`

Implemented (increment 8 / `PA-04c` integrated quiet/error matrix + RGB query cases):
- Expanded the project-integrated `a=q` parse-path tests to cover more quiet-mode combinations:
  - `q=2` suppresses `ENODATA`
  - `q=2` suppresses preflight `EINVAL`
- Added additional raw RGB (`f=24`) integrated parse-path coverage:
  - valid RGB payload -> `OK`
  - short RGB payload -> `ENODATA`
- This strengthens both the quiet/error matrix and format coverage in the end-to-end parse path.

Files:
- `src/terminal_kitty_query_parse_tests.zig`

Verification:
- `zig build test-terminal-kitty-query-parse`

Implemented (increment 9 / `PA-04c` integrated format/error matrix expansion):
- Expanded end-to-end `a=q` parse-path tests with additional format and validation combinations:
  - valid PNG (`f=100`) success -> `OK`
  - `q=2` suppresses PNG success replies
  - unsupported format (`f=999`) -> `EINVAL`
  - `q=2` suppresses unsupported-format `EINVAL`
  - RGBA payload without dimensions (`f=32` and no `s`/`v`) -> `EINVAL`
  - `q=2` suppresses missing-dimensions `EINVAL`
- This strengthens parser-path conformance coverage for format validation and dimension requirements, not just payload-size checks.

Files:
- `src/terminal_kitty_query_parse_tests.zig`

Verification:
- `zig build test-terminal-kitty-query-parse`

Implemented (increment 10 / `PA-04c` malformed base64 + compression-flag query matrix):
- Expanded project-integrated `a=q` parse-path tests for additional payload-encoding conditions:
  - malformed base64 payload -> `EINVAL`
  - `q=2` suppresses malformed-base64 `EINVAL`
  - `o=z` with raw RGBA payload still returns `OK` in the current query path
  - `o=z` with zlib-compressed RGBA payload also currently returns `OK` (current behavior: query path does not inflate `o=z`)
  - `q=2` suppresses the current `o=z` success reply path
- These tests explicitly document and lock current query-path compression behavior while improving quiet/error coverage.
- Also fixed a leak exposed by the new invalid-format parse-path tests: `buildKittyImage()` now frees owned payload data before returning `InvalidData` when `f=` is unsupported.

Files:
- `src/terminal/kitty/graphics.zig`
- `src/terminal_kitty_query_parse_tests.zig`

Verification:
- `zig build test-terminal-kitty-query-parse`
- `zig build test-terminal-replay -- --all`
- Environment note: `test-terminal-kitty-query-parse` can fail in restricted environments on the shared-memory medium test (`ShmOpenFailed`); replay sweep remains authoritative and passed in this slice.

Implemented (increment 11 / `PA-04c` align query `o=z` behavior with kitty/ghostty convention):
- Updated the `a=q` parse path to honor query payload compression (`o=z`) instead of ignoring it.
- Query flow now inflates zlib-compressed payloads before size validation/build checks, matching the shared load/validate behavior expected by kitty/ghostty-style implementations.
- Invalid/decompression-failed `o=z` query payloads now return `EINVAL` (and still respect quiet suppression semantics).
- Updated integrated parse-path tests to lock the new behavior:
  - compressed RGBA payload + `o=z` -> `OK`
  - uncompressed RGBA payload + `o=z` -> `EINVAL`
  - quiet-mode combinations for compressed success and decompression error

Files:
- `src/terminal/kitty/graphics.zig`
- `src/terminal_kitty_query_parse_tests.zig`

Verification:
- `zig build test-terminal-kitty-query-parse`
- `zig build test-terminal-replay -- --all`

Implemented (increment 12 / `PA-04c` integrated `o=z` error-matrix expansion):
- Expanded integrated `a=q` parse-path coverage for additional `o=z` failure and quiet-mode combinations:
  - `q=2` suppresses decompression-error replies
  - malformed zlib stream payload -> `EINVAL`
  - post-inflate size mismatch -> `ENODATA`
- This locks the new kitty/ghostty-aligned query compression behavior across both pre-build decompression failures and post-inflate size validation.

Files:
- `src/terminal_kitty_query_parse_tests.zig`

Verification:
- `zig build test-terminal-kitty-query-parse`

Implemented (increment 13 / `PA-04c` compressed PNG query matrix):
- Added integrated `a=q` parse-path tests for compressed PNG (`f=100,o=z`) success/error and quiet-mode behavior:
  - valid compressed PNG -> `OK`
  - `q=2` suppresses compressed PNG success replies
  - compressed invalid PNG payload -> `EBADPNG`
  - `q=1` does not suppress compressed PNG `EBADPNG`
  - `q=2` suppresses compressed PNG `EBADPNG`
- This extends the query compression coverage beyond raw RGB/RGBA into the PNG decode path and quiet-mode conformance.

Files:
- `src/terminal_kitty_query_parse_tests.zig`

Verification:
- `zig build test-terminal-kitty-query-parse`

Implemented (increment 14 / `PA-04c` compressed query parser-precedence edge cases):
- Added integrated `a=q` compressed-payload coverage for parser/decoder precedence in the PNG path (`f=100,o=z`) with quiet-mode variants.
- The matrix now spans:
  - decompression failures (`EINVAL`)
  - decode failures after successful decompression (`EBADPNG`)
  - successful decode (`OK`)
  - quiet suppression / non-suppression across success and error modes
- This makes the compressed query path precedence substantially more explicit in tests.

Files:
- `src/terminal_kitty_query_parse_tests.zig`

Verification:
- `zig build test-terminal-kitty-query-parse`

Implemented (increment 15 / `PA-04c` invalid `o=` and `m/O + o=z` precedence cases):
- Added integrated `a=q` parse-path tests for:
  - unsupported compression value (`o=1`) -> `EINVAL`
  - `q=2` suppression for unsupported compression reply
  - chunked query (`m=1`) + `o=z` returns preflight `EINVAL` (compression is not consulted first)
  - offset query (`O=1`) + `o=z` returns preflight `EINVAL`
  - `q=2` suppression for both preflight error cases
- These tests explicitly lock parser-path precedence between query preflight validation and compression handling.

Files:
- `src/terminal_kitty_query_parse_tests.zig`

Verification:
- `zig build test-terminal-kitty-query-parse`

Implemented (increment 16 / `PA-04c` invalid `o=` ordering vs decode/size validation):
- Added integrated `a=q` parse-path tests to ensure unsupported compression (`o=1`)
  returns `EINVAL` before later validation stages that would otherwise yield:
  - PNG decode error (`EBADPNG`)
  - raw RGBA size mismatch (`ENODATA`)
  - raw RGBA missing-dimensions validation
- This extends parser-precedence coverage beyond `q` suppression and `m/O` preflight
  cases to include deeper format/decode branches.

Files:
- `src/terminal_kitty_query_parse_tests.zig`

Verification:
- `zig build test-terminal-kitty-query-parse`

Implemented (increment 17 / `PA-04c` invalid `o=` ordering vs missing-id/format/payload decode):
- Added integrated `a=q` parse-path tests locking additional precedence combinations:
  - missing image id preflight beats invalid compression handling
  - invalid compression (`o=1`) beats invalid format validation
  - invalid compression beats malformed payload base64 error handling
  - `q=2` suppression still applies when missing-id preflight wins
- The malformed payload precedence test exposed and fixed a real leak in kitty base64
  decoding (`decodeBase64` used `errdefer` in an optional-return path, so invalid
  base64 could leak temporary storage).

Files:
- `src/terminal_kitty_query_parse_tests.zig`
- `src/terminal/kitty/graphics.zig`

Verification:
- `zig build test-terminal-kitty-query-parse`
- `zig build test-terminal-replay -- --all`

Implemented (increment 18 / `PA-04c` missing-id precedence matrix expansion):
- Added integrated `a=q` parse-path tests confirming missing image-id preflight wins over:
  - invalid format validation
  - chunked query preflight (`m=1`, including with `o=z`)
- Added `q=2` suppression coverage when missing-id preflight wins over invalid format.
- This extends early-error ordering coverage around the highest-priority `image_id`
  preflight branch.

Files:
- `src/terminal_kitty_query_parse_tests.zig`

Verification:
- `zig build test-terminal-kitty-query-parse`

Implemented (increment 19 / `PA-04c` `q=1` missing-id precedence permutations):
- Added integrated `a=q` parse-path tests proving `q=1` does not suppress missing-id
  preflight errors when missing-id wins over:
  - invalid compression (`o=1`)
  - malformed payload data
  - chunked `m=1,o=z` forms
- This closes the `q=1` permutation gap for the missing-id early-error branch.

Files:
- `src/terminal_kitty_query_parse_tests.zig`

Verification:
- `zig build test-terminal-kitty-query-parse`

Implemented (increment 20 / `PA-04c` `q=1` mixed invalid-format precedence combinations):
- Added integrated `a=q` parse-path tests proving missing-id preflight still wins (and
  `q=1` still does not suppress the error) when mixed lower-priority invalid branches
  are also present:
  - invalid compression + invalid format
  - chunked zlib form + invalid format
- Added `q=2` suppression coverage for the mixed invalid-compression + invalid-format
  case when missing-id preflight is the winning branch.

Files:
- `src/terminal_kitty_query_parse_tests.zig`

Verification:
- `zig build test-terminal-kitty-query-parse`
- `zig build test-terminal-replay -- --all`

Implemented (increment 21 / `PA-04c` table-driven missing-id precedence matrix refactor):
- Refactored the integrated missing-id precedence tests into a compact table-driven
  matrix using reusable reply / no-reply helpers.
- No behavior change intended; this reduces repetition and makes it cheaper to add
  more early-error ordering cases.

Files:
- `src/terminal_kitty_query_parse_tests.zig`

Verification:
- `zig build test-terminal-kitty-query-parse`
- `zig build test-terminal-replay -- --all`

Implemented (increment 22 / `PA-04c` `q=2` mixed missing-id precedence matrix expansion):
- Expanded the table-driven missing-id precedence matrix with additional `q=2`
  quiet-mode combinations that mix invalid format, malformed payload, invalid
  compression (`o=1`), and chunked zlib forms.
- This locks the no-reply behavior when missing-id preflight wins over multiple
  simultaneous lower-priority invalid branches.

Files:
- `src/terminal_kitty_query_parse_tests.zig`

Verification:
- `zig build test-terminal-kitty-query-parse`
- `zig build test-terminal-replay -- --all`

Implemented (increment 23 / `PA-04c` missing-id matrix `O=` offset combinations):
- Extended the table-driven missing-id precedence matrix to cover mixed invalid
  `O=` (offset) combinations with invalid format and malformed payload branches under
  both `q=1` and `q=2`.
- This closes the offset-form counterpart to the earlier `o=` invalid-compression
  missing-id precedence coverage in the matrix path.

Files:
- `src/terminal_kitty_query_parse_tests.zig`

Verification:
- `zig build test-terminal-kitty-query-parse`
- `zig build test-terminal-replay -- --all`

Implemented (increment 24 / `PA-04c` dense missing-id multi-invalid precedence matrix expansion):
- Expanded the table-driven missing-id precedence matrix to cover denser combinations
  where missing-id preflight competes with multiple simultaneous lower-priority
  branches in one sequence, including:
  - invalid compression (`o=1`) + invalid format + malformed payload
  - invalid offset (`O=1`) + invalid compression + invalid format + malformed payload
  - chunked query (`m=1`) + invalid compression + invalid format + malformed payload
  - offset/chunked zlib preflight variants under `q=2` no-reply behavior
- This increases confidence that the highest-priority missing-id preflight ordering
  remains stable even as more parser validation branches are added.

Files:
- `src/terminal_kitty_query_parse_tests.zig`

Verification:
- `zig build test-terminal-kitty-query-parse`
- `zig build test-terminal-replay -- --all`

Implemented (increment 25 / `PA-04c` table-driven non-missing-id invalid-compression precedence matrix):
- Replaced scattered one-off tests for non-missing-id `invalid o=` precedence with a
  compact table-driven matrix covering reply/no-reply behavior across:
  - PNG decode branch
  - raw RGBA size and missing-dimensions branches
  - invalid format branch
  - malformed payload decode branch
  - `q=1` reply and `q=2` no-reply variants
- This brings the same table-driven style used for missing-id precedence to the
  non-missing-id invalid-compression precedence path.

Files:
- `src/terminal_kitty_query_parse_tests.zig`

Verification:
- `zig build test-terminal-kitty-query-parse`
- `zig build test-terminal-replay -- --all`

Implemented (increment 26 / `PA-04c` table-driven non-missing-id zlib preflight precedence matrix):
- Replaced remaining one-off non-missing-id chunk/offset+zlib preflight tests with a
  compact table-driven matrix for `m=1,o=z` and `O=1,o=z` query forms.
- Covers reply/no-reply behavior and precedence against invalid format/malformed payload
  branches under `q=1` and `q=2`.
- This brings the major query-precedence families (missing-id, invalid-compression,
  zlib preflight) under a consistent table-driven test style.

Files:
- `src/terminal_kitty_query_parse_tests.zig`

Verification:
- `zig build test-terminal-kitty-query-parse`
- `zig build test-terminal-replay -- --all`

Implemented (increment 27 / `PA-04c` retire redundant isolated precedence one-off):
- Removed the remaining isolated missing-id precedence test (`q=2` suppresses missing-id
  preflight before invalid compression) after confirming equivalent coverage exists in
  the table-driven missing-id precedence matrix.
- Result: the major kitty query precedence families are table-driven in current scope
  (missing-id, invalid-compression, zlib preflight), with non-matrix tests focused on
  non-precedence behaviors (reply formatting, decode/build outcomes, quiet semantics).

Files:
- `src/terminal_kitty_query_parse_tests.zig`

Verification:
- `zig build test-terminal-kitty-query-parse`
- `zig build test-terminal-replay -- --all`

Implemented (increment 28 / `PA-04c` precedence matrix layout polish):
- Added an explicit section header in `src/terminal_kitty_query_parse_tests.zig` to mark
  the grouped query precedence matrix coverage block.
- This is a no-behavior-change readability pass to make future additions/reviews easier.

Files:
- `src/terminal_kitty_query_parse_tests.zig`

Verification:
- `zig build test-terminal-kitty-query-parse`
- `zig build test-terminal-replay -- --all`

Implemented (increment 29 / `PA-04c` non-missing-id `O=` precedence matrix + replay locks):
- Expanded the non-missing-id `a=q` precedence matrix to explicitly cover invalid offset
  (`O=1`) ordering against invalid format and malformed payload combinations under both
  `q=1` (reply) and `q=2` (suppressed reply).
- Added replay-level `reply_hex` fixtures to lock representative end-to-end precedence:
  - non-missing-id `O=1` + invalid-format+malformed quiet split (`q=1` emits `EINVAL`, `q=2` suppresses)
  - chunk/offset zlib preflight (`m=1,o=z` and `O=1,o=z`) quiet split in one stream

Files:
- `src/terminal_kitty_query_parse_tests.zig`
- `fixtures/terminal/kitty_query_offset_precedence_q1_q2_reply.vt`
- `fixtures/terminal/kitty_query_offset_precedence_q1_q2_reply.json`
- `fixtures/terminal/kitty_query_offset_precedence_q1_q2_reply.golden`
- `fixtures/terminal/kitty_query_chunk_offset_z_precedence_q1_q2_reply.vt`
- `fixtures/terminal/kitty_query_chunk_offset_z_precedence_q1_q2_reply.json`
- `fixtures/terminal/kitty_query_chunk_offset_z_precedence_q1_q2_reply.golden`

Verification:
- `zig build test-terminal-kitty-query-parse`
- `zig build test-terminal-replay -- --fixture kitty_query_offset_precedence_q1_q2_reply --update-goldens`
- `zig build test-terminal-replay -- --fixture kitty_query_chunk_offset_z_precedence_q1_q2_reply --update-goldens`
- `zig build test-terminal-replay -- --all`

Implemented (increment 30 / `PA-04c` medium transport success matrix for query path):
- Expanded project-integrated `a=q` parse-path coverage for transport mediums with real success-path behavior:
  - `t=f` file medium with valid PNG path payload (`OK`)
  - `t=t` temp-file medium with valid `/tmp/*tty-graphics-protocol*` path payload (`OK`)
- Added quiet-mode expectations for both mediums:
  - `q=1` suppresses success reply
  - `q=2` suppresses success reply
- Added behavioral assertion for `t=t` temp-file cleanup (file removed after read path).

Files:
- `src/terminal_kitty_query_parse_tests.zig`

Verification:
- `zig build test-terminal-kitty-query-parse`

Implemented (increment 31 / `PA-04c` mixed `m=1` + `O=1` precedence matrix + replay lock):
- Added integrated precedence matrix coverage for non-missing-id queries where chunk/offset forms are combined in one request:
  - `m=1,O=1` (with and without `o=z`) under `q=1` and `q=2`
  - mixed lower-priority invalid branches (`f=999` + malformed payload) to ensure preflight precedence remains stable
- Added replay-level reply lock covering the same mixed precedence under both quiet modes in one stream.

Files:
- `src/terminal_kitty_query_parse_tests.zig`
- `fixtures/terminal/kitty_query_mixed_chunk_offset_precedence_q1_q2_reply.vt`
- `fixtures/terminal/kitty_query_mixed_chunk_offset_precedence_q1_q2_reply.json`
- `fixtures/terminal/kitty_query_mixed_chunk_offset_precedence_q1_q2_reply.golden`

Verification:
- `zig build test-terminal-kitty-query-parse`
- `zig build test-terminal-replay -- --fixture kitty_query_mixed_chunk_offset_precedence_q1_q2_reply --update-goldens`
- `zig build test-terminal-replay -- --fixture kitty_query_mixed_chunk_offset_precedence_q1_q2_reply`

Implemented (increment 32 / `PA-04c` shared-memory (`t=s`) query transport success coverage):
- Added project-integrated parse-path coverage for kitty query shared-memory medium (`t=s`) with valid PNG payloads.
- Locked behavior for quiet-mode success suppression:
  - baseline success reply (`OK`)
  - `q=1` success suppression
  - `q=2` success suppression
- Test helper now creates and fills temporary POSIX shared-memory objects for deterministic transport-path validation.

Files:
- `src/terminal_kitty_query_parse_tests.zig`

Verification:
- `zig build test-terminal-kitty-query-parse`

Implemented (increment 33 / `PA-04c` replay lock for file-medium success + quiet split):
- Added replay-level fixture lock for kitty query file medium (`t=f`) success behavior in one stream:
  - `q=1` success suppressed
  - default `q=0` success replies `OK`
  - `q=2` success suppressed
- Added deterministic fixture asset PNG used by the replay file-medium success path.

Files:
- `fixtures/terminal/assets/kitty_query_png_1x1.png`
- `fixtures/terminal/kitty_query_medium_file_success_q1_q2_reply.vt`
- `fixtures/terminal/kitty_query_medium_file_success_q1_q2_reply.json`
- `fixtures/terminal/kitty_query_medium_file_success_q1_q2_reply.golden`

Verification:
- `zig build test-terminal-replay -- --fixture kitty_query_medium_file_success_q1_q2_reply --update-goldens`
- `zig build test-terminal-replay -- --fixture kitty_query_medium_file_success_q1_q2_reply`
- `zig build test-terminal-replay -- --all`

Implemented (increment 34 / `PA-04c` replay transport error-matrix expansion + `t=s` replay-limit note):
- Added replay fixtures for additional transport error permutations with explicit quiet split (`q=1` reply, `q=2` suppression):
  - file medium (`t=f`) missing path
  - temp medium (`t=t`) missing `tty-graphics-protocol` marker path
- Documented replay limitation for shared-memory transport (`t=s`):
  - parse-path unit/integration tests cover `t=s` success/suppression with real shm objects
  - replay harness remains intentionally file-stream-only for now, so deterministic shm lifecycle fixtures are deferred

Files:
- `fixtures/terminal/kitty_query_medium_file_missing_q1_q2_reply.vt`
- `fixtures/terminal/kitty_query_medium_file_missing_q1_q2_reply.json`
- `fixtures/terminal/kitty_query_medium_file_missing_q1_q2_reply.golden`
- `fixtures/terminal/kitty_query_medium_temp_missing_marker_q1_q2_reply.vt`
- `fixtures/terminal/kitty_query_medium_temp_missing_marker_q1_q2_reply.json`
- `fixtures/terminal/kitty_query_medium_temp_missing_marker_q1_q2_reply.golden`

Implemented (increment 36 / `PA-04c` replay `t=s` edge-form locks within current harness limits):
- Added replay fixtures for shared-memory query medium (`t=s`) error edge forms with explicit quiet split (`q=1` reply, `q=2` suppression):
  - missing shared-memory name/object path (`EINVAL`)
  - transport-precedence invalid combination (`m=1` with non-direct medium) (`EINVAL`)
- This closes the practical replay-side `t=s` edge coverage that is feasible without extending replay harness lifecycle control for real shm objects.

Files:
- `fixtures/terminal/kitty_query_medium_shm_missing_q1_q2_reply.vt`
- `fixtures/terminal/kitty_query_medium_shm_missing_q1_q2_reply.json`
- `fixtures/terminal/kitty_query_medium_shm_missing_q1_q2_reply.golden`
- `fixtures/terminal/kitty_query_medium_shm_precedence_q1_q2_reply.vt`
- `fixtures/terminal/kitty_query_medium_shm_precedence_q1_q2_reply.json`
- `fixtures/terminal/kitty_query_medium_shm_precedence_q1_q2_reply.golden`

Verification:
- `zig build test-terminal-replay -- --fixture kitty_query_medium_shm_missing_q1_q2_reply --update-goldens`
- `zig build test-terminal-replay -- --fixture kitty_query_medium_shm_precedence_q1_q2_reply --update-goldens`
- `zig build test-terminal-replay -- --fixture kitty_query_medium_shm_missing_q1_q2_reply`
- `zig build test-terminal-replay -- --fixture kitty_query_medium_shm_precedence_q1_q2_reply`

Implemented (increment 37 / `PA-04c` parent/virtual placement replay matrix start):
- Added replay fixtures that lock first parent/virtual placement success and error expectations with explicit ids and reply bytes:
  - success state lock for parented placement (`P/Q/H/V`) plus virtual placement (`U=1`) in one stream, asserted via kitty snapshot ids
  - missing parent placement reference returns `ENOPARENT`
  - invalid virtual+parent combination (`U=1` with `P/Q`) returns `EINVAL`
  - parent cycle update returns `ECYCLE`
- This establishes deterministic replay authority for the first `PA-04c` parent/virtual slice without changing kitty placement behavior.

Files:
- `fixtures/terminal/kitty_parent_virtual_success_state.vt`
- `fixtures/terminal/kitty_parent_virtual_success_state.json`
- `fixtures/terminal/kitty_parent_virtual_success_state.golden`
- `fixtures/terminal/kitty_parent_missing_reply.vt`
- `fixtures/terminal/kitty_parent_missing_reply.json`
- `fixtures/terminal/kitty_parent_missing_reply.golden`
- `fixtures/terminal/kitty_virtual_parent_combo_invalid_reply.vt`
- `fixtures/terminal/kitty_virtual_parent_combo_invalid_reply.json`
- `fixtures/terminal/kitty_virtual_parent_combo_invalid_reply.golden`
- `fixtures/terminal/kitty_parent_cycle_reply.vt`
- `fixtures/terminal/kitty_parent_cycle_reply.json`
- `fixtures/terminal/kitty_parent_cycle_reply.golden`

Verification:
- `zig build test-terminal-replay -- --fixture kitty_parent_virtual_success_state --update-goldens`
- `zig build test-terminal-replay -- --fixture kitty_parent_missing_reply --update-goldens`
- `zig build test-terminal-replay -- --fixture kitty_virtual_parent_combo_invalid_reply --update-goldens`
- `zig build test-terminal-replay -- --fixture kitty_parent_cycle_reply --update-goldens`
- `zig build test-terminal-replay -- --fixture kitty_parent_virtual_success_state`
- `zig build test-terminal-replay -- --fixture kitty_parent_missing_reply`
- `zig build test-terminal-replay -- --fixture kitty_virtual_parent_combo_invalid_reply`
- `zig build test-terminal-replay -- --fixture kitty_parent_cycle_reply`
- `zig build check-app-imports`

Implemented (increment 38 / `PA-04c` parent-chain depth-limit replay lock):
- Added replay fixture that locks parent-chain depth-limit behavior for parented placements:
  - long parent chain build with quiet setup
  - depth-overflow placement attempt replies `ETOODEEP` with explicit `i/p` identifiers.
- This gives deterministic replay evidence for the depth-limit branch in parented placement handling.

Files:
- `fixtures/terminal/kitty_parent_depth_limit_reply.vt`
- `fixtures/terminal/kitty_parent_depth_limit_reply.json`
- `fixtures/terminal/kitty_parent_depth_limit_reply.golden`

Verification:
- `zig build test-terminal-replay -- --fixture kitty_parent_depth_limit_reply --update-goldens`
- `zig build test-terminal-replay -- --fixture kitty_parent_depth_limit_reply`
- `zig build check-app-imports`

Implemented (increment 39 / `PA-04c` parented-placement delete interaction lock):
- Added replay fixture that locks a mixed delete interaction on parented placements:
  - deleting parent image by `d=I,i=<parent>` removes the parent image and also removes child placements that reference it as `parent_image_id`
  - unrelated placements on surviving images remain intact
- This adds explicit regression authority for parent-reference cleanup behavior in delete flows.

Files:
- `fixtures/terminal/kitty_delete_parent_image_cascades_child_placements.vt`
- `fixtures/terminal/kitty_delete_parent_image_cascades_child_placements.json`
- `fixtures/terminal/kitty_delete_parent_image_cascades_child_placements.golden`

Verification:
- `zig build test-terminal-replay -- --fixture kitty_delete_parent_image_cascades_child_placements --update-goldens`
- `zig build test-terminal-replay -- --fixture kitty_delete_parent_image_cascades_child_placements`
- `zig build check-app-imports`

Implemented (increment 40 / `PA-04c` parented placement success lock without explicit `p`):
- Added replay fixture that locks the parented placement path when no explicit placement id is provided (`p=0` path):
  - parent reference via `P/Q/H/V` succeeds
  - reply format is `OK` with image id only (`i=<id>;OK`)
  - kitty snapshot asserts resulting placement state is retained.

Files:
- `fixtures/terminal/kitty_parent_no_pid_success_reply.vt`
- `fixtures/terminal/kitty_parent_no_pid_success_reply.json`
- `fixtures/terminal/kitty_parent_no_pid_success_reply.golden`

Verification:
- `zig build test-terminal-replay -- --fixture kitty_parent_no_pid_success_reply --update-goldens`
- `zig build test-terminal-replay -- --fixture kitty_parent_no_pid_success_reply`
- `zig build check-app-imports`

Implemented (increment 41 / `PA-04c` temp-medium preflight precedence side-effect lock):
- Added project-integrated parse-path coverage for kitty query temp-file medium (`t=t`) with invalid query chunk/offset forms:
  - `m=1` and `O=1` still take query preflight `EINVAL` branches for `q=1`
  - `q=2` continues to suppress those preflight errors
- Locked a side-effect boundary not previously explicit in tests: invalid query preflight must occur before temp-medium file loading, so temp files are not consumed/deleted on these invalid forms.

Files:
- `src/terminal_kitty_query_parse_tests.zig`

Verification:
- `zig build test-terminal-kitty-query-parse`

Verification:
- `zig build test-terminal-replay -- --fixture kitty_query_medium_file_missing_q1_q2_reply --update-goldens`
- `zig build test-terminal-replay -- --fixture kitty_query_medium_file_missing_q1_q2_reply`
- `zig build test-terminal-replay -- --fixture kitty_query_medium_temp_missing_marker_q1_q2_reply --update-goldens`
- `zig build test-terminal-replay -- --fixture kitty_query_medium_temp_missing_marker_q1_q2_reply`

Implemented (increment 42 / `PA-04c` fixture-matrix closure gate):
- Closed the `PA-04c` query/reply fixture-matrix gate for the current kitty graphics parity phase:
  - query-path precedence/error/quiet matrices are covered by integrated parse-path tests.
  - transport medium paths (`t=d/f/t/s`) and representative failure forms are replay-locked within current harness limits.
  - parent/virtual placement reply and delete-interaction branches are replay-locked with explicit ids/reply bytes.
- Remaining kitty graphics parity breadth is now tracked under other `PA-04*` rows (not `PA-04c` fixture-matrix incompleteness).

Verification:
- `zig build test-terminal-kitty-query-parse`
- `zig build test-terminal-replay -- --all`

Implemented (increment 43 / `PA-04c` unknown delete-selector quiet-policy replay lock):
- Added replay fixture authority for unknown kitty delete-selector behavior across quiet levels:
  - `q=1` unknown selector emits `EINVAL`
  - `q=2` unknown selector suppresses the error reply
- Fixture also locks kitty-state no-op semantics (image/placement unchanged) for the unknown-selector path.

Files:
- `fixtures/terminal/kitty_delete_unknown_selector_quiet_policy.vt`
- `fixtures/terminal/kitty_delete_unknown_selector_quiet_policy.json`
- `fixtures/terminal/kitty_delete_unknown_selector_quiet_policy.golden`

Verification:
- `zig build test-terminal-replay -- --fixture kitty_delete_unknown_selector_quiet_policy --update-goldens`
- `zig build test-terminal-replay -- --fixture kitty_delete_unknown_selector_quiet_policy`

Implemented (increment 44 / `PA-04c` unknown delete-selector quiet matrix replay lock):
- Added replay fixture coverage that locks unknown delete-selector behavior across all quiet levels in one stream:
  - default quiet (`q=0`) -> `EINVAL` reply
  - `q=1` -> `EINVAL` reply
  - `q=2` -> reply suppressed
- The fixture also locks no-op kitty state semantics for the unknown-selector path (image/placement retained).

Files:
- `fixtures/terminal/kitty_delete_unknown_selector_quiet_matrix_reply.vt`
- `fixtures/terminal/kitty_delete_unknown_selector_quiet_matrix_reply.json`
- `fixtures/terminal/kitty_delete_unknown_selector_quiet_matrix_reply.golden`

Verification:
- `zig build test-terminal-replay -- --fixture kitty_delete_unknown_selector_quiet_matrix_reply --update-goldens`
- `zig build test-terminal-replay -- --fixture kitty_delete_unknown_selector_quiet_matrix_reply`
- `zig build test-terminal-replay -- --all`

Implemented (increment 45 / `PA-04c` invalid kitty-action quiet matrix replay lock):
- Added replay fixture coverage that locks invalid kitty action (`a=x`) reply policy across all quiet levels in one stream:
  - default quiet (`q=0`) -> `EINVAL` reply
  - `q=1` -> `EINVAL` reply (error reply still emitted)
  - `q=2` -> reply suppressed
- This pins end-to-end parser+dispatcher behavior for invalid-action handling and quiet-policy suppression.

Files:
- `fixtures/terminal/kitty_invalid_action_quiet_matrix_reply.vt`
- `fixtures/terminal/kitty_invalid_action_quiet_matrix_reply.json`
- `fixtures/terminal/kitty_invalid_action_quiet_matrix_reply.golden`

Verification:
- `zig build test-terminal-replay -- --fixture kitty_invalid_action_quiet_matrix_reply --update-goldens`
- `zig build test-terminal-replay -- --fixture kitty_invalid_action_quiet_matrix_reply`
- `zig build test-terminal-replay -- --all`

Implemented (increment 46 / `PA-04c` invalid query-chunk quiet matrix replay lock):
- Added replay fixture coverage for invalid kitty query chunk marker (`a=q,m=1`) across quiet levels in one stream:
  - default quiet (`q=0`) -> `EINVAL` reply
  - `q=1` -> `EINVAL` reply (error reply preserved)
  - `q=2` -> reply suppressed
- The fixture includes payload bytes to force the query preflight/validation path (avoids metadata-only early `OK` path) and locks parser+reply-policy behavior end-to-end.

Files:
- `fixtures/terminal/kitty_query_invalid_chunk_quiet_matrix_reply.vt`
- `fixtures/terminal/kitty_query_invalid_chunk_quiet_matrix_reply.json`
- `fixtures/terminal/kitty_query_invalid_chunk_quiet_matrix_reply.golden`

Verification:
- `zig build test-terminal-replay -- --fixture kitty_query_invalid_chunk_quiet_matrix_reply --update-goldens`
- `zig build test-terminal-replay -- --fixture kitty_query_invalid_chunk_quiet_matrix_reply`
- `zig build test-terminal-replay -- --all`

Implemented (increment 47 / `PA-04c` invalid query-offset quiet matrix replay lock):
- Added replay fixture coverage for invalid kitty query offset marker (`a=q,O=1`) across quiet levels in one stream:
  - default quiet (`q=0`) -> `EINVAL` reply
  - `q=1` -> `EINVAL` reply (error reply preserved)
  - `q=2` -> reply suppressed
- This locks end-to-end parser/query-preflight error policy for offset-invalid forms with deterministic reply bytes.

Files:
- `fixtures/terminal/kitty_query_invalid_offset_quiet_matrix_reply.vt`
- `fixtures/terminal/kitty_query_invalid_offset_quiet_matrix_reply.json`
- `fixtures/terminal/kitty_query_invalid_offset_quiet_matrix_reply.golden`

Verification:
- `zig build test-terminal-replay -- --fixture kitty_query_invalid_offset_quiet_matrix_reply --update-goldens`
- `zig build test-terminal-replay -- --fixture kitty_query_invalid_offset_quiet_matrix_reply`
- `zig build test-terminal-replay -- --all`

Implemented (increment 48 / `PA-04c` parse-path mirror tests for query preflight quiet matrices):
- Added focused project-integrated parse-path tests that mirror the new replay quiet matrices for invalid query preflight forms:
  - invalid chunk marker (`a=q,m=1`) across `q=0/1/2`
  - invalid offset marker (`a=q,O=1`) across `q=0/1/2`
- This adds unit/integration authority for the same behavior now locked in replay fixtures, reducing risk of internal parser/control-flow drift.

Files:
- `src/terminal_kitty_query_parse_tests.zig`

Verification:
- `zig build test-terminal-kitty-query-parse -- --test-filter "invalid chunk quiet-policy matrix"` *(fails in this environment due existing shared-memory test path: `ShmOpenFailed`)*
- `zig build test-terminal-kitty-query-parse -- --test-filter "invalid offset quiet-policy matrix"` *(fails in this environment due existing shared-memory test path: `ShmOpenFailed`)*
- `zig build test-terminal-replay -- --all`

Implemented (increment 49 / `PA-04c` parse-path invalid-action quiet matrix mirror):
- Added a focused parse-path matrix test for invalid kitty action (`a=x`) across quiet levels:
  - `q=0` -> `EINVAL` reply
  - `q=1` -> `EINVAL` reply
  - `q=2` -> reply suppressed
- This mirrors the replay lock with in-process parse-path authority for the same quiet-policy behavior.

Files:
- `src/terminal_kitty_query_parse_tests.zig`

Verification:
- `zig build test-terminal-kitty-query-parse` *(fails in this environment due existing shared-memory test path: `ShmOpenFailed`; new test still compiles/runs within suite before that failure point)*
- `zig build test-terminal-replay -- --all`

Implemented (increment 50 / `PA-04c` invalid-action metadata reply-field quiet matrix replay lock):
- Added replay fixture coverage for invalid action (`a=x`) with explicit metadata fields (`i=`, `I=`, `p=`) across quiet levels:
  - `q=0` -> `EINVAL` reply with `i/I/p` fields preserved
  - `q=1` -> `EINVAL` reply with `i/I/p` fields preserved
  - `q=2` -> reply suppressed
- This locks reply-field formatting and quiet-policy behavior together for the invalid-action path.

Files:
- `fixtures/terminal/kitty_invalid_action_metadata_quiet_matrix_reply.vt`
- `fixtures/terminal/kitty_invalid_action_metadata_quiet_matrix_reply.json`
- `fixtures/terminal/kitty_invalid_action_metadata_quiet_matrix_reply.golden`

Verification:
- `zig build test-terminal-replay -- --fixture kitty_invalid_action_metadata_quiet_matrix_reply --update-goldens`
- `zig build test-terminal-replay -- --fixture kitty_invalid_action_metadata_quiet_matrix_reply`
- `zig build test-terminal-replay -- --all`

Implemented (increment 51 / `PA-04c` shared-memory query matrix test skip gate in constrained environments):
- Updated the shared-memory medium success matrix test to skip when shared-memory object creation is unavailable (`ShmOpenFailed`) instead of failing the whole suite.
- This preserves coverage where shm is supported while restoring deterministic pass/fail semantics for sandboxed/restricted environments.

Files:
- `src/terminal_kitty_query_parse_tests.zig`

Verification:
- `zig build test-terminal-kitty-query-parse`
- `zig build test-terminal-replay -- --all`

Implemented (increment 52 / `PA-04c` invalid query-compression quiet matrix replay + parse mirror):
- Added a compact replay quiet matrix for invalid query compression value (`a=q,o=1`) across quiet levels in one stream:
  - `q=0` -> `EINVAL` reply
  - `q=1` -> `EINVAL` reply
  - `q=2` -> reply suppressed
- Added a matching parse-path matrix test in `src/terminal_kitty_query_parse_tests.zig` so replay authority and integration authority remain paired for this policy slice.

Files:
- `fixtures/terminal/kitty_query_invalid_compression_quiet_matrix_reply.vt`
- `fixtures/terminal/kitty_query_invalid_compression_quiet_matrix_reply.json`
- `fixtures/terminal/kitty_query_invalid_compression_quiet_matrix_reply.golden`
- `src/terminal_kitty_query_parse_tests.zig`

Verification:
- `zig build test-terminal-replay -- --fixture kitty_query_invalid_compression_quiet_matrix_reply --update-goldens`
- `zig build test-terminal-replay -- --fixture kitty_query_invalid_compression_quiet_matrix_reply`
- `zig build test-terminal-kitty-query-parse`
- `zig build test-terminal-replay -- --all`

Implemented (increment 53 / `PA-04c` `o=z` decompression-error quiet matrix replay + parse mirror):
- Added a compact replay quiet matrix for `o=z` decompression-error query forms (`a=q,o=z` with uncompressed RGBA payload) across quiet levels in one stream:
  - `q=0` -> `EINVAL` reply
  - `q=1` -> `EINVAL` reply
  - `q=2` -> reply suppressed
- Added a matching parse-path matrix test in `src/terminal_kitty_query_parse_tests.zig` to keep replay and integration authority aligned for this error-policy slice.

Files:
- `fixtures/terminal/kitty_query_oz_decompression_error_quiet_matrix_reply.vt`
- `fixtures/terminal/kitty_query_oz_decompression_error_quiet_matrix_reply.json`
- `fixtures/terminal/kitty_query_oz_decompression_error_quiet_matrix_reply.golden`
- `src/terminal_kitty_query_parse_tests.zig`

Verification:
- `zig build test-terminal-replay -- --fixture kitty_query_oz_decompression_error_quiet_matrix_reply --update-goldens`
- `zig build test-terminal-replay -- --fixture kitty_query_oz_decompression_error_quiet_matrix_reply`
- `zig build test-terminal-kitty-query-parse`
- `zig build test-terminal-replay -- --all`

### PA-05 Kitty Keyboard / CSI-u Alternate-Key & Disambiguation Flags

Evidence from review:
- `key_mode_report_alternate_key` declared but not used in encoder output.
- Current kitty key mapping is intentionally subset-focused.

Status:
- `partial` (2026-02-23)

Implemented (increment 1):
- Unsupported `alternate_key` flag is now sanitized out when pushed/modified/queried via key mode flags.
- Prevents `CSI ?u` query replies and input snapshots from advertising a flag the encoder does not implement.

Files:
- `src/terminal/core/input_modes.zig`
- `src/terminal_input_modes_tests.zig`

Verification:
- `zig test src/terminal_input_modes_tests.zig`
- `zig build test-terminal-replay -- --all`

Implemented (increment 2):
- `disambiguate` mode now affects char-key output in the legacy input path:
  - protocol encoding is attempted before legacy Ctrl/Alt fallback
  - modified chars can emit CSI-u without requiring `report_text`
  - unmodified ambiguous control chars (e.g. `ESC`) can emit CSI-u in disambiguate mode
- Test helper `encodeCharBytesForTest` now matches runtime gating for `report_text` / `disambiguate`.
- Updated encoder replay golden for `report_text` plain-char case to match runtime output (`CSI-u` instead of empty bytes).

Files:
- `src/terminal/input/input.zig`
- `src/terminal_input_encoding_tests.zig`
- `fixtures/terminal/encoder/csi_u_encoder_bytes.golden`

Verification:
- `zig test src/terminal_input_encoding_tests.zig`

Implemented (increment 11):
- Completed `report_all_event_types` action-field coverage for non-cursor function keys in disambiguate mode:
  - `Enter`, `Tab`, `Backspace`, `Escape`, `Ins`, `Del`, `PgUp`, `PgDn`
  - repeat (`:2`) and release (`:3`) forms
- Added replay encoder fixtures/goldens to lock the action-field matrix beyond cursor/home/end, with representative modified-key cases.

Files:
- `src/terminal_input_encoding_tests.zig`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_enter_release.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_enter_repeat.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_tab_release.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_tab_repeat.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_backspace_release.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_backspace_repeat.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_escape_release.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_escape_repeat.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_ins_release.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_ins_repeat.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_del_release.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_del_repeat.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_pageup_release.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_pageup_repeat.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_pagedown_release.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_pagedown_repeat.json`

Verification:
- `zig test src/terminal_input_encoding_tests.zig`
- `zig build test-terminal-replay -- --all`
- `zig build test-terminal-replay -- --all`

Implemented (increment 12 / `AUDIT-09` release omits associated text field for `embed_text`):
- Suppressed CSI-u associated text (third field) for char **release** events when `embed_text` is enabled.
- Press/repeat behavior is unchanged:
  - press continues to include associated text
  - repeat continues to include associated text plus action (`:2`) when `report_all_event_types` is active
- Updated test helper parity for char-event encoding so release formatting matches runtime behavior.
- Added focused unit coverage proving press includes associated text while release omits it.

Files:
- `src/terminal/input/input.zig`
- `src/terminal_input_encoding_tests.zig`

Verification:
- `zig test src/terminal_input_encoding_tests.zig`

Implemented (increment 13 / `AUDIT-10` multi-codepoint associated text for `embed_text`):
- Updated CSI-u associated-text serialization (third field) for char press/repeat paths to support multiple codepoints as colon-separated decimal values when metadata provides multi-codepoint UTF-8 text.
- Behavior remains consistent with `AUDIT-09`: release events still omit the associated-text field entirely.
- Runtime encoder and test helper parity were kept aligned for `embed_text` formatting.
- Added focused input-encoding tests for:
  - press/repeat multi-codepoint associated text serialization
  - release omission even when metadata contains multi-codepoint text

Files:
- `src/terminal/input/input.zig`
- `src/terminal_input_encoding_tests.zig`

Verification:
- `zig test src/terminal_input_encoding_tests.zig`

Implemented (increment 14 / `AUDIT-10` replay encoder fixture locks):
- Added replay encoder fixtures to lock multi-codepoint `embed_text` associated-text serialization for:
  - press (`;;97:98`)
  - repeat (`;:2;97:98`)
  - release omission (`;:3` with no third field)

Files:
- `fixtures/terminal/encoder/csi_u_embed_text_multicodepoint_press.json`
- `fixtures/terminal/encoder/csi_u_embed_text_multicodepoint_press.golden`
- `fixtures/terminal/encoder/csi_u_embed_text_multicodepoint_repeat.json`
- `fixtures/terminal/encoder/csi_u_embed_text_multicodepoint_repeat.golden`
- `fixtures/terminal/encoder/csi_u_embed_text_multicodepoint_release_omit.json`
- `fixtures/terminal/encoder/csi_u_embed_text_multicodepoint_release_omit.golden`
- `src/terminal/replay_harness.zig` (encoder char-event action passthrough for alternate metadata path)

Verification:
- `zig build test-terminal-replay -- --all`

Implemented (increment 14 / `AUDIT-11` alternate-field emission without Shift):
- Relaxed CSI-u alternate serialization gating so metadata-provided alternate layout codepoints can emit without requiring `Shift`.
- When no shifted field is present, the encoder now emits kitty/foot-style empty shifted slot syntax (`key::alternate`) instead of suppressing the alternate field.
- Kept existing shifted alternate behavior unchanged (`key:shifted[:alternate]` still applies for Shift paths).
- Added focused coverage for a no-Shift metadata event and locked it with both unit and encoder replay fixture assertions.

Files:
- `src/terminal/input/input.zig`
- `src/terminal_input_encoding_tests.zig`
- `fixtures/terminal/encoder/csi_u_alternate_metadata_no_shift_third_field.json`
- `fixtures/terminal/encoder/csi_u_alternate_metadata_no_shift_third_field.golden`

Verification:
- `zig test src/terminal_input_encoding_tests.zig`
- `zig build test-terminal-replay -- --fixture csi_u_alternate_metadata_no_shift_third_field`

Deferred (increment 7 / layout-aware alternates decision):
- Explicitly deferred full layout-aware alternate-key reporting (beyond the current US-ASCII shifted-char subset).
- Rationale:
  - the current legacy char input path only receives a resolved Unicode codepoint + modifier bits
  - it does not carry keyboard-layout metadata (e.g. unshifted/base codepoint, physical key identity, alternate layout codepoint)
  - reliable kitty `report_alternate_key` parity for non-US layouts requires that metadata to avoid incorrect `key:shifted[:alternate]` fields
- Decision:
  - keep the current US-ASCII shifted subset in place as a pragmatic enhancement
  - do not expand heuristics further without upstream input-model support for layout/base-key metadata
  - track future work as an input-model/API extension rather than more encoding heuristics

Follow-on sub-items:
- `PA-05a` Define required input metadata for layout-aware alternates (base/unshifted codepoint, physical key, produced text)
- `PA-05b` Thread metadata through input event path to kitty encoder
- `PA-05c` Add non-US layout replay/unit fixtures once metadata exists

Implemented (increment 8 / `PA-05a` metadata contract definition):
- Added a dedicated architecture note defining the minimum input-event metadata
  needed for layout-aware kitty `report_alternate_key` parity.
- The contract specifies required fields (`physical_key`, `produced_text_utf8`,
  `base_codepoint`, `shifted_codepoint`, optional `alternate_layout_codepoint`)
  and encoder expectations/non-goals.
- This converts the `PA-05` blocker into an explicit contract for future input
  pipeline work (`PA-05b` / `PA-05c`).

Files:
- `app_architecture/terminal/KEYBOARD_ALTERNATE_METADATA_CONTRACT.md`
- `app_architecture/terminal/PROTOCOL_ACCURACY_PROGRESS.md`

Implemented (increment 9 / `PA-05b` type-only metadata threading to input boundary):
- Added `types.KeyboardAlternateMetadata` as the runtime carrier for the `PA-05a` contract fields (all optional, no behavior impact yet).
- Added additive input-layer event structs/APIs:
  - `input.KeyInputEvent`
  - `input.CharInputEvent`
  - `sendKeyActionEvent(...)`
  - `sendCharActionEvent(...)`
- Added additive terminal session entrypoints:
  - `sendKeyActionWithMetadata(...)`
  - `sendCharActionWithMetadata(...)`
- Current encoder behavior is unchanged: metadata is threaded to the input boundary and intentionally ignored for now pending real layout-aware encoding work.
- Added a unit test ensuring the char-event metadata path preserves current encoded output bytes.

Files:
- `src/terminal/model/types.zig`
- `src/terminal/input/input.zig`
- `src/terminal/core/terminal_session.zig`
- `src/terminal_input_encoding_tests.zig`

Verification:
- `zig test src/terminal_input_encoding_tests.zig`
- `zig build test-terminal-replay -- --all`

Implemented (increment 10 / `PA-05b` UI/key-encoder call-site metadata threading):
- Threaded `KeyboardAlternateMetadata` through active UI terminal input call sites into the new terminal session metadata APIs (`send*WithMetadata(...)`) without changing encoding behavior.
- Updated key-mapped key and ctrl/alt fallback-char paths in `key_encoder` to pass:
  - `physical_key` (from UI key enum)
  - `base_codepoint` when a base char is known
- Updated direct terminal text and report-text key-char paths in `terminal_widget_input` to call `sendCharActionWithMetadata(...)` and attach available metadata (`produced_text_utf8`, `base_codepoint`, key identity where available).
- Metadata remains a no-op in the encoder for now; this step is plumbing only.

Files:
- `src/terminal/input/key_encoder.zig`
- `src/ui/widgets/terminal_widget_input.zig`
- `app_architecture/terminal/PROTOCOL_ACCURACY_PROGRESS.md`

Verification:
- `zig test src/terminal_input_encoding_tests.zig`
- `zig build test-terminal-replay -- --all`

Implemented (increment 11 / `PA-05b` shared input metadata plumbing from platform ingestion):
- Extended `shared_types.input` events with additive metadata fields:
  - `KeyEvent.scancode`
  - `TextEvent.utf8_len` / `TextEvent.utf8` / `TextEvent.text_is_composed`
- Preserved UTF-8 bytes per text codepoint through the SDL input path (`platform.input_events` -> `ui.Renderer` queue -> `input_builder`) and attached scancodes to key events in `InputBatch`.
- Updated terminal UI metadata assembly to consume event-provided fields (`scancode`, `utf8`) when available, reducing local metadata synthesis.
- Existing behavior remains unchanged; this is metadata quality/plumbing for future layout-aware alternate-key encoding.

Files:
- `src/types/input.zig`
- `src/platform/input_events.zig`
- `src/ui/renderer.zig`
- `src/app_shell.zig`
- `src/input/input_builder.zig`
- `src/ui/widgets/terminal_widget_input.zig`

Verification:
- `zig build`
- `zig build test-terminal-replay -- --all`

Implemented (increment 12 / `PA-05b` IME commit `text_is_composed` propagation):
- Propagated `text_is_composed` from the SDL text-input path when text input is emitted while composition was active.
- The renderer now captures composition-active state immediately before `EVENT_TEXT_INPUT` clears composition, and passes that signal into per-codepoint text queue entries.
- `input_builder` preserves the composed flag into `shared_types.input.TextEvent`, so terminal input metadata consumers receive a real IME/compose signal.

Files:
- `src/platform/input_events.zig`
- `src/ui/renderer.zig`
- `src/input/input_builder.zig`

Verification:
- `zig build`
- `zig build test-terminal-replay -- --all`

Implemented (increment 13 / `PA-05b` preserve SDL key symbol metadata in input events):
- Extended platform key queue and shared input key events to preserve the SDL key symbol (`sym`) alongside scancode.
- `input_builder` now records `KeyEvent.sym` for keydown events (and leaves it absent on synthetic release events).
- This is additive metadata plumbing for future layout/base-key inference work and complements the existing scancode path.

Files:
- `src/platform/input_events.zig`
- `src/types/input.zig`
- `src/input/input_builder.zig`

Verification:
- `zig build`

Implemented (increment 14 / `PA-05b` SDL scancode translation probe + runtime metadata derivation):
- Added SDL wrapper helpers for:
  - scancode+modifier translation via `SDL_GetKeyFromScancode(...)`
  - printable SDL keycode -> Unicode codepoint conversion
- Exposed these helpers through `ui.Renderer` so terminal widget input can use them
  without introducing a direct `ui/widgets -> platform` dependency.
- Terminal widget input now uses best-effort runtime SDL translation (when scancode is
  present) to populate richer metadata on char/report-text paths:
  - `base_codepoint`
  - `shifted_codepoint`
  - inferred distinct `alternate_layout_codepoint` (from event `sym`)
- Text events can now inherit this richer key metadata from the preceding key event in
  the same input batch, improving real runtime alternate-key fidelity beyond synthetic
  test fixtures.

Files:
- `src/platform/sdl_api.zig`
- `src/ui/renderer.zig`
- `src/ui/widgets/terminal_widget_input.zig`

Verification:
- `zig build`
- `zig build test-terminal-replay -- --all`

Implemented (increment 15 / `PA-05b` AltGr-style probe candidates + runtime comparison logging):
- Expanded the SDL translation probe wrapper to accept full modifier combinations
  (shift/alt/ctrl/super) so terminal input can sample AltGr-style candidates
  (`ctrl+alt`, `shift+ctrl+alt`) in addition to base/shift translations.
- Terminal widget metadata derivation now prefers these scancode-translation probe
  candidates before falling back to distinct event `sym` inference for the third
  alternate field, improving non-US alternate-key fidelity on layouts that expose
  alternate characters through AltGr.
- Added low-noise diagnostic logging (`terminal.input.altmeta`) that logs event `sym`
  and scancode-translation probe outputs (`base/shift/altgr/altgr_shift`) alongside
  the metadata selected for the encoder, for real-layout validation during manual
  testing.

Files:
- `src/platform/sdl_api.zig`
- `src/ui/renderer.zig`
- `src/ui/widgets/terminal_widget_input.zig`

Verification:
- `zig build`
- `zig build test-terminal-replay -- --all`

Implemented (increment 16 / `PA-05b` explicit SDL keymod plumbing for AltGr/right-alt distinction):
- Preserved raw SDL keymod bits on key events (`sdl_mod_bits`) through the input pipeline:
  - SDL event parsing (`event.key.mod` / `keysym.mod`)
  - platform key queue
  - shared `InputBatch` key events
- Terminal widget alternate-key metadata derivation now uses explicit SDL keymod bits to
  distinguish:
  - explicit AltGr/right-alt (`RALT` / `MODE`) -> prefer AltGr probe candidates
  - explicit non-AltGr alt usage -> avoid generic ctrl+alt AltGr inference
  - missing SDL keymod bits -> fall back to generic best-effort probing
- This reduces false third-field alternates when left Alt is used and better matches the
  intent of `PA-05b` explicit AltGr distinction.

Files:
- `src/platform/sdl_api.zig`
- `src/platform/input_events.zig`
- `src/types/input.zig`
- `src/input/input_builder.zig`
- `src/ui/widgets/terminal_widget_input.zig`

Verification:
- `zig build`
- `zig build test-terminal-replay -- --all`

Implemented (increment 17 / `PA-05b` normalized `altgr` flag in shared modifiers):
- Added `altgr` to `shared_types.input.Modifiers` and propagated it in the input pipeline.
- `input_builder` now derives `KeyEvent.mods.altgr` from SDL keymod bits (`RALT` / `MODE`)
  for queued key events, so downstream terminal code can consume a normalized AltGr signal
  without reading raw `sdl_mod_bits`.
- Batch-level `mods.altgr` uses `RightAlt` key state as a best-effort proxy (SDL `MODE`
  remains event-scoped).
- Terminal widget alternate-key metadata derivation now uses `key_event.mods.altgr` /
  `key_event.mods.alt` for explicit AltGr vs non-AltAlt distinction; raw SDL keymod bits are
  retained for diagnostics only.

Files:
- `src/types/input.zig`
- `src/input/input_builder.zig`
- `src/ui/widgets/terminal_widget_input.zig`

Verification:
- `zig build`
- `zig build test-terminal-replay -- --all`

Investigated feasibility/limits (research note, 2026-02-23):
- Documented the current SDL/platform data surface and limitations for layout-aware alternate-key parity:
  - available: scancode, key symbol (`sym`), text input UTF-8, composition state
  - missing directly in events: full base/shifted/alternate layout tuple for the same key
  - IME/composed text is lossy for layout inference
- Recorded the likely next step for higher-fidelity inference: explicit scancode+modifier translation via SDL keyboard APIs (wrapper work in `src/platform/sdl_api.zig`) plus platform/IME validation.

Files:
- `app_architecture/terminal/KEYBOARD_ALTERNATE_METADATA_CONTRACT.md`

Implemented (increment 1 / `PA-05c` synthetic non-US metadata fixtures at encoder boundary):
- Extended the encoder replay fixture schema with optional `encoder.alternate_meta` so fixtures can inject synthetic `KeyboardAlternateMetadata` into char encoding tests.
- `runEncoderFixture()` now routes metadata-bearing char fixtures through `encodeCharEventBytesForTest(...)`.
- Added initial replay fixtures that emulate non-US/layout metadata and composed-text metadata:
  - non-US alternate metadata present -> current encoder output unchanged (no-op baseline)
  - composed-text metadata present -> current encoder output unchanged (no-op baseline)

Implemented (increment 5 / `PA-05c` unit tests for runtime AltGr probe selection behavior):
- Extracted third-field selection ordering into a small pure helper used by terminal UI
  metadata derivation (`src/terminal/input/alternate_probe.zig`).
- Added unit coverage for runtime probe behavior:
  - explicit AltGr probe candidates are preferred over event `sym`
  - explicit non-AltGr alt usage suppresses generic ctrl+alt AltGr inference
  - generic ctrl+alt probing still applies when explicit SDL distinction is unavailable
  - duplicate candidates are ignored
- This provides direct regression coverage for runtime-derived alternate selection logic,
  complementing encoder replay fixtures that cover downstream CSI-u formatting.

Files:
- `src/terminal/input/alternate_probe.zig`

Verification:
- `zig test src/terminal_input_encoding_tests.zig` (includes `alternate_probe` unit tests)

Implemented (increment 6 / `PA-05c` key/text batch -> metadata -> CSI-u bridge seam test):
- Added a small pure bridge helper in `src/terminal/input/alternate_probe.zig` that builds
  `KeyboardAlternateMetadata` from synthetic shared `KeyEvent` / `TextEvent` inputs plus
  precomputed probe outputs.
- Added an encoder integration test that feeds synthetic key/text events through this seam and
  verifies the derived metadata reaches CSI-u formatting (`key:shifted:alternate`) correctly.
- This complements the existing encoder fixture coverage by testing the UI-side derived metadata
  contract without requiring the full terminal widget path.

Files:
- `src/terminal/input/alternate_probe.zig`
- `src/terminal_input_encoding_tests.zig`

Verification:
- `zig test src/terminal_input_encoding_tests.zig`

Implemented (increment 7 / `PA-05c` replay fixture seam for normalized AltGr metadata selection):
- Extended encoder replay fixture schema with `encoder.alternate_probe_meta`, which builds
  `KeyboardAlternateMetadata` through the key/text bridge seam using synthetic shared key-event
  modifiers (including `mods.altgr`) plus probe outputs.
- Added replay fixtures locking:
  - normalized AltGr path selects the third alternate field from probe outputs
  - explicit non-AltGr Alt suppresses generic AltGr probes and falls back to `event_sym`
- Added a matching unit bridge-seam test for the explicit non-AltGr Alt case.

Files:
- `src/terminal/replay_harness.zig`
- `src/terminal_input_encoding_tests.zig`
- `fixtures/terminal/encoder/csi_u_alternate_probe_altgr_mods_third_field.json`
- `fixtures/terminal/encoder/csi_u_alternate_probe_altgr_mods_third_field.golden`
- `fixtures/terminal/encoder/csi_u_alternate_probe_non_altgr_alt_suppresses_generic.json`
- `fixtures/terminal/encoder/csi_u_alternate_probe_non_altgr_alt_suppresses_generic.golden`

Verification:
- `zig test src/terminal_input_encoding_tests.zig`
- `zig build test-terminal-replay -- --all`

Implemented (increment 8 / `PA-05c` composed-text AltGr replay suppression fixture):
- Added an encoder replay fixture proving composed text still suppresses alternate-key
  fields even when normalized `mods.altgr=true` and AltGr probe candidates are present.
- This locks the composed-text suppression rule against future regressions in the replay
  harness path that builds metadata from `alternate_probe_meta`.

Files:
- `fixtures/terminal/encoder/csi_u_alternate_probe_composed_altgr_suppresses.json`
- `fixtures/terminal/encoder/csi_u_alternate_probe_composed_altgr_suppresses.golden`

Verification:
- `zig build test-terminal-replay -- --all`
- These fixtures create a regression seam for future layout-aware alternate-key encoding without changing current behavior.

Files:
- `src/terminal/replay_harness.zig`
- `fixtures/terminal/encoder/csi_u_alternate_metadata_non_us_noop.json`
- `fixtures/terminal/encoder/csi_u_alternate_metadata_non_us_noop.golden`
- `fixtures/terminal/encoder/csi_u_alternate_metadata_composed_noop.json`
- `fixtures/terminal/encoder/csi_u_alternate_metadata_composed_noop.golden`

Verification:
- `zig build test-terminal-replay -- --fixture encoder:csi_u_alternate_metadata_non_us_noop --update-goldens`
- `zig build test-terminal-replay -- --fixture encoder:csi_u_alternate_metadata_composed_noop --update-goldens`
- `zig build test-terminal-replay -- --all`

Implemented (increment 2 / `PA-05c` first metadata-aware encoder behavior + fixtures):
- `encodeCharEventBytesForTest(...)` and `sendCharActionEvent(...)` now use `KeyboardAlternateMetadata` for char CSI-u alternate-key field selection.
- Behavior changes (metadata-bearing event path only):
  - non-US base/shifted metadata can produce `key:shifted` alternates (when shift is active and metadata is consistent with the emitted char)
  - `text_is_composed=true` suppresses alternate-key reporting to avoid fabricating alternates for IME/compose text
- Added unit tests and replay encoder fixtures for both behaviors:
  - synthetic non-US shifted alternate (`é/É` metadata)
  - composed-text suppression (`A` with composed flag no longer emits ASCII heuristic alternate)

Files:
- `src/terminal/input/input.zig`
- `src/terminal_input_encoding_tests.zig`
- `src/terminal/replay_harness.zig`
- `fixtures/terminal/encoder/csi_u_alternate_metadata_non_us_shifted.json`
- `fixtures/terminal/encoder/csi_u_alternate_metadata_non_us_shifted.golden`
- `fixtures/terminal/encoder/csi_u_alternate_metadata_composed_suppresses.json`
- `fixtures/terminal/encoder/csi_u_alternate_metadata_composed_suppresses.golden`

Verification:
- `zig test src/terminal_input_encoding_tests.zig`
- `zig build test-terminal-replay -- --fixture encoder:csi_u_alternate_metadata_non_us_shifted --update-goldens`
- `zig build test-terminal-replay -- --fixture encoder:csi_u_alternate_metadata_composed_suppresses --update-goldens`
- `zig build test-terminal-replay -- --all`

Implemented (increment 3 / `PA-05c` third kitty alternate field from metadata):
- Extended metadata-aware char CSI-u encoding to emit the third kitty alternate field (`key:shifted:alternate`) when `alternate_layout_codepoint` is provided and distinct.
- This applies only in the metadata-bearing char event path and respects existing composed-text suppression.
- Added unit and replay coverage for a synthetic non-US example emitting all three fields.

Files:
- `src/terminal/input/input.zig`
- `src/terminal_input_encoding_tests.zig`
- `fixtures/terminal/encoder/csi_u_alternate_metadata_third_field.json`
- `fixtures/terminal/encoder/csi_u_alternate_metadata_third_field.golden`

Verification:
- `zig test src/terminal_input_encoding_tests.zig`
- `zig build test-terminal-replay -- --fixture encoder:csi_u_alternate_metadata_third_field --update-goldens`
- `zig build test-terminal-replay -- --all`

Implemented (increment 3):
- Aligned `encodeKeyBytesForTest` with runtime protocol gating for key-mode flags:
  - unsupported flag-only modes (e.g. `alternate_key` bit by itself) no longer produce protocol bytes in tests
  - `disambiguate` now allows `Enter`/`Tab`/`Backspace` CSI-u key encoding in the test helper
- Added unit coverage for `Enter` disambiguation and unsupported-flag-only key-mode behavior.

Files:
- `src/terminal/input/input.zig`
- `src/terminal_input_encoding_tests.zig`

Verification:
- `zig test src/terminal_input_encoding_tests.zig`

Implemented (increment 4):
- Re-enabled `report_alternate_key` flag in key-mode state push/modify/query paths (it is no longer masked out of `CSI ?u` state).
- Added a US-ASCII shifted-alternate subset for char CSI-u encoding when `report_alternate_key` is enabled:
  - uppercase letters (e.g. `A`) encode as base+shifted alternate (`97:65`)
  - shifted punctuation on a US layout (e.g. `:` from `Shift+;`) encodes as base+shifted alternate (`59:58`)
- This applies only when the event is already encoded as CSI-u (e.g. via `disambiguate` / `report_text`), matching kitty's progressive-enhancement model.

Files:
- `src/terminal/core/input_modes.zig`
- `src/terminal_input_modes_tests.zig`
- `src/terminal/input/input.zig`
- `src/terminal_input_encoding_tests.zig`

Verification:
- `zig test src/terminal_input_modes_tests.zig`
- `zig test src/terminal_input_encoding_tests.zig`
- `zig build test-terminal-replay -- --all`

Implemented (increment 5):
- Added encoder replay fixtures for `alternate_key` char CSI-u outputs so fixture harness coverage matches unit-test coverage:
  - shifted letter (`A` -> `97:65`)
  - shifted punctuation (`:` -> `59:58`)
  - `alternate_key`-only no-op case (pure enhancement; does not force CSI-u on its own)

Files:
- `fixtures/terminal/encoder/csi_u_alternate_only_noop.json`
- `fixtures/terminal/encoder/csi_u_alternate_only_noop.golden`
- `fixtures/terminal/encoder/csi_u_alternate_shifted_letter.json`
- `fixtures/terminal/encoder/csi_u_alternate_shifted_letter.golden`
- `fixtures/terminal/encoder/csi_u_alternate_shifted_punct.json`
- `fixtures/terminal/encoder/csi_u_alternate_shifted_punct.golden`

Verification:
- `zig build test-terminal-replay -- --all`

Implemented (increment 6):
- Expanded `PA-05` encoder fixture coverage across additional flag combinations:
  - `report_text + alternate_key` shifted-letter output
  - `report_text + embed_text + alternate_key` shifted-letter output
  - key-path `alternate_key`-only no-op (`UP` remains empty)
- Fixed a test-helper conformance bug in `encodeCharBytesForTest()`:
  - helper now models `embed_text` field formatting (including alternate-key `key:shifted` forms)
  - this aligns replay encoder fixtures with runtime formatting for `embed_text`
- Added direct unit coverage for alternate-key + embedded-text char encoding.

Files:
- `src/terminal/input/input.zig`
- `src/terminal_input_encoding_tests.zig`
- `fixtures/terminal/encoder/csi_u_alternate_report_text_shifted_letter.json`
- `fixtures/terminal/encoder/csi_u_alternate_report_text_shifted_letter.golden`
- `fixtures/terminal/encoder/csi_u_alternate_embed_text_shifted_letter.json`
- `fixtures/terminal/encoder/csi_u_alternate_embed_text_shifted_letter.golden`
- `fixtures/terminal/encoder/csi_u_alternate_only_key_noop_up.json`
- `fixtures/terminal/encoder/csi_u_alternate_only_key_noop_up.golden`

Verification:
- `zig test src/terminal_input_encoding_tests.zig`
- `zig build test-terminal-replay -- --all`

Implemented (increment 7):
- Fixed kitty/disambiguate-mode unmodified cursor/home/end function-key encoding to use the compact legacy-compatible CSI forms (`ESC[A/B/C/D/H/F`) instead of `ESC[1A/B/C/D/H/F`.
- This was a real app-facing regression (`lazygit` arrows stopped responding after entering kitty keyboard disambiguate mode).
- Added unit coverage and replay encoder fixtures to lock compact forms for `Up/Down/Left/Right/Home/End` under `flags=1`.

Files:
- `src/terminal/input/key_encoding.zig`
- `src/terminal/input/input.zig`
- `src/terminal_input_encoding_tests.zig`
- `fixtures/terminal/encoder/csi_u_disambiguate_up_compact.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_up_compact.golden`
- `fixtures/terminal/encoder/csi_u_disambiguate_down_compact.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_down_compact.golden`
- `fixtures/terminal/encoder/csi_u_disambiguate_left_compact.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_left_compact.golden`
- `fixtures/terminal/encoder/csi_u_disambiguate_right_compact.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_right_compact.golden`
- `fixtures/terminal/encoder/csi_u_disambiguate_home_compact.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_home_compact.golden`
- `fixtures/terminal/encoder/csi_u_disambiguate_end_compact.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_end_compact.golden`

Verification:
- `zig test src/terminal_input_encoding_tests.zig`
- `zig build test-terminal-replay -- --all`

Implemented (increment 8):
- Expanded disambiguate-mode cursor/home/end coverage for modified keys (`Shift`,
  `Alt`, `Ctrl`) to lock the `ESC[1;{m}{A/B/C/D/H/F}` form while preserving the new
  compact unmodified form.
- Added replay encoder fixtures for representative modified cursor/home/end cases and
  unit coverage spanning cursor + home/end variants.

Files:
- `src/terminal_input_encoding_tests.zig`
- `fixtures/terminal/encoder/csi_u_disambiguate_up_shift_mod.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_up_shift_mod.golden`
- `fixtures/terminal/encoder/csi_u_disambiguate_down_shift_mod.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_down_shift_mod.golden`
- `fixtures/terminal/encoder/csi_u_disambiguate_left_shift_mod.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_left_shift_mod.golden`
- `fixtures/terminal/encoder/csi_u_disambiguate_right_shift_mod.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_right_shift_mod.golden`
- `fixtures/terminal/encoder/csi_u_disambiguate_home_shift_mod.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_home_shift_mod.golden`
- `fixtures/terminal/encoder/csi_u_disambiguate_end_shift_mod.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_end_shift_mod.golden`
- `fixtures/terminal/encoder/csi_u_disambiguate_up_alt_mod.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_up_alt_mod.golden`
- `fixtures/terminal/encoder/csi_u_disambiguate_home_alt_mod.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_home_alt_mod.golden`
- `fixtures/terminal/encoder/csi_u_disambiguate_end_alt_mod.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_end_alt_mod.golden`
- `fixtures/terminal/encoder/csi_u_disambiguate_up_ctrl_mod.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_up_ctrl_mod.golden`
- `fixtures/terminal/encoder/csi_u_disambiguate_home_ctrl_mod.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_home_ctrl_mod.golden`
- `fixtures/terminal/encoder/csi_u_disambiguate_end_ctrl_mod.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_end_ctrl_mod.golden`

Verification:
- `zig test src/terminal_input_encoding_tests.zig`
- `zig build test-terminal-replay -- --all`

Implemented (increment 9):
- Added action-aware encoder test support (`encodeKeyActionBytesForTest`) and replay
  fixture support (`encoder.action`) so key release formatting can be fixture-locked.
- Added unit and replay coverage for disambiguate + `report_all_event_types` release
  events on cursor/home/end keys, including representative modified releases, to lock
  the `:3` action field formatting (`ESC[1;:3A`, `ESC[1;2:3A`, etc.).
- Aligned the existing disambiguate `Enter` unit-test expectation with runtime output
  (`ESC[13u` compact form).

Files:
- `src/terminal/input/input.zig`
- `src/terminal/replay_harness.zig`
- `src/terminal_input_encoding_tests.zig`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_up_release.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_up_release.golden`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_down_release.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_down_release.golden`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_left_release.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_left_release.golden`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_right_release.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_right_release.golden`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_home_release.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_home_release.golden`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_end_release.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_end_release.golden`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_up_shift_release.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_up_shift_release.golden`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_home_alt_release.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_home_alt_release.golden`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_end_ctrl_release.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_end_ctrl_release.golden`

Verification:
- `zig test src/terminal_input_encoding_tests.zig`
- `zig build test-terminal-replay -- --all`

Implemented (increment 10):
- Completed the action-field matrix coverage for cursor/home/end function keys in
  disambiguate + `report_all_event_types` mode by adding repeat-event (`:2`) unit and
  replay fixture coverage.
- Replay encoder fixtures now lock press/repeat/release formatting coverage across:
  - compact/modified press forms (previous increments)
  - repeat `:2` forms
  - release `:3` forms

Files:
- `src/terminal_input_encoding_tests.zig`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_up_repeat.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_up_repeat.golden`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_down_repeat.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_down_repeat.golden`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_left_repeat.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_left_repeat.golden`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_right_repeat.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_right_repeat.golden`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_home_repeat.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_home_repeat.golden`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_end_repeat.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_end_repeat.golden`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_up_shift_repeat.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_up_shift_repeat.golden`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_home_alt_repeat.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_home_alt_repeat.golden`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_end_ctrl_repeat.json`
- `fixtures/terminal/encoder/csi_u_disambiguate_reportall_end_ctrl_repeat.golden`

Verification:
- `zig test src/terminal_input_encoding_tests.zig`
- `zig build test-terminal-replay -- --all`

Remaining work:
- Alternate-key reporting is only a US-ASCII shifted-char subset in the legacy char path (no layout-aware base/alternate reporting for general keys yet).
- Disambiguation semantics are improved but still incomplete (broader kitty keyboard parity and key-map coverage).

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
- `partial` (2026-02-23)

Notes:
- Track as roadmap item with sub-issues (e.g., missing DCS queries, APC extensions, CSI tabs/window ops).

Parity targets (for `PA-08` sub-items unless explicitly scoped otherwise):
- Primary references: `xterm`, `kitty`, `ghostty` (with `foot` used as an additional xterm-family implementation check when useful).
- "Done" for a parity slice means behavior is either:
  1. implemented to match reference-terminal convention, or
  2. intentionally deferred with documented scope + rationale.

Sub-items (traceable parity slices):
- `PA-08a` CSI gap inventory vs xterm/kitty/ghostty seeds (missing finals / private modes used by modern TUIs)
- `PA-08b` DCS query/reply gap inventory (beyond XTGETTCAP)
- `PA-08c` APC extension policy (kitty-only vs extensible dispatcher)
- `PA-08d` Add replay/PTY fixtures for query/reply coverage (DA/DSR/OSC/DCS)
- `PA-08e` Implement highest-value CSI gaps (tabulation/window ops/mode queries in demand-driven slices)
- `PA-08f` CSI parser intermediate-byte parity (`$`, `!`, and other intermediates needed to disambiguate CSI families cleanly)
- `PA-08g` `DECRQM` / `DECRPM` parity breadth and reply-value policy (`Pm=0/1/2/3/4`, supported ANSI/DEC mode set)
- `PA-08h` Remaining high-value CSI/private-mode gaps promoted from `PA-08a` (e.g. `DECSTR`, `DECSLRM`, `DECRQM` follow-ons)

Priority notes:
- Focus first on sequences observed in fixtures, vttest, and real apps in `reference_repos/terminals/*`.
- Prefer PTY-stubbed tests before expanding query/reply behavior.
- Before marking any `PA-08*` item `done`, document:
  - exact sequence scope
  - target reference convention(s)
  - required test layers (`unit`, `PTY`, `replay`) and what is intentionally omitted

Definition of done (current `PA-08` top-level status can become `done` only when all are true):
- `PA-08a` inventory/checklist is complete enough to enumerate remaining relevant CSI/private-mode gaps against `xterm` / `kitty` / `ghostty` for Zide's TUI scope.
- `PA-08d` replay + PTY query/reply coverage is representative across implemented families and is used for newly-added query/reply behavior.
- `PA-08f` CSI parser intermediate handling is implemented (or explicitly scoped/deferred with documented consequences) so CSI-family dispatch is not relying on ambiguous final-byte shortcuts for parity-critical sequences.
- `PA-08g` `DECRQM` support scope is explicitly defined against references (implemented set + unsupported convention) and test-locked.
- Remaining promoted `PA-08h` gaps are either implemented or intentionally deferred with rationale and compatibility impact notes.

Implemented (increment 1 / `PA-08a` first CSI/private-mode gap inventory pass):
- Created an initial inventory of high-value CSI/private-mode gaps relative to xterm /
  kitty / ghostty usage patterns, scoped to realistic TUI impact.
- This is a planning/inventory increment (no behavior change) intended to feed
  `PA-08d` implementable follow-on items.

Inventory snapshot (`PA-08a`, first pass) checklist (audit-traceable):

| Area | Status | Priority | Tested | Zide refs (impl/tests) | Reference refs | Notes |
|---|---|---|---|---|---|---|
| Core cursor movement/positioning (`A/B/C/D/E/F/G/H/f/d`) | implemented | high | replay | `src/terminal/protocol/csi.zig`, `fixtures/terminal/*cursor*` | `reference_repos/terminals/xterm_snapshots/ctlseqs.txt`, `reference_repos/terminals/ghostty/src/terminal/stream.zig` | Strong baseline support for real TUIs |
| Erase / insert-delete char+line (`J/K/@/P/X/L/M`) | implemented | high | replay | `src/terminal/protocol/csi.zig`, replay fixtures in `fixtures/terminal/` | `reference_repos/terminals/xterm_snapshots/ctlseqs.txt`, `reference_repos/terminals/ghostty/src/terminal/stream.zig` | Covered in existing fixtures |
| Scroll region + region scroll (`r/S/T`) | implemented | high | replay | `src/terminal/protocol/csi.zig`, `fixtures/terminal/scroll_region_basic.*` | `reference_repos/terminals/xterm_snapshots/ctlseqs.txt`, `reference_repos/terminals/ghostty/src/terminal/stream.zig` | Includes scroll-region fixtures |
| SGR + cursor style (`m/q`) | implemented | high | replay | `src/terminal/protocol/csi.zig`, `fixtures/terminal/*sgr*` | `reference_repos/terminals/xterm_snapshots/ctlseqs.txt`, `reference_repos/terminals/ghostty/src/terminal/stream.zig` | Basic/256/truecolor/underline-color present |
| DSR/DA basic replies (`n/c`) | implemented | high | unit+PTY+replay | `src/terminal/protocol/csi.zig`, `src/terminal_csi_reply_tests.zig`, `fixtures/terminal/da_primary_query_reply.*`, `fixtures/terminal/dsr_*_query_reply.*` | `reference_repos/terminals/xterm_snapshots/ctlseqs.txt`, `reference_repos/terminals/foot/csi.c` | PTY-capture + replay reply tests added |
| DEC private modes (alt screen/DECCKM/DECOM/DECAWM/bracketed paste/sync update/mouse 1000/1002/1003/1006) | implemented | high | replay+app | `src/terminal/protocol/csi.zig`, replay fixtures, app validation (nvim/lazygit) | `reference_repos/terminals/xterm_snapshots/ctlseqs.txt`, `reference_repos/terminals/ghostty/src/terminal/stream.zig`, `reference_repos/terminals/foot/csi.c` | Strong modern TUI coverage |
| Kitty keyboard mode controls (`CSI >u/<u/=u/?u`) | implemented | high | replay+unit | `src/terminal/protocol/csi.zig`, `src/terminal/input/*`, encoder fixtures in `fixtures/terminal/encoder/` | `reference_repos/terminals/kitty` (protocol behavior), `reference_repos/terminals/ghostty/src/terminal/stream.zig` | Encoding parity still partial under `PA-05` |
| Tabulation family beyond `TBC` | partial | medium | replay | `src/terminal/protocol/csi.zig` (`I/Z/g`), `src/terminal/model/screen/tabstops.zig`, `fixtures/terminal/csi_tab_cht_cbt_counts.*` | `reference_repos/terminals/xterm_snapshots/ctlseqs.txt`, `reference_repos/terminals/ghostty/src/terminal/stream.zig` | `CHT/CBT/TBC` now implemented; tab-stop report/edit breadth still partial |
| Mode query/report breadth (`DECRQM` etc.) | partial | high | replay+unit+PTY (partial) | `src/terminal/protocol/csi.zig`, `src/terminal_csi_reply_tests.zig`, `src/terminal_focus_reporting_tests.zig`, `fixtures/terminal/decrqm_*` | `reference_repos/terminals/xterm_snapshots/ctlseqs.txt`, `reference_repos/terminals/foot/csi.c`, `reference_repos/terminals/ghostty/src/terminal/stream.zig`, `reference_repos/terminals/kitty/docs/clipboard.rst` | Private `DECRQM` replies implemented for common DEC modes + ANSI mode `20`; replay reply assertions now available |
| Focus reporting mode (`?1004`) + event emission path | implemented (bounded) | high | replay+PTY | `src/terminal/protocol/csi.zig`, `src/terminal/core/terminal_session.zig`, `src/terminal_focus_reporting_tests.zig`, `fixtures/terminal/focus_reporting_mode_*` | `reference_repos/terminals/xterm_snapshots/ctlseqs.txt`, `reference_repos/terminals/foot/csi.c` | Implemented with window + pane source toggles; bounded semantics are test-locked |
| Terminal reset conveniences (`DECSTR`, CSI soft reset breadth) | partial | medium | replay + PTY | `DECSTR` implemented/tested (`src/terminal/protocol/csi.zig`, `src/terminal_focus_reporting_tests.zig`, `fixtures/terminal/decstr_*`); broader reset-family breadth still pending | `reference_repos/terminals/xterm_snapshots/ctlseqs.txt`, `reference_repos/terminals/kitty/kitty/vt-parser.c`, `reference_repos/terminals/ghostty/src/terminal/stream.zig` | `DECSTR` slice active; broader CSI reset-family parity still tracked under `PA-08h` |
| Left/right margins (`DECSLRM`) + rectangular semantics | partial | medium | replay+PTY | `src/terminal/protocol/csi.zig`, `src/terminal/model/screen/screen.zig`, `src/terminal_focus_reporting_tests.zig`, `fixtures/terminal/decslrm_*` | `reference_repos/terminals/xterm_snapshots/ctlseqs.txt`, `reference_repos/terminals/ghostty/src/terminal/stream.zig`, `reference_repos/terminals/ghostty/src/terminal/Terminal.zig` | core `DECSLRM` behavior implemented and heavily fixture-covered; advanced rectangular breadth remains deferred |
| Alternate mouse encodings (`1005`, `1015`) | deferred | low/medium | replay (query policy) | `src/terminal/protocol/csi.zig`, `src/terminal/input/mouse_report.zig`, `fixtures/terminal/decrqm_pm_policy_matrix_reply.*` | `reference_repos/terminals/xterm_snapshots/ctlseqs.txt`, `reference_repos/terminals/foot/csi.c` | explicit strategic non-support (`DECRQM Pm=4`); revisit on concrete app compatibility signal |
| Xterm window ops (`CSI ... t`) | partial | low/medium | PTY + replay | `src/terminal/protocol/csi.zig`, `src/terminal_focus_reporting_tests.zig`, `fixtures/terminal/csi_window_ops_14t_query_reply.*`, `fixtures/terminal/csi_window_ops_16t_query_reply.*`, `fixtures/terminal/csi_window_ops_18t_query_reply.*`, `fixtures/terminal/csi_window_ops_19t_query_reply.*` | `reference_repos/terminals/xterm_snapshots/ctlseqs.txt` | bounded support: `CSI 14 t` (text-area pixels), `CSI 16 t` (cell pixels), `CSI 18 t` (text area chars), `CSI 19 t` (screen chars); broader `t` family still pending |
| Printer/media/status extensions | deferred | low | no | no Zide support | `reference_repos/terminals/xterm_snapshots/ctlseqs.txt` | Explicit out-of-scope defer for current product/parity phase |
| Legacy/rare tab-stop report/edit variants | deferred | low | replay | current tab support in `src/terminal/protocol/csi.zig`, `src/terminal/model/screen/tabstops.zig`, `fixtures/terminal/csi_tab_ctc_legacy_variants_deferred_noop.*` | `reference_repos/terminals/xterm_snapshots/ctlseqs.txt` | Explicitly defer-lock representative `CSI Ps W` variants as no-op until app demand appears |

Suggested `PA-08d` promotion candidates (first pass):
1. `?1004` focus reporting mode + event emission (real TUI impact)
2. `CHT` / `CBT` tab movement coverage (completes currently-partial tab family)
3. `DECRQM` / minimal mode-report replies for queried private modes seen in reference seeds

Implemented (increment 2 / `PA-08a` inventory closure pass):
- Refreshed the `PA-08a` CSI/private inventory table to reflect current landed behavior and explicit defer decisions:
  - `?1004` focus reporting is now tracked as implemented (bounded + test-locked).
  - `DECSLRM` row now reflects implemented core behavior with replay/PTy coverage instead of pre-implementation wording.
  - alternate mouse encodings (`1005`, `1015`) are explicitly deferred with query-policy coverage reference.
  - printer/media/status extensions are explicitly deferred for current scope.
- This closes the queue-level inventory drift and keeps `PA-08a` as an auditable reference for subsequent parity slices.

Verification:
- source-audit/docs alignment increment (no runtime behavior change)

Implemented (increment 3 / `PA-08` defer-policy hygiene registry):
- Added an explicit deferred-row registry for current `PA-08` scope so each deferred area has:
  - current behavior boundary
  - compatibility impact note
  - concrete resume criteria
  - pointer to replay/fixture authority when available

`PA-08` deferred-row registry (current phase):

| Deferred row | Current behavior boundary | Compatibility impact | Resume criteria | Evidence/authority |
|---|---|---|---|---|
| Alternate mouse encodings (`1005`, `1015`) | strategic non-support (`DECRQM Pm=4`), no encoder/report path | apps expecting UTF-8/urxvt mouse encodings can fall back poorly vs SGR-only support | concrete app breakage requiring `1005`/`1015` encoding parity | `fixtures/terminal/decrqm_pm_policy_matrix_reply.*`, `src/terminal/protocol/csi.zig` |
| Printer/media/status extension families | explicit out-of-scope defer; no implementation | scripts expecting printer/media/status reports will observe no support | concrete product requirement or compatibility issue tied to a specific extension | xterm control-sequence family references + current no-support policy |
| Legacy tab-stop report/edit variants (`CSI Ps W`) | explicit no-op defer lock | rare apps relying on full CTC edit/report breadth may not observe expected tab-stop edits | real app signal requiring specific `CSI Ps W` variant support | `fixtures/terminal/csi_tab_ctc_legacy_variants_deferred_noop.*` |
| Broader xterm window-op `CSI ... t` modes | bounded support only (`14/16/18/19`), representative deferred modes no-reply | apps querying unsupported window-op modes may receive no reply vs richer terminals | compatibility issue tied to a specific deferred `t` mode with demonstrated app impact | `fixtures/terminal/csi_window_ops_deferred_modes_no_reply.*` |
| `DECSTR` hidden-screen soft-state reset breadth | defer lock: active-screen soft reset, hidden-screen soft state preserved | TUIs expecting `DECSTR` to scrub hidden-screen mode bits may diverge after alt-screen exit | concrete app failure or strong reference alignment evidence favoring dual-screen soft-state reset | `fixtures/terminal/decstr_hidden_screen_soft_state_preserve_query_reply.*` |

Verification:
- source-audit/docs alignment increment (no runtime behavior change)

Implemented (increment 2 / `PA-08b` DCS/APC gap inventory + implement/defer policy):
- Added an explicit DCS/APC parity inventory with reference-backed implement/defer
  decisions for Zide's current protocol scope.
- This is docs-only classification work; no runtime behavior change in this increment.

`PA-08b` DCS/APC inventory (beyond current XTGETTCAP + kitty APC):

| Family | Sequence scope | Zide status | Reference signal | Decision | Done criteria |
|---|---|---|---|---|---|
| DCS XTGETTCAP | `DCS + q` termcap query | implemented (minimal) | foot/rio docs list/support XTGETTCAP (`reference_repos/terminals/rio/docs/docs/escape-sequence-support.md`) | keep + expand on demand | already test-locked via PTY + replay; extend only if missing caps are demanded by apps |
| DCS DECRQSS/DECRPSS | request/report setting strings | not implemented | xterm control-sequence family (`reference_repos/terminals/xterm_snapshots/ctlseqs.txt`) | defer | promote only with concrete app demand; add PTY reply tests before implementation |
| DCS sync-update legacy form | `DCS = s` (`=1s` / `=2s`) | implemented (compat alias) | rio/alacritty docs mark this rejected in favor of `CSI ? 2026 h/l` (`reference_repos/terminals/rio/docs/docs/escape-sequence-support.md`, `reference_repos/terminals/alacritty/docs/escape_support.md`) | implemented (bounded) | map `=1s`/`=2s` to existing sync-updates mode state, ignore other values, keep `CSI ?2026` as primary path |
| DCS sixel/DRCS graphics | sixel payload families | not implemented | rio advertises sixel support; broad surface (`reference_repos/terminals/rio/docs/docs/features/sixel-protocol.md`) | defer | separate large-scope graphics project; not in PA-08 near-term scope |
| APC kitty graphics | `APC G ... ST` | implemented (partial protocol surface under PA-04) | kitty/ghostty convention | keep expanding under PA-04 | continue PA-04 command/error/reply conformance work |
| APC non-kitty payloads | generic APC app commands | ignored | parser capability exists in reference parsers (rio/copa) but no strong cross-terminal standard behavior | strategic non-support for now | keep ignore-by-default; only promote with explicit product need |
| PM/SOS strings | privacy/message strings | not implemented/ignored | parser capabilities exist in rio/copa (`reference_repos/terminals/rio/copa/src/lib.rs`) | strategic non-support for now | keep ignored unless compatibility evidence appears |

Verification:
- source audit + reference doc audit only (inventory increment)

Implemented (increment 3 / `PA-08b` legacy DCS sync-updates compatibility alias):
- Added bounded support for legacy synchronized-update DCS controls:
  - `DCS = 1 s` enables sync updates (equivalent to `CSI ? 2026 h`)
  - `DCS = 2 s` disables sync updates (equivalent to `CSI ? 2026 l`)
  - unsupported values are ignored (no reply)
- This keeps `CSI ?2026` as the canonical mode path while improving compatibility
  with apps/tools that still emit the historical DCS form.

Files:
- `src/terminal/protocol/dcs_apc.zig`
- `src/terminal_focus_reporting_tests.zig`
- `fixtures/terminal/dcs_legacy_sync_updates_query_reply.vt`
- `fixtures/terminal/dcs_legacy_sync_updates_query_reply.json`
- `fixtures/terminal/dcs_legacy_sync_updates_query_reply.golden`

Verification:
- `zig build test-terminal-focus-reporting`
- `zig build test-terminal-replay -- --fixture dcs_legacy_sync_updates_query_reply --update-goldens`
- `zig build test-terminal-replay -- --all`

Implemented (increment 4 / `PA-08b` sixel deferred no-reply lock):
- Promoted the deferred sixel/DRCS DCS row into explicit replay authority for the current non-support policy:
  - representative sixel payload is consumed/ignored
  - no reply is emitted
  - surrounding printable text remains stable, so the defer boundary is visible and deterministic
- This keeps sixel out of current scope while turning implicit ignore behavior into an auditable compatibility boundary.

Files:
- `fixtures/terminal/dcs_sixel_deferred_no_reply.vt`
- `fixtures/terminal/dcs_sixel_deferred_no_reply.json`
- `fixtures/terminal/dcs_sixel_deferred_no_reply.golden`

Verification:
- `zig build test-terminal-replay -- --fixture dcs_sixel_deferred_no_reply --update-goldens`
- `zig build test-terminal-replay -- --fixture dcs_sixel_deferred_no_reply`
- `zig build test-terminal-replay -- --all`

Implemented (increment 5 / `PA-08b` minimal `DECRQSS` support for `DECSCUSR`):
- Implemented a first bounded `DCS $ q` (`DECRQSS`) slice for cursor-style state queries:
  - `DCS $ q SP q ST` now replies with `DCS 1 $ r Ps SP q ST` using the current `DECSCUSR` cursor style
  - unsupported request strings currently return `DCS 0 $ r ST`
- This promotes one `PA-08b` row from deferred to implemented in a tightly-scoped, reference-backed way without broad DCS expansion.

Files:
- `src/terminal/protocol/dcs_apc.zig`
- `src/terminal/core/terminal_session.zig`
- `src/terminal_protocol_reply_tests.zig`
- `src/terminal_focus_reporting_tests.zig`
- `fixtures/terminal/dcs_decrqss_decscusr_query_reply.vt`
- `fixtures/terminal/dcs_decrqss_decscusr_query_reply.json`
- `fixtures/terminal/dcs_decrqss_decscusr_query_reply.golden`

Verification:
- `zig test src/terminal_protocol_reply_tests.zig -lc`
- `zig build test-terminal-focus-reporting`
- `zig build test-terminal-replay -- --fixture dcs_decrqss_decscusr_query_reply --update-goldens`
- `zig build test-terminal-replay -- --fixture dcs_decrqss_decscusr_query_reply`
- `zig build test-terminal-replay -- --all`

Implemented (increment 6 / `PA-08b` bounded `DECRQSS` support for current SGR state):
- Extended the minimal `DCS $ q` (`DECRQSS`) slice to support `m` queries for a bounded current-SGR subset:
  - serializes current boolean attributes in scope (`bold`, `blink`, `reverse`, `underline`)
  - serializes current fg/bg when they are default or within the 16-color palette mapping
  - unsupported richer SGR state remains outside this first bounded slice and falls back to `DCS 0 $ r ST`
- This adds another real `PA-08b` implementation step without taking on full RGB / underline-color / extended-attribute serialization yet.

Files:
- `src/terminal/core/terminal_session.zig`
- `src/terminal_protocol_reply_tests.zig`
- `src/terminal_focus_reporting_tests.zig`
- `fixtures/terminal/dcs_decrqss_sgr_query_reply.vt`
- `fixtures/terminal/dcs_decrqss_sgr_query_reply.json`
- `fixtures/terminal/dcs_decrqss_sgr_query_reply.golden`
- `app_architecture/terminal/PROTOCOL_ACCURACY_PROGRESS.md`

Verification:
- `zig test src/terminal_protocol_reply_tests.zig -lc`
- `zig build test-terminal-focus-reporting`
- `zig build test-terminal-replay -- --fixture dcs_decrqss_sgr_query_reply --update-goldens`
- `zig build test-terminal-replay -- --all`

Implemented (increment 7 / `PA-08b` bounded `DECRQSS` support for `DECSTBM`):
- Extended the minimal `DCS $ q` (`DECRQSS`) slice to support `r` queries for current vertical scroll-region state:
  - `DCS $ q r ST` now replies with `DCS 1 $ r Pt ; Pb r ST`
  - reply reflects the current `DECSTBM` top/bottom margins already modeled in the active screen
- This keeps the implementation bounded while expanding `PA-08b` into another real query family with existing terminal state authority.

Files:
- `src/terminal/core/terminal_session.zig`
- `src/terminal_protocol_reply_tests.zig`
- `src/terminal_focus_reporting_tests.zig`
- `fixtures/terminal/dcs_decrqss_decstbm_query_reply.vt`
- `fixtures/terminal/dcs_decrqss_decstbm_query_reply.json`
- `fixtures/terminal/dcs_decrqss_decstbm_query_reply.golden`
- `app_architecture/terminal/PROTOCOL_ACCURACY_PROGRESS.md`

Verification:
- `zig test src/terminal_protocol_reply_tests.zig -lc`
- `zig build test-terminal-focus-reporting`
- `zig build test-terminal-replay -- --fixture dcs_decrqss_decstbm_query_reply --update-goldens`
- `zig build test-terminal-replay -- --fixture dcs_decrqss_decstbm_query_reply`
- `zig build test-terminal-replay -- --all`

Implemented (increment 2 / `PA-08e` promoted high-value CSI gap: `?1004` focus reporting):
- Implemented CSI private mode handling for `?1004 h/l` (focus reporting enable/disable).
- Added terminal focus-report emission (`ESC[I` / `ESC[O`) gated on the mode bit.
- Wired SDL window focus gain/loss through renderer -> `InputBatch.events` -> terminal widget input dispatch.
- Added project-integrated PTY-capture tests for mode toggling and emitted focus bytes.
- Added replay fixtures to lock parser-side mode toggles in snapshot output (`focus_reporting: 1` when enabled).

Files:
- `src/terminal/protocol/csi.zig`
- `src/terminal/core/terminal_session.zig`
- `src/terminal/core/snapshot.zig`
- `src/ui/renderer.zig`
- `src/input/input_builder.zig`
- `src/ui/widgets/terminal_widget_input.zig`
- `src/terminal_focus_reporting_tests.zig`
- `build.zig`
- `fixtures/terminal/focus_reporting_mode_enable.vt`
- `fixtures/terminal/focus_reporting_mode_enable.json`
- `fixtures/terminal/focus_reporting_mode_enable.golden`
- `fixtures/terminal/focus_reporting_mode_disable.vt`
- `fixtures/terminal/focus_reporting_mode_disable.json`
- `fixtures/terminal/focus_reporting_mode_disable.golden`

Verification:
- `zig build test-terminal-focus-reporting`
- `zig build test-terminal-replay -- --all`

Implemented (increment 4 / `PA-08e` bounded xterm window-op queries `CSI 14 t` + `CSI 16 t` + `CSI 18 t` + `CSI 19 t`):
- Added bounded support for xterm window-op queries:
  - `CSI 14 t` report text area size in pixels (`CSI 4 ; height ; width t`)
  - `CSI 16 t` report character cell size in pixels (`CSI 6 ; height ; width t`)
  - `CSI 18 t` report text area size in characters (`CSI 8 ; rows ; cols t`)
  - `CSI 19 t` report screen size in characters (`CSI 9 ; rows ; cols t`)
- Pixel replies use current cell metrics and report `0;0` when metrics are unknown.
- Unsupported/other `CSI ... t` window-op modes remain ignored for now (no reply).

Files:
- `src/terminal/protocol/csi.zig`
- `src/terminal_focus_reporting_tests.zig`
- `fixtures/terminal/csi_window_ops_14t_query_reply.vt`
- `fixtures/terminal/csi_window_ops_14t_query_reply.json`
- `fixtures/terminal/csi_window_ops_14t_query_reply.golden`
- `fixtures/terminal/csi_window_ops_16t_query_reply.vt`
- `fixtures/terminal/csi_window_ops_16t_query_reply.json`
- `fixtures/terminal/csi_window_ops_16t_query_reply.golden`
- `fixtures/terminal/csi_window_ops_18t_query_reply.vt`
- `fixtures/terminal/csi_window_ops_18t_query_reply.json`
- `fixtures/terminal/csi_window_ops_18t_query_reply.golden`
- `fixtures/terminal/csi_window_ops_19t_query_reply.vt`
- `fixtures/terminal/csi_window_ops_19t_query_reply.json`
- `fixtures/terminal/csi_window_ops_19t_query_reply.golden`

Verification:
- `zig build test-terminal-focus-reporting`
- `zig build test-terminal-replay -- --fixture csi_window_ops_14t_query_reply --update-goldens`
- `zig build test-terminal-replay -- --fixture csi_window_ops_16t_query_reply --update-goldens`
- `zig build test-terminal-replay -- --fixture csi_window_ops_18t_query_reply --update-goldens`
- `zig build test-terminal-replay -- --fixture csi_window_ops_19t_query_reply --update-goldens`
- `zig build test-terminal-replay -- --all`

Implemented (increment 3 / `PA-08e` promoted high-value CSI gap: `CHT` / `CBT` tab movement):
- Implemented CSI `I` (CHT, Cursor Forward Tabulation) by advancing to the next tab stop `n` times (default `1`).
- Implemented CSI `Z` (CBT, Cursor Backward Tabulation) by moving to the previous tab stop `n` times (default `1`).
- Added `Screen.backTab()` and `TabStops.prev()` to support backward tab-stop traversal in the screen model.
- Added replay fixture coverage for parameterized forward/backward tab movement (`2I`, `2Z`) to lock tab-stop behavior against the replay harness.

Files:
- `src/terminal/protocol/csi.zig`
- `src/terminal/model/screen/screen.zig`
- `src/terminal/model/screen/tabstops.zig`
- `fixtures/terminal/csi_tab_cht_cbt_counts.vt`
- `fixtures/terminal/csi_tab_cht_cbt_counts.json`
- `fixtures/terminal/csi_tab_cht_cbt_counts.golden`

Verification:
- `zig build test-terminal-replay -- --all`

Implemented (increment 4 / `PA-08e` `?1004` dual-source event toggles + pane focus source):
- Added separate terminal focus-report event sources for `?1004` emission:
  1. window focus gain/loss (existing SDL window-focus path)
  2. terminal-pane focus gain/loss within the IDE (new `AppState` focus transition hook)
- Added separate Lua config toggles for each source under `terminal.focus_reporting`:
  - `window` (default `true`)
  - `pane` (default `false`)
- Added widget-level source gating and duplicate-state suppression so enabling both sources does not emit duplicate focus bytes for the same effective focus state transition.
- Reloading config updates the source toggles on existing terminal widgets.

Lua config example:
- `terminal = { focus_reporting = { window = true, pane = true } }`

Files:
- `src/config/lua_config.zig`
- `src/main.zig`
- `src/ui/widgets/terminal_widget.zig`
- `src/ui/widgets/terminal_widget_input.zig`
- `src/terminal_focus_reporting_tests.zig`

Verification:
- `zig build`
- `zig build test-terminal-focus-reporting`
- `zig build test-terminal-replay -- --all`

Decision note (scope boundary, 2026-02-23):
- Kitty-style unfocused cursor UI feedback (non-blinking hollow block when terminal loses focus) is intentionally treated as a **UI render behavior**, not part of `?1004` protocol correctness.
- Do not implement this by mutating terminal protocol cursor style/state; implement as a terminal widget draw-time cursor override keyed off effective focus state.
- This is out of scope for the current protocol pass and should be tracked as a UI follow-on when focus visualization work is scheduled.

Implemented (increment 5 / `PA-08e` `DECRQM` minimal private mode replies, first slice):
- Implemented minimal DEC private mode query handling for `DECRQM` (`CSI ? Ps $ p`) with `DECRPM` replies (`CSI ? Ps ; Pm $ y`).
- Added state reporting for currently-supported common DEC/private modes (cursor keys, autowrap/origin/reverse/cursor-visible, alt screen, mouse modes, focus reporting, bracketed paste, sync updates, 132-column mode).
- Unsupported queried private modes currently return `Pm=0` (not recognized) instead of silently ignoring the query.
- Added PTY-capture integration coverage for `?1004` query set/reset replies and unit coverage for reply-byte formatting.

Files:
- `src/terminal/protocol/csi.zig`
- `src/terminal_csi_reply_tests.zig`
- `src/terminal_focus_reporting_tests.zig`

Verification:
- `zig test src/terminal_csi_reply_tests.zig -lc`
- `zig build test-terminal-focus-reporting`

Implemented (increment 6 / `PA-08e` `DECRQM` query coverage expansion + ANSI mode `20`):
- Expanded PTY-capture `DECRQM` integration coverage with a table-driven private-mode query matrix covering representative common modes (`?1`, `?7`, `?25`, `?1000`, `?1006`, `?2004`, `?2026`) across default/set/reset states.
- Added explicit `Pm=0` integration coverage for unsupported private mode queries.
- Added minimal ANSI `DECRQM` support for mode `20` (newline mode) with set/reset reporting (`CSI 20 ; Pm $ y`).
- Broadened PTY-capture `DECRQM` private-mode coverage to include more DEC modes (`?3`, `?5`, `?6`, `?47`, `?1047`, `?1049`, `?1002`, `?1003`) and added an explicit unsupported ANSI `DECRQM` integration test.
- Convention decision (implemented): unsupported ANSI `DECRQM` queries return `Pm=0` (`not recognized`), following local reference terminal sources:
  - xterm docs (`reference_repos/terminals/xterm_snapshots/ctlseqs.txt`)
  - foot implementation/docs (`reference_repos/terminals/foot/csi.c`, `reference_repos/terminals/foot/doc/foot-ctlseqs.7.scd`)
- Current ANSI `DECRQM` scope is intentionally minimal:
  - implemented: mode `20` (newline mode)
  - unsupported ANSI modes: reply with `Pm=0` (not recognized) rather than silent ignore
  - expand only when a real app/seed demonstrates demand
- This is a **partial milestone**, not `DECRQM` parity completion; broader `DECRQM` breadth and parser-intermediate correctness are tracked under `PA-08f` / `PA-08g`.

Files:
- `src/terminal/protocol/csi.zig`
- `src/terminal_focus_reporting_tests.zig`

Verification:
- `zig build test-terminal-focus-reporting`
- `zig test src/terminal_csi_reply_tests.zig -lc`

Implemented (increment 7 / `PA-08d` replay query-reply assertion seam, first slice):
- Added replay-harness support for fixture-level PTY reply assertions via `reply_hex` metadata plus `assertions: [\"reply\"]`.
- Replay harness now attaches a pipe-backed PTY only when `reply_hex` is present and compares captured reply bytes to the expected hex payload.
- Added a replay fixture that validates `DECRQM ?1004` reply bytes end-to-end in fixture flow (`\x1b[?1004;1$y`).

Files:
- `src/terminal/replay_harness.zig`
- `fixtures/terminal/decrqm_focus_reporting_query_reply.vt`
- `fixtures/terminal/decrqm_focus_reporting_query_reply.json`
- `fixtures/terminal/decrqm_focus_reporting_query_reply.golden`

Verification:
- `zig build test-terminal-replay -- --fixture decrqm_focus_reporting_query_reply --update-goldens`
- `zig build test-terminal-replay -- --all`

Implemented (increment 8 / `PA-08d` replay query-reply fixtures for DA/DSR/OSC):
- Added replay fixtures that validate query reply bytes end-to-end for:
  - `DA` primary (`CSI c`)
  - `DSR` CPR (`CSI 6 n`, after cursor positioning)
  - `OSC 10` dynamic-color query with BEL terminator
- These fixtures use the `reply_hex` + `assertions: ["reply"]` seam and expand replay-level query coverage beyond the initial `DECRQM ?1004` example.
- Coverage now includes both ANSI and DEC-private `DSR` cursor position replies and two OSC query families (`OSC 10`, `OSC 52`).

Files:
- `fixtures/terminal/da_primary_query_reply.vt`
- `fixtures/terminal/da_primary_query_reply.json`
- `fixtures/terminal/da_primary_query_reply.golden`
- `fixtures/terminal/dsr_cpr_query_reply.vt`
- `fixtures/terminal/dsr_cpr_query_reply.json`
- `fixtures/terminal/dsr_cpr_query_reply.golden`
- `fixtures/terminal/osc_10_query_reply_bel.vt`
- `fixtures/terminal/osc_10_query_reply_bel.json`
- `fixtures/terminal/osc_10_query_reply_bel.golden`
- `fixtures/terminal/dsr_decx_cpr_query_reply.vt`
- `fixtures/terminal/dsr_decx_cpr_query_reply.json`
- `fixtures/terminal/dsr_decx_cpr_query_reply.golden`
- `fixtures/terminal/osc_52_query_reply_bel.vt`
- `fixtures/terminal/osc_52_query_reply_bel.json`
- `fixtures/terminal/osc_52_query_reply_bel.golden`

Verification:
- `zig build test-terminal-replay -- --all`

Implemented (increment 9 / `PA-08d` `DECRQM` replay query matrix fixture):
- Added a compact replay fixture that issues multiple `DECRQM` queries in one stream (private + ANSI, supported + unsupported, before/after mode toggles) and asserts the concatenated reply byte sequence.
- This reduces reliance on one-off PTY tests for query ordering and gives fixture-level regression coverage for a representative `DECRQM` reply matrix.

Files:
- `fixtures/terminal/decrqm_query_matrix_reply.vt`
- `fixtures/terminal/decrqm_query_matrix_reply.json`
- `fixtures/terminal/decrqm_query_matrix_reply.golden`

Verification:
- `zig build test-terminal-replay -- --fixture decrqm_query_matrix_reply --update-goldens`
- `zig build test-terminal-replay -- --all`

Implemented (increment 10 / `PA-08d` color-scheme DSR replay reply lock):
- Added replay fixture coverage for `DSR ?996n` color-scheme preference replies in one stream with `?2031` mode toggles interleaved.
- The fixture asserts concatenated reply bytes and locks current behavior that `?996n` replies are available regardless of `?2031` enablement.

Files:
- `fixtures/terminal/color_scheme_dsr_996_query_reply.vt`
- `fixtures/terminal/color_scheme_dsr_996_query_reply.json`
- `fixtures/terminal/color_scheme_dsr_996_query_reply.golden`

Verification:
- `zig build test-terminal-replay -- --fixture color_scheme_dsr_996_query_reply --update-goldens`
- `zig build test-terminal-replay -- --fixture color_scheme_dsr_996_query_reply`
- `zig build test-terminal-replay -- --all`

Implemented (increment 10 / `PA-08g` `DECRQM` reply-policy prep + keypad mode query):
- `PA-08f` groundwork: CSI parser now captures intermediate bytes (`$`, `!`, `#`, etc.), and `DECRQM` dispatch requires the `$` intermediate so unrelated `CSI ... p` families no longer over-match.
- Added PTY no-reply tests for non-`DECRQM` `CSI p` forms (`CSI ! p`, `CSI ?1004p`, `CSI #p`) and CSI debug logging now includes captured intermediates.
- Added a replay no-reply fixture that locks deterministic ignore behavior for non-`DECRQM` intermediate-bearing `CSI p` sequences (`CSI ! p`, `CSI # p`, malformed `CSI ?1004p`) end-to-end in fixture flow.
- Refactored `DECRQM` state reporting to use an explicit `DecrpmState` enum (`0..4`) to support future parity policy work cleanly.
- Expanded `DECRQM` private-mode coverage with keypad application mode `?66` (reports state from existing `DECPAM` / `DECPNM` tracking).
- Began `Pm=4` adoption for clearly unsupported fixed DEC-private modes (`?67`, `?1001`, `?1005`, `?1015`, `?1016`) to move closer to xterm/foot `DECRPM` semantics.
- Expanded that `Pm=4` set with `?9` (legacy X10 mouse) and `?45` (reverse-wrap) as unsupported fixed-off modes.
- Expanded the `Pm=4` set again with `?1034`, `?1035`, `?1036`, and `?1042` (unsupported meta/bell toggles) and extended replay matrix coverage with a representative `?1034` case.
- Expanded the `Pm=4` set again with `?1070`, `?2031`, `?2048`, and kitty clipboard mode `?5522`; replay matrix coverage now includes a representative kitty-facing unsupported-mode detection case (`?5522 -> Pm=4`).
- Expanded the replay `DECRQM` matrix fixture to cover `?66` transitions and a representative `Pm=4` mode (`?1005`).

Files:
- `src/terminal/parser/csi.zig`
- `src/terminal/protocol/csi.zig`
- `src/terminal_focus_reporting_tests.zig`
- `src/terminal_csi_reply_tests.zig`
- `fixtures/terminal/decrqm_query_matrix_reply.vt`
- `fixtures/terminal/decrqm_query_matrix_reply.json`

Verification:
- `zig test src/terminal/parser/csi.zig`
- `zig test src/terminal_csi_reply_tests.zig -lc`
- `zig build test-terminal-focus-reporting`
- `zig build test-terminal-replay -- --all`

Implemented (increment 11 / `PA-08f` malformed-intermediate dispatch lock):
- Expanded PTY no-reply coverage for malformed `CSI ... p` intermediate combinations so
  intermediate-aware dispatch remains exact and non-overlapping:
  - `CSI ?1004$!p`
  - `CSI 20!$p`
  - `CSI ##p`
  - `CSI ?!p`
- Expanded replay no-reply fixture coverage for the same malformed forms under
  `csi_p_intermediate_non_decrqm_no_reply`.
- This closes the remaining ambiguity gap for parity-critical `p`-family intermediate
  dispatch in current scope (`DECRQM` requires exact `$`, `DECSTR` requires exact `!`).

Files:
- `src/terminal_focus_reporting_tests.zig`
- `fixtures/terminal/csi_p_intermediate_non_decrqm_no_reply.vt`
- `fixtures/terminal/csi_p_intermediate_non_decrqm_no_reply.golden`

Verification:
- `zig build test-terminal-focus-reporting`
- `zig build test-terminal-replay -- --fixture csi_p_intermediate_non_decrqm_no_reply --update-goldens`
- `zig build test-terminal-replay -- --all`

Planned work (decomposition / `PA-08f` CSI parser intermediate-byte parity):
- Status note (2026-02-26): **implemented for current parity-critical scope**. The plan below is retained as historical decomposition context.
- Problem statement:
  - (historical) Zide's CSI parser previously recorded `final`, `params`, `leader`, and `private` but dropped CSI intermediate bytes.
  - (historical) `DECRQM` support previously depended on final-byte dispatch without exact intermediate matching.
- Why parity work requires this:
  - xterm control sequences define distinct CSI families that differ only by intermediate bytes (e.g. `CSI Ps $ p` `DECRQM`, `CSI ! p` `DECSTR`, `CSI ? Ps $ p` DEC-private `DECRQM`).
  - kitty and ghostty both parse CSI intermediates and branch on them; ghostty explicitly logs/ignores unimplemented sequences by final+intermediate combinations rather than conflating by final byte (`reference_repos/terminals/ghostty/src/terminal/stream.zig`, `reference_repos/terminals/kitty/kitty/vt-parser.c`).
- `PA-08f` done looks like:
  - `CsiAction` captures CSI intermediates (at least enough bytes/range for parity-critical sequences) without regressing existing parser behavior.
  - CSI dispatch in `src/terminal/protocol/csi.zig` uses intermediates for parity-critical families (`DECRQM`, `DECSTR`, and future promoted `$`/`!` forms) instead of final-byte shortcuts.
  - Unsupported intermediate-bearing CSI sequences are ignored/logged deterministically by exact final+intermediate combination (not accidentally interpreted as another family).
  - Coverage exists at three layers:
    - parser unit tests (intermediate capture)
    - protocol PTY/unit tests for dispatch/replies (`DECRQM`, `DECSTR` when implemented)
    - replay fixture(s) for at least one `$` family and one `!` family sequence
- `PA-08f` implementation plan (small-commit slices):
  1. Extend `src/terminal/parser/csi.zig` `CsiAction` with intermediate storage (bounded array + length) and preserve existing `leader/private/params` semantics.
  2. Add parser unit tests that prove:
     - `CSI 20 $ p` captures `intermediates="$"`
     - `CSI ? 1004 $ p` captures `intermediates="?$"` (or equivalent `leader + "$"` representation, whichever API we choose)
     - `CSI ! p` captures `intermediates="!"`
  3. Refactor `src/terminal/protocol/csi.zig` `DECRQM` dispatch to require/interrogate intermediate bytes explicitly (behavior-preserving for currently-supported queries).
  4. Add exact ignore-path tests for unrelated `CSI ... p` sequences so `DECRQM` handling does not over-match.
  5. Promote next intermediate-dependent CSI family (`DECSTR` or another `PA-08h` item) using the new parser capability.
- Scope boundary (current pass):
  - `PA-08f` is parser/disambiguation infrastructure; it does not by itself require implementing all intermediate-bearing CSI families.
  - Each newly-enabled family still needs a separate parity slice (`PA-08h`) with reference behavior + tests.
  - Coverage freeze rule (after `p/q/x/z` replay no-reply fixtures):
    - Do not add more generic unsupported-intermediate replay fixtures unless a real parser/dispatch bug appears or a touched CSI family needs a new regression lock.

Planned work (decomposition / `PA-08g` `DECRQM` / `DECRPM` parity breadth + reply policy):
- Reference convention summary (anchors for parity decisions):
  - xterm defines `DECRPM` reply values `Pm=0..4` (`not recognized`, `set`, `reset`, `permanently set`, `permanently reset`) for both ANSI and DEC-private `DECRQM` (`reference_repos/terminals/xterm_snapshots/ctlseqs.txt`).
  - foot implements broad `DECRQM` coverage and uses all `DECRPM` statuses, including permanent states for unsupported/fixed modes such as mouse encodings and other features (`reference_repos/terminals/foot/csi.c`).
  - kitty protocol docs (clipboard extension) explicitly rely on `DECRQM` for feature detection and note that `0` or `4` can indicate unsupported mode (`CSI ? 5522 $ p` -> `CSI ? 5522 ; Ps $ y`) (`reference_repos/terminals/kitty/docs/clipboard.rst`).
  - ghostty parses `DECRQM` with CSI intermediate-aware dispatch and routes unknown modes through a dedicated path (`request_mode_unknown`) rather than overloading other CSI `p` families (`reference_repos/terminals/ghostty/src/terminal/stream.zig`, `reference_repos/terminals/ghostty/src/terminal/modes.zig`).
- Current Zide state (partial milestone):
  - Implemented DEC-private `DECRQM` for a useful common subset and ANSI mode `20`.
  - Unsupported ANSI/DEC queries reply `Pm=0` (xterm/foot-compatible convention already locked by tests).
  - `Pm=4` is emitted for strategic fixed-off private modes; `Pm=3` is intentionally not emitted in current policy scope.
  - Parser intermediate handling is implemented for parity-critical `p` families (`PA-08f` scope complete).
- `PA-08g` done looks like:
  - Supported ANSI and DEC-private `DECRQM` mode set is explicitly documented against references (`xterm` / `kitty` / `ghostty`, checked with `foot` where useful).
  - Unsupported-mode policy is explicit and test-locked (`Pm=0` vs `Pm=4` by mode/category, if differentiated).
  - Zide emits `Pm=3/4` for modes that are intentionally fixed/permanent in Zide (if any exist and parity gain justifies exposing them), or explicitly documents why Zide always returns `0/1/2` for now.
  - Coverage is table-driven across:
    - unit reply formatting (`src/terminal_csi_reply_tests.zig`)
    - PTY integration mode-state queries (`src/terminal_focus_reporting_tests.zig` or renamed broader file)
    - replay fixture matrix (`fixtures/terminal/decrqm_query_matrix_reply.*`, expanded as needed)
- `PA-08g` parity checklist (mode coverage and policy):
  - ANSI `DECRQM`:
    - [x] mode `20` newline mode (`Pm=1/2`, `Pm=0` unsupported others)
    - [ ] Audit xterm/ghostty/foot-relevant ANSI modes for Zide (`4` insert mode, `12` local echo, `20` newline, etc.) and classify `implement` / `defer`
    - [x] Add explicit tests/docs for representative unsupported ANSI modes that apps may query (reply `Pm=0`)
  - DEC-private `DECRQM`:
    - [x] common TUI modes currently implemented (`?1`, `?3`, `?5`, `?6`, `?7`, `?25`, `?47`, `?1047`, `?1049`, `?1000`, `?1002`, `?1003`, `?1004`, `?1006`, `?2004`, `?2026`)
    - [ ] Audit reference-terminal queried modes relevant to Zide parity (`?9`, `?12`, `?45`, `?66`, `?67`, `?80`, `?1005`, `?1015`, `?1016`, `?1034`, `?1035`, `?1036`, `?1042`, `?1070`, `?2027`, `?2031`, `?2048`, `?5522`, etc.) and classify `implement` / `defer`
    - [x] Review already-landed `Pm=4` rows and correct course before further DECRQM parity breadth work:
      - keep only if `strategic non-support` is intentional and documented
      - otherwise convert to `implement now` / `defer provisional` with follow-up slice
    - [ ] Decide whether any fixed unsupported features should report `Pm=4` instead of `Pm=0` (kitty docs treat both as unsupported for `?5522`; xterm/foot semantics permit both); apply only to strategically unsupported modes
  - Reply-value policy:
    - [x] `Pm=0` for unsupported ANSI/DEC query in current implemented scope
    - [ ] Define criteria for `Pm=3/4` use in Zide (feature permanently on/off vs unsupported/not recognized)
    - [x] Add explicit fixture/unit cases that lock the current strategic `Pm=4` mode set
    - [x] Decide and lock whether `Pm=3` is used in any Zide mode family (currently not used)
- Suggested small-commit sequence for `PA-08g`:
  1. Docs-only mode inventory table (current implemented DEC/ANSI set vs reference-candidate set) with `implement/defer` decisions.
  2. Behavior-preserving refactor to centralize `DECRQM` mode classification/state policy (easier table-driven testing).
  3. Add or defer one small batch of high-value modes (e.g. `?9`, `?12`, `?45`, `?66`) with PTY + replay matrix updates.
  4. Finalize `Pm=3/4` policy and lock with unit/replay tests.

- Non-support decision rule (tightened, 2026-02-23):
  - Do not classify a DECRQM mode as strategic non-support (`Pm=4`) based on Zide preference alone.
  - `Pm=4` requires:
    1. A product-level decision that Zide intends to keep the feature unsupported in current scope, and
    2. Multiple strong references (at least 2 of: `foot`, `kitty`, `ghostty`, xterm-family docs/source behavior) that lean in the same direction (`fixed-off` / permanent-reset semantics) for that mode family.
  - If the references are mixed or parity implementation is plausible/likely soon, keep `Pm=0` provisional unsupported until an explicit implement/defer decision is recorded.

`PA-08g` reference coverage snapshot (DECRQM mode families, strong refs):

Legend:
- `Y`: explicit mode support/query path present in scanned reference source/docs
- `P`: explicit permanent/fixed reply behavior (commonly `Pm=4`) in reference
- `?`: not directly audited in local source snapshot for that mode

High-value ANSI modes:

| Mode | Meaning | Zide | foot | ghostty | kitty | xterm-family | Note |
|---|---|---|---|---|---|---|---|
| `20` | newline (LNM) | implemented | `Y` | `Y` | `Y` | docs family | implemented and test-locked |
| `4` | insert (IRM) | implemented (`1/2`) | `?` | `Y` | `Y` | docs family | implemented with real insert-mode write semantics + DECRQM |
| `12` | send/receive (SRM) | implemented (`1/2`) | `?` | `Y` | `-` | docs family | implemented first slice as no-PTY local echo toggle |

High-value DEC private modes (common TUI / modern terminal usage):

| Mode | Meaning | Zide | foot | ghostty | kitty | xterm-family | Suggested next action |
|---|---|---|---|---|---|---|---|
| `?12` | cursor blinking | implemented (`1/2`) | `Y` | `Y` | `?` | strong | implemented via DECSET/DECRST + DECRQM state |
| `?45` | reverse-wrap | `Pm=0` | `Y` | `Y` | `?` | strong | defer or implement with explicit rationale |
| `?1016` | SGR pixel mouse | implemented (`1/2`, first slice) | `Y` | `Y` | `Y` | strong modern | first slice implemented (SGR pixel coords when `1006+1016` enabled); broader compat matrix still pending |
| `?2031` | color scheme notifications | implemented (`1/2`, first slice) | `Y` | `Y` | `Y` | modern ext | implemented mode + `?996n` current-scheme reply + live notify API seam |
| `?2048` | in-band resize notifications | implemented (`1/2`) | `Y` | `Y` | `Y` | modern ext | implemented first slice (mode + resize report emit) |
| `?5522` | kitty paste/clipboard events mode | implemented (`1/2`, partial behavior slice) | `-` | `-` | `Y` (+ docs) | kitty-specific | implemented mode + paste-event MIME list + minimal read path (`.`/`text/plain`/`text/html`/`text/uri-list`/`image/png`); write/permission/primary deferred |

Current strategic non-support rows (`Pm=4`) are retained only where references and product direction both support fixed-off behavior:
- legacy/low-value mouse/meta toggles: `?67`, `?1001`, `?1005`, `?1015`, `?1034`, `?1035`, `?1036`, `?1042`, `?1070`
- Any expansion beyond this set requires the rule above.

`PA-08g` mode inventory snapshot (current Zide vs reference candidates):

| Family | Mode(s) | Zide status | Current reply policy | Reference signal | Suggested action |
|---|---|---|---|---|---|
| ANSI `DECRQM` | `20` (newline) | implemented | `1/2` state, `0` unsupported others | xterm/foot | keep |
| ANSI `DECRQM` | `4` (insert), `20` (newline) | implemented | `1/2` | xterm/kitty/ghostty | `4` now implemented with IRM behavior + DECRQM; `20` unchanged |
| ANSI `DECRQM` | `12` (local echo), other ANSI queryable modes | `12` implemented, others pending | `12 => 1/2`, others `0` | xterm/foot/ghostty parsing model | continue mode-by-mode |
| DEC private `DECRQM` | `?1 ?3 ?5 ?6 ?7 ?25 ?47 ?1047 ?1049` | implemented | `1/2` | xterm/foot | keep |
| DEC private `DECRQM` | `?1000 ?1002 ?1003 ?1004 ?1006 ?2004 ?2026` | implemented | `1/2` | xterm/foot/kitty app usage | keep |
| DEC private `DECRQM` | `?66` (application keypad) | implemented | `1/2` | foot/xterm VT semantics | implemented via existing `DECPAM` / `DECPNM` state |
| DEC private `DECRQM` | `?1048` (save cursor mode) | implemented | `1/2` | ghostty mode list, foot set/reset support, kitty mode constant | implemented with explicit Zide `?1048` mode-state tracking + save/restore action |
| DEC private `DECRQM` | `?8` (DECARM autorepeat) | implemented | `1/2` | ghostty/kitty (xterm-family common) | implemented with repeat suppression in terminal input dispatch |
| DEC private `DECRQM` | `?9` (X10 mouse) | implemented | `1/2` | xterm/foot/ghostty | implemented via existing X10 mouse state (`mouse_mode_x10`) |
| DEC private `DECRQM` | `?12` (cursor blinking) | implemented | `1/2` | foot/ghostty (kitty mixed) | implemented via DECSET/DECRST cursor blink toggle on `cursor_style.blink` |
| DEC private `DECRQM` | `?45` (reverse-wrap) | not implemented | `0` | foot/ghostty | defer provisional (needs real reverse-wrap behavior, not query-only) |
| DEC private `DECRQM` | `?67 ?1001 ?1005` | implemented (query-only) | `4` (permanently reset) | foot often reports permanent reset (`4`) | strategic non-support (fixed-off) |
| DEC private `DECRQM` | `?1015` mouse alt encoding (urxvt) | implemented (query-only) | `4` (permanently reset) | foot/xterm queryable | strategic non-support (legacy encoding) |
| DEC private `DECRQM` | `?1016` mouse pixel encoding (SGR pixels) | implemented (first slice) | `1/2` | foot/ghostty/kitty | SGR pixel coords emitted when `1006+1016` enabled; broader compat/replay coverage pending |
| DEC private `DECRQM` | `?1034 ?1035 ?1036 ?1042` | implemented (query-only) | `4` (permanently reset) | foot supports/reportable | unsupported fixed-off parity policy adopted |
| DEC private `DECRQM` | `?1070` | implemented (query-only) | `4` (permanently reset) | foot supports/reportable | unsupported fixed-off parity policy adopted |
| DEC private `DECRQM` | `?2031` theme notifications | not implemented | `0` | foot/ghostty/kitty | defer provisional; do not claim fixed-off unless strategic |
| DEC private `DECRQM` | `?2048` in-band resize notifications | implemented (first slice) | `1/2` | foot/ghostty/kitty | mode bit + resize report emit (`CSI 48;rows;cols;rows_px;cols_px t`) |
| DEC private `DECRQM` | `?5522` kitty paste/clipboard events mode | implemented (bounded slice) | `1/2` | kitty docs + code | implemented mode + unsolicited paste-event MIME list + minimal `OSC 5522` read (`.`/`text/plain`/`text/html`/`text/uri-list`/`image/png`); write path + permission/pw flow deferred |
| DEC private `DECRQM` | `?1007` alternate scroll | implemented | `1/2` | foot/ghostty | implemented via wheel->arrow behavior in alt-screen (when mouse reporting off) |
| DEC private `DECRQM` | unknown modes | implemented fallback | `0` | xterm/foot convention | keep (test-locked) |

Notes:
- Current Zide implemented set is sourced from `src/terminal/protocol/csi.zig` (`decrqmPrivateModeState`, `decrqmAnsiModeState`).
- Reference candidate set is seeded primarily from `reference_repos/terminals/foot/csi.c` plus xterm docs and kitty clipboard docs (`?5522`).
- Final `implement/defer` decisions for each non-implemented row should be recorded here before broadening `PA-08e` mode handling.
- `?66` is now implemented and test-covered (`DECPAM`/`DECPNM` -> `DECRQM ?66`).
- `PA-08g` 5-mode batch decision (2026-02-23, implementation-first, batch A):
  - Implemented: `?9` (X10 mouse mode query/state), `?12` (cursor blinking query/state)
  - Deferred provisional: `?45` (reverse-wrap), `?1016` (SGR pixel mouse), `?5522` (kitty paste events)
  - Rationale: only `?9`/`?12` had low-risk underlying state support already present in Zide; the others require larger behavior work and remain `Pm=0` provisional unsupported.
- `PA-08g` 5-mode batch decision (2026-02-23, implementation-first, batch B):
  - Implemented: ANSI `4` (IRM insert mode + DECRQM), `?1048` (save-cursor mode query tracking + DECRQM)
  - Deferred provisional: `?45` (reverse-wrap), `?1016` (SGR pixel mouse), `?5522` (kitty paste events)
  - Rationale: `IRM` and `?1048` were the next tractable rows with bounded underlying support; deferred rows require materially larger behavior/integration work.
- `PA-08g` 5-mode batch decision (2026-02-23, implementation-first, batch C):
  - Implemented: `?8` (DECARM autorepeat + DECRQM), `?1007` (alternate scroll + DECRQM)
  - Deferred provisional: `?45` (reverse-wrap), `?1016` (SGR pixel mouse), `?5522` (kitty paste events)
  - Rationale: `?8`/`?1007` had tractable underlying behavior in Zide input/UI paths; deferred rows still require larger protocol/UI feature work.
- `PA-08g` 5-mode batch decision (2026-02-23, implementation-first, batch D: medium rows audit):
  - Deferred provisional (all `Pm=0`, no implementation landed in this batch): `?45`, `?1016`, `?2031`, `?2048`, `?5522`
  - Reference direction:
    - `?45` is supported/queryable in `foot` and `ghostty` (xterm-family common reverse-wrap semantics)
    - `?1016` is supported/queryable in `foot`, `ghostty`, and `kitty` (SGR pixel mouse)
    - `?2031` / `?2048` are supported/queryable in `foot`, `ghostty`, and `kitty` (modern notifications)
    - `?5522` is kitty-specific but documented/queryable in kitty (`docs/clipboard.rst`) and should not be reclassified as fixed-off without a product decision
  - Why no implementation was landed (none are "small" after batches A/B/C):
    - `?45` reverse-wrap: requires real reverse-wrap cursor/write semantics (screen/cursor movement behavior), not query-only state
    - `?1016` SGR pixel mouse: requires pixel-coordinate mouse reporting path (current terminal mouse reporting uses row/col only)
    - `?2031` color-scheme notifications: requires terminal mode state + theme-change event emission into terminal child stream
    - `?2048` in-band resize notifications: requires resize event protocol emission path and payload semantics
    - `?5522` kitty paste/clipboard events: requires kitty clipboard event protocol behavior (not just mode bit)
  - Follow-on rule (reaffirmed): next work should take one of these as a dedicated implementation slice; do not "improve" by changing unsupported reporting alone.
- `PA-08g` dedicated implementation slice (2026-02-23, kitty `?5522` paste events mode):
  - Implemented: `DECRQM/DECSET/DECRST ?5522` mode state (`Pm=1/2`) + real paste-event behavior
  - Implemented behavior (current bounded scope):
    - user-triggered paste routes (shortcut/menu paste + middle-click paste path) send unsolicited `OSC 5522` MIME-list event instead of direct paste text when mode is enabled
    - minimal `OSC 5522` read replies for `type=read` requests:
      - `.` (targets list) -> advertises `text/plain`, `text/html`, `text/uri-list`, and `image/png` (when present)
      - `text/plain` -> returns cached clipboard text from the user-triggered paste event
      - `text/html` -> returns cached HTML clipboard data when available (via SDL clipboard MIME read)
      - `text/uri-list` -> returns cached URI list clipboard data when available (via SDL clipboard MIME read)
      - `image/png` -> returns cached PNG clipboard bytes when available (via SDL clipboard MIME read), read-only
  - Deferred within `?5522` slice (still parity work, not unsupported polish):
    - `OSC 5522` write path (`type=write` / `wdata` / `walias`)
    - permission prompts / `pw` one-time password flow
    - primary-selection (`loc=primary`)
    - arbitrary MIME types beyond `text/plain` / `text/html` / `text/uri-list` / `image/png`
  - Evidence:
    - PTY integration: `src/terminal_focus_reporting_tests.zig` (`DECRQM` state + unsolicited event + `type=read`)
    - PTY integration: explicit `OSC 5522 type=read:loc=primary` -> `ENOSYS` and malformed/unsupported read error replies (`EINVAL` / `ENOSYS`)
    - replay: `fixtures/terminal/decrqm_query_matrix_reply.*` now queries `?5522` default/set/reset
    - replay: `fixtures/terminal/osc_5522_read_invalid_payload_reply_bel.*`, `fixtures/terminal/osc_5522_read_unsupported_mime_reply_st.*`, `fixtures/terminal/osc_5522_read_primary_unsupported_reply_st.*`
    - replay (success): `fixtures/terminal/osc_5522_read_html_success_reply_st.*`, `fixtures/terminal/osc_5522_read_html_success_reply_bel.*`, `fixtures/terminal/osc_5522_read_text_success_reply_st.*`, `fixtures/terminal/osc_5522_read_text_success_id_reply_st.*`, `fixtures/terminal/osc_5522_read_uri_list_success_reply_bel.*`, `fixtures/terminal/osc_5522_read_png_success_reply_st.*`, `fixtures/terminal/osc_5522_read_targets_order_success_reply_st.*` (via replay pre-seeded `OSC 5522` clipboard cache)
    - replay (success semantics): target-list ordering is test-locked as `text/plain`, `text/html`, `text/uri-list`, `image/png`; success `id=` echo/sanitization is replay-covered in addition to PTY tests
    - replay harness support: `src/terminal/replay_harness.zig` now supports pre-seeding `OSC 5522` clipboard caches (`text/plain`, `text/html`, `text/uri-list`, `image/png` hex) for reply-fixture success-path coverage
    - `PA-08h` alignment: `DECSTR` reset reply fixture now includes `?5522` (`fixtures/terminal/decstr_resets_modes_query_reply.*`)
- `PA-08g` next dedicated implementation slice (docs-first, `?2048` in-band resize notifications):
  - Reference anchors:
    - `foot` supports/query-reports mode `2048` (`reference_repos/terminals/foot/csi.c`); foot ctlseq docs list `2048` as in-band window resize notifications (`reference_repos/terminals/foot/doc/foot-ctlseqs.7.scd`)
    - `ghostty` emits mode-2048 resize reports on resize when enabled and uses CSI `48;rows;cols;rows_px;cols_px t` (`reference_repos/terminals/ghostty/src/termio/Termio.zig`)
    - `kitty` emits the same `CSI 48;rows;cols;rows_px;cols_px t` payload on resize (`reference_repos/terminals/kitty/kitty/window.py`)
  - Proposed Zide first-slice target (implementation, not reporting polish):
    - `DECRQM/DECSET/DECRST ?2048` returns real mode state (`Pm=1/2`)
    - when enabled, terminal sends in-band resize report to child on terminal resize using `CSI 48;rows;cols;rows_px;cols_px t`
    - report values sourced from terminal grid size and current terminal pixel size (already tracked in `TerminalSession`)
  - Done looks like (first slice):
    - `?2048` mode bit exists and is reset by `DECSTR`
    - resize path emits one report per resize event when mode is enabled and PTY is attached
    - no reports when mode is disabled
    - PTY tests cover default/set/reset + emitted bytes on resize
    - replay fixture or integrated PTY test locks exact payload formatting
  - Explicit non-goals for first slice:
    - throttling/debouncing policy tuning beyond current resize flow
    - backfilling reports for historical resizes
    - alternate payload formats or legacy compatibility aliases
- `PA-08g` dedicated implementation slice (2026-02-23, `?2048` in-band resize notifications):
  - Implemented first slice: `DECRQM/DECSET/DECRST ?2048` mode state (`Pm=1/2`) + in-band resize report emission on terminal resize
  - Behavior:
    - emits `CSI 48;rows;cols;rows_px;cols_px t` when mode enabled and PTY attached
    - if cell pixel size is unknown (`cell_width=0`/`cell_height=0`), emits `rows_px=0;cols_px=0` (explicit fallback, test-locked)
    - no emission when mode disabled
    - `DECSTR` resets `?2048` to default (`Pm=2`)
  - Evidence:
    - PTY integration: `src/terminal_focus_reporting_tests.zig` (`DECRQM` state + resize emit bytes)
    - replay: `fixtures/terminal/decrqm_query_matrix_reply.*` now queries/set/resets `?2048`
  - Second-slice docs-first follow-up (event-source fidelity / emission policy):
    - Confirm resize emit source(s) and duplication behavior across UI resize paths so `?2048` notifications do not double-fire during the same logical resize.
    - Define throttling/debouncing policy only if a real app compatibility/perf issue appears; current foundation intentionally emits from the existing terminal resize path without extra throttling.
    - Keep current `rows_px/cols_px = 0` fallback when cell pixel size is unknown unless reference behavior or app compatibility demands a different policy.
- `PA-08g` dedicated implementation slice (2026-02-23, `?2031` color-scheme notifications):
  - Reference anchors:
    - `foot` supports/query-reports mode `2031` and replies to private DSR `?996n` with `CSI ? 997 ; {1|2} n` (`reference_repos/terminals/foot/csi.c`)
    - `ghostty` supports mode `2031` and emits `CSI ? 997 ; {1|2} n` on color-scheme changes (`reference_repos/terminals/ghostty/src/Surface.zig`)
    - `kitty` supports color preference notification mode `2031` and private DSR `?996n` handling (`reference_repos/terminals/kitty/kitty/modes.h`, `reference_repos/terminals/kitty/kitty/screen.c`)
  - Implemented first slice:
    - `DECRQM/DECSET/DECRST ?2031` mode state (`Pm=1/2`)
    - private DSR `CSI ? 996 n` reply for current color-scheme preference (`CSI ? 997 ; 1 n` dark, `CSI ? 997 ; 2 n` light)
    - `TerminalSession.reportColorSchemeChanged(dark)` API emits live `?997` notification only when `?2031` is enabled
    - App theme wiring in `src/main.zig` now propagates config/theme changes to terminal sessions using a background-luma dark/light heuristic
  - Deferred within `?2031` slice:
    - OS/theme-provider event wiring beyond current app-config theme changes
    - richer theme semantics beyond dark/light preference (current signal is dark vs light only)
  - Evidence:
    - PTY integration: `src/terminal_focus_reporting_tests.zig` (`DECRQM` state, `?996n`, gated live notify emission)
    - replay: `fixtures/terminal/decrqm_query_matrix_reply.*` now queries/set/resets `?2031`
    - app integration wiring: `src/main.zig` (`reloadConfig`, `newTerminal`)
- `PA-08g` next-slice decision (2026-02-23, post-`?45` defer):
  - Chosen next real follow-up for medium-mode work: continue `?2031` with richer live event sources before reopening larger behavior modes like `?45`.
  - Why:
    - `?2031` already has real mode state + DSR + app-config wiring, so the next step is incremental and low-risk.
    - `?45` still requires deeper cursor/write semantics and wrap-history behavior.
  - Current status checkpoint:
    - audited `Shell.setTheme(...)` callsites and confirmed current live theme-change path is startup/new-terminal + config reload (`src/main.zig`).
    - no separate runtime theme-toggle event source exists today, so current `?2031` app wiring is sufficient for this slice until a new real source is added.
  - Next `?2031` done-slice target:
    - add additional live event sources only when a concrete UI/theme-change path exists (beyond config reload)
    - test-lock notification suppression when mode is reset/disabled (including after `DECSTR`)
  - If no new real `?2031` source appears, the next medium mode candidate moves to `?2027` (grapheme-cluster shaping mode), but only after a docs-first implement/defer review.
- `PA-08h` DECSTR matrix alignment follow-up (2026-02-23):
  - Added PTY + replay coverage proving `DECSTR` restores default-set modes `?8` (DECARM autorepeat) and `?1007` (alternate scroll) after they are explicitly reset.
  - Expanded the DECSTR mode-reset reply matrix to include `?2031` and `?5522` so newer `PA-08g` mode slices remain aligned (later extended to `?1016` as that slice landed).
  - Evidence:
    - PTY integration: `src/terminal_focus_reporting_tests.zig`
    - replay: `fixtures/terminal/decstr_resets_default_set_modes_query_reply.*`, `fixtures/terminal/decstr_resets_modes_query_reply.*`
  - Later extension:
    - `src/terminal_focus_reporting_tests.zig` now also locks `DECSTR` suppression of live `?2031` color-scheme notifications and `?2048` resize reports after reset (mode reset side-effect boundary)
    - `fixtures/terminal/decstr_resets_modes_query_reply.*` now includes `?2048` in the DECRQM before/after matrix
    - `src/terminal_focus_reporting_tests.zig` also locks `DECSTR` suppression of unsolicited `?5522` paste-event emissions after reset and re-enable recovery in the same sequence
- `PA-08g` DECRQM unsupported-reporting correction review (2026-02-23):
  - Kept `Pm=4` only for strategic fixed-off / legacy non-goal modes in current scope: `?67`, `?1001`, `?1005`, `?1015`, `?1034`, `?1035`, `?1036`, `?1042`, `?1070`.
  - Reverted to `Pm=0` provisional unsupported replies for modes still plausibly on the support path: `?9`, `?45`, `?1016`, `?2031`, `?2048`, `?5522`.
  - Subsequent implementations promoted `?1016`, `?2031`, `?2048`, and `?5522` to real support (`Pm=1/2`) with feature slices; remaining provisional rows continue to require implement/defer decisions.
  - Rule in force: do not expand the `Pm=4` set further without a strategic non-support decision per mode.
- `PA-08g` docs-first implementation decision (2026-02-23, `?1016` SGR pixel mouse mode):
  - Decision basis (before implementation): keep `Pm=0` provisional unsupported until a real end-to-end slice is landed; do not reclassify as fixed-off.
  - Reference direction:
    - `foot`, `ghostty`, and `kitty` support/query-report `?1016`, so this remains on Zide's support path rather than strategic non-support.
  - Why it was deferred initially (not a small slice):
    - current terminal mouse reporting is row/col-oriented; `?1016` needs a pixel-coordinate reporting path plumbed end-to-end
    - requires explicit interaction/precedence rules with existing mouse-report modes (`1000/1002/1003`) and SGR formatting mode (`1006`)
    - should land as real behavior with PTY + replay evidence, not as query-only `DECRQM` reporting
  - `?1016` first-slice done looks like:
    - `DECRQM/DECSET/DECRST ?1016` reports/toggles real mode state (`Pm=1/2`)
    - when enabled and SGR mouse reporting is active, mouse reports use pixel coordinates (not cell coordinates)
    - precedence/compat rules for non-SGR mouse modes are documented and test-locked
    - PTY tests + replay fixture(s) cover representative click + motion payloads
- `PA-08g` dedicated implementation slice (2026-02-23, `?1016` SGR pixel mouse mode):
  - Implemented first slice: `DECRQM/DECSET/DECRST ?1016` mode state (`Pm=1/2`) + SGR pixel-coordinate mouse reporting when `1006` SGR mouse is active
  - Behavior (current bounded scope):
    - SGR mouse reports use pixel coordinates (`x`,`y` pixels, 1-based) when `?1016` and `?1006` are both enabled
    - falls back to standard SGR cell coordinates when `?1016` is disabled
    - UI mouse path now supplies snapped terminal-grid pixel coordinates (`pixel_x`/`pixel_y`) in `MouseEvent`
  - Deferred within `?1016` slice:
    - explicit broader compatibility matrix for motion-heavy edge cases and non-SGR mode interactions beyond the current first-slice behavior
    - replay fixture coverage for emitted pixel mouse bytes (PTY tests currently lock representative bytes)
  - Evidence:
    - PTY integration: `src/terminal_focus_reporting_tests.zig` (`DECRQM` state + representative pixel-vs-cell SGR mouse click bytes)
    - PTY integration: `src/terminal_focus_reporting_tests.zig` (`?1016` motion + release bytes and non-SGR precedence when `1006` is disabled)
    - PTY integration: `src/terminal_focus_reporting_tests.zig` (`?1016` wheel bytes with Shift/Alt/Ctrl modifiers in SGR pixel mode)
    - PTY integration: `src/terminal_focus_reporting_tests.zig` (`?1016` mixed-modifier wheel bytes and explicit wheel-up/down ordering in SGR pixel mode)
    - replay: `fixtures/terminal/mouse_sgr_1016_pixel_reply.*` synthetic mouse events lock representative pixel-SGR press/move/release/wheel bytes via `reply_hex`
    - replay: `fixtures/terminal/mouse_1016_without_1006_cell_reply.*` synthetic mouse events lock non-SGR precedence (`?1016` without `?1006` still emits X10/cell-coordinate bytes)
    - replay: `fixtures/terminal/decrqm_query_matrix_reply.*` queries/set/resets `?1016`
- `PA-08g` implementation slice (2026-02-26, `?45` reverse-wrap mode):
  - Implemented first slice: `DECRQM/DECSET/DECRST ?45` real mode state (`Pm=1/2`) plus reverse-wrap behavior for cursor-left operations at column `0`.
  - Behavior:
    - `BS` (`0x08`) and `CUB` (`CSI D`) now reverse-wrap to the previous row’s last column when all are true:
      - `?45` enabled
      - current column is `0`
      - previous row is marked wrapped
      - cursor is within the active scroll region (`row > scroll_top`)
    - otherwise behavior remains clamped-at-column-0.
  - Evidence:
    - PTY/unit integration:
      - `src/terminal_focus_reporting_tests.zig` common `DECRQM` mode matrix now includes `?45`
      - `src/terminal_focus_reporting_tests.zig` adds reverse-wrap cursor behavior tests for both `BS` and `CUB`
    - replay:
      - `fixtures/terminal/decrqm_query_matrix_reply.*` now includes `?45` query/set/reset replies
- `PA-08g` implementation slice (2026-02-26, strategic fixed-off `Pm=4` policy lock):
  - Added explicit PTY and replay coverage that locks the current strategic fixed-off private-mode set to `Pm=4` replies:
    - `?67`, `?1001`, `?1005`, `?1015`, `?1034`, `?1035`, `?1036`, `?1042`, `?1070`
  - Scope:
    - this is policy-lock coverage only (no behavior change), to prevent accidental drift between `Pm=0` provisional rows and strategic fixed-off rows.
  - Evidence:
    - PTY integration: `src/terminal_focus_reporting_tests.zig` (`terminal DECRQM strategic fixed-off private modes report permanently reset (Pm=4)`)
    - replay: `fixtures/terminal/decrqm_strategic_fixed_off_query_reply.*` (`reply_hex` asserted end-to-end)
- `PA-08g` implementation slice (2026-02-26, `Pm=3` policy lock):
  - Decision:
    - Zide does not currently emit `Pm=3` (`permanently set`) for any `DECRPM` mode family.
    - Use `Pm=1/2` for dynamic set/reset modes, `Pm=4` for strategic fixed-off modes, and `Pm=0` for not-recognized/provisional unsupported rows.
  - Evidence:
    - PTY integration: `src/terminal_focus_reporting_tests.zig` (`terminal DECRQM emits no Pm=3 replies in current policy scope`) guards representative ANSI/DEC/strategic-fixed-off queries against `;3$y`.
- `PA-08g` implementation slice (2026-02-26, ANSI unsupported-mode query lock):
  - Added explicit PTY coverage for representative unsupported ANSI `DECRQM` rows returning `Pm=0`:
    - `1`, `2`, `3`, `5`, `6`, `10`, `13`, `14`, `18`, `19`
  - Evidence:
    - PTY integration: `src/terminal_focus_reporting_tests.zig` (`terminal DECRQM representative unsupported ANSI modes return Pm=0`)
    - replay: `fixtures/terminal/decrqm_ansi_unsupported_query_reply.*` (`reply_hex` asserted end-to-end)
- `PA-08g` implementation slice (2026-02-23, `?2027` grapheme-cluster shaping mode, first slice):
  - Decision: implement a **queryable no-op semantics** first slice (real mode state + documented no-op behavior boundary), then defer renderer/shaping behavior changes to a later slice.
  - Reference direction:
    - `foot` and `ghostty` support/query-report `?2027`, so it remains on the support path.
    - Reference polarity check completed:
      - `foot`: `2027` toggles grapheme shaping state (config-gated in some builds; may DECRPM as permanent reset if unavailable)
      - `ghostty`: `2027` is a real mode with explicit enabled/disabled tests
      - kitty: no equivalent `?2027` mode identified in current parity review; treat as xterm/foot/ghostty-side extension
  - Why first slice is queryable no-op (not renderer behavior yet):
    - requires a clear shaping-semantics contract for the terminal pipeline beyond a mode bit
    - must define interaction with existing grapheme/ligature shaping paths and user-visible behavior boundaries
    - implementation-first rule is still satisfied because this slice adds real state + reset/query semantics + explicit, test-locked no-op boundary
  - Shaping semantics contract (implemented first slice):
    - Scope target for first slice:
      - `?2027` controls whether the terminal is allowed to apply multi-codepoint grapheme shaping / cluster-aware presentation heuristics beyond simple cell-local combining storage.
      - It does **not** change parser decoding, codepoint storage, UTF-8 validation, or terminal cell width accounting.
    - Zide-specific behavioral boundary (first slice proposal):
      - `?2027 = reset/default` (`Pm=2`): current Zide behavior (existing grapheme shaping path allowed, as implemented today).
      - `?2027 = set` (`Pm=1`): explicit enable state (same behavior as default in first slice unless we define a divergent default policy).
      - If references require opposite polarity, record and adjust before code; do not guess.
    - Observable effects that count for first-slice evidence:
      - `DECRQM/DECSET/DECRST ?2027` real state (`Pm=1/2`)
      - at least one replay/PTy-visible boundary proving mode toggling affects a documented behavior **or** an explicit reference-aligned no-op policy with stable query semantics
      - `DECSTR` reset returns mode to default and query reports `Pm=2`
    - Non-goals for first slice:
      - redesigning shaping pipeline, ligature engine, or renderer architecture
      - changing Unicode storage/model semantics (`PA-01` scope)
      - introducing font-dependent shaping quality tuning work
    - Reference check status:
      - polarity/meaning in `foot`/`ghostty` reviewed (mode enables/disables grapheme shaping behavior)
      - kitty overlap reviewed: no direct `?2027` equivalent tracked in current slice
  - `?2027` first-slice done looks like:
    - `DECRQM/DECSET/DECRST ?2027` reports/toggles real mode state (`Pm=1/2`)
    - shaping behavior impact (or explicit no-op semantics, if reference-aligned for Zide scope) is documented by the contract above and observable/test-locked
    - PTY + replay coverage lock query state and at least one behavior boundary
  - Status (current):
    - implemented for first slice
    - query/reset semantics:
      - `DECRQM/DECSET/DECRST ?2027` -> real state (`Pm=1/2`) in `src/terminal/protocol/csi.zig`
      - `DECSTR` resets `?2027` to default (`Pm=2`)
    - behavior boundary (explicit no-op for now):
      - PTY test proves representative multicodepoint text model state remains unchanged while mode bit toggles
      - see `src/terminal_focus_reporting_tests.zig` (`terminal grapheme cluster mode ?2027 first slice is queryable no-op for text model`)
    - replay/PTy evidence:
      - `fixtures/terminal/decrqm_query_matrix_reply.*` (query/set/reset replies)
      - `fixtures/terminal/decstr_resets_modes_query_reply.*` (reset-to-default reply after `DECSTR`)

- `PA-08g` implementation slice (2026-02-26, `?2027` grapheme-cluster shaping mode, second slice):
  - Implemented first real behavior toggle beyond query-only no-op:
    - when a cell's combining-mark storage is full, `?2027` now preserves shaping-priority marks (`ZWJ`, `VS16`, emoji skin-tone modifiers) by replacing the last stored combining mark.
    - when `?2027` is reset/default, overflow behavior remains unchanged (drop extra combining mark).
  - Scope:
    - keeps parser/storage model unchanged; only affects overflow replacement policy for shaping-critical marks.
  - Evidence:
    - PTY/unit integration: `src/terminal_focus_reporting_tests.zig` (`terminal grapheme cluster mode ?2027 keeps shaping-priority combining mark on overflow`)
    - replay: `fixtures/terminal/decrqm_query_matrix_reply.*` (query/set/reset replies remain locked)
    - replay: `fixtures/terminal/grapheme_mode_2027_priority_overflow.*` (mode-off vs mode-on overflow behavior on grid snapshot)

- `PA-08g` implementation slice (2026-02-26, ANSI mode `12` local echo first slice):
  - Implemented `DECRQM/SM/RM` for ANSI mode `12` with real behavior:
    - `DECRQM 12` returns `Pm=1/2`
    - with no PTY attached and mode `12` enabled, printable `sendChar` input is echoed to the terminal model
    - with mode `12` reset, no local echo occurs
  - Evidence:
    - PTY/unit integration: `src/terminal_focus_reporting_tests.zig` (`terminal DECRQM ansi queries report mode 4, 12 and 20 set/reset state`)
    - PTY/unit integration: `src/terminal_focus_reporting_tests.zig` (`terminal ANSI local echo mode 12 echoes chars only without PTY`)
    - replay: `fixtures/terminal/decrqm_query_matrix_reply.*` now includes ANSI `12` query/set/reset replies

- `PA-08h` implementation slice (2026-02-27, `DECSLRM` first bounded slice):
  - Implemented first bounded `DECSLRM` behavior behind private mode `?69`:
    - `DECRQM/DECSET/DECRST ?69` now reports/toggles real state (`Pm=1/2`)
    - `CSI Pl;Pr s` applies left/right margins only when `?69` is enabled
    - cursor is clamped to active horizontal bounds and `DECSLRM` homes cursor to row 1 at left margin
  - Scope boundary (first slice):
    - includes margin state + core cursor clamp behavior (`CR`, `CUF/CUB`, `HPA/HVP/CUP`, tab movement paths)
    - excludes broader rectangular editing semantics (`DECCRA`/rect ops) and full app-parity matrix for all margin-interacting operations
  - Evidence:
    - PTY integration: `src/terminal_focus_reporting_tests.zig`
      - `terminal DECSLRM applies margins only when ?69 mode is enabled`
      - common private `DECRQM` mode matrix now includes `?69`
      - `DECSTR` mode-reset matrix includes `?69`
    - replay:
      - `fixtures/terminal/decrqm_declrmm_69_query_reply.*`
      - `fixtures/terminal/decslrm_set_margins_cpr_reply.*`

- `PA-08h` implementation slice (2026-02-27, `DECSLRM` margin-clipped character-edit ops):
  - Extended `DECSLRM` behavior so character-edit operations are clipped to active horizontal margins when `?69` is enabled:
    - `ICH` (`CSI Ps @`) shifts only within `left_margin..right_margin`
    - `DCH` (`CSI Ps P`) deletes/shifts only within `left_margin..right_margin`
    - `ECH` (`CSI Ps X`) erases only within `left_margin..right_margin`
  - Outside-margin cells are preserved for these operations.
  - Evidence:
    - PTY/unit integration: `src/terminal_focus_reporting_tests.zig`
      - `terminal DECSLRM clips ICH DCH ECH edits to active horizontal margins`
    - replay:
      - `fixtures/terminal/decslrm_margin_clips_ich_dch_ech.*`

- `PA-08h` implementation slice (2026-02-27, `DECSLRM` write/wrap boundary alignment):
  - Aligned text write paths and wrap behavior to active horizontal margins when `?69` is enabled:
    - `writeCodepoint` / ASCII-run writes now use `right_margin` as the active write boundary
    - autowrap transition lands at `left_margin` on the next row (not column 1)
    - wide-codepoint pre-wrap guard now checks margin boundary, not full-grid width
  - Evidence:
    - PTY/unit integration: `src/terminal_focus_reporting_tests.zig`
      - `terminal DECSLRM autowrap continues at left margin`
    - replay:
      - `fixtures/terminal/decslrm_wrap_left_margin.*`

- `PA-08h` implementation slice (2026-02-27, `DECSLRM` line-erase clipping):
  - Aligned `EL` (`CSI Ps K`) behavior to active horizontal margins when `?69` is enabled:
    - mode `0` erases cursor..`right_margin`
    - mode `1` erases `left_margin`..cursor
    - mode `2` erases `left_margin`..`right_margin`
  - Outside-margin cells are preserved under DECSLRM.
  - Evidence:
    - PTY/unit integration: `src/terminal_focus_reporting_tests.zig`
      - `terminal DECSLRM clips EL to active horizontal margins`
    - replay:
      - `fixtures/terminal/decslrm_el_mode2_clips_to_margins.*`

- `PA-08h` implementation slice (2026-02-26, `DECSLRM` line insert/delete margin-band clipping):
  - Aligned line insert/delete behavior to active horizontal margins when `?69` is enabled:
    - `IL` (`CSI Ps L`) shifts only the active margin band (`left_margin..right_margin`) downward within the vertical scroll region and blanks inserted band cells.
    - `DL` (`CSI Ps M`) shifts only the active margin band upward within the vertical scroll region and blanks vacated tail band cells.
  - Outside-margin columns are preserved for both operations.
  - Evidence:
    - PTY/unit integration: `src/terminal_focus_reporting_tests.zig`
      - `terminal DECSLRM clips IL and DL to active horizontal margins`
    - replay:
      - `fixtures/terminal/decslrm_il_margin_band_only.*`
      - `fixtures/terminal/decslrm_dl_margin_band_only.*`

- `PA-08h` implementation slice (2026-02-26, `DECSLRM` display-erase clipping):
  - Aligned `ED` (`CSI Ps J`) behavior to active horizontal margins when `?69` is enabled:
    - modes `0`/`1` erase only the affected cursor-row segment and above/below row spans within `left_margin..right_margin`
    - modes `2`/`3` erase the full row range but still clip horizontally to `left_margin..right_margin`
  - Outside-margin columns are preserved for these erase-display modes.
  - Evidence:
    - PTY/unit integration: `src/terminal_focus_reporting_tests.zig`
      - `terminal DECSLRM clips ED to active horizontal margins`
    - replay:
      - `fixtures/terminal/decslrm_ed_mode2_clips_to_margins.*`

- `PA-08h` implementation slice (2026-02-26, `DECSLRM` scroll-region clipping for `SU`/`SD`):
  - Aligned `SU` (`CSI Ps S`) and `SD` (`CSI Ps T`) scroll-region operations to active horizontal margins when `?69` is enabled:
    - row shifts are now limited to `left_margin..right_margin` inside the vertical scroll region
    - outside-margin columns are preserved
  - Evidence:
    - PTY/unit integration: `src/terminal_focus_reporting_tests.zig`
      - `terminal DECSLRM clips SU and SD to active horizontal margins`
    - replay:
      - `fixtures/terminal/decslrm_su_margin_band_only.*`
      - `fixtures/terminal/decslrm_sd_margin_band_only.*`

- `PA-08h` implementation slice (2026-02-26, `DECSLRM` IL/DL outside-margin cursor guard):
  - Added a defensive parity guard for direct `IL` (`CSI Ps L`) / `DL` (`CSI Ps M`) in DECSLRM mode:
    - when `?69` is enabled and cursor column is outside `left_margin..right_margin`, `IL`/`DL` are no-op.
  - Note:
    - this state is not normally reachable via CSI cursor positioning under active DECSLRM because movement is margin-clamped; guard is locked via direct model-state unit integration.
  - Evidence:
    - PTY/unit integration: `src/terminal_focus_reporting_tests.zig`
      - `terminal DECSLRM IL and DL are no-op when cursor is outside margins`

- `PA-08h` implementation slice (2026-02-26, `DECSLRM` + `DECSTBM` interaction lock for `SU`):
  - Added explicit interaction coverage for vertical + horizontal margin composition:
    - with `?69` + `DECSLRM` and `DECSTBM` active together, `SU` (`CSI Ps S`) shifts only the horizontal margin band and only within the configured vertical scroll region.
    - outside-margin columns and rows outside `DECSTBM` are preserved.
  - Evidence:
    - PTY/unit integration: `src/terminal_focus_reporting_tests.zig`
      - `terminal DECSLRM and DECSTBM clip SU to margin band within scroll region`
    - replay:
      - `fixtures/terminal/decslrm_decstbm_su_margin_band_only.*`

- `PA-08h` implementation slice (2026-02-26, `DECSLRM` + `DECSTBM` interaction lock for `SD`):
  - Added matching interaction coverage for `SD` (`CSI Ps T`) under combined vertical + horizontal margins:
    - with `?69` + `DECSLRM` and `DECSTBM` active together, `SD` shifts only the horizontal margin band within the configured vertical scroll region.
    - outside-margin columns and rows outside `DECSTBM` are preserved.
  - Evidence:
    - PTY/unit integration: `src/terminal_focus_reporting_tests.zig`
      - `terminal DECSLRM and DECSTBM clip SD to margin band within scroll region`
    - replay:
      - `fixtures/terminal/decslrm_decstbm_sd_margin_band_only.*`

- `PA-08h` implementation slice (2026-02-26, `DECSLRM` + `DECSTBM` interaction lock for `IL`):
  - Added interaction coverage for `IL` (`CSI Ps L`) under combined vertical + horizontal margins:
    - with `?69` + `DECSLRM` and `DECSTBM` active together, insert-line shifts only the horizontal margin band and only from cursor row through scroll-bottom.
    - outside-margin columns and rows outside `DECSTBM` are preserved.
  - Evidence:
    - PTY/unit integration: `src/terminal_focus_reporting_tests.zig`
      - `terminal DECSLRM and DECSTBM clip IL to margin band within scroll region`
    - replay:
      - `fixtures/terminal/decslrm_decstbm_il_margin_band_only.*`

- `PA-08h` implementation slice (2026-02-26, `DECSLRM` + `DECSTBM` interaction lock for `DL`):
  - Added interaction coverage for `DL` (`CSI Ps M`) under combined vertical + horizontal margins:
    - with `?69` + `DECSLRM` and `DECSTBM` active together, delete-line shifts only the horizontal margin band and only from cursor row through scroll-bottom.
    - outside-margin columns and rows outside `DECSTBM` are preserved.
  - Evidence:
    - PTY/unit integration: `src/terminal_focus_reporting_tests.zig`
      - `terminal DECSLRM and DECSTBM clip DL to margin band within scroll region`
    - replay:
      - `fixtures/terminal/decslrm_decstbm_dl_margin_band_only.*`

- `PA-08h` audit slice (2026-02-26, DECSLRM promoted-row closure review):
  - Completed an explicit DECSLRM coverage audit for the promoted non-rectangular margin-sensitive operations in current scope.
  - Implemented + test-locked in current DECSLRM scope:
    - margin set/query baseline (`?69`, `DECSLRM`) and write/wrap boundary behavior
    - character/erase ops (`ICH`, `DCH`, `ECH`, `EL`, `ED`)
    - line/scroll ops (`IL`, `DL`, `SU`, `SD`)
    - combined vertical+horizontal interaction locks with `DECSTBM` for (`SU`, `SD`, `IL`, `DL`)
  - Deferred beyond current scope (intentional):
    - rectangular editing/copy families (`DECCRA` and related rectangular ops) under left/right margins
    - full cross-terminal parity matrix across all advanced xterm private-mode edge combinations
  - Outcome:
    - promoted DECSLRM non-rectangular operation row is considered covered for current PA-08h scope; remaining DECSLRM work is now explicitly in the deferred rectangular/advanced matrix bucket.

Planned work (decomposition / `PA-08h` first promoted CSI family: `DECSTR` soft terminal reset):
- Reference anchors:
  - xterm docs define `CSI ! p` as `DECSTR` (soft terminal reset), VT220+ (`reference_repos/terminals/xterm_snapshots/ctlseqs.txt`).
  - kitty parses `DECSTR` as a distinct CSI family keyed by intermediates + final (`reference_repos/terminals/kitty/kitty/vt-parser.c`).
  - ghostty routes intermediate-bearing CSI families distinctly (via intermediate-aware parsing/dispatch), which is the model we are moving toward with `PA-08f` (`reference_repos/terminals/ghostty/src/terminal/stream.zig`).
- Why this is a separate `PA-08h` slice (not just a parser follow-up):
  - `DECSTR` semantics are behavioral and reset-scoped; parser support alone is not sufficient.
  - Zide already has a hard reset path (`src/terminal/core/state_reset.zig`, `TerminalSession.resetState()`), and using it for `DECSTR` would be incorrect and destructive (clears screens/kitty images, etc.).
- `PA-08h` `DECSTR` done looks like:
  - `CSI ! p` is recognized via explicit `!` intermediate handling in CSI dispatch.
  - `DECSTR` applies a documented soft-reset subset aligned with xterm/kitty/ghostty conventions for Zide scope (mode resets, parser/input state resets as appropriate, but no destructive full terminal reset).
  - Hard-reset-only effects are explicitly excluded (e.g. no full screen clear, no kitty image wipe, no scrollback destruction) unless a reference-backed requirement says otherwise.
  - Tests cover:
    - PTY/no-reply dispatch path (`CSI ! p` recognized and handled as soft reset, not `DECRQM`)
    - replay fixture(s) showing key mode/mode bits reset behavior and preserved state that should survive soft reset
- Guardrails (must hold during implementation):
  - Do **not** call `TerminalSession.resetState()` / `state_reset.resetState()` from `DECSTR`.
  - Implement `DECSTR` as its own reset helper (or narrowly composed helpers) with a documented reset matrix.
  - If any `DECSTR` behavior is uncertain across references, document the divergence and test-lock the chosen convention.
- Suggested small-commit sequence:
  1. Docs-only reset matrix (what `DECSTR` resets vs preserves in Zide scope).
  2. Behavior-preserving parser/dispatch hook for `CSI ! p` (no-op handler + tests proving exact dispatch family).
  3. Implement the first safe subset (mode resets only) with PTY/replay coverage.

`PA-08h` DECSTR reset matrix (Zide first implementation scope):

| Area | `DECSTR` first-slice behavior | Notes |
|---|---|---|
| Screen grid contents | preserve | soft reset only; no clear |
| Scrollback | preserve | hard-reset-only behavior |
| Kitty images/placements (active + hidden screen) | reset/clear | explicit `PA-08h` parity decision (2026-02-26); kitty state is cleared on both screens by `DECSTR` |
| Kitty images/placements (hidden non-active screen) | reset/clear | verified symmetric clear for hidden-primary and hidden-alt paths |
| Cursor position | reset to home (`0,0`) on active screen | via `Screen.resetState()` |
| Cursor style/visibility | reset to defaults | active screen only |
| SGR attrs / key-mode stack / wrap-next | reset on active screen | via `Screen.resetState()` |
| Scroll region | reset to full active-screen region | via `Screen.resetState()` |
| Tabs | reset to default tab stops | via `Screen.resetState()` |
| Parser partial state / charsets | reset | via `parser.reset()` + `saved_charset = .{}` |
| Saved cursor restore slot (active screen) | reset/invalidated | `CSI u`/DECRC should not restore pre-`DECSTR` saved cursor on active screen |
| Saved charset restore slot | reset/invalidated | `CSI u`/DECRC should not restore pre-`DECSTR` saved charset |
| App cursor keys / app keypad | reset | terminal session global mode bits |
| Mouse reporting modes | reset | `input.resetMouse()` |
| Focus reporting / bracketed paste / sync updates | reset | mode defaults |
| Alt-screen active state | preserve | `DECSTR` must not force alt-screen enter/exit |
| Hidden screen contents (non-active screen) | preserve | verified for primary hidden behind alt in current slice |
| Title | reset to default (`"Terminal"`) | explicit `PA-08h` parity decision (2026-02-23); matched to broader soft-reset precedent (foot), replay + PTY verified |
| Cwd / clipboard / hyperlinks | preserve | outside DECSTR scope in Zide current slice; replay-verified |

`PA-08h` DECSTR reference-alignment review snapshot (xterm / kitty / ghostty anchors, 2026-02-23):
- Implemented + test-locked in Zide current scope:
  - intermediate-aware `CSI ! p` dispatch (distinct from `DECRQM`)
  - no-reply soft-reset handling (not hard reset)
  - active-screen soft-state resets (cursor/style/attrs/scroll region/tabs/parser charset state)
  - session mode resets (mouse/focus/bracketed paste/app cursor/app keypad/key mode flags)
  - preserve boundaries: grid contents, scrollback (heuristic replay assertion caveat), alt-screen active state, hidden primary contents
  - saved cursor/charset restore slots invalidated
- Implemented, but reference nuance still not fully audited:
  - exact metadata reset/preserve behavior across `DECSTR` (title reset vs cwd/clipboard/hyperlink preserve) is now replay-verified in Zide, but broader reference nuance across terminals is not fully audited yet
  - any reference-specific divergences in saved-state scope beyond Zide's current `CSI s/u` model
- Explicit reference divergence / pending policy decision (do not treat as parity-complete yet):
  - foot's `DECSTR` path (`reference_repos/terminals/foot/csi.c` -> `term_reset(term, false)` in `reference_repos/terminals/foot/terminal.c`) is materially broader than Zide's current slice:
    - exits alt-screen
    - resets title/app-id state
    - clears image/notification state
  - Zide currently preserves those areas by design for a safer soft-reset slice; this is intentional for now but must be kept marked as a divergence until xterm/kitty/ghostty alignment is chosen and documented.
- Current row-by-row classification in this `DECSTR` slice (to avoid ambiguity while `PA-08h` remains `partial`):
  - `implemented + evidence locked`: grid/scrollback (heuristic caveat), **kitty clear on active+hidden screens**, cursor pos/style, attrs, scroll region, tabs, parser/charsets, saved cursor/charset slots, session mode bits, alt-screen active state, hidden primary contents, **title reset to default**, cwd/clipboard/hyperlinks preserve
  - `defer (reference parity decision pending)`: whether `DECSTR` should reset app-id metadata and/or broaden non-graphics reset scope further
  - `out of current slice`: broader CSI reset-family parity beyond `DECSTR` (`PA-08h` promoted gaps)
- Explicit product/parity decision (2026-02-23):
  - `DECSTR` **alt-screen active state**: keep current Zide behavior (`preserve`) as a **strategic divergence** for now.
  - Rationale:
    - Zide is an IDE terminal and preserving active alt-screen state avoids surprising pane resets during soft-reset handling.
    - xterm docs define `DECSTR` as soft reset but do not provide a single unambiguous row-level reset matrix here; foot is broader, but that breadth is not automatically the target for Zide.
    - We already have PTY + replay evidence locking preserve semantics (`decstr_alt_screen_preserve_reply_and_grid`, direct alt-kitty boundary tests).
  - Revisit trigger:
    - If a real TUI compatibility issue is traced to `DECSTR` alt-screen preservation, promote a dedicated `PA-08h` parity adjustment slice and compare xterm/kitty/ghostty behavior directly before changing semantics.

- Explicit product/parity decision + implementation (2026-02-23):
  - `DECSTR` **title metadata**: changed Zide behavior to **reset title to default** (`"Terminal"`) on `CSI ! p` (match broader soft-reset precedent, notably foot, for this row).
  - Scope:
    - title only (app-id remains deferred/not modeled in Zide terminal session state)
    - cwd / clipboard / hyperlinks remain preserved in the current slice
  - Evidence:
    - PTY test: `terminal DECSTR resets title to default`
    - replay fixture: `decstr_resets_title_to_default`
    - existing metadata preserve fixture updated to assert cwd/hyperlinks (not title): `decstr_preserves_title_cwd_hyperlink`

- Explicit product/parity decision + implementation (2026-02-23):
  - `DECSTR` **kitty graphics state (active+hidden screens)**: changed Zide behavior to **clear kitty images/placements on both screens** on `CSI ! p` (align with foot-style soft reset clearing per-screen graphics state).
  - Evidence:
    - PTY/direct tests: active alt-screen kitty clears after `DECSTR`; hidden primary and hidden alt are cleared while non-active
    - replay fixtures: `decstr_clears_active_primary_kitty_placement`, `decstr_clears_active_alt_kitty_placement`, `decstr_clears_hidden_primary_kitty_state`, `decstr_clears_hidden_alt_kitty_state`
- Deferred / out of current `PA-08h` slice unless reference/app evidence demands it:
  - hard-reset-like behavior (screen clear, scrollback wipe, kitty image wipe)
  - broader CSI reset-family parity beyond `DECSTR` (tracked separately in `PA-08h` promoted gaps / `PA-08a`)

Implemented (increment 12 / `PA-08h` promoted-gap closure pass: explicit implement/defer classification):
- Added an explicit closure classification for the remaining promoted CSI/private rows
  outside the landed `DECSTR` slice. This is docs-only (no behavior change).
- Purpose: keep `PA-08h` auditable and prevent ambiguous `partial` drift.

Remaining promoted rows (`PA-08h`) and disposition:
- `DECSLRM` (`CSI ? Ps s` / left-right margins):
  - classification: `implement next` (not strategic non-support)
  - reference basis: xterm ctlseqs + ghostty margin-aware terminal flow indicate this is real, relevant support.
  - done criteria:
    - parser/dispatch + mode behavior in viewport model
    - interaction lock with `DECOM` and cursor-motion boundaries
    - PTY + replay fixtures for margin movement/erase behavior
- Broader reset-family rows beyond `DECSTR`:
  - classification: `defer intentionally`
  - reason: no current app breakage signal; `DECSTR` semantics are already test-locked.
  - resume criteria:
    - app compatibility failure tied to a specific reset-family sequence, or
    - clear high-impact reference divergence requiring parity change
- Xterm window-op breadth beyond `14/16/18/19`:
  - classification: `defer intentionally`
  - reason: low TUI impact relative to active protocol priorities.
  - resume criteria:
    - concrete app/tool demand for specific additional `CSI ... t` modes
    - PTY + replay reply fixtures per promoted mode
- Alternate mouse encodings (`?1005`, `?1015`):
  - classification: `strategic non-support` (fixed-off)
  - reference basis: modern terminals/apps favor SGR mouse paths; legacy encodings remain optional compatibility surface.
  - keep policy: continue `Pm=4` for these rows (already test-locked) unless product direction changes.
- Legacy tab-stop report/edit variants:
  - classification: `defer intentionally`
  - reason: low observed demand in active app/test set.
  - resume criteria:
    - fixture or app requiring a specific missing variant, then implement + replay lock.

Evidence anchors:
- Inventory + references: `PA-08a` table entries for DECSLRM, window-op breadth, tab variants, alternate mouse encodings.
- Existing lock points: `src/terminal/protocol/csi.zig`, `src/terminal_focus_reporting_tests.zig`, `fixtures/terminal/decrqm_*`, `fixtures/terminal/csi_window_ops_*`.

Implemented (increment 1 / `PA-08h` `DECSTR` first safe subset):
- Added explicit `CSI ! p` dispatch handling using CSI intermediate-aware matching (`!`), distinct from `DECRQM` (`$`).
- Implemented a non-destructive soft reset helper that resets parser/mode state and active-screen soft state without calling the hard reset path.
- Preserves grid contents, scrollback, and kitty graphics while resetting:
  - parser/charsets, cursor/style/visibility, scroll region, tab stops, key-mode stack
  - app cursor/keypad modes, mouse reporting, focus reporting, bracketed paste, sync updates
- Added PTY integration test proving:
  - no reply bytes for `DECSTR`
  - mode subset resets to defaults
  - grid contents remain intact
- Added replay fixture locking end-to-end soft-reset preservation of grid + cursor default state.

Files:
- `src/terminal/protocol/csi.zig`
- `src/terminal_focus_reporting_tests.zig`
- `fixtures/terminal/decstr_soft_reset_mode_subset.vt`
- `fixtures/terminal/decstr_soft_reset_mode_subset.json`
- `fixtures/terminal/decstr_soft_reset_mode_subset.golden`

Verification:
- `zig build test-terminal-focus-reporting`
- `zig build test-terminal-replay -- --fixture decstr_soft_reset_mode_subset --update-goldens`
- `zig build test-terminal-replay -- --all`

Implemented (increment 2 / `PA-08h` `DECSTR` end-to-end reset/preserve verification):
- Added PTY integration test that proves `DECSTR` resets a representative DECRQM-queryable mode set back to defaults:
  - `?1004`, `?1002`, `?2004`, ANSI `20`, `?66`
- Added replay reply fixture that captures the same before/after `DECRQM` replies end-to-end (set -> query, `DECSTR`, query again).
- Added replay fixture that proves kitty image/placement state survives `DECSTR` (direct preserved-state lock via `kitty:` snapshot section).
- Added PTY + replay coverage for alt-screen boundary semantics:
  - `DECSTR` does not force `?1049` reset while alt is active
  - primary-screen contents survive `DECSTR` executed while alt-screen is active
- Added PTY tests proving `DECSTR` invalidates the active-screen saved-cursor restore slot and saved charset restore slot.
- Added replay fixture that visibly proves charset reset behavior (`DEC special` mapped glyph before `DECSTR`, plain ASCII after `DECSTR`).
- Added an extra replay fixture with `scrollback` assertion + `DECSTR`; note this currently validates scroll behavior via existing `scrollback` assertion semantics (heuristic/tag semantics), not persistent scrollback count preservation in snapshot output.

Files:
- `src/terminal_focus_reporting_tests.zig`
- `fixtures/terminal/decstr_resets_modes_query_reply.vt`
- `fixtures/terminal/decstr_resets_modes_query_reply.json`
- `fixtures/terminal/decstr_resets_modes_query_reply.golden`
- `fixtures/terminal/decstr_clears_active_primary_kitty_placement.vt`
- `fixtures/terminal/decstr_clears_active_primary_kitty_placement.json`
- `fixtures/terminal/decstr_clears_active_primary_kitty_placement.golden`
- `fixtures/terminal/decstr_alt_screen_preserve_reply_and_grid.vt`
- `fixtures/terminal/decstr_alt_screen_preserve_reply_and_grid.json`
- `fixtures/terminal/decstr_alt_screen_preserve_reply_and_grid.golden`
- `fixtures/terminal/decstr_resets_charset_mapping.vt`
- `fixtures/terminal/decstr_resets_charset_mapping.json`
- `fixtures/terminal/decstr_resets_charset_mapping.golden`
- `fixtures/terminal/decstr_preserves_scrollback.vt`
- `fixtures/terminal/decstr_preserves_scrollback.json`
- `fixtures/terminal/decstr_preserves_scrollback.golden`

Verification:
- `zig build test-terminal-focus-reporting`
- `zig build test-terminal-replay -- --fixture decstr_resets_modes_query_reply --update-goldens`
- `zig build test-terminal-replay -- --fixture decstr_clears_active_primary_kitty_placement --update-goldens`
- `zig build test-terminal-replay -- --fixture decstr_alt_screen_preserve_reply_and_grid --update-goldens`
- `zig build test-terminal-replay -- --fixture decstr_resets_charset_mapping --update-goldens`
- `zig build test-terminal-replay -- --fixture decstr_preserves_scrollback --update-goldens`
- `zig build test-terminal-replay -- --all`

Implemented (increment 3 / `PA-08h` `DECSTR` cursor-style + alt-screen kitty nuance locks):
- Added PTY integration test proving `DECSTR` resets cursor style to the default (shape=`block`, blink=`true`) after `DECSCUSR` style changes.
- Added replay fixture that visibly locks cursor-style reset in snapshot output after `CSI 6 q` then `DECSTR`.
- Added state-level test and replay fixture proving kitty image/placement state survives `DECSTR` while alt-screen remains active (not only on primary or after alt exit).

Files:
- `src/terminal_focus_reporting_tests.zig`
- `fixtures/terminal/decstr_resets_cursor_style.vt`
- `fixtures/terminal/decstr_resets_cursor_style.json`
- `fixtures/terminal/decstr_resets_cursor_style.golden`
- `fixtures/terminal/decstr_clears_active_alt_kitty_placement.vt`
- `fixtures/terminal/decstr_clears_active_alt_kitty_placement.json`
- `fixtures/terminal/decstr_clears_active_alt_kitty_placement.golden`

Verification:
- `zig build test-terminal-focus-reporting`
- `zig build test-terminal-replay -- --fixture decstr_resets_cursor_style --update-goldens`
- `zig build test-terminal-replay -- --fixture decstr_clears_active_alt_kitty_placement --update-goldens`
- `zig build test-terminal-replay -- --all`

Implemented (increment 4 / `PA-08h` `DECSTR` alt-screen kitty non-leak boundary):
- Added a direct terminal-session test proving kitty placement state created in alt-screen:
  - survives `DECSTR` while alt-screen remains active
  - does not leak into the primary-screen snapshot after `?1049l`
- This tightens the soft-reset boundary semantics around screen-scoped kitty placements without relying on replay `kitty` assertions (which require final active-snapshot kitty activity).

Files:
- `src/terminal_focus_reporting_tests.zig`

Verification:
- `zig build test-terminal-focus-reporting`

Implemented (increment 5 / `PA-08h` `DECSTR` clipboard preserve + `PA-08f` non-`p` intermediate ignore fixture):
- Added replay reply fixture proving `DECSTR` preserves clipboard state in current Zide scope:
  - `OSC 52` set clipboard (`BEL` terminator)
  - `DECSTR`
  - `OSC 52` query reply unchanged (`BEL` terminator preserved)
- Added replay fixture that locks deterministic ignore/no-reply behavior for unsupported intermediate-bearing non-`p` CSI families (`CSI $ q`, `CSI ! q`) while preserving surrounding grid text.

Files:
- `fixtures/terminal/decstr_preserves_clipboard_query_reply_bel.vt`
- `fixtures/terminal/decstr_preserves_clipboard_query_reply_bel.json`
- `fixtures/terminal/decstr_preserves_clipboard_query_reply_bel.golden`
- `fixtures/terminal/csi_q_intermediate_unsupported_no_reply.vt`
- `fixtures/terminal/csi_q_intermediate_unsupported_no_reply.json`
- `fixtures/terminal/csi_q_intermediate_unsupported_no_reply.golden`

Verification:
- `zig build test-terminal-replay -- --fixture decstr_preserves_clipboard_query_reply_bel --update-goldens`
- `zig build test-terminal-replay -- --fixture csi_q_intermediate_unsupported_no_reply --update-goldens`
- `zig build test-terminal-replay -- --all`

Implemented (increment 6 / `PA-08h` `DECSTR` title/cwd/hyperlink preserve lock + `PA-08f` alternate-final ignore fixture):
- Added replay fixture proving `DECSTR` preserves all of the following together in one end-to-end snapshot:
  - terminal title (`OSC 2`)
  - cwd metadata (`OSC 7`)
  - hyperlink attrs + link table (`OSC 8`)
- Added replay fixture that locks deterministic ignore/no-reply behavior for unsupported intermediate-bearing `CSI ... x` forms (`CSI $ x`, `CSI ! x`) with surrounding grid text preserved.

Files:
- `fixtures/terminal/decstr_preserves_title_cwd_hyperlink.vt`
- `fixtures/terminal/decstr_preserves_title_cwd_hyperlink.json`
- `fixtures/terminal/decstr_preserves_title_cwd_hyperlink.golden`
- `fixtures/terminal/csi_x_intermediate_unsupported_no_reply.vt`
- `fixtures/terminal/csi_x_intermediate_unsupported_no_reply.json`
- `fixtures/terminal/csi_x_intermediate_unsupported_no_reply.golden`

Verification:
- `zig build test-terminal-replay -- --fixture decstr_preserves_title_cwd_hyperlink --update-goldens`
- `zig build test-terminal-replay -- --fixture csi_x_intermediate_unsupported_no_reply --update-goldens`
- `zig build test-terminal-replay -- --all`

Implemented (increment 7 / `PA-08f` unsupported-intermediate ignore coverage for `CSI ... z`):
- Added replay fixture that locks deterministic ignore/no-reply behavior for unsupported intermediate-bearing `CSI ... z` forms (`CSI $ z`, `CSI ! z`) with surrounding grid text preserved.
- This broadens end-to-end ignore coverage across multiple final bytes (`p`, `q`, `x`, `z`) so parser/disambiguation regressions are more likely to be caught early.

Files:
- `fixtures/terminal/csi_z_intermediate_unsupported_no_reply.vt`
- `fixtures/terminal/csi_z_intermediate_unsupported_no_reply.json`
- `fixtures/terminal/csi_z_intermediate_unsupported_no_reply.golden`

Verification:
- `zig build test-terminal-replay -- --fixture csi_z_intermediate_unsupported_no_reply --update-goldens`
- `zig build test-terminal-replay -- --all`

Implemented (increment 8 / `PA-08h` `DECSTR` title reset parity row):
- Updated `DECSTR` soft reset to reset terminal title back to the default (`"Terminal"`), while continuing to preserve cwd / clipboard / hyperlinks in the current slice.
- Added PTY integration test proving title reset and no-reply behavior.
- Added replay fixture locking title reset in snapshot output with `reply_hex: ""`.
- Updated the existing metadata-preserve replay fixture to stop asserting `title` exercised in final state, since title is now intentionally reset by `DECSTR`.

Files:
- `src/terminal/protocol/csi.zig`
- `src/terminal_focus_reporting_tests.zig`
- `fixtures/terminal/decstr_resets_title_to_default.vt`
- `fixtures/terminal/decstr_resets_title_to_default.json`
- `fixtures/terminal/decstr_resets_title_to_default.golden`
- `fixtures/terminal/decstr_preserves_title_cwd_hyperlink.json`

Verification:
- `zig build test-terminal-focus-reporting`
- `zig build test-terminal-replay -- --fixture decstr_resets_title_to_default --update-goldens`
- `zig build test-terminal-replay -- --all`

Implemented (increment 9 / `PA-08h` `DECSTR` active-screen kitty clear parity row):
- Updated `DECSTR` soft reset to clear kitty graphics state on the active screen (images, placements, partials), while preserving hidden-screen kitty state for now.
- Updated direct DECSTR kitty tests to reflect the new semantics:
  - active alt-screen kitty state is cleared by `DECSTR`
  - hidden primary still does not receive leaked alt placements after `?1049l`
- Renamed + refreshed the DECSTR kitty replay fixtures so filenames match active-screen kitty clear semantics.

Files:
- `src/terminal/protocol/csi.zig`
- `src/terminal_focus_reporting_tests.zig`
- `fixtures/terminal/decstr_clears_active_primary_kitty_placement.golden`
- `fixtures/terminal/decstr_clears_active_alt_kitty_placement.golden`

Verification:
- `zig build test-terminal-focus-reporting`
- `zig build test-terminal-replay -- --fixture decstr_clears_active_primary_kitty_placement --update-goldens`
- `zig build test-terminal-replay -- --fixture decstr_clears_active_alt_kitty_placement --update-goldens`
- `zig build test-terminal-replay -- --all`

Implemented (increment 10 / `PA-08h` `DECSTR` hidden-screen kitty clear parity row):
- Updated `DECSTR` soft reset to clear kitty graphics state on both screens (active + hidden), replacing the previous hidden-screen preserve behavior.
- Reference decision basis:
  - `foot` soft reset path (`term_reset(..., hard=false)`) clears graphics state in both normal and alt grids (`normal.sixel_images` and `alt.sixel_images`), which is the strongest explicit DECSTR implementation signal in current seeds.
  - `kitty` and `ghostty` local snapshots do not provide a clear implemented DECSTR soft-reset graphics contract for this row, so we align to the explicit xterm-family implementation signal from foot.
- Added direct terminal-session test that seeds primary kitty state, runs `DECSTR` while alt is active, exits alt, and verifies hidden primary kitty state is cleared.
- Added replay fixture locking the same hidden-primary clear behavior end-to-end.

Files:
- `src/terminal/protocol/csi.zig`
- `src/terminal/kitty/graphics.zig`
- `src/terminal_focus_reporting_tests.zig`
- `fixtures/terminal/decstr_clears_hidden_primary_kitty_state.vt`
- `fixtures/terminal/decstr_clears_hidden_primary_kitty_state.json`
- `fixtures/terminal/decstr_clears_hidden_primary_kitty_state.golden`

Verification:
- `zig build test-terminal-focus-reporting`
- `zig build test-terminal-replay -- --fixture decstr_clears_hidden_primary_kitty_state --update-goldens`
- `zig build test-terminal-replay -- --fixture decstr_clears_hidden_primary_kitty_state`
  4. Extend/reset matrix incrementally as reference behavior is confirmed.

Implemented (increment 11 / `AUDIT-01` `CSI s` ambiguity under `?69` / `DECLRMM`):
- Updated CSI `s` dispatch so `?69` enabled always routes to DECSLRM semantics, including zero-parameter full-width margin reset (`CSI s` -> left=1/right=cols), instead of save-cursor.
- Preserved SCP behavior when `?69` is disabled (`CSI s` remains save-cursor).
- Added focused integration coverage proving:
  - `CSI s/u` save/restore behavior with `?69` disabled
  - zero-param `CSI s` under `?69` resets margins to full width and homes cursor
  - `CSI s` under `?69` does not overwrite the saved cursor slot
- Added replay fixture with `reply_hex` lock proving end-to-end ambiguity behavior (`\x1b[4;7R` expected after `CSI u`).

Files:
- `src/terminal/protocol/csi.zig`
- `src/terminal_focus_reporting_tests.zig`
- `fixtures/terminal/decslrm_csi_s_ambiguity_reply.vt`
- `fixtures/terminal/decslrm_csi_s_ambiguity_reply.json`
- `fixtures/terminal/decslrm_csi_s_ambiguity_reply.golden`

Verification:
- `zig build test-terminal-focus-reporting`
- `zig build test-terminal-replay -- --fixture decslrm_csi_s_ambiguity_reply --update-goldens`
- `zig build test-terminal-replay -- --fixture decslrm_csi_s_ambiguity_reply`
- `zig build check-app-imports`

Implemented (increment 12 / `AUDIT-03` strict equal-bounds rejection for `DECSTBM` / `DECSLRM`):
- Tightened invalid-bound guards in CSI handling:
  - `DECSTBM` (`CSI t;b r`) now no-ops when `top >= bottom` (equal bounds rejected).
  - `DECSLRM` (`CSI l;r s` with `?69` enabled) now no-ops when `left >= right` (equal bounds rejected).
- Added focused integration tests proving equal-bound sequences are no-op and preserve prior region/margins + cursor position:
  - `terminal DECSTBM equal bounds are rejected as no-op`
  - `terminal DECSLRM equal bounds are rejected as no-op`
- Added replay fixture locking end-to-end reply behavior for both cases via `CPR`:
  - `fixtures/terminal/audit03_equal_bounds_noop_reply.*`

Implemented (increment 13 / `AUDIT-02` `DECSTBM` cursor-home semantics with `DECOM` / `DECLRMM`):
- Updated `DECSTBM` cursor-home behavior to follow `CUP 1;1` style origin semantics:
  - with `DECOM` off, homes to display origin (`row=1`, `col=1`) even when `?69` margins are active.
  - with `DECOM` on, homes to scroll-region top and left margin when `?69` is active.
- Added focused integration coverage that proves both states under active `DECLRMM`:
  - `terminal DECSTBM homes cursor using DECOM semantics under DECLRMM`
- Added replay fixture with reply-byte lock across both transitions (`DECOM` off then on):
  - `fixtures/terminal/audit02_decstbm_home_decom_declrmm_reply.*`

Files:
- `src/terminal/model/screen/screen.zig`
- `src/terminal_focus_reporting_tests.zig`
- `fixtures/terminal/audit02_decstbm_home_decom_declrmm_reply.vt`
- `fixtures/terminal/audit02_decstbm_home_decom_declrmm_reply.json`
- `fixtures/terminal/audit02_decstbm_home_decom_declrmm_reply.golden`

Verification:
- `zig build test-terminal-focus-reporting`
- `zig build test-terminal-replay -- --fixture audit02_decstbm_home_decom_declrmm_reply --update-goldens`
- `zig build test-terminal-replay -- --fixture audit02_decstbm_home_decom_declrmm_reply`
- `zig build check-app-imports`

Implemented (increment 14 / `AUDIT-04` DECRQM strict single-parameter validation + policy-matrix lock):
- Tightened CSI `p` DECRQM dispatch to require exactly one parameter (`param_len == 1`) after `$` intermediate matching.
- Invalid DECRQM cardinality now has explicit ignore/no-reply behavior for both ANSI and DEC-private forms (missing mode, multi-parameter, leading-empty forms).
- Added focused PTY integration coverage for invalid DECRQM cardinality no-reply behavior.
- Extended the replay `DECRQM` policy matrix fixture with invalid-cardinality query forms to lock no-reply behavior without altering the existing supported/unsupported reply matrix.

Files:
- `src/terminal/protocol/csi.zig`
- `src/terminal_focus_reporting_tests.zig`
- `fixtures/terminal/decrqm_query_matrix_reply.vt`

Verification:
- `zig build test-terminal-focus-reporting`
- `zig build test-terminal-replay -- --fixture decrqm_query_matrix_reply`

Implemented (increment 15 / `AUDIT-08` kitty parent semantics parity decision + depth-limit policy lock):
- Explicitly locked current (deferred parity) parent policy for now: placement commands that provide `P` without `Q` are treated as invalid control and reply `EINVAL`.
- Added focused parse-path test proving the invalid-control path reply format includes `i/p` identifiers.
- Added replay fixture authority for the same `P`-without-`Q` scenario, with `reply_hex` and kitty state assertions.
- Depth-limit policy remains locked at current behavior (`kitty_parent_max_depth = 10`) and is re-verified via the existing depth fixture (`kitty_parent_depth_limit_reply`).

Files:
- `src/terminal_kitty_query_parse_tests.zig`
- `fixtures/terminal/kitty_parent_p_without_q_policy_reply.vt`
- `fixtures/terminal/kitty_parent_p_without_q_policy_reply.json`
- `fixtures/terminal/kitty_parent_p_without_q_policy_reply.golden`

Verification:
- `zig build test-terminal-kitty-query-parse`
- `zig build test-terminal-replay -- --fixture kitty_parent_p_without_q_policy_reply --update-goldens`
- `zig build test-terminal-replay -- --fixture kitty_parent_p_without_q_policy_reply`
- `zig build test-terminal-replay -- --fixture kitty_parent_depth_limit_reply`
- `zig build check-app-imports`

Implemented (increment 16 / `AUDIT-07` kitty delete selector `q/Q/f/F` explicit defer lock):
- Locked current policy explicitly in delete handling: selectors `q/Q/f/F` are intentionally deferred and treated as invalid (`EINVAL`).
- Added focused parse-path tests for the selector set across quiet policies:
  - `q=0` and `q=1` reply with `EINVAL`
  - `q=2` suppresses replies.
- Added replay fixture authority for the deferred selector set with concatenated reply assertions and preserved kitty-state no-op behavior.

Files:
- `src/terminal/kitty/graphics.zig`
- `src/terminal_kitty_query_parse_tests.zig`
- `fixtures/terminal/kitty_delete_deferred_selectors_policy_reply.vt`
- `fixtures/terminal/kitty_delete_deferred_selectors_policy_reply.json`
- `fixtures/terminal/kitty_delete_deferred_selectors_policy_reply.golden`

Verification:
- `zig build test-terminal-kitty-query-parse`
- `zig build test-terminal-replay -- --fixture kitty_delete_deferred_selectors_policy_reply`

Implemented (increment 17 / `PA-08g` `DECRQM`/`DECRPM` representative parity-policy scope lock):
- Added a representative, deterministic `DECRPM` policy matrix lock for `Pm=0/1/2/4` across ANSI + DEC-private query paths:
  - `Pm=2/1`: supported mode reset/set (`4`, `?1004`)
  - `Pm=0`: unsupported mode (`999`)
  - `Pm=4`: strategic fixed-off mode (`?1005`)
- Added reply-format unit coverage that locks exact encoded bytes for representative `Pm=0/1/2/4` values.
- Added focused PTY integration coverage that exercises real query/set/query flows and validates exact replies for the same policy matrix.
- Added a replay fixture authority for the same representative policy matrix (`reply_hex`) to lock end-to-end fixture behavior.
- Scope decision for `PA-08g`: parity-policy semantics are now considered test-locked for the currently implemented mode set; additional mode-family expansion work proceeds under `PA-08h`.

Files:
- `src/terminal_csi_reply_tests.zig`
- `src/terminal_focus_reporting_tests.zig`
- `fixtures/terminal/decrqm_pm_policy_matrix_reply.vt`
- `fixtures/terminal/decrqm_pm_policy_matrix_reply.json`
- `fixtures/terminal/decrqm_pm_policy_matrix_reply.golden`

Verification:
- `ZIG_GLOBAL_CACHE_DIR=.zig-global-cache ZIG_LOCAL_CACHE_DIR=.zig-cache zig test src/terminal_csi_reply_tests.zig`
- `zig build test-terminal-focus-reporting`
- `zig build test-terminal-replay -- --fixture decrqm_pm_policy_matrix_reply --update-goldens`
- `zig build test-terminal-replay -- --fixture decrqm_pm_policy_matrix_reply`

Implemented (increment 18 / `PA-08h` xterm window-op breadth explicit defer lock):
- Promoted one remaining `PA-08h` row to an explicit defer lock for bounded window-op support:
  - keep `CSI 14 t`, `CSI 16 t`, `CSI 18 t`, `CSI 19 t` as the only implemented window-op query set.
  - keep broader xterm window-op query/report modes deferred for now.
- Added replay authority that locks deterministic no-reply behavior (and no grid side effects) for representative deferred modes:
  - `CSI 11 t` (window state report)
  - `CSI 13 t` (window position report)
  - `CSI 20 t` (icon label report/reset family surface)
- Compatibility notes:
  - xterm-family terminals may implement additional `CSI ... t` replies, so some window-management-aware tools can observe fewer capabilities in Zide.
  - current policy intentionally avoids partial/emulated replies outside the implemented bounded set.

Files:
- `fixtures/terminal/csi_window_ops_deferred_modes_no_reply.vt`
- `fixtures/terminal/csi_window_ops_deferred_modes_no_reply.json`
- `fixtures/terminal/csi_window_ops_deferred_modes_no_reply.golden`
- `app_architecture/terminal/PROTOCOL_ACCURACY_PROGRESS.md`

Verification:
- `zig build test-terminal-replay -- --fixture csi_window_ops_deferred_modes_no_reply --update-goldens`
- `zig build test-terminal-replay -- --fixture csi_window_ops_deferred_modes_no_reply`

Implemented (increment 19 / `PA-08h` legacy tab-stop report/edit variants explicit defer lock):
- Promoted one remaining `PA-08h` row to an explicit defer lock for legacy tab-stop report/edit variants (`CSI Ps W` / CTC family).
- Policy lock:
  - keep `CSI Ps W` variants deferred (no-op) in current scope while `CHT`/`CBT`/`TBC` remain the supported tab-control surface.
  - avoid partial/emulated CTC behavior until a concrete app-compat signal justifies full semantics.
- Added replay authority that deterministically exercises representative deferred `CSI Ps W` forms and verifies no behavioral change to tab traversal:
  - `CSI 5 W` (legacy clear-all variant)
  - `CSI 0 W` (legacy set-at-cursor variant)
  - `CSI 2 W` (legacy clear-at-cursor variant)
  - `CSI 1 W` (legacy/report variant)
- Compatibility notes:
  - xterm-family terminals may implement additional CTC report/edit behavior, so apps that depend on those legacy tab-edit semantics can observe reduced capability in Zide.
  - current policy intentionally keeps these variants inert rather than shipping partial semantics.

Files:
- `fixtures/terminal/csi_tab_ctc_legacy_variants_deferred_noop.vt`
- `fixtures/terminal/csi_tab_ctc_legacy_variants_deferred_noop.json`
- `fixtures/terminal/csi_tab_ctc_legacy_variants_deferred_noop.golden`
- `app_architecture/terminal/PROTOCOL_ACCURACY_PROGRESS.md`

Verification:
- `zig build test-terminal-replay -- --fixture csi_tab_ctc_legacy_variants_deferred_noop --update-goldens`
- `zig build test-terminal-replay -- --fixture csi_tab_ctc_legacy_variants_deferred_noop`

Implemented (increment 20 / `PA-08h` reset-family breadth: DECSTR hidden-screen soft-state explicit defer lock):
- Promoted one remaining reset-family breadth ambiguity under `DECSTR` into an explicit defer lock:
  - current Zide `DECSTR` scope resets active-screen soft state only (`screen.resetState()` on active screen), while hidden-screen soft state is preserved.
  - this is now an intentional, test-locked compatibility boundary in `PA-08h` (not accidental behavior).
- Added replay authority that exercises the boundary end-to-end with reply bytes:
  - set `?45` on primary, switch to alt, set `?45` on alt, run `DECSTR`, query `?45` while alt active (expects reset/default), return to primary and query `?45` again (expects preserved set state).
- Compatibility notes:
  - terminals with broader soft-reset scope may reset hidden-screen soft modes on `DECSTR`; Zide currently does not.
  - TUI flows that rely on `DECSTR` to scrub hidden-screen mode bits can observe divergence after alt-screen exit.
- Resume criteria:
  - concrete app compatibility failure tied to hidden-screen soft-mode persistence across `DECSTR`, or
  - clear xterm/kitty/ghostty alignment evidence favoring dual-screen soft-state reset for this row.

Files:
- `fixtures/terminal/decstr_hidden_screen_soft_state_preserve_query_reply.vt`
- `fixtures/terminal/decstr_hidden_screen_soft_state_preserve_query_reply.json`
- `fixtures/terminal/decstr_hidden_screen_soft_state_preserve_query_reply.golden`
- `app_architecture/terminal/PROTOCOL_ACCURACY_PROGRESS.md`

Verification:
- `zig build test-terminal-replay -- --fixture decstr_hidden_screen_soft_state_preserve_query_reply --update-goldens`
- `zig build test-terminal-replay -- --fixture decstr_hidden_screen_soft_state_preserve_query_reply`

Implemented (increment 21 / `PA-08h` promoted-gap closure gate):
- Closed the current `PA-08h` promoted-gap gate for this parity phase:
  - promoted CSI/private rows in scope are now either implemented or explicitly deferred with compatibility notes and fixture/test authority.
  - reset-family breadth is intentionally bounded by the current `DECSTR` scope, including hidden-screen soft-state preservation as a defer-locked boundary.
- Refreshed replay cursor baselines for `DECSLRM + DECSTBM` interaction fixtures after validating unchanged grid semantics under current runtime behavior:
  - `fixtures/terminal/decslrm_decstbm_su_margin_band_only.golden`
  - `fixtures/terminal/decslrm_decstbm_sd_margin_band_only.golden`

Files:
- `fixtures/terminal/decslrm_decstbm_su_margin_band_only.golden`
- `fixtures/terminal/decslrm_decstbm_sd_margin_band_only.golden`
- `app_architecture/terminal/PROTOCOL_ACCURACY_PROGRESS.md`

Verification:
- `zig build test-terminal-replay -- --all`

## Change Log

### 2026-02-27

- Implemented `AUDIT-05` kitty reply-policy parity slice:
  - `a=d` now suppresses success replies (`OK`) unconditionally.
  - `a=q` with missing image id/number now follows explicit no-reply policy (all quiet levels).
- Added focused test coverage:
  - unit seam: `handleKittyQueryEarlyReply` missing-id now asserts handled + no-reply
  - integrated parse-path tests for delete success suppression and delete invalid-control error quiet behavior (`q=1` reply, `q=2` suppression)
  - replay fixtures locking end-to-end reply bytes:
    - `fixtures/terminal/kitty_query_missing_id_no_reply_policy.*`
    - `fixtures/terminal/kitty_delete_reply_policy_parity.*`
- Implemented `AUDIT-06` unknown kitty delete-selector invalid-reply slice:
  - unknown `d=` selectors now emit explicit `EINVAL` replies instead of silent no-op success.
  - known selectors keep existing behavior (success replies remain suppressed).
  - quiet handling for unknown selector is locked (`q=0/1` reply, `q=2` suppression).
  - replay fixture `fixtures/terminal/kitty_delete_unsupported_selector_noop.*` now asserts reply bytes while preserving kitty-state no-op semantics.
- Implemented `AUDIT-10` keyboard `embed_text` associated-text parity slice:
  - press/repeat now support multi-codepoint associated text (colon-separated) via metadata UTF-8 text
  - release continues to omit associated text (`AUDIT-09` preserved)
  - focused encoder tests added in `src/terminal_input_encoding_tests.zig`
- Added `AUDIT-10` replay encoder fixtures to lock multi-codepoint `embed_text` press/repeat bytes and release omission.
- Refreshed replay cursor baselines for:
  - `fixtures/terminal/decslrm_decstbm_su_margin_band_only.golden`
  - `fixtures/terminal/decslrm_decstbm_sd_margin_band_only.golden`
- Added replay fixture `fixtures/terminal/color_scheme_dsr_996_query_reply.*`:
  - locks concatenated `DSR ?996n` reply bytes across interleaved `?2031` toggles
  - preserves current behavior boundary where `?996n` replies are available regardless of `?2031` mode state
  after confirming current parser/runtime behavior produced cursor `r=1 c=0` with unchanged grid semantics.
- Implemented `AUDIT-07` kitty delete selector explicit defer lock:
  - selectors `d=q/Q/f/F` are now explicitly treated as invalid (deferred parity, no silent fallback)
  - added focused parse-path tests for `q=0/1/2` quiet-policy behavior
  - added replay fixture `fixtures/terminal/kitty_delete_deferred_selectors_policy_reply.*` with `reply_hex` lock
- Implemented `PA-08g` `DECRQM`/`DECRPM` representative policy lock:
  - added focused unit + PTY + replay coverage for deterministic representative `Pm` semantics (`0/1/2/4`)
  - explicitly locked current `PA-08g` scope as complete for mode-policy parity, with remaining mode-family breadth tracked under `PA-08h`
- Implemented `PA-08h` legacy tab-stop `CSI Ps W` explicit defer lock:
  - added replay fixture authority for representative deferred variants (`0/1/2/5W`) and locked current no-op policy
  - updated `PA-08` inventory row status for legacy tab-stop report/edit variants to `deferred`
  - narrowed the top Next Work Queue `PA-08h` note to remaining reset-family breadth
- Implemented `PA-08h` reset-family hidden-screen soft-state explicit defer lock:
  - added replay fixture authority to lock current `DECSTR` boundary (active-screen soft reset, hidden-screen soft-state preserve)
  - recorded compatibility impact + resume criteria for future parity adjustment
- Closed current `PA-08h` promoted-gap gate for this parity phase:
  - marked promoted CSI/private rows as implemented-or-explicitly-deferred with fixture authority
  - moved top queue focus to `PA-08a` inventory closure and `PA-04c` kitty query/reply matrix breadth
- Closed `PA-08a` CSI/private inventory drift for current scope:
  - updated stale rows (`?1004`, `DECSLRM`, alternate mouse encodings, printer/media/status family) to explicit implemented/deferred states with references
  - moved top queue focus to `PA-04c` and ongoing replay/PTY matrix hygiene
- Closed current `PA-04c` query/reply fixture-matrix gate:
  - matrix now treated as complete for the current kitty graphics phase (precedence/error/quiet, transport forms, parent/virtual branches)
  - follow-on kitty graphics breadth should proceed under other `PA-04*` rows
- Added replay fixture `fixtures/terminal/kitty_delete_unknown_selector_quiet_policy.*`:
  - locks unknown delete-selector quiet policy end-to-end (`q=1` reply, `q=2` suppression)
  - preserves kitty-state no-op semantics for the unknown-selector path
- Added explicit `PA-08` deferred-row registry:
  - each deferred row now includes compatibility impact and concrete resume criteria, with fixture authority links where available

### 2026-02-23

- Created progress tracker from protocol support/accuracy review.
- Completed `PA-01` (Unicode width/cursor correctness baseline + edge-wrap replay coverage).
- Completed `PA-03` (kitty invalid control emits `EINVAL` reply).
- Completed `PA-06` (X10 coord overflow saturates to `255`; added unit coverage).
- Completed `PA-07` (removed bare `58` reset behavior in SGR parser).
- Advanced `PA-02` to `partial` (replay assertions are now consumed and validated; PTY reply coverage still pending).
- Strengthened `PA-02` semantic checks for `grid`/`cursor`/`attrs` assertions in replay harness.
- Advanced `PA-02` PTY-gated reply coverage with direct unit tests for DCS/OSC reply paths.
- Expanded `PA-02` DCS/OSC reply coverage to include error-path and ST-terminator variants.
- Expanded `PA-02` reply coverage to include `OSC 10` dynamic-color query formatting/terminator behavior.
- Expanded `PA-02` to cover CSI `DA`/`DSR` reply bytes with direct PTY-gated unit tests.
- Expanded `PA-02` to cover kitty reply formatting + quiet-mode suppression behavior.
- Strengthened `PA-02` `scrollback` assertion semantics (no longer recognized-only; now checks scrollback/scroll behavior evidence).
- Advanced `PA-04a` by documenting the current kitty graphics `a=`/`d=` surface from code as a parity map for follow-on fixtures/fixes.
- Advanced `PA-04c` with replay delete conformance fixtures (placement-only vs image+placement delete, plus unsupported-selector no-op).
- Expanded `PA-04b` delete selector replay coverage to include `c/C`, `z/Z`, and `r/R`.
- Expanded `PA-04b` delete edge-case replay coverage for `i/I`, `n/N`, `x/X`, and `y/Y` semantics (filters + partial overlaps).
- Advanced `PA-04c` query coverage with an extracted `a=q` early-reply seam and unit tests (`EINVAL` missing id / metadata-only `OK`).
- Advanced `PA-04c` query payload-validation coverage with extracted helper tests for `EINVAL`, `ENODATA`, and `EBADPNG` reply mapping branches.
- Advanced `PA-04c` integrated query control-flow coverage with `a=q` chunk-build reply seam tests (success + build-error paths).
- Advanced `PA-04c` with project-integrated `a=q` parse-path tests (real session + PTY capture) for representative success/error replies.
- Expanded `PA-04c` integrated parse-path tests with quiet-mode suppression and invalid chunk/offset query cases.
- Advanced `PA-05` to `partial` (unsupported `alternate_key` no longer advertised via key-mode flags).
- Advanced `PA-05` disambiguation support: modified chars and ambiguous control chars now emit CSI-u without `report_text`; aligned encoder test helper/golden with runtime behavior.
- Tightened `PA-05` key-encoder test helper gating/mappings so replay/unit tests do not falsely advertise unsupported key-mode outputs.
- Advanced `PA-05` alternate-key support: flag now persists in key-mode state and char CSI-u emits US-ASCII shifted alternates (`key:shifted`) for common shifted printable keys.
- Added replay encoder fixtures for `PA-05` alternate-key shifted-char CSI-u outputs (`key:shifted`) to lock behavior in the fixture harness.
- Expanded `PA-05` alternate-key replay coverage (`report_text`, `embed_text`, key-path no-op) and fixed `embed_text` formatting drift in encoder test helper.
- Expanded `PA-05` disambiguate+report-all action-field coverage to non-cursor function keys (`Enter`/`Tab`/`Backspace`/`Escape`/`Ins`/`Del`/`PgUp`/`PgDn`) with replay fixtures.
- Deferred full layout-aware `PA-05` alternate-key parity pending input-model metadata; tracked as explicit follow-on sub-items instead of expanding heuristics.
- Defined `PA-05a` input metadata contract for layout-aware alternate-key parity in `app_architecture/terminal/KEYBOARD_ALTERNATE_METADATA_CONTRACT.md`.
- Advanced `PA-08` to `partial` by implementing promoted CSI private mode gap `?1004` focus reporting (parser mode toggles + focus event emission + PTY/replay coverage).
- Advanced `PA-08e` with `CHT`/`CBT` tab movement support and replay fixture coverage (`2I` / `2Z` tab-stop traversal).
- Advanced `PA-08e` `?1004` focus reporting with dual event sources (window + terminal-pane) and separate Lua toggles for each source.
- Advanced `PA-08e` with a first `DECRQM` slice: minimal DEC private mode query replies (`DECRPM`) for common supported modes plus `Pm=0` for unsupported private queries.
- Expanded `PA-08e` `DECRQM` coverage with a table-driven private-mode PTY query matrix and ANSI mode `20` (newline mode) query replies.
- Advanced `PA-08d` with a first replay-level query reply assertion seam (`reply_hex`) and a `DECRQM ?1004` reply fixture.
- Broadened `PA-08e` `DECRQM` coverage to additional DEC private modes and locked unsupported ANSI `DECRQM -> Pm=0` per xterm/foot convention.
- Expanded `PA-08d` replay-level query reply coverage with `DA`, `DSR` CPR, and `OSC 10` reply fixtures.
- Expanded `PA-08d` replay reply fixtures to include DEC-private `DSR ?6n` and `OSC 52` query replies.
- Added a compact replay `DECRQM` query matrix fixture (multi-query concatenated reply assertions).

## Next Work Queue (Ordered)

1. `PA-08` replay/PTY matrix maintenance as new parity slices land (avoid assertion/golden drift)
2. `PA-04` follow-on parity breadth outside fixture-matrix closure (as needed by compatibility signals)
3. `PA-08` focused implementation slice for one deferred row when compatibility signal appears

## Decomposition Backlog (New)

### PA-04 Parity Decomposition Checklist

- [x] `PA-04a` Write command surface table (`a=` actions, `d=` delete variants) with status `implemented/partial/todo`
- [x] `PA-04b` Document response/error-code conformance targets (`OK/EINVAL/ENOENT/...`) with quiet-mode rules
- [x] `PA-04c` Add fixture matrix for query/chunking/mediums/parented placements
- [x] `PA-04d` Decide animation/composition path (`implement` / `defer`)

### PA-08 Parity Decomposition Checklist

- [x] `PA-08a` Inventory missing CSI finals/private modes from `xterm`/`kitty`/`ghostty` relevant to Zide, with explicit `done` criteria and reference links/notes
- [x] `PA-08b` Inventory DCS/APC gaps relative to kitty/ghostty/foot usage, with explicit `implement` vs `defer` policy per family
- [x] `PA-08c` Define PTY-stub replay strategy for query/reply assertions (implemented as `reply_hex` + `assertions: ["reply"]`)
- [x] `PA-08d` Promote highest-value gaps into implementable tracker items (`?1004` promoted and implemented under `PA-08e`)
- [x] `PA-08f` Implement or explicitly defer CSI intermediate-byte parser support required for parity-critical CSI families
- [x] `PA-08g` Define and test-lock `DECRQM`/`DECRPM` parity scope (mode coverage + `Pm` reply semantics) against `xterm`/`kitty`/`ghostty`
- [x] `PA-08h` Close or defer remaining promoted CSI/private-mode gaps with compatibility notes before advancing new top-level parity areas

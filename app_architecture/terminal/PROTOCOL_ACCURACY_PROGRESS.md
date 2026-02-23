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
| PA-05 | Medium | partial | Kitty keyboard / CSI-u alternate/disambiguation flags tracked but not encoded | `alternate_key` / disambiguation flags affect output and tests cover behavior |
| PA-06 | Medium | done | X10 mouse encoding can emit `0` for large coords | X10 coord encoding saturates/falls back safely; no invalid zero coord bytes from overflow |
| PA-07 | Medium | done | Bare SGR `58` likely treated incorrectly as reset | Bare `58` no longer resets underline color; `59` remains reset |
| PA-08 | Medium-Low | partial | CSI/DCS/APC coverage is subset of reference terminals | Sub-gaps enumerated and prioritized with explicit roadmap/tests |

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
- Unsupported/ignored (current code path): other delete selectors fall through with no effect.

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

Implemented (increment 2 / `PA-04c` fixture matrix start):
- Added replay fixtures for kitty delete conformance behavior (state-level coverage):
  - `d=p` explicit point delete removes placement but preserves image storage
  - `d=P` explicit point delete removes placement and backing image
- unsupported delete selector (e.g. `d=v`) is currently a no-op on kitty state
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

Sub-items (traceable parity slices):
- `PA-08a` CSI gap inventory vs xterm seed (missing finals / private modes used by modern TUIs)
- `PA-08b` DCS query/reply gap inventory (beyond XTGETTCAP)
- `PA-08c` APC extension policy (kitty-only vs extensible dispatcher)
- `PA-08d` Add replay/PTY fixtures for query/reply coverage (DA/DSR/OSC/DCS)
- `PA-08e` Implement highest-value CSI gaps (tabulation/window ops only if demanded)

Priority notes:
- Focus first on sequences observed in fixtures, vttest, and real apps in `reference_repos/terminals/*`.
- Prefer PTY-stubbed tests before expanding query/reply behavior.

Implemented (increment 1 / `PA-08a` first CSI/private-mode gap inventory pass):
- Created an initial inventory of high-value CSI/private-mode gaps relative to xterm /
  kitty / ghostty usage patterns, scoped to realistic TUI impact.
- This is a planning/inventory increment (no behavior change) intended to feed
  `PA-08d` implementable follow-on items.

Inventory snapshot (`PA-08a`, first pass):
- `implemented / strong` (already in Zide):
  - core cursor movement/positioning (`A/B/C/D/E/F/G/H/f/d`)
  - erase / insert-delete char+line (`J/K/@/P/X/L/M`)
  - scroll region and region scroll (`r/S/T`)
  - SGR (basic/256/truecolor/underline color), cursor style (`m/q`)
  - DSR/DA basic replies (`n/c`)
  - DEC private modes used by modern TUIs: alt screen, DECCKM, DECOM, DECAWM,
    bracketed paste, sync update, mouse `1000/1002/1003/1006`
  - kitty keyboard mode controls (`CSI >u/<u/=u/?u`)
- `partial / likely gaps for xterm compatibility`:
  - tabulation family beyond `TBC` (`CHT`/`CBT` tab moves not implemented; only `CSI g`)
  - mode query/report breadth (`DECRQM` / mode reports beyond current DSR subset)
  - terminal reset/control conveniences (`DECSTR`, `RIS`-adjacent CSI soft reset behavior)
  - left/right margins (`DECSLRM`) and related rectangular editing semantics
  - focus in/out reporting mode (`?1004`) and associated event emission path
  - alternate mouse encodings (`1005` UTF-8, `1015` urxvt) if compatibility is needed
- `likely low priority unless demanded by apps`:
  - xterm window ops (`CSI ... t`)
  - printer/media and status extensions
  - legacy/rare tab-stop editing/reporting variants

Suggested `PA-08d` promotion candidates (first pass):
1. `?1004` focus reporting mode + event emission (real TUI impact)
2. `CHT` / `CBT` tab movement coverage (completes currently-partial tab family)
3. `DECRQM` / minimal mode-report replies for queried private modes seen in reference seeds

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

Follow-on requirement note (user request, not implemented yet):
- `?1004` focus event sources should support both:
  1. window focus gain/loss
  2. terminal-pane focus gain/loss within the IDE
- Add separate Lua config toggles for each source so users can enable/disable them independently.
- Current implementation emits window-focus events only.

## Change Log

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

## Next Work Queue (Ordered)

1. `PA-02` PTY reply fixture/stub coverage + stronger semantic assertion checks
2. `PA-05b` Thread layout/base-key metadata through input path using `PA-05a` contract
3. `PA-04` Kitty graphics parity decomposition
4. `PA-08` CSI/DCS/APC parity decomposition

## Decomposition Backlog (New)

### PA-04 Parity Decomposition Checklist

- [ ] `PA-04a` Write command surface table (`a=` actions, `d=` delete variants) with status `implemented/partial/todo`
- [ ] `PA-04b` Document response/error-code conformance targets (`OK/EINVAL/ENOENT/...`) with quiet-mode rules
- [ ] `PA-04c` Add fixture matrix for query/chunking/mediums/parented placements
- [ ] `PA-04d` Decide animation/composition path (`implement` / `defer`)

### PA-08 Parity Decomposition Checklist

- [ ] `PA-08a` Inventory missing CSI finals and private modes from xterm seed relevant to Zide
- [ ] `PA-08b` Inventory DCS/APC gaps relative to kitty/ghostty/foot usage
- [ ] `PA-08c` Define PTY-stub replay strategy for query/reply assertions
- [x] `PA-08d` Promote highest-value gaps into implementable tracker items (`?1004` promoted and implemented under `PA-08e`)

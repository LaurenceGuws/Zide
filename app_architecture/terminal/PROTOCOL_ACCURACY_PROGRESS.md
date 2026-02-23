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

Query coverage note (`PA-04c` remaining):
- `a=q` reply-byte conformance is still partial, but now includes direct tests for early replies and payload-validation reply branches via extracted helpers.
- Added a small extracted seam for the early `a=q` parse-path replies (`missing image id`, metadata-only query); these cases now have direct unit coverage.
- Payload/image reply coverage status:
  - covered via extracted helpers: `EINVAL` (chunked/load-failure), `ENODATA` size reply formatting, build-error message mapping (`EBADPNG`/`EINVAL`)
  - remaining gap: full integrated `a=q` payload decode/build-image parse-path tests (actual decode/build invocation and success cases)

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
- `todo`

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
- Advanced `PA-04c` query coverage with an extracted `a=q` early-reply seam and unit tests (`EINVAL` missing id / metadata-only `OK`).
- Advanced `PA-04c` query payload-validation coverage with extracted helper tests for `EINVAL`, `ENODATA`, and `EBADPNG` reply mapping branches.
- Advanced `PA-04c` integrated query control-flow coverage with `a=q` chunk-build reply seam tests (success + build-error paths).
- Advanced `PA-05` to `partial` (unsupported `alternate_key` no longer advertised via key-mode flags).
- Advanced `PA-05` disambiguation support: modified chars and ambiguous control chars now emit CSI-u without `report_text`; aligned encoder test helper/golden with runtime behavior.
- Tightened `PA-05` key-encoder test helper gating/mappings so replay/unit tests do not falsely advertise unsupported key-mode outputs.
- Advanced `PA-05` alternate-key support: flag now persists in key-mode state and char CSI-u emits US-ASCII shifted alternates (`key:shifted`) for common shifted printable keys.
- Added replay encoder fixtures for `PA-05` alternate-key shifted-char CSI-u outputs (`key:shifted`) to lock behavior in the fixture harness.
- Expanded `PA-05` alternate-key replay coverage (`report_text`, `embed_text`, key-path no-op) and fixed `embed_text` formatting drift in encoder test helper.

## Next Work Queue (Ordered)

1. `PA-02` PTY reply fixture/stub coverage + stronger semantic assertion checks
2. `PA-05` Implement alternate-key output + stronger disambiguation semantics
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
- [ ] `PA-08d` Promote highest-value gaps into implementable tracker items

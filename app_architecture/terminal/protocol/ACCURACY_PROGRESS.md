# Terminal Protocol Accuracy Progress

Date started: 2026-02-23
Source review: terminal protocol/code audit against `reference_repos/terminals/*` quality seeds
Owner: agent

## Purpose

Track protocol support/accuracy findings from the review as discrete, traceable fixes.

This file is the active protocol parity tracker.

Use [TERMINAL_PROTOCOL_ACCURACY_REVIEW_2026-02-23.md](/home/home/personal/zide/docs/review/TERMINAL_PROTOCOL_ACCURACY_REVIEW_2026-02-23.md)
for the detailed source-review evidence, implementation increments, and dated
change history that used to live inline here.

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

## Historical Evidence

Detailed findings, implementation increments, and dated protocol parity history
now live in
[TERMINAL_PROTOCOL_ACCURACY_REVIEW_2026-02-23.md](/home/home/personal/zide/docs/review/TERMINAL_PROTOCOL_ACCURACY_REVIEW_2026-02-23.md).

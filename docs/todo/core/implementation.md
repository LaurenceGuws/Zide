# Core Zig Stability/Hygiene Queue

Active queue for the post-Android-pause core cleanup lane.

## Mission

Freeze product behavior while cleaning core seams so the base Zig product is
stable, reviewable, and ready for the next expansion phase.

## Current State

- Android lane is intentionally paused except blocker regressions.
- Core lane is now primary.
- Current active macro batch: `CZH-B2` (`architect_review_pending`).

## Campaign Goals

1. stability first: user stress tests run continuously while cleanup lands
2. enforce probe/debug hygiene on main branch product paths
3. naming/ownership cleanup
4. normalize Android-driven FFI/rendering advancements into shared core seams

## Hard Contracts

- Behavior freeze by default during hygiene cuts.
- No compatibility sludge.
- No stale debug/probe caller residue in tracked product code.
- Batch closure requires doc updates + validation record.

## Validation Baseline

- `zig build`
- `zig build test`
- `zig build -Dmode=terminal`
- `zig build -Dmode=editor`
- Android regression guard at seam boundaries:
  - `./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac`
  - `./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac`

## Macro Batches

### `CZH-B1` Freeze + Stability Baseline (`accepted`)

Queue line (exact):

- establish behavior-freeze authority plus repeatable stress baseline and drift
  watchlist before broad cleanup

#### Behavior-freeze authority (normative)

During `CZH` hygiene batches, **product behavior is frozen by default**: no
semantic changes, no drive-by refactors, and no compatibility/fallback seams
unless a macro batch explicitly scopes a behavior change and carries its own
test/replay evidence. The default posture is: **measure first, then cut** —
this batch records *what* is stable and *where* drift is allowed to queue
next (`CZH-B2`+), without landing broad cleanup here.

#### Internal milestones (engineer-defined)

| Id | Scope |
| --- | --- |
| `CZH1-M1` | Freeze authority text in this queue + engineer entrypoint + `docs/AGENT_HANDOFF.md` alignment |
| `CZH1-M2` | Stress workload list + pass/fail recording template (below) |
| `CZH1-M3` | First recorded baseline run for mandatory ladder commands |
| `CZH1-M4` | Drift / cleanup watchlist (no implementation in this batch) |
| `CZH1-M5` | One mechanical correctness fix that is clearly bug-fix scope (not behavior policy): `encodeSnapshot` must read `DebugSnapshot.focus_reporting`, not a non-existent `debug.session` field |
| `CZH1-M6` | Super-gate packet + batch handoff to architect |

#### Stress workloads (repeatable)

| Id | Command / intent | Role |
| --- | --- | --- |
| `SL-0` | `zig build` | Mandatory compile gate |
| `SL-1` | `zig build test` | Mandatory automated test gate |
| `SL-2` | `zig build -Dmode=terminal` | Product shape: terminal mode |
| `SL-3` | `zig build -Dmode=editor` | Product shape: editor mode |
| `SL-ext-1` | `zig build test-terminal-replay` | Extended VT replay harness (compile+fixture smoke when green) |
| `SL-ext-2` | `zig build test-terminal-replay-all` | Full golden replay sweep when `SL-ext-1` is green |

#### Pass/fail recording template (copy for each run)

```
date (authoritative): YYYY-MM-DD
host: <short uname / OS note>
git: <describe HEAD or tag>

SL-0  zig build                              PASS|FAIL  (notes)
SL-1  zig build test                         PASS|FAIL  (notes)
SL-2  zig build -Dmode=terminal              PASS|FAIL  (notes)
SL-3  zig build -Dmode=editor                PASS|FAIL  (notes)
SL-ext-1  zig build test-terminal-replay    PASS|FAIL  (notes)
SL-ext-2  zig build test-terminal-replay-all PASS|FAIL (notes)

Android guard (only if seam-touching this batch): compileDebug/ReleaseJavaWithJavac PASS|SKIP (reason)
```

#### First baseline run (recorded)

- **Date:** 2026-04-18  
- **Host:** Linux (engineer session)  
- **Git:** `main` workspace at batch close  
- **SL-0** `zig build` — **PASS**  
- **SL-1** `zig build test` — **PASS**  
- **SL-2** `zig build -Dmode=terminal` — **PASS**  
- **SL-3** `zig build -Dmode=editor` — **PASS**  
- **SL-ext-1** `zig build test-terminal-replay` — **FAIL (compile)**  
  - `replay_harness` still imports moved modules (`core/snapshot.zig`,
    `core/terminal_publication.zig`) that no longer exist at those paths after
    the publication layout move.  
- **SL-ext-2** — **not run** (blocked by `SL-ext-1`)  
- **Android guard** — **SKIP** (no Android seam touched this batch; lane paused)

#### `CZH2-M1` replay harness drift audit (explicit file list)

- `src/terminal/replay_harness.zig` — stale imports (`core/snapshot.zig`,
  `core/terminal_publication.zig`); canonical paths are
  `core/publication/{snapshot,terminal_publication}.zig`. `ReplayPtyCapture` must
  mirror `src/terminal/io/pty_unix.zig` `Pty` field layout when the stub pipe PTY
  is constructed.

#### Drift / cleanup watchlist (prioritized, `CZH-B2`+)

1. **Terminal replay harness compile drift:** **cleared in `CZH-B2`** (imports,
   `Pty` stub fields, `terminal_publication.notePresentedGeneration` re-export).
   **Residual:** fixtures with `reply_hex` still emit `size: 0x0` snapshots vs
   goldens under the PTY capture / `debugFeedBytes` path — needs a focused harness
   lane (not a golden refresh under behavior freeze without root-cause proof).
2. **Generic `*const` core owners:** **partially cleared in `CZH-B2`** via shared
   `src/terminal/core/engine_core_face.zig` `mutableTerminalCore` (scroll + kitty
   call sites). Optional future rename to a single authority-owned symbol per
   `TERMINAL_SUBSYSTEM_LAYERS` remains queue-shaping only.
3. **Probe/debug hygiene (`CZH-B2` scope):** audit hot paths per `AGENTS.md`
   logging policy; remove stale investigation callers.
4. **Naming / ownership (`CZH-B2` scope):** align lingering names with
   `TERMINAL_SUBSYSTEM_LAYERS` + `VT_MATURITY_PURITY_CAMPAIGN` authority.
5. **FFI/render normalization (`CZH-B3` scope):** per queue line when opened.

#### `CZH1-M5` code note (bug fix, not policy)

- `src/terminal/core/publication/snapshot.zig`: `encodeSnapshot` now gates
  `focus_reporting:` output on `debug.focus_reporting` (the field populated by
  `debug_ops.debugSnapshot`), fixing a stale reference to `debug.session` that
  did not exist on `DebugSnapshot`.

#### Architect gate result

- `Review chunk: CZH-B1`
- `Verdict: accepted`
- `Engineer commits reviewed: f4c2e673, 18d556d2`
- `Architect validation spot-check: SL-0..SL-3 PASS; SL-ext-1 FAIL (expected/documented import drift).`
- `Residual risk carried forward: replay harness compile drift remains unresolved.`

### `CZH-B2` Probe/Debug Caller Purge + Naming Hygiene (`architect_review_pending`)

Queue line (exact):

- remove stale investigation callers and normalize naming/ownership across core
  seams without behavior change

Acceptance:

- stale probe/debug callers are removed from active product paths
- naming aligns with subsystem ownership contracts
- no behavior regressions in baseline validation

Internal milestones (`CZH2-M1..M6`, execute sequentially in one batch):

| Id | Scope |
| --- | --- |
| `CZH2-M1` | replay-harness compile drift audit with explicit file list + watchlist update |
| `CZH2-M2` | unblock `SL-ext-1` (`test-terminal-replay`) by fixing moved publication imports and immediate compile fallout |
| `CZH2-M3` | run `SL-ext-2` (`test-terminal-replay-all`) and record baseline result |
| `CZH2-M4` | scoped probe/debug caller purge in touched core seams (no behavior changes) |
| `CZH2-M5` | scoped naming/ownership cleanup in touched seams aligned to subsystem authority docs |
| `CZH2-M6` | super-gate packet + queue/handoff/entrypoint sync for architect review |

`CZH-B2` stop conditions:

- stop only at super-gate or real hard blocker
- target 5–10 validated commits
- maintain behavior freeze and single-path contract

#### `CZH-B2` engineer stress re-baseline (2026-04-18)

- **Date:** 2026-04-18  
- **Host:** Linux (engineer session)  
- **Git:** `main` workspace at `CZH-B2` engineer close  
- **SL-0** `zig build` — **PASS**  
- **SL-1** `zig build test` — **PASS**  
- **SL-2** `zig build -Dmode=terminal` — **PASS**  
- **SL-3** `zig build -Dmode=editor` — **PASS**  
- **SL-ext-1** `zig build test-terminal-replay` — **PASS** (default harness smoke exits 0)  
- **SL-ext-2** `zig build test-terminal-replay-all` — **FAIL** (`GoldenMismatch`: first
  lex-sorted `reply_hex` fixture compares `size: 0x0` observed snapshot vs `5x12`
  golden; non-`reply_hex` fixtures such as `alt_screen_enter_exit` pass)  
- **Android guard** — **SKIP** (lane paused; no Android seam touched)

#### `CZH-B2` super-gate packet (engineer → architect)

- `Review chunk: CZH-B2`
- `Verdict: architect_review_pending`
- `Scope summary:` replay publication import repair; `ReplayPtyCapture` `Pty` stub
  field alignment; `terminal_publication` re-export of
  `presentation_feedback.notePresentedGeneration`; shared
  `engine_core_face.mutableTerminalCore` for scroll + kitty `anytype` core
  resolution (avoids `*const` inference traps and stack-copy hazards on embedded
  `core`); `presentation_feedback` alt-exit completion path dead-local trim;
  replay harness `publication_snapshot` import alias.
- `Residual risks / follow-ups:`
  - `replay reply_hex fixtures:` PTY capture + `debugFeedBytes` path still yields
    empty `TERM_SNAPSHOT` (`0x0`) vs goldens — treat as harness parity / capture
    plumbing, not product golden drift, until proven otherwise.
  - `zig build test-editor` failed in this session with `import of file outside module path`
    errors against `tests/tests_main.zig` (likely toolchain / test-root mismatch;
    not touched by this batch).
- `Architect validation request:` rerun SL ladder + decide whether `reply_hex`
  replay failures gate `CZH-B3` or warrant a `CZH-B2.1` harness sub-batch.

### `CZH-B3` Android-Driven FFI/Render Normalization (`planned`)

Queue line (exact):

- normalize Android-proven FFI/render seam improvements into shared core layers
  with loose coupling preserved

Acceptance:

- shared seam contracts are explicit and platform-agnostic
- Android-specific glue stays platform-owned
- core runtime/ffi/render ownership is clearer than pre-batch baseline

## Response Contract

Every batch update must include:

- `LABELS`
- `#DONE`
- `#OUTSTANDING`
- `COMMITS`
- `VALIDATION`
- `Blocked by Archtect review needed: true|false` (Engineer)
- `Blocked by humain review needed: true|false` (Architect)

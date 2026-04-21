# Core Zig Stability/Hygiene Queue

Active queue for the post-Android-pause core cleanup lane.

## Mission

Freeze product behavior while cleaning core seams so the base Zig product is
stable, reviewable, and ready for the next expansion phase.

## Current State

- Android lane is intentionally paused except blocker regressions.
- Core lane is now primary.
- Current active macro batch: `CZH-B79` (in_progress, super-gate `CZH-GATE-133`). Sprint `CZH-S74` in progress.
- Previous batch: `CZH-B59` (accepted, `CZH-GATE-113`). Sprint `CZH-S54` accepted.
- Sprint authority: `docs/todo/core/JIRA_BOARD.md`
- Accepted sprint: `CZH-S36` (`CZH-B41`, `CZH-GATE-95`). Checkpoint: `docs/todo/core/CZH_S36_CHECKPOINT.md`.
- Accepted sprint: `CZH-S37` (`CZH-B42`, `CZH-GATE-96`). Checkpoint: `docs/todo/core/CZH_S37_CHECKPOINT.md`.
- Accepted sprint: `CZH-S38` (`CZH-B43`, `CZH-GATE-97`). Checkpoint: `docs/todo/core/CZH_S38_CHECKPOINT.md`.
- Accepted sprint: `CZH-S39` (`CZH-B44`, `CZH-GATE-98`). Checkpoint: `docs/todo/core/CZH_S39_CHECKPOINT.md`.
- Accepted sprint: `CZH-S55` (`CZH-B60`, `CZH-GATE-114`). Checkpoint: `docs/todo/core/CZH_S55_CHECKPOINT.md`.
- Accepted sprint: `CZH-S56` (`CZH-B61`, `CZH-GATE-115`). Checkpoint: `docs/todo/core/CZH_S56_CHECKPOINT.md`.
- Accepted sprint: `CZH-S57` (`CZH-B62`, `CZH-GATE-116`). Checkpoint: `docs/todo/core/CZH_S57_CHECKPOINT.md`.
- Accepted sprint: `CZH-S58` (`CZH-B63`, `CZH-GATE-117`). Checkpoint: `docs/todo/core/CZH_S58_CHECKPOINT.md`.
- Accepted sprint: `CZH-S59` (`CZH-B64`, `CZH-GATE-118`). Checkpoint: `docs/todo/core/CZH_S59_CHECKPOINT.md`.
- Accepted sprint: `CZH-S60` (`CZH-B65`, `CZH-GATE-119`). Checkpoint: `docs/todo/core/CZH_S60_CHECKPOINT.md`.
- Accepted sprint: `CZH-S61` (`CZH-B66`, `CZH-GATE-120`). Checkpoint: `docs/todo/core/CZH_S61_CHECKPOINT.md`.
- Accepted sprint: `CZH-S62` (`CZH-B67`, `CZH-GATE-121`). Checkpoint: `docs/todo/core/CZH_S62_CHECKPOINT.md`.
- Accepted sprint: `CZH-S63` (`CZH-B68`, `CZH-GATE-122`). Checkpoint: `docs/todo/core/CZH_S63_CHECKPOINT.md`.
- Accepted sprint: `CZH-S64` (`CZH-B69`, `CZH-GATE-123`). Checkpoint: `docs/todo/core/CZH_S64_CHECKPOINT.md`.
- Accepted sprint: `CZH-S65` (`CZH-B70`, `CZH-GATE-124`). Checkpoint: `docs/todo/core/CZH_S65_CHECKPOINT.md`.
- Accepted sprint: `CZH-S66` (`CZH-B71`, `CZH-GATE-125`). Checkpoint: `docs/todo/core/CZH_S66_CHECKPOINT.md`.
- Accepted sprint: `CZH-S67` (`CZH-B72`, `CZH-GATE-126`). Checkpoint: `docs/todo/core/CZH_S67_CHECKPOINT.md`.
- Accepted sprint: `CZH-S68` (`CZH-B73`, `CZH-GATE-127`). Checkpoint: `docs/todo/core/CZH_S68_CHECKPOINT.md`.
- Accepted sprint: `CZH-S69` (`CZH-B74`, `CZH-GATE-128`). Checkpoint: `docs/todo/core/CZH_S69_CHECKPOINT.md`.
- Accepted sprint: `CZH-S70` (`CZH-B75`, `CZH-GATE-129`). Checkpoint: `docs/todo/core/CZH_S70_CHECKPOINT.md`.
- Accepted sprint: `CZH-S71` (`CZH-B76`, `CZH-GATE-130`). Checkpoint: `docs/todo/core/CZH_S71_CHECKPOINT.md`.
- Accepted sprint: `CZH-S65` (`CZH-B70`, `CZH-GATE-124`). Checkpoint: `docs/todo/core/CZH_S65_CHECKPOINT.md`.
- Accepted sprint: `CZH-S54` (`CZH-B59`, `CZH-GATE-113`). Checkpoint: `docs/todo/core/CZH_S54_CHECKPOINT.md`.
- Accepted sprint: `CZH-S52` (`CZH-B57`, `CZH-GATE-111`). Checkpoint: `docs/todo/core/CZH_S52_CHECKPOINT.md`.
- Accepted sprint: `CZH-S53` (`CZH-B58`, `CZH-GATE-112`). Checkpoint: `docs/todo/core/CZH_S53_CHECKPOINT.md`.
- Accepted sprint: `CZH-S51` (`CZH-B56`, `CZH-GATE-110`). Checkpoint: `docs/todo/core/CZH_S51_CHECKPOINT.md`.
- Accepted sprint: `CZH-S50` (`CZH-B55`, `CZH-GATE-109`). Checkpoint: `docs/todo/core/CZH_S50_CHECKPOINT.md`.
- Accepted sprint: `CZH-S49` (`CZH-B54`, `CZH-GATE-108`). Checkpoint: `docs/todo/core/CZH_S49_CHECKPOINT.md`.
- Accepted sprint: `CZH-S48` (`CZH-B53`, `CZH-GATE-107`). Checkpoint: `docs/todo/core/CZH_S48_CHECKPOINT.md`.
- Accepted sprint: `CZH-S47` (`CZH-B52`, `CZH-GATE-106`). Checkpoint: `docs/todo/core/CZH_S47_CHECKPOINT.md`.
- Accepted sprint: `CZH-S46` (`CZH-B51`, `CZH-GATE-105`). Checkpoint: `docs/todo/core/CZH_S46_CHECKPOINT.md`.
- Accepted sprint: `CZH-S45` (`CZH-B50`, `CZH-GATE-104`). Checkpoint: `docs/todo/core/CZH_S45_CHECKPOINT.md`.
- Accepted sprint: `CZH-S44` (`CZH-B49`, `CZH-GATE-103`). Checkpoint: `docs/todo/core/CZH_S44_CHECKPOINT.md`.
- Accepted sprint: `CZH-S43` (`CZH-B48`, `CZH-GATE-102`). Checkpoint: `docs/todo/core/CZH_S43_CHECKPOINT.md`.
- Accepted sprint: `CZH-S42` (`CZH-B47`, `CZH-GATE-101`). Checkpoint: `docs/todo/core/CZH_S42_CHECKPOINT.md`.
- Accepted sprint: `CZH-S41` (`CZH-B46`, `CZH-GATE-100`). Checkpoint: `docs/todo/core/CZH_S41_CHECKPOINT.md`.
- Accepted sprint: `CZH-S35` (`CZH-B40`, `CZH-GATE-94`). Checkpoint: `docs/todo/core/CZH_S35_CZH900_GATE_PACKET.md`.
- Completed sprint: `CZH-S34` (accepted, with CZH-B39-corrective extraction). Checkpoint: `docs/todo/core/CZH_S34_CHECKPOINT.md` and `docs/todo/core/CZH_B39_CORRECTIVE_CHECKPOINT.md`.
- Previous sprint: `CZH-S33` (accepted). Validation: `docs/todo/core/CZH_S33_VALIDATION.md`.
- Active validation platforms: Linux desktop and the connected Android device
  (`RF8M74JDWEK`). Windows and macOS are follow-up validation platforms for now;
  they must not block core correction work unless a change intentionally touches
  their platform-specific code.
- Hard blockers (CZH-B36 resolved): startup assertion regression fixed; no current blockers.

## Campaign Goals

1. freeze the shared host/core/editor/surface split before further cleanup
2. keep stability first: user stress tests stay green while architecture work lands
3. enforce probe/debug hygiene on main branch product paths
4. remove compatibility/fallback/legacy preservation leftovers instead of carrying them forward
5. scrutinize doc strings and locked-down function docs for alignment with real ownership and behavior
6. normalize Android-driven FFI/rendering advancements into shared core seams only after the split is explicit

## Hard Contracts

- Behavior freeze by default during hygiene cuts.
- Correctness regressions that break startup/runtime are allowed to cut through
  the freeze, but must be isolated, tested, and documented as fixes.
- No compatibility sludge.
- No stale debug/probe caller residue in tracked product code.
- No compatibility shims, migration surfaces, or preservation-only fallbacks kept "just in case".
- Every file in the touched layer set must have a doc string; important/locked-down functions must be audited for whether their doc strings help, hurt, or lie about current responsibility.
- Source doc comments are architectural drawings: current ownership, invariants,
  and constraints only. Ticket IDs, sprint names, progress notes, and historical
  commentary belong in `docs/todo/`, not product source files.
- The current FFI/caller shape is not frozen by this campaign. If VT core,
  editor, BYO-PTY, or terminal presentation maturity requires callers to move,
  move them cleanly and update Android as the proving host rather than treating
  Android's first implementation as the final shape.
- Batch closure requires doc updates + validation record.

## Validation Baseline

- `zig build`
- `zig build test`
- `zig build -Dmode=terminal`
- `zig build -Dmode=editor`
- bounded Linux GUI startup smoke when presentation paths are touched: launch
  terminal mode, verify init gets past the targeted failure, then terminate it
  cleanly; do not leave a GUI process open as a validation step
- Android regression guard at seam boundaries:
  - `./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac`
  - `./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac`
  - when a device is connected, deploy/start/logcat smoke on `RF8M74JDWEK`

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
   **`reply_hex` / `debugFeedBytes` snapshot parity:** **cleared** — `debugFeedBytes`
   now delegates to `terminal_core_feed.feedOutputBytes` (same publish path as
   production feed), so PTY-capture replay no longer snapshots `size: 0x0` from
   parse-only feeds.
2. **`mutableTerminalCore` seam:** **cleared in `CZH-B2`** — explicit owner-type
   branches in `src/terminal/core/engine_core_face.zig` (`*TerminalCore`,
   `*TerminalRuntimeShell`, `*ProtocolExecution`); no broad structural cast path.
   Optional future rename to a single authority-owned symbol per
   `TERMINAL_SUBSYSTEM_LAYERS` remains queue-shaping only.
3. **Probe/debug hygiene (`CZH-B2` scope):** audit hot paths per `AGENTS.md`
   logging policy; remove stale investigation callers.
4. **Naming / ownership (`CZH-B2` scope):** align lingering names with
   `TERMINAL_SUBSYSTEM_LAYERS` + `VT_MATURITY_PURITY_CAMPAIGN` authority.
5. **FFI/render normalization (`CZH-B3` scope):** **in progress / see `CZH-B3`
   milestone notes below** — shared FFI metadata module + publication viewport
   helper for Android selection.

#### `CZH1-M5` code note (bug fix, not policy)

- `src/terminal/core/publication/snapshot.zig`: `encodeSnapshot` now gates
  `focus_reporting:` output on `debug.focus_reporting` (the field populated by
  `debug_ops.debugSnapshot`), fixing a stale reference to `debug.session` that
  did not exist on `DebugSnapshot`.

#### Architect gate result

- `Review chunk: CZH-B1`
- `Verdict: architect_review_pending`
- `Engineer commits reviewed: f4c2e673, 18d556d2`
- `Architect validation spot-check: SL-0..SL-3 PASS; SL-ext-1 FAIL (expected/documented import drift).`
- `Residual risk carried forward: replay harness compile drift remains unresolved.`

### `CZH-B2` Probe/Debug Caller Purge + Naming Hygiene (`accepted`)

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
- **SL-ext-2** `zig build test-terminal-replay-all` — **PASS** (full VT + encoder sweep)  
- **`zig build test-editor`** — **FAIL** (`import of file outside module path` from
  `tests/tests_main.zig` and related test roots; unchanged by this batch — treat
  as editor test-module wiring / toolchain issue until fixed separately)  
- **Android guard** — **SKIP** (lane paused; no Android seam touched)

#### `CZH-B2` super-gate packet (engineer → architect)

- `Review chunk: CZH-B2`
- `Verdict: accepted`
- `Scope summary:` `debugFeedBytes` routes through `terminal_core_feed.feedOutputBytes`
  so `reply_hex` / PTY-capture replay publishes parsed output like production;
  `mutableTerminalCore` uses explicit owner-type branches only (`*TerminalCore`,
  `*TerminalRuntimeShell`, `*ProtocolExecution`). Replay fixture set refreshed:
  goldens + harness assertion metadata (damage bounds, scrollback lines, viewport
  shift flags) were stale against **committed** engine output (reproduced on
  pre-change `main` for representative failures — e.g. `decslrm_ed_mode2_clips_to_margins`,
  `redraw_alternating_gutter_churn`); no intentional terminal semantic change in
  this refresh.
- `Residual risks / follow-ups:`
  - `zig build test-editor` still fails with `import of file outside module path`
    (see ladder note above).
- `Architect validation request:` confirm batch closure vs `CZH-B3` handoff; spot-check
  seam commits + fixture diff scope.

#### Architect gate result

- `Review chunk: CZH-B2`
- `Verdict: accepted`
- `Engineer commits reviewed:` `43702b5e`, `dcb92263`, `b2148299`, `c420d177`,
  `eae70584`, `cede70dd`, `2d93997d`, `dfade0a8`
- `Architect validation spot-check:` `SL-0..SL-3 PASS`, `SL-ext-1 PASS`,
  `SL-ext-2 PASS`; `zig build test-editor` still fails with module-path imports
  and is tracked as a separate lane concern.

### `CZH-B3` Android-Driven FFI/Render Normalization (`accepted`)

Queue line (exact):

- normalize Android-proven FFI/render seam improvements into shared core layers
  with loose coupling preserved

Acceptance:

- shared seam contracts are explicit and platform-agnostic
- Android-specific glue stays platform-owned
- core runtime/ffi/render ownership is clearer than pre-batch baseline

Internal milestones (`CZH3-M1..M6`, execute sequentially in one batch):

| Id | Scope |
| --- | --- |
| `CZH3-M1` | Audit Android-proven FFI/render seam deltas that should move to shared core (explicit file list + non-goals) |
| `CZH3-M2` | Normalize one bounded shared seam (owner/type/API clarity) with no behavior change |
| `CZH3-M3` | Normalize second bounded shared seam (keep Android glue platform-local) |
| `CZH3-M4` | Probe/debug caller hygiene in touched seams only |
| `CZH3-M5` | Authority docs update (core queue + handoff + entrypoint + any touched architecture docs) |
| `CZH3-M6` | Super-gate packet with validation ladder and residual-risk notes |

`CZH-B3` stop conditions:

- stop only at super-gate or real hard blocker
- target 5–10 validated commits
- maintain behavior freeze and single-path contract

#### `CZH3-M1` seam audit (explicit files + non-goals)

**Shared terminal FFI / publication (canonical for native + tests):**

- `src/terminal/ffi/shared.zig` — extern ABI structs and `Handle` bookkeeping
- `src/terminal/byo_pty_host.zig` — optional BYO-PTY seam (session/transport)
- `src/terminal/ffi/bridge.zig`, `core_api.zig`, `c_api.zig` — VT core FFI + bridge surface
- `src/terminal_ffi_exports.zig` — exported C symbols

**Android platform glue (stays local — JNI / Activity / GLES wiring):**

- `src/platform/android_runtime_bridge.zig` — JNI entrypoints, `ANativeWindow`, lifecycle
- `src/platform/android_shell_session.zig` — thin session + selection UX over `c_api` / core
- `src/platform/android_host.zig`, `android_gles_surface_status.zig`
- `src/ui/renderer/android_gles_backend.zig` — GLES backend (not shared contract debt for this batch)

**Non-goals (explicit):**

- No GLES/Vulkan/renderer-backend contract refactors — see `RENDER_BACKEND_CONTRACT.md` adoption gates.
- No JNI signature or Java/Kotlin source changes.
- No behavior or ABI version bumps beyond mechanical relocation of existing logic.

#### `CZH3-M2` first bounded seam (done)

- Added `src/terminal/ffi/renderer_metadata.zig`: `fillRendererMetadata` + glyph classification
  (moved out of `shared.zig`). `core_api.rendererMetadata` is the single fill path.

#### `CZH3-M3` second bounded seam (done)

- `RenderCache.visibleStartLineIndex()` in `render_cache.zig` — publication-truth first visible
  line in scrollback coordinates.
- `android_shell_session` selection helpers use it (removed duplicate local math). Android glue
  remains in `src/platform/`; semantics owned by publication layer.

#### `CZH3-M4` probe hygiene (done)

- No new logging in touched paths; no investigation probes added.

#### `CZH3-M5` docs touched

- This queue file; `docs/AGENT_HANDOFF.md`; `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `app_architecture/terminal/TERMINAL_SUBSYSTEM_LAYERS.md` — FFI metadata + viewport helper section

#### `CZH-B3` engineer validation (2026-04-18)

- **Date:** 2026-04-18  
- **Host:** Linux (engineer session)  
- **Git:** `main` at engineer close  
- **SL-0** `zig build` — **PASS**  
- **SL-1** `zig build test` — **PASS**  
- **SL-2** `zig build -Dmode=terminal` — **PASS**  
- **SL-3** `zig build -Dmode=editor` — **PASS**  
- **SL-ext-1** `zig build test-terminal-replay` — **PASS**  
- **SL-ext-2** `zig build test-terminal-replay-all` — **PASS**  
- **`zig build test-editor`** — **FAIL** (module-path imports; separate lane; unchanged)  
- **Android guard** — **SKIP** (lane paused; seam touches Zig-only `android_shell_session` — no Gradle run this session)

#### `CZH-B3` super-gate packet (engineer → architect)

- `Review chunk: CZH-B3`
- `Verdict: architect_review_pending`
- `Scope summary:` Shared `renderer_metadata.zig` owns FFI `RendererMetadata` fill + glyph
  classification; `RenderCache.visibleStartLineIndex()` centralizes visible-line math for
  Android selection; platform JNI/GLES files unchanged.
- `Residual risks / follow-ups:` Full Android `compileDebugJavaWithJavac` not re-run (lane
  paused); `test-editor` still broken; broader RENDER_BACKEND_CONTRACT Vulkan/Android rendering
  gates remain future work.
- `Architect validation request:` confirm layer ownership + optional Android compile spot-check
  when lane reopens.

#### Architect gate result

- `Review chunk: CZH-B3`
- `Verdict: accepted`
- `Engineer commits reviewed:` `1951875b`, `f2b8246f`
- `Architect validation spot-check:` `zig build PASS`, `zig build test PASS`,
  `zig build -Dmode=terminal PASS`, `zig build -Dmode=editor PASS`,
  `zig build test-terminal-replay-all PASS`; `zig build test-editor` still fails
  with module-path imports and is tracked as a separate stability lane concern.

### `CZH-B4` Stability Baseline Closure: `test-editor` Module Path Lane (`accepted`)

Queue line (exact):

- isolate and resolve `zig build test-editor` module-path/import-root failures so
  the core stress ladder has no known baseline hole

Acceptance:

- `zig build test-editor` passes in the default repo-local invocation surface, or
  failure is explicitly narrowed to a documented external/toolchain precondition
  with reproducible evidence and fallback invocation policy
- no behavior changes in terminal/runtime product paths
- full existing ladder remains green:
  `zig build`, `zig build test`, `zig build -Dmode=terminal`,
  `zig build -Dmode=editor`, `zig build test-terminal-replay`,
  `zig build test-terminal-replay-all`

Internal milestones (`CZH4-M1..M6`, execute sequentially in one batch):

| Id | Scope |
| --- | --- |
| `CZH4-M1` | Audit `test-editor` build graph/module root wiring with explicit failing edge list |
| `CZH4-M2` | Implement bounded build/test wiring fix (no product runtime semantics) |
| `CZH4-M3` | Re-run `zig build test-editor`; if still failing, narrow to concrete external precondition with proof |
| `CZH4-M4` | Probe/debug caller hygiene in touched build/test files only |
| `CZH4-M5` | Docs sync (queue/handoff/entrypoint + any touched build/test authority docs) |
| `CZH4-M6` | Super-gate packet with residual-risk notes |

`CZH-B4` stop conditions:

- stop only at super-gate or real hard blocker
- target 5–10 validated commits
- maintain behavior freeze and single-path contract

#### `CZH-B4` engineer implementation summary (2026-04-19)

- repo-root test entrypoints added for editor test bundles:
  - `editor_tests_root.zig`
  - `editor_highlight_smoke_root.zig`
- build wiring updated so `zig build test-editor` / highlight smoke use repo-root
  module roots instead of `tests/*.zig` as package root.
- config parser abort fixed:
  - `parseLogGroupsOwned` no longer invalidates Lua table iteration stack
    during grouped log sink parsing.
- scoped mechanical compile/test drift cleanup landed in editor/render/runtime
  test seams; runtime behavior unchanged.
- terminal glyph prep ownership fix landed in draw adoption path:
  successful adopted rasters now free staging upload buffers.

#### `CZH-B4` engineer commits reviewed

- `23785c17` — config Lua log-group iterator fix + keybind fixture repair
- `49e396cb` — repo-root editor test entrypoints + build/test wiring
- `4207edcc` — editor/doc buffer ownership routing + matching tests
- `d5a42c68` — compile-fallout test seam updates (editor/render/runtime)
- `dbadae3e` — glyph prep ownership leak fix + presentation-plan tests

#### `CZH-B4` architect validation spot-check

- `zig build` — PASS
- `zig build test` — PASS
- `zig build -Dmode=terminal` — PASS
- `zig build -Dmode=editor` — PASS
- `zig build test-config` — PASS
- `zig build test-editor` — PASS
- `zig build test-terminal-replay-all` — PASS
- Android guard — SKIP (lane paused; no Android seam touched)

#### Architect gate result

- `Review chunk: CZH-B4`
- `Verdict: accepted`
- `Residual risks:` editor test bundle remains intentionally narrower than full
  integration scope; expand in a dedicated follow-up once Lua/config and
  harness boundaries are explicitly scoped.

### `CZH-B5` Probe/Debug Hygiene + Ownership Naming Sweep (`accepted`, narrow slice only)

Queue line (exact):

- remove stale investigation caller residue and normalize ownership naming in
  touched core/editor seams while preserving frozen runtime behavior

Acceptance:

- no stale probe/debug caller residue remains in touched product paths
- touched naming aligns with declared owner contracts
- stress ladder remains green:
  `zig build`, `zig build test`, `zig build -Dmode=terminal`,
  `zig build -Dmode=editor`, `zig build test-config`,
  `zig build test-editor`, `zig build test-terminal-replay-all`

Internal milestones (`CZH5-M1..M6`, execute sequentially in one batch):

| Id | Scope |
| --- | --- |
| `CZH5-M1` | audit touched core/editor seams for stale probe/debug callers with explicit file list |
| `CZH5-M2` | remove stale investigation-only callers/checks in audited seams (no behavior change) — **done** (see `CZH5-M2` section) |
| `CZH5-M3` | ownership naming cleanup in audited seams only (no semantic change) — **done** (see `CZH5-M3` section) |
| `CZH5-M4` | re-run full stress ladder and capture results |
| `CZH5-M5` | docs sync (queue/handoff/entrypoint + any touched authority docs) |
| `CZH5-M6` | super-gate packet with residual-risk notes |

#### `CZH5-M1` stale probe/debug caller audit (2026-04-18)

**Seed commits (file union):** `15b790cf`, `dbadae3e`, `d5a42c68`, `4207edcc`, `49e396cb`, `23785c17`.

**Candidate file list (22 files):**

- `src/ui/renderer/font_runtime.zig`
- `src/ui/widgets/terminal_widget_draw.zig`
- `src/editor/manual_highlights.zig`
- `src/editor/render/segment_paint.zig`
- `src/editor/tree_sitter_assets.zig`
- `src/terminal/core/pty_terminal_runtime_tests.zig`
- `src/ui/renderer/metal_backend.zig`
- `src/ui/renderer/window_chrome_runtime.zig`
- `tests/layout_tests.zig`
- `tests/terminal_input_encoding_tests.zig`
- `src/editor/editor.zig`
- `src/editor/navigation.zig`
- `src/editor/selection_state.zig`
- `tests/editor_clipboard_tests.zig`
- `tests/editor_tests.zig`
- `build_system/ide_extended_artifacts.zig`
- `editor_highlight_smoke_root.zig`
- `editor_tests_root.zig`
- `tests/editor_highlight_smoke_tests.zig`
- `tests/tests_main.zig`
- `src/config/lua_config_log_parse.zig`
- `src/config/lua_config_ziglua_parse.zig`

**Adjacent ownership files added:** none. Imports checked for the touched hot paths (e.g. glyph prep → `renderer_font_backend_host.zig`) show no additional `app_logger` / probe surface; sub-draw modules were not part of the seed commit set and were excluded as speculative scope.

**Per-file classification (summary):**

| File | keep_correctness | keep_operator_telemetry | remove_probe_residue (see queue) |
| --- | --- | --- | --- |
| `font_runtime.zig` | — | glyph prep worker spawn/compute warnings; terminal glyph prep compute failure warning | gated `.info` pinch/UI-scale/zoom traces (`applyPinchZoomScale`, `refreshUiScaleFromDisplayMetrics`, `applyPendingZoom`) |
| `terminal_widget_draw.zig` | — | adopt-path warning when committed font cache missing | — (glyph-prep `.info` spam removed in `15b790cf`) |
| `editor.zig` | — | `editor.draw` warnings on highlight/IO failures; `openFile` path `.info` (core) | env-driven highlight worker delay + helper; high-frequency `editor.perf` `.info` on visible-highlight path; `openFile` startup perf line; `undo`/`redo` unconditional `.info` “ok” lines; structured lifecycle `.info` that embed raw `editor_ptr` (treat as investigation residue — see removal queue) |
| `navigation.zig` | — | caret/selection restore warnings only | — |
| `selection_state.zig` | `std.debug.assert` invariants | — | — |
| `metal_backend.zig` | — | present capture warnings | — (test-local `FakeRenderer` is harness-only) |
| `window_chrome_runtime.zig` | — | SDL border/hit-test warnings | — |
| `pty_terminal_runtime_tests.zig` | test use of `debug_ops` / `debugFeedBytes` / grid helpers | — | — |
| `lua_config_log_parse.zig` | level string parsing | — | — |
| `lua_config_ziglua_parse.zig` | unit tests exercising logger config mapping | — | — |
| `manual_highlights.zig`, `segment_paint.zig`, `tree_sitter_assets.zig` | — | — | no logging/probe patterns located |
| `build_system/ide_extended_artifacts.zig`, `editor_*_root.zig`, `tests/tests_main.zig`, listed `tests/*.zig` | — | — | no probe/logging residue in reviewed paths |

**Explicit removal queue (`remove_probe_residue` — execute in `CZH5-M2+`):**

| File | Symbol / site | Why residue | Intended removal action | Risk |
| --- | --- | --- | --- | --- |
| `src/ui/renderer/font_runtime.zig` | `applyPinchZoomScale` | Gated `.info` `ui_pinch_zoom` / `terminal_pinch_tick` dumps mirror removed glyph-prep chatter; hot pinch path | Delete `ui_log_enabled` / `font_log_enabled` blocks and dependent locals | low |
| `src/ui/renderer/font_runtime.zig` | `refreshUiScaleFromDisplayMetrics` | Gated `.info` `ui_scale` lines on DPI/display updates | Delete gated `.info` block | low |
| `src/ui/renderer/font_runtime.zig` | `applyPendingZoom` | Gated `.info` `ui_zoom` + `ui_zoom_effective` on zoom apply | Delete gated `.info` blocks | low |
| `src/editor/editor.zig` | `visibleHighlightWorkerMain` | `ZIDE_EDITOR_DEBUG_VISIBLE_HIGHLIGHT_DELAY_MS` sleep is investigation-only timing injection | Remove getenv + `Thread.sleep` branch | low |
| `src/editor/editor.zig` | `debugWorkerDelayMs` | Helper exists only to support env delay probe | Delete function when call site removed | low |
| `src/editor/editor.zig` | `applyPendingVisibleHighlightResult`, `computeVisibleHighlightRequest`, `executePendingVisibleHighlightRequest`, `ensureVisibleHighlightWorker`, `finishVisibleHighlightWorkerStop`, `visibleHighlightWorkerMain` | Ungated `editor.perf` `.info` on every publish/compute/worker transition — hot-path spam | Drop or relocate behind dedicated perf/trace policy (default off); remove duplicate “lines=0 budget=0” stubs | med |
| `src/editor/editor.zig` | `openFile` | `editor.perf` `.info` startup line logs bytes/deferrals every open — investigation-style perf | Remove `perf_log` `.info` startup stanza (keep optional `editor.core` path log if still desired) | med |
| `src/editor/editor.zig` | `undo`, `redo` | Unconditional `.info` on every successful undo/redo | Remove `log.logf(.info, …)` “ok” lines | med |
| `src/editor/editor.zig` | `requestRuntimeWake`, `prepareForShutdown`, `applyPendingVisibleHighlightResult`, visible-highlight worker stop/join/publish sites | `logFields(.info, …)` includes `editor_ptr` raw addresses — investigation-oriented payload | Remove pointer fields or replace with non-address correlation id per lifecycle contract (`CZH5-M3` naming pass) | med |

**Ownership naming drift (no edits this milestone):**

| Current | Proposed owner-aligned | Why |
| --- | --- | --- |
| `debugWorkerDelayMs` | remove or `editor.highlight.probeDelayFromEnv` under explicit debug/test hook policy | Name hides that only visible-highlight worker uses it for env injection |
| `editor.lifecycle` + `editor_ptr` field | `editor.lifecycle` without raw pointers, or `editor.support` + stable instance token | Raw addresses are not part of product logging contract; reads as leftover probe fields |
| Mixed `renderer.font` vs `ui.scale` loggers in `font_runtime.zig` pinch path | Keep tags but split file-level doc/owner note: scale vs terminal font cache | Same file owns UI scale and terminal font; tags blur subsystem boundaries |

**Validation (M1 audit run, 2026-04-18):**

- `zig build` — **PASS**
- `zig build test` — **PASS**
- `zig build -Dmode=terminal` — **PASS**
- `zig build -Dmode=editor` — **PASS**

#### `CZH5-M2` probe residue removal (`done`, 2026-04-18)

**Authority:** removal queue in `#### CZH5-M1 stale probe/debug caller audit` above.

**Removed (mechanical, no naming refactors):**

- `src/ui/renderer/font_runtime.zig`
  - `applyPinchZoomScale`: deleted gated `.info` `ui_pinch_zoom` / `terminal_pinch_tick` blocks and locals only used for those logs; preserved zoom/font prep control flow.
  - `refreshUiScaleFromDisplayMetrics`: deleted gated `.info` `ui_scale` block.
  - `applyPendingZoom`: deleted gated `.info` `ui_zoom` / `ui_zoom_effective` blocks.
- `src/editor/editor.zig`
  - `visibleHighlightWorkerMain`: removed `ZIDE_EDITOR_DEBUG_VISIBLE_HIGHLIGHT_DELAY_MS` getenv + sleep path.
  - Deleted `debugWorkerDelayMs` helper (was only used for that probe).
  - Removed `editor.perf` `.info` spam from: `applyPendingVisibleHighlightResult`, `computeVisibleHighlightRequest`, `executePendingVisibleHighlightRequest`, `ensureVisibleHighlightWorker`, `finishVisibleHighlightWorkerStop`, `visibleHighlightWorkerMain` (including `lines_done` only used for perf).
  - `openFile`: removed `editor.perf` startup `.info` line (bytes/deferrals/timing); kept `editor.core` `openFile path=` `.info`.
  - `undo` / `redo`: removed unconditional `.info` “ok” lines on success.
  - Lifecycle `logFields(.info, …)`: removed `editor_ptr` fields everywhere; removed `visible_highlight_worker_join_begin` / `visible_highlight_worker_join_end` events (they only carried the pointer); kept non-pointer fields on remaining lifecycle events.

**Validation (M2 engineer run, 2026-04-18):**

- `zig build` — **PASS**
- `zig build test` — **PASS**
- `zig build -Dmode=terminal` — **PASS**
- `zig build -Dmode=editor` — **PASS**
- `zig build test-config` — **PASS**
- `zig build test-editor` — **PASS**
- `zig build test-terminal-replay-all` — **PASS**

#### `CZH5-M3` ownership naming cleanup (`done`, 2026-04-18)

**Authority:** `#### CZH5-M1 stale probe/debug caller audit` → **Ownership naming drift**, plus `CZH5-M2` removals.

**Resolved by removal (no code change this milestone):**

- `debugWorkerDelayMs` / `ZIDE_EDITOR_DEBUG_VISIBLE_HIGHLIGHT_DELAY_MS` — removed in `CZH5-M2`; no resurrection or rename.

**Applied in `src/editor/editor.zig` (lifecycle `logFields` event names only; logger tag `editor.lifecycle` unchanged):**

| Previous event name | New event name |
| --- | --- |
| `runtime_wake_attempt` | `lifecycle_runtime_wake` |
| `visible_highlight_apply_during_shutdown` | `lifecycle_highlight_apply_during_shutdown` |
| `visible_highlight_worker_stop_signal` | `lifecycle_highlight_worker_stop` |
| `visible_highlight_worker_exit` | `lifecycle_highlight_worker_exit` |
| `visible_highlight_worker_publish_attempt` | `lifecycle_highlight_worker_publish` |
| `editor_deinit_enter` | `lifecycle_editor_shutdown_begin` |

Rationale: consistent `lifecycle_*` vocabulary for JSONL `message` values, drop probe-adjacent wording (`attempt`, `signal`, `publish_attempt`, `deinit_enter`), align with product lifecycle ownership (no pointer payloads — those were removed in M2).

**Deferred (out of M3 file scope; `font_runtime.zig` not editable this milestone):**

- M1 drift note on mixed `renderer.font` vs `ui.scale` in pinch/zoom — remains a future doc/owner clarification in `font_runtime.zig` or architecture note when that file is in scope.

**Validation (M3 engineer run, 2026-04-18):**

- `zig build` — **PASS**
- `zig build test` — **PASS**
- `zig build -Dmode=terminal` — **PASS**
- `zig build -Dmode=editor` — **PASS**
- `zig build test-config` — **PASS**
- `zig build test-editor` — **PASS**
- `zig build test-terminal-replay-all` — **PASS**

#### Architect gate result

- `Review chunk: CZH-B5`
- `Verdict: accepted as a narrow hygiene slice, not campaign closure`
- `Engineer commits reviewed:` `8b9aaacc`, `839b11ca`, `6e3e2ee4`
- `Architect validation spot-check:` `zig build test-config PASS`,
  `zig build test-editor PASS`
- `Carry-forward judgment:` `CZH-B5` removed one audited slice of probe residue,
  but it does **not** answer the larger ownership problem. Wider hygiene now
  continues only inside the explicit layer split defined by `CZH-B6`.

### `CZH-B6` Layer Freeze: VT Core FFI / Optional PTY Host / Editor FFI / Terminal Surface (`accepted`)

Queue line (exact):

- flatten the Zig-side focus around one explicit host/core split: freeze the
  VT core FFI, optional bring-your-own-PTY host seam, editor backend FFI, and
  host-initialized terminal surface contract before more cleanup or extraction

Objective:

- turn the current broad "cleanup" lane into a small number of explicit layer
  contracts that the engineer can execute against without drifting

**Four target layers (name consistently everywhere):**

1. **VT core FFI** — publication / query / redraw / events / metadata truth
   exported to hosts (terminal state and what changed). **Not** session,
   runtime, or transport ownership.
2. **optional bring-your-own-PTY host seam** — session / runtime / input /
   transport path when the host drives a local PTY-backed or equivalent loop.
   **Target:** distinct from VT core FFI; packaged as `src/terminal/byo_pty_host.zig`
   (terminal-owned sibling to `ffi/`, not inside it — see `CZH-S4`).
3. editor backend FFI
4. terminal surface contract — host initializes/passes the **shared GPU
   texture/resource attachment** the backend needs; Zide owns dirty tracking,
   generation truth, and terminal **content** update logic; host owns binding
   that resource into platform presentation (see `TERMINAL_SURFACE_CONTRACT.md`)

Acceptance:

- authority docs explicitly define these four target layers (same list as
  above)
- current files are classified into those target layers with explicit keep/move
  boundaries and non-goals
- hard-rule audits exist for:
  - probe/debug residue
  - compatibility/fallback/legacy leftovers
  - file/module doc strings and important function doc strings
- the first post-freeze implementation sprint is ticketed for the engineer

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_B6_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`
- terminal/editor authority docs named by the tickets below

Internal milestones (`CZH6-M1..M6`, executed through Jira tickets `CZH-601`..`CZH-610`):

| Id | Scope |
| --- | --- |
| `CZH6-M1` | establish Jira/board/ticket authority and flatten the active focus |
| `CZH6-M2` | audit current file ownership across terminal FFI, editor FFI, Android/native host glue, and renderer surface paths |
| `CZH6-M3` | write/freeze the target split docs for VT core FFI, optional bring-your-own-PTY host seam, editor backend FFI, and terminal surface contract |
| `CZH6-M4` | run the three hard-rule audits (probe/debug, compat/fallback, doc strings) against the layer set |
| `CZH6-M5` | shape the first implementation sprint from that authority |
| `CZH6-M6` | checkpoint packet + review gate |

Stop conditions:

- engineer executes `CZH-601`..`CZH-610` in order from
  `docs/todo/core/CZH_B6_TICKETS.md`
- one ticket per commit unless a ticket is explicitly marked atomic
- stop only at `CZH-GATE-60` or a real hard blocker

Architect note:

- `CZH-B6` intentionally replaces a vague hygiene lane with a focused
  architecture freeze. Do not reopen broad cleanup-by-instinct until this split
  is written down and accepted.

#### `CZH-602` terminal FFI ownership audit (recorded)

- **Authority:** `app_architecture/terminal/TERMINAL_SUBSYSTEM_LAYERS.md` →
  **Terminal FFI directory ownership (`CZH-B6` current-state map)**.
- **Scope:** `src/terminal/ffi/**` and `src/terminal_ffi_exports.zig`, plus the
  closely coupled session/runtime modules called from `byo_pty_host` / `core_api`.
- **Outcome:** file-by-file classification into **VT core FFI** (publication /
  query / events / metadata), **optional BYO-PTY host seam** (session/runtime /
  transport — `byo_pty_host` + session modules), bridge/facade glue, and explicit
  packaging (`byo_pty_host.zig` names the seam).

#### `CZH-603` editor backend FFI authority (recorded)

- **Authority:** `app_architecture/editor/FFI_DESIGN.md` (freeze section +
  routing/versioning notes).
- **Outcome:** editor FFI scoped as the **editor backend** export for foreign
  hosts; native app remains direct-to-core; platform routing and future JNI-style
  glue stay host-owned and trace this doc.

#### `CZH-604` terminal surface contract (recorded)

- **Authority:** `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md`.
- **Outcome:** host initializes/passes the **shared GPU texture/resource
  attachment** the backend needs; Zide owns dirty tracking, generation truth, and
  terminal content update logic; host owns binding/presentation; window/swapchain
  specifics out of the frozen center; Android one proving host only.

#### `CZH-605` cross-layer file inventory and non-goals

**Layer → primary paths (keep map for the first implementation sprint)**

| Layer | Canonical paths | Role |
| --- | --- | --- |
| VT core FFI | `src/terminal/ffi/shared.zig` (types/helpers), `core_api.zig`, `renderer_metadata.zig`, `bridge.zig`, `c_api.zig`, `src/terminal_ffi_exports.zig` | Publication / query / redraw / events / metadata + shared ABI; **not** `byo_pty_host` |
| Optional BYO-PTY host seam | `src/terminal/byo_pty_host.zig`; `src/terminal/core/session/runtime.zig`, `input.zig`, `lifecycle.zig` | Session/runtime/input/transport; **terminal-owned** (sibling to `ffi/`, not inside it) |
| Editor backend FFI | `src/editor/ffi/bridge.zig`, `src/editor/ffi/c_api.zig` | Foreign editor hosts; C ABI |
| Terminal surface contract | `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md`; `src/ui/widgets/terminal_widget*.zig` (presentation + publication coupling); `src/platform/android_shell_session.zig` (peer host example); GL/Metal backends under `src/ui/renderer/*_backend.zig` | Drawable surface + generations; host proves binding; Zide proves redraw truth |
| Bridge / glue | `bridge.zig`, `c_api.zig`, `terminal_ffi_exports.zig`; `src/editor/ffi/c_api.zig` | Thin forwarders and symbol roots |

**Explicit non-goals (this sprint / freeze batch)**

- No Vulkan or Android GLES **adoption-gate** work — see
  `RENDER_BACKEND_CONTRACT.md` readiness.
- No JNI / Java / Kotlin source edits (Android lane paused).
- No terminal **semantic** or FFI **ABI version** behavior changes — doc and map
  only unless a later ticket scopes a change with replay evidence.
- No broad refactor of `terminal_widget_*` beyond what a future ticket lists —
  inventory only here.
- No deletion of the snapshot-diff **full refresh** paths in `core_api.zig`
  (they are contract, not cruft) — any rename/collapse waits on an
  implementation sprint tied to `CZH-607` review notes.

#### `CZH-606` hard-rule audit: probe / debug residue (layer set)

Scope: `src/terminal/ffi/**`, `src/editor/ffi/**`, plus `src/terminal_ffi_exports.zig`
(the `CZH-605` FFI + export inventory).

| File | Symbol / site | Classification | Removal queue? |
| --- | --- | --- | --- |
| `terminal/ffi/shared.zig` | `mapError`, `stringFromSlice`, `byteBufferFromSlice`, … `log.logf(.warning, …)` | Operator telemetry on allocation/backend failures | **No** — legitimate error-path logging |
| `terminal/ffi/core_api.zig` | `app_logger` `.warning` in `snapshotAcquire`, `snapshotDiffAcquire`, etc. | Same — export failure diagnostics | **No** |
| `terminal/ffi/core_api.zig` | *(historical)* `destroy_debug_pause_ms_for_tests` + sleep in `destroy` | Removed from product (`CZH-S6` / `CZH-B11`); smoke test syncs on `Handle.destroying` in `tests/terminal_ffi_smoke_tests.zig` | **Resolved** — no product debug sleep |
| `editor/ffi/bridge.zig` | `app_logger` `.warning` on alloc/create failures | Error-path telemetry | **No** |
| `terminal_ffi_exports.zig` | (none) | N/A | **No** |

**Explicit removal queue (later sprint, bounded)**

1. *(done `CZH-S6`)* — product `destroy` no longer contains test sleep or
   `destroy_debug_pause_ms_for_tests`.

#### `CZH-607` hard-rule audit: compatibility / fallback residue (layer set)

Same scope as `CZH-606` (`src/terminal/ffi/**`, `src/editor/ffi/**`,
`src/terminal_ffi_exports.zig`).

| File | Symbol / pattern | Assessment | Recommended action |
| --- | --- | --- | --- |
| `terminal/ffi/core_api.zig` | `should_fallback` + early `return null` in snapshot diff export | **Not** a deprecated shim — encodes when granular diff cannot be produced (stale base generation, dimension/mode changes, full dirty, etc.). | Keep behavior. Optional **rename** in a behavior-allowed ticket to `requires_full_refresh` (or similar) so the name does not read like “compat fallback.” |
| `terminal/ffi/core_api.zig` | `copyPublishedSnapshotExport` branch after granular path fails | Delivers full cell buffer with `full_refresh_required` — part of the snapshot-diff contract. | **No removal.** |
| `terminal/ffi/core_api.zig` | `feedOutput` → `enqueueExternalBytes` vs `terminal_core_feed.feedOutputBytes` | Dual path for **external host-fed** transport vs **direct engine feed** — ownership split, not a legacy duplicate. | **No removal**; document only (already the BYO transport seam). |
| `editor/ffi/*` | (none located) | No `fallback` / `compat` / `legacy` markers in editor FFI tree. | None. |

**Net:** no preservation-only fallback identified that should be deleted in the
next sprint without a scoped behavior/replay ticket. The only follow-up is
**naming hygiene** around snapshot-diff “fallback” vocabulary if engineers
misread it as cruft.

#### `CZH-608` hard-rule audit: module docs and important functions (layer set)

Scope: same FFI/export inventory as `CZH-606` / `CZH-607`.

**Module (`//!`) status**

| File | Module doc present? | Note |
| --- | --- | --- |
| `terminal/ffi/renderer_metadata.zig` | **Yes** | Describes single fill path for hosts. |
| `terminal/ffi/shared.zig` | **Yes** | `//!` (`CZH-612`). |
| `terminal/ffi/core_api.zig` | **Yes** | `//!` + key `///` (`CZH-612`/`CZH-613`). |
| `terminal/byo_pty_host.zig` | **Yes** | `//!` + `///`; module was `host_api.zig` before `CZH-617`; moved out of `ffi/` in `CZH-S4`. |
| `terminal/ffi/bridge.zig` | **Yes** | `//!` (`CZH-612`); ownership text (`CZH-618`). |
| `terminal/ffi/c_api.zig` | **Yes** | `//!` (`CZH-612`); C edge (`CZH-618`). |
| `terminal_ffi_exports.zig` | **Yes** | `//!` — symbol root vs `c_api` behavior explicit (`CZH-627` / `CZH-S5`). |
| `editor/ffi/bridge.zig` | **Yes** | Editor backend FFI facade (`CZH-S5`); `///` on `create`/`destroy` (`CZH-628`). |
| `editor/ffi/c_api.zig` | **Yes** | Flat `zide_editor_*` forwarders (`CZH-S5` verified). |

**Important function doc drift (representative)**

| Symbol | Issue | Status (`CZH-S5`) |
| --- | --- | --- |
| `core_api.destroy` | *(historical)* test pause global | Hook removed (`CZH-S6`); `///` is product-only teardown (`CZH-628` + `CZH-S6`). |
| `byo_pty_host.start` / `poll` | — | Documented (`CZH-613`); unchanged. |
| `bridge.create` / `destroy` (editor) | — | `///` added (`CZH-628`). |

**Doc-alignment queue**

- **Closed in `CZH-S5` (`CZH-B10`):** editor `//!`, `terminal_ffi_exports` ownership
  `//!`, and representative `core_api` / editor bridge `///` gaps identified in
  `#### CZH-626`..`CZH-628`.
- **Out of scope here:** ABI version getter `///` on `core_api` (thin constants);
  optional snapshot-diff **rename** hygiene remains a future behavior-allowed ticket
  if naming still misreads as “compat fallback” (`CZH-607`).

#### `CZH-609` first implementation sprint shaped (recorded)

- **Next sprint tickets:** `docs/todo/core/CZH_S2_TICKETS.md` (`CZH-S2`:
  `CZH-611`..`CZH-615`).
- **Intent:** close the audited gaps (probe isolation, FFI module docs, export
  docstrings, optional snapshot-diff rename hygiene) without reopening broad
  cleanup.

#### Architect gate result

- `Review chunk: CZH-B6`
- `Verdict: accepted`
- `Engineer commits reviewed:` `3b772c77`, `15c51c8d`, `a43610d8`, `04153fa3`,
  `44ebe637`, `a04c9bc4`, `89cb2d5b`, `015aa139`, `15df5921`, `40f9dd2f`
- `Corrective authority commits reviewed:` `a03ace8f`, `60d26864`, `4c251c00`,
  `b1cfcc27`
- `Architect validation spot-check:` `zig build test-config PASS`,
  `zig build test-editor PASS`, `zig build test-terminal-replay-all PASS`
- `Acceptance judgment:` the frozen authority now matches the intended target:
  VT core publication/query truth stays distinct from the optional BYO-PTY host
  seam, and the terminal surface contract is centered on the shared GPU
  resource/update boundary rather than generic host window ownership.

### `CZH-B7` First Post-Freeze Implementation Sprint (`accepted`)

Queue line (exact):

- execute the first bounded implementation sprint from the accepted split
  authority: isolate the product-path destroy test hook, align FFI/export docs,
  and clean snapshot-diff fallback naming without behavior drift

Acceptance:

- product `destroy` path carries **no** test sleep or debug pause global
  (completed in `CZH-S6`; historical `CZH-B7` acceptance targeted isolation)
- FFI/export files have module doc strings aligned to the four-layer split
- key exported host entrypoints have concise `///` ownership docs
- snapshot-diff fallback naming no longer reads like compatibility sludge
- full stress ladder remains green through `CZH-GATE-61`

#### `CZH-S2` engineer validation (`CZH-615`)

- **Date:** 2026-04-19  
- **Tickets:** `CZH-611`..`CZH-615` (one commit each).  
- **SL-0** `zig build` — PASS  
- **SL-1** `zig build test` — PASS  
- **SL-2** `zig build -Dmode=terminal` — PASS  
- **SL-3** `zig build -Dmode=editor` — PASS  
- **`zig build test-config`** — PASS  
- **`zig build test-editor`** — PASS  
- **`zig build test-terminal-replay-all`** — PASS  
- **Android guard** — SKIP (lane paused; no Android seam touched)

Checkpoint packet: `docs/todo/core/CZH_S2_CHECKPOINT.md`.

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S2_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

Execution source:

- engineer executes `CZH-611`..`CZH-615` in order from
  `docs/todo/core/CZH_S2_TICKETS.md`
- one ticket per commit unless explicitly marked otherwise
- stop only at `CZH-GATE-61` or a real hard blocker

#### Architect gate result

- `Review chunk: CZH-B7`
- `Verdict: accepted`
- `Engineer commits reviewed:` `8f351cf4`, `2b76d32d`, `08cbd94c`, `dccf53eb`,
  `4faf3ead`
- `Architect validation spot-check:` `zig build test-config PASS`,
  `zig build test-editor PASS`, `zig build test-terminal-replay-all PASS`
- `Acceptance judgment:` first post-freeze cleanup landed cleanly: the product
  destroy test hook is now test-only, FFI/export doc strings exist on the
  bounded target set, and snapshot-diff naming no longer reads like compatibility
  residue.

### `CZH-B8` Make BYO-PTY Packaging Explicit (`accepted`)

Queue line (exact):

- make the accepted split real in code packaging: separate optional BYO-PTY
  session/transport API ownership from VT core FFI packaging without changing
  behavior or exported C symbols

Acceptance:

- the optional BYO-PTY seam is explicit in code/module packaging, not just docs
- VT core FFI and BYO-PTY session transport no longer read as one undifferentiated
  implementation blob
- exported C surface remains behaviorally stable
- full stress ladder remains green through `CZH-GATE-62`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S3_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

Execution source:

- engineer executes `CZH-616`..`CZH-620` in order from
  `docs/todo/core/CZH_S3_TICKETS.md`
- one ticket per commit unless explicitly marked otherwise
- stop only at `CZH-GATE-62` or a real hard blocker

#### Architect gate result

- `Review chunk: CZH-B8`
- `Verdict: accepted`
- `Engineer commits reviewed:` `b3512236`, `554eb430`, `22626c9b`, `9a741692`,
  `25caacc6`
- `Architect validation spot-check:` `zig build test-config PASS`,
  `zig build test-editor PASS`, `zig build test-terminal-replay-all PASS`
- `Acceptance judgment:` the BYO-PTY seam is now explicit in Zig packaging
  (`byo_pty_host.zig`) without behavior change or C export churn. The split is
  cleaner in code, not just in docs.

### `CZH-B9` Extract BYO-PTY Out Of `terminal/ffi` Packaging (`accepted`)

Queue line (exact):

- move the optional BYO-PTY seam out of `src/terminal/ffi/` so the accepted
  split is reflected in directory ownership, while keeping bridge behavior and
  exported C symbols stable

Acceptance:

- optional BYO-PTY code no longer lives under `src/terminal/ffi/`
- bridge/c_api/export roots still provide the same external behavior
- docs reflect the new actual placement rather than calling the remaining
  packaging a smell
- full stress ladder remains green through `CZH-GATE-63`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S4_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

Execution source:

- engineer executes `CZH-621`..`CZH-625` in order from
  `docs/todo/core/CZH_S4_TICKETS.md`
- one ticket per commit unless explicitly marked otherwise
- stop only at `CZH-GATE-63` or a real hard blocker

#### `CZH-621` BYO extraction touchpoint map (`CZH-S4`)

**Goal path (terminal-owned, not FFI-owned):** `src/terminal/byo_pty_host.zig`
(sibling to `ffi/`, alongside `core/`, `replay_harness.zig`, etc.).

**Single file to relocate**

- `src/terminal/ffi/byo_pty_host.zig` → `src/terminal/byo_pty_host.zig` (**no**
  re-export shim left under `ffi/`).

**Import rewrites inside the moved module** (same semantics, paths from
`terminal/` root like `replay_harness.zig`):

| Current (`ffi/`) | After move (`terminal/`) |
| --- | --- |
| `@import("../core/session/host_queries.zig")` | `@import("core/session/host_queries.zig")` |
| `@import("../core/session/input.zig")` | `@import("core/session/input.zig")` |
| `@import("../core/session/runtime.zig")` | `@import("core/session/runtime.zig")` |
| `@import("../core/scrollback_view.zig")` | `@import("core/scrollback_view.zig")` |
| `@import("../model/types.zig")` | `@import("model/types.zig")` |
| `@import("shared.zig")` | `@import("ffi/shared.zig")` |

**Bridge join point (only Zig consumer)**

- `src/terminal/ffi/bridge.zig`: `@import("byo_pty_host.zig")` →
  `@import("../byo_pty_host.zig")`; identifier stays `byo_pty_host`.

**Doc / authority touchpoints (scheduled `CZH-624`)**

- `core_api.zig`, `shared.zig` cross-reference strings; `TERMINAL_SUBSYSTEM_LAYERS.md`,
  `VT_CORE_DESIGN.md`, queue inventory rows; `CZH-616` / `CZH-S3` history blocks
  that still mention `ffi/byo_pty_host.zig`.

**C ABI:** unchanged (`c_api` / exports only see `bridge`).

**Atomic move:** land in **`CZH-622`** as one commit (move + import fixes +
`bridge` import).

#### `CZH-616` BYO-PTY packaging audit (touchpoint map)

**Zig import graph (post-`CZH-617`, path post-`CZH-S4`)**

- **`bridge.zig`** — `@import("../byo_pty_host.zig")` for the BYO-PTY seam; session
  / transport forwards use identifier `byo_pty_host`.
- **`core_api.zig`**, **`shared.zig`** — doc cross-references to
  `../byo_pty_host.zig` / BYO seam only (no imports).

**Exported C surface**

- **`c_api.zig`** / **`terminal_ffi_exports.zig`** — thin wrappers over
  `bridge.zig` only; **no** dependency on the Zig filename of the BYO module.
  **No C symbol churn** from a pure file rename.

**Coupled core (unchanged by packaging rename)**

- `src/terminal/core/session/runtime.zig`, `input.zig`, etc. — still the engine
  owners; the BYO seam module calls into them.

**Packaging cut (`CZH-617` — landed)**

- `byo_pty_host.zig` (renamed from `host_api.zig`; originally under `ffi/`).
- **`bridge.zig`** imports the BYO module; call sites use `byo_pty_host`.
- Authority docs refreshed in **`CZH-619`**.

**Directory ownership (`CZH-S4` — landed)**

- `src/terminal/ffi/byo_pty_host.zig` → `src/terminal/byo_pty_host.zig` (no shim in
  `ffi/`); **`bridge.zig`** uses `@import("../byo_pty_host.zig")`.

#### `CZH-S3` engineer validation (`CZH-620`)

- **Date:** 2026-04-19  
- **Tickets:** `CZH-616`..`CZH-620` (one commit each).  
- **SL-0** `zig build` — PASS  
- **SL-1** `zig build test` — PASS  
- **SL-2** `zig build -Dmode=terminal` — PASS  
- **SL-3** `zig build -Dmode=editor` — PASS  
- **`zig build test-config`** — PASS  
- **`zig build test-editor`** — PASS  
- **`zig build test-terminal-replay-all`** — PASS  
- **Android guard** — SKIP (lane paused)

Checkpoint packet: `docs/todo/core/CZH_S3_CHECKPOINT.md`.

#### `CZH-S4` engineer validation (`CZH-625`)

- **Date:** 2026-04-19  
- **Tickets:** `CZH-621`..`CZH-625` (one commit each).  
- **SL-0** `zig build` — PASS  
- **SL-1** `zig build test` — PASS  
- **SL-2** `zig build -Dmode=terminal` — PASS  
- **SL-3** `zig build -Dmode=editor` — PASS  
- **`zig build test-config`** — PASS  
- **`zig build test-editor`** — PASS  
- **`zig build test-terminal-replay-all`** — PASS  
- **Android guard** — SKIP (lane paused)

Checkpoint packet: `docs/todo/core/CZH_S4_CHECKPOINT.md`.

#### Architect gate result

- `Review chunk: CZH-B9`
- `Verdict: accepted`
- `Engineer commits reviewed:` `088c075b`, `d9a60ca4`, `eafac101`, `e8ed828f`,
  `03dc5fcc`
- `Architect validation spot-check:` `zig build test-config PASS`,
  `zig build test-editor PASS`, `zig build test-terminal-replay-all PASS`
- `Acceptance judgment:` the optional BYO-PTY seam now lives under
  `src/terminal/` instead of `src/terminal/ffi/`, so directory ownership is
  finally aligned with the accepted split. Bridge behavior and exported C
  symbols remained stable through the move.

### `CZH-B10` FFI/Export Doc-Alignment Closure (`accepted`)

Queue line (exact):

- close the remaining FFI/export doc-alignment drift so the queue audit,
  authority docs, and current code all describe the same ownership reality

Acceptance:

- stale audit rows claiming missing editor FFI module docs are removed or
  corrected
- remaining important FFI/editor-FFI/export entrypoints have concise,
  ownership-accurate `///` docs where still missing
- queue and authority docs no longer lag accepted code state
- full stress ladder remains green through `CZH-GATE-64`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S5_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

Execution source:

- engineer executes `CZH-626`..`CZH-630` in order from
  `docs/todo/core/CZH_S5_TICKETS.md`
- one ticket per commit unless explicitly marked otherwise
- stop only at `CZH-GATE-64` or a real hard blocker

#### `CZH-B10` scope note

This sprint is intentionally narrow. It does **not** reopen architecture shape
or move files again. It closes the remaining doc/audit truthfulness gap that is
still visible after `CZH-B7`..`CZH-B9`, especially the stale `CZH-608` table
rows that still claim missing module docs for `src/editor/ffi/bridge.zig` and
`src/editor/ffi/c_api.zig`.

#### `CZH-S5` engineer validation (`CZH-630`)

- **Date:** 2026-04-19  
- **Tickets:** `CZH-626`..`CZH-630` (one commit each).  
- **SL-0** `zig build` — PASS  
- **SL-1** `zig build test` — PASS  
- **SL-2** `zig build -Dmode=terminal` — PASS  
- **SL-3** `zig build -Dmode=editor` — PASS  
- **`zig build test-config`** — PASS  
- **`zig build test-editor`** — PASS  
- **`zig build test-terminal-replay-all`** — PASS  
- **Android guard** — SKIP (lane paused)

Checkpoint packet: `docs/todo/core/CZH_S5_CHECKPOINT.md`.

#### Architect gate result

- `Review chunk: CZH-B10`
- `Verdict: accepted`
- `Engineer commits reviewed:` `850561fb`, `b63d3c90`, `d632c93d`, `605d081e`,
  `76df6d2f`
- `Architect validation spot-check:` `zig build test-config PASS`,
  `zig build test-editor PASS`, `zig build test-terminal-replay-all PASS`
- `Acceptance judgment:` FFI/export doc alignment is now coherent: queue audits,
  `CZH-608` table state, and the touched source files describe the same
  ownership and contract shape.

### `CZH-B11` Remove Residual FFI Debug Test Hook (`accepted`)

Queue line (exact):

- eliminate the remaining debug hook surface from product FFI code by removing
  `destroy_debug_pause_ms_for_tests` from `core_api.zig` and relocating test
  behavior to test-owned seams only

Acceptance:

- `src/terminal/ffi/core_api.zig` no longer contains
  `destroy_debug_pause_ms_for_tests`
- FFI destroy semantics remain unchanged for production behavior
- FFI smoke tests keep equivalent coverage without product debug globals
- queue/handoff/entrypoint and authority docs reflect the post-removal truth
- full stress ladder remains green through `CZH-GATE-65`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S6_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

Execution source:

- engineer executes `CZH-631`..`CZH-635` in order from
  `docs/todo/core/CZH_S6_TICKETS.md`
- one ticket per commit unless explicitly marked otherwise
- stop only at `CZH-GATE-65` or a real hard blocker

#### `CZH-631` destroy debug-hook audit (`CZH-S6`)

**Read/write paths (`main` pre-change)**

| Site | Role |
| --- | --- |
| `src/terminal/ffi/core_api.zig` | `pub var destroy_debug_pause_ms_for_tests` (atomic `u32`). |
| `core_api.destroy` | If `builtin.is_test` and value \> 0: `Thread.sleep` that many ms after `destroying.store(true)`. |
| `tests/terminal_ffi_smoke_tests.zig` | `store(150)` before spawning destroy thread; `defer store(0)`. |

**Intent of** `test "ffi destroy blocks host-visible transport and event calls once teardown begins"`:
concurrent destroy vs main thread; main observes `invalid_argument` (`1`) on FFI
calls while teardown is in progress. The 150 ms pause **widened** the window
where `destroying` stays true during deinit.

**Replacement plan (no product globals)**

- **`CZH-632`:** Delete the atomic, delete the `builtin.is_test` sleep block, drop
  `builtin` import if unused. **`destroy`:** keep `destroying.store(true, .release)`
  as the first effect; single-line `///` (no test-hook wording).
- **`CZH-633`:** Tests import `src/terminal/ffi/shared.zig`, resolve
  `shared.fromOpaque(handle).?`, spin until `raw.destroying.load(.acquire)` after
  spawning `zide_terminal_destroy`, **then** run the same FFI assertions (remove
  `core_api` global usage). This is test-only observation of an atomic already on
  `Handle`; no new product seam.
- **`CZH-634`:** Update `CZH-606` removal queue row, `CZH-608` destroy row, and any
  `implementation.md` / handoff lines that still name the removed hook.

**Landed (`CZH-632`..`CZH-634`):** `destroy_debug_pause_ms_for_tests` and test sleep
removed from `core_api.destroy`; `tests/terminal_ffi_smoke_tests.zig` syncs via
`shared.fromOpaque` + spin on `Handle.destroying`; queue (`CZH-606` / `CZH-608`)
updated.

#### Architect gate result

- `Review chunk: CZH-B11`
- `Verdict: accepted`
- `Engineer commits reviewed:` `3c27f8f0`, `55aa37f8`, `430281f0`, `901e2c44`,
  `13fd2057`
- `Architect validation spot-check:` `zig build test-config PASS`,
  `zig build test-editor PASS`, `zig build test-terminal-replay-all PASS`
- `Acceptance judgment:` product FFI destroy no longer carries debug timing hooks;
  teardown synchronization now lives in test-owned code only.

#### `CZH-626` FFI/export doc drift audit (`CZH-S5`)

**Stale history (fix in `CZH-629`):** the `CZH-608` module-doc table still lists
`editor/ffi/bridge.zig` and `editor/ffi/c_api.zig` as missing `//!` — **false**
as of current `main` (both carry module docs). The “Important function doc drift”
rows that claim `core_api.destroy` has **no** `///` are also **false** (destroy
has a `///` block; the earlier test-timing note is historical and was removed in
`CZH-S6`).

**Truthful state today**

| File | Module `//!` | Notes |
| --- | --- | --- |
| `src/editor/ffi/bridge.zig` | **Yes** | Editor backend FFI facade (`CZH-S5` verified). |
| `src/editor/ffi/c_api.zig` | **Yes** | Flat `zide_editor_*` forwarders. |
| `src/terminal/ffi/bridge.zig` | **Yes** | VT core + BYO join; current. |
| `src/terminal/ffi/core_api.zig` | **Yes** | VT core publication/query surface. |
| `src/terminal_ffi_exports.zig` | **Yes** (thin) | Accurate but **minimal** — expand in `CZH-627`. |

**`CZH-627` scope (module docs only, no logic):** strengthen `//!` on
`src/terminal_ffi_exports.zig` so ownership (symbol root vs `c_api` behavior) is
explicit. Editor + terminal facades above already carry `//!`; no packaging move.

**`CZH-628` scope (`///` on important entrypoints, no spam):**

- `src/editor/ffi/bridge.zig` — add concise `///` on **`create`** and **`destroy`**
  (foreign-host handle lifecycle vs in-process `Editor`).
- **`destroy` test-hook `///` note (`CZH-628`):** superseded — hook removed in
  `CZH-S6` (`CZH-B11`); `destroy` docs are product-only.
- `src/terminal/ffi/core_api.zig` — add concise `///` on publication/query
  exports that still lack any `///`: **`acknowledgedGeneration`**,
  **`publishedGeneration`**, **`closeConfirmSignals`**, **`closeInput`**,
  **`pendingInputAcquire`**, **`pendingInputRelease`**, **`scrollbackAcquire`** /
  **`scrollbackRelease`**, **`metadataAcquire`** / **`metadataRelease`**,
  **`activityAcquire`** / **`activityRelease`**, **`eventDrain`** /
  **`eventsFree`**, **`selectionText`**, **`clipboardWrite`**,
  **`scrollbackPlainText`**, **`scrollbackAnsiText`**, **`stringFree`** (string
  buffers), **`rendererMetadata`**. **Out of scope for this sprint:** ABI
  version getters (`*AbiVersion`) — thin constants, self-explanatory names.

**`CZH-629`:** rewrite the `CZH-608` table + “Doc-alignment queue” bullets so
they match this audit; drop completed “add `//!` to editor FFI” items.

**Completion (`CZH-627`..`CZH-629` landed):** `terminal_ffi_exports` `//!` expanded;
`CZH-608` table synced; `///` work per `CZH-628` list applied in
`src/terminal/ffi/core_api.zig` and `src/editor/ffi/bridge.zig`.

#### `CZH-S5` engineer validation (`CZH-630`)

- **Date:** 2026-04-19  
- **Tickets:** `CZH-626`..`CZH-630` (one commit each).  
- **SL-0** `zig build` — PASS  
- **SL-1** `zig build test` — PASS  
- **SL-2** `zig build -Dmode=terminal` — PASS  
- **SL-3** `zig build -Dmode=editor` — PASS  
- **`zig build test-config`** — PASS  
- **`zig build test-editor`** — PASS  
- **`zig build test-terminal-replay-all`** — PASS  
- **Android guard** — SKIP (lane paused)

Checkpoint packet: `docs/todo/core/CZH_S5_CHECKPOINT.md`.

#### `CZH-S6` engineer validation (`CZH-635`)

- **Date:** 2026-04-19  
- **Tickets:** `CZH-631`..`CZH-635` (one commit each).  
- **SL-0** `zig build` — PASS  
- **SL-1** `zig build test` — PASS  
- **SL-2** `zig build -Dmode=terminal` — PASS  
- **SL-3** `zig build -Dmode=editor` — PASS  
- **`zig build test-config`** — PASS  
- **`zig build test-editor`** — PASS  
- **`zig build test-terminal-replay-all`** — PASS  
- **Android guard** — SKIP (lane paused)

Checkpoint packet: `docs/todo/core/CZH_S6_CHECKPOINT.md`.

### `CZH-B12` Terminal Surface Contract Wiring Seed (`accepted`)

Queue line (exact):

- begin wiring the accepted terminal surface contract into code with explicit
  shared-surface ownership seams, while preserving current runtime behavior

Acceptance:

- current terminal surface ownership/wiring touchpoints are audited and mapped
- first explicit shared-surface seam types/helpers land in code
- one behavior-neutral wiring cut uses the new seam surface
- queue/handoff/entrypoint and authority docs remain aligned
- full stress ladder remains green through `CZH-GATE-66`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S7_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

Execution source:

- engineer executes `CZH-636`..`CZH-640` in order from
  `docs/todo/core/CZH_S7_TICKETS.md`
- one ticket per commit unless explicitly marked otherwise
- stop only at `CZH-GATE-66` or a real hard blocker

#### `CZH-636` terminal surface ownership touchpoint map (`CZH-S7`)

**Authority:** `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md` — shared GPU
attachment + Zide-owned generation/dirty truth + host presentation completion via
FFI `present_ack` / `acknowledged_generation`.

| Layer | Primary paths | Role |
| --- | --- | --- |
| VT core FFI (logical surface state) | `src/terminal/ffi/core_api.zig` — `presentAck`, `publishedGeneration`, `acknowledgedGeneration`, `redrawState`, `needsRedraw` | Portable generation pairing for hosts; **no** raw GPU handles on this boundary (`TERMINAL_SURFACE_CONTRACT.md` §FFI touchpoints). |
| FFI ABI structs | `src/terminal/ffi/shared.zig` — `RedrawState` | Extern bundle for published/ack/`needs_redraw`. |
| Bridge / C exports | `bridge.zig`, `c_api.zig`, `terminal_ffi_exports.zig` | Stable C names; unchanged ABI in `CZH-S7`. |
| IDE gating (“terminal surface” feature) | `src/app/terminal/terminal_surface_gate.zig`, `src/app/modes/ide/host.zig` | When a terminal **tab surface** may be shown / receive input (not the publication contract center). |
| Widget draw + presentation | `src/ui/widgets/terminal_widget*.zig`, `terminal_widget_presentation_runtime.zig`, `terminal_widget_surface_state.zig` | GPU draw scheduling vs `terminal_view.generation` (widget publication coupling). |

**First-cut seam plan (`CZH-637`..`CZH-638`)**

- Add **`src/terminal/surface_contract.zig`**: explicit **logical** surface-frame
  naming (published vs acknowledged + derived `needs_redraw`) aligned to the
  contract doc; helpers to fill `shared.RedrawState` without a second truth
  source.
- **`CZH-638`:** route **`core_api.redrawState`** through the helper (behavior-neutral
  refactor).
- **`CZH-639`:** point `TERMINAL_SURFACE_CONTRACT.md` / queue at the landed module +
  wiring path.

**Landed (`CZH-637`..`CZH-639`):** `surface_contract.zig` + `tests_main` import;
`core_api.redrawState` / `needsRedraw` use `fillRedrawState` /
`needsRedrawFromPair`; `TERMINAL_SURFACE_CONTRACT.md` references the Zig seam.

#### `CZH-S7` engineer validation (`CZH-640`)

- **Date:** 2026-04-19  
- **Tickets:** `CZH-636`..`CZH-640` (one commit each).  
- **SL-0** `zig build` — PASS  
- **SL-1** `zig build test` — PASS  
- **SL-2** `zig build -Dmode=terminal` — PASS  
- **SL-3** `zig build -Dmode=editor` — PASS  
- **`zig build test-config`** — PASS  
- **`zig build test-editor`** — PASS  
- **`zig build test-terminal-replay-all`** — PASS  
- **Android guard** — SKIP (lane paused)

Checkpoint packet: `docs/todo/core/CZH_S7_CHECKPOINT.md`.

#### Architect gate result

- `Review chunk: CZH-B12`
- `Verdict: accepted`
- `Engineer commits reviewed:` `28711290`, `8c0e65ae`, `4d78a473`, `fdc33518`,
  `518fea84`
- `Architect validation spot-check:` `zig build test-config PASS`,
  `zig build test-editor PASS`, `zig build test-terminal-replay-all PASS`
- `Acceptance judgment:` explicit surface-contract seam (`surface_contract.zig`)
  now exists in code and is wired through `core_api.redrawState` /
  `core_api.needsRedraw` without behavior or ABI drift.

### `CZH-B13` Surface Contract Wiring Expansion (`accepted`)

Queue line (exact):

- expand terminal surface-contract seam usage to one additional bounded path so
  ownership is encoded in live wiring rather than remaining helper-local

Acceptance:

- touchpoint audit identifies the next bounded surface ownership crossing
- one additional behavior-neutral path adopts seam types/helpers
- seam invariants are covered by test assertions for the expanded path
- queue/handoff/entrypoint and authority docs remain aligned
- full stress ladder remains green through `CZH-GATE-67`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S8_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

Execution source:

- engineer executes `CZH-641`..`CZH-645` in order from
  `docs/todo/core/CZH_S8_TICKETS.md`
- one ticket per commit unless explicitly marked otherwise
- stop only at `CZH-GATE-67` or a real hard blocker

#### `CZH-641` next bounded surface-contract crossing (`CZH-S8`)

**Already seam-backed (`CZH-B12`):** `core_api.redrawState` / `needsRedraw` use
`surface_contract.fillRedrawState` / `needsRedrawFromPair`.

**Selected expansion (`CZH-642`..`CZH-643`):** `core_api.presentAck` — host calls FFI
after binding/presenting the shared GPU attachment; Zide must reject impossible
`generation` values vs **publication truth** and **last acknowledged**
generation (`TERMINAL_SURFACE_CONTRACT.md` §ownership: host reports presentation
completion through shared FFI). Today this is two implicit comparisons; the cut
routes the **admissibility predicate** through `surface_contract.zig` so the
surface contract names the same monotonic window as `redraw_state`.

**Not in scope this sprint:** terminal widget GPU draw paths (different
`generation` symbol — widget publication coupling); no ABI or renderer policy
change.

**Plan:** add `presentAckGenerationAdmissible` (or equivalent) in
`surface_contract.zig`; **`presentAck`** early-return uses it; **`CZH-644`** adds
unit tests for predicate edges + doc pointer.

**Landed (`CZH-642`..`CZH-644`):** `presentAckGenerationAdmissible` in
`surface_contract.zig`; `core_api.presentAck` uses it; tests + authority seam
paragraph updated.

#### `CZH-S8` engineer validation (`CZH-645`)

- **Date:** 2026-04-19  
- **Tickets:** `CZH-641`..`CZH-645` (one commit each).  
- **SL-0** `zig build` — PASS  
- **SL-1** `zig build test` — PASS  
- **SL-2** `zig build -Dmode=terminal` — PASS  
- **SL-3** `zig build -Dmode=editor` — PASS  
- **`zig build test-config`** — PASS  
- **`zig build test-editor`** — PASS  
- **`zig build test-terminal-replay-all`** — PASS  
- **Android guard** — SKIP (lane paused)

Checkpoint packet: `docs/todo/core/CZH_S8_CHECKPOINT.md`.

#### Architect gate result

- `Review chunk: CZH-B13`
- `Verdict: accepted`
- `Engineer commits reviewed:` `c8f6a41e`, `8657ff26`, `f8c5d492`, `7c036b79`,
  `964ec2b9`
- `Architect validation spot-check:` `zig build test-config PASS`,
  `zig build test-editor PASS`, `zig build test-terminal-replay-all PASS`
- `Acceptance judgment:` `present_ack` admissibility now routes through the
  explicit surface-contract seam with no behavior or ABI drift.

### `CZH-B14` Surface Contract Consumer Expansion (`accepted`)

Queue line (exact):

- expand surface-contract seam consumption to one additional bounded
  draw/presentation-facing path while preserving behavior and host ABI

Acceptance:

- one additional bounded consumer path is selected via audit
- minimal seam helpers/types for that path are added behavior-neutrally
- selected path adopts the seam helpers/types with equivalent runtime behavior
- queue/handoff/entrypoint and authority docs remain aligned
- full stress ladder remains green through `CZH-GATE-68`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S9_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

Execution source:

- engineer executes `CZH-646`..`CZH-650` in order from
  `docs/todo/core/CZH_S9_TICKETS.md`
- one ticket per commit unless explicitly marked otherwise
- stop only at `CZH-GATE-68` or a real hard blocker

#### `CZH-646` draw/presentation seam consumer audit (`CZH-S9`)

**Selected path:** `src/ui/widgets/terminal_widget_presentation_runtime.zig` —
`buildTerminalPresentPlan` computes `generation_matches_presented` from
`terminal_view.generation` vs `self.surface.lastRenderGeneration()` (plus
`clear_generation` vs last clear gen). The **publication vs last surface-render
generation** limb is the same inequality predicate as FFI `needs_redraw` /
`redraw_state` (`surface_contract.needsRedrawFromPair`), but was implicit (`==`
on both limbs).

**Plan (`CZH-647`..`CZH-648`):** add a named helper on
`src/terminal/surface_contract.zig` for the publication-vs-last-surface-render
mismatch; **`buildTerminalPresentPlan`** uses it for the generation limb only
(clear-generation limb unchanged). **No** draw policy / present-plan branching
changes.

**`CZH-649`:** predicate test + `TERMINAL_SURFACE_CONTRACT.md` consumer note.

**Landed (`CZH-647`..`CZH-649`):** `publicationGenerationDiffersFromLastSurfaceRender`;
`buildTerminalPresentPlan` uses it; tests + `TERMINAL_SURFACE_CONTRACT.md` widget
paragraph.

#### `CZH-S9` engineer validation (`CZH-650`)

- **Date:** 2026-04-19  
- **Tickets:** `CZH-646`..`CZH-650` (one commit each).  
- **SL-0** `zig build` — PASS  
- **SL-1** `zig build test` — PASS  
- **SL-2** `zig build -Dmode=terminal` — PASS  
- **SL-3** `zig build -Dmode=editor` — PASS  
- **`zig build test-config`** — PASS  
- **`zig build test-editor`** — PASS  
- **`zig build test-terminal-replay-all`** — PASS  
- **Android guard** — SKIP (lane paused)

Checkpoint packet: `docs/todo/core/CZH_S9_CHECKPOINT.md`.

#### Architect gate result

- `Review chunk: CZH-B14`
- `Verdict: accepted`
- `Engineer commits reviewed:` `a501dcd8`, `6aa45e5c`, `2f3ce267`, `6c672952`,
  `6ab36079`
- `Architect validation spot-check:` `zig build test-config PASS`,
  `zig build test-editor PASS`, `zig build test-terminal-replay-all PASS`
- `Acceptance judgment:` widget present-plan generation match now consumes the
  explicit surface-contract seam in a behavior-neutral cut; host ABI unchanged.

### `CZH-B15` Surface Contract Consumer Expansion II (`accepted`)

Queue line (exact):

- expand surface-contract seam consumption to one additional bounded
  draw/presentation-facing path while preserving behavior and host ABI

Acceptance:

- one additional bounded consumer path is selected via audit
- minimal seam helpers/types for that path are added behavior-neutrally
- selected path adopts the seam helpers/types with equivalent runtime behavior
- queue/handoff/entrypoint and authority docs remain aligned
- full stress ladder remains green through `CZH-GATE-69`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S10_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

Execution source:

- engineer executes `CZH-651`..`CZH-655` in order from
  `docs/todo/core/CZH_S10_TICKETS.md`
- one ticket per commit unless explicitly marked otherwise
- stop only at `CZH-GATE-69` or a real hard blocker

#### `CZH-651` draw/presentation seam consumer audit (`CZH-S10`)

**Selected path target:** clear-generation limb in
`src/ui/widgets/terminal_widget_presentation_runtime.zig`
(`terminal_view.clear_generation` vs
`self.surface.lastRenderClearGeneration()`) that still uses an implicit
equality predicate.

**Plan (`CZH-652`..`CZH-653`):** add a named helper on
`src/terminal/surface_contract.zig` for clear-generation-vs-last-surface-clear
mismatch; route `buildTerminalPresentPlan` clear-generation limb through that
helper only. **No** draw policy / present-plan branching changes.

**`CZH-654`:** predicate test + `TERMINAL_SURFACE_CONTRACT.md` consumer note.

**`CZH-655`:** validation ladder + checkpoint packet + board/queue/handoff sync
to `CZH-GATE-69`.

**Engineer (CZH-651):** Confirmed in `buildTerminalPresentPlan`
(`terminal_widget_presentation_runtime.zig`): the clear-generation consumer is
the conjunct `terminal_view.clear_generation ==
self.surface.lastRenderClearGeneration()` (paired with the publication-generation
mismatch limb). No plan change from the `CZH-652`..`CZH-653` seam-cut above.

#### Landed (`CZH-652`..`CZH-654`)

- `surface_contract.clearGenerationDiffersFromLastSurfaceRenderClear`
- `buildTerminalPresentPlan` uses `clear_gen_mismatch_surface` with that helper
  (paired with the publication-generation limb)
- unit test aliases `needsRedrawFromPair`; `TERMINAL_SURFACE_CONTRACT.md` widget
  draw consumer updated

#### `CZH-S10` engineer validation (`CZH-655`)

- **Date:** 2026-04-19  
- **Tickets:** `CZH-651`..`CZH-655` (one commit each).  
- **SL-0** `zig build` — PASS  
- **SL-1** `zig build test` — PASS  
- **SL-2** `zig build -Dmode=terminal` — PASS  
- **SL-3** `zig build -Dmode=editor` — PASS  
- **`zig build test-config`** — PASS  
- **`zig build test-editor`** — PASS  
- **`zig build test-terminal-replay-all`** — PASS  
- **Android guard** — SKIP (lane paused)

Checkpoint packet: `docs/todo/core/CZH_S10_CHECKPOINT.md`.

#### Architect gate result

- `Review chunk: CZH-B15`
- `Verdict: accepted`
- `Engineer commits reviewed:` `116636d4`, `23faf7bb`, `07f0023f`, `98aaa494`,
  `63854b41`
- `Architect validation spot-check:` `zig build test-config PASS`,
  `zig build test-editor PASS`, `zig build test-terminal-replay-all PASS`
- `Acceptance judgment:` clear-generation reuse limb now consumes
  `surface_contract` in a behavior-neutral cut; host ABI unchanged.

### `CZH-B16` Surface Contract Consumer Expansion III (`accepted`)

Queue line (exact):

- expand surface-contract seam consumption to one additional bounded
  draw/presentation-facing path while preserving behavior and host ABI

Acceptance:

- one additional bounded consumer path is selected via audit
- minimal seam helpers/types for that path are added behavior-neutrally
- selected path adopts the seam helpers/types with equivalent runtime behavior
- queue/handoff/entrypoint and authority docs remain aligned
- full stress ladder remains green through `CZH-GATE-70`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S11_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

Execution source:

- engineer executes `CZH-656`..`CZH-660` in order from
  `docs/todo/core/CZH_S11_TICKETS.md`
- one ticket per commit unless explicitly marked otherwise
- stop only at `CZH-GATE-70` or a real hard blocker

#### `CZH-656` draw/presentation seam consumer audit (`CZH-S11`)

**Selected path target:** `presentationUpdateDelta` in
`src/ui/widgets/terminal_widget_surface_state.zig`, where
`generation_changed` and `clear_generation_changed` are still implicit direct
inequality checks against last rendered generations.

**Plan (`CZH-657`..`CZH-658`):** add named mismatch helpers on
`src/terminal/surface_contract.zig` for the `presentationUpdateDelta` consumer
path and route these two predicates through seam helpers only. **No** policy
or branching changes.

**`CZH-659`:** predicate tests + `TERMINAL_SURFACE_CONTRACT.md` consumer note.

**`CZH-660`:** validation ladder + checkpoint packet + board/queue/handoff sync
to `CZH-GATE-70`.

**Engineer (CZH-656):** Confirmed in `TerminalWidgetSurfaceState.presentationUpdateDelta`
(`terminal_widget_surface_state.zig`): `generation_changed` and
`clear_generation_changed` are the publication vs `last_render_generation` and
clear vs `last_render_clear_generation` inequality limbs. Plan: route both
through existing `surface_contract` mismatch helpers (`CZH-657`..`CZH-658`); no
new predicate surface beyond doc binding where needed.

#### Landed (`CZH-657`..`CZH-659`)

- `surface_contract` docs bind `presentationUpdateDelta` to the publication and
  clear mismatch helpers
- `presentationUpdateDelta` routes both `*_changed` fields through those helpers
- unit test + `TERMINAL_SURFACE_CONTRACT.md` widget consumer line

#### `CZH-S11` engineer validation (`CZH-660`)

- **Date:** 2026-04-19  
- **Tickets:** `CZH-656`..`CZH-660` (one commit each).  
- **SL-0** `zig build` — PASS  
- **SL-1** `zig build test` — PASS  
- **SL-2** `zig build -Dmode=terminal` — PASS  
- **SL-3** `zig build -Dmode=editor` — PASS  
- **`zig build test-config`** — PASS  
- **`zig build test-editor`** — PASS  
- **`zig build test-terminal-replay-all`** — PASS  
- **Android guard** — SKIP (lane paused)

Checkpoint packet: `docs/todo/core/CZH_S11_CHECKPOINT.md`.

#### Architect gate result

- `Review chunk: CZH-B16`
- `Verdict: accepted`
- `Engineer commits reviewed:` `c3f5d301`, `98d25d25`, `7cdabc0d`, `c46a4831`,
  `616800ac`
- `Architect validation spot-check:` `zig build test-config PASS`,
  `zig build test-editor PASS`, `zig build test-terminal-replay-all PASS`
- `Acceptance judgment:` `presentationUpdateDelta` generation/clear-generation
  mismatch fields now consume the explicit `surface_contract` seam in a
  behavior-neutral cut; host ABI unchanged.

### `CZH-B17` Long-Loop Surface Contract Pack + Hygiene Sweep (`accepted`)

Queue line (exact):

- execute a longer engineering loop (10-ticket pack) that lands two bounded
  surface-contract consumer consolidations plus a scoped probe/doc hygiene pass
  while preserving behavior and host ABI

Acceptance:

- two additional bounded draw/presentation-facing consumers are routed through
  explicit `surface_contract` helper ownership
- one scoped probe/doc hygiene sweep is completed across touched modules with no
  behavior drift
- queue/handoff/entrypoint and authority docs remain aligned
- full stress ladder remains green through `CZH-GATE-71`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S12_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

Execution source:

- engineer executes `CZH-661`..`CZH-670` in order from
  `docs/todo/core/CZH_S12_TICKETS.md`
- one ticket per commit unless explicitly marked otherwise
- stop only at `CZH-GATE-71` or a real hard blocker

#### `CZH-661` multi-consumer + hygiene audit (`CZH-S12`)

**Selected target set:**

- `src/ui/widgets/terminal_widget_presentation_runtime.zig`:
  `generation_matches_presented` conjunct ownership path
- `src/ui/widgets/terminal_widget_surface_state.zig`:
  `presentationUpdateDelta` helper-wiring follow-through path
- `src/terminal/surface_contract.zig`:
  helper ownership center and doc locks

**Plan (`CZH-662`..`CZH-666`):**

- add small composite seam helpers for generation/clear generation pairing
- route runtime and surface-state call sites through those helpers
- keep behavior/ABI unchanged

**Plan (`CZH-667`..`CZH-669`):**

- strengthen seam tests for composite helper invariants
- run scoped probe/doc hygiene sweep in touched modules
- align authority docs to landed terms only

**`CZH-670`:** validation ladder + checkpoint packet + board/queue/handoff sync
to `CZH-GATE-71`.

**Engineer (CZH-661):** Confirmed plan: composite publication/clear pair seam in
`surface_contract.zig`; route `buildTerminalPresentPlan.generation_matches_presented`
and `presentationUpdateDelta` generation fields through that composite (`CZH-662`..`CZH-664`).
Hygiene sweep scope for `CZH-668`: `surface_contract.zig`,
`terminal_widget_presentation_runtime.zig`, `terminal_widget_surface_state.zig`
only.

#### `CZH-668` probe/debug sweep (`CZH-S12`)

- **Reviewed:** `surface_contract.zig`, `terminal_widget_presentation_runtime.zig`,
  `terminal_widget_surface_state.zig`.
- **Removed:** nothing (no stale investigation-only probe callers in these paths).
- **Kept:** `terminal_widget_presentation_runtime` operator `app_logger` warning for
  surface-unavailable present; existing `debug` sample sinks unchanged (product
  instrumentation, not sprint probes).

#### Landed (`CZH-662`..`CZH-669`)

- Composite pair seam: `publicationClearPairMismatchesFromLastSurfaceRender`,
  `publicationClearPairMatchesLastSurfaceRender` (`surface_contract.zig`)
- Present-plan reuse and `presentationUpdateDelta` route through composite helpers
- Seam invariant tests (`CZH-666`, `CZH-667`); probe sweep note (`CZH-668`)
- `TERMINAL_SURFACE_CONTRACT.md` widget consumer updated to composite truth

#### `CZH-S12` engineer validation (`CZH-670`)

- **Date:** 2026-04-19  
- **Tickets:** `CZH-661`..`CZH-670` (one commit each).  
- **SL-0** `zig build` — PASS  
- **SL-1** `zig build test` — PASS  
- **SL-2** `zig build -Dmode=terminal` — PASS  
- **SL-3** `zig build -Dmode=editor` — PASS  
- **`zig build test-config`** — PASS  
- **`zig build test-editor`** — PASS  
- **`zig build test-terminal-replay-all`** — PASS  
- **Android guard** — SKIP (lane paused)

Checkpoint packet: `docs/todo/core/CZH_S12_CHECKPOINT.md`.

#### Architect gate result

- `Review chunk: CZH-B17`
- `Verdict: accepted`
- `Engineer commits reviewed:` `cb1949c1`, `d9b85611`, `210390d7`, `e570eadf`,
  `68b2d9af`, `78acf8d3`, `89d864ae`, `913362be`, `4e276f06`, `0ac00467`
- `Architect validation spot-check:` `zig build test-config PASS`,
  `zig build test-editor PASS`, `zig build test-terminal-replay-all PASS`
- `Acceptance judgment:` composite publication/clear seam is now the explicit
  ownership center for present-plan reuse and `presentationUpdateDelta`; scoped
  probe/doc hygiene completed with no behavior or ABI drift.

### `CZH-B18` Long-Loop FFI/Surface Consolidation Pack (`accepted`)

Queue line (exact):

- execute a longer engineering loop (10-ticket pack) that consolidates VT FFI
  redraw-state/present-ack seam consumption under `surface_contract` plus a
  bounded doc/probe hygiene sweep, behavior-neutral

Acceptance:

- redraw-state and present-ack seam call sites use explicit
  `surface_contract` ownership helpers with equivalent behavior
- touched module docs reflect final ownership truth and are drift-free
- scoped probe/doc hygiene sweep is recorded for touched modules
- queue/handoff/entrypoint and authority docs remain aligned
- full stress ladder remains green through `CZH-GATE-72`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S13_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

Execution source:

- engineer executes `CZH-671`..`CZH-680` in order from
  `docs/todo/core/CZH_S13_TICKETS.md`
- one ticket per commit unless explicitly marked otherwise
- stop only at `CZH-GATE-72` or a real hard blocker

#### `CZH-671` FFI/surface seam + hygiene audit (`CZH-S13`)

**Selected target set:**

- `src/terminal/ffi/core_api.zig`: redraw-state and present-ack seam call sites
- `src/terminal/surface_contract.zig`: helper ownership center and naming
- `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md`: FFI binding wording

**Plan (`CZH-672`..`CZH-676`):**

- add bounded helper wrappers for FFI redraw/present-ack semantics where needed
- route `core_api` call sites through those helpers only
- keep behavior/ABI unchanged

**Plan (`CZH-677`..`CZH-679`):**

- lock seam invariants in focused tests
- run scoped probe/doc hygiene sweep in touched modules
- align authority docs to landed terms only

**`CZH-680`:** validation ladder + checkpoint packet + board/queue/handoff sync
to `CZH-GATE-72`.

**Engineer (CZH-671):** Confirmed plan: add explicit `ffi*` wrappers in
`surface_contract.zig` for VT core `redraw_state`, `needs_redraw`, and
`present_ack` admissibility; route `core_api` through those wrappers only
(`CZH-672`..`CZH-675`). Hygiene scope for `CZH-679`: `core_api.zig`,
`surface_contract.zig`, `TERMINAL_SURFACE_CONTRACT.md`.

#### `CZH-679` probe/doc hygiene (`CZH-S13`)

- **Reviewed:** `src/terminal/ffi/core_api.zig`, `src/terminal/surface_contract.zig`
  (stale probe/debug sweep).
- **Removed:** nothing (no investigation-only probe callers in touched seam paths;
  existing `log.logf` warnings remain operator/error signals).
- **Authority:** `TERMINAL_SURFACE_CONTRACT.md` FFI paragraph updated to `ffi*`
  entrypoints (`CZH-S13`).

#### Landed (`CZH-672`..`CZH-679`)

- VT FFI wrappers: `ffiRedrawStateFill`, `ffiNeedsRedrawU8`,
  `ffiPresentAckGenerationAdmissible`; `core_api` routes through them
- Seam invariant tests in `surface_contract.zig` and `core_api.zig`
- Probe sweep + authority sync (`CZH-679`)

#### `CZH-S13` engineer validation (`CZH-680`)

- **Date:** 2026-04-19  
- **Tickets:** `CZH-671`..`CZH-680` (one commit each).  
- **SL-0** `zig build` — PASS  
- **SL-1** `zig build test` — PASS  
- **SL-2** `zig build -Dmode=terminal` — PASS  
- **SL-3** `zig build -Dmode=editor` — PASS  
- **`zig build test-config`** — PASS  
- **`zig build test-editor`** — PASS  
- **`zig build test-terminal-replay-all`** — PASS  
- **Android guard** — SKIP (lane paused)

Checkpoint packet: `docs/todo/core/CZH_S13_CHECKPOINT.md`.

#### Architect gate result

- `Review chunk: CZH-B18`
- `Verdict: accepted`
- `Engineer commits reviewed:` `6106f474`, `6f7377e3`, `d3d8285e`, `f0589eef`,
  `37f1a07d`, `addc96fd`, `c716a112`, `6e1563f3`, `e8bb08c9`, `ac07c395`
- `Architect validation spot-check:` `zig build test-config PASS`,
  `zig build test-editor PASS`, `zig build test-terminal-replay-all PASS`
- `Acceptance judgment:` VT FFI redraw-state / needs-redraw / present-ack now
  consume named `surface_contract` ffi wrappers with behavior/ABI preserved;
  scoped probe/doc hygiene is aligned.

### `CZH-B19` Long-Loop Surface/FFI Convergence Pack (`accepted`)

Queue line (exact):

- execute a longer engineering loop (10-ticket pack) that converges remaining
  mixed primitive/composite seam consumption to explicit `surface_contract`
  ownership across widget + FFI touched paths, plus scoped hygiene/doc lock

Acceptance:

- selected widget + FFI seam consumers use one explicit ownership shape
  (primitive or composite per contract) with no behavior drift
- remaining drift in seam tests/docs is resolved in touched paths
- scoped probe/doc hygiene sweep is recorded for touched modules
- queue/handoff/entrypoint and authority docs remain aligned
- full stress ladder remains green through `CZH-GATE-73`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S14_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

Execution source:

- engineer executes `CZH-681`..`CZH-690` in order from
  `docs/todo/core/CZH_S14_TICKETS.md`
- one ticket per commit unless explicitly marked otherwise
- stop only at `CZH-GATE-73` or a real hard blocker

#### `CZH-681` convergence + hygiene audit (`CZH-S14`)

**Selected target set:**

- `src/terminal/surface_contract.zig`: primitive/composite/ffi helper layering
  and doc ownership
- `src/ui/widgets/terminal_widget_surface_state.zig`: composite vs primitive
  seam test/consumer shape
- `src/terminal/ffi/core_api.zig`: ffi wrapper ownership and seam-test drift

**Plan (`CZH-682`..`CZH-686`):**

- tighten helper-layer ownership naming without behavior changes
- converge selected call sites/tests to one explicit seam shape per contract
- keep ABI and runtime semantics unchanged

**Plan (`CZH-687`..`CZH-689`):**

- lock invariants in focused seam tests
- run scoped probe/doc hygiene sweep in touched modules
- align authority docs to landed terms only

**`CZH-690`:** validation ladder + checkpoint packet + board/queue/handoff sync
to `CZH-GATE-73`.

**Engineer (CZH-681):** Confirmed convergence: **widget** paths keep **composite**
pair helpers as the explicit consumer shape; **FFI** paths keep **`ffi*`** as the
explicit export shape; **primitives** remain building blocks and bundle fill
(`fillRedrawState`) inside `surface_contract` tests only where they lock
decomposition. Hygiene scope `CZH-689`: `surface_contract.zig`,
`terminal_widget_surface_state.zig`, `core_api.zig`, `TERMINAL_SURFACE_CONTRACT.md`.

#### `CZH-689` probe/doc hygiene (`CZH-S14`)

- **Reviewed:** `surface_contract.zig`, `terminal_widget_surface_state.zig`,
  `core_api.zig` (probe residue).
- **Removed:** nothing (no stale investigation-only probes in touched paths).
- **Authority:** `TERMINAL_SURFACE_CONTRACT.md` updated to layered FFI vs widget
  composite vs primitives (`CZH-S14`).

#### Landed (`CZH-681`..`CZH-689`)

- Layering docs in `surface_contract.zig`; redundant `CZH-S11` loop test removed
- Widget + `core_api` tests converged to explicit composite / `ffi*` shapes
- Convergence invariant tests (`CZH-687`, `CZH-688`); probe sweep note above

#### `CZH-S14` engineer validation (`CZH-690`)

- **Date:** 2026-04-19  
- **Tickets:** `CZH-681`..`CZH-690` (one commit each).  
- **SL-0** `zig build` — PASS  
- **SL-1** `zig build test` — PASS  
- **SL-2** `zig build -Dmode=terminal` — PASS  
- **SL-3** `zig build -Dmode=editor` — PASS  
- **`zig build test-config`** — PASS  
- **`zig build test-editor`** — PASS  
- **`zig build test-terminal-replay-all`** — PASS  
- **Android guard** — SKIP (lane paused)

Checkpoint packet: `docs/todo/core/CZH_S14_CHECKPOINT.md`.

#### Architect gate result

- `Review chunk: CZH-B19`
- `Verdict: accepted`
- `Engineer commits reviewed:` `477c4402`, `9fe1d11b`, `dcc4cea1`, `cc302880`,
  `b946c611`, `fc7d5c9f`, `838b4306`, `0d8d75af`, `3bfde86e`, `64d6d974`
- `Architect validation spot-check:` `zig build test-config PASS`,
  `zig build test-editor PASS`, `zig build test-terminal-replay-all PASS`
- `Acceptance judgment:` layered primitive/composite/ffi ownership is now
  explicit and consistent in touched widget + FFI seam consumers; convergence
  tests are stronger and behavior-neutral.

### `CZH-B20` Long-Loop Surface Attachment Contract Shaping (`accepted`)

Queue line (exact):

- execute one longer engineering loop (10-ticket pack) to shape the next
  terminal surface layer as a host-owned shared-surface attachment contract in
  Zig authority/tests, without ABI churn or behavior drift

Acceptance:

- one explicit Zig seam names host-owned shared-surface attachment state and
  invariants used by widget presentation consumers
- touched widget/runtime seam consumers use the new seam helpers consistently
- docs/tests reflect the layered model (primitive/composite/ffi + surface
  attachment) without contradictory ownership text
- scoped probe/doc hygiene is recorded for touched modules
- full stress ladder remains green through `CZH-GATE-74`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S15_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

Execution source:

- engineer executes `CZH-691`..`CZH-700` in order from
  `docs/todo/core/CZH_S15_TICKETS.md`
- one ticket per commit unless explicitly marked otherwise
- stop only at `CZH-GATE-74` or a real hard blocker

#### `CZH-691` surface attachment seam audit + cut plan (`CZH-S15`)

- map current host-surface attachment touchpoints in:
  `terminal_widget_presentation_runtime.zig`,
  `terminal_widget_surface_state.zig`,
  `terminal_widget_draw.zig`,
  `surface_contract.zig`
- classify what belongs to shared contract helpers vs call-site local wiring
- record scoped probe/doc hygiene targets for `CZH-699`

**Engineer (CZH-691):** Cut plan: introduce `src/terminal/surface_attachment_contract.zig`
for host **pipeline-ready ∧ host-target-available** pairing; route
`notePresentableAvailability` return through primitives/composites; present-plan
`reuse_allowed` stays **pipeline-only** (`presentableReady`) — no semantic drift.
Cross-link from `surface_contract.zig` / widget docs. Hygiene `CZH-699`:
`surface_attachment_contract.zig`, `terminal_widget_surface_state.zig`,
`terminal_widget_presentation_runtime.zig`, `terminal_widget_draw.zig`,
`TERMINAL_SURFACE_CONTRACT.md`.

#### `CZH-699` probe/doc hygiene (`CZH-S15`)

- **Reviewed:** `surface_attachment_contract.zig`, `terminal_widget_surface_state.zig`,
  `terminal_widget_presentation_runtime.zig`, `terminal_widget_draw.zig`.
- **Removed:** nothing (no stale investigation-only probe callers).
- **Authority:** `TERMINAL_SURFACE_CONTRACT.md` host attachment seam (`CZH-S15`).

#### Landed (`CZH-691`..`CZH-699`)

- `surface_attachment_contract.zig` primitive/composite; `notePresentableAvailability` wiring
- Docs in `surface_contract`, presentation runtime; draw test + widget integration test
- Authority + sweep note above

#### `CZH-S15` engineer validation (`CZH-700`)

- **Date:** 2026-04-19  
- **Tickets:** `CZH-691`..`CZH-700` (one commit each).  
- **SL-0** `zig build` — PASS  
- **SL-1** `zig build test` — PASS  
- **SL-2** `zig build -Dmode=terminal` — PASS  
- **SL-3** `zig build -Dmode=editor` — PASS  
- **`zig build test-config`** — PASS  
- **`zig build test-editor`** — PASS  
- **`zig build test-terminal-replay-all`** — PASS  
- **Android guard** — SKIP (lane paused)

Checkpoint packet: `docs/todo/core/CZH_S15_CHECKPOINT.md`.

#### Architect gate result

- `Review chunk: CZH-B20`
- `Verdict: accepted`
- `Engineer commits reviewed:` `66f0c359`, `232c9da1`, `2383908c`, `a3b94513`,
  `ed7dffa2`, `68001a0f`, `52f2fccf`, `8cbef312`, `140af167`, `19c774ac`
- `Architect validation spot-check:` `zig build test-config PASS`,
  `zig build test-editor PASS`, `zig build test-terminal-replay-all PASS`
- `Acceptance judgment:` host shared-surface attachment seam is explicit,
  behavior-neutral, and cleanly layered with generation/presentable ownership.

### `CZH-B21` Long-Loop Surface Seams Convergence Pack (`accepted`)

Queue line (exact):

- execute one longer engineering loop (10-ticket pack) to converge selected
  widget/presentation call sites and tests onto explicit split ownership between
  generation seam (`surface_contract`) and host attachment seam
  (`surface_attachment_contract`), plus scoped hygiene/doc lock

Acceptance:

- selected call sites/tests use the correct seam by ownership:
  generation pairing in `surface_contract`; host attachment pairing in
  `surface_attachment_contract`
- terminology drift (`presentable_ready` vs attachment-ready naming) is reduced
  in touched paths without behavior changes
- authority docs and test naming align to landed seam ownership
- scoped probe/doc hygiene sweep is recorded for touched modules
- full stress ladder remains green through `CZH-GATE-75`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S16_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

Execution source:

- engineer executes `CZH-701`..`CZH-710` in order from
  `docs/todo/core/CZH_S16_TICKETS.md`
- one ticket per commit unless explicitly marked otherwise
- stop only at `CZH-GATE-75` or a real hard blocker

#### `CZH-701` seam ownership audit + cut plan (`CZH-S16`)

**Classified touchpoints (generation vs attachment):**

| Site | Owner seam | Notes |
| --- | --- | --- |
| `surface_contract.zig` | **Generation** | Primitives (`needsRedrawFromPair`, per-leg helpers), composite pair, `fillRedrawState` / `ffi*` wrappers — no attachment state. |
| `surface_attachment_contract.zig` | **Attachment** | `hostSharedSurfaceAttachmentReady` / `FromPair` — pipeline ∧ host target; no publication generations. |
| `terminal_widget_surface_state.presentationUpdateDelta` | **Mixed (explicit)** | Publication/clear vs last draw via `publicationClearPairMismatchesFromLastSurfaceRender`; `presentable_ready` field is the **terminal presentable pipeline** leg only (not full attachment). |
| `terminal_widget_surface_state.notePresentableAvailability` / `readSharedSurfaceAttachmentReady` | **Attachment** | Routes through `surface_attachment_contract`. |
| `terminal_widget_presentation_runtime.buildTerminalPresentPlan` | **Mixed** | Reuse generation alignment: `publicationClearPairMatchesLastSurfaceRender`; `presentableReady()` is **pipeline-only** for `reuse_allowed` (documented; not the full attachment conjunction). |
| `terminal_widget_presentation_runtime.planUpdate` | **Mixed (drift)** | `choosePresentationUpdatePlan` / `planViewportPresentShift` consume `presentation_delta` fields; converge selected args to explicit `surface_contract` primitives + pipeline getter (`CZH-703`..`CZH-705`). |
| `terminal_widget_presentation_runtime.refreshPresentState`, `tryFastPresentExisting` | **Attachment** | `notePresentableAvailability` drives readiness / fast reuse gate. |
| `terminal_widget_draw.drawPrepared` | **Consumer** | Invokes `presentation_runtime.updateAndPresent`; draw tests already anchor `surface_attachment_contract` vocabulary (`CZH-S15`); extend module doc (`CZH-706`). |

**`CZH-709` scoped hygiene targets:** `surface_contract.zig`, `surface_attachment_contract.zig`, `terminal_widget_surface_state.zig`, `terminal_widget_presentation_runtime.zig`, `terminal_widget_draw.zig`, `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md` — expect **no** investigation-only probe callers; keep operator/error-path logging as-is unless stale.

#### `CZH-709` probe/doc hygiene (`CZH-S16`)

- **Reviewed:** `surface_contract.zig`, `surface_attachment_contract.zig`,
  `terminal_widget_surface_state.zig`, `terminal_widget_presentation_runtime.zig`,
  `terminal_widget_draw.zig`.
- **Removed:** nothing (no investigation-only probe callers in these paths).
- **Kept:** `logUnavailable` operator `app_logger` warning in presentation runtime;
  draw-path `renderer.font` warnings on glyph prep adopt (`terminal_widget_draw.zig`).
- **Authority:** `TERMINAL_SURFACE_CONTRACT.md` — `CZH-S16` widget/delta vocabulary (`CZH-709`).

#### `CZH-S16` engineer validation (`CZH-710`)

- **Date:** 2026-04-19  
- **Tickets:** `CZH-701`..`CZH-710` (one commit each).  
- **SL-0** `zig build` — **PASS**  
- **SL-1** `zig build test` — **PASS**  
- **SL-2** `zig build -Dmode=terminal` — **PASS**  
- **SL-3** `zig build -Dmode=editor` — **PASS**  
- **`zig build test-config`** — **PASS**  
- **`zig build test-editor`** — **PASS**  
- **`zig build test-terminal-replay-all`** — **PASS**  
- **Android guard** — **SKIP** (lane paused)

Checkpoint packet: `docs/todo/core/CZH_S16_CHECKPOINT.md`.

#### Architect gate result

- `Review chunk: CZH-B21`
- `Verdict: accepted`
- `Engineer commits reviewed:` `ade57c19`, `82c151e1`, `1bc19081`, `5c973f96`,
  `a0870ccd`, `3a610823`, `212d6942`, `4e071fae`, `b3367d7f`, `a2cdf043`
- `Architect validation spot-check:` `zig build test-config PASS`,
  `zig build test-editor PASS`, `zig build test-terminal-replay-all PASS`
- `Acceptance judgment:` generation-vs-attachment ownership is explicit in
  touched widget/presentation call sites; terminology/docs/tests are aligned and
  behavior remained stable.

### `CZH-B22` Long-Loop Surface Naming/State Convergence Pack (`accepted`)

Queue line (exact):

- execute one longer engineering loop (10-ticket pack) to converge selected
  presentation-state and call-site naming around pipeline-ready vs
  attachment-ready seams, tightening helpers/tests/docs while preserving
  behavior and ABI

Acceptance:

- selected touched paths use explicit naming for pipeline leg vs full
  attachment readiness with no ambiguous mixed terminology
- no behavior/ABI changes; present-plan and redraw semantics unchanged
- integration tests cover pipeline-only vs full-attachment distinctions in
  selected runtime/widget paths
- scoped probe/doc hygiene is recorded for touched modules
- full stress ladder remains green through `CZH-GATE-76`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S17_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

Execution source:

- engineer executes `CZH-711`..`CZH-720` in order from
  `docs/todo/core/CZH_S17_TICKETS.md`
- one ticket per commit unless explicitly marked otherwise
- stop only at `CZH-GATE-76` or a real hard blocker

#### `CZH-711` naming/state drift audit + cut plan (`CZH-S17`)

**Classified touchpoints (pipeline leg vs full attachment vs generation state):**

| Location | Kind | Drift / note |
| --- | --- | --- |
| `PresentationState.terminal_presentable_ready` | **Pipeline leg** | Correct field name; module lacked `//!` seam vocabulary (`CZH-712`). |
| `PresentationState.target_available` | **Host drawable target** | Pairs with pipeline in `hostSharedSurfaceAttachmentReady`; name ok. |
| `PresentationState.last_render_generation` / `last_render_clear_generation` | **Generation (surface cache)** | Match `surface_contract` publication/clear vs last draw; naming ok. |
| `PresentationUpdateDelta.terminal_presentable_pipeline_ready` | **Pipeline leg** | Renamed from `presentable_ready` (`CZH-715`); sourced from `presentableReady()`. |
| `buildTerminalPresentPlan` locals | **Mixed** | `publication_clear_pair_matches_last_surface_render` + `terminal_presentable_pipeline_ready` (`CZH-713`/`714`). |
| `tryFastPresentExisting` `shared_surface_attachment_ready` | **Full attachment** | `notePresentableAvailability` return (`CZH-714`). |
| `planUpdate` locals | **Mixed** | `publication_gen_mismatch` / `clear_gen_mismatch` / `terminal_presentable_pipeline_ready` (`CZH-B21`). |
| `logUnavailable` / handoff log keys | **Pipeline leg** | `terminal_presentable_pipeline_ready` (`CZH-716`). |
| `surface_contract` / `surface_attachment_contract` | **Authority** | Synced to delta field + log vocabulary (`CZH-712`/`715`). |

**`CZH-719` hygiene scope:** same five widget/terminal modules as sprint targets; expect no new probe residue; sync `TERMINAL_SURFACE_CONTRACT.md` if field/log vocabulary shifts.

#### `CZH-719` probe/doc hygiene (`CZH-S17`)

- **Reviewed:** `terminal_widget_presentation_state.zig`, `terminal_widget_surface_state.zig`,
  `terminal_widget_presentation_runtime.zig`, `terminal_widget.zig`, `surface_contract.zig`,
  `surface_attachment_contract.zig`.
- **Removed:** nothing (no investigation-only probe callers in touched paths).
- **Kept:** operator `logUnavailable` / generation handoff `terminal.generation_handoff` strings;
  `terminal.ui.redraw` resize warnings in `presentation_state`.
- **Authority:** `TERMINAL_SURFACE_CONTRACT.md` pipeline field name aligned in `CZH-715` / `CZH-716`.

#### `CZH-S17` engineer validation (`CZH-720`)

- **Date:** 2026-04-19  
- **Tickets:** `CZH-711`..`CZH-720` (one commit each).  
- **SL-0** `zig build` — **PASS**  
- **SL-1** `zig build test` — **PASS**  
- **SL-2** `zig build -Dmode=terminal` — **PASS**  
- **SL-3** `zig build -Dmode=editor` — **PASS**  
- **`zig build test-config`** — **PASS**  
- **`zig build test-editor`** — **PASS**  
- **`zig build test-terminal-replay-all`** — **PASS**  
- **Android guard** — **SKIP** (lane paused)

Checkpoint packet: `docs/todo/core/CZH_S17_CHECKPOINT.md`.

#### Architect gate result

- `Review chunk: CZH-B22`
- `Verdict: accepted`
- `Engineer commits reviewed:` `86406205`, `772fb44d`, `048d347b`, `95dea29d`,
  `f239f164`, `b14b2234`, `fb29571f`, `53c53530`, `a4f10f51`, `eb61a543`
- `Architect validation spot-check:` `zig build test-config PASS`,
  `zig build test-editor PASS`, `zig build test-terminal-replay-all PASS`
- `Acceptance judgment:` pipeline-vs-attachment naming/state ownership is now
  explicit and consistent in touched widget/presentation paths with no behavior
  or ABI drift.

### `CZH-B23` Long-Loop Surface State Vocabulary Lock Pack (`accepted`)

Queue line (exact):

- execute one longer engineering loop (10-ticket pack) to lock state-vocabulary
  consistency for pipeline leg, attachment conjunction, and generation terms
  across selected widget/runtime/state modules, tests, and authority docs

Acceptance:

- selected touched modules expose one consistent vocabulary for:
  pipeline-ready, full-attachment-ready, and generation mismatch/match
- no behavior changes and no host ABI/C export changes
- integration tests cover representative pipeline-vs-attachment-vs-generation
  call-site invariants in selected runtime/widget paths
- scoped probe/doc hygiene is recorded for touched modules
- full stress ladder remains green through `CZH-GATE-77`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S18_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

Execution source:

- engineer executes `CZH-721`..`CZH-730` in order from
  `docs/todo/core/CZH_S18_TICKETS.md`
- one ticket per commit unless explicitly marked otherwise
- stop only at `CZH-GATE-77` or a real hard blocker

#### `CZH-721` vocabulary/state drift audit + cut plan (`CZH-S18`)

**Three-way vocabulary (target lock for `CZH-S18`):**

| Category | Authority / meaning | Drift / convergence |
| --- | --- | --- |
| **Generation (publication vs last surface draw)** | `surface_contract` primitives + composite pair | `planUpdate` locals `publication_gen_mismatch` / `clear_gen_mismatch` shorten helper names (`CZH-723`). `presentationUpdateDelta` local `gen_clear_mismatch` → align to `publicationClearPairMismatches*` vocabulary (`CZH-723`). |
| **Pipeline leg** | `PresentationState.terminal_presentable_ready` / `terminalPresentablePipelineReady()` | Landed (`CZH-725`). |
| **Host drawable target leg** | `PresentationState.target_available` / `hostSurfaceTargetAvailable()` | Landed (`CZH-724`). |
| **Full attachment conjunction** | `surface_attachment_contract.hostSharedSurfaceAttachmentReady` | `logUnavailable` uses `host_surface_target_available` key (`CZH-726`). |
| **surface_contract / surface_attachment_contract** | Module `//!` centers | Three-category lock (`CZH-722`); stale forward-ref cleaned (`CZH-729`). |
| **terminal_widget_draw** | Consumer | Pipeline + attachment getters named in module `//!` (`CZH-725`). |

**`CZH-729` hygiene scope:** `terminal_widget_presentation_state.zig`, `terminal_widget_surface_state.zig`, `terminal_widget_presentation_runtime.zig`, `terminal_widget_draw.zig`, `terminal_widget.zig` (telemetry touched in `CZH-726`), `surface_contract.zig`, `surface_attachment_contract.zig`, `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md` — probe sweep; no new investigation-only callers expected.

#### `CZH-729` probe/doc hygiene (`CZH-S18`)

- **Reviewed:** sprint target modules + `TERMINAL_SURFACE_CONTRACT.md`.
- **Removed:** nothing (no investigation-only probe callers).
- **Kept:** operator `renderer.terminal_present` / `terminal.generation_handoff` telemetry;
  `terminal.ui.redraw` partial plan resize warnings.
- **Authority:** `surface_attachment_contract` module doc de-staled for post-`CZH-725` getter name (`CZH-729`).

#### `CZH-S18` engineer validation (`CZH-730`)

- **Date:** 2026-04-19  
- **Tickets:** `CZH-721`..`CZH-730` (one commit each).  
- **SL-0** `zig build` — **PASS**  
- **SL-1** `zig build test` — **PASS**  
- **SL-2** `zig build -Dmode=terminal` — **PASS**  
- **SL-3** `zig build -Dmode=editor` — **PASS**  
- **`zig build test-config`** — **PASS**  
- **`zig build test-editor`** — **PASS**  
- **`zig build test-terminal-replay-all`** — **PASS**  
- **Android guard** — **SKIP** (lane paused)

Checkpoint packet: `docs/todo/core/CZH_S18_CHECKPOINT.md`.

#### Architect gate result

- `Review chunk: CZH-B23`
- `Verdict: accepted`
- `Engineer commits reviewed:` `49ecd8b9`, `c0684e07`, `35431e56`, `c6684f1c`,
  `268fb7ac`, `39fff8e9`, `20339def`, `9004cc7f`, `6a10c6f0`, `c3d6e371`
- `Architect validation spot-check:` `zig build test-config PASS`,
  `zig build test-editor PASS`, `zig build test-terminal-replay-all PASS`
- `Acceptance judgment:` vocabulary lock for pipeline leg, host target leg,
  full attachment, and generation terms is coherent across touched paths with
  no behavior or ABI drift.

### `CZH-B24` Long-Loop Surface Observability Vocabulary Lock (`accepted`)

Queue line (exact):

- execute one longer engineering loop (10-ticket pack) to align selected
  observability/log/telemetry vocabulary with the locked pipeline-vs-attachment-vs-generation
  state model, plus targeted test/doc lock, without behavior or ABI changes

Acceptance:

- selected touched observability/log surfaces use the same explicit vocabulary
  as core state helpers (pipeline leg, host target leg, full attachment, generation)
- no behavior changes and no host ABI/C export changes
- selected tests/docs enforce the observability vocabulary lock
- scoped probe/doc hygiene is recorded for touched modules
- full stress ladder remains green through `CZH-GATE-78`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S19_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

Execution source:

- engineer executes `CZH-731`..`CZH-740` in order from
  `docs/todo/core/CZH_S19_TICKETS.md`
- one ticket per commit unless explicitly marked otherwise
- stop only at `CZH-GATE-78` or a real hard blocker

#### `CZH-731` observability vocabulary audit + cut plan (`CZH-S19`)

- map selected observability/log touchpoints in:
  `terminal_widget_presentation_runtime.zig`,
  `terminal_widget.zig`,
  `terminal_widget_draw.zig`,
  `terminal_widget_surface_state.zig`,
  `surface_contract.zig`,
  `surface_attachment_contract.zig`
- classify each touched signal as pipeline-leg, host-target-leg,
  full-attachment, or generation-owned
- record scoped hygiene targets for `CZH-739`

**Classified observability touchpoints (pipeline vs host-target vs full attachment vs generation):**

| Site | Signals | Owner seam / note |
| --- | --- | --- |
| `terminal_widget_presentation_runtime.logUnavailable` (`renderer.terminal_present`) | `publication_generation`; `sync_updates`; `updated`; `renderer_presentable_refresh_tag`; `terminal_presentable_pipeline_ready`; `host_surface_target_available`; `shared_surface_attachment_ready`; `visible_w` / `visible_h` | **Generation:** `publication_generation` is `terminal_view.generation`. **Pipeline leg:** `terminal_presentable_pipeline_ready`. **Host target leg:** `host_surface_target_available`. **Full attachment:** `shared_surface_attachment_ready` (`readSharedSurfaceAttachmentReady`). **Renderer refresh cycle:** `renderer_presentable_refresh_tag` (`TerminalPresentableRefresh` enum — not the pipeline-ready bool). **Geometry:** visible size. |
| `terminal.generation_handoff` (`terminal_widget.draw`) | `last_surface_render_generation`, `capture_presented_generation`, `publication_pending_generation`, `publication_published_generation`, `publication_presented_generation`, `terminal_presentable_pipeline_ready`, `cache_dirty` | **Generation:** last surface draw vs capture vs publication triple uses explicit `publication_*` / `capture_*` tokens. **Pipeline leg:** `terminal_presentable_pipeline_ready`. |
| `terminal.generation_handoff` (`terminal_frame_pacing_runtime`) | `presented_generation`, `published_generation`, `pending_generation` | **Generation** snapshot for frame pacing with explicit field names. |
| `terminal_glyph_prep_adopt_target_missing` (`terminal_widget_draw`) | `publication_generation=` in format string | **Generation** (glyph prep / raster generation) aligned with `publication_generation` vocabulary (`CZH-736`). |
| `surface_contract.zig` / `surface_attachment_contract.zig` | no operator JSON logs | **Authority only:** generation pairing vs attachment conjunction naming for downstream docs/logs. |

**`CZH-739` scoped hygiene targets:** `terminal_widget_presentation_runtime.zig`, `terminal_widget.zig`, `terminal_widget_draw.zig`, `terminal_widget_surface_state.zig`, `surface_contract.zig`, `surface_attachment_contract.zig`, and `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md` if structured log keys shift; expect no investigation-only probe callers; keep operator-facing warnings (`logUnavailable`, glyph prep, resize) unless proven stale.

#### `CZH-739` scoped probe/doc hygiene + authority sync (`CZH-S19`)

- **Reviewed:** `terminal_widget_presentation_runtime.zig`, `terminal_widget.zig`,
  `terminal_widget_draw.zig`, `terminal_widget_surface_state.zig`, `surface_contract.zig`,
  `surface_attachment_contract.zig`.
- **Removed:** nothing (no investigation-only probe callers in these paths).
- **Kept:** operator `logUnavailable` / `terminal.generation_handoff` / glyph-prep warnings;
  `terminal.ui.redraw` and other existing operator logs outside this sprint scope unchanged.
- **Authority:** `TERMINAL_SURFACE_CONTRACT.md` — operator observability vocabulary subsection (`CZH-739`);
  audit table above refreshed to landed keys (`CZH-731`).

#### `CZH-S19` engineer validation (`CZH-740`)

- **Date:** 2026-04-19  
- **Tickets:** `CZH-731`..`CZH-740` (one commit each).  
- **SL-0** `zig build` — **PASS**  
- **SL-1** `zig build test` — **PASS**  
- **SL-2** `zig build -Dmode=terminal` — **PASS**  
- **SL-3** `zig build -Dmode=editor` — **PASS**  
- **`zig build test-config`** — **PASS**  
- **`zig build test-editor`** — **PASS**  
- **`zig build test-terminal-replay-all`** — **PASS**  
- **Android guard** — **SKIP** (lane paused)

Checkpoint packet: `docs/todo/core/CZH_S19_CHECKPOINT.md`.

#### Architect gate result

- `Review chunk: CZH-B24`
- `Verdict: accepted`
- `Engineer commits reviewed:` `9fc9948c`, `a696f882`, `8994f553`, `c919c6e2`,
  `652c05a4`, `af05178a`, `2013240e`, `7d977c95`, `6fbb1519`, `81cf9f11`
- `Architect validation spot-check:` `zig build test-config PASS`,
  `zig build test-editor PASS`, `zig build test-terminal-replay-all PASS`
- `Acceptance judgment:` observability/log vocabulary is aligned with the
  locked pipeline/attachment/generation state model in touched paths with no
  behavior or ABI drift.

### `CZH-B25` Long-Loop Surface Contract Alias Reduction (`accepted`)

Queue line (exact):

- execute one longer engineering loop (10-ticket pack) to reduce remaining
  terminology aliases in selected widget/runtime/state seams so each state
  concept has one dominant term, with test/doc lock and no behavior/ABI changes

Acceptance:

- selected touched paths reduce duplicate aliases for the same state concept
  (pipeline leg, host target leg, full attachment, generation)
- no behavior changes and no host ABI/C export changes
- selected tests/docs assert the alias-reduction vocabulary lock
- scoped probe/doc hygiene is recorded for touched modules
- full stress ladder remains green through `CZH-GATE-79`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S20_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

Execution source:

- engineer executes `CZH-741`..`CZH-750` in order from
  `docs/todo/core/CZH_S20_TICKETS.md`
- one ticket per commit unless explicitly marked otherwise
- stop only at `CZH-GATE-79` or a real hard blocker

#### `CZH-741` alias inventory audit + cut plan (`CZH-S20`)

- map selected alias pairs and preferred canonical terms in:
  `terminal_widget_presentation_runtime.zig`,
  `terminal_widget_surface_state.zig`,
  `terminal_widget_draw.zig`,
  `terminal_widget.zig`,
  `surface_contract.zig`,
  `surface_attachment_contract.zig`
- classify alias retention/removal targets by seam ownership
- record scoped hygiene targets for `CZH-749`

**Classified alias pairs (canonical term → remove/retain):**

| Concept | Dominant canonical term | Aliases to fold | Primary sites |
| --- | --- | --- | --- |
| Publication generation (view / draw path) | `publication_generation` (locals/params mirroring `terminal_view.generation`) | `terminal_generation` parameter/visitor field in glyph draw pass | `terminal_widget_presentation_runtime.zig` |
| Surface cache generations | `last_render_generation`, `last_render_clear_generation` | none material | `terminal_widget_presentation_state.zig` |
| Pipeline leg (stored bool) | `terminal_presentable_pipeline_ready` | `terminal_presentable_ready` on `PresentationState` (short form vs delta field) | `terminal_widget_presentation_state.zig`, `terminal_widget_surface_state.zig`, `terminal_widget_draw_presentation.zig` |
| Host drawable target leg (stored bool) | `host_surface_target_available` | `target_available` on `PresentationState` and present-path snapshots (`PresentationPresentState`, outcome states, `TerminalPresentResult`) | `terminal_widget_presentation_state.zig`, `terminal_widget_presentation_runtime.zig`, `presentable_contract.zig` |
| Full attachment predicate | `readSharedSurfaceAttachmentReady` / `hostSharedSurfaceAttachmentReady` | none material (helpers already named) | `surface_attachment_contract.zig`, `terminal_widget_surface_state.zig` |
| Surface contract primitives | `publicationGenerationDiffersFromLastSurfaceRender`, `publicationClearPair*` | informal “gen mismatch” phrasing in comments only | `surface_contract.zig` |

**`CZH-749` scoped hygiene targets:** `terminal_widget_presentation_runtime.zig`, `terminal_widget_surface_state.zig`, `terminal_widget_draw.zig`, `terminal_widget.zig`, `surface_contract.zig`, `surface_attachment_contract.zig`, `terminal_widget_presentation_state.zig`, `terminal_widget_draw_presentation.zig`, `presentable_contract.zig`, and `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md` if field renames land; expect no investigation-only probe callers; keep operator logs and debug samples unless proven stale.

#### `CZH-749` scoped probe/doc hygiene + authority sync (`CZH-S20`)

- **Reviewed:** `terminal_widget_presentation_runtime.zig`, `terminal_widget_surface_state.zig`,
  `terminal_widget_draw.zig`, `terminal_widget_draw_grid.zig`, `terminal_widget.zig`,
  `surface_contract.zig`, `surface_attachment_contract.zig`,
  `terminal_widget_presentation_state.zig`, `terminal_widget_draw_presentation.zig`,
  `presentable_contract.zig`, `TERMINAL_SURFACE_CONTRACT.md`.
- **Removed:** nothing (no investigation-only probe callers in these paths).
- **Kept:** operator `logUnavailable` / `terminal.generation_handoff` / glyph-prep warnings;
  debug presentation/metal fallback samples; `terminal.ui.redraw` resize warnings.
- **Authority:** `TERMINAL_SURFACE_CONTRACT.md` — widget storage + observability subsections (`CZH-749`);
  alias audit table (`CZH-741`) describes pre-fold pairs; dominant names landed in `CZH-743`..`CZH-746`.

#### `CZH-S20` engineer validation (`CZH-750`)

- **Date:** 2026-04-19  
- **Tickets:** `CZH-741`..`CZH-750` (one commit each).  
- **SL-0** `zig build` — **PASS**  
- **SL-1** `zig build test` — **PASS**  
- **SL-2** `zig build -Dmode=terminal` — **PASS**  
- **SL-3** `zig build -Dmode=editor` — **PASS**  
- **`zig build test-config`** — **PASS**  
- **`zig build test-editor`** — **PASS**  
- **`zig build test-terminal-replay-all`** — **PASS**  
- **Android guard** — **SKIP** (lane paused)

Checkpoint packet: `docs/todo/core/CZH_S20_CHECKPOINT.md`.

#### Architect gate result

- `Review chunk: CZH-B25`
- `Verdict: accepted`
- `Engineer commits reviewed:` `589897c0`, `998a11a1`, `11f196b9`, `1fa7276e`,
  `62455ff3`, `9e856b85`, `f51f19b5`, `20d03bf5`, `8de6fa12`, `bd171ce3`
- `Architect corrective commit:` `63a2f2be` (reuse-return path now
  preserves host-target leg semantics instead of writing full attachment into
  `host_surface_target_available`).
- `Architect validation spot-check:` `zig build test-config PASS`,
  `zig build test-editor PASS`, `zig build test-terminal-replay-all PASS`
- `Acceptance judgment:` dominant alias terms are landed and locked with no ABI
  drift; one semantic naming mismatch in reuse-return bookkeeping was corrected
  in-place and does not change draw/present control flow.

### `CZH-B26` Long-Loop Present Result Ownership Lock (`accepted`)

Queue line (exact):

- execute one longer engineering loop (10-ticket pack) to lock ownership
  boundaries between host-target leg and full-attachment readiness in selected
  present/runtime/state result paths, with test/doc lock and no ABI changes

Acceptance:

- selected touched present/runtime/state paths keep host-target leg and
  full-attachment readiness distinct and explicitly named
- no host ABI/C export changes
- selected tests/docs assert ownership boundaries (host-target leg vs full attachment)
- scoped probe/doc hygiene is recorded for touched modules
- full stress ladder remains green through `CZH-GATE-80`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S21_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

Execution source:

- engineer executes `CZH-751`..`CZH-760` in order from
  `docs/todo/core/CZH_S21_TICKETS.md`
- one ticket per commit unless explicitly marked otherwise
- stop only at `CZH-GATE-80` or a real hard blocker

#### `CZH-751` present result ownership audit + cut plan (`CZH-S21`)

- map host-target leg vs full-attachment values across:
  `terminal_widget_presentation_runtime.zig`,
  `terminal_widget_surface_state.zig`,
  `terminal_widget_presentation_state.zig`,
  `presentable_contract.zig`,
  `surface_attachment_contract.zig`
- classify which structs should carry host-target only vs full-attachment only
- record scoped hygiene targets for `CZH-759`

**Classified ownership (host-target leg vs full attachment):**

| Site | Host-target leg (drawable target from host/renderer) | Full attachment (pipeline ∧ host target) | Drift / cut |
| --- | --- | --- | --- |
| `surface_attachment_contract` | `SharedSurfaceAttachmentPipelinePair.host_surface_target_available` | `hostSharedSurfaceAttachmentReady` / `FromPair` | Authority only; no present-result struct. |
| `TerminalWidgetSurfaceState` | `presentation.host_surface_target_available`, `hostSurfaceTargetAvailable()` | `readSharedSurfaceAttachmentReady()`, `notePresentableAvailability` | Stored legs + conjunction helpers; distinct names (`CZH-B25`). |
| `PresentationPresentState` | `host_surface_target_available` (from `terminalPresentableInfo`) | `shared_surface_attachment_ready` / `present` via `notePresentableAvailability` (conjunction) | Two fields: target leg vs gated readiness (`CZH-S15`); field name locked in `CZH-764`. |
| `tryFastPresentExisting` / `ReusePresentOutcomeState` | Renderer `terminalPresentableInfo` → host-target leg local | `notePresentableAvailability` → `shared_surface_attachment_ready` | Both carried on `ReusePresentOutcomeState` (`CZH-753`). |
| `TerminalPresentResult` | `host_surface_target_available` | `shared_surface_attachment_ready` | Landed (`CZH-754`); non-reuse present paths default full-attachment field to `false`. |
| `RefreshOutcomeState` | `host_surface_target_available` (refresh saw drawable target) | Not represented in outcome | Leave unset in present result (`false`) unless a future path computes widget conjunction (`CZH-754`). |

**`CZH-759` scoped hygiene targets:** `terminal_widget_presentation_runtime.zig`, `terminal_widget_surface_state.zig`, `terminal_widget_presentation_state.zig`, `presentable_contract.zig`, `surface_attachment_contract.zig`, `terminal_widget_draw.zig`, `TERMINAL_SURFACE_CONTRACT.md`; no investigation-only probe callers expected.

#### `CZH-759` scoped probe/doc hygiene + authority sync (`CZH-S21`)

- **Reviewed:** `terminal_widget_presentation_runtime.zig`, `terminal_widget_surface_state.zig`,
  `terminal_widget_presentation_state.zig`, `presentable_contract.zig`,
  `surface_attachment_contract.zig`, `terminal_widget.zig`, `terminal_widget_draw.zig`,
  `TERMINAL_SURFACE_CONTRACT.md`.
- **Removed:** nothing (no investigation-only probe callers in these paths).
- **Kept:** operator `logUnavailable` / `terminal.generation_handoff`; debug presentation samples;
  `terminal.ui.redraw` resize warnings.
- **Authority:** `TERMINAL_SURFACE_CONTRACT.md` — present-result ownership note (`CZH-759`);
  audit table (`CZH-751`) updated by landed `TerminalPresentResult` / reuse outcome fields (`CZH-753`..`CZH-754`).

#### `CZH-S21` engineer validation (`CZH-760`)

- **Date:** 2026-04-19  
- **Tickets:** `CZH-751`..`CZH-760` (one commit each).  
- **SL-0** `zig build` — **PASS**  
- **SL-1** `zig build test` — **PASS**  
- **SL-2** `zig build -Dmode=terminal` — **PASS**  
- **SL-3** `zig build -Dmode=editor` — **PASS**  
- **`zig build test-config`** — **PASS**  
- **`zig build test-editor`** — **PASS**  
- **`zig build test-terminal-replay-all`** — **PASS**  
- **Android guard** — **SKIP** (lane paused)

Checkpoint packet: `docs/todo/core/CZH_S21_CHECKPOINT.md`.

#### Architect gate result

- `Review chunk: CZH-B26`
- `Verdict: accepted`
- `Engineer commits reviewed:` `d4c13024`, `321d0406`, `707bd546`, `ea40fbe8`,
  `fea2b910`, `357722da`, `8a3440be`, `bad751b8`, `136ceb82`, `da3aaff2`
- `Architect validation spot-check:` `zig build test-config PASS`,
  `zig build test-editor PASS`, `zig build test-terminal-replay-all PASS`
- `Acceptance judgment:` host-target leg vs full-attachment ownership is now
  explicit in selected present/runtime/state carriers with no ABI drift.

### `CZH-B27` Long-Loop Present Readiness Conjunction Propagation (`accepted`)

Queue line (exact):

- execute one longer engineering loop (10-ticket pack) to lock where the
  full-attachment conjunction is computed vs stored vs reported in selected
  present/runtime/state paths, with test/doc lock and no ABI changes

Acceptance:

- selected touched paths have one explicit source of truth for full-attachment
  conjunction per phase (compute/store/report), with no leg/conjunction mixing
- no host ABI/C export changes
- selected tests/docs assert conjunction propagation boundaries
- scoped probe/doc hygiene is recorded for touched modules
- full stress ladder remains green through `CZH-GATE-81`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S22_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

Execution source:

- engineer executes `CZH-761`..`CZH-770` in order from
  `docs/todo/core/CZH_S22_TICKETS.md`
- one ticket per commit unless explicitly marked otherwise
- stop only at `CZH-GATE-81` or a real hard blocker

#### `CZH-761` conjunction propagation audit + cut plan (`CZH-S22`)

- map where full-attachment is computed, stored, and reported across:
  `terminal_widget_presentation_runtime.zig`,
  `terminal_widget_surface_state.zig`,
  `terminal_widget_presentation_state.zig`,
  `presentable_contract.zig`,
  `surface_attachment_contract.zig`
- classify per phase owner: compute vs storage vs report carrier
- record scoped hygiene targets for `CZH-769`

**Phase ownership (compute / store / report) — full-attachment conjunction (`CZH-S22`):**

| Phase | Primary owner | Mechanism / carrier |
| --- | --- | --- |
| Compute (pure) | `surface_attachment_contract` | `hostSharedSurfaceAttachmentReady` / `FromPair` define conjunction from the two legs; no runtime state. |
| Compute (widget) | `TerminalWidgetSurfaceState.notePresentableAvailability` | Writes the host-target leg on `PresentationState`, returns conjunction from stored pipeline ∧ host-target legs. |
| Compute (reuse fast path) | `tryFastPresentExisting` | Conjunction local `shared_surface_attachment_ready` from `notePresentableAvailability` before packaging `ReusePresentOutcomeState`. |
| Compute (refreshed present path) | `refreshPresentState` | Conjunction from `notePresentableAvailability` gates `present` / `log_unavailable` (canonical local naming in `CZH-763`..`CZH-764`). |
| Store (attachment legs) | `PresentationState` | `terminal_presentable_pipeline_ready`, `host_surface_target_available` — legs only; no standalone conjunction field. |
| Store (reuse / present results) | `ReusePresentOutcomeState`, `TerminalPresentResult` | `shared_surface_attachment_ready` is the conjunction snapshot on these carriers. |
| Store (transient present gate) | `PresentationPresentState` | Host-target leg plus `shared_surface_attachment_ready` (conjunction for this tick’s gating). |
| Report (read helper) | `readSharedSurfaceAttachmentReady` | Re-reads conjunction from stored legs (same predicate as compute return after `notePresentableAvailability`). |
| Report (operator JSON) | `logUnavailable` | Keys `host_surface_target_available`, `shared_surface_attachment_ready` (`CZH-765` ties report to stored snapshot where applicable). |
| Report (downstream) | `TerminalPresentResult` consumers | Field vocabulary matches `presentable_contract` aggregation; refresh/direct paths default conjunction field when not computed. |

**`CZH-769` scoped hygiene targets:** `terminal_widget_presentation_runtime.zig`, `terminal_widget_surface_state.zig`, `terminal_widget_presentation_state.zig`, `presentable_contract.zig`, `surface_attachment_contract.zig`, `terminal_widget_draw.zig`, `TERMINAL_SURFACE_CONTRACT.md`; confirm no investigation-only probe residue on product paths.

#### `CZH-769` scoped probe/doc hygiene + authority sync (`CZH-S22`)

- **Reviewed:** `terminal_widget_presentation_runtime.zig`, `terminal_widget_surface_state.zig`,
  `terminal_widget_presentation_state.zig`, `presentable_contract.zig`, `surface_attachment_contract.zig`,
  `terminal_widget_draw.zig`, `TERMINAL_SURFACE_CONTRACT.md`.
- **Removed:** nothing (no investigation-only probe callers on product paths; `std.debug.assert` remains
  in tests only).
- **Kept:** operator `logUnavailable` / `terminal.generation_handoff`; existing comptime ownership tests.
- **Authority:** `TERMINAL_SURFACE_CONTRACT.md` — transient `PresentationPresentState` conjunction note (`CZH-769`).

#### `CZH-S22` engineer validation (`CZH-770`)

- **Date:** 2026-04-19  
- **Tickets:** `CZH-761`..`CZH-770` (one commit each).  
- **SL-0** `zig build` — **PASS**  
- **SL-1** `zig build test` — **PASS**  
- **SL-2** `zig build -Dmode=terminal` — **PASS**  
- **SL-3** `zig build -Dmode=editor` — **PASS**  
- **`zig build test-config`** — **PASS**  
- **`zig build test-editor`** — **PASS**  
- **`zig build test-terminal-replay-all`** — **PASS**  
- **Android guard** — **SKIP** (lane paused)

Checkpoint packet: `docs/todo/core/CZH_S22_CHECKPOINT.md`.

#### Architect gate result

- `Review chunk: CZH-B27`
- `Verdict: accepted`
- `Engineer commits reviewed:` `efed9fc0`, `4b04c2fe`, `47a2d078`, `a2d97344`,
  `7d44de3c`, `58280597`, `cad9c799`, `34d78b73`, `cd88e422`, `074defdf`
- `Architect validation spot-check:` `zig build test-config PASS`,
  `zig build test-editor PASS`, `zig build test-terminal-replay-all PASS`
- `Acceptance judgment:` conjunction compute/store/report propagation is explicit
  in touched paths with no behavior or ABI drift.

### `CZH-B28` Long-Loop Present Reporting Carrier Consolidation (`accepted`)

Queue line (exact):

- execute one longer engineering loop (10-ticket pack) to consolidate which
  carrier is authoritative for present-time conjunction reporting in selected
  runtime/widget paths, with test/doc lock and no ABI changes

Acceptance:

- selected touched paths use one dominant present-time reporting carrier for
  conjunction visibility, with no leg/conjunction ambiguity
- no host ABI/C export changes
- selected tests/docs assert reporting-carrier boundaries
- scoped probe/doc hygiene is recorded for touched modules
- full stress ladder remains green through `CZH-GATE-82`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S23_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

Execution source:

- engineer executes `CZH-771`..`CZH-780` in order from
  `docs/todo/core/CZH_S23_TICKETS.md`
- one ticket per commit unless explicitly marked otherwise
- stop only at `CZH-GATE-82` or a real hard blocker

#### `CZH-771` reporting-carrier audit + cut plan (`CZH-S23`)

- map present-time conjunction reporting carriers across:
  `terminal_widget_presentation_runtime.zig`,
  `terminal_widget_surface_state.zig`,
  `terminal_widget_presentation_state.zig`,
  `presentable_contract.zig`,
  `TERMINAL_SURFACE_CONTRACT.md`
- classify primary reporting carrier vs secondary debug/diagnostic carriers
- record scoped hygiene targets for `CZH-779`

**Reporting-carrier map (present-time conjunction visibility) — `CZH-S23`:**

| Flow | Dominant conjunction reporting carrier | Companion / non-carrier (same vocabulary, different role) |
| --- | --- | --- |
| Refreshed-present operator JSON (`logUnavailable`) | `PresentationPresentState.shared_surface_attachment_ready` (per-tick snapshot after `refreshPresentState` compute) | Predicate equivalence with `readSharedSurfaceAttachmentReady()` when legs match; **not** a second log source — log reads the present-state field only. |
| Widget surface outside transient present tick | `TerminalWidgetSurfaceState.readSharedSurfaceAttachmentReady()` | Reads stored legs on `PresentationState`; no `PresentationPresentState` in scope. |
| Present outcome / host aggregation | `TerminalPresentResult.shared_surface_attachment_ready` | `host_surface_target_available` is **leg-only** on the same struct — never substitute it for conjunction reporting. |
| Pure definition / tests | `surface_attachment_contract.hostSharedSurfaceAttachmentReady` / `FromPair` | Authority predicate; not a log or widget-runtime carrier. |

**Secondary (leg reporters, not conjunction carriers):** `terminal_presentable_pipeline_ready` in operator JSON; `host_surface_target_available` on `PresentationPresentState` / present results — each names one leg for observability, not the ∧ alone.

**`CZH-779` scoped hygiene targets:** `terminal_widget_presentation_runtime.zig`, `terminal_widget_surface_state.zig`, `terminal_widget_presentation_state.zig`, `presentable_contract.zig`, `terminal_widget_draw.zig`, `TERMINAL_SURFACE_CONTRACT.md`; confirm no investigation-only probe residue on product paths.

#### `CZH-779` scoped probe/doc hygiene + authority sync (`CZH-S23`)

- **Reviewed:** `terminal_widget_presentation_runtime.zig`, `terminal_widget_surface_state.zig`,
  `terminal_widget_presentation_state.zig`, `presentable_contract.zig`, `terminal_widget_draw.zig`,
  `terminal_widget.zig`, `TERMINAL_SURFACE_CONTRACT.md`.
- **Removed:** nothing (no investigation-only probe callers on product paths; `std.debug.assert` remains
  in tests only).
- **Kept:** operator `logUnavailable` / `terminal.generation_handoff`; comptime reporting-carrier tests
  (`CZH-777`, `CZH-778`).
- **Authority:** `TERMINAL_SURFACE_CONTRACT.md` — operator log conjunction carrier note (`CZH-772` / `CZH-S23`).

#### `CZH-S23` engineer validation (`CZH-780`)

- **Date:** 2026-04-19  
- **Tickets:** `CZH-771`..`CZH-780` (one commit each).  
- **SL-0** `zig build` — **PASS**  
- **SL-1** `zig build test` — **PASS**  
- **SL-2** `zig build -Dmode=terminal` — **PASS**  
- **SL-3** `zig build -Dmode=editor` — **PASS**  
- **`zig build test-config`** — **PASS**  
- **`zig build test-editor`** — **PASS**  
- **`zig build test-terminal-replay-all`** — **PASS**  
- **Android guard** — **SKIP** (lane paused)

Checkpoint packet: `docs/todo/core/CZH_S23_CHECKPOINT.md`.

#### Architect gate result

- `Review chunk: CZH-B28`
- `Verdict: accepted`
- `Engineer commits reviewed:` `ca75eb62`, `1cba26c4`, `1af411e3`, `f9cdc60d`,
  `0765b648`, `97d6feed`, `5e2e968f`, `2059991b`, `b0398630`, `d6bb7198`
- `Architect validation spot-check:` `zig build test-config PASS`,
  `zig build test-editor PASS`, `zig build test-terminal-replay-all PASS`
- `Acceptance judgment:` dominant reporting carrier boundaries are explicit in
  touched runtime/widget paths with no behavior or ABI drift.

### `CZH-B29` Long-Loop Reporting/Result Cohesion Lock (`accepted`)

Queue line (exact):

- execute one longer engineering loop (10-ticket pack) to lock cohesion between
  present-time reporting carriers and present-result aggregation fields in selected
  runtime/widget/result seams, with test/doc lock and no ABI changes

Acceptance:

- selected touched paths keep reporting-carrier and present-result field roles
  coherent and non-overlapping (leg vs conjunction)
- no host ABI/C export changes
- selected tests/docs assert reporting/result cohesion boundaries
- scoped probe/doc hygiene is recorded for touched modules
- full stress ladder remains green through `CZH-GATE-83`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S24_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

Execution source:

- engineer executes `CZH-781`..`CZH-790` in order from
  `docs/todo/core/CZH_S24_TICKETS.md`
- one ticket per commit unless explicitly marked otherwise
- stop only at `CZH-GATE-83` or a real hard blocker

#### `CZH-781` reporting/result cohesion audit + cut plan (`CZH-S24`)

- map reporting carriers vs present-result fields across:
  `terminal_widget_presentation_runtime.zig`,
  `terminal_widget_surface_state.zig`,
  `presentable_contract.zig`,
  `terminal_widget_presentation_state.zig`,
  `TERMINAL_SURFACE_CONTRACT.md`
- classify primary ownership and no-overlap rules (leg vs conjunction) per flow
- record scoped hygiene targets for `CZH-789`

**Reporting vs present-result cohesion map (`CZH-S24`):**

| Surface | Dominant reporting role | Present-result / aggregation role | No-overlap rule |
| --- | --- | --- | --- |
| `PresentationPresentState` | Per-tick **report** snapshot for operator JSON (`shared_surface_attachment_ready`); host-target **leg** for same tick | Not a `TerminalPresentResult`; feeds gating + `logUnavailable` only | Do not treat as `TerminalPresentResult`; conjunction field is **report**-shaped, not host-export aggregation. |
| `ReusePresentOutcomeState` | N/A (intermediate reuse bookkeeping) | **Feeds** `presentResultFromReuseOutcomeState` → `TerminalPresentResult` with matching field names | Leg and conjunction fields must stay **pair-aligned** with `TerminalPresentResult`; no overload of one bool. |
| `TerminalPresentResult` | Consumed by hosts as **aggregated** present outcome | **Stores** `host_surface_target_available` (leg) + `shared_surface_attachment_ready` (conjunction when computed) | **Never** use `host_surface_target_available` as the conjunction carrier; reporting **into** logs uses `PresentationPresentState` or getters, not this struct in isolation for operator `renderer.terminal_present`. |
| `PresentationState` (cached draw) | Leg **storage** feeding `readSharedSurfaceAttachmentReady` | Does **not** embed `TerminalPresentResult` | Conjunction is **derived** via bridge getter, not stored as a third bool here. |
| `readSharedSurfaceAttachmentReady` | Widget-surface **read/report** bridge from stored legs | Not a struct field; informs diagnostics outside transient present tick | Same predicate family as conjunction on results when legs match; not a substitute for `TerminalPresentResult` fields in aggregation paths. |

**`CZH-789` scoped hygiene targets:** `terminal_widget_presentation_runtime.zig`, `terminal_widget_surface_state.zig`, `terminal_widget_presentation_state.zig`, `presentable_contract.zig`, `terminal_widget_draw.zig`, `terminal_widget.zig`, `TERMINAL_SURFACE_CONTRACT.md`.

#### `CZH-789` scoped probe/doc hygiene + authority sync (`CZH-S24`)

- **Reviewed:** `terminal_widget_presentation_runtime.zig`, `terminal_widget_surface_state.zig`,
  `terminal_widget_presentation_state.zig`, `presentable_contract.zig`, `terminal_widget_draw.zig`,
  `terminal_widget.zig`, `TERMINAL_SURFACE_CONTRACT.md`.
- **Removed:** nothing (no investigation-only probe callers on product paths; `std.debug.assert` remains
  in tests only).
- **Kept:** operator `logUnavailable` / `terminal.generation_handoff`; cohesion comptime tests (`CZH-787`,
  `CZH-788`).
- **Authority:** `TERMINAL_SURFACE_CONTRACT.md` — reporting vs present-result cohesion note (`CZH-782` / `CZH-S24`).

#### `CZH-S24` engineer validation (`CZH-790`)

- **Date:** 2026-04-19  
- **Tickets:** `CZH-781`..`CZH-790` (one commit each).  
- **SL-0** `zig build` — **PASS**  
- **SL-1** `zig build test` — **PASS**  
- **SL-2** `zig build -Dmode=terminal` — **PASS**  
- **SL-3** `zig build -Dmode=editor` — **PASS**  
- **`zig build test-config`** — **PASS**  
- **`zig build test-editor`** — **PASS**  
- **`zig build test-terminal-replay-all`** — **PASS**  
- **Android guard** — **SKIP** (lane paused)

Checkpoint packet: `docs/todo/core/CZH_S24_CHECKPOINT.md`.

#### Architect gate result

- `Review chunk: CZH-B29`
- `Verdict: accepted`
- `Engineer commits reviewed:` `ffe6b603`, `21259bb5`, `9f26dc7b`, `4d613244`,
  `d6697849`, `fed066d7`, `2c4f1747`, `319a6466`, `32946134`, `13be5eac`
- `Architect validation spot-check:` `zig build test-config PASS`,
  `zig build test-editor PASS`, `zig build test-terminal-replay-all PASS`
- `Acceptance judgment:` reporting/result boundaries are explicit and
  non-overlapping in touched runtime/widget seams with no behavior or ABI drift.

### `CZH-B30` Long-Loop Reporting/Result Seam Contraction (`accepted`)

Queue line (exact):

- execute one longer engineering loop (10-ticket pack) to contract duplicate
  reporting/result derivation paths to canonical helper routes across selected
  runtime/widget seams, with test/doc lock and no ABI changes

Acceptance:

- selected touched paths converge on one canonical helper route for
  leg/conjunction derivation per flow (no parallel ambiguous paths)
- no host ABI/C export changes
- selected tests/docs assert seam-contraction equivalence boundaries
- scoped probe/doc hygiene is recorded for touched modules
- full stress ladder remains green through `CZH-GATE-84`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S25_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

Execution source:

- engineer executes `CZH-791`..`CZH-800` in order from
  `docs/todo/core/CZH_S25_TICKETS.md`
- one ticket per commit unless explicitly marked otherwise
- stop only at `CZH-GATE-84` or a real hard blocker

#### `CZH-791` seam-contraction audit + cut plan (`CZH-S25`)

- map duplicate conjunction/leg derivation callsites across:
  `terminal_widget_presentation_runtime.zig`,
  `terminal_widget_surface_state.zig`,
  `surface_attachment_contract.zig`,
  `presentable_contract.zig`,
  `TERMINAL_SURFACE_CONTRACT.md`
- classify canonical helper route per flow and mark parallel paths for
  contraction
- record scoped hygiene targets for `CZH-799`

#### `CZH-S25` engineer validation (`CZH-800`)

- **Date:** 2026-04-19
- **Tickets:** `CZH-791`..`CZH-800` (plus board state sync commit).
- **SL-0** `zig build` — **PASS**
- **SL-1** `zig build test` — **PASS**
- **SL-2** `zig build -Dmode=terminal` — **PASS**
- **SL-3** `zig build -Dmode=editor` — **PASS**
- **`zig build test-config`** — **PASS**
- **`zig build test-editor`** — **PASS**
- **`zig build test-terminal-replay-all`** — **PASS**
- **Android guard** — **SKIP** (lane paused)

Checkpoint packet: `docs/todo/core/CZH_S25_CHECKPOINT.md`.

#### Architect gate result

- `Review chunk: CZH-B30`
- `Verdict: accepted`
- `Engineer commits reviewed:` `41d982c7`, `dc3334bb`, `c0fe59e6`, `4c76ca63`,
  `4e611184`, `363f28ee`, `8bcedb47`, `e5cee575`, `b00d1fbd`, `251b7ccc`,
  `e8da8fe3`
- `Architect validation spot-check:` `zig build test-config PASS`,
  `zig build test-editor PASS`, `zig build test-terminal-replay-all PASS`
- `Process finding:` `CZH-793` landed a real behavior correction (refresh-path
  conjunction propagation) while the packet reported “behavior changes: 0”.
- `Acceptance judgment:` accepted because the correction is coherent, tested,
  and ABI-stable; future batches must declare any behavior fix explicitly.

### `CZH-B31` Long-Loop Surface/Result Contraction Follow-Through (`accepted`)

Queue line (exact):

- execute one longer engineering loop (10-ticket pack) to finish contraction of
  remaining duplicate surface/result derivation callsites to canonical helper
  routes across selected runtime/widget seams, with equivalence tests/doc lock
  and no ABI changes

Acceptance:

- selected touched paths use one canonical derivation route per flow (leg vs
  conjunction) with no duplicated parallel stories
- no host ABI/C export changes
- selected helper/integration tests lock equivalence invariants
- scoped probe/doc hygiene is recorded for touched modules
- full stress ladder remains green through `CZH-GATE-85`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S26_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

Execution source:

- engineer executes `CZH-801`..`CZH-810` in order from
  `docs/todo/core/CZH_S26_TICKETS.md`
- one ticket per commit unless explicitly marked otherwise
- stop only at `CZH-GATE-85` or a real hard blocker

#### `CZH-801` follow-through audit + hygiene scope (`CZH-S26`)

- map remaining duplicated derivation callsites across:
  `terminal_widget_presentation_runtime.zig`,
  `terminal_widget_surface_state.zig`,
  `surface_attachment_contract.zig`,
  `presentable_contract.zig`,
  `TERMINAL_SURFACE_CONTRACT.md`
- record explicit behavior-freeze guardrails and the scope for `CZH-809`

#### `CZH-S26` engineer validation (`CZH-810`)

- **Date:** 2026-04-19
- **Tickets:** `CZH-801`..`CZH-810` (plus board-state sync commit).
- **SL-0** `zig build` — **PASS**
- **SL-1** `zig build test` — **PASS**
- **SL-2** `zig build -Dmode=terminal` — **PASS**
- **SL-3** `zig build -Dmode=editor` — **PASS**
- **`zig build test-config`** — **PASS**
- **`zig build test-editor`** — **PASS**
- **`zig build test-terminal-replay-all`** — **PASS**
- **Android guard** — **SKIP** (lane paused)

Checkpoint packet: `docs/todo/core/CZH_S26_CHECKPOINT.md`.

#### Architect gate result

- `Review chunk: CZH-B31`
- `Verdict: accepted`
- `Engineer commits reviewed:` `f44ca7aa`, `f174c91d`, `4243dc20`, `5ae79ccc`,
  `4211655d`, `831c3b96`, `8a88985c`, `b6a2ac80`, `47cb3faf`, `34a74a5a`,
  `0093906c`
- `Architect validation spot-check:` `zig build test-config PASS`,
  `zig build test-editor PASS`, `zig build test-terminal-replay-all PASS`
- `Process finding:` `CZH-803`/`CZH-804`/`CZH-805` are empty “verified” commits.
  Future batches must pre-label such tickets as `verification-only` or land
  concrete code changes.
- `Acceptance judgment:` seam state is stable and ABI-safe; tests/docs are
  coherent. Accepted with stronger next-batch ticket-shape constraints.

### `CZH-B32` Runtime/Surface Seam Contraction Implementation Cut (`accepted`)

Queue line (exact):

- execute one longer engineering loop (10-ticket pack) to land concrete runtime
  and surface derivation contractions (not verification-only placeholders), with
  equivalence tests/doc lock and no ABI changes

Acceptance:

- selected touched paths have concrete contraction edits to canonical helper
  routes (no parallel duplicate derivations in scope)
- no host ABI/C export changes
- helper and integration tests lock landed contractions
- scoped probe/doc hygiene is recorded for touched modules
- full stress ladder remains green through `CZH-GATE-86`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S27_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

Execution source:

- engineer executes `CZH-811`..`CZH-820` in order from
  `docs/todo/core/CZH_S27_TICKETS.md`
- one ticket per commit unless explicitly marked otherwise
- no empty commits unless ticket is explicitly `doc-only` or
  `verification-only`
- stop only at `CZH-GATE-86` or a real hard blocker

#### `CZH-811` runtime/surface contraction audit + scope lock (`CZH-S27`)

- map concrete contraction opportunities requiring code edits across:
  `terminal_widget_presentation_runtime.zig`,
  `terminal_widget_surface_state.zig`,
  `surface_attachment_contract.zig`,
  `presentable_contract.zig`,
  `TERMINAL_SURFACE_CONTRACT.md`
- lock exact edit targets and scope for `CZH-819`

#### `CZH-S27` engineer validation (`CZH-820`)

- **Date:** 2026-04-19
- **Tickets:** `CZH-811`..`CZH-820` (plus board state sync commit).
- **SL-0** `zig build` — **PASS**
- **SL-1** `zig build test` — **PASS**
- **SL-2** `zig build -Dmode=terminal` — **PASS**
- **SL-3** `zig build -Dmode=editor` — **PASS**
- **`zig build test-config`** — **PASS**
- **`zig build test-editor`** — **PASS**
- **`zig build test-terminal-replay-all`** — **PASS**
- **Android guard** — **SKIP** (lane paused)

Checkpoint packet: `docs/todo/core/CZH_S27_CHECKPOINT.md`.

#### Architect gate result

- `Review chunk: CZH-B32`
- `Verdict: accepted`
- `Engineer commits reviewed:` `f120045a`, `5eb2ccfe`, `a167185d`, `57d5206e`,
  `302f077f`, `fdd7b93d`, `3d5279db`, `b1e7470d`, `9848dc87`, `bcc006cf`,
  `8d44b8eb`
- `Architect validation spot-check:` `zig build test-config PASS`,
  `zig build test-editor PASS`, `zig build test-terminal-replay-all PASS`
- `Acceptance judgment:` concrete contraction edits and invariants are coherent,
  behavior/ABI remain stable, and gate state is complete.

### `CZH-B33` Present/Outcome Seam Hardening Implementation Cut (`accepted`)

Queue line (exact):

- execute one longer engineering loop (10-ticket pack) to harden present/outcome
  seam paths with concrete implementation cuts and invariant locks, maintaining
  behavior freeze and ABI stability

Acceptance:

- selected touched seam paths have concrete hardening edits with no duplicated
  ambiguous derivation stories in scope
- no host ABI/C export changes
- helper and integration tests lock landed hardening invariants
- scoped probe/doc hygiene is recorded for touched modules
- full stress ladder remains green through `CZH-GATE-87`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S28_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

Execution source:

- engineer executes `CZH-821`..`CZH-830` in order from
  `docs/todo/core/CZH_S28_TICKETS.md`
- one ticket per commit unless explicitly marked otherwise
- no empty commits unless ticket is explicitly `doc-only` or
  `verification-only`
- stop only at `CZH-GATE-87` or a real hard blocker

#### `CZH-821` hardening audit + scope lock (`CZH-S28`)

- map concrete hardening opportunities requiring code edits across:
  `terminal_widget_presentation_runtime.zig`,
  `terminal_widget_surface_state.zig`,
  `surface_attachment_contract.zig`,
  `presentable_contract.zig`,
  `TERMINAL_SURFACE_CONTRACT.md`
- lock exact edit targets and scope for `CZH-829`

#### `CZH-S28` engineer validation (`CZH-830`)

- **Date:** 2026-04-19
- **Tickets:** `CZH-821`..`CZH-830` (plus board state sync commit).
- **SL-0** `zig build` — **PASS**
- **SL-1** `zig build test` — **PASS**
- **SL-2** `zig build -Dmode=terminal` — **PASS**
- **SL-3** `zig build -Dmode=editor` — **PASS**
- **`zig build test-config`** — **PASS**
- **`zig build test-editor`** — **PASS**
- **`zig build test-terminal-replay-all`** — **PASS**
- **Android guard** — **SKIP** (lane paused)

Checkpoint packet: `docs/todo/core/CZH_S28_CHECKPOINT.md`.

#### Architect gate result

- `Review chunk: CZH-B33`
- `Verdict: accepted`
- `Engineer commits reviewed:` `655a2428`, `dcd6b303`, `93437ecb`, `32e903d7`,
  `789ea679`, `0fac505e`, `d3afd43e`, `d2ea32f0`, `168f9923`, `4a5d50ad`,
  `8d44b8eb`
- `Architect validation spot-check:` `zig build test-config PASS`,
  `zig build test-editor PASS`, `zig build test-terminal-replay-all PASS`
- `Process finding:` board marked `CZH-B33` accepted before architect verdict.
  Preserve architect-only acceptance ownership in future gate packets.
- `Acceptance judgment:` hardening/contraction updates and invariants are
  coherent, behavior/ABI remain stable.

### `CZH-B34` Present/Outcome Seam Hardening Follow-Through (`accepted`)

Queue line (exact):

- execute one longer engineering loop (10-ticket pack) to continue concrete
  present/outcome seam hardening follow-through with invariant locks and strict
  behavior freeze / ABI stability

Acceptance:

- selected touched seam paths have concrete follow-through hardening edits in
  scope (no placeholder verification-only commits unless explicitly tagged)
- no host ABI/C export changes
- helper and integration tests lock landed follow-through invariants
- scoped probe/doc hygiene is recorded for touched modules
- full stress ladder remains green through `CZH-GATE-88`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S29_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

Execution source:

- engineer executes `CZH-831`..`CZH-840` in order from
  `docs/todo/core/CZH_S29_TICKETS.md`
- one ticket per commit unless explicitly marked otherwise
- no empty commits unless ticket is explicitly `doc-only` or
  `verification-only`
- stop only at `CZH-GATE-88` or a real hard blocker

#### `CZH-831` follow-through audit + scope lock (`CZH-S29`)

- map concrete follow-through opportunities requiring code edits across:
  `terminal_widget_presentation_runtime.zig`,
  `terminal_widget_surface_state.zig`,
  `surface_attachment_contract.zig`,
  `presentable_contract.zig`,
  `TERMINAL_SURFACE_CONTRACT.md`
- lock exact edit targets and scope for `CZH-839`

#### `CZH-S29` engineer validation (`CZH-840`)

- **Date:** 2026-04-19
- **Tickets:** `CZH-831`..`CZH-840`
- **SL-0** `zig build` — **PASS**
- **SL-1** `zig build test` — **PASS**
- **SL-2** `zig build -Dmode=terminal` — **PASS**
- **SL-3** `zig build -Dmode=editor` — **PASS**
- **`zig build test-config`** — **PASS**
- **`zig build test-editor`** — **PASS**
- **`zig build test-terminal-replay-all`** — **PASS**
- **Android guard** — **SKIP** (lane paused)

Checkpoint packet: `docs/todo/core/CZH_S29_CHECKPOINT.md`.

#### Architect gate result

- `Review chunk: CZH-B34`
- `Verdict: accepted`
- `Engineer commits reviewed:` `065a2ea4`, `31049000`, `a637b180`, `597fb337`,
  `aeff8898`, `9b5e6862`, `e51940f2`, `6308c766`, `0c22552d`, `6fcf04e1`
- `Architect validation spot-check:` `zig build test-config PASS`,
  `zig build test-editor PASS`, `zig build test-terminal-replay-all PASS`
- `Acceptance judgment:` follow-through hardening is coherent; behavior and ABI
  remain stable.

### `CZH-B35` Present/Outcome Seam Consolidation Follow-Through (`changes_required`)

Queue line (exact):

- execute one longer engineering loop (10-ticket pack) to continue concrete
  present/outcome seam consolidation through canonical helpers while preserving
  behavior freeze and ABI stability

Acceptance:

- selected runtime/state/result seam paths have concrete consolidation edits in
  scope (no placeholder verification-only commits unless explicitly tagged)
- no host ABI/C export changes
- helper and integration tests lock landed consolidation invariants
- scoped probe/doc hygiene is recorded for touched modules
- full stress ladder remains green through `CZH-GATE-89`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S30_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

Execution source:

- engineer executes `CZH-841`..`CZH-850` in order from
  `docs/todo/core/CZH_S30_TICKETS.md`
- one ticket per commit unless explicitly marked otherwise
- no empty commits unless ticket is explicitly `doc-only` or
  `verification-only`
- stop only at `CZH-GATE-89` or a real hard blocker

#### `CZH-841` follow-through audit + scope lock (`CZH-S30`)

- map concrete consolidation opportunities requiring code edits across:
  `terminal_widget_presentation_runtime.zig`,
  `terminal_widget_surface_state.zig`,
  `terminal_widget_presentation_state.zig`,
  `presentable_contract.zig`,
  `TERMINAL_SURFACE_CONTRACT.md`
- lock exact edit targets and scope for `CZH-849`

#### Architect gate result

- `Review chunk: CZH-B35`
- `Verdict: changes_required`
- `Reason:` Linux terminal startup smoke is broken by
  `TerminalWidgetSurfaceState.assertLegsInitialized` during
  terminal GUI initialization.
- `Failure path:` `notePresentableAvailability` asserts that both presentation
  legs are initialized immediately after writing the host-target leg, but the
  pipeline leg may still be unset on the first refresh path.
- `Architecture finding:` hardening assertions must reflect real runtime order.
  If the canonical route requires a different initialization owner, move the
  caller/state ownership cleanly; do not preserve the current caller shape just
  because it exists.
- `Source-comment finding:` touched product files contain ticket/progress
  wording such as `CZH-S30`; remove historical progress language from source
  comments and keep only current ownership/invariant text.

### `CZH-B36` Runtime Startup Correctness + Comment Hygiene (`accepted`)

Queue line (exact):

- fix the Linux terminal startup assertion regression, validate on the connected
  Android device, and clean product source comments so they describe current
  architecture rather than ticket history

Acceptance:

- bounded Linux terminal GUI startup smoke gets past initialization without the
  `assertLegsInitialized` panic and leaves no GUI process running
- connected Android device `RF8M74JDWEK` is used for compile/deploy/start/logcat
  smoke unless the device disconnects
- Windows/macOS validation is explicitly non-blocking for this correction pass
- product source comments in touched presentation files contain current
  ownership/invariant language only, with no ticket/progress history
- no host ABI/C export changes
- full stress ladder remains green through `CZH-GATE-90`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S31_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

Execution source:

- engineer executes `CZH-851`..`CZH-860` in order from
  `docs/todo/core/CZH_S31_TICKETS.md`
- one ticket per commit unless explicitly marked otherwise
- stop only at `CZH-GATE-90` or a real hard blocker

#### `CZH-851` runtime blocker audit + scope lock (`CZH-S31`)

- reproduce or reason from the captured stack for the startup assertion failure
- map the actual initialization order for:
  `terminal_presentable_pipeline_ready`,
  `host_surface_target_available`, and
  `shared_surface_attachment_ready`
- lock exact edit targets and source-comment cleanup scope

#### `CZH-S31` engineer validation (`CZH-860`)

- **Date:** 2026-04-19
- **Tickets:** `CZH-851`..`CZH-860`
- **SL-0** `zig build` — **PASS**
- **SL-1** `zig build test` — **PASS**
- **SL-2** `zig build -Dmode=terminal` — **PASS**
- **SL-3** `zig build -Dmode=editor` — **PASS**
- **Bounded Linux GUI startup smoke** — **PASS** (no assertion panic before timeout)
- **Android compile/deploy/start smoke** — **PASS** on `RF8M74JDWEK`

Checkpoint packet: `docs/todo/core/CZH_S31_CHECKPOINT.md`.

#### Architect gate result

- `Review chunk: CZH-B36`
- `Verdict: accepted`
- `Engineer commits reviewed:` `c603d941`, `318f9a0f`, `9874f122`,
  `c890e457`, `47ae240b`, `46d15f52`, `b3570d0f`, `6dddeee4`, `ddef7349`
- `Architect validation spot-check:` `zig build test-config PASS`,
  `zig build test-editor PASS`, `zig build test-terminal-replay-all PASS`,
  bounded Linux GUI startup smoke PASS, Android compile/deploy/start/logcat PASS
- `Acceptance judgment:` startup regression is fixed, behavior and ABI remain
  stable, and source comments in touched product code no longer carry sprint
  progress history.
- `Process finding:` checkpoint text claimed Android environment issues, but
  architect rerun passed compile/deploy/start; keep validation reporting strict.

### `CZH-B37` VT-Core Maturity Follow-Through + Caller Mobility (`accepted`)

Queue line (exact):

- continue the VT-core maturity direction by auditing and implementing caller
  ownership moves where needed, without letting current file/caller placement
  freeze the architecture

Acceptance:

- selected caller ownership moves are landed where they improve the mature split
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- touched source comments remain present-tense architecture only
- Linux and connected Android validation stay green through `CZH-GATE-91`
- Windows/macOS remain non-blocking unless their platform-owned code is touched

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S32_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

Execution source:

- engineer executes `CZH-861`..`CZH-870` in order from
  `docs/todo/core/CZH_S32_TICKETS.md`
- one ticket per commit unless explicitly marked otherwise
- stop only at `CZH-GATE-91` or a real hard blocker

#### `CZH-861` maturity audit + movement scope lock (`CZH-S32`)

- map remaining caller-placement constraints that block the intended mature
  split between VT core FFI, BYO-PTY, editor backend FFI, and terminal
  presentation/runtime ownership
- lock exact move targets and comment-hygiene scope for `CZH-869`

`Verdict: accepted`

- Architect review confirmed the caller-ownership move is real (widget delegates conjunction compute/read to terminal-owned `presentation_bridge`).
- Corrective cut removed ticket-history wording from touched comments and removed unused callback path without behavior drift.
- Validation spot-check stays green: core Zig ladder pass, bounded Linux GUI startup smoke pass, Android compile/deploy/start/logcat smoke pass.

### `CZH-B38` Terminal Presentation Runtime Ownership Extraction (`accepted`)

Queue line (exact):

- move terminal presentation orchestration ownership from widget runtime into a terminal-owned runtime module while keeping widget as a thin facade

Acceptance:

- terminal-owned runtime module is the canonical owner for refresh/reuse outcome orchestration in this seam
- widget runtime layer becomes delegation-focused (no duplicate orchestration logic)
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- touched source comments remain present-tense architecture only
- Linux and connected Android validation stay green through `CZH-GATE-92`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S33_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

`Verdict: accepted`

- Architect review confirmed runtime ownership extraction landed without behavior or ABI drift.
- Corrective passes removed historical ticket/sprint lineage from touched source comments and runtime seam tests.
- Validation spot-check stayed green: Zig ladder pass, bounded Linux GUI startup smoke pass, Android compile guard pass.

### `CZH-B39` Runtime Orchestration Ownership Completion (`accepted`)

Queue line (exact):

- finish moving terminal presentation orchestration ownership from widget runtime into terminal-owned runtime seams while keeping widget as integration facade

Acceptance:

- orchestration helpers that are pure terminal presentation logic are terminal-owned
- widget runtime remains integration/orchestration facade only for renderer/shell context wiring
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- touched source comments remain present-tense architecture only
- Linux and connected Android validation stay green through `CZH-GATE-93`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S34_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

`Verdict: accepted`

- Architect review confirmed a real code extraction landed: terminal-owned `computeTerminalPresentPlanDecision` now owns present-plan decision logic, and widget runtime delegates.
- Validation spot-check stayed green: Zig ladder pass, bounded Linux GUI startup smoke pass, Android debug/release compile guard pass.
- Process correction: checkpoint text claimed Android gradle environment failure, but architect rerun passed; keep validation claims strict and current.

### `CZH-B40` Callback-Based Orchestration Extraction (`accepted`)

Queue line (exact):

- complete runtime orchestration extraction by introducing callback-based terminal-owned orchestrators so widget remains integration-only facade

Acceptance:

- refresh/reuse/direct orchestration helpers that remain in widget runtime are moved to terminal runtime with explicit callback interfaces
- widget runtime keeps integration concerns only (renderer/shell/context wiring)
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- touched source comments remain present-tense architecture only
- Linux and connected Android validation stay green through `CZH-GATE-94`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S35_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

`Verdict: accepted`

- Architect review confirmed refresh/reuse/direct orchestration decisions are terminal-owned and widget runtime delegates as integration facade.
- Corrective extraction commit `5185d084` activated the terminal refresh orchestrator call path.
- Validation stayed green on Linux and connected Android.

### `CZH-B41` Execution-Hook Purity and Facade Tightening (`accepted`)

Queue line (exact):

- tighten callback orchestration execution hooks so terminal-owned seams are explicit, minimal, and test-locked while widget remains integration-only

Acceptance:

- terminal-owned orchestration hooks remain pure about decisions and folding responsibilities
- widget runtime owns integration wiring only (renderer/shell/timing side effects)
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-95`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S36_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

`Verdict: accepted`

- Architect review confirmed refresh execution-hook purity (`refreshPresentState`) and facade ownership tightening landed as single-path behavior-preserving cuts.
- Test/invariant coverage increased and remained green.
- Linux ladder + bounded GUI smoke + Android deploy/log smoke stayed green.

### `CZH-B42` Callback Surface Reduction and Runtime Boundary Hardening (`accepted`)

Queue line (exact):

- reduce callback surface ambiguity and harden terminal/widget runtime boundary contracts with behavior-neutral reductions and invariant locks

Acceptance:

- terminal-owned orchestration hooks expose only minimal required integration inputs
- widget runtime remains an integration facade with no decision/fold re-derivation
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-96`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S37_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

#### `CZH-B42` engineer validation record (2026-04-20)

- `zig build` — PASS
- `zig build test` — PASS
- `zig build -Dmode=terminal` — PASS
- `zig build -Dmode=editor` — PASS
- `timeout 3s zig build run -- --mode terminal` — PASS (bounded startup smoke)
- Android regression guard (connected device `RF8M74JDWEK`) — PASS
  - `./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac`
  - `./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac`
  - `python3 ops/android_terminal_host.py deploy`
  - `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E`

`Verdict: accepted`

- Architect review confirmed callback surface reductions remained behavior-neutral and preserved widget-facade boundaries.
- Added invariants and integration tests locked reduced boundary contracts.
- Linux ladder + bounded GUI smoke + Android deploy/log smoke stayed green.

### `CZH-B43` Outcome Carrier Simplification and Boundary De-duplication (`accepted`)

Queue line (exact):

- simplify outcome carrier flow and remove boundary de-duplication leftovers while preserving terminal-owned decision/fold semantics

Acceptance:

- terminal-owned orchestration keeps single authoritative outcome carrier path
- widget/runtime boundary does not duplicate outcome carrier derivation or transport
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-97`

#### `CZH-B43` engineer validation record (2026-04-20)

- `zig build` — PASS
- `zig build test` — PASS
- `zig build -Dmode=terminal` — PASS
- `zig build -Dmode=editor` — PASS
- `timeout 3s zig build run -- --mode terminal` — PASS (bounded startup smoke; process exited by timeout after successful startup banner)
- Android regression guard (connected device `RF8M74JDWEK`) — PASS
  - `python3 ops/android_terminal_host.py deploy`
  - `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E`

#### `CZH-B43` super-gate packet (engineer → architect)

- `Review chunk: CZH-B43`
- `Verdict: architect_review_pending`
- `Scope summary:` outcome carrier flow was simplified across refresh/reuse/direct paths with terminal-owned canonical folds, preceded by corrective carrier-flow audit mapping for ticket-accounting integrity:
  - `CZH-921` corrective doc-only audit map added to capture carrier-flow and de-dup targets as sprint authority evidence
  - refresh path now carries `shared_surface_attachment_ready` inline in `RefreshOutcomeState` and folds without a separate conjunction argument
  - reuse path removed redundant `reused` carrier flag and uses canonical `outcome == .reused` semantics
  - direct path now uses canonical direct-fold helper `presentResultFromDirectPresentOutcomeState(...)` to remove duplicate fold transport at widget boundary
  - widget/runtime boundary glue duplicates were removed where outcome transport was previously re-threaded or documented as separate
  - helper and integration invariants were expanded to lock inline refresh carrier semantics and direct-fold parity
- `Engineer commits reviewed:` `0aaed36c`, `8c72dd32`, `3627c76e`, `8c24955f`, `0fea268b`, `edd8ef1e`, `a1d756b1`, `24effe28`, `a46ac4dd`, `017ade77`
- `Residual risks / follow-ups:`
  - JIRA sprint board state transition (`in_progress` → `review_gate`) and sprint checkpoint file publication remain architect-owned acceptance actions
  - Android Java compile-only guard commands were not separately executed in this packet because deploy path remained green and launch/logcat smoke was clean
- `Architect validation request:` validate behavior-neutral carrier simplification and boundary de-duplication against `CZH-GATE-97`; confirm ticket closure and move sprint artifacts to accepted state if approved.

`Verdict: accepted`

- Architect review confirmed ticket-accounting integrity (including `CZH-921`) and behavior-neutral carrier simplification across refresh/reuse/direct paths.
- Boundary de-duplication remained within widget-facade constraints.
- Linux ladder + bounded GUI smoke + Android deploy/log smoke stayed green.

### `CZH-B44` Result Transport Flattening and Contract Locking (`accepted`)

Queue line (exact):

- flatten remaining result transport indirections and lock terminal/widget contract edges with behavior-neutral tests

Acceptance:

- terminal-owned fold/result transport remains single-path and explicit
- widget boundary avoids duplicated result transport helpers
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-98`

#### `CZH-B44` engineer validation record (2026-04-20)

- `zig build` — PASS
- `zig build test` — PASS
- `zig build -Dmode=terminal` — PASS
- `zig build -Dmode=editor` — PASS
- `timeout 3s zig build run -- --mode terminal` — PASS (bounded startup smoke; process exited by timeout after startup banner)
- Android regression guard (connected device `RF8M74JDWEK`) — PASS
  - `python3 ops/android_terminal_host.py deploy`
  - `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E`

#### `CZH-B44` super-gate packet (engineer → architect)

- `Review chunk: CZH-B44`
- `Verdict: architect_review_pending`
- `Scope summary:` result transport flattening and contract-locking landed as behavior-neutral seams:
  - `CZH-931` added audit authority map for remaining result transport indirections and flattening targets
  - `CZH-932` tightened architecture authority around terminal-owned result transport and fold exits
  - `CZH-933` flattened refresh transport mapping by introducing terminal helper `refreshedPresentationResultFromCycleTiming(...)` and routing widget refresh result timing through the canonical helper
  - `CZH-934` flattened reuse transport by introducing terminal helper `foldReuseAttemptOutcome(...)` and routing widget reuse wrapper through canonical terminal fold helper
  - `CZH-935` flattened direct-present timing transport via terminal helper `directPresentTimingResult(...)`
  - `CZH-936` removed boundary glue duplication while preserving widget-as-facade and terminal-owned fold semantics
  - `CZH-937` and `CZH-938` added helper/integration invariants locking refresh/reuse/direct flattened transport contracts
  - `CZH-939` completed hygiene sweep with no residual probe/debug lineage in touched seams
- `Engineer commits reviewed:` `ccac0976`, `01c48e58`, `1f159554`, `0a3e1185`, `279dd12c`, `917a89f7`, `705ed67e`, `877c5fcb`, `8d971f41`
- `Residual risks / follow-ups:`
  - Sprint board checkpoint transition to accepted remains architect-owned after `CZH-GATE-98` review
- `Architect validation request:` validate behavior-neutral transport flattening and contract locks against `CZH-GATE-98`; confirm sprint closure if accepted.

`Verdict: accepted`

- Architect review confirmed result transport flattening remained behavior-neutral and preserved terminal-owned fold semantics.
- Helper/integration invariants locked flattened transport behavior.
- Linux ladder + bounded GUI smoke + Android deploy/log smoke stayed green.

### `CZH-B45` Refresh/Reuse Transport Boundary Consolidation (`accepted`)

Queue line (exact):

- consolidate refresh/reuse transport boundaries to reduce remaining contract spread while preserving behavior and ownership

Acceptance:

- terminal-owned refresh/reuse transport stays canonical and single-path
- widget boundary remains integration-only with no duplicate transport derivation
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-99`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S40_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

#### `CZH-B45` engineer validation record (2026-04-20)

- `zig build` — PASS
- `zig build test` — PASS
- `zig build -Dmode=terminal` — PASS
- `zig build -Dmode=editor` — PASS
- `timeout 3s zig build run -- --mode terminal` — PASS (bounded startup smoke; process exited by timeout after startup banner)
- Android regression guard (connected device `RF8M74JDWEK`) — PASS
  - `python3 ops/android_terminal_host.py deploy`
  - `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E`

#### `CZH-B45` super-gate packet (engineer → architect)

- `Review chunk: CZH-B45`
- `Verdict: architect_review_pending`
- `Scope summary:` refresh/reuse transport boundary consolidation landed as behavior-neutral seams:
  - `CZH-941` added boundary audit/consolidation authority map for remaining refresh/reuse boundary spread
  - `CZH-942` tightened architecture authority for refresh/reuse boundary ownership and canonical fold exits
  - `CZH-943` consolidated refresh boundary transport to terminal-owned canonical folded host-facing result via `refreshedPresentationResultFromCycle(...)`
  - `CZH-944` consolidated reuse boundary transport to terminal-owned canonical helper `foldReuseAttemptResultToPresent(...)`
  - `CZH-945` simplified boundary helper aliases/usages to match consolidated canonical naming
  - `CZH-946` removed residual widget/runtime glue duplication at reuse boundary callsite
  - `CZH-947` and `CZH-948` added helper/integration invariants locking consolidated refresh/reuse boundary semantics and parity
  - `CZH-949` completed hygiene sweep with no residual probe/debug lineage in touched seams
- `Engineer commits reviewed:` `509b61aa`, `97066e49`, `273a69ac`, `f6ab3ce0`, `54b7b1f3`, `fe8589ac`, `4afedb39`, `cb20133a`, `ee3efa3f`
- `Residual risks / follow-ups:`
  - Sprint board/checkpoint transition to accepted remains architect-owned after `CZH-GATE-99` review
- `Architect validation request:` validate behavior-neutral refresh/reuse transport boundary consolidation against `CZH-GATE-99`; confirm sprint closure if accepted.

`Verdict: accepted`

- Architect review confirmed refresh/reuse transport boundary consolidation remained behavior-neutral and preserved canonical terminal-owned fold/result paths.
- Helper and integration invariants locked the consolidated boundary semantics.
- Linux ladder + bounded GUI smoke + Android deploy/log smoke stayed green.

### `CZH-B46` Boundary Alias Pruning and Surface Contract Narrowing (`accepted`)

Queue line (exact):

- prune remaining boundary aliases and narrow surface contract vocabulary to canonical transport terms without behavior change

Acceptance:

- terminal-owned transport/fold vocabulary remains canonical and single-path
- widget/runtime boundary no longer carries redundant alias terms
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-100`

#### `CZH-B46` engineer validation record (2026-04-20)

- `zig build` — PASS
- `zig build test` — PASS
- `zig build -Dmode=terminal` — PASS
- `zig build -Dmode=editor` — PASS
- `timeout 3s zig build run -- --mode terminal` — PASS (bounded startup smoke; process exited by timeout after startup banner)
- Android regression guard (connected device `RF8M74JDWEK`) — PASS
  - `python3 ops/android_terminal_host.py deploy`
  - `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E`

#### `CZH-B46` super-gate packet (engineer → architect)

- `Review chunk: CZH-B46`
- `Verdict: accepted`
- `Scope summary:` boundary alias pruning + surface contract narrowing landed as behavior-neutral seam hardening:
  - `CZH-951` added alias/vocabulary audit map and canonical replacement dictionary for boundary transport terms
  - `CZH-952` tightened architecture authority to canonical transport vocabulary and narrowed refresh/reuse wording
  - `CZH-953` pruned refresh-side alias terms (`runRefreshedPresentablePresentation` -> `runRefreshBoundaryPresentationResult`) and aligned refresh boundary commentary
  - `CZH-954` pruned reuse-side alias terms and exposed canonical reuse alias export (`presentResultFromReuseOutcomeState`) mapped to `foldReuseAttemptResultToPresent`
  - `CZH-955` pruned direct/fold alias language toward canonical direct boundary folded-result vocabulary
  - `CZH-956` cleaned stale widget/runtime alias glue in local boundary tests
  - `CZH-957` and `CZH-958` added helper/integration invariants locking canonical vocabulary routes and behavior parity
  - `CZH-959` completed hygiene sweep with no residual probe/debug lineage in touched seams
- `Engineer commits reviewed:` `10b4bf7f`, `7100815b`, `49055d7d`, `dbe07a5e`, `8874e740`, `fbb2d606`, `9cc7d2a9`, `efccb67a`, `baf51942`
- `Residual risks / follow-ups:`
  - Sprint board/checkpoint transition to accepted remains architect-owned after `CZH-GATE-100` review
- `Architect validation request:` validate behavior-neutral alias pruning and contract vocabulary narrowing against `CZH-GATE-100`; confirm sprint closure if accepted.

`Verdict: accepted`

- Architect review confirmed alias pruning and contract vocabulary narrowing remained behavior-neutral and ABI-stable.
- Helper and integration invariants lock canonical boundary vocabulary routes after pruning.
- Linux ladder + bounded GUI smoke + Android deploy/log smoke stayed green.

### `CZH-B47` Boundary Helper Contraction + Refresh/Reuse Result Narrowing (`accepted`)

Queue line (exact):

- contract remaining refresh/reuse boundary helper duplication and narrow result carriers to canonical folded host-facing transport semantics without behavior change

Acceptance:

- refresh/reuse boundary helper routes are canonical and single-path
- refresh/reuse result carriers expose only canonical folded host-facing transport semantics
- widget/runtime boundary has no duplicate helper or carrier glue
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-101`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S42_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

#### `CZH-B47` engineer validation record (2026-04-20)

- `zig build` — PASS
- `zig build test` — PASS
- `zig build -Dmode=terminal` — PASS
- `zig build -Dmode=editor` — PASS
- `timeout 3s zig build run -- --mode terminal` — PASS (bounded smoke; startup banner observed; timeout exit expected for bounded run)
- Android regression guard (connected device `RF8M74JDWEK`) — PASS
  - `python3 ops/android_terminal_host.py deploy`
  - `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E`

#### `CZH-B47` super-gate packet (engineer → architect)

- `Review chunk: CZH-B47`
- `Verdict: accepted`
- `Scope summary:` boundary helper contraction + refresh/reuse boundary carrier narrowing landed as behavior-neutral seam tightening:
  - `CZH-961` added explicit helper/carrier contraction audit map and ordered cut plan (`docs/todo/core/CZH_961_BOUNDARY_CONTRACTION_AUDIT_MAP.md`)
  - `CZH-962` tightened authority language in `TERMINAL_SURFACE_CONTRACT.md` to contracted helper routes and narrowed result carriers
  - `CZH-963` removed refresh-side wrapper helper duplication; refresh boundary fold now routes directly through `presentResultFromRefreshOutcomeState`
  - `CZH-964` removed reuse-side terminal wrapper duplication; reuse fold now terminates at `foldReuseAttemptResultToPresent`
  - `CZH-965` narrowed refresh boundary carrier to direct `TerminalPresentResult` transport (removed wrapper-only refresh boundary carrier)
  - `CZH-966` narrowed reuse boundary carrier so `tryFastPresentExisting` returns folded `TerminalPresentResult` directly
  - `CZH-967` removed stale widget passthrough glue (`runFastPresentIfAvailable`) after helper/result contraction
  - `CZH-968` added helper-level invariants locking canonical reuse helper declaration set and refresh boundary carrier narrowing
  - `CZH-969` added integration invariants locking contracted widget/terminal parity and no-wrapper boundary hygiene
- `Engineer commits reviewed:` `7048df90`, `022a1a32`, `4ffb4a0e`, `923cccc4`, `f3718afd`, `17923b45`, `20d76773`, `bb180cce`, `dea6a882`
- `Residual risks / follow-ups:`
  - Sprint board/checkpoint transition to accepted remains architect-owned after `CZH-GATE-101` review
- `Architect validation request:` validate behavior-neutral helper contraction and boundary carrier narrowing against `CZH-GATE-101`; confirm sprint closure if accepted.

`Verdict: accepted`

- Architect review confirmed helper contraction and refresh/reuse boundary carrier narrowing remained behavior-neutral and ABI-stable.
- Helper and integration invariants lock canonical boundary helper/result routes post-contraction.
- Linux ladder + bounded GUI smoke + Android deploy/log smoke stayed green.

### `CZH-B48` Boundary Result Transport Collapse + Helper Surface Narrowing (`accepted`)

Queue line (exact):

- collapse remaining boundary result transport duplication and narrow helper surfaces to one canonical route per flow without behavior change

Acceptance:

- refresh/reuse/direct boundary result transport is canonical and single-path
- helper surface contains one canonical fold/transport route per flow
- widget/runtime boundary contains no duplicate transport glue
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-102`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S43_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

#### `CZH-B48` engineer validation record (2026-04-20)

- `zig build` — PASS
- `zig build test` — PASS
- `zig build -Dmode=terminal` — PASS
- `zig build -Dmode=editor` — PASS
- `timeout 3s zig build run -- --mode terminal` — PASS (bounded smoke; startup banner observed; timeout exit expected for bounded run)
- Android regression guard (connected device `RF8M74JDWEK`) — PASS
  - `python3 ops/android_terminal_host.py deploy`
  - `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E`

#### `CZH-B48` super-gate packet (engineer → architect)

- `Review chunk: CZH-B48`
- `Verdict: accepted`
- `Scope summary:` boundary result transport collapse + helper surface narrowing landed as behavior-neutral seam tightening:
  - `CZH-971` added explicit transport-collapse audit map and ordered cut plan (`docs/todo/core/CZH_971_TRANSPORT_COLLAPSE_AUDIT_MAP.md`)
  - `CZH-972` tightened authority wording in `TERMINAL_SURFACE_CONTRACT.md` to collapsed transport and narrowed helper surfaces
  - `CZH-973` collapsed refresh transport wrapper hop by inlining refresh boundary transport into the canonical refresh-flow hook return path
  - `CZH-974` collapsed reuse transport flow to one folded-result exit over a single canonical outcome route
  - `CZH-975` collapsed direct-present transport by removing intermediate direct timing wrapper struct hop in widget direct execution
  - `CZH-976` narrowed helper surface by removing terminal direct timing helper aliasing and keeping direct timing transport literal at callsites
  - `CZH-977` cleaned widget/runtime boundary glue by removing local fold aliases and routing calls directly to terminal-owned fold helpers
  - `CZH-978` added helper-level invariants locking collapsed refresh/direct helper surface and removed wrapper declarations
  - `CZH-979` added integration invariants locking collapsed boundary surface across widget/terminal and no-wrapper helper exposure
- `Engineer commits reviewed:` `f280a91b`, `14408aed`, `2e728524`, `dacfbdbb`, `2aff0e27`, `8fea1a71`, `b71b2f49`, `5b4e8c3a`, `0cb40960`
- `Residual risks / follow-ups:`
  - Sprint board/checkpoint transition to accepted remains architect-owned after `CZH-GATE-102` review
- `Architect validation request:` validate behavior-neutral boundary transport collapse and helper-surface narrowing against `CZH-GATE-102`; confirm sprint closure if accepted.

`Verdict: accepted`

- Architect review confirmed boundary result transport collapse and helper-surface narrowing remained behavior-neutral and ABI-stable.
- Helper and integration invariants lock the contracted transport/helper routes post-collapse.
- Linux ladder + bounded GUI smoke + Android deploy/log smoke stayed green.

### `CZH-B49` Boundary Fold-Route Unification + Transport-Field Contraction (`accepted`)

Queue line (exact):

- unify remaining boundary fold routes and contract duplicated transport fields to one canonical shape per flow without behavior change

Acceptance:

- refresh/reuse/direct fold routes are canonical and single-path
- duplicated transport fields are contracted to canonical flow-owned shapes
- widget/runtime boundary contains no duplicate fold/field glue
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-103`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S44_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

#### `CZH-B49` engineer validation record (2026-04-20)

- `zig build` — PASS
- `zig build test` — PASS
- `zig build -Dmode=terminal` — PASS
- `zig build -Dmode=editor` — PASS
- `timeout 3s zig build run -- --mode terminal` — PASS (bounded smoke; startup banner observed; timeout exit expected for bounded run)
- Android regression guard (connected device `RF8M74JDWEK`) — PASS
  - `python3 ops/android_terminal_host.py deploy`
  - `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E`

#### `CZH-B49` super-gate packet (engineer → architect)

- `Review chunk: CZH-B49`
- `Verdict: accepted`
- `Scope summary:` boundary fold-route unification + transport-field contraction landed as behavior-neutral seam tightening:
  - `CZH-981` added explicit fold-route/field-contraction audit map and ordered cut plan (`docs/todo/core/CZH_981_FOLD_ROUTE_FIELD_CONTRACTION_AUDIT_MAP.md`)
  - `CZH-982` tightened authority wording in `TERMINAL_SURFACE_CONTRACT.md` to unified fold-route vocabulary and contracted field story
  - `CZH-983` unified refresh fold-route naming to canonical `foldRefreshOutcomeToPresent`
  - `CZH-984` unified reuse fold-route naming to canonical `foldReuseOutcomeToPresent`
  - `CZH-985` unified direct fold-route naming to canonical `foldDirectOutcomeToPresent`
  - `CZH-986` contracted refresh followup transport fields into one nested `followup` carrier on `RefreshOutcomeState`
  - `CZH-987` contracted reuse/direct fold transport threading through shared `FoldTransportFields` on canonical generic fold entry
  - `CZH-988` added helper-level invariants locking unified fold-route declarations and shared fold transport carrier
  - `CZH-989` added integration invariants + hygiene locks for unified fold surface and contracted refresh followup carrier
- `Engineer commits reviewed:` `d419cd38`, `176a009b`, `3b6cb6aa`, `2938ac6c`, `d816426e`, `cf34a268`, `0a8c1033`, `b6e52330`, `eb180565`
- `Residual risks / follow-ups:`
  - Sprint board/checkpoint transition to accepted remains architect-owned after `CZH-GATE-103` review
- `Architect validation request:` validate behavior-neutral fold-route unification and transport-field contraction against `CZH-GATE-103`; confirm sprint closure if accepted.

`Verdict: accepted`

- Architect review confirmed fold-route unification and transport-field contraction remained behavior-neutral and ABI-stable.
- Helper and integration invariants lock canonical fold routes and contracted field shapes post-unification.
- Linux ladder + bounded GUI smoke + Android deploy/log smoke stayed green.

### `CZH-B50` Fold API Narrowing + Field-Shape Lock (`accepted`)

Queue line (exact):

- narrow terminal/widget fold APIs and lock canonical field shapes so transport semantics stay single-path without behavior change

Acceptance:

- refresh/reuse/direct fold APIs expose one canonical route per flow
- fold/result field shapes are canonical and locked for transport semantics
- widget/runtime boundary contains no duplicate API/field mapping glue
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-104`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S45_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

#### `CZH-B50` engineer validation record (2026-04-20)

- `zig build` — PASS
- `zig build test` — PASS
- `zig build -Dmode=terminal` — PASS
- `zig build -Dmode=editor` — PASS
- `timeout 3s zig build run -- --mode terminal` — PASS (bounded smoke; startup banner observed; timeout exit expected for bounded run)
- Android regression guard (connected device `RF8M74JDWEK`) — PASS
  - `python3 ops/android_terminal_host.py deploy`
  - `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E`

#### `CZH-B50` super-gate packet (engineer → architect)

- `Review chunk: CZH-B50`
- `Verdict: accepted`
- `Scope summary:` terminal/widget fold API narrowing + field-shape lock landed as behavior-neutral seam tightening:
  - `CZH-991` added explicit fold API/field-shape audit map and ordered cut plan (`docs/todo/core/CZH_991_FOLD_API_FIELD_SHAPE_AUDIT_MAP.md`)
  - `CZH-992` tightened authority wording in `TERMINAL_SURFACE_CONTRACT.md` to narrowed fold API surface and canonical field-shape lock
  - `CZH-993` narrowed refresh fold API by removing separate generic followup-field helper route and keeping inline refresh fold followup assignment
  - `CZH-994` narrowed reuse fold API by routing reuse fold mapping through one dedicated reuse field-mapping helper
  - `CZH-995` narrowed direct fold API by routing direct fold mapping through one dedicated direct field-mapping helper
  - `CZH-996` locked refresh/reuse field shape routing by adding canonical refresh fold field-mapping helper path
  - `CZH-997` locked direct field shape with direct outcome carrier compile-time field-shape assertion
  - `CZH-998` added helper-level invariants locking narrowed fold API surface and canonical field-shape declarations
  - `CZH-999` added integration invariants + hygiene locks for narrowed fold API surface and canonical transport field-shape exposure
- `Engineer commits reviewed:` `9a548329`, `63085e2e`, `0e0d4a36`, `1075b5eb`, `79c59c22`, `b6187044`, `da5e6022`, `f84c000d`, `9139742a`
- `Residual risks / follow-ups:`
  - Sprint board/checkpoint transition to accepted remains architect-owned after `CZH-GATE-104` review
- `Architect validation request:` validate behavior-neutral fold API narrowing and field-shape lock against `CZH-GATE-104`; confirm sprint closure if accepted.

`Verdict: accepted`

- Architect review confirmed fold API narrowing and field-shape lock remained behavior-neutral and ABI-stable.
- Helper and integration invariants lock the narrowed fold API surface and canonical field-shape semantics.
- Linux ladder + bounded GUI smoke + Android deploy/log smoke stayed green.

### `CZH-B51` Fold/Result Struct Contraction + Boundary Callsite Collapse (`accepted`)

Queue line (exact):

- contract fold/result structs and collapse boundary callsites so routing remains canonical and single-path without behavior change

Acceptance:

- refresh/reuse/direct fold/result structs are canonical and minimal per flow
- boundary callsites collapse to one canonical route per flow
- widget/runtime boundary contains no duplicate callsite/field mapping glue
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-105`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S46_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

#### `CZH-B51` engineer validation record (2026-04-20)

- `zig build` — PASS
- `zig build test` — PASS
- `zig build -Dmode=terminal` — PASS
- `zig build -Dmode=editor` — PASS
- `timeout 3s zig build run -- --mode terminal` — PASS (bounded smoke; startup banner observed; timeout exit expected for bounded run)
- Android regression guard (connected device `RF8M74JDWEK`) — PASS
  - `python3 ops/android_terminal_host.py deploy`
  - `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E`

#### `CZH-B51` super-gate packet (engineer → architect)

- `Review chunk: CZH-B51`
- `Verdict: accepted`
- `Scope summary:` fold/result struct contraction + boundary callsite collapse landed as behavior-neutral seam tightening:
  - `CZH-1001` added explicit struct/callsite contraction audit map and ordered cut plan (`docs/todo/core/CZH_1001_STRUCT_CALLSITE_CONTRACTION_AUDIT_MAP.md`)
  - `CZH-1002` tightened authority wording in `TERMINAL_SURFACE_CONTRACT.md` to contracted fold/result carriers and collapsed boundary callsites
  - `CZH-1003` contracted refresh outcome carrier around canonical transport sub-struct while preserving behavior-neutral field routing
  - `CZH-1004` contracted reuse outcome carrier to include canonical transport sub-struct
  - `CZH-1005` contracted direct outcome carrier to include canonical transport sub-struct
  - `CZH-1006` collapsed widget boundary callsites to direct terminal-runtime canonical route usage (reduced local alias glue)
  - `CZH-1007` collapsed terminal boundary mapping callsites by removing dedicated boundary mapping helpers
  - `CZH-1008` added helper-level invariants for contracted struct/callsite surface and removed mapping-helper declaration exposure
  - `CZH-1009` added integration invariants + hygiene locks for contracted carrier exposure and collapsed callsite surface
- `Engineer commits reviewed:` `a56fe953`, `13a0cf9b`, `b4788537`, `7c6b3f21`, `b8ca9087`, `d57e820f`, `fd89240e`, `918a5397`, `c35ce99a`
- `Residual risks / follow-ups:`
  - Sprint board/checkpoint transition to accepted remains architect-owned after `CZH-GATE-105` review
- `Architect validation request:` validate behavior-neutral fold/result struct contraction and boundary callsite collapse against `CZH-GATE-105`; confirm sprint closure if accepted.

`Verdict: accepted`

- Architect review confirmed fold/result struct contraction and boundary callsite collapse remained behavior-neutral and ABI-stable.
- Helper and integration invariants lock contracted carrier shapes and canonical callsite routes.
- Linux ladder + bounded GUI smoke + Android deploy/log smoke stayed green.

### `CZH-B52` Outcome/Transport Helper Collapse + Boundary Callsite Canonicalization (`accepted`)

Queue line (exact):

- collapse remaining outcome/transport helper duplication and canonicalize boundary callsites to one route per flow without behavior change

Acceptance:

- refresh/reuse/direct outcome/transport helper surface is canonical and minimal per flow
- boundary callsites are canonicalized to one route per flow
- widget/runtime boundary contains no duplicate helper/callsite glue
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-106`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S47_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

#### `CZH-B52` engineer validation record (2026-04-20)

- `zig build` — PASS
- `zig build test` — PASS
- `zig build -Dmode=terminal` — PASS
- `zig build -Dmode=editor` — PASS
- `timeout 3s zig build run -- --mode terminal` — PASS (bounded smoke; startup banner observed; timeout exit expected for bounded run)
- Android regression guard (connected device `RF8M74JDWEK`) — PASS
  - `python3 ops/android_terminal_host.py deploy`
  - `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E`

#### `CZH-B52` super-gate packet (engineer → architect)

- `Review chunk: CZH-B52`
- `Verdict: accepted`
- `Scope summary:` outcome/transport helper collapse + boundary callsite canonicalization landed as behavior-neutral seam tightening:
  - `CZH-1011` added explicit helper/callsite collapse audit map and ordered cut plan (`docs/todo/core/CZH_1011_HELPER_CALLSITE_COLLAPSE_AUDIT_MAP.md`)
  - `CZH-1012` tightened authority wording in `TERMINAL_SURFACE_CONTRACT.md` to collapsed helper surface and canonicalized boundary callsites
  - `CZH-1013` collapsed refresh helper duplication via canonical refresh transport helper route in refresh outcome classification
  - `CZH-1014` collapsed reuse helper duplication via canonical reuse transport helper route in reuse outcome/fold composition
  - `CZH-1015` collapsed direct helper duplication via canonical direct transport helper route in direct outcome/fold composition
  - `CZH-1016` canonicalized widget boundary callsites to one local route per outcome/fold helper set
  - `CZH-1017` canonicalized terminal fold callsites to one transport-carrier route per flow
  - `CZH-1018` added helper-level invariants locking collapsed helper surface and transport-carrier fold usage
  - `CZH-1019` added integration invariants + hygiene locks for collapsed helper exposure and canonicalized callsites
- `Engineer commits reviewed:` `a039f202`, `f4265482`, `001d85d5`, `9ba0eb43`, `fb9f502d`, `8019fb38`, `cda7351b`, `e6266e13`, `116b8ee9`
- `Residual risks / follow-ups:`
  - Sprint board/checkpoint transition to accepted remains architect-owned after `CZH-GATE-106` review
- `Architect validation request:` validate behavior-neutral outcome/transport helper collapse and boundary callsite canonicalization against `CZH-GATE-106`; confirm sprint closure if accepted.

`Verdict: accepted`

- Architect review confirmed outcome/transport helper collapse and boundary callsite canonicalization remained behavior-neutral and ABI-stable.
- Helper and integration invariants lock collapsed helper surface and canonical callsite routes.
- Linux ladder + bounded GUI smoke + Android deploy/log smoke stayed green.

### `CZH-B53` Canonical Fold-Entry Collapse + Boundary Field-Route Lock (`accepted`)

Queue line (exact):

- collapse remaining canonical fold-entry duplication and lock boundary field routes to one route per flow without behavior change

Acceptance:

- refresh/reuse/direct canonical fold-entry surface is minimal and single-path per flow
- boundary field routes are locked to one canonical route per flow
- widget/runtime boundary contains no duplicate fold-entry/field-route glue
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-107`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S48_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

#### `CZH-B53` engineer validation record (2026-04-20)

- `zig build` — PASS
- `zig build test` — PASS
- `zig build -Dmode=terminal` — PASS
- `zig build -Dmode=editor` — PASS
- `timeout 3s zig build run -- --mode terminal` — PASS (bounded smoke; startup banner observed; timeout exit expected for bounded run)
- Android regression guard (connected device `RF8M74JDWEK`) — PASS
  - `python3 ops/android_terminal_host.py deploy`
  - `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E`

#### `CZH-B53` super-gate packet (engineer → architect)

- `Review chunk: CZH-B53`
- `Verdict: accepted`
- `Scope summary:` canonical fold-entry collapse + boundary field-route lock landed as behavior-neutral seam tightening:
  - `CZH-1021` added explicit fold-entry/field-route audit map and ordered cut plan (`docs/todo/core/CZH_1021_FOLD_ENTRY_FIELD_ROUTE_AUDIT_MAP.md`)
  - `CZH-1022` tightened authority wording in `TERMINAL_SURFACE_CONTRACT.md` to canonical fold-entry collapse and boundary route locks
  - `CZH-1023` collapsed refresh canonical fold-entry setup to one helper route
  - `CZH-1024` collapsed reuse canonical fold-entry setup to one helper route
  - `CZH-1025` collapsed direct canonical fold-entry setup to one helper route
  - `CZH-1026` locked refresh boundary field routes via mirrored-route assertions against transport carrier
  - `CZH-1027` locked reuse/direct boundary field routes via mirrored-route assertions against transport carrier
  - `CZH-1028` added helper-level invariants for collapsed fold entries + locked field routes
  - `CZH-1029` added integration invariants + hygiene locks for canonicalized fold-entry and route behavior
- `Engineer commits reviewed:` `e9345539`, `77e5398e`, `b4f48524`, `8993d575`, `da021f69`, `937c0789`, `aff06657`, `731ede6e`, `4d02d345`
- `Residual risks / follow-ups:`
  - Sprint board/checkpoint transition to accepted remains architect-owned after `CZH-GATE-107` review
- `Architect validation request:` validate behavior-neutral canonical fold-entry collapse and boundary field-route lock against `CZH-GATE-107`; confirm sprint closure if accepted.

`Verdict: accepted`

- Architect review confirmed canonical fold-entry collapse and boundary field-route lock remained behavior-neutral and ABI-stable.
- Helper and integration invariants lock collapsed fold-entry setup and mirrored route-lock behavior.
- Linux ladder + bounded GUI smoke + Android deploy/log smoke stayed green.

### `CZH-B54` Fold Transport Helper Collapse + Route-Lock Simplification (`accepted`)

Queue line (exact):

- collapse remaining fold transport helper duplication and simplify route-lock checks to one canonical route per flow without behavior change

Acceptance:

- refresh/reuse/direct fold transport helper surface is canonical and minimal per flow
- route-lock checks are simplified and canonical per flow
- widget/runtime boundary contains no duplicate helper/route-lock glue
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-108`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S49_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

`Verdict: accepted`

- Architect review confirmed fold transport helper collapse and route-lock simplification remained behavior-neutral and ABI-stable.
- Helper and integration invariants lock simplified route-lock checks and collapsed helper surface.
- Linux ladder + bounded GUI smoke + Android deploy/log smoke stayed green.

### `CZH-B55` Fold-Route Assertion Collapse + Transport Mapping Simplification (`accepted`)

Queue line (exact):

- collapse remaining fold-route assertion duplication and simplify transport mapping checks to one canonical route per flow without behavior change

Acceptance:

- refresh/reuse/direct fold-route assertions are collapsed and canonical per flow
- transport mapping checks are simplified and canonical per flow
- widget/runtime boundary contains no duplicate assertion/mapping glue
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-109`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S50_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

`Verdict: accepted`

- Architect review confirmed fold-route assertion collapse and transport mapping simplification remained behavior-neutral and ABI-stable.
- Helper and integration invariants lock collapsed assertion paths and simplified mapping checks.
- Linux ladder + bounded GUI smoke + Android deploy/log smoke stayed green.

### `CZH-B56` Fold Transport Route Pruning + Assertion-Surface Minimization (`accepted`)

Queue line (exact):

- prune remaining fold transport route duplication and minimize assertion surface to one canonical path per flow without behavior change

Acceptance:

- refresh/reuse/direct fold transport routes are canonical and minimal per flow
- assertion surface is minimized and canonical per flow
- widget/runtime boundary contains no duplicate route/assertion glue
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-110`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S51_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

`Verdict: accepted`

- Architect review confirmed route pruning and assertion-surface minimization remained behavior-neutral and ABI-stable.
- Refresh/reuse/direct flows now use transport-only result carriers without duplicate top-level field mirrors.
- Linux ladder + bounded GUI smoke + Android deploy/log smoke stayed green through `CZH-GATE-110`.

### `CZH-B57` Outcome/Fold Surface Consolidation (Larger-Cut Sprint) (`accepted`)

Queue line (exact):

- remove remaining outcome/fold helper indirection by landing canonical per-flow folds and reducing widget/runtime boundary to one data-gather + one terminal call per flow

Acceptance:

- refresh/reuse/direct each expose one canonical fold entry in terminal runtime
- widget runtime delegates per-flow fold decisions through one canonical terminal call path
- boundary helper naming and docs reflect ownership without alias duplication
- helper + integration invariants lock parity and prevent field-route drift
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-111`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S52_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

`Verdict: accepted`

- Architect review confirmed canonical fold-entry consolidation is behavior-neutral and ABI-stable.
- Refresh/reuse/direct production callsites now route through terminal-owned canonical entries.
- Widget layer remains a façade for orchestration/integration; terminal layer owns fold construction/validation.
- Linux ladder + bounded GUI smoke + Android deploy/log smoke remained green through `CZH-GATE-111`.

### `CZH-B58` Outcome-State/Internal API Contraction (Larger-Cut Sprint) (`accepted`)

Queue line (exact):

- contract widget/runtime boundary to canonical result-only transport by internalizing outcome-state usage and pruning non-essential fold helper surface

Acceptance:

- widget runtime production paths consume canonical terminal result entries without outcome-state handling
- non-essential public fold helper aliases are pruned or internalized where safe
- helper + integration tests lock parity between canonical entries and remaining helper routes
- docs reflect result-only boundary ownership vocabulary
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-112`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S53_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

`Verdict: accepted`

- Architect review confirmed result-only widget boundary and terminal-internal outcome-state ownership remained behavior-neutral and ABI-stable.
- Reuse production flow now constructs outcome state in terminal runtime via `reuseEligibilityEntry(...)`; widget no longer constructs outcome carriers.
- Linux ladder + bounded GUI smoke + Android deploy/log smoke remained green through `CZH-GATE-112`.

### `CZH-B59` Canonical Entry/Eligibility Unification (Larger-Cut Sprint) (`accepted`)

Queue line (exact):

- unify remaining entry/eligibility helper surfaces into one canonical per-flow terminal entry contract and remove non-essential boundary glue while preserving behavior

Acceptance:

- refresh/reuse/direct production paths each use one canonical terminal entry with no duplicate boundary helper glue
- eligibility-to-result mapping is terminal-owned and consistent across reuse/direct flows
- helper + integration tests lock canonical-entry parity and boundary non-bypass invariants
- docs reflect unified entry vocabulary and ownership
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-113`

Engineer completion (2026-04-20):

- **All 8 tickets executed:** CZH-1077 through CZH-1084 (7 commits)
- **Validation ladder:** SL-0 PASS, SL-1 PASS, SL-2 PASS, SL-3 PASS
- **Canonical entries unified:** refreshPresentEntry, reuseEligibilityEntry, directPresentEntry
- **Redundant helpers removed:** reusePresentEntry (collapsed)
- **Fold helpers privatized:** foldRefreshOutcomeToPresent, foldReuseOutcomeToPresent, foldDirectOutcomeToPresent
- **Sprint checkpoint:** `docs/todo/core/CZH_S54_CHECKPOINT.md`
- **Board state:** All tickets moved to review_gate
- **Acceptance criteria:** All met (canonical entries, no boundary glue, docs updated, no behavior changes, no ABI changes, validation green)

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S54_TICKETS.md`
- `docs/todo/core/CZH_S54_CHECKPOINT.md`
- `docs/todo/core/CZH_S54_AUDIT.md`
- `docs/todo/core/CZH_S54_PRUNING.md`
- `docs/todo/core/CZH_S54_INVARIANTS.md`
- `docs/AGENT_HANDOFF.md`
- `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md`

`Verdict: accepted`

- Architect review confirmed entry/eligibility unification remained behavior-neutral and ABI-stable.
- Refresh/reuse/direct production paths are single-route through canonical terminal entries.
- Fold helpers are terminal-internal and no longer broad production boundary surface.
- Linux validation remained green for this batch scope.

### `CZH-B60` Result-Surface Tightening + Test-Surface Isolation (Larger-Cut Sprint) (`accepted`)

Queue line (exact):

- tighten result-surface ownership so production widget/runtime paths depend only on canonical terminal entries while test-only helper access stays explicit and isolated

Acceptance:

- production boundary uses canonical terminal entries only, with no test-surface leakage
- helper/test access paths are explicit and limited to test files
- docs align with canonical entry ownership and test-surface isolation
- helper + integration tests lock boundary non-bypass and route parity
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-114`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S55_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`


`Verdict: accepted`

- Architect review confirmed result-surface tightening and test-surface isolation remained behavior-neutral and ABI-stable.
- Production boundary remains canonical-entry only; fold/classification/assertion helpers are isolated to terminal-internal or explicit test usage.
- Linux validation remained green for batch scope.

### `CZH-B61` Canonical Entry Contract Lockdown + Exposure Prune (Larger-Cut Sprint) (`accepted`)

Queue line (exact):

- lock canonical entry contract as the only production boundary while pruning remaining non-essential helper exposure and hardening no-bypass invariants

Acceptance:

- production widget/runtime paths use canonical entries only with no secondary helper routes
- remaining helper exposure is minimal and explicitly justified (or pruned)
- helper + integration tests lock no-bypass and parity invariants
- docs align with canonical-entry contract and exposure rules
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-115`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S56_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`


`Verdict: accepted`

- Architect review confirmed canonical entry contract lockdown remained behavior-neutral and ABI-stable.
- Production entry routing remains canonical-only across refresh/reuse/direct flows.
- Helper exposure remains controlled; no secondary production entry surfaces were introduced.

### `CZH-B62` Contract-Only Production Surface Audit + Exposure Lock (Larger-Cut Sprint) (`accepted`)

Queue line (exact):

- harden canonical production surface so only contract-approved entry points remain production-callable while test helper access stays explicit and bounded

Acceptance:

- production-callable entry surface is minimal and contract-approved
- non-essential public helper exposure is removed or justified with explicit test-only scope
- helper + integration tests lock no-bypass and surface-parity guarantees
- docs align with production-surface contract and exposure bounds
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-116`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S57_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`


`Verdict: accepted`

- Architect review confirmed contract-only production surface lock remained behavior-neutral and ABI-stable.
- Canonical production-callable boundary remained minimal and no-bypass invariants stayed intact.

### `CZH-B63` Entry Contract Compression + Assertion Surface Trim (Larger-Cut Sprint) (`accepted`)

Queue line (exact):

- compress canonical entry contract surface and trim non-essential assertion/exposure layers while preserving behavior and ABI

Acceptance:

- production canonical entry surface remains single-route per flow with no helper leakage
- non-essential assertion/exposure layers are removed or explicitly scoped
- helper + integration invariants lock no-bypass and parity guarantees after trim
- docs align with compressed contract vocabulary and ownership
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-117`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S58_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`


`Verdict: accepted`

- Architect review confirmed entry contract compression/assertion trim remained behavior-neutral and ABI-stable.
- Canonical no-bypass guarantees remained intact after assertion surface reduction.

### `CZH-B64` Canonical Entry Contract Final Surface Seal (Larger-Cut Sprint) (`accepted`)

Queue line (exact):

- finalize canonical production entry contract by sealing residual helper exposure edges and locking final no-bypass/route-parity guarantees

Acceptance:

- production entry contract is sealed to canonical entry points only
- residual helper exposure edges are removed or explicitly constrained
- helper + integration tests lock final no-bypass and parity guarantees
- docs align with final sealed contract vocabulary
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-118`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S59_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`


`Verdict: accepted`

- Architect review confirmed final surface seal remained behavior-neutral and ABI-stable.
- Canonical entry contract remains sealed with no secondary production entry routes.

### `CZH-B65` Post-Seal Contract Governance Baseline (Larger-Cut Sprint) (`accepted`)

Queue line (exact):

- establish post-seal governance baseline by tightening change-control checks, explicit extension criteria, and regression locks around the sealed contract surface

Acceptance:

- post-seal governance rules are explicit and test-anchored
- extension/change criteria are documented and bounded to avoid contract drift
- helper + integration locks cover sealed-surface regression scenarios
- docs align with post-seal governance vocabulary and ownership
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-119`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S60_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

## Response Contract

Every batch update must include:

- `LABELS`
- `#DONE`
- `#OUTSTANDING`
- `COMMITS`
- `VALIDATION`
- `Blocked by Architect review needed: true|false` (Engineer)
- `Blocked by human review needed: true|false` (Architect)


### `CZH-B66` Governance Enforcement Tightening (Larger-Cut Sprint) (`accepted`)

Queue line (exact):

- tighten post-seal governance enforcement so canonical entry contract drift fails fast at compile/test boundaries

Acceptance:

- governance enforcement points are explicit and bounded per refresh/reuse/direct/shared paths
- regression + integration locks cover new enforcement paths and no-bypass guarantees
- docs align with governance enforcement vocabulary and ownership
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-120`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S61_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`


### `CZH-B67` Governance Simplification and Sustained Enforcement (Larger-Cut Sprint) (`accepted`)

Queue line (exact):

- simplify governance enforcement surface while preserving sealed-contract guard strength and drift detection coverage

Acceptance:

- redundant governance mappings are removed without weakening no-bypass protections
- refresh/reuse/direct/shared simplifications preserve enforcement intent and ownership clarity
- regression + integration locks prove sustained coverage after simplification
- docs align with sustained-enforcement vocabulary and ownership
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-121`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S62_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`


### `CZH-B68` Governance Runtime-to-Test Binding Tightening (Larger-Cut Sprint) (`accepted`)

Queue line (exact):

- tighten governance by binding runtime enforcement claims directly to explicit compile/test locks so drift detection stays verifiable

Acceptance:

- runtime enforcement claims are explicitly bound to concrete compile/test guards
- refresh/reuse/direct/shared bindings are documented and non-ambiguous
- regression + integration verification confirms no unbound claims remain
- docs align with binding vocabulary and ownership
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-122`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S63_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`


### `CZH-B69` Enforcement Surface Compaction with Lock Preservation (Larger-Cut Sprint) (`accepted`)

Queue line (exact):

- compact enforcement surface representation while preserving all established no-bypass and drift-lock guarantees

Acceptance:

- enforcement surface is reduced/compacted without weakening binding or lock guarantees
- refresh/reuse/direct/shared compaction preserves enforcement ownership clarity
- regression + integration verification proves lock preservation after compaction
- docs align with compaction vocabulary and ownership
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-123`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S64_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`


### `CZH-B70` Enforcement Signal Compression with Verifiability Retention (Larger-Cut Sprint) (`accepted`)

Queue line (exact):

- compress enforcement signal surface while preserving explicit verifiability through compile/test lock bindings

Acceptance:

- enforcement signal representation is reduced without weakening lock guarantees
- refresh/reuse/direct/shared signal compression preserves ownership clarity
- regression + integration verification proves retained explicit verifiability
- docs align with signal-compression vocabulary and ownership
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-124`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S65_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`


### `CZH-B71` Enforcement Evidence Surface Normalization (Larger-Cut Sprint) (`accepted`)

Queue line (exact):

- normalize enforcement evidence surface so lock/test traceability remains explicit while duplication is removed

Acceptance:

- enforcement evidence representation is normalized without weakening lock/test traceability
- refresh/reuse/direct/shared evidence paths preserve ownership clarity
- regression + integration verification proves unambiguous traceability after normalization
- docs align with evidence-normalization vocabulary and ownership
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-125`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S66_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`


### `CZH-B72` Enforcement Claim-to-Lock Trace Matrix Hardening (Larger-Cut Sprint) (`accepted`)

Queue line (exact):

- harden claim-to-lock trace matrix so every enforcement claim maps unambiguously to concrete compile/test guards

Acceptance:

- claim-to-lock trace matrix is explicit and unambiguous across refresh/reuse/direct/shared paths
- no unmapped or multiply-ambiguous enforcement claims remain
- regression + integration verification confirms matrix completeness
- docs align with trace-matrix vocabulary and ownership
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-126`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S67_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`


### `CZH-B73` Enforcement Matrix Determinism Hardening (Larger-Cut Sprint) (`accepted`)

Queue line (exact):

- harden enforcement matrix determinism so claim-to-lock mappings remain stable, ordered, and unambiguous under ongoing maintenance

Acceptance:

- claim-to-lock mappings are deterministic and consistently ordered across refresh/reuse/direct/shared paths
- no ambiguity or ordering drift remains in enforcement matrix representations
- regression + integration verification confirms determinism preservation
- docs align with determinism vocabulary and ownership
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-127`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S68_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`


### `CZH-B74` Enforcement Matrix Drift-Guard Tightening (Larger-Cut Sprint) (`accepted`)

Queue line (exact):

- tighten matrix drift-guards so claim-to-lock mappings remain stable and regression-resistant under ongoing edits

Acceptance:

- drift-guard coverage is explicit across refresh/reuse/direct/shared paths
- identified drift vectors are closed without weakening existing determinism guarantees
- regression + integration verification confirms ongoing drift resistance
- docs align with drift-guard vocabulary and ownership
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-128`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S69_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`


### `CZH-B75` Drift-Guard Verification Surface Simplification (Larger-Cut Sprint) (`accepted`)

Queue line (exact):

- simplify drift-guard verification surface while preserving complete enforcement coverage and traceability

Acceptance:

- verification surface is simplified without reducing drift-guard coverage
- refresh/reuse/direct/shared simplifications preserve guard clarity and ownership
- regression + integration verification confirms full coverage preservation
- docs align with verification-surface vocabulary and ownership
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-129`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S70_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`


### `CZH-B76` Drift-Guard Coverage Evidence Consolidation (Larger-Cut Sprint) (`accepted`)

Queue line (exact):

- consolidate drift-guard coverage evidence while preserving explicit integrity and traceability

Acceptance:

- coverage evidence is consolidated without reducing drift-guard integrity
- refresh/reuse/direct/shared consolidations preserve coverage clarity and ownership
- regression + integration verification confirms full coverage integrity preservation
- docs align with coverage-evidence vocabulary and ownership
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-130`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S71_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`


### `CZH-B77` Coverage Evidence Invariant Locks (Larger-Cut Sprint) (`accepted`)

Queue line (exact):

- tighten invariant locks around consolidated coverage evidence so integrity remains robust under ongoing maintenance

Acceptance:

- invariant locks are explicit across refresh/reuse/direct/shared paths
- identified invariant gaps are closed without reducing existing coverage guarantees
- regression + integration verification confirms invariant integrity preservation
- docs align with invariant-lock vocabulary and ownership
- no compatibility/fallback paths are introduced
- no host ABI/C export changes
- source comments remain present-tense ownership/invariant statements only
- Linux and connected Android validation stay green through `CZH-GATE-131`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S72_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

#### Architect gate result

- `Review chunk: CZH-B77`
- `Verdict: accepted as terminal documentation-hardening stop point, not as a precedent for further doc-only sprinting`
- `Engineer commits reviewed:` `e6e9cc30`, `0d3e84fe`, `10d3eda7`, `697b3a7c`, `8c4835ac`, `161b5062`, `f188de7b`, `0ffd01fe`
- `Scope reality:` `CZH-S72` was documentation-only invariant-lock hardening: 673 inserted lines across authority/checkpoint/audit docs and no product code movement.
- `Process finding:` the lane drifted because governance/ticket compliance was allowed to substitute for product-path progress. This closes the enforcement-doc loop and bars further documentation-only hardening unless explicitly pre-approved.
- `Residual risk:` the real product goals remain: hot-path logging/probe/copy hygiene, naming/topology normalization, Android-to-core consolidation, then VT correctness.

### `CZH-B78` Product Hot-Path Hygiene Baseline (`in_progress`)

Queue line (exact):

- remove stale investigation logging, debug capture, raw pointer telemetry, and avoidable copy churn from real app paths so performance baselines are meaningful

Acceptance:

- active tickets produce code/test movement, not documentation-only churn
- real app paths do not retain investigation-only logging/probe/debug capture work by default
- retained telemetry is classified as correctness contract or operator telemetry with defensible disabled cost
- at least two bounded hot-path cleanup cuts land before the gate
- tests or assertions replace removed probe reliance where correctness still needs protection
- no behavior or ABI changes unless a concrete correctness bug is found and documented
- docs record only landed code/test evidence and active residual risks
- Linux validation ladder stays green through `CZH-GATE-132`

Non-goals:

- broad widget folder moves
- repo-wide naming normalization
- Android feature reopening
- VT correctness feature work
- enforcement-matrix/documentation optimization

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S73_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

Anti-drift gate:

- If an implementation ticket can be completed by markdown alone, it is mis-scoped and must return to Architect before execution.
- Every non-audit implementation commit must change product source or tests.
- The final checkpoint may update docs, but it cannot be the dominant output of the sprint.

#### Architect status update (`CZH-S73`)

- `CZH-1229` accepted: audit confirms product hot paths are already clean for unconditional investigation logging/debug contamination under current scope.
- Consequence: hygiene-only phrasing in `CZH-1230`/`CZH-1231` was underspecified for execution.
- Re-scope: `CZH-1230` is now an explicit architect-approved `doc-only` measurement attribution ticket to identify one defensible runtime-cost target.
- `CZH-1231` and `CZH-1232` remain code/test tickets and must land measured cleanup cuts.

#### Architect closure (`CZH-B78` / `CZH-GATE-132`)

- `Verdict: accepted`
- `Reason:` phase-1 hygiene baseline reached; audit (`CZH-1229`) and measurement (`CZH-1230`) found no executable unconditional hot-path cleanup targets within hygiene scope.
- `Scope disposition:` `CZH-1231`..`CZH-1234` closed without execution for this batch; moved to next-phase planning as needed.
- `Next batch opened:` `CZH-B79` / `CZH-S74` for naming and module-topology normalization.

### `CZH-B79` Naming + Module Topology Normalization (`in_progress`)

Queue line (exact):

- normalize naming and module boundaries in `src/ui/widgets/` to improve ownership clarity and extraction readiness without behavior change

Acceptance:

- one bounded architect-approved map ticket may be doc-only; remaining tickets are code/test movement
- renamed symbols and moved concerns are ownership-clear and behavior-neutral
- no broad folder reshuffle; cuts remain reviewable and bounded
- no compatibility shim residue remains after renamed/moved seams
- validation ladder stays green through `CZH-GATE-133`

Owner docs:

- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/CZH_S74_TICKETS.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

#### Architect status update (`CZH-S74`)

- `CZH-1235` accepted: widget naming/topology map is concrete and executable after import-site correction.
- `CZH-1236` opened as active execution ticket.

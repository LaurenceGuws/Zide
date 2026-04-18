# Core Zig Stability/Hygiene Queue

Active queue for the post-Android-pause core cleanup lane.

## Mission

Freeze product behavior while cleaning core seams so the base Zig product is
stable, reviewable, and ready for the next expansion phase.

## Current State

- Android lane is intentionally paused except blocker regressions.
- Core lane is now primary.
- Current active macro batch: `CZH-B4` (`in_progress`).

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
- `Verdict: accepted`
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
- `Verdict: architect_review_pending`
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
- `src/terminal/ffi/bridge.zig`, `core_api.zig`, `host_api.zig`, `c_api.zig` — host API surface
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

### `CZH-B4` Stability Baseline Closure: `test-editor` Module Path Lane (`in_progress`)

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

## Response Contract

Every batch update must include:

- `LABELS`
- `#DONE`
- `#OUTSTANDING`
- `COMMITS`
- `VALIDATION`
- `Blocked by Archtect review needed: true|false` (Engineer)
- `Blocked by humain review needed: true|false` (Architect)

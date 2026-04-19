# Core Zig Stability/Hygiene Queue

Active queue for the post-Android-pause core cleanup lane.

## Mission

Freeze product behavior while cleaning core seams so the base Zig product is
stable, reviewable, and ready for the next expansion phase.

## Current State

- Android lane is intentionally paused except blocker regressions.
- Core lane is now primary.
- Current active macro batch: `CZH-B6` (`in_progress`).
- Sprint authority: `docs/todo/core/JIRA_BOARD.md`
- Active ticket source: `docs/todo/core/CZH_B6_TICKETS.md`

## Campaign Goals

1. freeze the shared host/core/editor/surface split before further cleanup
2. keep stability first: user stress tests stay green while architecture work lands
3. enforce probe/debug hygiene on main branch product paths
4. remove compatibility/fallback/legacy preservation leftovers instead of carrying them forward
5. scrutinize doc strings and locked-down function docs for alignment with real ownership and behavior
6. normalize Android-driven FFI/rendering advancements into shared core seams only after the split is explicit

## Hard Contracts

- Behavior freeze by default during hygiene cuts.
- No compatibility sludge.
- No stale debug/probe caller residue in tracked product code.
- No compatibility shims, migration surfaces, or preservation-only fallbacks kept "just in case".
- Every file in the touched layer set must have a doc string; important/locked-down functions must be audited for whether their doc strings help, hurt, or lie about current responsibility.
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

### `CZH-B6` Layer Freeze: VT Core FFI / Optional PTY Host / Editor FFI / Terminal Surface (`in_progress`)

Queue line (exact):

- flatten the Zig-side focus around one explicit host/core split: freeze the
  VT core FFI, optional bring-your-own-PTY host seam, editor backend FFI, and
  host-initialized terminal surface contract before more cleanup or extraction

Objective:

- turn the current broad "cleanup" lane into a small number of explicit layer
  contracts that the engineer can execute against without drifting

**Four target layers (name consistently everywhere):**

1. VT core FFI
2. optional bring-your-own-PTY host seam
3. editor backend FFI
4. terminal surface contract (host passes shared GPU resource/surface; Zide
   owns dirty tracking/update logic; host owns binding/presentation)

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
  closely coupled session/runtime modules called from `host_api` / `core_api`.
- **Outcome:** file-by-file classification into VT core FFI, optional
  bring-your-own-PTY host seam, bridge/facade glue, and explicit smell notes for
  post-freeze extraction.

#### `CZH-603` editor backend FFI authority (recorded)

- **Authority:** `app_architecture/editor/FFI_DESIGN.md` (freeze section +
  routing/versioning notes).
- **Outcome:** editor FFI scoped as the **editor backend** export for foreign
  hosts; native app remains direct-to-core; platform routing and future JNI-style
  glue stay host-owned and trace this doc.

## Response Contract

Every batch update must include:

- `LABELS`
- `#DONE`
- `#OUTSTANDING`
- `COMMITS`
- `VALIDATION`
- `Blocked by Archtect review needed: true|false` (Engineer)
- `Blocked by humain review needed: true|false` (Architect)

# Editor Stress Ritual 2026-03-18

## Purpose

Define the first repeatable local stress ritual for Zide's editor subsystem so
pressure testing is comparable across runs and produces documentation-quality
evidence.

This is not the final benchmark system. It is the first stable ritual that:

- uses existing repo seams
- exercises the editor pipeline beyond trivial files
- produces output that can be written back into architecture docs and queue
  updates

## Authority And Boundaries

This doc owns:

- the first local workload set
- the exact first-pass commands
- what to record during a pass

It does not own:

- editor architecture authority
- long-term perf thresholds
- product-facing claims

Those live in:

- `app_architecture/editor/DESIGN.md`
- `docs/todo/editor/stress_and_reference.md`

## First-Pass Workload Set

### H1. Synthetic large-file headless workloads

Use the built-in synthetic fixture path in `perf-editor-headless` for size-class
coverage without depending on external files.

Exact classes:

- `1 MiB` synthetic text fixture
- `8 MiB` synthetic text fixture
- `32 MiB` synthetic text fixture

Why:

- deterministic and local
- exercises open path, line-start lookup path, viewport pass, and editor scroll
- avoids unstable dependency on external repo files for the first pass

### H2. Syntax-heavy real fixture

Use:

- `fixtures/editor/stress/large_highlight_sample.zig`

Current size:

- about `3.1 MiB`

Why:

- real Zig/token/query-heavy content
- useful for highlight/search/render churn checks
- already lives under the repo fixture policy

### M1. Native interactive editor pass

Use the same syntax-heavy fixture for the first manual run:

- `fixtures/editor/stress/large_highlight_sample.zig`

Why:

- keeps the first interactive pass aligned with the first real-file headless
  workload
- avoids mixing many workload variables before the ritual itself is stable

## Build And Run Mode

Use release-fast local builds for the first pass.

Headless harness:

```sh
zig build -Doptimize=ReleaseFast perf-editor-headless
```

Native editor build:

```sh
zig build -Dmode=editor -Doptimize=ReleaseFast
```

Do not use debug builds as the primary authority for this ritual.

## Exact First-Pass Commands

### 1. Synthetic size sweep

Run all four headless metrics for each size class:

```sh
zig build -Doptimize=ReleaseFast perf-editor-headless -- \
  --scenario all \
  --size-mb 1 \
  --queries 10000 \
  --frames 240 \
  --visible-lines 80 \
  --stride-lines 3 \
  --seed 682034097421
```

```sh
zig build -Doptimize=ReleaseFast perf-editor-headless -- \
  --scenario all \
  --size-mb 8 \
  --queries 10000 \
  --frames 240 \
  --visible-lines 80 \
  --stride-lines 3 \
  --seed 682034097421
```

```sh
zig build -Doptimize=ReleaseFast perf-editor-headless -- \
  --scenario all \
  --size-mb 32 \
  --queries 10000 \
  --frames 240 \
  --visible-lines 80 \
  --stride-lines 3 \
  --seed 682034097421
```

### 2. Syntax-heavy real-file headless pass

```sh
zig build -Doptimize=ReleaseFast perf-editor-headless -- \
  --scenario all \
  --file fixtures/editor/stress/large_highlight_sample.zig \
  --queries 10000 \
  --frames 240 \
  --visible-lines 80 \
  --stride-lines 3 \
  --seed 682034097421
```

### 3. Native interactive pass

```sh
./zig-out/bin/zide-editor fixtures/editor/stress/large_highlight_sample.zig
```

During the interactive pass, check:

- first-open feel and obvious stall points
- immediate page-up/page-down and wheel scroll behavior
- `Ctrl+F` search prompt responsiveness while changing the query
- `Ctrl+D`, `Ctrl+Shift+K`, `Tab`, and `Shift+Tab` behavior near the start,
  middle, and end of the file
- redraw correctness after repeated edits and scrolls

## What To Record

### Headless metrics

For each run, record:

- `PERF open`
- `PERF line_start_random`
- `PERF line_start_sequential`
- `PERF viewport`
- `PERF editor_scroll`

Preserve the printed `PERF meta` line as well so file size and parameters stay
attached to the result.

### Interactive observations

Record concise observations for:

- first paint / initial stall feel
- visible redraw glitches, if any
- search/highlight stability during query churn
- edit-to-render coherence after line operations
- any mixed input-routing oddities

Do not write vague notes like "felt slow". Prefer short factual statements such
as:

- "first open visibly stalled before first paint for about one second"
- "page-down remained smooth with no stale background rows"
- "search result highlight count lagged one query behind after rapid typing"

## Result Location

Write each serious pass to:

- `docs/research/editor/EDITOR_STRESS_RESULTS_<date>.md`

Minimum structure:

1. build + machine context
2. exact commands used
3. headless metric table
4. interactive observations
5. immediate architectural implications
6. next concrete actions

## Current Cautions

### 1. `perf_editor_gate.sh` now mirrors the first-pass workload set

`tools/perf_editor_gate.sh` now runs:

- synthetic `1 MiB`
- synthetic `8 MiB`
- synthetic `32 MiB`
- `fixtures/editor/stress/large_highlight_sample.zig`

Treat it as a repeatable local gate for the current first-pass ritual, not as a
final benchmark authority.

### 2. Start with one real syntax-heavy fixture before broadening

The first pass should stabilize the ritual on one real file before adding more
languages or long-line/Unicode-specific fixtures.

### 3. Manual stress is still required

The headless harness covers important cost centers, but it does not replace the
native interactive checks that exercise input routing, redraw behavior, and
prompt-driven editing flow.

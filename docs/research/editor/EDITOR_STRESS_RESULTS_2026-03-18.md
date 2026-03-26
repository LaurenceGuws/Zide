# Editor Stress Results 2026-03-18

## Purpose

Record the first real run of the editor stress ritual defined in:

- `docs/research/editor/EDITOR_STRESS_RITUAL_2026-03-18.md`

This pass is intentionally narrow:

- headless synthetic size sweep
- headless syntax-heavy real-file pass
- headless long-line and Unicode real-file pass
- native release build validation

The fully interactive native run is still pending manual observation.

## Build And Machine Context

Build mode used:

- `ReleaseFast`

Commands validated in this pass:

- `zig build -Doptimize=ReleaseFast perf-editor-headless`
- `zig build -Dmode=editor -Doptimize=ReleaseFast`

Immediate build-graph finding:

- the documented `perf-editor-headless` ritual was initially broken because the
  target was not receiving the `zlua` module import used by the config layer
- this pass included a build-graph fix so the perf target now follows the same
  configured-module path as the app targets

## Exact Commands Used

Synthetic size sweep:

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

Real syntax-heavy fixture:

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

Long-line and Unicode fixture:

```sh
zig build -Doptimize=ReleaseFast perf-editor-headless -- \
  --scenario all \
  --file fixtures/editor/stress/unicode_longline_sample.txt \
  --queries 10000 \
  --frames 240 \
  --visible-lines 80 \
  --stride-lines 3 \
  --seed 682034097421
```

Native editor build validation:

```sh
zig build -Dmode=editor -Doptimize=ReleaseFast
```

## Headless Metric Table

### Synthetic fixtures

| Workload | Size bytes | Open ms | Random line-start ns/op | Sequential line-start ns/op | Viewport ms/frame | Editor scroll ms/frame |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| synthetic `1 MiB` | 1,048,576 | 0.597 | 244.5 | 178.7 | 0.0034 | 0.0048 |
| synthetic `8 MiB` | 8,388,608 | 3.774 | 687.8 | 538.7 | 0.0056 | 0.0051 |
| synthetic `32 MiB` | 33,554,432 | 4.644 | 890.6 | 546.3 | 0.0061 | 0.0056 |

### Syntax-heavy real fixture

| Workload | Size bytes | Open ms | Random line-start ns/op | Sequential line-start ns/op | Viewport ms/frame | Editor scroll ms/frame |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `large_highlight_sample.zig` | 3,145,763 | 1.547 | 363.2 | 285.8 | 0.0046 | 0.0048 |
| `unicode_longline_sample.txt` | 8,710 | 0.093 | 16.4 | 5.1 | 0.0001 | 0.0019 |

## Raw Perf Output

### Synthetic `1 MiB`

```text
PERF meta path="zig-cache/editor-perf/synth_1mb_l120.txt" size_bytes=1048576 scenario=all queries=10000 frames=240 visible_lines=80 stride_lines=3
PERF open open_ms=0.597 total_len=1048576 line_count=8739 rss_before_kb=1848 rss_after_open_kb=3156 rss_after_close_kb=1988
PERF line_start_random queries=10000 total_ms=2.445 ns_per_op=244.5 checksum=5335217160
PERF line_start_sequential queries=10000 total_ms=1.787 ns_per_op=178.7 checksum=4677014520
PERF viewport frames=240 visible_lines=80 total_ms=0.824 ms_per_frame=0.0034 bytes_read=2284800 checksum=919276800
PERF editor_scroll frames=240 visible_lines=80 total_ms=1.143 ms_per_frame=0.0048 bytes_read=2284800 checksum=370924800
```

### Synthetic `8 MiB`

```text
PERF meta path="zig-cache/editor-perf/synth_8mb_l120.txt" size_bytes=8388608 scenario=all queries=10000 frames=240 visible_lines=80 stride_lines=3
PERF open open_ms=3.774 total_len=8388608 line_count=69906 rss_before_kb=1828 rss_after_open_kb=10684 rss_after_close_kb=1964
PERF line_start_random queries=10000 total_ms=6.878 ns_per_op=687.8 checksum=42682292040
PERF line_start_sequential queries=10000 total_ms=5.387 ns_per_op=538.7 checksum=5999400000
PERF viewport frames=240 visible_lines=80 total_ms=1.341 ms_per_frame=0.0056 bytes_read=2284800 checksum=919276800
PERF editor_scroll frames=240 visible_lines=80 total_ms=1.227 ms_per_frame=0.0051 bytes_read=2284800 checksum=370924800
```

### Synthetic `32 MiB`

```text
PERF meta path="zig-cache/editor-perf/synth_32mb_l120.txt" size_bytes=33554432 scenario=all queries=10000 frames=240 visible_lines=80 stride_lines=3
PERF open open_ms=4.644 total_len=33554432 line_count=279621 rss_before_kb=1760 rss_after_open_kb=36728 rss_after_close_kb=1896
PERF line_start_random queries=10000 total_ms=8.906 ns_per_op=890.6 checksum=170729135040
PERF line_start_sequential queries=10000 total_ms=5.463 ns_per_op=546.3 checksum=5999400000
PERF viewport frames=240 visible_lines=80 total_ms=1.468 ms_per_frame=0.0061 bytes_read=2284800 checksum=919276800
PERF editor_scroll frames=240 visible_lines=80 total_ms=1.346 ms_per_frame=0.0056 bytes_read=2284800 checksum=370924800
```

### `large_highlight_sample.zig`

```text
PERF meta path="fixtures/editor/stress/large_highlight_sample.zig" size_bytes=3145763 scenario=all queries=10000 frames=240 visible_lines=80 stride_lines=3
PERF open open_ms=1.547 total_len=3145763 line_count=39609 rss_before_kb=1768 rss_after_open_kb=5384 rss_after_close_kb=1908
PERF line_start_random queries=10000 total_ms=3.632 ns_per_op=363.2 checksum=15921992746
PERF line_start_sequential queries=10000 total_ms=2.858 ns_per_op=285.8 checksum=3876040686
PERF viewport frames=240 visible_lines=80 total_ms=1.094 ms_per_frame=0.0046 bytes_read=1436161 checksum=573669953
PERF editor_scroll frames=240 visible_lines=80 total_ms=1.156 ms_per_frame=0.0048 bytes_read=1429337 checksum=226613888
```

### `unicode_longline_sample.txt`

```text
PERF meta path="fixtures/editor/stress/unicode_longline_sample.txt" size_bytes=8710 scenario=all queries=10000 frames=240 visible_lines=80 stride_lines=3
PERF open open_ms=0.093 total_len=8710 line_count=33 rss_before_kb=1752 rss_after_open_kb=1852 rss_after_close_kb=1820
PERF line_start_random queries=10000 total_ms=0.164 ns_per_op=16.4 checksum=44479241
PERF line_start_sequential queries=10000 total_ms=0.051 ns_per_op=5.1 checksum=43643211
PERF viewport frames=240 visible_lines=80 total_ms=0.020 ms_per_frame=0.0001 bytes_read=50411 checksum=3192838
PERF editor_scroll frames=240 visible_lines=80 total_ms=0.449 ms_per_frame=0.0019 bytes_read=2079600 checksum=36399840
```

## Interactive Observations

This pass did not include direct interactive runtime observations.

What was validated instead:

- the native editor release build succeeds
- the headless perf harness now builds and runs with the same config-module
  dependency path as the main app targets

Manual interactive checks still required:

- first-open stall feel on the real widget/runtime path
- redraw correctness during search churn
- edit-to-render coherence after repeated line operations
- cursor and selection behavior on long rows with Unicode-heavy content
- mixed host-routing behavior during active edits

## Immediate Architectural Implications

### 1. The first useful stress seam already existed

The combination of `perf-editor-headless` and a native release editor build is a
good first measurement baseline.

We did not need a bigger runtime CLI before getting useful data.

### 2. The headless harness was a build-graph citizen problem, not a perf problem

The first ritual immediately found build-graph drift:

- app-facing config code assumes the `zlua` module import exists
- the perf target had drifted away from that configured target path

That is exactly the kind of engineering issue a repeatable ritual should expose
early.

### 3. Current line-start and viewport numbers look healthy enough to justify deeper runtime checks

Nothing in this first pass suggests an obvious catastrophic cost center in:

- open path
- line-start lookup path
- viewport pass
- editor-scroll pass

That shifts the next highest-value investigation toward:

- real widget/runtime interaction cost
- redraw/cache behavior under edit/search churn
- long-line and Unicode cursor/selection correctness
- render-path clarity in the architecture docs

## Next Concrete Actions

1. Run the pending native interactive pass from the ritual and capture factual
   observations for first paint, scroll, search churn, edit-to-render
   coherence, and long-line/Unicode cursor behavior.
2. Update `tools/perf/perf_editor_gate.sh` to use the current stress authority once
   the ritual is trusted enough to freeze those workloads.
   - Completed after this first pass:
     - the gate now mirrors synthetic `1/8/32 MiB` plus
       `large_highlight_sample.zig` and `unicode_longline_sample.txt`
3. Add one focused render/cache research note if the interactive pass reveals a
   mismatch between headless cost and on-screen behavior.

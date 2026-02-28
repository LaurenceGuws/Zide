#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

OPTIMIZE="${ZIDE_PERF_GATE_OPTIMIZE:-ReleaseFast}"
QUERIES="${ZIDE_PERF_GATE_QUERIES:-10000}"
FRAMES="${ZIDE_PERF_GATE_FRAMES:-120}"
VISIBLE_LINES="${ZIDE_PERF_GATE_VISIBLE_LINES:-80}"

MAX_OPEN_MS="${ZIDE_PERF_GATE_MAX_OPEN_MS:-80}"
MAX_LINE_RANDOM_NS="${ZIDE_PERF_GATE_MAX_LINE_RANDOM_NS:-5000}"
MAX_EDITOR_SCROLL_MS_FRAME="${ZIDE_PERF_GATE_MAX_EDITOR_SCROLL_MS_FRAME:-0.05}"

fixtures=(
  "fixtures/editor/stress/bash_fluff_1100k.sh"
  "fixtures/editor/stress/go_fluff_1200k.go"
  "fixtures/editor/stress/python_fluff_1300k.py"
  "fixtures/editor/stress/java_fluff_1400k.java"
)

float_gt() {
  awk -v a="$1" -v b="$2" 'BEGIN { exit !(a > b) }'
}

extract_metric() {
  local line="$1"
  local key="$2"
  awk -v key="$key" '
    {
      for (i = 1; i <= NF; i++) {
        if ($i ~ ("^" key "=")) {
          split($i, kv, "=");
          print kv[2];
          exit 0;
        }
      }
    }
  ' <<< "$line"
}

failed=0

echo "[perf-gate] optimize=$OPTIMIZE queries=$QUERIES frames=$FRAMES visible_lines=$VISIBLE_LINES"
echo "[perf-gate] thresholds: open_ms<=$MAX_OPEN_MS line_start_random_ns<=$MAX_LINE_RANDOM_NS editor_scroll_ms_frame<=$MAX_EDITOR_SCROLL_MS_FRAME"

for fixture in "${fixtures[@]}"; do
  if [[ ! -f "$fixture" ]]; then
    echo "[perf-gate] missing fixture: $fixture" >&2
    failed=1
    continue
  fi

  echo "[perf-gate] running $fixture"
  out="$(zig build -Doptimize="$OPTIMIZE" perf-editor-headless -- --scenario all --file "$fixture" --queries "$QUERIES" --frames "$FRAMES" --visible-lines "$VISIBLE_LINES" 2>&1)"
  echo "$out"

  open_line="$(awk '/PERF open /{print; exit}' <<< "$out")"
  random_line="$(awk '/PERF line_start_random /{print; exit}' <<< "$out")"
  scroll_line="$(awk '/PERF editor_scroll /{print; exit}' <<< "$out")"

  if [[ -z "$open_line" || -z "$random_line" || -z "$scroll_line" ]]; then
    echo "[perf-gate] missing metrics for $fixture" >&2
    failed=1
    continue
  fi

  open_ms="$(extract_metric "$open_line" "open_ms")"
  random_ns="$(extract_metric "$random_line" "ns_per_op")"
  scroll_ms_frame="$(extract_metric "$scroll_line" "ms_per_frame")"

  if float_gt "$open_ms" "$MAX_OPEN_MS"; then
    echo "[perf-gate] FAIL $fixture open_ms=$open_ms > $MAX_OPEN_MS" >&2
    failed=1
  fi
  if float_gt "$random_ns" "$MAX_LINE_RANDOM_NS"; then
    echo "[perf-gate] FAIL $fixture line_start_random_ns=$random_ns > $MAX_LINE_RANDOM_NS" >&2
    failed=1
  fi
  if float_gt "$scroll_ms_frame" "$MAX_EDITOR_SCROLL_MS_FRAME"; then
    echo "[perf-gate] FAIL $fixture editor_scroll_ms_frame=$scroll_ms_frame > $MAX_EDITOR_SCROLL_MS_FRAME" >&2
    failed=1
  fi
done

if [[ "$failed" -ne 0 ]]; then
  echo "[perf-gate] FAILED"
  exit 1
fi

echo "[perf-gate] PASSED"

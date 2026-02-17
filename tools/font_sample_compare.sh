#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ $# -gt 0 ]]; then
  SIZES=("$@")
else
  SIZES=(12 14 16 20)
fi

OUT_DIR="$ROOT_DIR/zig-cache/font_sample_compare"
mkdir -p "$OUT_DIR"

FRAMES="${ZIDE_FONT_SAMPLE_FRAMES:-2}"
MISMATCH=0

for size in "${SIZES[@]}"; do
  fixture="fixtures/ui/font_sample/jbmono_iosevka_size${size}.ppm"
  output="${OUT_DIR}/size${size}.ppm"

  if [[ ! -f "$fixture" ]]; then
    echo "missing fixture: $fixture"
    MISMATCH=1
    continue
  fi

  echo "capturing size ${size}..."
  ZIDE_FONT_SAMPLE_SIZE="${size}" \
  ZIDE_FONT_SAMPLE_FRAMES="${FRAMES}" \
  ZIDE_FONT_SAMPLE_SCREENSHOT="${output}" \
  zig build run -- --mode font-sample >/dev/null

  if cmp -s "$fixture" "$output"; then
    echo "match: ${fixture}"
  else
    echo "mismatch: ${fixture} vs ${output}"
    MISMATCH=1
  fi
done

if [[ "$MISMATCH" -ne 0 ]]; then
  echo "font sample compare failed"
  exit 1
fi

echo "font sample compare passed"

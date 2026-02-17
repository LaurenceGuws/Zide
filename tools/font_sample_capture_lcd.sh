#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ $# -gt 0 ]]; then
  SIZES=("$@")
else
  SIZES=(12 14 16 20)
fi

OUT_DIR="$ROOT_DIR/zig-cache/font_sample_lcd"
mkdir -p "$OUT_DIR"

FRAMES="${ZIDE_FONT_SAMPLE_FRAMES:-2}"

for size in "${SIZES[@]}"; do
  output="${OUT_DIR}/jbmono_iosevka_lcd_size${size}.ppm"
  echo "capturing lcd-on size ${size} -> ${output}"
  ZIDE_FONT_RENDERING_LCD=1 \
  ZIDE_FONT_SAMPLE_SIZE="${size}" \
  ZIDE_FONT_SAMPLE_FRAMES="${FRAMES}" \
  ZIDE_FONT_SAMPLE_SCREENSHOT="${output}" \
  zig build run -- --mode font-sample >/dev/null
done

echo "lcd captures written to ${OUT_DIR}"

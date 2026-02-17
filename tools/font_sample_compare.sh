#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

UPDATE_FIXTURES=0
SIZES=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --update-fixtures)
      UPDATE_FIXTURES=1
      shift
      ;;
    --help|-h)
      echo "usage: tools/font_sample_compare.sh [--update-fixtures] [size ...]"
      exit 0
      ;;
    *)
      SIZES+=("$1")
      shift
      ;;
  esac
done

if [[ ${#SIZES[@]} -eq 0 ]]; then
  SIZES=(12 14 16 20)
fi

OUT_DIR="$ROOT_DIR/zig-cache/font_sample_compare"
mkdir -p "$OUT_DIR"

FRAMES="${ZIDE_FONT_SAMPLE_FRAMES:-2}"
MISMATCH=0

checksum_file() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
    return
  fi
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
    return
  fi
  echo "unavailable"
}

for size in "${SIZES[@]}"; do
  fixture="fixtures/ui/font_sample/jbmono_iosevka_size${size}.ppm"
  output="${OUT_DIR}/size${size}.ppm"

  echo "capturing size ${size}..."
  ZIDE_FONT_SAMPLE_SIZE="${size}" \
  ZIDE_FONT_SAMPLE_FRAMES="${FRAMES}" \
  ZIDE_FONT_SAMPLE_SCREENSHOT="${output}" \
  zig build run -- --mode font-sample >/dev/null

  if [[ ! -f "$fixture" ]]; then
    if [[ "$UPDATE_FIXTURES" -eq 1 ]]; then
      cp "$output" "$fixture"
      echo "created fixture: ${fixture}"
      continue
    fi
    echo "missing fixture: $fixture"
    MISMATCH=1
    continue
  fi

  if cmp -s "$fixture" "$output"; then
    echo "match: ${fixture}"
  else
    if [[ "$UPDATE_FIXTURES" -eq 1 ]]; then
      cp "$output" "$fixture"
      echo "updated fixture: ${fixture}"
      continue
    fi
    echo "mismatch: ${fixture} vs ${output}"
    first_diff="$(cmp -l "$fixture" "$output" | head -n1 || true)"
    if [[ -n "$first_diff" ]]; then
      echo "  first byte diff: ${first_diff}"
    fi
    fixture_sum="$(checksum_file "$fixture")"
    output_sum="$(checksum_file "$output")"
    echo "  fixture sha256: ${fixture_sum}"
    echo "  output  sha256: ${output_sum}"
    MISMATCH=1
  fi
done

if [[ "$MISMATCH" -ne 0 ]]; then
  echo "font sample compare failed"
  exit 1
fi

if [[ "$UPDATE_FIXTURES" -eq 1 ]]; then
  echo "font sample fixture refresh passed"
else
  echo "font sample compare passed"
fi

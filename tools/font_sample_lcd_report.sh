#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CSV_MODE=0
SIZES=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --csv)
      CSV_MODE=1
      shift
      ;;
    --help|-h)
      echo "usage: tools/font_sample_lcd_report.sh [--csv] [size ...]"
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

if [[ "$CSV_MODE" -eq 1 ]]; then
  echo "size,equal,default_sha256,lcd_sha256"
else
  echo "font sample lcd report"
  echo
  echo "size | equal | default_sha256 | lcd_sha256"
  echo "-----|-------|----------------|----------"
fi

for size in "${SIZES[@]}"; do
  default_file="fixtures/ui/font_sample/jbmono_iosevka_size${size}.ppm"
  lcd_file="zig-cache/font_sample_lcd/jbmono_iosevka_lcd_size${size}.ppm"
  if [[ ! -f "$default_file" || ! -f "$lcd_file" ]]; then
    if [[ "$CSV_MODE" -eq 1 ]]; then
      echo "${size},n/a,missing,missing"
    else
      echo "${size} | n/a | missing | missing"
    fi
    continue
  fi
  if cmp -s "$default_file" "$lcd_file"; then
    equal="yes"
  else
    equal="no"
  fi
  default_sum="$(checksum_file "$default_file")"
  lcd_sum="$(checksum_file "$lcd_file")"
  if [[ "$CSV_MODE" -eq 1 ]]; then
    echo "${size},${equal},${default_sum},${lcd_sum}"
  else
    echo "${size} | ${equal} | ${default_sum} | ${lcd_sum}"
  fi
done

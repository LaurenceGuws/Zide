#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CSV_MODE=0
JSON_MODE=0
SIZES=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --csv)
      CSV_MODE=1
      shift
      ;;
    --json)
      JSON_MODE=1
      shift
      ;;
    --help|-h)
      echo "usage: tools/font_sample_lcd_report.sh [--csv|--json] [size ...]"
      exit 0
      ;;
    *)
      SIZES+=("$1")
      shift
      ;;
  esac
done

if [[ "$CSV_MODE" -eq 1 && "$JSON_MODE" -eq 1 ]]; then
  echo "error: use only one of --csv or --json" >&2
  exit 2
fi

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
elif [[ "$JSON_MODE" -eq 1 ]]; then
  echo "["
else
  echo "font sample lcd report"
  echo
  echo "size | equal | default_sha256 | lcd_sha256"
  echo "-----|-------|----------------|----------"
fi

emitted_json=0
for size in "${SIZES[@]}"; do
  default_file="fixtures/ui/font_sample/jbmono_iosevka_size${size}.ppm"
  lcd_file="zig-cache/font_sample_lcd/jbmono_iosevka_lcd_size${size}.ppm"
  equal="n/a"
  default_sum="missing"
  lcd_sum="missing"

  if [[ ! -f "$default_file" || ! -f "$lcd_file" ]]; then
    :
  else
    if cmp -s "$default_file" "$lcd_file"; then
      equal="yes"
    else
      equal="no"
    fi
    default_sum="$(checksum_file "$default_file")"
    lcd_sum="$(checksum_file "$lcd_file")"
  fi

  if [[ "$CSV_MODE" -eq 1 ]]; then
    echo "${size},${equal},${default_sum},${lcd_sum}"
  elif [[ "$JSON_MODE" -eq 1 ]]; then
    if [[ "$emitted_json" -eq 1 ]]; then
      echo ","
    fi
    printf '  {"size":%s,"equal":"%s","default_sha256":"%s","lcd_sha256":"%s"}' "${size}" "${equal}" "${default_sum}" "${lcd_sum}"
    emitted_json=1
  else
    echo "${size} | ${equal} | ${default_sum} | ${lcd_sum}"
  fi
done

if [[ "$JSON_MODE" -eq 1 ]]; then
  echo
  echo "]"
fi

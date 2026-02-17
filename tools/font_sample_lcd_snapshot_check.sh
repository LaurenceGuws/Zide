#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BASE_DIR="app_architecture/ui/font_sample_lcd_snapshots"
if [[ ! -d "$BASE_DIR" ]]; then
  echo "missing snapshot base dir: $BASE_DIR"
  exit 1
fi

required=(
  "lcd_report.txt"
  "lcd_report.csv"
  "lcd_report.json"
  "ppm_validate.txt"
  "README.txt"
)

FAILED=0
found_any=0
while IFS= read -r dir; do
  found_any=1
  stamp="$(basename "$dir")"
  for f in "${required[@]}"; do
    path="${dir}/${f}"
    if [[ ! -f "$path" ]]; then
      echo "missing: ${path}"
      FAILED=1
    fi
  done
  if [[ "$FAILED" -eq 0 ]]; then
    echo "ok: ${stamp}"
  fi
done < <(find "$BASE_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

if [[ "$found_any" -eq 0 ]]; then
  echo "no snapshot folders found under $BASE_DIR"
  exit 1
fi

if [[ "$FAILED" -ne 0 ]]; then
  echo "snapshot integrity check failed"
  exit 1
fi

echo "snapshot integrity check passed"

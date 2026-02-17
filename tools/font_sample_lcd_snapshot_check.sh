#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

LATEST_ONLY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --latest)
      LATEST_ONLY=1
      shift
      ;;
    --help|-h)
      echo "usage: tools/font_sample_lcd_snapshot_check.sh [--latest]"
      exit 0
      ;;
    *)
      echo "error: unexpected argument: $1" >&2
      exit 2
      ;;
  esac
done

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
if [[ "$LATEST_ONLY" -eq 1 ]]; then
  latest_dir="$(find "$BASE_DIR" -mindepth 1 -maxdepth 1 -type d | sort | tail -n1)"
  if [[ -z "${latest_dir:-}" ]]; then
    echo "no snapshot folders found under $BASE_DIR"
    exit 1
  fi
  dir_list=("$latest_dir")
else
  mapfile -t dir_list < <(find "$BASE_DIR" -mindepth 1 -maxdepth 1 -type d | sort)
fi

for dir in "${dir_list[@]}"; do
  found_any=1
  stamp="$(basename "$dir")"
  snapshot_failed=0
  for f in "${required[@]}"; do
    path="${dir}/${f}"
    if [[ ! -f "$path" ]]; then
      echo "missing: ${path}"
      FAILED=1
      snapshot_failed=1
    fi
  done
  if [[ "$snapshot_failed" -eq 0 ]]; then
    echo "ok: ${stamp}"
  fi
done

if [[ "$found_any" -eq 0 ]]; then
  echo "no snapshot folders found under $BASE_DIR"
  exit 1
fi

if [[ "$FAILED" -ne 0 ]]; then
  echo "snapshot integrity check failed"
  exit 1
fi

echo "snapshot integrity check passed"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

STAMP=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --stamp)
      if [[ $# -lt 2 ]]; then
        echo "error: --stamp requires a value" >&2
        exit 2
      fi
      STAMP="$2"
      shift 2
      ;;
    --help|-h)
      echo "usage: tools/font_sample_lcd_snapshot.sh [--stamp YYYY-MM-DD] [stamp]"
      exit 0
      ;;
    *)
      if [[ -z "$STAMP" ]]; then
        STAMP="$1"
      else
        echo "error: unexpected argument: $1" >&2
        exit 2
      fi
      shift
      ;;
  esac
done

if [[ -z "$STAMP" ]]; then
  STAMP="$(date +%F)"
fi

SNAP_DIR="app_architecture/ui/font_sample_lcd_snapshots/${STAMP}"
mkdir -p "${SNAP_DIR}"

echo "capturing LCD fixtures..."
tools/font_sample_capture_lcd.sh

echo "writing reports..."
tools/font_sample_lcd_report.sh > "${SNAP_DIR}/lcd_report.txt"
tools/font_sample_lcd_report.sh --csv > "${SNAP_DIR}/lcd_report.csv"
tools/font_sample_lcd_report.sh --json > "${SNAP_DIR}/lcd_report.json"

echo "validating default fixture PPMs..."
tools/font_sample_validate_ppm.sh > "${SNAP_DIR}/ppm_validate.txt"

{
  echo "stamp=${STAMP}"
  echo "created_at_utc=$(date -u +%FT%TZ)"
  echo "command=tools/font_sample_lcd_snapshot.sh ${STAMP}"
  echo "artifacts="
  echo "  - ${SNAP_DIR}/lcd_report.txt"
  echo "  - ${SNAP_DIR}/lcd_report.csv"
  echo "  - ${SNAP_DIR}/lcd_report.json"
  echo "  - ${SNAP_DIR}/ppm_validate.txt"
} > "${SNAP_DIR}/README.txt"

echo "snapshot written to ${SNAP_DIR}"

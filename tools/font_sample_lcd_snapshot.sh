#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

STAMP="${1:-$(date +%F)}"
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

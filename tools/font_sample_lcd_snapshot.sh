#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

STAMP=""
DRY_RUN=0
NO_CAPTURE=0
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
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --no-capture)
      NO_CAPTURE=1
      shift
      ;;
    --help|-h)
      echo "usage: tools/font_sample_lcd_snapshot.sh [--stamp YYYY-MM-DD] [--dry-run] [--no-capture] [stamp]"
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

checksum_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "missing"
    return
  fi
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

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "dry-run: no files will be written"
  echo "snapshot dir: ${SNAP_DIR}"
  if [[ "$NO_CAPTURE" -eq 1 ]]; then
    echo "would skip capture step (--no-capture)"
  else
    echo "would run: tools/font_sample_capture_lcd.sh"
  fi
  echo "would write:"
  echo "  - ${SNAP_DIR}/lcd_report.txt"
  echo "  - ${SNAP_DIR}/lcd_report.csv"
  echo "  - ${SNAP_DIR}/lcd_report.json"
  echo "  - ${SNAP_DIR}/ppm_validate.txt"
  echo "  - ${SNAP_DIR}/README.txt"
  exit 0
fi

mkdir -p "${SNAP_DIR}"

if [[ "$NO_CAPTURE" -eq 1 ]]; then
  echo "skipping capture step (--no-capture)"
else
  echo "capturing LCD fixtures..."
  tools/font_sample_capture_lcd.sh
fi

echo "writing reports..."
tools/font_sample_lcd_report.sh > "${SNAP_DIR}/lcd_report.txt"
tools/font_sample_lcd_report.sh --csv > "${SNAP_DIR}/lcd_report.csv"
tools/font_sample_lcd_report.sh --json > "${SNAP_DIR}/lcd_report.json"

echo "validating default fixture PPMs..."
tools/font_sample_validate_ppm.sh > "${SNAP_DIR}/ppm_validate.txt"

host_name="$(hostname 2>/dev/null || echo unknown)"
renderer_backend="sdl_gl"
font_config_digest="$(checksum_file assets/config/init.lua)"
project_config_digest="$(checksum_file .zide.lua)"

command_line="tools/font_sample_lcd_snapshot.sh --stamp ${STAMP}"
if [[ "$NO_CAPTURE" -eq 1 ]]; then
  command_line="${command_line} --no-capture"
fi

{
  echo "stamp=${STAMP}"
  echo "created_at_utc=$(date -u +%FT%TZ)"
  echo "host=${host_name}"
  echo "renderer_backend=${renderer_backend}"
  echo "font_config_digest=${font_config_digest}"
  echo "project_config_digest=${project_config_digest}"
  echo "command=${command_line}"
  echo "artifacts="
  echo "  - ${SNAP_DIR}/lcd_report.txt"
  echo "  - ${SNAP_DIR}/lcd_report.csv"
  echo "  - ${SNAP_DIR}/lcd_report.json"
  echo "  - ${SNAP_DIR}/ppm_validate.txt"
} > "${SNAP_DIR}/README.txt"

echo "snapshot written to ${SNAP_DIR}"

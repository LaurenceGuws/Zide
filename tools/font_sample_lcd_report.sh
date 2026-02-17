#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ $# -gt 0 ]]; then
  SIZES=("$@")
else
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

echo "font sample lcd report"
echo
echo "size | equal | default_sha256 | lcd_sha256"
echo "-----|-------|----------------|----------"

for size in "${SIZES[@]}"; do
  default_file="fixtures/ui/font_sample/jbmono_iosevka_size${size}.ppm"
  lcd_file="zig-cache/font_sample_lcd/jbmono_iosevka_lcd_size${size}.ppm"
  if [[ ! -f "$default_file" || ! -f "$lcd_file" ]]; then
    echo "${size} | n/a | missing | missing"
    continue
  fi
  if cmp -s "$default_file" "$lcd_file"; then
    equal="yes"
  else
    equal="no"
  fi
  default_sum="$(checksum_file "$default_file")"
  lcd_sum="$(checksum_file "$lcd_file")"
  echo "${size} | ${equal} | ${default_sum} | ${lcd_sum}"
done

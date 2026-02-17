#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ $# -gt 0 ]]; then
  FILES=("$@")
else
  mapfile -t FILES < <(ls fixtures/ui/font_sample/*.ppm 2>/dev/null || true)
fi

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "no ppm files found"
  exit 1
fi

FAILED=0
for file in "${FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "missing: $file"
    FAILED=1
    continue
  fi

  {
    IFS= read -r line1
    IFS= read -r line2
    IFS= read -r line3
  } <"$file"

  if [[ "$line1" != "P6" ]]; then
    echo "invalid magic: $file ($line1)"
    FAILED=1
    continue
  fi

  read -r width height <<<"$line2"
  maxval="$line3"

  if ! [[ "$width" =~ ^[0-9]+$ && "$height" =~ ^[0-9]+$ && "$maxval" =~ ^[0-9]+$ ]]; then
    echo "invalid header fields: $file"
    FAILED=1
    continue
  fi

  if [[ "$width" -le 0 || "$height" -le 0 || "$maxval" -ne 255 ]]; then
    echo "unexpected ppm bounds: $file (w=$width h=$height max=$maxval)"
    FAILED=1
    continue
  fi

  header_bytes=$(( ${#line1} + ${#line2} + ${#line3} + 3 ))
  expected_bytes=$(( width * height * 3 + header_bytes ))
  actual_bytes=$(wc -c <"$file")
  if [[ "$actual_bytes" -ne "$expected_bytes" ]]; then
    echo "size mismatch: $file (expected=$expected_bytes actual=$actual_bytes)"
    FAILED=1
    continue
  fi

  echo "ok: $file (${width}x${height})"
done

if [[ "$FAILED" -ne 0 ]]; then
  echo "ppm validation failed"
  exit 1
fi

echo "ppm validation passed"

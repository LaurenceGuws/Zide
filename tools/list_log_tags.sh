#!/usr/bin/env bash
set -euo pipefail

# Lists logger tags found in source.
# Sources:
# - app_logger.logger("tag")
# - std.log.scoped(.tag)
#
# Usage:
#   tools/list_log_tags.sh
#   tools/list_log_tags.sh --with-counts

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

with_counts=0
if [[ "${1:-}" == "--with-counts" ]]; then
  with_counts=1
fi

tmp_tags="$(mktemp)"
trap 'rm -f "$tmp_tags"' EXIT

rg -n 'app_logger\.logger\("([^"]+)"\)' src \
  | sed -E 's/.*app_logger\.logger\("([^"]+)"\).*/\1/' >> "$tmp_tags"

rg -n 'std\.log\.scoped\(\.[A-Za-z0-9_]+\)' src \
  | sed -E 's/.*std\.log\.scoped\(\.([A-Za-z0-9_]+)\).*/\1/' >> "$tmp_tags"

if [[ "$with_counts" -eq 1 ]]; then
  sort "$tmp_tags" | uniq -c | awk '{print $2"\t"$1}' | sort
else
  sort -u "$tmp_tags"
fi

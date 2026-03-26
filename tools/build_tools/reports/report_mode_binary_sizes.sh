#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bin_dir="$repo_root/zig-out/bin"

bins=(
  "zide"
  "zide-terminal"
  "zide-editor"
  "zide-ide"
)

echo "mode binary sizes (bytes)"
echo "-------------------------"

for bin in "${bins[@]}"; do
    path="$bin_dir/$bin"
    if [[ -f "$path" ]]; then
        size="$(wc -c <"$path" | tr -d ' ')"
        printf "%-15s %12s\n" "$bin" "$size"
    else
        printf "%-15s %12s\n" "$bin" "<missing>"
    fi
done


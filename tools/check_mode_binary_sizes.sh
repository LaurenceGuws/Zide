#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bin_dir="$repo_root/zig-out/bin"

main_bin="$bin_dir/zide"
terminal_bin="$bin_dir/zide-terminal"
editor_bin="$bin_dir/zide-editor"
ide_bin="$bin_dir/zide-ide"

require_file() {
    local path="$1"
    if [[ ! -f "$path" ]]; then
        echo "missing binary: $path" >&2
        exit 1
    fi
}

require_file "$main_bin"
require_file "$terminal_bin"
require_file "$editor_bin"
require_file "$ide_bin"

main_size="$(wc -c <"$main_bin" | tr -d ' ')"
terminal_size="$(wc -c <"$terminal_bin" | tr -d ' ')"
editor_size="$(wc -c <"$editor_bin" | tr -d ' ')"
ide_size="$(wc -c <"$ide_bin" | tr -d ' ')"

echo "mode size check"
echo "---------------"
echo "zide:          $main_size"
echo "zide-terminal: $terminal_size"
echo "zide-editor:   $editor_size"
echo "zide-ide:      $ide_size"

if (( terminal_size > main_size )); then
    echo "zide-terminal should not exceed zide size" >&2
    exit 1
fi
if (( editor_size > main_size )); then
    echo "zide-editor should not exceed zide size" >&2
    exit 1
fi
if (( ide_size > main_size )); then
    echo "zide-ide should not exceed zide size" >&2
    exit 1
fi

echo "ok"

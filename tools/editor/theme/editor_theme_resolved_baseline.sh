#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "usage: $0 <colorscheme> [resolved-name]" >&2
    exit 1
fi

colorscheme="$1"
resolved_name="${2:-${colorscheme}-resolved}"
artifact="/tmp/${resolved_name}.json"
legacy_resolved_name="${colorscheme%-night}-resolved"

if [ "$legacy_resolved_name" != "$resolved_name" ]; then
    python3 tools/editor/theme/editor_theme_import.py --remove-generated "$legacy_resolved_name" >/tmp/zide_theme_cleanup.log
    if ! grep -q "nothing to remove" /tmp/zide_theme_cleanup.log; then
        cat /tmp/zide_theme_cleanup.log
    fi
fi

nvim --headless "+lua dofile('tools/editor/theme/nvim_resolved_theme_export.lua')" -- \
    --colorscheme "$colorscheme" \
    --profile treesitter \
    --preset zide-core \
    --out "$artifact"

python3 tools/editor/theme/nvim_resolved_theme_compare.py --summary "$artifact"
python3 tools/editor/theme/editor_theme_import.py \
    --resolved-export "$artifact" \
    --resolved-name "$resolved_name" \
    --apply \
    --register

echo "artifact: $artifact"

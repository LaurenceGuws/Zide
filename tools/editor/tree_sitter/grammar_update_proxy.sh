#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/../../.." && pwd)"

resolve_tree_sitter_repo() {
    if [[ -n "${ZIDE_TREE_SITTER_REPO:-}" ]]; then
        printf '%s\n' "$ZIDE_TREE_SITTER_REPO"
        return 0
    fi

    local candidates=(
        "$repo_root/../zide-tree-sitter"
        "$repo_root/../../zide-tree-sitter"
    )
    local candidate
    for candidate in "${candidates[@]}"; do
        if [[ -d "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    printf 'zide-tree-sitter repo not found; set ZIDE_TREE_SITTER_REPO or clone it beside zide\n' >&2
    return 1
}

resolve_asset_root() {
    if [[ -n "${ZIDE_TREE_SITTER_ASSET_ROOT:-}" ]]; then
        printf '%s\n' "$ZIDE_TREE_SITTER_ASSET_ROOT"
        return 0
    fi
    if [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
        printf '%s\n' "$XDG_CONFIG_HOME/zide/tree-sitter-assets"
        return 0
    fi
    if [[ -n "${HOME:-}" ]]; then
        printf '%s\n' "$HOME/.config/zide/tree-sitter-assets"
        return 0
    fi
    printf '%s\n' "$repo_root/.zide/tree-sitter-assets"
}

tree_sitter_repo="$(resolve_tree_sitter_repo)"
asset_root="$(resolve_asset_root)"

(
    cd "$tree_sitter_repo"
    zig build grammar-update -- "$@"
)

mkdir -p "$asset_root"
rm -rf "$asset_root/queries"
cp -R "$tree_sitter_repo/assets/queries" "$asset_root/queries"
mkdir -p "$asset_root/syntax"
cp "$tree_sitter_repo/assets/syntax/generated.lua" "$asset_root/syntax/generated.lua"

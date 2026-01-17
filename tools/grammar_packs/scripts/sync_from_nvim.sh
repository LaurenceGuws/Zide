#!/usr/bin/env bash
set -euo pipefail

# Sync registry (parsers.lua) + queries from nvim-treesitter into work/.

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
work="$root/work"
mkdir -p "$work"

nvim_dir="$work/nvim-treesitter"
if [[ ! -d "$nvim_dir/.git" ]]; then
  echo "Cloning nvim-treesitter..."
  git clone --depth 1 https://github.com/nvim-treesitter/nvim-treesitter.git "$nvim_dir"
else
  echo "Updating nvim-treesitter..."
  git -C "$nvim_dir" fetch --depth 1 origin
  git -C "$nvim_dir" reset --hard origin/HEAD
fi

queries_src="$nvim_dir/runtime/queries"
queries_dst="$work/queries"
mkdir -p "$queries_dst"

# Sync all highlights.scm files.
find "$queries_src" -mindepth 1 -maxdepth 1 -type d -print0 | while IFS= read -r -d '' dir; do
  lang=$(basename "$dir")
  src="$dir/highlights.scm"
  if [[ -f "$src" ]]; then
    cp "$src" "$queries_dst/${lang}_highlights.scm"
  fi
 done

# Copy parsers.lua for parsing.
cp "$nvim_dir/lua/nvim-treesitter/parsers.lua" "$work/parsers.lua"


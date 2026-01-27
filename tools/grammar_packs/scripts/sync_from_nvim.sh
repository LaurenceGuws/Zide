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

# Sync all query files we care about.
query_files=(
  highlights.scm
  injections.scm
  locals.scm
  tags.scm
  textobjects.scm
  indents.scm
)

find "$queries_src" -mindepth 1 -maxdepth 1 -type d -print0 | while IFS= read -r -d '' dir; do
  lang=$(basename "$dir")
  for name in "${query_files[@]}"; do
    src="$dir/$name"
    if [[ -f "$src" ]]; then
      suffix="${name%.scm}"
      cp "$src" "$queries_dst/${lang}_${suffix}.scm"
    fi
  done
 done

# Patch markdown inline injections to include children (matches Helix behavior).
markdown_injections="$queries_dst/markdown_injections.scm"
if [[ -f "$markdown_injections" ]]; then
  python - "$markdown_injections" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
data = path.read_text(encoding="utf-8")

needle = '(#set! injection.language "markdown_inline")'
insert = needle + '\n  (#set! injection.include-children)'
if "injection.include-children" not in data and needle in data:
    data = data.replace(needle, insert)
    path.write_text(data, encoding="utf-8")
PY
fi

# Copy parsers.lua for parsing.
cp "$nvim_dir/lua/nvim-treesitter/parsers.lua" "$work/parsers.lua"

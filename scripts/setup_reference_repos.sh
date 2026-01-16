#!/usr/bin/env bash
set -euo pipefail

# Each entry should be "name - URL".
# Example: "kitty - https://github.com/kovidgoyal/kitty.git"
TERMINAL_REPOS=(
  "kitty - https://github.com/kovidgoyal/kitty.git"
  "ghostty - https://github.com/ghostty-org/ghostty.git"
  "alacritty - https://github.com/alacritty/alacritty.git"
  "wezterm - https://github.com/wezterm/wezterm.git"
  "foot - https://github.com/r-c-f/foot.git"
  "rio - https://github.com/raphamorim/rio.git"
  "contour - https://github.com/contour-terminal/contour.git"
  "xterm_snapshots - https://github.com/xterm-x11/xterm-snapshots.git"
  "st - https://github.com/Shourai/st.git"
  "tabby - https://github.com/Eugeny/tabby.git"
  "hyper - https://github.com/vercel/hyper.git"
  "iterm2 - https://github.com/gnachman/iTerm2.git"
)

# Fill these with backend/library URLs. Each entry should be "name - URL".
BACKEND_REPOS=(
  "libtsm - https://github.com/Aetf/libtsm.git"
  "gnome_vte - https://github.com/GNOME/vte.git"
  "libvterm - https://github.com/neovim/libvterm.git"
  "alacritty_vte - https://github.com/alacritty/vte.git"
)

# Fonts / shaping (name - URL)
FONT_REPOS=(
  "harfbuzz - https://github.com/harfbuzz/harfbuzz.git"
  "freetype - https://github.com/freetype/freetype.git"
  "graphite2 - https://github.com/Distrotech/graphite2.git"
  "unicode_width - https://github.com/alacritty/unicode-width-16.git"
  "crossfont - https://github.com/alacritty/crossfont.git"
)

# Rendering / GPU refs (name - URL)
RENDER_REPOS=(
  "skia - https://github.com/google/skia.git"
  "pixman - https://gitlab.freedesktop.org/pixman/pixman.git"
  "wgpu - https://github.com/gfx-rs/wgpu.git"
)

# Base folder for all reference repos
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/reference_repos"
TERMINAL_DIR="$ROOT_DIR/terminals"
BACKEND_DIR="$ROOT_DIR/backends"
FONT_DIR="$ROOT_DIR/fonts"
RENDER_DIR="$ROOT_DIR/rendering"

mkdir -p "$TERMINAL_DIR" "$BACKEND_DIR" "$FONT_DIR" "$RENDER_DIR"

clone_list() {
  local target_dir="$1"
  shift
  local repos=("$@")

  for repo in "${repos[@]}"; do
    [ -z "$repo" ] && continue
    local name url
    name="${repo%% - *}"
    url="${repo#* - }"
    local dest="$target_dir/$name"
    if [ -d "$dest" ]; then
      echo "skip $name (already exists)"
      continue
    fi
    git clone --depth 1 "$url" "$dest" || echo "failed $url"
  done
}

clone_list "$TERMINAL_DIR" "${TERMINAL_REPOS[@]}"
clone_list "$BACKEND_DIR" "${BACKEND_REPOS[@]}"
clone_list "$FONT_DIR" "${FONT_REPOS[@]}"
clone_list "$RENDER_DIR" "${RENDER_REPOS[@]}"

echo "done."

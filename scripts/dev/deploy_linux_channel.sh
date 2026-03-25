#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/dev/deploy_linux_channel.sh <stable|dev> [--skip-build]

Dev-only local installer for the Linux launcher family.

Channels:
  stable  Builds with ReleaseFast and installs the stable launcher family
  dev     Builds default debug/dev and installs the dev launcher family

Installs:
  Binaries:
    ~/.local/bin/zide-<channel>
    ~/.local/bin/zide-editor-<channel>
    ~/.local/bin/zide-terminal-<channel>
  Desktop entries:
    ~/.local/share/applications/zide-<channel>.desktop
    ~/.local/share/applications/zide-editor-<channel>.desktop
    ~/.local/share/applications/zide-terminal-<channel>.desktop
  Icons:
    ~/.local/share/icons/hicolor/512x512/apps/zide-<channel>.png
    ~/.local/share/icons/hicolor/512x512/apps/zide-editor-<channel>.png
    ~/.local/share/icons/hicolor/512x512/apps/zide-terminal-<channel>.png
EOF
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" || $# -lt 1 ]]; then
  usage
  exit 0
fi

channel="$1"
skip_build="false"
if [[ ${2:-} == "--skip-build" ]]; then
  skip_build="true"
fi

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
bin_dir="$HOME/.local/bin"
apps_dir="$HOME/.local/share/applications"
icons_dir="$HOME/.local/share/icons/hicolor/512x512/apps"

case "$channel" in
  stable)
    channel_label="Stable"
    channel_id="stable"
    build_main_cmd=(zig build -Doptimize=ReleaseFast)
    build_editor_cmd=(zig build -Dmode=editor -Doptimize=ReleaseFast)
    build_terminal_cmd=(zig build -Dmode=terminal -Doptimize=ReleaseFast)
    ;;
  dev|test)
    channel_label="Dev"
    channel_id="dev"
    build_main_cmd=(zig build)
    build_editor_cmd=(zig build -Dmode=editor)
    build_terminal_cmd=(zig build -Dmode=terminal)
    ;;
  *)
    echo "Unknown channel: $channel" >&2
    usage
    exit 1
    ;;
esac

if [[ "$skip_build" != "true" ]]; then
  echo "Building zide-$channel_id launcher family..."
  (
    cd "$repo_root"
    "${build_main_cmd[@]}"
    "${build_editor_cmd[@]}"
    "${build_terminal_cmd[@]}"
  )
fi

mkdir -p "$bin_dir" "$apps_dir" "$icons_dir"

install_launcher() {
  local binary_name="$1"
  local desktop_id="$2"
  local display_name="$3"
  local icon_src="$4"
  local categories="$5"

  local src_bin="$repo_root/zig-out/bin/$binary_name"
  if [[ ! -f "$src_bin" ]]; then
    echo "Missing binary: $src_bin" >&2
    exit 1
  fi

  local dst_bin="$bin_dir/$desktop_id"
  local dst_icon="$icons_dir/$desktop_id.png"
  local dst_desktop="$apps_dir/$desktop_id.desktop"

  install -m 0755 "$src_bin" "$dst_bin"
  install -m 0644 "$icon_src" "$dst_icon"

  cat > "$dst_desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$display_name
Exec=env SDL_APP_ID=$desktop_id "$dst_bin"
Path=$repo_root
Icon=$desktop_id
StartupWMClass=$desktop_id
Terminal=false
Categories=$categories
StartupNotify=true
EOF

  chmod 0644 "$dst_desktop"

  echo "Installed $display_name"
  echo "  Binary:  $dst_bin"
  echo "  Desktop: $dst_desktop"
  echo "  Icon:    $dst_icon"
}

install_launcher "zide" "zide-$channel_id" "Zide $channel_label" "$repo_root/assets/icon/color_icon.png" "Development;IDE;Utility;"
install_launcher "zide-editor" "zide-editor-$channel_id" "Zide Editor $channel_label" "$repo_root/assets/icon/color_icon.png" "System;Utility;"
install_launcher "zide-terminal" "zide-terminal-$channel_id" "Zide Terminal $channel_label" "$repo_root/assets/icon/zide_terminal_taskbar.png" "System;Utility;"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$apps_dir" >/dev/null 2>&1 || true
fi

if [[ "$channel" == "test" ]]; then
  echo "  Note: 'test' is a compatibility alias; prefer 'dev'."
fi

#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ops/linux/install-local/deploy_channel.sh <stable|dev> [--skip-build]

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

repo_root="$(cd "$(dirname "$0")/../../.." && pwd)"
bin_dir="$HOME/.local/bin"
apps_dir="$HOME/.local/share/applications"
icons_dir="$HOME/.local/share/icons/hicolor/512x512/apps"

refresh_linux_desktop_caches() {
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$apps_dir" >/dev/null 2>&1 || true
  fi

  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t "$(dirname "$icons_dir")" >/dev/null 2>&1 || true
  fi

  if command -v kbuildsycoca6 >/dev/null 2>&1; then
    kbuildsycoca6 >/dev/null 2>&1 || true
  fi
}

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
  local generic_name="$4"
  local comment="$5"
  local icon_src="$6"
  local categories="$7"
  local keywords="$8"
  local extra_actions="${9:-}"

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
Version=1.0
Type=Application
Name=$display_name
GenericName=$generic_name
Comment=$comment
TryExec=$dst_bin
Exec=env SDL_APP_ID=$desktop_id "$dst_bin"
Path=$repo_root
Icon=$desktop_id
StartupWMClass=$desktop_id
Terminal=false
Categories=$categories
Keywords=$keywords
StartupNotify=true
EOF

  if [[ -n "$extra_actions" ]]; then
    printf '%s\n' "$extra_actions" >> "$dst_desktop"
  fi

  chmod 0644 "$dst_desktop"

  echo "Installed $display_name"
  echo "  Binary:  $dst_bin"
  echo "  Desktop: $dst_desktop"
  echo "  Icon:    $dst_icon"
}

ide_actions=$(cat <<EOF
Actions=OpenEditor;OpenTerminal;

[Desktop Action OpenEditor]
Name=Open Editor
Exec=env SDL_APP_ID=zide-editor-$channel_id "$bin_dir/zide-editor-$channel_id"

[Desktop Action OpenTerminal]
Name=Open Terminal
Exec=env SDL_APP_ID=zide-terminal-$channel_id "$bin_dir/zide-terminal-$channel_id"
EOF
)

editor_actions=$(cat <<EOF
Actions=OpenIDE;OpenTerminal;

[Desktop Action OpenIDE]
Name=Open IDE
Exec=env SDL_APP_ID=zide-$channel_id "$bin_dir/zide-$channel_id"

[Desktop Action OpenTerminal]
Name=Open Terminal
Exec=env SDL_APP_ID=zide-terminal-$channel_id "$bin_dir/zide-terminal-$channel_id"
EOF
)

terminal_actions=$(cat <<EOF
Actions=OpenIDE;OpenEditor;

[Desktop Action OpenIDE]
Name=Open IDE
Exec=env SDL_APP_ID=zide-$channel_id "$bin_dir/zide-$channel_id"

[Desktop Action OpenEditor]
Name=Open Editor
Exec=env SDL_APP_ID=zide-editor-$channel_id "$bin_dir/zide-editor-$channel_id"
EOF
)

install_launcher \
  "zide" \
  "zide-$channel_id" \
  "Zide $channel_label" \
  "Zig IDE" \
  "Efficient workspace IDE for editing, terminals, and project navigation." \
  "$repo_root/assets/icon/color_icon.png" \
  "Development;IDE;Utility;" \
  "ide;editor;terminal;zig;development;workspace;code;" \
  "$ide_actions"

install_launcher \
  "zide-editor" \
  "zide-editor-$channel_id" \
  "Zide Editor $channel_label" \
  "Code Editor" \
  "Efficient editor mode for quick code and text editing." \
  "$repo_root/assets/icon/color_icon.png" \
  "System;Utility;" \
  "editor;text;code;zig;files;notepad;" \
  "$editor_actions"

install_launcher \
  "zide-terminal" \
  "zide-terminal-$channel_id" \
  "Zide Terminal $channel_label" \
  "Terminal Emulator" \
  "Efficient GPU-based Zide terminal module for shell and command-line work." \
  "$repo_root/assets/icon/zide_terminal_taskbar.png" \
  "System;Utility;" \
  "terminal;shell;console;pty;cli;command line;" \
  "$terminal_actions"

refresh_linux_desktop_caches

if [[ "$channel" == "test" ]]; then
  echo "  Note: 'test' is a compatibility alias; prefer 'dev'."
fi

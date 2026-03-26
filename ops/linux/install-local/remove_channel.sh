#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ops/linux/install-local/remove_channel.sh <stable|dev>

Removes one local Linux launcher family installed by deploy_channel.sh.

Removes:
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
    channel_id="stable"
    channel_label="Stable"
    ;;
  dev|test)
    channel_id="dev"
    channel_label="Dev"
    ;;
  *)
    echo "Unknown channel: $channel" >&2
    usage
    exit 1
    ;;
esac

remove_launcher() {
  local desktop_id="$1"
  rm -f \
    "$bin_dir/$desktop_id" \
    "$apps_dir/$desktop_id.desktop" \
    "$icons_dir/$desktop_id.png"
}

remove_launcher "zide-$channel_id"
remove_launcher "zide-editor-$channel_id"
remove_launcher "zide-terminal-$channel_id"

refresh_linux_desktop_caches

echo "Removed Zide $channel_label launcher family"
echo "  Binary prefix:  $bin_dir/*$channel_id"
echo "  Desktop prefix: $apps_dir/*$channel_id.desktop"
echo "  Icon prefix:    $icons_dir/*$channel_id.png"

if [[ "$channel" == "test" ]]; then
  echo "  Note: 'test' is a compatibility alias; prefer 'dev'."
fi

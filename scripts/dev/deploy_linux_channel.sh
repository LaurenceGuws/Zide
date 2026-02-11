#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/dev/deploy_linux_channel.sh <stable|test> [--skip-build]

Dev-only local installer for Linux launchers.

Channels:
  stable  Builds with ReleaseFast and installs as zide-stable
  test    Builds default debug/dev and installs as zide-test

Installs:
  ~/.local/bin/zide-stable|zide-test
  ~/.local/share/applications/zide-stable.desktop|zide-test.desktop
  ~/.local/share/icons/hicolor/512x512/apps/zide-stable.png|zide-test.png
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
    app_name="Zide Stable"
    app_id="zide-stable"
    icon_src="$repo_root/assets/icon/color_icon.png"
    build_cmd=(zig build -Doptimize=ReleaseFast)
    ;;
  test)
    app_name="Zide Test"
    app_id="zide-test"
    icon_src="$repo_root/assets/icon/grey_icon.png"
    build_cmd=(zig build)
    ;;
  *)
    echo "Unknown channel: $channel" >&2
    usage
    exit 1
    ;;
esac

if [[ "$skip_build" != "true" ]]; then
  echo "Building $app_id..."
  (
    cd "$repo_root"
    "${build_cmd[@]}"
  )
fi

src_bin="$repo_root/zig-out/bin/zide"
if [[ ! -f "$src_bin" ]]; then
  echo "Missing binary: $src_bin" >&2
  echo "Run: ${build_cmd[*]}" >&2
  exit 1
fi

mkdir -p "$bin_dir" "$apps_dir" "$icons_dir"

dst_bin="$bin_dir/$app_id"
dst_icon="$icons_dir/$app_id.png"
dst_desktop="$apps_dir/$app_id.desktop"

install -m 0755 "$src_bin" "$dst_bin"
install -m 0644 "$icon_src" "$dst_icon"

cat > "$dst_desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$app_name
Exec=env SDL_APP_ID=$app_id "$dst_bin"
Path=$repo_root
Icon=$app_id
StartupWMClass=$app_id
Terminal=false
Categories=Development;IDE;
StartupNotify=true
EOF

chmod 0644 "$dst_desktop"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$apps_dir" >/dev/null 2>&1 || true
fi

echo "Installed $app_name"
echo "  Binary:  $dst_bin"
echo "  Desktop: $dst_desktop"
echo "  Icon:    $dst_icon"

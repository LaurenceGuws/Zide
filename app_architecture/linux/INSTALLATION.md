# Linux Installation

This document owns the supported Linux local-install layout and the current
local staged-release path.

It is the Linux counterpart to `app_architecture/windows/INSTALLATION.md`.

## Current Policy

- Linux local desktop testing should use explicit local install surfaces, not
  only repo-local smoke launches.
- Linux release staging should treat IDE, editor, and terminal as one product
  family, not as a terminal-only special case.
- Finder/taskbar/dock behavior is part of product truth on Linux, especially on
  Wayland/KDE where desktop-entry metadata matters.

## Tooling Intents

Cross-OS tooling intent authority lives in:

- `app_architecture/TOOLING_INSTALL_SURFACES.md`

Current Linux entrypoints:

- smoke:
  - `zig build gui-smokes-manual`
- install-local:
  - `ops/linux/install-local/deploy_channel.sh <stable|dev>`
  - `ops/linux/install-local/deploy_channels.sh`
  - `ops/linux/install-local/remove_channel.sh <stable|dev>`
  - `ops/linux/install-local/remove_channels.sh`
  - `ops/linux/install-local/sync_channel.sh <stable|dev>`
  - `ops/linux/install-local/sync_channels.sh`
- stage-release:
  - `ops/linux/Stage-CurrentLinuxDist.sh`

## Local Install Channels

Current channel vocabulary:

- `dev`
  - default debug/dev build
  - local desktop install for fast iteration
- `stable`
  - `ReleaseFast` local desktop install
  - local daily-driver style validation surface

Compatibility note:

- legacy `test` naming should only remain a short migration alias in scripts;
  docs should prefer `dev`

## Local Install Layout

Current Linux local desktop install path:

- binaries:
  - `~/.local/bin/zide-dev`
  - `~/.local/bin/zide-editor-dev`
  - `~/.local/bin/zide-terminal-dev`
  - `~/.local/bin/zide-stable`
  - `~/.local/bin/zide-editor-stable`
  - `~/.local/bin/zide-terminal-stable`
- desktop entries:
  - `~/.local/share/applications/zide-dev.desktop`
  - `~/.local/share/applications/zide-editor-dev.desktop`
  - `~/.local/share/applications/zide-terminal-dev.desktop`
  - `~/.local/share/applications/zide-stable.desktop`
  - `~/.local/share/applications/zide-editor-stable.desktop`
  - `~/.local/share/applications/zide-terminal-stable.desktop`
- icons:
  - `~/.local/share/icons/hicolor/512x512/apps/zide-dev.png`
  - `~/.local/share/icons/hicolor/512x512/apps/zide-editor-dev.png`
  - `~/.local/share/icons/hicolor/512x512/apps/zide-terminal-dev.png`
  - `~/.local/share/icons/hicolor/512x512/apps/zide-stable.png`
  - `~/.local/share/icons/hicolor/512x512/apps/zide-editor-stable.png`
  - `~/.local/share/icons/hicolor/512x512/apps/zide-terminal-stable.png`

Current desktop-entry behavior:

- local installs launch from repo-built binaries
- local desktop entries point `Path=` at the repo root today
- local installs now expose first-class IDE/editor/terminal desktop launchers
  per channel instead of only one `zide` launcher
- local desktop entries should look like real desktop apps, not only minimal
  launch stubs:
  - `Version=1.0`
  - `GenericName`
  - `Comment`
  - `TryExec`
  - `Keywords`
- icon and WM class behavior are part of the install-local contract, not a
  renderer-only concern
- install-local ownership now includes explicit remove/replace behavior for the
  full launcher family per channel, not only one-way installs
- local install/remove scripts should refresh desktop, icon, and KDE cache
  indexes after mutating launcher metadata
- `sync_channel.sh` is the preferred operator path for updating an existing
  local channel install in place
- launcher-family desktop entries may advertise convenience actions for sibling
  modes so each launcher can pivot into the others without a second menu search
- current first pass exposes:
  - IDE: `Open Editor`, `Open Terminal`
  - editor: `Open IDE`, `Open Terminal`
  - terminal: `Open IDE`, `Open Editor`

## Local Stage-Release Layout

Current local Linux stage output:

- `releases/<tag>/linux-x86_64-local/dist/`

Current staged artifacts:

- `zide-ide-bundle-<version>-linux-x86_64.tar.gz`
- `zide-editor-bundle-<version>-linux-x86_64.tar.gz`
- `zide-terminal-bundle-<version>-linux-x86_64.tar.gz`
- `zide-terminal-ffi-<version>-linux-x86_64.tar.gz`
- `zide-editor-ffi-<version>-linux-x86_64.tar.gz`
- `SHA256SUMS-linux-x86_64.txt`

The stage script also keeps unpacked working directories under the same staged
root while assembling the bundles.

## Bundle Shape

Current Linux bundle helper is:

- `tools/packaging/linux/bundle_terminal_linux.sh`

Despite the historical name, it now serves all three launcher modes:

- `ide`
- `editor`
- `terminal`

Current bundle behavior:

- copies the requested launcher binary into `bin/`
- copies the required subset of `assets/` for the selected mode
- compiles bundled terminfo into `terminfo/`
- copies non-core shared libraries into `lib/`
- emits a top-level launcher script that runs from a per-launcher runtime dir

## Current Gaps

- Wayland desktop icon/grouping behavior may still require stronger desktop
  metadata ownership than repo-local smoke launches prove.
- canonical Linux install-local entrypoints now live under
  `ops/linux/install-local/`; the old `scripts/dev/` wrappers have been
  removed.

## KDE Notes

- KDE/Wayland can keep stale launcher identity or icon state after metadata
  changes even when the files on disk are already correct.
- The install-local scripts now refresh:
  - desktop database
  - icon cache
  - KDE 6 sycoca cache
- If a stale entry still remains after a sync, the next checks are:
  - remove obsolete local desktop entries from `~/.local/share/applications/`
  - remove obsolete local icons from
    `~/.local/share/icons/hicolor/512x512/apps/`
  - restart Plasma shell or log out/in
- System-wide stale entries under `/usr/share/applications/` are outside the
  local install-local contract and should be removed by uninstalling the owning
  package rather than by changing repo-local scripts.

## Direction

1. Keep repo-local smoke and local desktop install as separate intents.
2. Keep Linux stage-release unified across IDE/editor/terminal.
3. Keep Linux install-local on the launcher-family model and avoid regressing to
   a single-launcher shortcut hack.
4. Preserve one clear owning authority for Linux desktop integration behavior.

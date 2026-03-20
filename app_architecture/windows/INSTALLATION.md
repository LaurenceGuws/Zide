# Windows Installation

This document owns the supported Windows install layout and the first
distribution path for native Zide installs.

Current policy:

- native Windows target: `x86_64-windows-msvc`
- released artifacts are zip bundles
- the first native-feeling install path is a per-user PowerShell installer
- installer/package-manager work later should preserve this runtime layout

## Goals

- feel like a normal Windows desktop app install, not "run an extracted zip"
- keep binaries out of random working folders
- separate app files, user config, and runtime state
- create stable Start Menu launch surfaces for:
  - `Zide`
  - `Zide Editor`
  - `Zide Terminal`

## Install Layout

Per-user app files:

- `%LOCALAPPDATA%\\Programs\\Zide\\<version>\\`
- `%LOCALAPPDATA%\\Programs\\Zide\\current\\`

User config:

- `%APPDATA%\\Zide\\init.lua`

User-local state, logs, caches:

- `%LOCALAPPDATA%\\Zide\\`

Start Menu shortcuts:

- `%APPDATA%\\Microsoft\\Windows\\Start Menu\\Programs\\Zide\\`

Shortcut launch defaults:

- shared terminal shell/cwd policy belongs in Lua config, not the installer
- default Windows behavior should come from `assets/config/init.lua` and user
  config under `%APPDATA%\\Zide\\init.lua`
- installer may still stamp explicit shortcut launch args when `-ShellPath`
  and/or `-LaunchCwd` are passed for a launcher-specific override

Uninstall registration:

- `HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Zide`

## Installed File Shape

The installer merges the Windows release bundles into one versioned install
root:

- `zide.exe`
- `zide-editor.exe`
- `zide-terminal.exe`
- shared runtime DLLs
- `assets/`
- generated shortcut icons under `icons/`

Native launch expectation:

- `zide.exe`
- `zide-editor.exe`
- `zide-terminal.exe`

should all be built as Windows GUI-subsystem executables so Start Menu or shell
launch does not create a companion console host window.

Current Windows identity policy:

- each launcher embeds real PE resources:
  - icon
  - file/product version
  - file description/original filename metadata
- each launcher sets an explicit Windows AppUserModelID at runtime
- default identity set:
  - `LaurenceGuws.Zide`
  - `LaurenceGuws.Zide.Editor`
  - `LaurenceGuws.Zide.Terminal`
- SDL app name/app id defaults should match those launcher identities unless
  explicitly overridden for debugging

Current launcher expectation:

- `zide.exe`, `zide-editor.exe`, and `zide-terminal.exe` all accept terminal
  launch override args (`--shell`, `--cwd`, `--command`, etc.)
- for IDE/editor modes those args seed terminal-session defaults without being
  misread as startup file paths

Current bundle merge rule:

- IDE bundle provides the full asset set and default app binary
- editor bundle contributes `zide-editor.exe`
- terminal bundle contributes `zide-terminal.exe`

This keeps one shared runtime layout instead of three separate extracted app
folders.

## Shortcut Icons

Current icon policy:

- app/editor shortcuts use `assets/icon/color_icon.png` converted to `.ico`
- terminal shortcut uses `assets/icon/zide_terminal_taskbar.png` converted to
  `.ico`

The terminal icon is intentionally distinct so terminal-only launch surfaces do
not reuse the generic app icon.

Current shortcut policy:

- installed shortcuts are clean by default and rely on shared terminal config
- if explicit launcher overrides are requested, all three Start Menu shortcuts
  should carry the same terminal args so IDE/editor terminals match
- installed Start Menu shortcuts should also carry the matching
  `AppUserModelID` for:
  - `LaurenceGuws.Zide`
  - `LaurenceGuws.Zide.Editor`
  - `LaurenceGuws.Zide.Terminal`
- Windows PTY launch must pass the resolved terminal cwd into
  `CreateProcessW(..., lpCurrentDirectory=...)` so installed launches do not
  fall back to `%LOCALAPPDATA%\\Programs\\Zide\\current`

## First Distribution Method

Current first-class Windows install path:

- `scripts/windows/Install-Zide.ps1`

Current non-goals for this first cut:

- machine-wide install
- file associations
- PATH mutation
- winget packaging
- MSI/WiX authoring

Those can come later if they preserve this same install/runtime contract.

## Installer Inputs

Normal install path:

- download release assets from
  `https://github.com/LaurenceGuws/Zide/releases`
- verify `SHA256SUMS-windows-x86_64.txt`
- install from:
  - `zide-ide-bundle-<version>-windows-x86_64.zip`
  - `zide-editor-bundle-<version>-windows-x86_64.zip`
  - `zide-terminal-bundle-<version>-windows-x86_64.zip`

Current installer supports:

- release download install
- local dist-dir install for validation/dev

## Uninstall Behavior

Uninstall removes:

- Start Menu shortcuts
- current-version install directory
- current junction when it points to that version
- uninstall registry entry

Uninstall keeps by default:

- `%APPDATA%\\Zide\\`
- `%LOCALAPPDATA%\\Zide\\`

That matches normal Windows expectations: app removal should not silently wipe
user config/state unless explicitly requested.

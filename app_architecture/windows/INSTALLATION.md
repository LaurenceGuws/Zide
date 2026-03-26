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

Current grammar-pack cache root:

- `%LOCALAPPDATA%\\Zide\\grammars\\`

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

App Paths registration:

- `HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\App Paths\\zide.exe`
- `HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\App Paths\\zide-editor.exe`
- `HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\App Paths\\zide-terminal.exe`

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

Current native shell-path policy:

- installer registers all three launchers under per-user `App Paths`
- this gives Windows a standard executable lookup surface without mutating the
  user's `PATH`
- uninstall removes those `App Paths` entries again

Current shell integration policy:

- installer removes legacy classic Explorer verbs and registers the packaged
  Win11 Explorer command path instead
- current supported Win11 menu shape intentionally follows:
  - files:
    - top-level `Zide`
    - submenu:
      - `Open in Zide`
      - `Open in Zide Editor`
  - folders:
    - top-level `Zide`
    - submenu:
      - `Open in Zide`
      - `Open Zide Terminal here`
  - multiple folders:
    - top-level `Zide`
    - submenu:
      - `Open Zide Terminal here`
  - directory background:
    - top-level `Zide`
    - submenu:
      - `Open in Zide`
      - `Open Zide Terminal here`
  - mixed file+folder selection:
    - hidden
- current implementation is the packaged `IExplorerCommand` path backed by
  package identity and a full local package registration
- the old classic `HKCU\Software\Classes\...` verb path is no longer a
  supported product surface; installs now clean it up to avoid mixed menus
- deeper Windows-native integration authority lives in:
  - `app_architecture/windows/NATIVE_SHELL_INTEGRATION.md`

## First Distribution Method

Current first-class Windows install path:

- `ops/windows/Install-Zide.ps1`

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
- package-identity registration via:
  - `ops/windows/Register-ZidePackageIdentity.ps1`
  - `ops/windows/Unregister-ZidePackageIdentity.ps1`
  - package-identity metadata is now written into the installed app under:
    - `%LOCALAPPDATA%\Programs\Zide\<version>\support\windows-package-identity.json`
  - registration now builds the Explorer package from the installed metadata
    and install root, not from the repo checkout
  - self-signed local/dev registration expects elevation so the signing cert can
    be trusted in the machine certificate stores
  - the supported installer path now uses:
    - `Register-ZidePackageIdentity.ps1 -PackageMode Full`
  - `External` remains a troubleshooting-only comparison mode, not the supported
    install story for Win11 Explorer commands

Current installer UX policy:

- package identity and packaged Win11 Explorer integration are the one supported
  Windows install path
- installer output should state:
  - whether Start Menu registration is enabled
  - whether Add/Remove Programs registration is enabled
  - that Win11 Explorer integration is enabled
  - that package identity registration is enabled
  - that package mode is `Full`
  - which packaged Explorer commands are expected after install
- the repeatable post-install validation ritual lives in:
  - `docs/reference/windows_win11_shell_validation.md`

Example local install:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\Install-Zide.ps1 -ReleaseDistDir .\dist
```

Example local package registration comparison:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\Register-ZidePackageIdentity.ps1 -InstallDir $env:LOCALAPPDATA\Programs\Zide\current -PackageMode External
```

## Uninstall Behavior

Uninstall removes:

- Start Menu shortcuts
- current-version install directory
- current junction when it points to that version
- uninstall registry entry
- per-user `App Paths` registrations
- packaged Explorer integration and any leftover legacy shell verbs

Uninstall keeps by default:

- `%APPDATA%\\Zide\\`
- `%LOCALAPPDATA%\\Zide\\`

That matches normal Windows expectations: app removal should not silently wipe
user config/state unless explicitly requested.

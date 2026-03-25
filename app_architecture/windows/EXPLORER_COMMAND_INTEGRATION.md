# Windows Explorer Command Integration

Date: 2026-03-25

Purpose: define the packaged `IExplorerCommand` lane for top-level Windows 11
Explorer integration.

Use this with:

- `app_architecture/windows/NATIVE_SHELL_INTEGRATION.md`
- `app_architecture/windows/INSTALLATION.md`
- `docs/todo/windows/implementation.md`

## Goal

Move beyond classic per-user registry verbs and give Zide a real top-level
Windows 11 Explorer entry.

This lane is:

- packaged
- COM-based
- package-identity-backed

It is not an extension of the classic `HKCU\Software\Classes\...` registry verb
path.

## Current Command Set

Current supported packaged commands:

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
- folder background:
  - direct `Open Zide Terminal here`

## Reference Shape

Windows Terminal uses:

- packaged COM server
- `IExplorerCommand`
- `windows.comServer`
- `windows.fileExplorerContextMenus`

Reference files:

- `reference_repos/terminals/windows_terminal/src/cascadia/ShellExtension/OpenTerminalHere.h`
- `reference_repos/terminals/windows_terminal/src/cascadia/ShellExtension/OpenTerminalHere.cpp`
- `reference_repos/terminals/windows_terminal/src/cascadia/ShellExtension/dllmain.cpp`
- `reference_repos/terminals/windows_terminal/src/cascadia/CascadiaPackage/Package.appxmanifest`

The current Zide lane follows that same high-level model:

- in-proc COM DLL
- packaged through full local package registration from the installed payload
- separate top-level COM classes for:
  - file submenu
  - folder submenu
  - direct folder-background terminal command

## Current Zide Implementation State

Current artifact:

- `zide-shell-ext.dll`

Current top-level COM classes:

- `ZideFileMenu`
  - CLSID: `7A4A9F94-7A56-4B72-9D3A-0E4F1A0E6E11`
- `ZideFolderMenu`
  - CLSID: `7D8E995A-2D37-48D8-AB12-4F03C6362D85`
- `ZideBackgroundTerminal`
  - CLSID: `4C5D89A5-4E56-48E0-AE5A-8F4A5C6D1972`

Current build/runtime wiring:

- shell-extension DLL builds on Windows and installs beside the launchers
- installer writes shell-extension metadata into:
  - `support/windows-package-identity.json`
- package-identity registration generates:
  - `windows.comServer`
  - `windows.fileExplorerContextMenus`
- installer uses full package registration by default for the supported Win11
  Explorer path
- installs also remove stale legacy classic shell verbs so the packaged command
  surface is not mixed with old `Show more options` entries

## Architecture Notes

The shell extension should stay intentionally small.

Responsibilities:

- resolve the best Explorer location
- validate it is a file-system-backed directory target
- launch `zide-terminal.exe` with `--cwd`
- expose title/icon/state through `IExplorerCommand`

It should not:

- know app config
- know workspace semantics
- reimplement installer policy
- become a dumping ground for product command routing

The intended UX rule is:

- if multiple relevant launchers exist, show top-level `Zide` with a submenu
- if only one relevant launcher exists, show the direct command instead

## Validation Lane

The shell-extension lane is only meaningful when tested through the packaged
identity path.

Minimum validation for the supported lane:

1. install the current local Windows dist
2. register package identity with:
   - `Install-Zide.ps1`
3. confirm package manifest contains:
   - `windows.comServer`
   - `windows.fileExplorerContextMenus`
4. right-click a file in Windows 11 and verify:
   - top-level `Zide`
   - submenu:
     - `Open in Zide`
     - `Open in Zide Editor`
5. right-click a directory in Windows 11 and verify:
   - top-level `Zide`
   - submenu:
     - `Open in Zide`
     - `Open Zide Terminal here`
6. right-click a folder background and verify:
   - direct `Open Zide Terminal here`
7. invoke the commands and confirm:
   - file -> correct launcher opens the selected file
   - folder -> `zide.exe` starts with that folder as startup cwd
   - terminal-here -> `zide-terminal.exe` opens in the selected cwd

## Current Result

Current local findings:

- external-location identity is not sufficient on the current Win11 machine for
  reliable top-level Explorer command activation
- full package registration from the installed payload is the supported lane
- packaged launch uses AUMIDs directly:
  - `LaurenceGuws.Zide_1gfq4x6kk79tm!Zide`
  - `LaurenceGuws.Zide_1gfq4x6kk79tm!ZideEditor`
  - `LaurenceGuws.Zide_1gfq4x6kk79tm!ZideTerminal`
- folder launch uses the narrow startup contract:
  - `zide.exe --folder <path>`
- multi-select stays hidden for now; it does not have a product contract yet

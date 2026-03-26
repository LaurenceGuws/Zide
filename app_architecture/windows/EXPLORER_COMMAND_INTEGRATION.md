# Windows Explorer Command Integration

Date: 2026-03-25

Purpose: define the packaged `IExplorerCommand` lane for top-level Windows 11
Explorer integration.

Use this with:

- `app_architecture/windows/NATIVE_SHELL_INTEGRATION.md`
- `app_architecture/windows/INSTALLATION.md`
- `docs/reference/windows_win11_shell_validation.md`
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
- multiple files:
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
- folder background:
  - top-level `Zide`
  - submenu:
    - `Open in Zide`
    - `Open Zide Terminal here`
- mixed file+folder selection:
  - hidden

## Reference Shape

Windows Terminal uses:

- packaged COM server
- `IExplorerCommand`
- `windows.comServer`
- `windows.fileExplorerContextMenus`

Reference files:

- `dev_references/terminals/windows_terminal/src/cascadia/ShellExtension/OpenTerminalHere.h`
- `dev_references/terminals/windows_terminal/src/cascadia/ShellExtension/OpenTerminalHere.cpp`
- `dev_references/terminals/windows_terminal/src/cascadia/ShellExtension/dllmain.cpp`
- `dev_references/terminals/windows_terminal/src/cascadia/CascadiaPackage/Package.appxmanifest`

The current Zide lane follows that same high-level model:

- in-proc COM DLL
- packaged through full local package registration from the installed payload
- separate top-level COM classes for:
  - file submenu
  - folder submenu
  - folder-background submenu

## Current Zide Implementation State

Current artifact:

- `zide-shell-ext.dll`

Current top-level COM classes:

- `ZideFileMenu`
  - CLSID: `7A4A9F94-7A56-4B72-9D3A-0E4F1A0E6E11`
- `ZideFolderMenu`
  - CLSID: `7D8E995A-2D37-48D8-AB12-4F03C6362D85`
- `ZideBackgroundMenu`
  - CLSID: `63FDDD2D-D152-47DA-A9A0-9D6D724DC7F9`

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

- packaged `Directory` commands may still be grouped under `Zide` by Win11 even
  when only one child remains visible for the active selection
- hide mixed file+folder selections instead of guessing
- hide non-filesystem shell items rather than inventing launch targets for
  libraries, search surfaces, or other virtual locations

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
6. right-click multiple directories in Windows 11 and verify:
   - top-level `Zide`
   - submenu:
     - `Open Zide Terminal here`
7. right-click a folder background and verify:
   - top-level `Zide`
   - submenu:
     - `Open in Zide`
     - `Open Zide Terminal here`
8. invoke the commands and confirm:
   - file -> correct launcher opens the selected file
   - multi-file -> correct launcher opens all selected files
   - folder -> `zide.exe` starts with that folder as startup cwd
   - multi-folder terminal -> `zide-terminal.exe` opens one terminal window with one tab per selected folder via repeated `--cwd`
   - terminal-here -> `zide-terminal.exe` opens in the selected cwd
9. verify mixed file+folder selection shows no Zide command

For the repeatable local operator checklist, use:

- `docs/reference/windows_win11_shell_validation.md`

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
- current multi-select product contract is:
  - multiple files -> `Zide` submenu for IDE/editor
  - multiple folders -> `Zide` submenu with terminal only
  - mixed files+folders -> hidden
- packaged registration now keeps multi-folder under `ZideFolderMenu` instead
  of a separate `Directory` verb, to avoid extra app-grouping layers on
  Desktop-like shell surfaces

# Windows Explorer Command Integration

Date: 2026-03-22

Purpose: define the first packaged `IExplorerCommand` cut for top-level Windows
11 Explorer integration.

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

## First Cut

The first command is intentionally narrow:

- `Open Zide Terminal here`

Scope:

- Explorer item type: `Directory`
- Explorer item type: `Directory\Background`
- launch target: `zide-terminal.exe --cwd <selected path>`

Non-goals for the first cut:

- no top-level file verbs yet for:
  - `Open in Zide`
  - `Open in Zide Editor`
- no multi-command submenu
- no folder/workspace-open IDE verb yet

Why this cut first:

- it matches the Windows Terminal reference shape closely
- it is the highest-value command for top-level Explorer presence
- it avoids forcing an IDE/editor workspace-open contract before that contract
  is product-ready cross-platform

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

The current Zide cut follows that same high-level model:

- in-proc COM DLL
- packaged by the external-location identity package
- one verb bound to directory and directory-background item types

## Current Zide Implementation State

Current first-cut artifact:

- `zide-shell-ext.dll`

Current COM class:

- CLSID: `4C5D89A5-4E56-48E0-AE5A-8F4A5C6D1972`

Current first-cut verb:

- `OpenZideTerminalHere`

Current build/runtime wiring:

- shell-extension DLL builds on Windows and installs beside the launchers
- installer writes shell-extension metadata into:
  - `support/windows-package-identity.json`
- package-identity registration generates:
  - `windows.comServer`
  - `windows.fileExplorerContextMenus`
- current item types:
  - `Directory`
  - `Directory\Background`

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

If future verbs are added, they should be separate clearly scoped commands, not
one monolithic shell-extension object with product logic embedded in it.

## Validation Lane

The shell-extension lane is only meaningful when tested through the packaged
identity path.

Minimum validation for this first cut:

1. install the current local Windows dist
2. register package identity with:
   - `Install-Zide.ps1`
3. confirm package manifest contains:
   - `windows.comServer`
   - `windows.fileExplorerContextMenus`
4. right-click a directory in Windows 11 and verify the top-level menu entry
5. right-click a folder background and verify the top-level menu entry
6. invoke the command and confirm `zide-terminal.exe` opens in the selected cwd

## Current Result

Current local Win11 result:

- external-location package identity registers successfully
- packaged COM registration exists
- classic verbs still work
- Explorer does not instantiate the packaged `IExplorerCommand` DLL from the
  external-location install model
- a self-contained full MSIX from the installed payload does work:
  - `Register-ZidePackageIdentity.ps1 -PackageMode Full`
  - top-level `Open Zide Terminal here` appears
  - the packaged command activates `ZideTerminal` by AUMID through
    `IApplicationActivationManager`

That is the key architectural boundary for this lane:

- external-location identity is a prerequisite
- top-level Win11 Explorer commands want the full-package lane on the current
  machine

Follow-up fixes already required on that path:

- full-package payload copy instead of metadata-only packing
- packaged terminal launch via:
  - `LaurenceGuws.Zide_1gfq4x6kk79tm!ZideTerminal`
- installed config/assets resolving relative to the packaged executable

## Next Likely Expansions

After the first command is stable:

1. top-level `Open in Zide Editor` for files
2. top-level `Open in Zide` once IDE/workspace open semantics are first-class
3. only after Explorer integration is stable, take the heavier default-terminal
   lane

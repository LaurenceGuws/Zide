# Win11 Explorer Command Reference

Date: 2026-03-25

Purpose: capture the reference shape for Zide's packaged Windows 11 Explorer
command lane and the menu structure we want to keep stable.

## What Windows Terminal Shows

Windows Terminal's shell extension is a single packaged `IExplorerCommand`
implementation in:

- `reference_repos/terminals/windows_terminal/src/cascadia/ShellExtension/OpenTerminalHere.cpp`
- `reference_repos/terminals/windows_terminal/src/cascadia/ShellExtension/OpenTerminalHere.h`
- `reference_repos/terminals/windows_terminal/src/cascadia/ShellExtension/dllmain.cpp`
- `reference_repos/terminals/windows_terminal/src/cascadia/CascadiaPackage/Package.appxmanifest`

The reference shape is simple:

- `OpenTerminalHere` implements `IExplorerCommand`
- the package manifest registers the COM server under `windows.comServer`
- the same manifest registers Explorer integration under
  `windows.fileExplorerContextMenus`
- the only registered item types are:
  - `Directory`
  - `Directory\\Background`

In `OpenTerminalHere.cpp`, the command:

- resolves the current Explorer target from the selection or site chain
- reads `SIGDN_FILESYSPATH`
- launches the terminal with a working directory derived from that path
- hides itself when the target is not a filesystem item
- does not declare any submenu surface
- returns `ECS_ENABLED` or `ECS_HIDDEN` based on the current target

## Menu Structure Pattern

The useful design lesson is not the exact Terminal title, but the shape of the
surface:

- a packaged COM command can be top-level and direct
- Explorer item types are the primary registration gate
- background support is explicit and separate from directory selection
- the shell extension itself should stay narrow and route only from Explorer
  target to process launch

For Zide, the current menu shape is:

- files:
  - top-level `Zide`
  - submenu entries for app/editor launchers
- folders:
  - top-level `Zide`
  - submenu entries for IDE and terminal launchers
- folder background:
  - direct `Open Zide Terminal here`

That split is preferable to a flat list of many unrelated top-level verbs.

## Item-Type Registration

The important registration lesson is how the item types map to behavior:

- `Directory` is for the folder object itself
- `Directory\\Background` is for the folder's background context
- `*` is appropriate for filesystem-backed file targets when the command should
  appear broadly across file types

For Zide, the relevant implementation and metadata are in:

- `src/platform/windows_shell_extension/open_zide_terminal_here.cpp`
- `tools/windows/windows_identity_contract.zig`
- `scripts/windows/Install-Zide.ps1`
- `scripts/windows/Register-ZidePackageIdentity.ps1`

Current Zide registration now models three top-level classes in the package
metadata:

- file submenu root
- folder submenu root
- direct folder-background terminal command

## Background Handling

Background handling should stay explicit and narrow.

Observed reference behavior:

- background support is only registered where the command truly needs the
  folder background
- the command still resolves the current location from the site/folder-view
  chain
- the path handling remains filesystem-based

For Zide, the background-specific terminal command is intentionally separate
from the folder submenu root so the menu can stay predictable and avoid
overloading one command with multiple product meanings.

## Multi-Select

The reference code does not advertise a rich multi-select contract.

In `OpenTerminalHere.cpp`:

- `GetBestLocationFromSelectionOrSite(...)` reads the selection array
- if a selection exists, it takes the first item
- `GetState(...)` only cares whether the resolved target is a filesystem item
- there is no submenu-level batch-open contract

In the current Zide implementation:

- `src/platform/windows_shell_extension/open_zide_terminal_here.cpp` currently
  hides multi-select by returning `ERROR_NOT_SUPPORTED` from the selection path
  when more than one item is chosen
- that makes multi-select an explicit product decision instead of a hidden
  accident

The open question for Zide is whether multi-select should remain hidden or gain
an explicit batch-open behavior later.

## Bottom Line

Use the packaged COM + manifest model, not classic registry verbs, for the Win11
surface.

Keep the menu deterministic:

- submenu when multiple relevant launchers exist
- direct command when only one action is meaningful
- explicit `Directory` and `Directory\\Background` registration
- no implied multi-select semantics until we define them on purpose

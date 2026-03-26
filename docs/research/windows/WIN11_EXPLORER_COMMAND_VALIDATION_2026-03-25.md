# Win11 Explorer Command Validation

Date: 2026-03-25

Purpose: capture the current packaged Windows 11 Explorer integration shape,
the validation ritual that proved it, and the remaining questions before the
lane is considered stable.

This is research and validation context, not design authority. The owning docs
remain:

- [app_architecture/windows/EXPLORER_COMMAND_INTEGRATION.md](../../../app_architecture/windows/EXPLORER_COMMAND_INTEGRATION.md)
- [app_architecture/windows/INSTALLATION.md](../../../app_architecture/windows/INSTALLATION.md)
- [docs/todo/windows/implementation.md](../../../docs/todo/windows/implementation.md)

## Current Supported Flow

The supported Windows shell path is the packaged Win11 Explorer command lane
backed by full package registration.

Current install and registration flow:

- build locally with `zig build`
- stage a local Windows dist with [`ops/windows/Stage-CurrentWindowsDist.ps1`](../../../ops/windows/Stage-CurrentWindowsDist.ps1)
- install from the staged dist with [`ops/windows/Install-Zide.ps1`](../../../ops/windows/Install-Zide.ps1)
- package identity is registered through [`ops/windows/Register-ZidePackageIdentity.ps1`](../../../ops/windows/Register-ZidePackageIdentity.ps1)
- uninstall cleanup remains owned by [`ops/windows/Uninstall-Zide.ps1`](../../../ops/windows/Uninstall-Zide.ps1)

Current menu shape:

- files:
  - top-level `Zide`
  - submenu entries:
    - `Open in Zide`
    - `Open in Zide Editor`
- multiple files:
  - top-level `Zide`
  - submenu entries:
    - `Open in Zide`
    - `Open in Zide Editor`
- folders:
  - top-level `Zide`
  - submenu entries:
    - `Open in Zide`
    - `Open Zide Terminal here`
- multiple folders:
  - top-level `Zide`
  - submenu entries:
    - `Open Zide Terminal here`
- folder background:
  - top-level `Zide`
  - submenu entries:
    - `Open in Zide`
    - `Open Zide Terminal here`

The shell-extension implementation lives in
[`src/platform/windows_shell_extension/open_zide_terminal_here.cpp`](../../../src/platform/windows_shell_extension/open_zide_terminal_here.cpp).

## Validation Ritual

The current manual ritual that matches the installed path is:

1. run `zig build`
2. stage a local dist with [`ops/windows/Stage-CurrentWindowsDist.ps1`](../../../ops/windows/Stage-CurrentWindowsDist.ps1)
3. install from the staged dist with [`ops/windows/Install-Zide.ps1`](../../../ops/windows/Install-Zide.ps1)
4. run the installer in an elevated shell when package trust needs to be added to the local machine cert stores
5. confirm `Get-AppxPackage LaurenceGuws.Zide` succeeds after install
6. verify the package metadata file at `%LOCALAPPDATA%\\Programs\\Zide\\current\\support\\windows-package-identity.json`
7. right-click a file and confirm the `Zide` submenu appears with file-launch entries
8. right-click a folder and confirm the `Zide` submenu appears with folder-launch entries
9. right-click multiple folders and confirm the `Zide` submenu appears with only the terminal command
10. right-click a folder background and confirm the `Zide` submenu appears
11. invoke each command and confirm the selected file/folder path reaches the expected launcher

The package identity script currently defaults to `-PackageMode Full`, which is the
supported path for Explorer command activation on the current Win11 machine.

## Known Gaps

- Multi-select now has a product contract, but still needs repeated manual confirmation.
- External-location package identity remains a comparison/troubleshooting mode,
  not the supported Explorer lane.
- The old classic per-user Explorer verbs are intentionally removed during
  install/uninstall cleanup, so legacy `Show more options` paths are not part of
  the supported menu story.
- Menu behavior still needs repeated manual confirmation after Explorer cache
  changes or machine restarts, because Win11 shell registration can be sticky.

## Next Verification Questions

1. Does the current `*`, `Directory`, and `Directory\\Background` registration
   stay stable across Explorer restarts and package re-registration?
2. Are there any item classes or shell locations where the submenu still needs
   special handling beyond the current packaged manifest shape?

## Reference Files

- [ops/windows/Install-Zide.ps1](../../../ops/windows/Install-Zide.ps1)
- [ops/windows/Register-ZidePackageIdentity.ps1](../../../ops/windows/Register-ZidePackageIdentity.ps1)
- [ops/windows/Uninstall-Zide.ps1](../../../ops/windows/Uninstall-Zide.ps1)
- [src/platform/windows_shell_extension/open_zide_terminal_here.cpp](../../../src/platform/windows_shell_extension/open_zide_terminal_here.cpp)
- [app_architecture/windows/EXPLORER_COMMAND_INTEGRATION.md](../../../app_architecture/windows/EXPLORER_COMMAND_INTEGRATION.md)
- [app_architecture/windows/INSTALLATION.md](../../../app_architecture/windows/INSTALLATION.md)
- [docs/todo/windows/implementation.md](../../../docs/todo/windows/implementation.md)

# Windows Win11 Shell Validation

Date: 2026-03-25

Purpose: define the one repeatable local ritual for validating Zide's packaged
Windows 11 Explorer integration.

Use this after changes to:

- `src/platform/windows_shell_extension/open_zide_terminal_here.cpp`
- `ops/windows/Install-Zide.ps1`
- `ops/windows/Register-ZidePackageIdentity.ps1`
- `tools/packaging/windows/windows_identity_contract.zig`

This is an operator checklist, not design authority. The owning contract lives
in:

- `app_architecture/windows/EXPLORER_COMMAND_INTEGRATION.md`
- `app_architecture/windows/INSTALLATION.md`

## Preconditions

- run from an elevated PowerShell session
- close all running `zide`, `zide-editor`, and `zide-terminal` processes
- use the current `windows` branch checkout unless the task explicitly says
  otherwise

## Build And Install Ritual

1. build:

```powershell
zig build
zig build test
```

2. stage a local dist:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\Stage-CurrentWindowsDist.ps1
```

3. install from the staged dist:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\Install-Zide.ps1 -ReleaseDistDir .\releases\v0.1.0-beta.4\windows-x86_64-local\dist
```

4. confirm package identity:

```powershell
Get-AppxPackage LaurenceGuws.Zide | Select-Object Name, PackageFamilyName, Version
```

5. confirm installed metadata shape:

```powershell
Get-Content $env:LOCALAPPDATA\Programs\Zide\current\support\windows-package-identity.json
```

Expected shell-extension verb ids:

- `ZideFileMenu`
- `ZideFolderMenu`
- `ZideBackgroundMenu`

## Explorer Manual Checks

1. single file:
   - expect `Zide` submenu
   - expect `Open in Zide`
   - expect `Open in Zide Editor`

2. multiple files:
   - expect `Zide` submenu
   - expect `Open in Zide`
   - expect `Open in Zide Editor`
   - launching should open all selected files

3. single folder:
   - expect `Zide` submenu
   - expect `Open in Zide`
   - expect `Open Zide Terminal here`

4. multiple folders:
   - expect `Zide` submenu
   - expect only `Open Zide Terminal here`
   - launching should open one terminal window with one tab per selected folder

5. folder background:
   - expect `Zide` submenu
   - expect `Open in Zide`
   - expect `Open Zide Terminal here`

6. mixed file + folder selection:
   - expect no Zide command

7. non-filesystem or virtual shell surfaces:
   - test examples:
     - `This PC`
     - `Quick access` / `Home`
     - library views
     - search result surfaces that are not normal filesystem folder views
   - expect no Zide command when Explorer cannot provide a stable filesystem
     path target

## If Behavior Looks Stale

1. restart Explorer:

```powershell
Stop-Process -Name explorer -Force
Start-Sleep -Seconds 2
Start-Process explorer.exe
```

2. re-run the install step

3. inspect shell-extension logging:

```powershell
Get-Content $env:LOCALAPPDATA\Zide\shell-extension.log -Tail 200
```

Useful signals:

- `GetState title=Zide state=2`
  - hidden
- `GetState title=... state=0`
  - enabled
- `InspectSelection unsupported non-filesystem item`
  - selection came from a virtual/non-filesystem shell item, so Zide should hide
- `InspectSelection background location is not filesystem-backed`
  - background surface did not resolve to a normal filesystem folder

## Current Known Reality

- Win11 may still present multiple-folder terminal launch under the `Zide`
  submenu even though only one child command remains visible.
- Treat the actual Explorer presentation as product truth unless the packaged
  manifest or shell-extension evidence proves otherwise.
- Zide intentionally hides on non-filesystem shell items because the launch
  contract is defined only for stable filesystem-backed files and directories.

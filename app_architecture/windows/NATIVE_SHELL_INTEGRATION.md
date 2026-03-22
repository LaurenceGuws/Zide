# Windows Native Shell Integration

Date: 2026-03-22

Purpose: define the Windows-native integration lanes beyond the current
per-user installer and classic shell verbs.

Use this document with:

- `app_architecture/windows/INSTALLATION.md`
- `docs/todo/windows/implementation.md`

## Current Baseline

Zide currently has:

- per-user install under `%LOCALAPPDATA%\Programs\Zide`
- per-user `App Paths` registration for:
  - `zide.exe`
  - `zide-editor.exe`
  - `zide-terminal.exe`
- classic per-user Explorer verbs:
  - `Open in Zide`
  - `Open in Zide Editor`
  - `Open Zide Terminal here`

This is the correct first installer-owned baseline.

It is not the same thing as first-class Win11 shell integration.

## Split The Problem Correctly

There are three distinct Windows integration levels:

1. Classic shell integration
2. Top-level Win11 Explorer context-menu integration
3. Default terminal registration

They should not be mixed together.

### 1. Classic shell integration

What we already have:

- registry verbs under `HKCU\Software\Classes\...`
- no COM
- no package identity
- no MSIX/App Extension requirement

Behavior:

- works as normal Windows shell integration
- on Windows 11 it appears under `Show more options`

This is acceptable and useful, but it is not the final Win11-native surface.

### 2. Top-level Win11 Explorer context-menu integration

Goal:

- show Zide actions in the top-level Windows 11 context menu, not only under
  `Show more options`

Current technical conclusion:

- this is not a registry-verb-only problem
- the correct Windows-native lane is `IExplorerCommand`
- package identity is part of the intended platform direction

Why:

- Microsoft guidance for Windows 11 context-menu integration points toward the
  newer Explorer command model, not more classic shell verbs
- the current classic registry path is specifically the reason our entries land
  under `Show more options`

Implication for Zide:

- if we want true top-level Win11 menu presence, we should treat it as a
  separate COM/package integration project
- do not keep stretching the installer-only registry lane in hopes that it will
  become top-level Win11 integration

### 3. Default terminal registration

Goal:

- have `Zide Terminal` appear in Windows' default terminal chooser and support
  delegated console launches the way Windows Terminal does

Current technical conclusion:

- this is much heavier than shell verbs
- it is not achieved by `App Paths` or simple installer registry writes
- Windows Terminal uses:
  - `HKCU\Console\%%Startup`
  - `DelegationConsole`
  - `DelegationTerminal`
  - COM
  - App Extension discovery
  - package identity

From the Windows Terminal reference:

- `DelegationConfig.cpp` discovers available console/terminal hosts through
  App Extension catalogs:
  - `com.microsoft.windows.console.host`
  - `com.microsoft.windows.terminal.host`
- the active choice is written through the per-user delegation keys:
  - `DelegationConsole`
  - `DelegationTerminal`
- the Windows Terminal package manifest declares those extensions in the APPX
  package

Implication for Zide:

- “default terminal” is a packaging/integration project, not an installer tweak
- it likely wants a formal Windows identity/package story before we attempt it

## Package Identity Is The Key Prerequisite

The most important shared prerequisite for both advanced lanes is package
identity.

Microsoft's supported bridge for a non-packaged desktop app is:

- package the app with external location
- register identity during install
- then use the Windows features that depend on package identity

Current Zide implementation state:

- launcher PE resources and runtime AppUserModelIDs already exist
- launcher binaries now also embed the `msix` identity metadata Windows expects
  in desktop application manifests
- the installer now writes package-identity metadata into the installed app
  layout, so identity registration can be performed from the install root
  without a repo checkout
- local/dev package identity registration is now handled by:
  - `scripts/windows/Register-ZidePackageIdentity.ps1`
  - `scripts/windows/Unregister-ZidePackageIdentity.ps1`
- the main installer can now invoke that registration path explicitly through:
  - `Install-Zide.ps1 -RegisterPackageIdentity`
- local/dev registration currently follows the Microsoft self-signed test path:
  - self-signed cert subject must match the package `Publisher`
  - package install trust must be added at machine scope
  - that means the dev registration script expects elevation when it must trust
    its own self-signed cert

For Zide, this means:

- current installer/runtime layout remains valid
- the install story now has a real external-location identity package path
- future Windows-native integration can build on that instead of inventing a
  second packaging model
- that package-identity lane should be designed once and then reused for:
  - top-level Win11 context menu integration
  - default terminal registration

## Recommended Execution Order

1. Keep the current classic installer verbs as the supported baseline.
2. Add package identity to the Windows install story without changing the app
   runtime layout.
3. Use that to pursue top-level Win11 Explorer integration first.
4. Only then attempt default terminal registration.

Why this order:

- top-level Explorer integration is smaller and more visible
- it forces us to learn the package/COM/registration shape on a narrower
  problem
- default terminal registration is more Windows-specific and pulls in more
  moving pieces at once

## Non-Goals For The Current Installer Lane

The following are explicitly not “just one more installer tweak”:

- top-level Win11 context-menu placement
- default terminal chooser integration
- App Extension registration
- COM host registration for these advanced shell scenarios

If we take those on, they should be tracked as first-class Windows-native
integration projects.

## References

Primary Windows docs:

- `IExplorerCommand` / shell integration guidance:
  - `https://learn.microsoft.com/en-us/windows/win32/shell/shortcut-choose-method`
  - `https://learn.microsoft.com/en-us/windows/win32/shell/context-menu-handlers`
- package identity for non-packaged desktop apps:
  - `https://learn.microsoft.com/en-us/windows/apps/desktop/modernize/grant-identity-to-nonpackaged-apps`
- Windows 11 app best-practices guidance:
  - `https://learn.microsoft.com/en-us/windows/apps/get-started/best-practices`

Reference implementation:

- Windows Terminal default terminal spec:
  - `reference_repos/terminals/windows_terminal/doc/specs/#492 - Default Terminal/spec.md`
- Windows Terminal delegation config:
  - `reference_repos/terminals/windows_terminal/src/propslib/DelegationConfig.cpp`
- Windows Terminal default terminal model:
  - `reference_repos/terminals/windows_terminal/src/cascadia/TerminalSettingsModel/DefaultTerminal.h`
- Windows Terminal shell extension surface:
  - `reference_repos/terminals/windows_terminal/src/cascadia/ShellExtension/`

## Bottom Line

Zide now has a good native installer baseline.

The next Windows-native steps are not “more registry verbs”.

They are:

- package identity
- `IExplorerCommand` for top-level Win11 Explorer integration
- App Extension / delegation work for default terminal registration

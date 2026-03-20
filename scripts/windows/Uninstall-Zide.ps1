param(
    [string]$InstallDir,
    [string]$ProgramsRoot = (Join-Path $env:LOCALAPPDATA "Programs\\Zide"),
    [string]$StartMenuDir = (Join-Path $env:APPDATA "Microsoft\\Windows\\Start Menu\\Programs\\Zide"),
    [string]$StateRoot = (Join-Path $env:LOCALAPPDATA "Zide"),
    [string]$ConfigRoot = (Join-Path $env:APPDATA "Zide"),
    [switch]$RemoveUserData
)

$ErrorActionPreference = "Stop"

function Remove-IfExists {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
}

function Get-ResolvedPathOrNull {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    return (Resolve-Path -LiteralPath $Path).ProviderPath
}

function Start-DeferredProgramsRootCleanup {
    param([string]$Root)

    $cleanupScript = Join-Path ([System.IO.Path]::GetTempPath()) ("zide-uninstall-" + [System.Guid]::NewGuid().ToString("N") + ".ps1")
    @"
Start-Sleep -Seconds 1
if (Test-Path -LiteralPath '$Root') {
    \$children = Get-ChildItem -LiteralPath '$Root' -Force
    if (\$children.Count -eq 0) {
        Remove-Item -LiteralPath '$Root' -Recurse -Force
    }
}
Remove-Item -LiteralPath '$cleanupScript' -Force -ErrorAction SilentlyContinue
"@ | Set-Content -LiteralPath $cleanupScript -Encoding ascii

    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        $cleanupScript
    ) | Out-Null
}

if (-not $InstallDir) {
    throw "InstallDir is required"
}

$resolvedInstallDir = Get-ResolvedPathOrNull -Path $InstallDir
if (-not $resolvedInstallDir) {
    throw "missing install directory: $InstallDir"
}

$currentRoot = Join-Path $ProgramsRoot "current"
$currentItem = Get-Item -LiteralPath $currentRoot -ErrorAction SilentlyContinue
if ($currentItem) {
    $currentTarget = $null
    if ($currentItem.PSObject.Properties.Match("ResolvedTarget").Count -gt 0 -and $currentItem.ResolvedTarget) {
        $currentTarget = $currentItem.ResolvedTarget
    } elseif ($currentItem.PSObject.Properties.Match("Target").Count -gt 0 -and $currentItem.Target) {
        $currentTarget = $currentItem.Target
    }

    if (($null -eq $currentTarget) -or ([System.IO.Path]::GetFullPath($currentTarget) -eq [System.IO.Path]::GetFullPath($resolvedInstallDir))) {
        Remove-IfExists $currentRoot
    }
}

Remove-IfExists $StartMenuDir
Remove-IfExists $resolvedInstallDir

$registryKey = "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Zide"
if (Test-Path -LiteralPath $registryKey) {
    Remove-Item -LiteralPath $registryKey -Recurse -Force
}

if ($RemoveUserData) {
    Remove-IfExists $StateRoot
    Remove-IfExists $ConfigRoot
}

$rootUninstaller = Join-Path $ProgramsRoot "Uninstall-Zide.ps1"
if (Test-Path -LiteralPath $rootUninstaller) {
    $remaining = Get-ChildItem -LiteralPath $ProgramsRoot -Force | Where-Object { $_.Name -ne "Uninstall-Zide.ps1" }
    if ($remaining.Count -eq 0) {
        Remove-Item -LiteralPath $rootUninstaller -Force
        Start-DeferredProgramsRootCleanup -Root $ProgramsRoot
    }
}

Write-Host "Uninstalled Zide from $resolvedInstallDir"

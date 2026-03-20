param(
    [string]$Version,
    [string]$Tag,
    [string]$Repo = "LaurenceGuws/Zide",
    [string]$ReleaseDistDir,
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA "Programs\\Zide"),
    [string]$StateRoot = (Join-Path $env:LOCALAPPDATA "Zide"),
    [string]$ConfigRoot = (Join-Path $env:APPDATA "Zide"),
    [string]$StartMenuRoot = (Join-Path $env:APPDATA "Microsoft\\Windows\\Start Menu\\Programs"),
    [string]$TerminalIconPng,
    [string]$ShellPath,
    [string]$LaunchCwd,
    [switch]$SkipHashVerification,
    [switch]$NoStartMenu,
    [switch]$NoUninstallRegistration
)

$ErrorActionPreference = "Stop"

function Get-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).ProviderPath
}

function Get-VersionFromBuildZon {
    param([string]$RepoRoot)
    $match = Select-String -Path (Join-Path $RepoRoot "build.zig.zon") -Pattern '\.version = "([^"]+)"' | Select-Object -First 1
    if (-not $match) {
        throw "failed to derive version from build.zig.zon"
    }
    return $match.Matches[0].Groups[1].Value
}

function Get-ReleaseAssetMap {
    param(
        [string]$Version,
        [string]$Tag
    )

    return @{
        IdeBundle = "zide-ide-bundle-$Version-windows-x86_64.zip"
        EditorBundle = "zide-editor-bundle-$Version-windows-x86_64.zip"
        TerminalBundle = "zide-terminal-bundle-$Version-windows-x86_64.zip"
        Checksums = "SHA256SUMS-windows-x86_64.txt"
        BaseUrl = "https://github.com/$Repo/releases/download/$Tag"
    }
}

function New-Directory {
    param([string]$Path)
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
}

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

function Read-Sha256File {
    param([string]$Path)
    $map = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^([0-9A-Fa-f]{64}) \*(.+)$') {
            $map[$matches[2]] = $matches[1].ToLowerInvariant()
        }
    }
    return $map
}

function Assert-ExpectedHash {
    param(
        [string]$FilePath,
        [hashtable]$ExpectedHashes
    )
    $name = Split-Path -Leaf $FilePath
    if (-not $ExpectedHashes.ContainsKey($name)) {
        throw "missing hash entry for $name"
    }
    $actual = (Get-FileHash -LiteralPath $FilePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $ExpectedHashes[$name]) {
        throw "SHA256 mismatch for $name"
    }
}

function Save-ReleaseAsset {
    param(
        [string]$SourcePath,
        [string]$DestinationPath
    )
    Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath -Force
}

function Download-ReleaseAsset {
    param(
        [string]$Url,
        [string]$DestinationPath
    )
    Invoke-WebRequest -Uri $Url -OutFile $DestinationPath
}

function Copy-ChildItems {
    param(
        [string]$SourceDir,
        [string]$DestinationDir
    )
    if (-not (Test-Path -LiteralPath $SourceDir)) {
        throw "missing source directory: $SourceDir"
    }
    New-Directory $DestinationDir
    Get-ChildItem -LiteralPath $SourceDir -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $DestinationDir -Recurse -Force
    }
}

function Write-PngAsIco {
    param(
        [string]$PngPath,
        [string]$IcoPath
    )

    if (-not (Test-Path -LiteralPath $PngPath)) {
        throw "missing PNG source for icon: $PngPath"
    }

    $pngBytes = [System.IO.File]::ReadAllBytes($PngPath)
    $stream = [System.IO.MemoryStream]::new()
    $writer = [System.IO.BinaryWriter]::new($stream)
    try {
        $writer.Write([UInt16]0)
        $writer.Write([UInt16]1)
        $writer.Write([UInt16]1)
        $writer.Write([Byte]0)
        $writer.Write([Byte]0)
        $writer.Write([Byte]0)
        $writer.Write([Byte]0)
        $writer.Write([UInt16]1)
        $writer.Write([UInt16]32)
        $writer.Write([UInt32]$pngBytes.Length)
        $writer.Write([UInt32]22)
        $writer.Write($pngBytes)
        [System.IO.File]::WriteAllBytes($IcoPath, $stream.ToArray())
    } finally {
        $writer.Dispose()
        $stream.Dispose()
    }
}

function Set-Shortcut {
    param(
        [string]$ShortcutPath,
        [string]$TargetPath,
        [string]$WorkingDirectory,
        [string]$IconPath,
        [string]$Arguments,
        [string]$AppUserModelId
    )

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($ShortcutPath)
    $shortcut.TargetPath = $TargetPath
    $shortcut.WorkingDirectory = $WorkingDirectory
    $shortcut.Arguments = if ($Arguments) { $Arguments } else { "" }
    if ($IconPath) {
        $shortcut.IconLocation = $IconPath
    }
    $shortcut.Save()
    if ($AppUserModelId) {
        Set-ShortcutAppUserModelId -ShortcutPath $ShortcutPath -AppUserModelId $AppUserModelId
    }
}

function Quote-ShortcutArgument {
    param([string]$Value)
    return '"' + $Value.Replace('"', '\"') + '"'
}

function Build-LaunchArguments {
    param(
        [string]$ShellPath,
        [string]$LaunchCwd
    )

    $parts = @()
    if ($ShellPath) {
        $parts += "--shell $(Quote-ShortcutArgument $ShellPath)"
    }
    if ($LaunchCwd) {
        $parts += "--cwd $(Quote-ShortcutArgument $LaunchCwd)"
    }
    return ($parts -join " ")
}

function Initialize-ShortcutAppUserModelInterop {
    if ("Zide.ShortcutPropertyStore" -as [type]) {
        return
    }

    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace Zide {
    [ComImport, Guid("00021401-0000-0000-C000-000000000046")]
    public class ShellLink {}

    [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99")]
    public interface IPropertyStore {
        uint GetCount(out uint cProps);
        uint GetAt(uint iProp, out PROPERTYKEY pkey);
        uint GetValue(ref PROPERTYKEY key, out PROPVARIANT pv);
        uint SetValue(ref PROPERTYKEY key, ref PROPVARIANT pv);
        uint Commit();
    }

    [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("0000010b-0000-0000-C000-000000000046")]
    public interface IPersistFile {
        void GetClassID(out Guid pClassID);
        void IsDirty();
        void Load([MarshalAs(UnmanagedType.LPWStr)] string pszFileName, uint dwMode);
        void Save([MarshalAs(UnmanagedType.LPWStr)] string pszFileName, bool fRemember);
        void SaveCompleted([MarshalAs(UnmanagedType.LPWStr)] string pszFileName);
        void GetCurFile([MarshalAs(UnmanagedType.LPWStr)] out string ppszFileName);
    }

    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    public struct PROPERTYKEY {
        public Guid fmtid;
        public uint pid;

        public PROPERTYKEY(Guid fmtid, uint pid) {
            this.fmtid = fmtid;
            this.pid = pid;
        }
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct PROPVARIANT {
        public ushort vt;
        public ushort wReserved1;
        public ushort wReserved2;
        public ushort wReserved3;
        public IntPtr pwszVal;
        public int extra;

        public static PROPVARIANT FromString(string value) {
            var pv = new PROPVARIANT();
            pv.vt = 31; // VT_LPWSTR
            pv.pwszVal = Marshal.StringToCoTaskMemUni(value);
            return pv;
        }
    }

    public static class ShortcutPropertyStore {
        private static readonly PROPERTYKEY AppUserModelIdKey =
            new PROPERTYKEY(new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3"), 5);

        [DllImport("ole32.dll")]
        private static extern int PropVariantClear(ref PROPVARIANT pvar);

        public static void SetAppUserModelId(string shortcutPath, string appUserModelId) {
            var persist = (IPersistFile)(new ShellLink());
            persist.Load(shortcutPath, 2);
            var store = (IPropertyStore)persist;
            var value = PROPVARIANT.FromString(appUserModelId);
            var key = AppUserModelIdKey;
            try {
                int hr = unchecked((int)store.SetValue(ref key, ref value));
                if (hr != 0) Marshal.ThrowExceptionForHR(hr);
                hr = unchecked((int)store.Commit());
                if (hr != 0) Marshal.ThrowExceptionForHR(hr);
                persist.Save(shortcutPath, true);
            } finally {
                PropVariantClear(ref value);
            }
        }

        public static string GetAppUserModelId(string shortcutPath) {
            var persist = (IPersistFile)(new ShellLink());
            persist.Load(shortcutPath, 0);
            var store = (IPropertyStore)persist;
            var key = AppUserModelIdKey;
            var value = new PROPVARIANT();
            int hr = unchecked((int)store.GetValue(ref key, out value));
            if (hr != 0) Marshal.ThrowExceptionForHR(hr);
            try {
                if (value.vt == 31 && value.pwszVal != IntPtr.Zero) {
                    return Marshal.PtrToStringUni(value.pwszVal);
                }
                return null;
            } finally {
                PropVariantClear(ref value);
            }
        }
    }
}
"@
}

function Set-ShortcutAppUserModelId {
    param(
        [string]$ShortcutPath,
        [string]$AppUserModelId
    )

    Initialize-ShortcutAppUserModelInterop
    [Zide.ShortcutPropertyStore]::SetAppUserModelId($ShortcutPath, $AppUserModelId)
}

function Get-ShortcutAppUserModelId {
    param([string]$ShortcutPath)

    Initialize-ShortcutAppUserModelInterop
    return [Zide.ShortcutPropertyStore]::GetAppUserModelId($ShortcutPath)
}

if (-not $Version) {
    $Version = Get-VersionFromBuildZon -RepoRoot (Get-RepoRoot)
}
if (-not $Tag) {
    $Tag = "v$Version"
}
if (-not $TerminalIconPng) {
    $repoTerminalIcon = Join-Path (Get-RepoRoot) "assets\\icon\\zide_terminal_taskbar.png"
    if (Test-Path -LiteralPath $repoTerminalIcon) {
        $TerminalIconPng = $repoTerminalIcon
    }
}

$assetMap = Get-ReleaseAssetMap -Version $Version -Tag $Tag
$versionRoot = Join-Path $InstallRoot $Version
$currentRoot = Join-Path $InstallRoot "current"
$startMenuDir = Join-Path $StartMenuRoot "Zide"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("zide-install-" + [System.Guid]::NewGuid().ToString("N"))
$downloadsDir = Join-Path $tempRoot "downloads"
$extractRoot = Join-Path $tempRoot "extract"
$iconsDir = Join-Path $versionRoot "icons"
$shortcutArguments = Build-LaunchArguments -ShellPath $ShellPath -LaunchCwd $LaunchCwd

try {
    New-Directory $downloadsDir
    New-Directory $extractRoot

    $assets = @(
        $assetMap.IdeBundle,
        $assetMap.EditorBundle,
        $assetMap.TerminalBundle,
        $assetMap.Checksums
    )

    foreach ($asset in $assets) {
        $destination = Join-Path $downloadsDir $asset
        if ($ReleaseDistDir) {
            $source = Join-Path $ReleaseDistDir $asset
            if (-not (Test-Path -LiteralPath $source)) {
                throw "missing local release asset: $source"
            }
            Save-ReleaseAsset -SourcePath $source -DestinationPath $destination
        } else {
            Download-ReleaseAsset -Url "$($assetMap.BaseUrl)/$asset" -DestinationPath $destination
        }
    }

    if (-not $SkipHashVerification) {
        $expectedHashes = Read-Sha256File -Path (Join-Path $downloadsDir $assetMap.Checksums)
        foreach ($asset in @($assetMap.IdeBundle, $assetMap.EditorBundle, $assetMap.TerminalBundle)) {
            Assert-ExpectedHash -FilePath (Join-Path $downloadsDir $asset) -ExpectedHashes $expectedHashes
        }
    }

    $ideExtract = Join-Path $extractRoot "ide"
    $editorExtract = Join-Path $extractRoot "editor"
    $terminalExtract = Join-Path $extractRoot "terminal"
    Expand-Archive -LiteralPath (Join-Path $downloadsDir $assetMap.IdeBundle) -DestinationPath $ideExtract -Force
    Expand-Archive -LiteralPath (Join-Path $downloadsDir $assetMap.EditorBundle) -DestinationPath $editorExtract -Force
    Expand-Archive -LiteralPath (Join-Path $downloadsDir $assetMap.TerminalBundle) -DestinationPath $terminalExtract -Force

    Remove-IfExists $versionRoot
    New-Directory $versionRoot
    Copy-ChildItems -SourceDir $ideExtract -DestinationDir $versionRoot

    Copy-Item -LiteralPath (Join-Path $editorExtract "zide-editor.exe") -Destination $versionRoot -Force
    Copy-Item -LiteralPath (Join-Path $terminalExtract "zide-terminal.exe") -Destination $versionRoot -Force

    if ($TerminalIconPng) {
        $installedTerminalPng = Join-Path $versionRoot "assets\\icon\\zide_terminal_taskbar.png"
        if (-not (Test-Path -LiteralPath $installedTerminalPng)) {
            Copy-Item -LiteralPath $TerminalIconPng -Destination $installedTerminalPng -Force
        }
    }

    New-Directory $InstallRoot
    New-Directory $ConfigRoot
    New-Directory $StateRoot
    New-Directory $iconsDir

    $appIconPng = Join-Path $versionRoot "assets\\icon\\color_icon.png"
    $terminalIconInstalledPng = Join-Path $versionRoot "assets\\icon\\zide_terminal_taskbar.png"
    $appIconIco = Join-Path $iconsDir "zide.ico"
    $terminalIconIco = Join-Path $iconsDir "zide-terminal.ico"
    Write-PngAsIco -PngPath $appIconPng -IcoPath $appIconIco
    if (Test-Path -LiteralPath $terminalIconInstalledPng) {
        Write-PngAsIco -PngPath $terminalIconInstalledPng -IcoPath $terminalIconIco
    } else {
        Copy-Item -LiteralPath $appIconIco -Destination $terminalIconIco -Force
    }

    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "Uninstall-Zide.ps1") -Destination (Join-Path $InstallRoot "Uninstall-Zide.ps1") -Force

    Remove-IfExists $currentRoot
    New-Item -ItemType Junction -Path $currentRoot -Target $versionRoot | Out-Null

    if (-not $NoStartMenu) {
        New-Directory $startMenuDir
        Set-Shortcut -ShortcutPath (Join-Path $startMenuDir "Zide.lnk") -TargetPath (Join-Path $currentRoot "zide.exe") -WorkingDirectory $currentRoot -IconPath $appIconIco -Arguments $shortcutArguments -AppUserModelId "LaurenceGuws.Zide"
        Set-Shortcut -ShortcutPath (Join-Path $startMenuDir "Zide Editor.lnk") -TargetPath (Join-Path $currentRoot "zide-editor.exe") -WorkingDirectory $currentRoot -IconPath $appIconIco -Arguments $shortcutArguments -AppUserModelId "LaurenceGuws.Zide.Editor"
        Set-Shortcut -ShortcutPath (Join-Path $startMenuDir "Zide Terminal.lnk") -TargetPath (Join-Path $currentRoot "zide-terminal.exe") -WorkingDirectory $currentRoot -IconPath $terminalIconIco -Arguments $shortcutArguments -AppUserModelId "LaurenceGuws.Zide.Terminal"
    }

    if (-not $NoUninstallRegistration) {
        $registryKey = "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Zide"
        $uninstallScript = Join-Path $InstallRoot "Uninstall-Zide.ps1"
        $displayIcon = Join-Path $currentRoot "zide.exe"
        $uninstallArgs = @(
            "-NoProfile"
            "-ExecutionPolicy"
            "Bypass"
            "-File"
            ('"{0}"' -f $uninstallScript)
            "-InstallDir"
            ('"{0}"' -f $versionRoot)
            "-ProgramsRoot"
            ('"{0}"' -f $InstallRoot)
            "-StartMenuDir"
            ('"{0}"' -f $startMenuDir)
            "-StateRoot"
            ('"{0}"' -f $StateRoot)
            "-ConfigRoot"
            ('"{0}"' -f $ConfigRoot)
        ) -join " "

        New-Item -Path $registryKey -Force | Out-Null
        Set-ItemProperty -Path $registryKey -Name "DisplayName" -Value "Zide"
        Set-ItemProperty -Path $registryKey -Name "DisplayVersion" -Value $Version
        Set-ItemProperty -Path $registryKey -Name "Publisher" -Value "Laurence"
        Set-ItemProperty -Path $registryKey -Name "InstallLocation" -Value $versionRoot
        Set-ItemProperty -Path $registryKey -Name "DisplayIcon" -Value $displayIcon
        Set-ItemProperty -Path $registryKey -Name "UninstallString" -Value ("powershell.exe " + $uninstallArgs)
        Set-ItemProperty -Path $registryKey -Name "QuietUninstallString" -Value ("powershell.exe " + $uninstallArgs)
        Set-ItemProperty -Path $registryKey -Name "NoModify" -Value 1 -Type DWord
        Set-ItemProperty -Path $registryKey -Name "NoRepair" -Value 1 -Type DWord
    }

    Write-Host "Installed Zide $Version"
    Write-Host "Install root: $versionRoot"
    Write-Host "Current link: $currentRoot"
    Write-Host "Config root: $ConfigRoot"
    Write-Host "State root: $StateRoot"
    if ($ShellPath) {
        Write-Host "Terminal shell: $ShellPath"
    }
    if ($LaunchCwd) {
        Write-Host "Terminal start dir: $LaunchCwd"
    }
    if (-not $NoStartMenu) {
        Write-Host "Start Menu: $startMenuDir"
    }
} finally {
    Remove-IfExists $tempRoot
}

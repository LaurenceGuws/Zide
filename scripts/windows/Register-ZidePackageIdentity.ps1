param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA "Programs\\Zide\\current"),
    [string]$OutputRoot = (Join-Path $env:LOCALAPPDATA "Zide\\package-identity"),
    [string]$CertSubject = "CN=Laurence",
    [ValidateSet("External", "Full")]
    [string]$PackageMode = "Full",
    [string]$MakeAppxPath,
    [string]$SignToolPath,
    [string]$MetadataPath
)

$ErrorActionPreference = "Stop"

function Assert-ZideProcessesNotRunning {
    $running = Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -in @("zide", "zide-editor", "zide-terminal")
    }
    if ($running) {
        $names = ($running | ForEach-Object { $_.ProcessName } | Sort-Object -Unique) -join ", "
        throw "running Zide processes detected ($names); close them before registering package identity"
    }
}

function Get-FriendlyDeploymentHint {
    param([Guid]$ActivityId)

    try {
        $events = Get-AppPackageLog -ActivityID $ActivityId -ErrorAction Stop
    } catch {
        return $null
    }

    if ($events | Where-Object { $_.Message -like "*PackagesInUseClosed*" -or $_.Message -like "*Failed to initialize PLM*" }) {
        return "package deployment was blocked because Zide or a related packaged process was still in use; close all Zide windows/processes and retry"
    }

    return $null
}

function Resolve-LatestSdkTool {
    param([string]$ToolName)

    if ($ToolName -eq "makeappx.exe" -and $MakeAppxPath) { return $MakeAppxPath }
    if ($ToolName -eq "signtool.exe" -and $SignToolPath) { return $SignToolPath }

    $kitsRoot = "C:\Program Files (x86)\Windows Kits\10\bin"
    $matches = Get-ChildItem -LiteralPath $kitsRoot -Recurse -Filter $ToolName -ErrorAction Stop |
        Where-Object { $_.FullName -match "\\x64\\" } |
        Sort-Object FullName -Descending
    if ($matches.Count -eq 0) {
        throw "failed to find $ToolName under $kitsRoot"
    }
    return $matches[0].FullName
}

function Get-OrCreateCodeSigningCert {
    param([string]$Subject)

    $store = [System.Security.Cryptography.X509Certificates.X509Store]::new(
        [System.Security.Cryptography.X509Certificates.StoreName]::My,
        [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser)
    $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
    try {
        $existing = $store.Certificates |
            Where-Object { $_.Subject -eq $Subject } |
            Sort-Object NotAfter -Descending |
            Select-Object -First 1
        if ($existing) {
            return $existing
        }
    } finally {
        $store.Close()
    }

    return New-SelfSignedCertificate `
        -Type Custom `
        -KeyUsage DigitalSignature `
        -Subject $Subject `
        -FriendlyName "Zide Package Identity Dev" `
        -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3", "2.5.29.19={text}") `
        -CertStoreLocation "Cert:\CurrentUser\My"
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-CertTrusted {
    param([System.Security.Cryptography.X509Certificates.X509Certificate2]$Cert)

    if (-not (Test-IsAdministrator)) {
        throw "package identity registration with a self-signed certificate requires an elevated PowerShell session so the certificate can be trusted under LocalMachine Root and TrustedPeople"
    }

    $tempCer = Join-Path ([System.IO.Path]::GetTempPath()) ("zide-identity-" + [System.Guid]::NewGuid().ToString("N") + ".cer")
    try {
        Export-Certificate -Cert $Cert -FilePath $tempCer | Out-Null
        Add-CertToStoreIfMissing -CertPath $tempCer -StoreName TrustedPeople
        Add-CertToStoreIfMissing -CertPath $tempCer -StoreName Root
    } finally {
        if (Test-Path -LiteralPath $tempCer) {
            Remove-Item -LiteralPath $tempCer -Force
        }
    }
}

function Add-CertToStoreIfMissing {
    param(
        [string]$CertPath,
        [ValidateSet("TrustedPeople", "Root")]
        [string]$StoreName
    )

    $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($CertPath)
    $store = [System.Security.Cryptography.X509Certificates.X509Store]::new(
        [System.Security.Cryptography.X509Certificates.StoreName]::$StoreName,
        [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine)
    $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
    try {
        $existing = $store.Certificates |
            Where-Object { $_.Thumbprint -eq $cert.Thumbprint } |
            Select-Object -First 1
        if (-not $existing) {
            $store.Add($cert)
        }
    } finally {
        $store.Close()
        $cert.Dispose()
    }
}

function Get-IdentityMetadata {
    param([string]$JsonPath)

    return Get-Content -LiteralPath $JsonPath -Raw | ConvertFrom-Json
}

function Copy-InstallPayloadToLayout {
    param(
        [string]$SourceDir,
        [string]$DestinationDir
    )

    Get-ChildItem -LiteralPath $SourceDir -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $DestinationDir -Recurse -Force
    }
}

function Write-AppxManifest {
    param(
        [string]$ManifestPath,
        $Identity,
        [bool]$AllowExternalContent
    )

    $applications = foreach ($application in $Identity.applications) {
        $applicationExtensions = ""
        if (($Identity.PSObject.Properties.Name -contains "shell_extensions") -and ($application.package_application_id -eq "ZideTerminal")) {
            $comClasses = foreach ($shellExtension in $Identity.shell_extensions) {
@"
              <com:Class Id="$($shellExtension.clsid)" Path="$($Identity.shell_extension_dll_name)" ThreadingModel="STA"/>
"@
            }

            $contextMenus = foreach ($shellExtension in $Identity.shell_extensions) {
                foreach ($itemType in $shellExtension.item_types) {
@"
            <desktop5:ItemType Type="$itemType">
              <desktop5:Verb Id="$($shellExtension.verb_id)" Clsid="$($shellExtension.clsid)"/>
            </desktop5:ItemType>
"@
                }
            }

            $applicationExtensions = @"
      <Extensions>
        <com:Extension Category="windows.comServer">
          <com:ComServer>
            <com:SurrogateServer DisplayName="Zide">
$(($comClasses -join "`n"))
            </com:SurrogateServer>
          </com:ComServer>
        </com:Extension>
        <desktop4:Extension Category="windows.fileExplorerContextMenus">
          <desktop4:FileExplorerContextMenus>
$(($contextMenus -join "`n"))
          </desktop4:FileExplorerContextMenus>
        </desktop4:Extension>
      </Extensions>
"@
        }
@"
    <Application Id="$($application.package_application_id)" Executable="$($application.executable)" uap10:TrustLevel="mediumIL" uap10:RuntimeBehavior="win32App">
      <uap:VisualElements AppListEntry="none" DisplayName="$($application.display_name)" Description="$($application.package_description)" BackgroundColor="transparent" Square150x150Logo="$($application.icon_png_path)" Square44x44Logo="$($application.icon_png_path)"/>
$applicationExtensions
    </Application>
"@
    }

    $manifest = @"
<?xml version="1.0" encoding="utf-8"?>
<Package IgnorableNamespaces="uap uap10 rescap com desktop4 desktop5"
  xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10"
  xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10"
  xmlns:uap10="http://schemas.microsoft.com/appx/manifest/uap/windows10/10"
  xmlns:rescap="http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities"
  xmlns:com="http://schemas.microsoft.com/appx/manifest/com/windows10"
  xmlns:desktop4="http://schemas.microsoft.com/appx/manifest/desktop/windows10/4"
  xmlns:desktop5="http://schemas.microsoft.com/appx/manifest/desktop/windows10/5">
  <Identity Name="$($Identity.package_name)" Publisher="$($Identity.publisher)" Version="$($Identity.package_version)" ProcessorArchitecture="neutral"/>
  <Properties>
    <DisplayName>$($Identity.display_name)</DisplayName>
    <PublisherDisplayName>$($Identity.publisher_display_name)</PublisherDisplayName>
    <Logo>assets\icon\color_icon.png</Logo>
    <uap10:AllowExternalContent>$($AllowExternalContent.ToString().ToLowerInvariant())</uap10:AllowExternalContent>
  </Properties>
  <Resources>
    <Resource Language="en-us"/>
  </Resources>
  <Dependencies>
    <TargetDeviceFamily Name="Windows.Desktop" MinVersion="$($Identity.min_version)" MaxVersionTested="$($Identity.max_version_tested)"/>
  </Dependencies>
  <Capabilities>
    <rescap:Capability Name="runFullTrust"/>
    <rescap:Capability Name="unvirtualizedResources"/>
  </Capabilities>
  <Applications>
$($applications -join "`n")
  </Applications>
</Package>
"@

    Set-Content -LiteralPath $ManifestPath -Value $manifest -Encoding utf8
}

$resolvedInstallDir = (Resolve-Path -LiteralPath $InstallDir).ProviderPath
Assert-ZideProcessesNotRunning
$makeAppx = Resolve-LatestSdkTool -ToolName "makeappx.exe"
$signTool = Resolve-LatestSdkTool -ToolName "signtool.exe"

$layoutDir = Join-Path $OutputRoot ("layout-" + [System.Guid]::NewGuid().ToString("N"))
$packagePath = Join-Path $OutputRoot "zide-identity.msix"
if (-not $MetadataPath) {
    $MetadataPath = Join-Path $resolvedInstallDir "support\\windows-package-identity.json"
}
$identityJson = (Resolve-Path -LiteralPath $MetadataPath).ProviderPath

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
$identity = Get-IdentityMetadata -JsonPath $identityJson
New-Item -ItemType Directory -Force -Path $layoutDir | Out-Null

if ($PackageMode -eq "Full") {
    Copy-InstallPayloadToLayout -SourceDir $resolvedInstallDir -DestinationDir $layoutDir
    foreach ($requiredPath in @(
        "zide.exe",
        "zide-editor.exe",
        "zide-terminal.exe",
        "zide-shell-ext.dll",
        "assets\\icon\\color_icon.png",
        "assets\\icon\\zide_terminal_taskbar.png"
    )) {
        if (-not (Test-Path -LiteralPath (Join-Path $layoutDir $requiredPath))) {
            throw "full package layout is missing required payload: $requiredPath"
        }
    }
}

Copy-Item -LiteralPath $identityJson -Destination (Join-Path $layoutDir "identity.json") -Force
Write-AppxManifest -ManifestPath (Join-Path $layoutDir "AppxManifest.xml") -Identity $identity -AllowExternalContent:($PackageMode -eq "External")

$existing = Get-AppxPackage $identity.package_name -ErrorAction SilentlyContinue
if ($existing) {
    $existing | Remove-AppxPackage
}

if (Test-Path -LiteralPath $packagePath) {
    Remove-Item -LiteralPath $packagePath -Force
}

& $makeAppx pack /o /d $layoutDir /nv /p $packagePath | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "MakeAppx failed"
}

$cert = Get-OrCreateCodeSigningCert -Subject $CertSubject
Ensure-CertTrusted -Cert $cert

& $signTool sign /fd SHA256 /sha1 $cert.Thumbprint /s My $packagePath | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "SignTool failed"
}

try {
    if ($PackageMode -eq "External") {
        Add-AppxPackage -Path $packagePath -ExternalLocation $resolvedInstallDir -ErrorAction Stop
    } else {
        Add-AppxPackage -Path $packagePath -ErrorAction Stop
    }
} catch {
    $activityId = [Guid]::Empty
    if ($_.Exception -and $_.Exception.Message -match "\[ActivityId\]\s+([0-9a-fA-F\-]+)") {
        $activityId = [Guid]$matches[1]
    }

    $hint = if ($activityId -ne [Guid]::Empty) { Get-FriendlyDeploymentHint -ActivityId $activityId } else { $null }
    if ($hint) {
        throw "$($_.Exception.Message)`nHint: $hint"
    }
    throw
}

$registered = Get-AppxPackage $identity.package_name -ErrorAction Stop
Write-Host "Registered package identity: $($identity.package_name)"
Write-Host "Package family: $($registered.PackageFamilyName)"
if ($PackageMode -eq "External") {
    Write-Host "External location: $resolvedInstallDir"
} else {
    Write-Host "Package mode: full"
}
Write-Host "Package path: $packagePath"

try {
    if (Test-Path -LiteralPath $layoutDir) {
        Remove-Item -LiteralPath $layoutDir -Recurse -Force
    }
} catch {
    Write-Warning "left package layout behind at $layoutDir"
}

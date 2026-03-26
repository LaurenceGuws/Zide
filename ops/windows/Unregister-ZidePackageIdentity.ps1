param(
    [string]$PackageName = "LaurenceGuws.Zide"
)

$ErrorActionPreference = "Stop"

$existing = Get-AppxPackage $PackageName -ErrorAction SilentlyContinue
if (-not $existing) {
    Write-Host "Package identity not registered: $PackageName"
    exit 0
}

$existing | Remove-AppxPackage
Write-Host "Removed package identity: $PackageName"

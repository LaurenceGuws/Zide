param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).ProviderPath,
    [string]$OutRoot = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..\..")).ProviderPath "releases\v0.1.0-beta.4\windows-x86_64-local")
)

$ErrorActionPreference = "Stop"

$srcDist = Join-Path $RepoRoot "releases\v0.1.0-beta.4\windows-x86_64\dist"
$outDist = Join-Path $OutRoot "dist"
$workRoot = Join-Path $OutRoot "work"

if (Test-Path -LiteralPath $OutRoot) {
    Remove-Item -LiteralPath $OutRoot -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $outDist | Out-Null
New-Item -ItemType Directory -Force -Path $workRoot | Out-Null

$bundles = @(
    @{
        Name = "zide-ide-bundle-0.1.0-beta.4-windows-x86_64.zip"
        Exe = "zide.exe"
        BuildExe = Join-Path $RepoRoot "zig-out\bin\zide.exe"
    },
    @{
        Name = "zide-editor-bundle-0.1.0-beta.4-windows-x86_64.zip"
        Exe = "zide-editor.exe"
        BuildExe = Join-Path $RepoRoot "zig-out\bin\zide-editor.exe"
    },
    @{
        Name = "zide-terminal-bundle-0.1.0-beta.4-windows-x86_64.zip"
        Exe = "zide-terminal.exe"
        BuildExe = Join-Path $RepoRoot "zig-out\bin\zide-terminal.exe"
    }
)

foreach ($bundle in $bundles) {
    $extract = Join-Path $workRoot ([IO.Path]::GetFileNameWithoutExtension($bundle.Name))
    Expand-Archive -LiteralPath (Join-Path $srcDist $bundle.Name) -DestinationPath $extract -Force
    Copy-Item -LiteralPath $bundle.BuildExe -Destination (Join-Path $extract $bundle.Exe) -Force
    if ($bundle.Exe -eq "zide.exe") {
        Copy-Item -LiteralPath (Join-Path $RepoRoot "zig-out\bin\zide-shell-ext.dll") -Destination (Join-Path $extract "zide-shell-ext.dll") -Force
    }
    Compress-Archive -Path (Join-Path $extract "*") -DestinationPath (Join-Path $outDist $bundle.Name) -Force
}

Copy-Item -LiteralPath (Join-Path $srcDist "zide-terminal-ffi-0.1.0-beta.4-windows-x86_64.zip") -Destination $outDist -Force
Copy-Item -LiteralPath (Join-Path $srcDist "zide-editor-ffi-0.1.0-beta.4-windows-x86_64.zip") -Destination $outDist -Force

$names = @(
    "zide-ide-bundle-0.1.0-beta.4-windows-x86_64.zip",
    "zide-editor-bundle-0.1.0-beta.4-windows-x86_64.zip",
    "zide-terminal-bundle-0.1.0-beta.4-windows-x86_64.zip",
    "zide-terminal-ffi-0.1.0-beta.4-windows-x86_64.zip",
    "zide-editor-ffi-0.1.0-beta.4-windows-x86_64.zip"
)

$lines = foreach ($name in $names) {
    $hash = (Get-FileHash -LiteralPath (Join-Path $outDist $name) -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash *$name"
}

Set-Content -LiteralPath (Join-Path $outDist "SHA256SUMS-windows-x86_64.txt") -Value $lines

Write-Host "Staged local dist at: $outDist"

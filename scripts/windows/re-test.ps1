param(
    [switch]$BuildOnly,
    [switch]$Wait,
    [string]$LogDir
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
Set-Location $RepoRoot

$targets = @(
    @{
        Name = "editor"
        Prefix = "zig-out-editor-retest"
        BuildArgs = @("-Dmode=editor", "--prefix", "zig-out-editor-retest")
        Exe = "zig-out-editor-retest\bin\zide-editor.exe"
    },
    @{
        Name = "ide"
        Prefix = "zig-out-ide-retest"
        BuildArgs = @("-Dmode=ide", "--prefix", "zig-out-ide-retest")
        Exe = "zig-out-ide-retest\bin\zide.exe"
    },
    @{
        Name = "terminal"
        Prefix = "zig-out-terminal-retest"
        BuildArgs = @("-Dmode=terminal", "--prefix", "zig-out-terminal-retest")
        Exe = "zig-out-terminal-retest\bin\zide-terminal.exe"
    }
)

if ($LogDir) {
    $LogDir = [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $LogDir))
    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
}

function Invoke-ZigBuild {
    param(
        [string]$Name,
        [string[]]$BuildArgs
    )

    Write-Host ("==> Building {0}: zig build {1}" -f $Name, ($BuildArgs -join " ")) -ForegroundColor Cyan
    & zig build @BuildArgs
    if ($LASTEXITCODE -ne 0) {
        throw "zig build failed for $Name with exit code $LASTEXITCODE"
    }
}

function Start-ZideTarget {
    param(
        [hashtable]$Target,
        [string]$ResolvedLogDir
    )

    $exePath = Join-Path $RepoRoot $Target.Exe
    if (-not (Test-Path -LiteralPath $exePath)) {
        throw "Built executable not found: $exePath"
    }

    $startInfo = @{
        FilePath = $exePath
        WorkingDirectory = $RepoRoot
        PassThru = $true
    }

    if ($ResolvedLogDir) {
        $stdoutPath = Join-Path $ResolvedLogDir ("{0}.stdout.log" -f $Target.Name)
        $stderrPath = Join-Path $ResolvedLogDir ("{0}.stderr.log" -f $Target.Name)
        $startInfo.RedirectStandardOutput = $stdoutPath
        $startInfo.RedirectStandardError = $stderrPath
        Write-Host ("==> Launching {0} (stdout: {1}, stderr: {2})" -f $Target.Name, $stdoutPath, $stderrPath) -ForegroundColor Green
    } else {
        Write-Host ("==> Launching {0}" -f $Target.Name) -ForegroundColor Green
    }

    return Start-Process @startInfo
}

$launched = @()
foreach ($target in $targets) {
    Invoke-ZigBuild -Name $target.Name -BuildArgs $target.BuildArgs
}

if ($BuildOnly) {
    Write-Host "Builds completed. Skipping launches because -BuildOnly was set." -ForegroundColor Yellow
    exit 0
}

foreach ($target in $targets) {
    $process = Start-ZideTarget -Target $target -ResolvedLogDir $LogDir
    $launched += [pscustomobject]@{
        Name = $target.Name
        Process = $process
    }
}

if ($Wait) {
    foreach ($entry in $launched) {
        $entry.Process.WaitForExit()
        Write-Host ("{0} exited with code {1}" -f $entry.Name, $entry.Process.ExitCode) -ForegroundColor Yellow
    }
} else {
    Write-Host ""
    Write-Host "Launched processes:" -ForegroundColor Cyan
    foreach ($entry in $launched) {
        Write-Host ("  {0}: pid={1}" -f $entry.Name, $entry.Process.Id)
    }
}

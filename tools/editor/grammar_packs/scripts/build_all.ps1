$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
& (Join-Path $PSScriptRoot 'run_python.ps1') (Join-Path $PSScriptRoot 'build_all.py') $root
exit $LASTEXITCODE

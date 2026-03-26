$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
& (Join-Path $PSScriptRoot 'run_python.ps1') (Join-Path $PSScriptRoot 'sync_from_nvim.py') $root
exit $LASTEXITCODE

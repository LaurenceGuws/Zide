$ErrorActionPreference = 'Stop'

# Bootstrap script for zide dependencies (Windows)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$VendorDir = Join-Path $ProjectRoot 'vendor'

Write-Host "==> Bootstrapping zide dependencies" -ForegroundColor Cyan
Write-Host "    Project root: $ProjectRoot"
Write-Host "    Vendor dir:   $VendorDir"

New-Item -ItemType Directory -Force -Path $VendorDir | Out-Null

Write-Host "==> Vendor deps are checked in (tree-sitter, stb_image). No external fetch needed."
Write-Host ""
Write-Host "==> Bootstrap complete!" -ForegroundColor Green
Write-Host "    - vendor: $VendorDir"
Write-Host ""
Write-Host "    To build: zig build"
Write-Host "    To run:   zig build run"

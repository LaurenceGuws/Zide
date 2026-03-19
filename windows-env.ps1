$ErrorActionPreference = "Stop"

$env:ZIG_LOCAL_CACHE_DIR = "C:\Users\lggou\AppData\Local\zide-zig-cache"
$env:ZIG_GLOBAL_CACHE_DIR = "C:\Users\lggou\AppData\Local\zig"
$env:VCPKG_ROOT = "C:\dev\vcpkg-win"
$env:VCPKG_DEFAULT_TRIPLET = "x64-windows"

Write-Host "Loaded Zide Windows build environment:"
Write-Host "  ZIG_LOCAL_CACHE_DIR=$env:ZIG_LOCAL_CACHE_DIR"
Write-Host "  ZIG_GLOBAL_CACHE_DIR=$env:ZIG_GLOBAL_CACHE_DIR"
Write-Host "  VCPKG_ROOT=$env:VCPKG_ROOT"
Write-Host "  VCPKG_DEFAULT_TRIPLET=$env:VCPKG_DEFAULT_TRIPLET"
